extends Node2D
## 玩家领主：WASD 自由走位、自动索敌普攻、空格回旋斩（范围伤害 + 击退）。
## 死亡不结束本局：4 秒后在主城前复活，扣 10 金币。

const Data = preload("res://scripts/game_data.gd")
const Art = preload("res://scripts/art.gd")

const SPAWN_POS := Vector2(344, 566)

var max_hp := 100.0
var hp := 100.0
var alive := true
var facing := Vector2.LEFT
var age := 0.0
var flash := 0.0
var invuln_t := 0.0
var attack_cd := 0.0
var skill_left := 0.0
var respawn_left := 0.0
var swing_t := 0.0
var moving := false
var _main
var _state


func setup(main_ref, state_ref) -> void:
	_main = main_ref
	_state = state_ref
	reset()


func reset() -> void:
	max_hp = float(Data.PLAYER["hp"])
	hp = max_hp
	alive = true
	position = SPAWN_POS
	facing = Vector2.LEFT
	age = 0.0
	flash = 0.0
	invuln_t = 0.0
	attack_cd = 0.0
	skill_left = 0.0
	respawn_left = 0.0
	swing_t = 0.0
	moving = false
	modulate.a = 1.0
	queue_redraw()


func skill_ready_ratio() -> float:
	if _state == null:
		return 1.0
	var total := maxf(0.01, float(_state.mods.get("skill_cd", Data.PLAYER["skill_cd"])))
	return clampf(1.0 - skill_left / total, 0.0, 1.0)


