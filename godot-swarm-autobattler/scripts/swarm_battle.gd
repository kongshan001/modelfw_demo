class_name SwarmBattle
extends RefCounted

## 百倍编队自动战斗内核。
## - 每个单位都是扁平 Packed 数组中的一条记录，不创建 Node。
## - 空间哈希：每 tick 重建 heads/next 链表网格，供局部索敌/溅射使用。
## - 渲染层通过 MultiMesh 读取本对象的位置，做 10Hz 逻辑 → 60fps 插值。
## - 纯逻辑，可 headless 跑完（tools/smoke_swarm_battler.gd）。

const Cards = preload("res://scripts/swarm_cards.gd")

const ARENA := Vector2(1200.0, 380.0)
const CELL := 40.0
const GRID_W := 30
const GRID_H := 10
const GRID_CELLS := 300
const TARGET_RING := 2
const TARGET_CELL_VISITS := 8
const TARGET_TOTAL_VISITS := 96
const QUERY_FRONT_MIN := 190.0
const TIME_LIMIT := 30.0
const SIM_DT := 0.1
const MAX_UNITS := 3000
const SEPARATION := true

# 性能剖析计数（默认关闭，不影响正常战斗）。
var profile_enabled := false
var stat_queries := 0
var stat_visits := 0
var stat_attacks := 0
var stat_splashes := 0
var stat_moves := 0
var separation_enabled := SEPARATION
var targeting_enabled := true

const TEAM_LABELS := ["蔚蓝铸群", "赤锈铸群"]

var seed_value := 0
var time := 0.0
var tick_count := 0
var finished := false
var result: Dictionary = {}
var fx_events: Array = []
var battle_log: Array[String] = []

var pos := PackedVector2Array()
var prev := PackedVector2Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var atk := PackedFloat32Array()
var aspd := PackedFloat32Array()
var atk_range := PackedFloat32Array()
var speed := PackedFloat32Array()
var cooldown := PackedFloat32Array()
var retarget := PackedFloat32Array()
var size_mul := PackedFloat32Array()
var team := PackedByteArray()
var role := PackedByteArray() # 0 近战 / 1 远程 / 2 支援 / 3 溅射
var star := PackedByteArray()
var card_idx := PackedByteArray()
var alive := PackedByteArray()
var target := PackedInt32Array()

var side_cards: Array = [[], []]
var side_labels: Array[String] = [TEAM_LABELS[0], TEAM_LABELS[1]]
var side_count: Array[int] = [0, 0]
var side_start_count: Array[int] = [0, 0]
var side_begin: Array[int] = [0, 0]
var side_end: Array[int] = [0, 0]
var side_hp_frac: Array[float] = [1.0, 1.0]
var side_support: Array[int] = [0, 0]
var side_centroid: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var has_centroid: Array[bool] = [false, false]
var side_front: Array[float] = [0.0, ARENA.x]

var _heads := PackedInt32Array()
var _next := PackedInt32Array()
var _rng := RandomNumberGenerator.new()
var _centroid_sum: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _half_logged: Array[bool] = [false, false]
var _time_logged := false
var _first_blood := false
var _kills := 0
var _fx_enabled := true
var _fx_budget := 18


