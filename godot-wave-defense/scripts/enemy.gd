extends Node2D
## 5 种原创敌人：沿预设路径推进；仇恨玩家 / 拆墙 / 攻击主城 / 精英优先拆塔。
## 无物理引擎：按距离与模式做确定性移动，主循环负责生成/回收。

const Data = preload("res://scripts/game_data.gd")
const Art = preload("res://scripts/art.gd")

var type_id := "militia"
var def: Dictionary = {}
var max_hp := 30.0
var hp := 30.0
var speed := 66.0
var damage := 5.0
var gold := 2
var radius := 10.0
var attack_interval := 1.0
var aggro_radius := 108.0
var body_color := Color("b8553f")

var path_distance := 0.0
var lane_offset := 0.0
var path_len := 1.0
var mode := "path"
var alive := true
var age := 0.0
var facing := Vector2.LEFT
var flash := 0.0
var hit_visible := 0.0
var attack_cd := 0.0
var lunge_t := 0.0
var lunge_dir := Vector2.LEFT
var summon_used := false
var knock_offset := Vector2.ZERO
var knock_t := 0.0
var _redraw_accum := 0.0
var _urgent_accum := 0.0
var _last_face_sign := 0.0

var _main
var _player
var _wall
var _towers: Array = []


func configure(id: String, offset: float) -> void:
	type_id = id
	def = Data.ENEMIES[id]
	max_hp = float(def["hp"])
	hp = max_hp
	speed = float(def["speed"])
	damage = float(def["damage"])
	gold = int(def["gold"])
	radius = float(def["radius"])
	attack_interval = float(def["attack_interval"])
	aggro_radius = float(def["aggro"])
	body_color = def["color"]
	lane_offset = offset
	path_len = Data.path_length()
	path_distance = 0.0
	mode = "path"
	alive = true
	age = 0.0
	normalize_path_position()
	queue_redraw()


func bind(main_ref, player_ref, wall_ref, towers_ref: Array) -> void:
	_main = main_ref
	_player = player_ref
	_wall = wall_ref
	_towers = towers_ref


func set_path_distance(distance: float) -> void:
	path_distance = clampf(distance, 0.0, path_len)
	normalize_path_position()
	mode = "path"


func normalize_path_position() -> void:
	var p := Data.path_point_at(path_distance)
	var t := Data.path_tangent_at(path_distance)
	var perp := Vector2(-t.y, t.x)
	position = p + perp * lane_offset
	facing = t


func is_boss() -> bool:
	return type_id == "boss"


func level_name() -> String:
	return String(def["name"])


