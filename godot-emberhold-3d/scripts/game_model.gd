class_name GameModel
extends RefCounted
## Pure simulation + AI commander. No rendering, no scene dependencies.
## Ported from web-html-tower-defense/index.html so that combat numbers,
## wave composition and AI decisions stay identical to the HTML build.

const GData = preload("res://scripts/game_data.gd")
const MMap = preload("res://scripts/map_data.gd")
const EMath = preload("res://scripts/ember_math.gd")


signal enemy_spawned(enemy)
signal enemy_hit(enemy)
signal enemy_killed(enemy)
signal enemy_leaked(enemy)
signal enemy_healed(enemy, radius)
signal boss_spawned(enemy)
signal tower_built(tower)
signal tower_upgraded(tower)
signal tower_sold(tower, refund)
signal tower_fired(tower, kind)
signal impact(kind, pos, radius)
signal skill_cast(count)
signal wave_started(wave, title, composition)
signal wave_cleared(wave, bonus, mint_total, next_name)
signal game_over(win)
signal toast(title, sub)
signal ai_log_added(log)
signal shake_requested(amount)


class Enemy:
	extends RefCounted
	var id: int
	var type: String
	var hp: float
	var max_hp: float
	var armor: float
	var speed: float
	var reward: int
	var leak: int
	var radius: float
	var slow_resist: float
	var slow_amt: float = 0.0
	var slow_t: float = 0.0
	var heal: float = 0.0
	var heal_radius: float = 0.0
	var heal_t: float = 0.7
	var dist: float = 0.0
	var pos: Vector2 = Vector2.ZERO
	var angle: float = 0.0
	var flash: float = 0.0
	var alive: bool = true
	var visual_seed: float = 0.0
	var trail_t: float = 0.0


class Tower:
	extends RefCounted
	var id: int
	var type: String
	var cx: int
	var cy: int
	var pos: Vector2
	var level: int = 0
	var cooldown: float = 0.15
	var invested: int = 0
	var angle: float = -PI * 0.5
	var flash: float = 0.0
	var pulse: float = 0.0


class Projectile:
	extends RefCounted
	var id: int
	var kind: String
	var pos: Vector2
	var last: Vector2
	var start: Vector2
	var target_id: int
	var speed: float
	var dmg: int
	var splash: float = 0.0
	var slow: float = 0.0
	var slow_time: float = 0.0
	var total: float = 1.0
	var travel: float = 0.0
	var alive: bool = true


var map
var map_id: String = "ashen"
var t: float = 0.0
var phase: String = "prep"
var wave: int = 1
var prep: float = GData.PREP_TIME
var wave_t: float = 0.0
var wave_kills: int = 0
var wave_total: int = 0
var spawn_queue: Array = []
var enemies: Array = []
var towers: Array = []
var projectiles: Array = []
var tower_grid: Dictionary = {}
var next_id: int = 1
var gold: int = GData.START_GOLD
var earned: int = GData.START_GOLD
var lives: int = GData.START_LIVES
var kills: int = 0
var leaks: int = 0
var skill_cd: float = 0.0
var boss = null
var ai_on: bool = false
var ai_timer: float = 0.35
var ai_logs: Array = []
var ai_actions: int = 0
var ai_save_at: float = -99.0
var ai_save_target: String = ""
var shake: float = 0.0
var over: Dictionary = {}
var speed: int = 1


func new_game(id: String, ai_start: bool) -> void:
	map_id = id
	map = MMap.prepare(id)
	t = 0.0
	phase = "prep"
	wave = 1
	prep = GData.PREP_TIME
	wave_t = 0.0
	wave_kills = 0
	wave_total = 0
	spawn_queue = []
	enemies = []
	towers = []
	projectiles = []
	tower_grid = {}
	next_id = 1
	gold = GData.START_GOLD
	earned = GData.START_GOLD
	lives = GData.START_LIVES
	kills = 0
	leaks = 0
	skill_cd = 0.0
	boss = null
	ai_on = ai_start
	ai_timer = 0.35
	ai_logs = []
	ai_actions = 0
	ai_save_at = -99.0
	ai_save_target = ""
	shake = 0.0
	over = {}
	speed = 1
	if ai_start:
		ai_log("info", "AI 指挥官上线 · 自动建造 / 升级 / 技能", "system")
		ai_log("info", "共用金币与冷却 · 不作弊", "system")