func setup(ally_cards: Array, enemy_cards: Array, opts: Dictionary = {}) -> void:
	seed_value = int(opts.get("seed", 20261126))
	_rng.seed = seed_value
	_fx_enabled = bool(opts.get("fx", true))
	profile_enabled = bool(opts.get("profile", false))
	separation_enabled = SEPARATION
	targeting_enabled = bool(opts.get("targeting", true))
	stat_queries = 0
	stat_visits = 0
	stat_attacks = 0
	stat_splashes = 0
	stat_moves = 0
	var cap := clampi(int(opts.get("cap", Cards.UNIT_CAP_PER_SIDE)), 1, Cards.UNIT_CAP_PER_SIDE)
	var flood := bool(opts.get("flood", false))
	var ally_greed := float(opts.get("ally_greed", 1.0))
	var enemy_greed := float(opts.get("enemy_greed", 1.0))
	var ally_scale := float(opts.get("ally_scale", 1.0))
	var enemy_scale := float(opts.get("enemy_scale", 1.0))
	var ally_counts := Cards.allocate_units(ally_cards, ally_greed, flood, cap, ally_scale)
	var enemy_counts := Cards.allocate_units(enemy_cards, enemy_greed, flood, cap, enemy_scale)
	var ally_stat := float(opts.get("ally_stat_mult", 1.0))
	var enemy_stat := float(opts.get("enemy_stat_mult", 1.0))
	side_cards = [_copy_cards(ally_cards), _copy_cards(enemy_cards)]
	side_labels = [String(opts.get("ally_label", TEAM_LABELS[0])), String(opts.get("enemy_label", TEAM_LABELS[1]))]
	_spawn_side(0, side_cards[0], ally_counts, ally_stat)
	side_begin[0] = 0
	side_end[0] = pos.size()
	_spawn_side(1, side_cards[1], enemy_counts, enemy_stat)
	side_begin[1] = side_end[0]
	side_end[1] = pos.size()
	# 高密度时关闭分离力：让洪流真正重叠成一片，也省掉最贵的邻居查询。
	if opts.has("separation"):
		separation_enabled = bool(opts.get("separation"))
	else:
		separation_enabled = pos.size() <= 600
	_heads = PackedInt32Array()
	_heads.resize(GRID_CELLS)
	_heads.fill(-1)
	_next.resize(pos.size())
	_compute_side_meta()
	time = 0.0
	tick_count = 0
	finished = false
	result = {}
	fx_events.clear()
	battle_log.clear()
	_half_logged = [false, false]
	_time_logged = false
	_first_blood = false
	_kills = 0
	var total_units := side_count[0] + side_count[1]
	_log("交锋 · %s %s 单位 vs %s %s 单位 · 种子 %d" % [
		side_labels[0], Cards.format_units(side_count[0]),
		side_labels[1], Cards.format_units(side_count[1]), seed_value])
	if total_units > 0:
		_log("洪流展开：%d 个独立单位，全部走数组 + 空间哈希。" % total_units)


func _copy_cards(cards: Array) -> Array:
	var out: Array = []
	for entry in cards:
		var card := Cards.get_card(String(entry.get("id", "")))
		if card.is_empty():
			continue
		out.append({"id": card["id"], "star": 2 if int(entry.get("star", 1)) >= 2 else 1})
	return out


func _spawn_side(s: int, cards: Array, counts: Array, side_stat_mult: float = 1.0) -> void:
	var n := cards.size()
	if n == 0:
		return
	var two_rows := n >= 4
	var cols_total := int(ceil(float(n) * 0.5)) if two_rows else n
	var zone_w := 480.0 / float(cols_total)
	var max_w := minf(150.0, zone_w * 0.92)
	var max_h := 130.0 if two_rows else 300.0
	for c in n:
		var entry: Dictionary = cards[c]
		var card := Cards.get_card(String(entry["id"]))
		if card.is_empty():
			continue
		var star_val := int(entry["star"])
		var count := int(counts[c]) if c < counts.size() else 0
		if count <= 0:
			continue
		var anchor := _anchor(s, c, n)
		var cols := maxi(1, int(ceil(sqrt(float(count) * 1.5))))
		var rows := maxi(1, int(ceil(float(count) / float(cols))))
		var spacing := clampf(minf(max_w / float(cols), max_h / float(rows)), 2.4, 13.0)
		var stat_mul := Cards.star_stat_mult(star_val) * side_stat_mult
		var role_val := 0
		if bool(card.get("support", false)):
			role_val = 2
		elif float(card.get("splash", 0.0)) > 0.0:
			role_val = 3
		elif float(card.get("range", 0.0)) > 40.0:
			role_val = 1
		var unit_size := 1.0
		if bool(card.get("tank", false)):
			unit_size = 1.35
		elif role_val == 1:
			unit_size = 0.86
		elif role_val == 2:
			unit_size = 1.12
		if int(card["tier"]) >= 5:
			unit_size *= 1.22
		if star_val >= 2:
			unit_size *= 1.15
		for k in count:
			var col := k % cols
			var row := k / cols
			var px := anchor.x + (float(col) - (float(cols) - 1.0) * 0.5) * spacing
			var py := anchor.y + (float(row) - (float(rows) - 1.0) * 0.5) * spacing * 0.86
			if row % 2 == 1:
				py += spacing * 0.36
			px += _rng.randf_range(-0.32, 0.32) * spacing
			py += _rng.randf_range(-0.32, 0.32) * spacing
			if s == 0:
				px = clampf(px, 18.0, 585.0)
			else:
				px = clampf(px, 615.0, ARENA.x - 18.0)
			py = clampf(py, 18.0, ARENA.y - 18.0)
			pos.append(Vector2(px, py))
			prev.append(Vector2(px, py))
			max_hp.append(float(card["hp"]) * stat_mul)
			hp.append(float(card["hp"]) * stat_mul)
			atk.append(float(card["atk"]) * stat_mul)
			aspd.append(float(card["aspd"]))
			atk_range.append(float(card["range"]))
			speed.append(float(card["speed"]))
			cooldown.append(_rng.randf_range(0.05, 0.85) / maxf(0.1, float(card["aspd"])))
			retarget.append(_rng.randf_range(0.05, 0.4))
			size_mul.append(unit_size)
			team.append(s)
			role.append(role_val)
			star.append(star_val)
			card_idx.append(c)
			alive.append(1)
			target.append(-1)
			side_count[s] += 1
	side_start_count[s] = side_count[s]