func tick(delta: float) -> void:
	if not alive:
		return
	age += delta
	flash = maxf(0.0, flash - delta)
	hit_visible = maxf(0.0, hit_visible - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	lunge_t = maxf(0.0, lunge_t - delta)
	if knock_t > 0.0:
		knock_t = maxf(0.0, knock_t - delta)
	modulate.a = minf(1.0, age / 0.22)

	if def.has("summon_ratio") and not summon_used and hp <= max_hp * float(def["summon_ratio"]):
		summon_used = true
		if _main != null:
			_main.on_boss_summon(self)

	var player_valid := _player != null and bool(_player.alive)
	var player_dist := INF
	if player_valid:
		player_dist = position.distance_to(_player.position)
	var wall_alive := _wall != null and bool(_wall.alive)

	if mode == "path":
		if wall_alive and path_distance >= path_len - 36.0:
			mode = "wall"
		elif path_distance >= path_len - 2.0:
			mode = "castle"
		elif bool(def.get("prefers_tower", false)) and _nearest_tower(135.0) != null:
			mode = "tower"
		elif player_valid and player_dist <= aggro_radius:
			mode = "chase"

	match mode:
		"path":
			_advance_path(delta)
		"chase":
			if not player_valid or player_dist > aggro_radius * 2.15:
				mode = "return"
			else:
				_move_toward(_player.position, speed * 1.03, delta)
				if player_dist <= radius + 20.0:
					_attack("player")
		"return":
			var back := Data.path_point_at(path_distance)
			var t := Data.path_tangent_at(path_distance)
			var target := back + Vector2(-t.y, t.x) * lane_offset
			if position.distance_to(target) <= 4.0:
				position = target
				facing = t
				mode = "path"
			else:
				_move_toward(target, speed * 1.18, delta)
		"wall":
			if not wall_alive:
				mode = "path"
			elif player_valid and player_dist <= aggro_radius * 0.78:
				mode = "chase"
			else:
				var wall_target := Data.WALL_ATTACK_POS + Vector2(0, lane_offset * 0.55)
				_move_toward(wall_target, speed, delta)
				if position.distance_to(Data.WALL_POS) <= 48.0:
					_attack("wall")
		"castle":
			var castle_target := Data.CASTLE_ATTACK_POS + Vector2(0, lane_offset * 0.4)
			_move_toward(castle_target, speed, delta)
			if position.distance_to(Data.CASTLE_POS) <= 74.0:
				_attack("castle")
		"tower":
			var tower = _nearest_tower(180.0)
			if tower == null or not bool(tower.alive):
				mode = "return"
			else:
				_move_toward(tower.position, speed, delta)
				if position.distance_to(tower.position) <= radius + 24.0:
					_attack("tower")

	# 移动只改 Node2D 变换，不必每帧重建绘制指令；10Hz 足够表现步态，
	# 受击白闪/前摇/击退/朝向翻转时立即重绘。
	var face_sign := 1.0 if facing.x >= 0.0 else -1.0
	_redraw_accum += delta
	_urgent_accum += delta
	var urgent := flash > 0.0 or lunge_t > 0.0 or knock_t > 0.0
	var flipped := not is_equal_approx(face_sign, _last_face_sign)
	if flipped or (urgent and _urgent_accum >= 0.05) or _redraw_accum >= 0.1:
		_redraw_accum = 0.0
		_urgent_accum = 0.0
		_last_face_sign = face_sign
		queue_redraw()


func _advance_path(delta: float) -> void:
	path_distance = minf(path_len, path_distance + speed * delta)
	var p := Data.path_point_at(path_distance)
	var t := Data.path_tangent_at(path_distance)
	var perp := Vector2(-t.y, t.x)
	position = p + perp * lane_offset
	facing = t


func _move_toward(target: Vector2, move_speed: float, delta: float) -> void:
	var delta_vec := target - position
	if delta_vec.length_squared() > 0.001:
		facing = delta_vec.normalized()
	position = position.move_toward(target, move_speed * delta)


func _attack(kind: String) -> void:
	if attack_cd > 0.0:
		return
	attack_cd = attack_interval
	lunge_t = 0.2
	match kind:
		"player":
			if _player != null and bool(_player.alive):
				lunge_dir = (_player.position - position).normalized()
				_player.take_damage(damage)
		"wall":
			if _wall != null and bool(_wall.alive):
				lunge_dir = (Data.WALL_POS - position).normalized()
				_wall.damage(damage)
		"castle":
			lunge_dir = (Data.CASTLE_POS - position).normalized()
			if _main != null:
				_main.damage_castle(damage)
		"tower":
			var tower = _nearest_tower(190.0)
			if tower != null:
				lunge_dir = (tower.position - position).normalized()
				tower.take_damage(damage)


func _nearest_tower(max_dist: float):
	var best = null
	var best_d := max_dist
	for tower in _towers:
		if tower == null or not is_instance_valid(tower) or not bool(tower.alive):
			continue
		var d := position.distance_to(tower.position)
		if d < best_d:
			best_d = d
			best = tower
	return best


func stagger(dir: Vector2, distance: float) -> void:
	knock_offset = dir.normalized() * distance
	knock_t = 0.18
	attack_cd = maxf(attack_cd, 0.22)
	queue_redraw()


func take_damage(amount: float, source := "bolt") -> float:
	if not alive:
		return 0.0
	var mult := 1.0
	if source == "bolt" and def.has("armor_bolt"):
		mult = float(def["armor_bolt"])
	var actual := maxf(0.0, amount * mult)
	hp -= actual
	flash = 0.09
	hit_visible = 2.0
	if _main != null:
		_main.on_enemy_damaged(self, actual, source)
	if hp <= 0.0:
		hp = 0.0
		alive = false
		if _main != null:
			_main.on_enemy_killed(self)
	queue_redraw()
	return actual


func _col(base: Color) -> Color:
	if flash <= 0.0:
		return base
	var f := clampf(flash / 0.09, 0.0, 1.0)
	return base.lerp(Color.WHITE, 0.72 * f)


func _lunge_offset() -> Vector2:
	if lunge_t <= 0.0:
		return Vector2.ZERO
	return lunge_dir * sin((lunge_t / 0.2) * PI) * 4.5


func _draw() -> void:
	var lunge := _lunge_offset()
	if knock_t > 0.0:
		lunge += knock_offset * clampf(knock_t / 0.18, 0.0, 1.0)
	var bob := sin(age * 8.0 + lane_offset) * 1.2
	match type_id:
		"militia":
			_draw_militia(lunge + Vector2(0, bob))
		"runner":
			_draw_runner(lunge + Vector2(0, bob * 1.3))
		"shield":
			_draw_shield(lunge + Vector2(0, bob))
		"elite":
			_draw_elite(lunge + Vector2(0, bob * 0.7))
		"boss":
			_draw_boss(lunge + Vector2(0, bob * 0.5))
	if hit_visible > 0.0 or is_boss():
		_draw_health_bar()


func _draw_health_bar() -> void:
	var width := radius * 2.4
	var y := -radius * 2.0 - 20.0
	draw_rect(Rect2(-width * 0.5 - 1, y - 1, width + 2, 6), Color(0, 0, 0, 0.55), true)
	draw_rect(Rect2(-width * 0.5, y, width, 4), Color(0.15, 0.10, 0.08, 0.9), true)
	var ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	draw_rect(Rect2(-width * 0.5, y, width * ratio, 4), Art.RUST.lerp(Art.GOLD, 0.25), true)
	if is_boss():
		Art.text_center(self, Rect2(-70, y - 20, 140, 16), "裂关巨兽", 12, Art.GOLD, true)


func _draw_militia(off: Vector2) -> void:
	var dark := _col(Color("573028"))
	var cloth := _col(body_color)
	Art.shadow(self, Vector2(0, 3), 10.0, 4.0, 0.32)
	draw_line(Vector2(-4, -3) + off, Vector2(-5, 2) + off, dark, 3.0)
	draw_line(Vector2(4, -3) + off, Vector2(5, 2) + off, dark, 3.0)
	var body := PackedVector2Array([
		Vector2(-7, -17) + off, Vector2(7, -17) + off,
		Vector2(9, -5) + off, Vector2(0, -1) + off, Vector2(-9, -5) + off,
	])
	draw_colored_polygon(body, cloth)
	draw_circle(Vector2(0, -21) + off, 6.0, _col(Color("c9a47d")))
	draw_arc(Vector2(0, -21) + off, 7.0, PI, TAU, 10, dark, 3.0)
	var side := -1.0 if facing.x < 0.0 else 1.0
	draw_line(Vector2(0, -13) + off, Vector2(10 * side, -22) + off, Color("8a6a45"), 2.5)
	var tip := Vector2(16 * side, -25) + off
	draw_line(Vector2(10 * side, -22) + off, tip, _col(Color("d7d0b5")), 2.0)
	draw_circle(Vector2(-7 * side, -12) + off, 5.2, _col(Color("6c4a30")))
	draw_circle(Vector2(-7 * side, -12) + off, 2.0, _col(Color("c99c55")))


func _draw_runner(off: Vector2) -> void:
	var cloth := _col(body_color)
	var dark := _col(Color("623025"))
	Art.shadow(self, Vector2(0, 3), 8.0, 3.5, 0.3)
	draw_line(Vector2(-3, -3) + off, Vector2(-7, 3) + off, dark, 2.5)
	draw_line(Vector2(3, -3) + off, Vector2(7, 3) + off, dark, 2.5)
	var body := PackedVector2Array([
		Vector2(-5, -17) + off, Vector2(5, -17) + off, Vector2(6, -4) + off,
		Vector2(0, -1) + off, Vector2(-6, -4) + off,
	])
	draw_colored_polygon(body, cloth)
	var scarf := PackedVector2Array([
		Vector2(-2, -18) + off, Vector2(-14, -21) + off, Vector2(-4, -14) + off,
	])
	draw_colored_polygon(scarf, _col(Color("e5b26a")))
	draw_circle(Vector2(0, -21) + off, 5.0, _col(Color("d7b08a")))
	draw_line(Vector2(0, -24) + off, Vector2(-4, -27) + off, dark, 2.0)
	var side := -1.0 if facing.x < 0.0 else 1.0
	draw_line(Vector2(3 * side, -11) + off, Vector2(10 * side, -16) + off, _col(Color("d7d0b5")), 2.0)
	draw_line(Vector2(-2 * side, -11) + off, Vector2(-9 * side, -17) + off, _col(Color("d7d0b5")), 1.6)


func _draw_shield(off: Vector2) -> void:
	var metal := _col(Color("5c5a51"))
	var cloth := _col(Color("7d3a2f"))
	Art.shadow(self, Vector2(0, 3), 12.0, 4.5, 0.34)
	draw_line(Vector2(-5, -3) + off, Vector2(-6, 3) + off, metal.darkened(0.2), 4.0)
	draw_line(Vector2(5, -3) + off, Vector2(6, 3) + off, metal.darkened(0.2), 4.0)
	var body := PackedVector2Array([
		Vector2(-9, -19) + off, Vector2(9, -19) + off, Vector2(11, -4) + off,
		Vector2(0, 0) + off, Vector2(-11, -4) + off,
	])
	draw_colored_polygon(body, cloth)
	draw_circle(Vector2(0, -22) + off, 6.6, _col(Color("6d6a5e")))
	draw_rect(Rect2(-7, -27, 14, 5), metal, true)
	var side := -1.0 if facing.x < 0.0 else 1.0
	var shield_center := Vector2(9 * side, -11) + off
	draw_rect(Rect2(shield_center.x - 6, shield_center.y - 12, 12, 24), metal, true)
	draw_rect(Rect2(shield_center.x - 4, shield_center.y - 10, 8, 20), metal.lightened(0.15), true)
	draw_line(Vector2(shield_center.x, shield_center.y - 8), Vector2(shield_center.x, shield_center.y + 8), cloth, 2.0)
	draw_line(Vector2(0, -12) + off, Vector2(17 * side, -20) + off, Color("8a6a45"), 2.4)
	draw_circle(Vector2(17 * side, -20) + off, 2.2, metal)


func _draw_elite(off: Vector2) -> void:
	var metal := _col(Color("7c5841"))
	var cloth := _col(body_color)
	Art.shadow(self, Vector2(0, 2), 16.0, 6.0, 0.36)
	draw_circle(Vector2(0, 1) + off, 17.0, Color(0.85, 0.35, 0.20, 0.055))
	draw_line(Vector2(-7, -3) + off, Vector2(-9, 4) + off, _col(Color("51302a")), 5.0)
	draw_line(Vector2(7, -3) + off, Vector2(9, 4) + off, _col(Color("51302a")), 5.0)
	var body := PackedVector2Array([
		Vector2(-12, -26) + off, Vector2(12, -26) + off, Vector2(15, -6) + off,
		Vector2(0, 0) + off, Vector2(-15, -6) + off,
	])
	draw_colored_polygon(body, cloth)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -24) + off, Vector2(-4, -24) + off, Vector2(-2, -6) + off, Vector2(-15, -8) + off,
	]), metal)
	draw_circle(Vector2(0, -30) + off, 8.0, _col(Color("c7a17c")))
	draw_rect(Rect2(-8, -38, 16, 9), metal, true)
	draw_line(Vector2(-2, -39) + off, Vector2(-7, -47) + off, _col(Color("a63f2f")), 3.0)
	var side := -1.0 if facing.x < 0.0 else 1.0
	draw_line(Vector2(0, -20) + off, Vector2(19 * side, -30) + off, Color("7b5a3a"), 4.0)
	var axe := PackedVector2Array([
		Vector2(19 * side, -34) + off, Vector2(27 * side, -27) + off,
		Vector2(19 * side, -19) + off, Vector2(16 * side, -27) + off,
	])
	draw_colored_polygon(axe, _col(Color("b9b3a0")))
	draw_circle(Vector2(-11 * side, -14) + off, 6.0, _col(Color("4e4034")))


