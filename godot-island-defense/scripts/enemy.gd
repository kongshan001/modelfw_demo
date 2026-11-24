class_name MistEnemy
extends Node3D
## 海掠者：从登陆点走向最近房屋，途中会攻击挡路的小队；重盾、掷斧手与首领形成额外威胁。

const Balance = preload("res://scripts/balance.gd")
const Models = preload("res://scripts/models.gd")

var game
var type_id := "raider"
var data: Dictionary
var hp := 46.0
var max_hp := 46.0
var alive := true
var class_id := "raider"
var speed := 2.9
var attack_range := 2.25
var damage := 9.0
var attack_cooldown := 1.0
var ranged := false
var scale_value := 1.0
var target_house = null
var target_squad = null
var target_member_index := -1

var _visual: MeshInstance3D
var _bar_root: Node3D
var _bar_fill: MeshInstance3D
var _cooldown := 0.0
var _hit_timer := 0.0
var _lunge := 0.0
var _bob_phase := 0.0
var _heading := 0.0
var _path := PackedVector3Array()
var _path_index := 0
var _repath_timer := 0.0
var _stuck_timer := 0.0
var _last_pos := Vector3.ZERO


func configure(game_ref, type_name: String, spawn_pos: Vector3, variant := 0) -> void:
	game = game_ref
	type_id = type_name
	data = Balance.enemy_type(type_id)
	hp = float(data["hp"])
	max_hp = hp
	class_id = str(data["class_id"])
	speed = float(data["speed"])
	attack_range = float(data["range"])
	damage = float(data["damage"])
	attack_cooldown = float(data["cooldown"])
	ranged = bool(data["ranged"])
	scale_value = float(data["scale"])
	alive = true
	position = spawn_pos
	_last_pos = spawn_pos
	_cooldown = randf_range(0.15, 0.8)
	name = "Enemy_%s" % type_id

	_visual = MeshInstance3D.new()
	_visual.name = "Visual"
	_visual.mesh = Models.enemy_mesh(type_id, variant % 3)
	_visual.material_override = Models.unit_material()
	_visual.scale = Vector3.ONE * scale_value
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_visual)

	_build_bar()
	_retarget_house(true)
	_heading = atan2(-(-spawn_pos.x), -(-spawn_pos.z))
	rotation.y = _heading


func _build_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.name = "HealthBar"
	_bar_root.position = Vector3(0, 2.15 * scale_value, 0)
	add_child(_bar_root)
	var back := _bar_quad(Vector2(0.92, 0.11), Color(0.06, 0.09, 0.09, 0.8))
	back.position.z = 0.01
	_bar_root.add_child(back)
	_bar_fill = _bar_quad(Vector2(0.86, 0.07), Color("d96a55"))
	_bar_fill.position.z = 0.02
	_bar_root.add_child(_bar_fill)
	_bar_root.visible = false


func _bar_quad(size: Vector2, color: Color) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var node := MeshInstance3D.new()
	node.mesh = quad
	var mat := Models.bar_material(color)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _retarget_house(force := false) -> void:
	if game == null or game.island == null:
		return
	var next_house = game.island.get_nearest_house(global_position)
	if force or next_house != target_house or target_house == null or target_house.destroyed:
		target_house = next_house
		_repath_timer = 0.0
		if target_house != null:
			_path = game.island.find_path(global_position, target_house.global_position)
			_path_index = 0
			if _path.size() > 1:
				_path_index = 1
		else:
			_path = PackedVector3Array()


func simulate(dt: float) -> void:
	if not alive:
		return
	if game == null or game.island == null:
		return
	_cooldown -= dt
	_hit_timer = maxf(0.0, _hit_timer - dt)
	_lunge = maxf(0.0, _lunge - dt)
	_repath_timer += dt
	if target_house == null or target_house.destroyed:
		_retarget_house(true)

	var player_target = _acquire_player_target()
	var moved := false
	if player_target.size() > 0:
		var tpos: Vector3 = player_target["pos"]
		var dist := Vector2(tpos.x - global_position.x, tpos.z - global_position.z).length()
		target_squad = player_target["squad"]
		target_member_index = int(player_target["index"])
		if dist <= attack_range:
			_face_toward(tpos, dt)
			_try_attack_player(dt, player_target)
		else:
			_face_toward(tpos, dt)
			moved = _move_direct(tpos, dt)
	else:
		target_squad = null
		target_member_index = -1
		if target_house != null:
			var house_pos: Vector3 = target_house.global_position
			var house_dist := Vector2(house_pos.x - global_position.x, house_pos.z - global_position.z).length()
			if house_dist <= 3.15:
				_face_toward(house_pos, dt)
				_try_attack_house(dt)
			else:
				_follow_house_path(dt)
				moved = true
	var new_pos := Vector3(global_position.x, game.island.height_at(global_position.x, global_position.z), global_position.z)
	global_position = new_pos
	if moved:
		var delta_pos := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
		if delta_pos < speed * dt * 0.2:
			_stuck_timer += dt
			if _stuck_timer > 2.6:
				_retarget_house(true)
				_stuck_timer = 0.0
		else:
			_stuck_timer = 0.0
		_last_pos = global_position
		_bob_phase += dt * speed * 2.4
	else:
		_bob_phase += dt * 0.8

	_update_visuals()
	_update_bar()