func tower_key(cx: int, cy: int) -> String:
	return str(cx) + "," + str(cy)


func tower_range(tower) -> float:
	return GData.tower_range(tower.type, tower.level)


func tower_at(cx: int, cy: int):
	return tower_grid.get(tower_key(cx, cy))


func is_buildable(cx: int, cy: int) -> bool:
	return map != null and map.is_buildable(cx, cy)


func alive_enemies() -> Array:
	var out: Array = []
	for e in enemies:
		if e.alive:
			out.append(e)
	return out


func remaining_enemies() -> int:
	var n := spawn_queue.size()
	for e in enemies:
		if e.alive:
			n += 1
	return n


func ai_log(kind: String, text: String, source: String = "ai") -> void:
	if kind == "save":
		var filtered: Array = []
		for l in ai_logs:
			if l["kind"] != "save":
				filtered.append(l)
		ai_logs = filtered
	ai_logs.append({"kind": kind, "text": text, "source": source, "stamp": EMath.fmt_time(t)})
	if ai_logs.size() > 48:
		ai_logs.pop_front()
	if source == "ai":
		ai_actions += 1
	ai_log_added.emit(ai_logs[ai_logs.size() - 1])


func player_acted() -> void:
	if not ai_on:
		return
	ai_on = false
	ai_log("info", "玩家接管 · AI 转入观察", "user")
	toast.emit("玩家接管", "AI 已转入观察 · 按 A 可交还")


func set_ai(on: bool) -> void:
	if on == ai_on:
		return
	ai_on = on
	ai_timer = 0.15
	if on:
		ai_log("info", "AI 接管 · 自动决策开启", "system")
		toast.emit("AI 接管", "AI 将自动建造 / 升级 / 技能")
	else:
		ai_log("info", "AI 退居观察 · 玩家指挥", "user")
		toast.emit("已切换手动", "按 A 可随时交还 AI")


# ---------- enemies ----------

func spawn_enemy(type_key: String) -> void:
	var base: Dictionary = GData.ENEMIES[type_key]
	var hp := float(roundi(base["hp"] * GData.hp_scale(wave)))
	var e := Enemy.new()
	e.id = next_id
	next_id += 1
	e.type = type_key
	e.hp = hp
	e.max_hp = hp
	e.armor = base["armor"]
	e.speed = base["speed"]
	e.reward = base["reward"]
	e.leak = base["leak"]
	e.radius = base["radius"]
	e.slow_resist = base["slow_resist"]
	e.heal = base.get("heal", 0.0)
	e.heal_radius = base.get("heal_radius", 0.0)
	e.visual_seed = float(e.id * 37) / 100.0
	var p: Vector2 = map.point_at(0.0)["pos"]
	e.pos = p
	enemies.append(e)
	enemy_spawned.emit(e)
	if base.get("boss", false):
		boss = e
		shake = 7.0
		boss_spawned.emit(e)
		toast.emit("无光巨像苏醒", "击退它，守住最后一波")


func position_enemy(e) -> void:
	var p: Dictionary = map.point_at(e.dist)
	e.pos = p["pos"]
	var seg: Dictionary = p["seg"]
	var a: Vector2 = seg["a"]
	var b: Vector2 = seg["b"]
	e.angle = atan2(b.y - a.y, b.x - a.x)


func apply_slow(e, amount: float, time: float) -> void:
	if not e.alive:
		return
	var eff: float = amount * (1.0 - e.slow_resist)
	if eff <= 0.0:
		return
	if eff >= e.slow_amt:
		e.slow_amt = eff
	e.slow_t = maxf(e.slow_t, time)


func damage_enemy(e, dmg: float, ignore_armor: bool = false) -> int:
	if not e.alive:
		return 0
	var armor: float = 0.0 if ignore_armor else e.armor
	var dealt := maxi(1, roundi(dmg - armor))
	e.hp -= dealt
	e.flash = 0.09
	enemy_hit.emit(e)
	if e.hp <= 0.0:
		kill_enemy(e)
	return dealt


func kill_enemy(e) -> void:
	if not e.alive:
		return
	e.alive = false
	kills += 1
	wave_kills += 1
	gold += e.reward
	earned += e.reward
	enemy_killed.emit(e)
	if e.type == "boss":
		shake = 8.0
		toast.emit("无光巨像倒下", "清扫残余，守住灯塔")


