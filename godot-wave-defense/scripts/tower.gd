extends Node2D
## 两种固定塔：弩塔（单体连射，盾兵减伤）与炮塔（范围爆炸，克制盾兵/兵潮）。
## 可升 2 级，出售返还总投入 50%；塔可被精英/Boss 拆毁并腾出建造位。

const Data = preload("res://scripts/game_data.gd")
const Art = preload("res://scripts/art.gd")

var type_id := "crossbow"
var def: Dictionary = {}
var level := 1
var max_hp := 180.0
var hp := 180.0
var alive := true
var invested := 50
var cooldown := 0.0
var flash := 0.0
var recoil_t := 0.0
var aim_angle := 0.0
var show_range := false
var _main
var _state
var _shells: Array = []


func setup(id: String, state_ref, main_ref) -> void:
	type_id = id
	def = Data.TOWERS[id]
	level = 1
	max_hp = float(def["hp"])
	hp = max_hp
	alive = true
	invested = int(def["cost"])
	cooldown = 0.35
	flash = 0.0
	recoil_t = 0.0
	aim_angle = PI
	show_range = false
	_shells.clear()
	_state = state_ref
	_main = main_ref
	queue_redraw()


func set_show_range(value: bool) -> void:
	if value != show_range:
		show_range = value
		queue_redraw()


func stats() -> Dictionary:
	return Data.tower_stats(type_id, level, _state.mods if _state != null else {})


func upgrade_cost() -> int:
	return 0 if level >= 2 else int(def["upgrade_cost"])


func upgrade() -> void:
	if level >= 2:
		return
	invested += int(def["upgrade_cost"])
	level = 2
	max_hp += 30.0
	hp = max_hp
	queue_redraw()


func sell_value() -> int:
	return int(floor(float(invested) * 0.5))


func tick(delta: float, enemies: Array) -> void:
	if not alive:
		return
	flash = maxf(0.0, flash - delta)
	recoil_t = maxf(0.0, recoil_t - delta)
	cooldown = maxf(0.0, cooldown - delta)

	for i in range(_shells.size() - 1, -1, -1):
		var shell: Dictionary = _shells[i]
		shell["timer"] = float(shell["timer"]) - delta
		if float(shell["timer"]) <= 0.0:
			_shells.remove_at(i)
			_impact(shell, enemies)

	if cooldown > 0.0:
		queue_redraw()
		return
	var st := stats()
	if type_id == "cannon":
		var target = _pick_cluster_target(enemies, float(st["range"]), float(st["splash"]))
		if target != null:
			_fire_cannon(target, st)
	else:
		var target = _pick_bolt_target(enemies, float(st["range"]))
		if target != null:
			_fire_bolt(target, st)
	queue_redraw()


func _pick_bolt_target(enemies: Array, reach: float):
	var best = null
	var best_progress := -INF
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not bool(enemy.alive):
			continue
		if position.distance_to(enemy.position) > reach + float(enemy.radius):
			continue
		if float(enemy.path_distance) > best_progress:
			best_progress = float(enemy.path_distance)
			best = enemy
	return best


func _pick_cluster_target(enemies: Array, reach: float, splash: float):
	var best = null
	var best_score := -1.0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not bool(enemy.alive):
			continue
		if position.distance_to(enemy.position) > reach + float(enemy.radius):
			continue
		var count := 0
		for other in enemies:
			if other == null or not is_instance_valid(other) or not bool(other.alive):
				continue
			if enemy.position.distance_to(other.position) <= splash:
				count += 1
		var score := float(count) * 1000.0 + float(enemy.path_distance)
		if score > best_score:
			best_score = score
			best = enemy
	return best


func _fire_bolt(target, st: Dictionary) -> void:
	cooldown = 1.0 / maxf(0.1, float(st["rate"]))
	recoil_t = 0.16
	var from := position + Vector2(0, -28)
	var to: Vector2 = target.position + Vector2(0, -12)
	aim_angle = (to - position).angle()
	var dmg := float(st["damage"])
	target.take_damage(dmg, "bolt")
	if _main != null:
		_main.fx.beam(from, to, Art.TEAL, 2.2)
		_main.fx.burst(to, Art.TEAL, 3, 40.0, 0.22)
		_main.add_shake(0.6)


func _fire_cannon(target, st: Dictionary) -> void:
	cooldown = 1.0 / maxf(0.1, float(st["rate"]))
	recoil_t = 0.24
	var radius := float(st["splash"])
	var impact_pos: Vector2 = target.position
	var from := position + Vector2(0, -30)
	var dist := from.distance_to(impact_pos)
	var travel := clampf(dist / 620.0, 0.18, 0.65)
	aim_angle = (impact_pos - position).angle()
	_shells.append({
		"timer": travel,
		"total": travel,
		"pos": impact_pos,
		"radius": radius,
		"damage": float(st["damage"]),
	})
	if _main != null:
		_main.fx.shell(from, impact_pos, travel)


func _impact(shell: Dictionary, enemies: Array) -> void:
	var impact_pos: Vector2 = shell["pos"]
	var radius := float(shell["radius"])
	var dmg := float(shell["damage"])
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not bool(enemy.alive):
			continue
		if impact_pos.distance_to(enemy.position) <= radius + float(enemy.radius):
			enemy.take_damage(dmg, "cannon")
	if _main != null:
		_main.fx.explosion(impact_pos, radius)
		_main.add_shake(2.5)


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp = maxf(0.0, hp - amount)
	flash = 0.12
	if _main != null:
		_main.on_tower_damaged(self, amount)
	if hp <= 0.0:
		alive = false
		if _main != null:
			_main.on_tower_destroyed(self)
	queue_redraw()