func _anchor(s: int, c: int, n: int) -> Vector2:
	var x_center := 300.0
	var y_center := ARENA.y * 0.5
	if n >= 4:
		# 两排锚点，让洪流有纵深，而不是一条横线。
		var cols := int(ceil(float(n) * 0.5))
		var zone_w := 480.0 / float(cols)
		var row := c % 2
		var col := c / 2
		x_center = 60.0 + zone_w * (float(col) + 0.5)
		y_center = 118.0 if row == 0 else 262.0
	else:
		var zone_w := 480.0 / float(n)
		x_center = 60.0 + zone_w * (float(c) + 0.5)
		y_center += (8.0 if c % 2 == 1 else -8.0)
	if s == 1:
		x_center = ARENA.x - x_center
	return Vector2(x_center, y_center)


func _cell_coords(p: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(p.x / CELL), 0, GRID_W - 1),
		clampi(int(p.y / CELL), 0, GRID_H - 1)
	)


func _rebuild_grid() -> void:
	_heads.fill(-1)
	if _next.size() != pos.size():
		_next.resize(pos.size())
	for i in pos.size():
		if alive[i] == 0:
			continue
		var cc := _cell_coords(pos[i])
		var ci := cc.y * GRID_W + cc.x
		_next[i] = _heads[ci]
		_heads[ci] = i


func _compute_side_meta() -> void:
	_centroid_sum[0] = Vector2.ZERO
	_centroid_sum[1] = Vector2.ZERO
	has_centroid = [false, false]
	side_support = [0, 0]
	var fronts: Array[float] = [0.0, ARENA.x]
	for s in 2:
		for i in range(side_begin[s], side_end[s]):
			if alive[i] == 0:
				continue
			_centroid_sum[s] += pos[i]
			has_centroid[s] = true
			if s == 0:
				fronts[0] = maxf(fronts[0], pos[i].x)
			else:
				fronts[1] = minf(fronts[1], pos[i].x)
			if role[i] == 2:
				side_support[s] += 1
		if has_centroid[s]:
			side_centroid[s] = _centroid_sum[s] / float(maxi(1, side_count[s]))
	side_front = fronts


func _find_target(u: int) -> int:
	if finished:
		return -1
	var p := pos[u]
	var my := int(team[u])
	var cc := _cell_coords(p)
	var best := -1
	var best_d2 := INF
	var visits := 0
	if profile_enabled:
		stat_queries += 1
	for ring in TARGET_RING + 1:
		var y0 := maxi(0, cc.y - ring)
		var y1 := mini(GRID_H - 1, cc.y + ring)
		var x0 := maxi(0, cc.x - ring)
		var x1 := mini(GRID_W - 1, cc.x + ring)
		for yy in range(y0, y1 + 1):
			for xx in range(x0, x1 + 1):
				if maxi(absi(xx - cc.x), absi(yy - cc.y)) != ring:
					continue
				var idx := _heads[yy * GRID_W + xx]
				var cell_visits := 0
				while idx != -1 and visits < TARGET_TOTAL_VISITS and cell_visits < TARGET_CELL_VISITS:
					visits += 1
					cell_visits += 1
					if profile_enabled:
						stat_visits += 1
					if alive[idx] != 0 and int(team[idx]) != my:
						var d2 := p.distance_squared_to(pos[idx])
						if d2 < best_d2:
							best_d2 = d2
							best = idx
					idx = _next[idx]
				if visits >= TARGET_TOTAL_VISITS:
					break
			if visits >= TARGET_TOTAL_VISITS:
				break
		if best >= 0:
			return best
		if visits >= TARGET_TOTAL_VISITS:
			break
	return -1