func leak_enemy(e) -> void:
	if not e.alive:
		return
	e.alive = false
	leaks += 1
	lives -= e.leak
	shake = minf(8.0, 3.0 + e.leak)
	enemy_leaked.emit(e)
	if lives <= 0:
		lives = 0
		finish_game(false)


func update_enemies(dt: float) -> void:
	for e in enemies:
		if not e.alive:
			continue
		e.flash = maxf(0.0, e.flash - dt)
		if e.slow_t > 0.0:
			e.slow_t -= dt
			if e.slow_t <= 0.0:
				e.slow_amt = 0.0
				e.slow_t = 0.0
		e.dist += e.speed * (1.0 - e.slow_amt) * dt
		if e.dist >= map.total_len:
			leak_enemy(e)
			if not over.is_empty():
				return
			continue
		position_enemy(e)

		if e.heal > 0.0:
			e.heal_t -= dt
			if e.heal_t <= 0.0:
				e.heal_t = 1.35
				var healed := false
				for other in enemies:
					if other == e or not other.alive or other.hp >= other.max_hp:
						continue
					if EMath.dist(e.pos.x, e.pos.y, other.pos.x, other.pos.y) <= e.heal_radius:
						other.hp = minf(other.max_hp, other.hp + e.heal)
						healed = true
				if healed:
					enemy_healed.emit(e, e.heal_radius)
		if e.type == "boss":
			e.trail_t -= dt
			if e.trail_t <= 0.0:
				e.trail_t = 0.14


# ---------- towers ----------

func try_build(type_key: String, cx: int, cy: int, by_ai: bool = false, reason: String = "") -> Dictionary:
	if map == null or not over.is_empty():
		return {"ok": false, "why": "not_playing"}
	var def: Dictionary = GData.TOWERS.get(type_key, {})
	if def.is_empty():
		return {"ok": false, "why": "type"}
	if not is_buildable(cx, cy):
		return {"ok": false, "why": "terrain"}
	if tower_grid.has(tower_key(cx, cy)):
		return {"ok": false, "why": "occupied"}
	if gold < int(def["cost"]):
		return {"ok": false, "why": "gold"}
	if not by_ai:
		player_acted()
	gold -= int(def["cost"])
	var p: Vector2 = map.cell_center(cx, cy)
	var tower := Tower.new()
	tower.id = next_id
	next_id += 1
	tower.type = type_key
	tower.cx = cx
	tower.cy = cy
	tower.pos = p
	tower.level = 0
	tower.cooldown = 0.15
	tower.invested = int(def["cost"])
	tower.angle = -PI * 0.5
	tower.pulse = fmod(float(tower.id) * 1.7, TAU)
	towers.append(tower)
	tower_grid[tower_key(cx, cy)] = tower
	tower_built.emit(tower)
	ai_log("build", "建 %s @%s · %s" % [def["short"], EMath.cell_name(cx, cy), reason if reason != "" else "布局"],
		"ai" if by_ai else "user")
	return {"ok": true, "tower": tower}


func try_upgrade(tower, by_ai: bool = false, reason: String = "") -> bool:
	if map == null or tower == null or not over.is_empty():
		return false
	var def: Dictionary = GData.TOWERS[tower.type]
	if tower.level >= 2:
		return false
	var cost: int = def["upgrades"][tower.level]
	if gold < cost:
		return false
	if not by_ai:
		player_acted()
	gold -= cost
	tower.level += 1
	tower.invested += cost
	tower.flash = 1.0
	tower_upgraded.emit(tower)
	ai_log("upgrade", "升 %s Lv%d · %s" % [def["short"], tower.level + 1,
		reason if reason != "" else "提升主路火力"], "ai" if by_ai else "user")
	return true


func try_sell(tower, by_ai: bool = false) -> bool:
	if map == null or tower == null:
		return false
	if not by_ai:
		player_acted()
	var refund := int(floor(tower.invested * GData.SELL_RATIO))
	gold += refund
	earned += refund
	towers.erase(tower)
	tower_grid.erase(tower_key(tower.cx, tower.cy))
	tower_sold.emit(tower, refund)
	ai_log("sell", "售 %s +%d 金" % [GData.TOWERS[tower.type]["short"], refund],
		"ai" if by_ai else "user")
	return true