func _acquire_player_target() -> Dictionary:
	if game == null:
		return {}
	var radius := 12.0 if ranged else 7.3
	return game.find_nearest_player_member(global_position, radius)


func _follow_house_path(dt: float) -> void:
	if target_house == null:
		return
	if _path.is_empty():
		_retarget_house(true)
	var moved := false
	if _path_index < _path.size():
		var wp: Vector3 = _path[_path_index]
		var flat := Vector3(wp.x - global_position.x, 0.0, wp.z - global_position.z)
		var dist := flat.length()
		var step := speed * dt
		if dist <= maxf(step, 0.2):
			_path_index += 1
		else:
			moved = _move_direct(wp, dt)
		if _path_index >= _path.size():
			_path_index = _path.size()
	if not moved:
		var hp: Vector3 = target_house.global_position
		var d := Vector2(hp.x - global_position.x, hp.z - global_position.z).length()
		if d > 2.9:
			_face_toward(hp, dt)
			_move_direct(hp, dt)
		else:
			_face_toward(hp, dt)


func _move_direct(goal: Vector3, dt: float) -> bool:
	var flat := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	var dist := flat.length()
	if dist < 0.05:
		return false
	var dir := flat / dist
	var step := minf(speed * dt, dist)
	var candidate := global_position + dir * step
	if game.island.is_terrain_walkable(candidate.x, candidate.z):
		global_position = Vector3(candidate.x, game.island.height_at(candidate.x, candidate.z), candidate.z)
		_face_toward(goal, dt)
		return true
	# 沿地形边缘滑动
	var slide_x := Vector3(global_position.x + dir.x * step, 0.0, global_position.z)
	if game.island.is_terrain_walkable(slide_x.x, slide_x.z):
		global_position = Vector3(slide_x.x, game.island.height_at(slide_x.x, slide_x.z), slide_x.z)
		_face_toward(goal, dt)
		return true
	var slide_z := Vector3(global_position.x, 0.0, global_position.z + dir.z * step)
	if game.island.is_terrain_walkable(slide_z.x, slide_z.z):
		global_position = Vector3(slide_z.x, game.island.height_at(slide_z.x, slide_z.z), slide_z.z)
		_face_toward(goal, dt)
		return true
	return false


func _face_toward(target: Vector3, dt: float) -> void:
	var d := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if d.length_squared() < 0.0001:
		return
	var desired := atan2(-d.x, -d.z)
	_heading = lerp_angle(_heading, desired, clampf(dt * 8.0, 0.0, 1.0))
	rotation.y = _heading


func _try_attack_player(dt: float, target: Dictionary) -> void:
	if _cooldown > 0.0:
		return
	var squad = target["squad"]
	var index := int(target["index"])
	if squad == null or not squad.alive:
		return
	_cooldown = attack_cooldown * randf_range(0.94, 1.06)
	_lunge = 0.2
	if ranged:
		game.spawn_projectile(
			"enemy", "axe", global_position + Vector3(0, 1.15 * scale_value, 0),
			null, "member", squad, index, class_id, damage,
			global_position.y, float(data["projectile_speed"])
		)
	else:
		game.damage_member(squad, index, damage, class_id, global_position, false, type_id)
		game.fx.slash(global_position + Vector3(0, 1.0, 0), squad.get_member_position(index), Color("d96a55"))
		game.fx.hit(squad.get_member_position(index) + Vector3(0, 0.9, 0), Color("d96a55"))


func _try_attack_house(dt: float) -> void:
	if _cooldown > 0.0 or target_house == null or target_house.destroyed:
		return
	_cooldown = attack_cooldown * randf_range(0.94, 1.06)
	_lunge = 0.2
	var amount := damage * float(data["house_mult"])
	target_house.take_damage(amount, global_position)
	game.fx.hit(target_house.global_position + Vector3(randf_range(-1, 1), 1.2, randf_range(-1, 1)), Color("ff9d4f"))
	if target_house.destroyed:
		_retarget_house(true)


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp = maxf(0.0, hp - maxf(0.0, amount))
	_hit_timer = 0.14
	_bar_root.visible = true
	_update_bar()
	if hp <= 0.0:
		alive = false
		_bar_root.visible = false
		_visual.visible = false
		if game != null:
			game.on_enemy_died(self)


func _update_visuals() -> void:
	if _visual == null:
		return
	var lunge := _lunge / 0.2
	_visual.position = Vector3(0, absf(sin(_bob_phase)) * 0.045, -lunge * 0.34)
	_visual.rotation.y = sin(_bob_phase * 0.5) * 0.025
	var hit_pulse := 1.0 + 0.06 * clampf(_hit_timer / 0.14, 0.0, 1.0)
	_visual.scale = Vector3.ONE * scale_value * hit_pulse


func _update_bar() -> void:
	if _bar_root == null:
		return
	_bar_root.visible = hp < max_hp and alive
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_bar_fill.scale.x = maxf(0.001, ratio)
	_bar_fill.position.x = -0.43 * (1.0 - ratio)
	var mat := _bar_fill.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = Color("e0bd74").lerp(Color("d96a55"), 1.0 - ratio)
	_bar_root.position.y = 2.15 * scale_value + absf(sin(_bob_phase)) * 0.045


func attack_origin() -> Vector3:
	return global_position + Vector3(0, 1.0 * scale_value, 0)