func _draw() -> void:
	var st := stats()
	if show_range:
		var reach := float(st["range"])
		draw_circle(Vector2.ZERO, reach, Color(0.30, 0.68, 0.58, 0.055))
		Art.dashed_circle(self, Vector2.ZERO, reach, Color(0.47, 0.84, 0.72, 0.35), 1.4, 48)
	# 圆形石基。
	Art.shadow(self, Vector2(0, 8), 29.0, 9.0, 0.36)
	draw_circle(Vector2(0, 0), 25.0, Art.STONE_DARK)
	draw_circle(Vector2(0, -2), 21.0, Art.STONE)
	draw_arc(Vector2(0, -2), 18.0, 0, TAU, 20, Art.GOLD_DIM, 1.2)
	var tint := 1.0 - clampf(flash / 0.12, 0.0, 1.0) * 0.55
	if type_id == "crossbow":
		_draw_crossbow(st, tint)
	else:
		_draw_cannon(st, tint)
	# 等级标记。
	for i in range(level):
		draw_circle(Vector2(-6 + i * 12, 18), 3.0, Art.GOLD if i == 0 else Art.CREAM)
	if hp < max_hp:
		var width := 38.0
		draw_rect(Rect2(-width * 0.5 - 1, -52, width + 2, 6), Color(0, 0, 0, 0.6), true)
		draw_rect(Rect2(-width * 0.5, -51, width * (hp / max_hp), 4), Art.GREEN, true)


func _draw_crossbow(st: Dictionary, tint: float) -> void:
	var wood := Color("6b5036").lerp(Color.WHITE, 1.0 - tint)
	var wood_light := Color("8b6b47").lerp(Color.WHITE, 1.0 - tint)
	var mast := Color("4a3a29").lerp(Color.WHITE, 1.0 - tint)
	var recoil := Vector2(0, sin(recoil_t * 32.0) * 2.0) if recoil_t > 0.0 else Vector2.ZERO
	draw_rect(Rect2(-7, -42, 14, 34), mast, true)
	draw_line(Vector2(-5, -38), Vector2(5, -10), wood_light, 2.0)
	draw_line(Vector2(5, -38), Vector2(-5, -10), wood_light, 2.0)
	# 弩臂指向目标。
	draw_set_transform(Vector2(0, -42) + recoil, aim_angle, Vector2.ONE)
	draw_line(Vector2(-20, 0), Vector2(0, -9), wood, 4.0)
	draw_line(Vector2(20, 0), Vector2(0, -9), wood, 4.0)
	draw_line(Vector2(-20, 0), Vector2(20, 0), Color(0.82, 0.78, 0.63, 0.75), 1.2)
	draw_line(Vector2(-4, -4), Vector2(18, -4), Art.CREAM, 2.4)
	draw_line(Vector2(18, -4), Vector2(23, -4), Art.TEAL, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(Vector2(0, -42), Vector2(0, -57), wood_light, 3.0)
	var flag := PackedVector2Array([Vector2(1, -57), Vector2(18, -53), Vector2(1, -47)])
	draw_colored_polygon(flag, Art.TEAL_DARK)
	# 塔顶小屋。
	draw_rect(Rect2(-11, -24, 22, 14), Color("4f5b50").lerp(Color.WHITE, 1.0 - tint), true)
	draw_rect(Rect2(-11, -24, 22, 3), Art.STONE_LIGHT, true)


func _draw_cannon(st: Dictionary, tint: float) -> void:
	var iron := Color("555a52").lerp(Color.WHITE, 1.0 - tint)
	var iron_dark := Color("363c36").lerp(Color.WHITE, 1.0 - tint)
	var wood := Color("6b4d34").lerp(Color.WHITE, 1.0 - tint)
	var recoil := sin(recoil_t * 34.0) * 3.0 if recoil_t > 0.0 else 0.0
	draw_rect(Rect2(-15, -18, 30, 15), wood, true)
	draw_circle(Vector2(-14, 2), 6.5, iron_dark)
	draw_circle(Vector2(14, 2), 6.5, iron_dark)
	draw_circle(Vector2(-14, 2), 2.0, Art.GOLD_DIM)
	draw_circle(Vector2(14, 2), 2.0, Art.GOLD_DIM)
	# 炮管朝目标，带后坐力。
	draw_set_transform(Vector2(-recoil, -20), aim_angle, Vector2.ONE)
	draw_rect(Rect2(-8, -7, 34, 14), iron, true)
	draw_rect(Rect2(-8, -7, 34, 3), iron.lightened(0.18), true)
	draw_rect(Rect2(20, -5, 8, 10), iron_dark, true)
	draw_circle(Vector2(0, 0), 8.0, iron_dark)
	draw_circle(Vector2(0, 0), 3.0, Art.AMBER)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 塔身与装填桶。
	draw_rect(Rect2(-9, -28, 18, 12), Color("4f5b50").lerp(Color.WHITE, 1.0 - tint), true)
	draw_rect(Rect2(-9, -28, 18, 3), Art.STONE_LIGHT, true)
	draw_circle(Vector2(13, -29), 4.0, Color("75552f"))