func find_target(tower, attack_range: float):
	var best = null
	var best_dist := -1.0
	for e in enemies:
		if not e.alive:
			continue
		var d := EMath.dist(tower.pos.x, tower.pos.y, e.pos.x, e.pos.y)
		if d <= attack_range and e.dist > best_dist:
			best = e
			best_dist = e.dist
	return best


func fire_tower(tower, target, def: Dictionary, lv: Dictionary) -> void:
	tower.angle = atan2(target.pos.y - (tower.pos.y - 6.0), target.pos.x - tower.pos.x)
	tower.flash = 1.0
	tower.cooldown = 1.0 / float(lv["rate"])
	var start_pos: Vector2 = tower.pos + Vector2(0.0, -7.0)
	var p := Projectile.new()
	p.id = next_id
	next_id += 1
	p.kind = tower.type
	p.pos = start_pos
	p.start = start_pos
	p.last = target.pos
	p.target_id = target.id
	p.dmg = lv["dmg"]
	p.total = maxf(1.0, EMath.dist(start_pos.x, start_pos.y, target.pos.x, target.pos.y))
	if tower.type == "bolt":
		p.speed = 320.0
	elif tower.type == "flame":
		p.speed = 175.0
		p.splash = lv["splash"]
	else:
		p.speed = 270.0
		p.slow = lv["slow"]
		p.slow_time = lv["slow_time"]
	projectiles.append(p)
	tower_fired.emit(tower, tower.type)


func update_towers(dt: float) -> void:
	for tower in towers:
		tower.flash = maxf(0.0, tower.flash - dt * 4.0)
		if tower.type == "mint":
			continue
		if tower.cooldown > 0.0:
			tower.cooldown -= dt
		if tower.cooldown > 0.0:
			continue
		var lv: Dictionary = GData.TOWERS[tower.type]["levels"][tower.level]
		var target = find_target(tower, float(lv["range"]))
		if target == null:
			continue
		fire_tower(tower, target, GData.TOWERS[tower.type], lv)


func impact_projectile(p) -> void:
	if p.kind == "flame":
		for e in enemies:
			if e.alive and EMath.dist(p.pos.x, p.pos.y, e.pos.x, e.pos.y) <= p.splash:
				damage_enemy(e, p.dmg)
		impact.emit("flame", p.pos, p.splash)
		shake = maxf(shake, 1.2)
	else:
		var target = null
		for e in enemies:
			if e.id == p.target_id and e.alive:
				target = e
				break
		if target != null:
			damage_enemy(target, p.dmg)
			if p.kind == "frost":
				apply_slow(target, p.slow, p.slow_time)
			impact.emit(p.kind, target.pos, 0.0)


func update_projectiles(dt: float) -> void:
	for p in projectiles:
		if not p.alive:
			continue
		var target = null
		for e in enemies:
			if e.id == p.target_id and e.alive:
				target = e
				break
		if target != null:
			p.last = target.pos
		var dx: float = p.last.x - p.pos.x
		var dy: float = p.last.y - p.pos.y
		var d: float = sqrt(dx * dx + dy * dy)
		if d <= 0.0:
			d = 1.0
		var step: float = p.speed * dt
		p.travel += step
		if d <= step + 2.5:
			p.pos = p.last
			impact_projectile(p)
			p.alive = false
		else:
			p.pos += Vector2(dx / d * step, dy / d * step)
	var kept: Array = []
	for p in projectiles:
		if p.alive:
			kept.append(p)
	projectiles = kept


# ---------- skill ----------

func cast_skill(by_ai: bool = false) -> int:
	if map == null or not over.is_empty():
		return 0
	if skill_cd > 0.0:
		return 0
	var targets: Array = []
	for e in enemies:
		if e.alive:
			targets.append(e)
	if targets.is_empty():
		return 0
	if not by_ai:
		player_acted()
	skill_cd = GData.SKILL_CD
	shake = maxf(shake, 3.5)
	for e in targets:
		apply_slow(e, 0.30, 1.5)
		damage_enemy(e, GData.SKILL_DMG, true)
	skill_cast.emit(targets.size())
	ai_log("skill", "烬雨命中 %d 只 · 全场真伤" % targets.size(), "ai" if by_ai else "user")
	toast.emit("烬雨落下", "命中 %d 个敌人 · 无视护甲" % targets.size())
	return targets.size()