func tick(delta: float, input: Vector2, mouse_pos: Vector2, enemies: Array) -> void:
	age += delta
	flash = maxf(0.0, flash - delta)
	invuln_t = maxf(0.0, invuln_t - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	skill_left = maxf(0.0, skill_left - delta)
	swing_t = maxf(0.0, swing_t - delta)

	if not alive:
		respawn_left = maxf(0.0, respawn_left - delta)
		if respawn_left <= 0.0:
			_revive()
		queue_redraw()
		return

	if input.length_squared() > 0.01:
		moving = true
		var dir := input.normalized()
		position += dir * float(Data.PLAYER["speed"]) * delta
		position.x = clampf(position.x, 48.0, 1232.0)
		position.y = clampf(position.y, 116.0, 684.0)
		if _main != null and _main.is_mouse_inside():
			facing = (mouse_pos - position).normalized()
		else:
			facing = dir
	else:
		moving = false
		if mouse_pos.distance_to(position) > 8.0:
			facing = (mouse_pos - position).normalized()

	if attack_cd <= 0.0:
		var target = _pick_target(enemies)
		if target != null:
			_attack(target)

	if invuln_t > 0.0:
		modulate.a = 0.72 + 0.28 * sin(age * 28.0)
	else:
		modulate.a = 1.0
	queue_redraw()


func _pick_target(enemies: Array):
	var best = null
	var best_score := INF
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not bool(enemy.alive):
			continue
		var dist := position.distance_to(enemy.position)
		if dist > float(Data.PLAYER["range"]):
			continue
		var score := dist
		if enemy.type_id == "elite" or enemy.type_id == "boss":
			score *= 0.72
		if score < best_score:
			best_score = score
			best = enemy
	return best


func _attack(target) -> void:
	var dmg_mult := 1.0 if _state == null else float(_state.mods.get("lord_damage", 1.0))
	var rate_mult := 1.0 if _state == null else float(_state.mods.get("lord_rate", 1.0))
	var dmg := float(Data.PLAYER["damage"]) * dmg_mult
	attack_cd = 1.0 / maxf(0.1, float(Data.PLAYER["rate"]) * rate_mult)
	swing_t = 0.16
	facing = (target.position - position).normalized()
	target.take_damage(dmg, "lord")
	if _main != null:
		_main.on_lord_attack(self, target)


func cast_skill(enemies: Array) -> bool:
	if not alive or skill_left > 0.0:
		return false
	skill_left = float(Data.PLAYER["skill_cd"]) if _state == null else float(_state.mods.get("skill_cd", Data.PLAYER["skill_cd"]))
	var before := position
	position += facing * float(Data.PLAYER["dash"])
	position.x = clampf(position.x, 48.0, 1232.0)
	position.y = clampf(position.y, 116.0, 684.0)
	swing_t = 0.34
	var dmg_mult := 1.0 if _state == null else float(_state.mods.get("lord_damage", 1.0))
	var dmg := float(Data.PLAYER["skill_damage"]) * dmg_mult
	var radius := float(Data.PLAYER["skill_radius"])
	var hit := 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not bool(enemy.alive):
			continue
		if position.distance_to(enemy.position) <= radius + float(enemy.radius):
			enemy.take_damage(dmg, "skill")
			enemy.stagger(enemy.position - position, 34.0)
			hit += 1
	if _main != null:
		_main.on_lord_skill(self, before, hit)
	queue_redraw()
	return true


func take_damage(amount: float) -> void:
	if not alive or invuln_t > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	flash = 0.14
	invuln_t = 0.45
	if _main != null:
		_main.on_player_damaged(self, amount)
	if hp <= 0.0:
		alive = false
		respawn_left = float(Data.PLAYER_RESPAWN_TIME)
		if _main != null:
			_main.on_lord_died(self)
	queue_redraw()


func _revive() -> void:
	alive = true
	hp = max_hp
	position = SPAWN_POS
	invuln_t = 1.4
	flash = 0.0
	modulate.a = 1.0
	if _main != null:
		_main.on_lord_revived(self)
	queue_redraw()


func _draw() -> void:
	if not alive:
		_draw_fallen()
		return
	var bob := sin(age * 9.0) * (1.2 if moving else 0.5)
	Art.shadow(self, Vector2(0, 3), 14.0, 5.0, 0.36)
	# 复活/技能就绪的脚下符文。
	if skill_left <= 0.0:
		Art.dashed_circle(self, Vector2(0, 2), 22.0, Color(0.34, 0.72, 0.64, 0.42), 1.2, 28)
	# 腿。
	var step := 3.0 * sin(age * 13.0) if moving else 0.0
	draw_line(Vector2(-5, -4) + Vector2(0, bob), Vector2(-6 + step, 4), Color("2e3b34"), 3.5)
	draw_line(Vector2(5, -4) + Vector2(0, bob), Vector2(6 - step, 4), Color("2e3b34"), 3.5)
	# 披风与身体。
	var cloak := PackedVector2Array([
		Vector2(-9, -28) + Vector2(0, bob), Vector2(8, -27) + Vector2(0, bob),
		Vector2(13, -7) + Vector2(0, bob), Vector2(5, 0), Vector2(-11, -6) + Vector2(0, bob),
	])
	draw_colored_polygon(cloak, Color("24645f") if flash <= 0.0 else Color("a9e8d8"))
	var tunic := PackedVector2Array([
		Vector2(-7, -24) + Vector2(0, bob), Vector2(7, -24) + Vector2(0, bob),
		Vector2(8, -8) + Vector2(0, bob), Vector2(-8, -8) + Vector2(0, bob),
	])
	draw_colored_polygon(tunic, Color("e6d3a6") if flash <= 0.0 else Color.WHITE)
	draw_line(Vector2(-8, -13) + Vector2(0, bob), Vector2(8, -13) + Vector2(0, bob), Art.GOLD, 2.4)
	# 头部与兜帽。
	draw_circle(Vector2(0, -33) + Vector2(0, bob), 7.4, Color("d9b58b") if flash <= 0.0 else Color.WHITE)
	draw_arc(Vector2(0, -34) + Vector2(0, bob), 8.2, PI * 0.92, TAU * 1.02, 14, Color("2c756c"), 4.0)
	draw_line(Vector2(-7, -34) + Vector2(0, bob), Vector2(-13, -30) + Vector2(0, bob), Art.GOLD, 2.0)
	# 小圆盾。
	draw_circle(Vector2(-11, -16) + Vector2(0, bob), 6.0, Color("3f5e4f"))
	draw_circle(Vector2(-11, -16) + Vector2(0, bob), 4.3, Art.TEAL_DARK)
	Art.diamond(self, Vector2(-11, -16) + Vector2(0, bob), 2.6, Art.GOLD)
	# 剑。
	var hand := Vector2(9, -17) + Vector2(0, bob)
	var sword_dir := facing
	if swing_t > 0.0:
		var swing_angle := facing.angle() + lerpf(1.0, -0.7, swing_t / 0.16)
		sword_dir = Vector2.from_angle(swing_angle)
	draw_line(hand, hand + sword_dir * 25.0, Color("dbe5da"), 2.6)
	draw_line(hand, hand + sword_dir * 7.0, Art.GOLD_DIM, 3.4)
	draw_circle(hand + sword_dir * 25.0, 2.2, Art.CREAM)
	# 血条。
	if hp < max_hp:
		var width := 32.0
		var y := -50.0
		draw_rect(Rect2(-width * 0.5 - 1, y - 1, width + 2, 6), Color(0, 0, 0, 0.6), true)
		draw_rect(Rect2(-width * 0.5, y, width * (hp / max_hp), 4), Art.GREEN, true)


func _draw_fallen() -> void:
	Art.shadow(self, Vector2(0, 3), 16.0, 5.0, 0.3)
	var cloth := PackedVector2Array([
		Vector2(-16, 0), Vector2(4, -6), Vector2(18, 1), Vector2(2, 8), Vector2(-13, 6),
	])
	draw_colored_polygon(cloth, Color(0.18, 0.35, 0.32, 0.7))
	draw_circle(Vector2(6, -2), 5.0, Color(0.18, 0.35, 0.32, 0.6))
	Art.text_center(self, Rect2(-40, -48, 80, 22), "%.1fs" % respawn_left, 15, Art.RED, true)
	draw_arc(Vector2.ZERO, 26.0, 0, TAU, 24, Color(0.85, 0.32, 0.24, 0.35), 2.0)
