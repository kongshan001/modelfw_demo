class_name MistBoat
extends Node3D
## 登陆艇：延迟出发 → 靠岸 → 逐个投放海掠者 → 撤离。波次清空条件包含所有登陆艇。

const Models = preload("res://scripts/models.gd")
const Balance = preload("res://scripts/balance.gd")

var game
var landing: Dictionary
var loadout: Array = []
var delay := 0.0
var state := "wait"
var timer := 0.0
var travel_t := 0.0
var spawn_index := 0
var spawn_timer := 0.0
var done := false
var _start_pos := Vector3.ZERO
var _shore_pos := Vector3.ZERO
var _outward := Vector3.ZERO
var _wake_mat: StandardMaterial3D
var _bob := 0.0


func configure(game_ref, landing_data: Dictionary, types: Array, start_delay: float, variant := 0) -> void:
	game = game_ref
	landing = landing_data
	loadout = types.duplicate()
	delay = maxf(0.0, start_delay)
	_outward = landing["outward"]
	var side := _outward.cross(Vector3.UP).normalized()
	var side_offset := side * (3.0 if variant % 2 == 0 else -3.0)
	_start_pos = landing["boat"] + side_offset
	_shore_pos = landing["shore"] + side_offset
	position = _start_pos
	_bob = randf() * TAU
	name = "Boat"

	var mesh := MeshInstance3D.new()
	mesh.mesh = Models.boat_mesh(variant % 2)
	mesh.material_override = Models.unit_material()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh)
	_face_toward_shore()

	var wake := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.2, 8.0)
	wake.mesh = quad
	wake.rotation_degrees.x = -90.0
	wake.position = Vector3(0, -0.32, 4.8)
	_wake_mat = StandardMaterial3D.new()
	_wake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wake_mat.albedo_color = Color(0.85, 0.92, 0.9, 0.16)
	_wake_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wake.material_override = _wake_mat
	wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wake)


func remaining_count() -> int:
	return maxi(0, loadout.size() - spawn_index)


func simulate(dt: float) -> void:
	if done:
		return
	_bob += dt * 1.6
	match state:
		"wait":
			timer += dt
			_float_bob()
			if timer >= delay:
				state = "sail"
				timer = 0.0
		"sail":
			timer += dt
			travel_t = clampf(timer / Balance.BOAT_TRAVEL, 0.0, 1.0)
			var eased := ease(travel_t, 0.35)
			var p := _start_pos.lerp(_shore_pos, eased)
			position = Vector3(p.x, Balance.WATER_LEVEL + 0.30 + sin(_bob) * 0.055, p.z)
			_face_toward_shore()
			if travel_t >= 1.0:
				state = "disembark"
				timer = 0.0
				spawn_timer = 0.0
		"disembark":
			_float_bob()
			spawn_timer += dt
			if spawn_timer >= Balance.DISEMBARK_INTERVAL and spawn_index < loadout.size():
				_spawn_one()
				spawn_timer = 0.0
			if spawn_index >= loadout.size() and spawn_timer > 0.9:
				state = "leave"
				timer = 0.0
				if _wake_mat != null:
					_wake_mat.albedo_color = Color(0.85, 0.92, 0.9, 0.10)
		"leave":
			timer += dt
			var p := position + _outward * dt * 3.2
			position = Vector3(p.x, Balance.WATER_LEVEL + 0.30 + sin(_bob) * 0.06, p.z)
			if _outward.length_squared() > 0.001:
				look_at(Vector3(position.x + _outward.x, position.y, position.z + _outward.z), Vector3.UP)
			if timer >= 3.0:
				done = true
				if game != null:
					game.on_boat_finished(self)
				queue_free()


func _float_bob() -> void:
	position = Vector3(position.x, Balance.WATER_LEVEL + 0.30 + sin(_bob) * 0.055, position.z)


func _face_toward_shore() -> void:
	var flat := Vector2(_shore_pos.x - position.x, _shore_pos.z - position.z)
	if flat.length() > 0.15:
		look_at(Vector3(_shore_pos.x, position.y, _shore_pos.z), Vector3.UP)


func _spawn_one() -> void:
	if game == null or spawn_index >= loadout.size():
		return
	var type_id := str(loadout[spawn_index])
	spawn_index += 1
	var pos: Vector3 = landing["pos"]
	var inward := -_outward
	var side := _outward.cross(Vector3.UP).normalized()
	var offset := inward * randf_range(0.2, 1.6) + side * randf_range(-1.2, 1.2)
	pos += offset
	pos = game.island.clamp_to_walkable(pos)
	pos.y += 0.03
	game.spawn_enemy(type_id, pos)