# ---------- waves ----------

func start_wave() -> void:
	var wave_def: Dictionary = GData.WAVES[wave - 1]
	phase = "wave"
	wave_t = 0.0
	wave_kills = 0
	spawn_queue = []
	boss = null
	var idx := 0
	for grp in wave_def["groups"]:
		for i in grp["n"]:
			spawn_queue.append({
				"type": grp["type"],
				"t": 0.15 + grp.get("delay", 0.0) + i * grp["gap"],
				"_i": idx,
			})
			idx += 1
	spawn_queue.sort_custom(func(a, b):
		if a["t"] == b["t"]:
			return a["_i"] < b["_i"]
		return a["t"] < b["t"])
	wave_total = spawn_queue.size()
	wave_started.emit(wave, wave_def["name"], GData.wave_composition(wave - 1))
	toast.emit("第 %d 波 · %s" % [wave, wave_def["name"]], GData.wave_composition(wave - 1))


func end_wave() -> void:
	var completed := wave
	var bonus := 18 + completed * 6
	gold += bonus
	earned += bonus
	var mint_total := 0
	for tower in towers:
		if tower.type != "mint":
			continue
		var inc: int = GData.TOWERS["mint"]["levels"][tower.level]["income"]
		gold += inc
		earned += inc
		mint_total += inc
	if completed >= GData.MAX_WAVE:
		finish_game(true)
		return
	wave = completed + 1
	phase = "prep"
	prep = GData.PREP_TIME
	wave_t = 0.0
	boss = null
	projectiles = []
	ai_save_at = -99.0
	ai_save_target = ""
	wave_cleared.emit(completed, bonus, mint_total, GData.WAVES[wave - 1]["name"])
	toast.emit("第 %d 波守住  +%d 金" % [completed, bonus],
		("铸币圣坛另产出 %d 金" % mint_total) if mint_total > 0 else ("下一波：%s" % GData.WAVES[wave - 1]["name"]))


func finish_game(win: bool) -> void:
	if map == null or not over.is_empty():
		return
	over = {
		"win": win,
		"wave": GData.MAX_WAVE if win else wave,
		"kills": kills,
		"lives": lives,
		"gold": gold,
		"earned": earned,
		"towers": towers.size(),
		"ai_actions": ai_actions,
		"time": t,
		"ai": ai_on,
	}
	phase = "done"
	game_over.emit(win)


# ---------- AI commander ----------

func tower_coverage(tower) -> int:
	if tower.type == "mint":
		return 0
	var r := tower_range(tower)
	var n := 0
	for s in map.samples:
		if EMath.dist(tower.pos.x, tower.pos.y, s.x, s.y) <= r:
			n += 1
	return n


func find_build_spot(type_key: String) -> Dictionary:
	var is_mint := type_key == "mint"
	var r: float = 0.0 if is_mint else GData.tower_range(type_key, 0)
	var mask := PackedInt32Array()
	mask.resize(map.samples.size())
	mask.fill(0)
	if not is_mint:
		for tower in towers:
			if tower.type == "mint":
				continue
			var tr := tower_range(tower)
			for i in map.samples.size():
				var s: Vector2 = map.samples[i]
				if EMath.dist(tower.pos.x, tower.pos.y, s.x, s.y) <= tr:
					mask[i] += 1
	var best := {}
	var best_score := -1e9
	for c in map.build_cells:
		if tower_grid.has(tower_key(c.x, c.y)):
			continue
		var p: Vector2 = map.cell_center(c.x, c.y)
		var score := 0.0
		if is_mint:
			var cov := 0
			for s in map.samples:
				if EMath.dist(p.x, p.y, s.x, s.y) <= 64.0:
					cov += 1
			score = -cov + EMath.hash2(c.x, c.y, 41) * 0.8
		else:
			var hits := 0
			for i in map.samples.size():
				var s: Vector2 = map.samples[i]
				if EMath.dist(p.x, p.y, s.x, s.y) <= r:
					score += 1.0 / (1.0 + mask[i] * 0.8)
					hits += 1
			if hits < 3:
				continue
			for tower in towers:
				if EMath.dist(p.x, p.y, tower.pos.x, tower.pos.y) < 26.0:
					score -= 0.55
			if map.distance_to_path(p.x, p.y) < 23.0:
				score += 0.22
			score += EMath.hash2(c.x, c.y, 73) * 0.02
		if score > best_score:
			best_score = score
			best = {"cx": c.x, "cy": c.y}
	return best