func step(dt: float = SIM_DT) -> bool:
	if finished:
		return true
	dt = clampf(dt, 0.01, 0.2)
	_rebuild_grid()
	_compute_side_meta()
	tick_count += 1
	for s in 2:
		var aura := 1.15 if side_support[s] > 0 and side_count[s] > 0 else 1.0
		var other := 1 - s
		for i in range(side_begin[s], side_end[s]):
			if alive[i] == 0:
				continue
			prev[i] = pos[i]
			cooldown[i] -= dt
			var tgt := target[i]
			if tgt >= 0:
				if alive[tgt] == 0 or int(team[tgt]) == s:
					target[i] = -1
					tgt = -1
				else:
					var leash := atk_range[i] * 1.35 + 24.0
					if pos[i].distance_squared_to(pos[tgt]) > leash * leash:
						target[i] = -1
						tgt = -1
			if tgt < 0:
				retarget[i] -= dt
				if retarget[i] <= 0.0:
					if targeting_enabled:
						var ref_x := side_front[1] if s == 0 else side_front[0]
						var gap := (ref_x - pos[i].x) if s == 0 else (pos[i].x - ref_x)
						var gate := maxf(QUERY_FRONT_MIN, atk_range[i] * 1.25)
						if gap <= gate:
							target[i] = _find_target(i)
					retarget[i] = 0.42 + _rng.randf() * 0.3
					tgt = target[i]
			var p := pos[i]
			var move := Vector2.ZERO
			if tgt >= 0:
				var tp := pos[tgt]
				var d := p.distance_to(tp)
				if d > atk_range[i]:
					move = (tp - p) / maxf(d, 0.001)
				elif cooldown[i] <= 0.0:
					_do_attack(i, tgt, aura)
			elif has_centroid[other]:
				var c := side_centroid[other]
				var d := p.distance_to(c)
				if d > 10.0:
					move = (c - p) / d
			if move != Vector2.ZERO:
				if profile_enabled:
					stat_moves += 1
				var np := p + move * speed[i] * dt
				if separation_enabled:
					var cc := _cell_coords(p)
					var idx := _heads[cc.y * GRID_W + cc.x]
					var seen := 0
					var visited := 0
					var push := Vector2.ZERO
					while idx != -1 and seen < 3 and visited < 8:
						visited += 1
						if idx != i and alive[idx] != 0 and int(team[idx]) == s:
							var off := p - pos[idx]
							var l2 := off.length_squared()
							if l2 > 0.001 and l2 < 36.0:
								var l := sqrt(l2)
								push += off / l * (6.0 - l) * 0.35
							seen += 1
						idx = _next[idx]
					np += push
				pos[i] = Vector2(
					clampf(np.x, 6.0, ARENA.x - 6.0),
					clampf(np.y, 6.0, ARENA.y - 6.0)
				)
	time += dt
	_check_log()
	if side_count[0] <= 0 or side_count[1] <= 0:
		_finish(false)
		return true
	if time >= TIME_LIMIT:
		_finish(true)
		return true
	return false


func _do_attack(i: int, tgt: int, aura: float) -> void:
	if profile_enabled:
		stat_attacks += 1
	var from := pos[i]
	var to := pos[tgt]
	if _fx_enabled and fx_events.size() < 2400:
		if int(role[i]) == 0:
			fx_events.append({"k": "hit", "a": to, "b": to, "team": int(team[i])})
		else:
			fx_events.append({"k": "shot", "a": from, "b": to, "team": int(team[i])})
	_damage(tgt, atk[i])
	if role[i] == 3:
		_splash_damage(i, tgt)
	cooldown[i] = 1.0 / maxf(0.05, aspd[i] * aura)


func _splash_damage(i: int, primary: int) -> void:
	if profile_enabled:
		stat_splashes += 1
	var center := pos[primary]
	var cc := _cell_coords(center)
	var hits := 0
	var visited := 0
	var hit_ids: Array[int] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var xx := cc.x + dx
			var yy := cc.y + dy
			if xx < 0 or xx >= GRID_W or yy < 0 or yy >= GRID_H:
				continue
			var idx := _heads[yy * GRID_W + xx]
			while idx != -1 and hits < 4 and visited < 80:
				visited += 1
				if idx != primary and alive[idx] != 0 and int(team[idx]) != int(team[i]):
					if center.distance_squared_to(pos[idx]) <= 28.0 * 28.0:
						hit_ids.append(idx)
						hits += 1
				idx = _next[idx]
			if hits >= 4:
				break
		if hits >= 4:
			break
	for hid in hit_ids:
		_damage(hid, atk[i] * 0.5)
		if _fx_enabled and fx_events.size() < 2400:
			fx_events.append({"k": "hit", "a": pos[hid], "b": pos[hid], "team": int(team[i])})