func _draw_boss(off: Vector2) -> void:
	var hide := _col(Color("8d5d44"))
	var dark := _col(Color("4a352c"))
	var bone := _col(Color("d8c9a6"))
	Art.shadow(self, Vector2(0, 3), 30.0, 10.0, 0.40)
	draw_circle(Vector2(0, 1) + off, 31.0, Color(0.85, 0.35, 0.18, 0.06))
	# 双腿与巨大躯干。
	draw_line(Vector2(-10, -6) + off, Vector2(-14, 7) + off, dark, 10.0)
	draw_line(Vector2(10, -6) + off, Vector2(14, 7) + off, dark, 10.0)
	var body := PackedVector2Array([
		Vector2(-25, -42) + off, Vector2(23, -45) + off, Vector2(31, -18) + off,
		Vector2(17, 2) + off, Vector2(-18, 2) + off, Vector2(-31, -18) + off,
	])
	draw_colored_polygon(body, hide)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-19, -35) + off, Vector2(1, -40) + off, Vector2(5, -17) + off, Vector2(-22, -14) + off,
	]), hide.lightened(0.12))
	# 岩石甲片。
	for i in range(3):
		draw_circle(Vector2(-13 + i * 12, -30 + (i % 2) * 6) + off, 4.5, dark.lightened(0.12))
	# 头、角与獠牙。
	draw_circle(Vector2(0, -52) + off, 14.0, hide)
	draw_arc(Vector2(0, -52) + off, 15.0, PI * 0.95, TAU * 0.98, 14, dark, 3.0)
	draw_line(Vector2(-13, -58) + off, Vector2(-23, -67) + off, bone, 4.0)
	draw_line(Vector2(13, -58) + off, Vector2(23, -67) + off, bone, 4.0)
	draw_line(Vector2(-7, -46) + off, Vector2(-9, -40) + off, bone, 2.4)
	draw_line(Vector2(7, -46) + off, Vector2(9, -40) + off, bone, 2.4)
	draw_circle(Vector2(-5, -54) + off, 2.2, Color("f2b45e"))
	draw_circle(Vector2(5, -54) + off, 2.2, Color("f2b45e"))
	var side := -1.0 if facing.x < 0.0 else 1.0
	# 巨槌。
	draw_line(Vector2(10 * side, -32) + off, Vector2(34 * side, -20) + off, Color("6b4d34"), 7.0)
	draw_rect(Rect2(28 * side - 8, -29, 18, 18), dark.lightened(0.08), true)
	draw_rect(Rect2(30 * side - 6, -26, 12, 12), _col(Color("9c8b70")), true)
	# 腰布。
	var cloth := PackedVector2Array([
		Vector2(-17, -8) + off, Vector2(17, -8) + off, Vector2(12, 6) + off, Vector2(-12, 6) + off,
	])
	draw_colored_polygon(cloth, _col(Color("6c3b2e")))