func _count_type(kind: String) -> int:
	var n := 0
	for tower in towers:
		if tower.type == kind:
			n += 1
	return n


func ai_extra_type(inc: Dictionary, attacks: Array) -> String:
	var frost_n := _count_type("frost")
	var flame_n := _count_type("flame")
	if inc["moth"] >= 8 and frost_n < 2:
		return "frost"
	if inc["brute"] >= 4 and flame_n < 2:
		return "flame"
	if wave >= 5 and frost_n < 2 and attacks.size() >= 4:
		return "frost"
	if flame_n < 2 and attacks.size() >= 3:
		return "flame"
	if wave >= 8 and frost_n < 3:
		return "frost"
	return "bolt" if wave % 2 == 0 else "flame"


func ai_pick_upgrade() -> Dictionary:
	var best := {}
	for tower in towers:
		if tower.level >= 2:
			continue
		var def: Dictionary = GData.TOWERS[tower.type]
		var cost: int = def["upgrades"][tower.level]
		if gold < cost:
			continue
		var score := 0.0
		if tower.type == "mint":
			if wave > 6:
				continue
			score = 18.0 + (6 - wave) * 4.0
		else:
			score = tower_coverage(tower) * (1.0 + tower.level * 0.12)
			if tower.type == "flame":
				score *= 1.22
			if tower.type == "frost":
				score *= 1.08
		if best.is_empty() or score > best["score"]:
			var reason := "主路火力提升"
			if tower.type == "flame":
				reason = "范围收益高"
			elif tower.type == "frost":
				reason = "控场时长提升"
			elif tower.type == "mint":
				reason = "早期返金"
			best = {"tower": tower, "cost": cost, "score": score, "reason": reason}
	return best


func ai_maybe_log_save(target: Dictionary) -> void:
	if target.is_empty():
		return
	var now := t
	var name := ""
	if target.get("upgrade", false):
		name = target["name"]
	else:
		name = GData.TOWERS[target["type"]]["short"] if GData.TOWERS.has(target["type"]) else "升级"
	if now - ai_save_at < 9.0 and name == ai_save_target:
		return
	if gold >= int(target["cost"]):
		return
	if gold < int(target["cost"]) * 0.35:
		return
	ai_save_at = now
	ai_save_target = name
	ai_log("save", "存 %d/%d · 攒%s%s" % [gold, int(target["cost"]),
		"升级·" if target.get("upgrade", false) else "", name], "ai")


func ai_execute_build(type_key: String, reason: String) -> bool:
	var spot := find_build_spot(type_key)
	if spot.is_empty():
		ai_log("info", "暂无合适落点 · 等待空位", "ai")
		return false
	var res := try_build(type_key, spot["cx"], spot["cy"], true, reason)
	return bool(res["ok"])