func _damage(idx: int, amount: float) -> void:
	if alive[idx] == 0:
		return
	var v := hp[idx] - amount
	if v <= 0.0:
		hp[idx] = 0.0
		alive[idx] = 0
		side_count[int(team[idx])] -= 1
		_kills += 1
		if not _first_blood:
			_first_blood = true
			_log("首次击破 · %s 阵线出现减员。" % side_labels[int(team[idx])])
	else:
		hp[idx] = v


func _check_log() -> void:
	for s in 2:
		if not _half_logged[s] and side_start_count[s] > 0:
			if float(side_count[s]) <= float(side_start_count[s]) * 0.5:
				_half_logged[s] = true
				_log("%s 编队损失过半（剩 %s 单位）" % [side_labels[s], Cards.format_units(side_count[s])])
	if not _time_logged and time >= TIME_LIMIT - 5.0:
		_time_logged = true
		_log("潮汐计时：还剩 5 秒，按剩余血量判定。")


static func recommended_step(units: int) -> float:
	if units <= 400:
		return 0.1
	if units <= 1500:
		return 0.14
	return 0.2


func _compute_hp_fractions() -> void:
	for s in 2:
		var cur := 0.0
		var mx := 0.0
		for i in range(side_begin[s], side_end[s]):
			if alive[i] != 0:
				cur += hp[i]
				mx += max_hp[i]
		side_hp_frac[s] = cur / maxf(1.0, mx)


func _finish(timeout: bool) -> void:
	if finished:
		return
	_compute_side_meta()
	_compute_hp_fractions()
	var winner := 2
	if side_count[0] <= 0 and side_count[1] <= 0:
		winner = 2
	elif side_count[0] <= 0:
		winner = 1
	elif side_count[1] <= 0:
		winner = 0
	elif timeout:
		var diff := side_hp_frac[0] - side_hp_frac[1]
		if absf(diff) < 0.01:
			winner = 2
		elif diff > 0.0:
			winner = 0
		else:
			winner = 1
	var cards_alive := [0, 0]
	var seen := {}
	for i in pos.size():
		if alive[i] == 0:
			continue
		var key := int(team[i]) * 7 + int(card_idx[i])
		if not seen.has(key):
			seen[key] = true
			cards_alive[int(team[i])] += 1
	result = {
		"winner": winner,
		"timeout": timeout,
		"duration": snappedf(time, 0.1),
		"ticks": tick_count,
		"seed": seed_value,
		"start_units": [side_start_count[0], side_start_count[1]],
		"units": [side_count[0], side_count[1]],
		"hp_frac": [snappedf(side_hp_frac[0], 0.001), snappedf(side_hp_frac[1], 0.001)],
		"surviving_cards": [cards_alive[0], cards_alive[1]],
		"kills": _kills,
		"labels": [side_labels[0], side_labels[1]],
		"log": battle_log.duplicate(),
	}
	finished = true
	if winner == 0:
		_log("结算：%s 获胜，剩余 %s 单位。" % [side_labels[0], Cards.format_units(side_count[0])])
	elif winner == 1:
		_log("结算：%s 获胜，剩余 %s 单位。" % [side_labels[1], Cards.format_units(side_count[1])])
	else:
		_log("结算：平局，双方潮汐同时退去。")


func _log(text: String) -> void:
	battle_log.append(text)
	if battle_log.size() > 8:
		battle_log.pop_front()


func run_to_end(max_ticks: int = 420) -> Dictionary:
	var guard := 0
	while not finished and guard < max_ticks:
		step(SIM_DT)
		guard += 1
		if fx_events.size() > 512:
			fx_events.clear()
	if not finished:
		_finish(true)
	result["fx_dropped"] = true
	return result


func kill_count() -> int:
	return _kills


func progress() -> Dictionary:
	return {
		"time": time,
		"finished": finished,
		"counts": [side_count[0], side_count[1]],
		"hp_frac": [side_hp_frac[0], side_hp_frac[1]],
		"units_total": side_count[0] + side_count[1],
	}


func drain_fx(max_count: int = 160) -> Array:
	if fx_events.is_empty():
		return []
	var n := mini(max_count, fx_events.size())
	var out := fx_events.slice(0, n)
	fx_events = fx_events.slice(n)
	return out