func ai_think() -> void:
	if map == null or not ai_on or not over.is_empty():
		return

	if phase == "wave" and skill_cd <= 0.0:
		var alive := alive_enemies()
		var boss_alive := false
		for e in alive:
			if e.type == "boss":
				boss_alive = true
				break
		if boss_alive or (wave >= 3 and alive.size() >= 5):
			cast_skill(true)

	var attacks: Array = []
	for tower in towers:
		if tower.type != "mint":
			attacks.append(tower)
	var inc := GData.count_wave_types(wave - 1)
	var desired: int = mini(11, 2 + int(ceil(wave * 0.7)))

	var essential := ""
	var essential_reason := ""
	if attacks.size() < 2:
		essential = "bolt"
		essential_reason = "起手火力"
	elif wave >= 3 and _count_type("frost") == 0:
		essential = "frost"
		essential_reason = "高速敌需减速"
	elif wave >= 3 and _count_type("flame") == 0:
		essential = "flame"
		essential_reason = "敌群密集·补溅射"
	if essential != "":
		var cost: int = GData.TOWERS[essential]["cost"]
		if gold >= cost:
			if ai_execute_build(essential, essential_reason):
				return
		ai_maybe_log_save({"type": essential, "cost": cost})
		return

	if _count_type("mint") == 0 and wave >= 2 and wave <= 7 and gold >= int(GData.TOWERS["mint"]["cost"]) + 28:
		if ai_execute_build("mint", "前期投资·每波返金"):
			return

	if attacks.size() < desired:
		var type_key := ai_extra_type(inc, attacks)
		var cost: int = GData.TOWERS[type_key]["cost"]
		if gold >= cost + 16:
			var reason := "补单体火力"
			if type_key == "frost":
				reason = "补控场"
			elif type_key == "flame":
				reason = "扩溅射"
			if ai_execute_build(type_key, reason):
				return
		var up := ai_pick_upgrade()
		if not up.is_empty() and gold >= int(up["cost"]) + 16:
			if try_upgrade(up["tower"], true, up["reason"]):
				return
		ai_maybe_log_save({"type": type_key, "cost": cost})
		return

	var up := ai_pick_upgrade()
	if not up.is_empty() and gold >= int(up["cost"]) + (0 if wave >= 10 else 18):
		if try_upgrade(up["tower"], true, up["reason"]):
			return

	if towers.size() < 12:
		var type_key := ai_extra_type(inc, attacks)
		var cost: int = GData.TOWERS[type_key]["cost"]
		if gold >= cost + 18:
			if ai_execute_build(type_key, "扩覆盖"):
				return
		if type_key != "bolt" and gold >= int(GData.TOWERS["bolt"]["cost"]) + 18:
			if ai_execute_build("bolt", "补火力"):
				return
		if not up.is_empty():
			ai_maybe_log_save({"upgrade": true, "name": GData.TOWERS[up["tower"].type]["short"], "cost": up["cost"]})
		else:
			ai_maybe_log_save({"type": type_key, "cost": cost})
		return

	if not up.is_empty():
		ai_maybe_log_save({"upgrade": true, "name": GData.TOWERS[up["tower"].type]["short"], "cost": up["cost"]})


func ai_update(dt: float) -> void:
	if map == null or not ai_on or not over.is_empty():
		return
	ai_timer -= dt
	if ai_timer > 0.0:
		return
	ai_timer = GData.AI_INTERVAL
	ai_think()


# ---------- main step ----------

func simulate(dt: float) -> void:
	if map == null or not over.is_empty():
		return
	t += dt
	if skill_cd > 0.0:
		skill_cd = maxf(0.0, skill_cd - dt)
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 18.0)

	if phase == "prep":
		prep -= dt
		if prep <= 0.0:
			start_wave()

	if phase == "wave":
		wave_t += dt
		while not spawn_queue.is_empty() and spawn_queue[0]["t"] <= wave_t:
			var entry: Dictionary = spawn_queue.pop_front()
			spawn_enemy(entry["type"])
		update_enemies(dt)
		if not over.is_empty():
			return

	update_towers(dt)
	update_projectiles(dt)

	if phase == "wave" and spawn_queue.is_empty():
		var any_alive := false
		for e in enemies:
			if e.alive:
				any_alive = true
				break
		if not any_alive:
			end_wave()

	if over.is_empty():
		var kept: Array = []
		for e in enemies:
			if e.alive:
				kept.append(e)
		enemies = kept
		if boss != null and not boss.alive:
			boss = null
		ai_update(dt)


# ---------- QA helpers ----------

## Headless autotest equivalent of ?autotest=1: AI plays alone, prep shortened to 2.5s.
func run_autotest(max_sim_time: float = 900.0) -> Dictionary:
	if map == null:
		new_game("ashen", true)
	prep = 2.5
	var steps := 0
	while over.is_empty() and t <= max_sim_time:
		simulate(GData.STEP)
		steps += 1
		if steps > int(max_sim_time / GData.STEP) + 10:
			break
	var res := {
		"map": map_id,
		"win": bool(over.get("win", false)),
		"timeout": over.is_empty(),
		"sim_time": snappedf(t, 0.01),
		"wave": wave,
		"lives": lives,
		"kills": kills,
		"leaks": leaks,
		"gold": gold,
		"earned": earned,
		"ai_actions": ai_actions,
		"ai_on": ai_on,
		"cheats": false,
		"towers": _tower_summary(),
		"logs": ai_logs.slice(maxi(0, ai_logs.size() - 12)),
	}
	return res


func _tower_summary() -> Array:
	var out: Array = []
	for tower in towers:
		out.append({"type": tower.type, "level": tower.level, "cx": tower.cx, "cy": tower.cy})
	return out
