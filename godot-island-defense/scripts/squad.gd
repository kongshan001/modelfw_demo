class_name MistSquad
extends Node3D
## 玩家小队：4 人一组、编队移动、自动索敌；成员阵亡永久减员，全队阵亡则本岛不可复活。

const Balance = preload("res://scripts/balance.gd")
const Models = preload("res://scripts/models.gd")
const UI = preload("res://scripts/ui_style.gd")

const SLOTS := [
	Vector3(-0.72, 0.0, -0.55),
	Vector3(0.72, 0.0, -0.55),
	Vector3(-0.72, 0.0, 0.55),
	Vector3(0.72, 0.0, 0.55),
]

var game
var squad_index := 0
var class_id := "shield"
var data: Dictionary
var members: Array = []
var alive := true
var center := Vector3.ZERO
var heading := 0.0
var moving := false
var path := PackedVector3Array()
var path_index := 0
var move_target := Vector3.ZERO
var selected := false
var hovered := false

var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _range_ring: MeshInstance3D
var _range_mat: StandardMaterial3D
var _banner: Node3D
var _bob_time := 0.0
var _look_target := Vector3.ZERO
var _repath_timer := 0.0


func configure(game_ref, index: int, class_name_id: String, spawn_pos: Vector3, member_count := Balance.SQUAD_SIZE) -> void:
	game = game_ref
	squad_index = index
	class_id = class_name_id
	data = Balance.player_class(class_id)
	name = "Squad_%d_%s" % [index, class_id]
	center = spawn_pos
	position = center
	var toward_center := Vector3(-center.x, 0.0, -center.z).normalized()
	heading = atan2(-toward_center.x, -toward_center.z)
	rotation.y = heading
	alive = true
	selected = false
	moving = false
	path = PackedVector3Array()
	path_index = 0
	_look_target = center

	members.clear()
	for i in range(member_count):
		var mesh := MeshInstance3D.new()
		mesh.name = "Member%d" % i
		mesh.mesh = Models.soldier_mesh(class_id, i % 4)
		mesh.material_override = Models.unit_material()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mesh)
		var blob := Models.make_disc(0.46, Color(0.06, 0.10, 0.075), 0.28)
		blob.name = "Shadow%d" % i
		add_child(blob)
		members.append({
			"mesh": mesh,
			"shadow": blob,
			"hp": float(data["hp"]),
			"max_hp": float(data["hp"]),
			"alive": true,
			"cooldown": randf_range(0.05, 0.45),
			"hit_timer": 0.0,
			"lunge": 0.0,
			"phase": randf() * TAU,
		})

	_ring = Models.make_ring(Color(data["color"]), 0.72, 0.96, 0.9)
	_ring.name = "SelectionRing"
	_ring.position.y = 0.06
	_ring.visible = false
	add_child(_ring)
	_ring_mat = _ring.material_override

	_range_ring = Models.make_ring(Color(data["color"]), 0.992, 1.0, 0.14)
	_range_ring.name = "RangeRing"
	_range_ring.position.y = 0.07
	_range_ring.scale = Vector3(float(data["range"]), 1.0, float(data["range"]))
	_range_ring.visible = false
	add_child(_range_ring)
	_range_mat = _range_ring.material_override

	_build_banner()
	_apply_member_transforms(0.0)


func _build_banner() -> void:
	_banner = Node3D.new()
	_banner.name = "Banner"
	_banner.position = Vector3(0.34, 0.0, 0.3)
	var pole := MeshInstance3D.new()
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.055, 2.3, 0.055)
	pole.mesh = pole_mesh
	var pole_mat := StandardMaterial3D.new()
	pole_mat.vertex_color_use_as_albedo = true
	pole_mat.albedo_color = Color("6b4f37")
	pole.material_override = pole_mat
	pole.position.y = 1.15
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_banner.add_child(pole)
	var cloth := MeshInstance3D.new()
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(0.62, 0.38, 0.035)
	cloth.mesh = cloth_mesh
	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.vertex_color_use_as_albedo = true
	cloth_mat.albedo_color = Color(data["color"])
	cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.material_override = cloth_mat
	cloth.position = Vector3(0.33, 2.05, 0.0)
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_banner.add_child(cloth)
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.06, 0.12, 0.06)
	tip.mesh = tip_mesh
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color("e0bd74")
	tip_mat.vertex_color_use_as_albedo = true
	tip.material_override = tip_mat
	tip.position.y = 2.36
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_banner.add_child(tip)
	add_child(_banner)


func issue_move(island, target: Vector3) -> void:
	if not alive or island == null:
		return
	var goal: Vector3 = island.clamp_to_walkable(target)
	move_target = goal
	path = island.find_path(center, goal)
	path_index = 0
	moving = path.size() > 0
	if path.size() > 1 and Vector2(path[0].x, path[0].z).distance_to(Vector2(center.x, center.z)) < 1.0:
		path_index = 1
	if path.size() <= 1 and Vector2(goal.x, goal.z).distance_to(Vector2(center.x, center.z)) < 0.5:
		moving = false
	_repath_timer = 0.0


func simulate(dt: float) -> void:
	if not alive:
		return
	if game == null or game.island == null:
		return
	_repath_timer += dt
	var speed := float(data["speed"])
	var move_dir := Vector3.ZERO
	if moving and path.size() > 0:
		if path_index >= path.size():
			moving = false
		else:
			var target: Vector3 = path[path_index]
			var flat := Vector3(target.x - center.x, 0.0, target.z - center.z)
			var dist := flat.length()
			var step := speed * dt
			if dist <= maxf(step, 0.22):
				center.x = target.x
				center.z = target.z
				path_index += 1
				if path_index >= path.size():
					moving = false
			else:
				move_dir = flat / dist
				center += move_dir * step
			center.y = game.island.height_at(center.x, center.z)
			position = center
			if move_dir.length_squared() > 0.001:
				var desired := atan2(-move_dir.x, -move_dir.z)
				heading = _lerp_angle_rad(heading, desired, clampf(dt * 8.0, 0.0, 1.0))
				rotation.y = heading
			_bob_time += dt * speed * 2.2

	var engaged := false
	for i in range(members.size()):
		var member: Dictionary = members[i]
		if not bool(member["alive"]):
			continue
		member["cooldown"] = float(member["cooldown"]) - dt
		member["hit_timer"] = maxf(0.0, float(member["hit_timer"]) - dt)
		member["lunge"] = maxf(0.0, float(member["lunge"]) - dt)
		var world_pos := get_member_position(i)
		if world_pos == Vector3.ZERO or game.state != "playing":
			continue
		if float(member["cooldown"]) <= 0.0:
			var target_enemy = game.find_nearest_enemy(world_pos, float(data["range"]))
			if target_enemy != null:
				engaged = true
				_look_target = target_enemy.global_position
				_attack_enemy(member, target_enemy, world_pos)
				member["cooldown"] = randf_range(float(data["cooldown"]) * 0.92, float(data["cooldown"]) * 1.08)

	if not moving and engaged and _look_target != Vector3.ZERO:
		var d := Vector3(_look_target.x - center.x, 0.0, _look_target.z - center.z)
		if d.length_squared() > 0.001:
			var desired := atan2(-d.x, -d.z)
			heading = _lerp_angle_rad(heading, desired, clampf(dt * 6.0, 0.0, 1.0))
			rotation.y = heading

	_apply_member_transforms(dt)
	if _ring != null:
		_ring.position.y = 0.07
		_refresh_ring()


func _attack_enemy(member: Dictionary, enemy, origin: Vector3) -> void:
	member["lunge"] = 0.2
	var dmg := float(data["damage"])
	if bool(data["ranged"]):
		game.spawn_projectile(
			"player", "arrow", origin, enemy, "enemy", null, -1,
			class_id, dmg, origin.y, float(data["projectile_speed"])
		)
	else:
		game.damage_enemy(enemy, dmg, class_id, origin, false)
		game.fx.slash(origin + Vector3(0, 0.8, 0), enemy.global_position, Color(data["color"]))
		game.fx.hit(enemy.global_position + Vector3(0, 0.9, 0), Color("f0d49a"))


func _apply_member_transforms(dt: float) -> void:
	var playing: bool = game != null and game.state == "playing"
	for i in range(members.size()):
		var member: Dictionary = members[i]
		var mesh: MeshInstance3D = member["mesh"]
		var blob: MeshInstance3D = member["shadow"]
		if not bool(member["alive"]):
			mesh.visible = false
			blob.visible = false
			continue
		mesh.visible = true
		blob.visible = true
		var slot: Vector3 = SLOTS[i % SLOTS.size()]
		var world_xz := Vector3(slot.x, 0.0, slot.z).rotated(Vector3.UP, heading) + center
		var local := slot
		var ground_y := 0.0
		if game != null and game.island != null:
			if not game.island.is_terrain_walkable(world_xz.x, world_xz.z):
				local.x = 0.0
				local.z = 0.0
				world_xz = center
			ground_y = game.island.height_at(world_xz.x, world_xz.z) - center.y
			local.y = ground_y
		else:
			local.y = 0.0
		blob.position = Vector3(local.x, ground_y + 0.035, local.z)
		if moving and playing:
			local.y += absf(sin(_bob_time + float(member["phase"]))) * 0.055
		var lunge := float(member["lunge"])
		if lunge > 0.0:
			var ratio := lunge / 0.2
			local.z -= ratio * 0.38
			local.y += ratio * 0.06
		var target_scale := Vector3.ONE
		if float(member["hit_timer"]) > 0.0:
			target_scale = Vector3(1.06, 0.96, 1.06)
		mesh.position = local
		mesh.scale = mesh.scale.lerp(target_scale, 0.35)
		mesh.rotation.y = sin(float(member["phase"])) * 0.04


func get_member_position(index: int) -> Vector3:
	if index < 0 or index >= members.size():
		return Vector3.ZERO
	var member: Dictionary = members[index]
	if not bool(member["alive"]) or not is_inside_tree():
		return Vector3.ZERO
	var mesh: MeshInstance3D = member["mesh"]
	return mesh.global_position


func get_member_ground_position(index: int) -> Vector3:
	var p := get_member_position(index)
	if p == Vector3.ZERO:
		return Vector3.ZERO
	return Vector3(p.x, position.y, p.z)


func take_member_damage(index: int, amount: float) -> void:
	if not alive or index < 0 or index >= members.size():
		return
	var member: Dictionary = members[index]
	if not bool(member["alive"]):
		return
	var before := float(member["hp"])
	member["hp"] = maxf(0.0, before - maxf(0.0, amount))
	member["hit_timer"] = 0.14
	if float(member["hp"]) <= 0.0:
		member["alive"] = false
		member["mesh"].visible = false
		if member.has("shadow") and member["shadow"] != null:
			member["shadow"].visible = false
		if game != null:
			game.on_member_died(self, index)
			game.fx.death(get_member_ground_position(index) + Vector3(0, 0.7, 0), Color(data["color"]))
		_check_wiped()


func _check_wiped() -> void:
	for member in members:
		if bool(member["alive"]):
			return
	alive = false
	selected = false
	moving = false
	path = PackedVector3Array()
	if _ring != null:
		_ring.visible = false
	if _range_ring != null:
		_range_ring.visible = false
	if _banner != null:
		_banner.visible = false
	if game != null:
		game.on_squad_wiped(self)


func living_count() -> int:
	var n := 0
	for member in members:
		if bool(member["alive"]):
			n += 1
	return n


func hp_ratio() -> float:
	var total := 0.0
	var max_total := 0.0
	for member in members:
		max_total += float(member["max_hp"])
		total += float(member["hp"])
	return clampf(total / maxf(1.0, max_total), 0.0, 1.0)


func hp_value() -> String:
	var total := 0.0
	var max_total := 0.0
	for member in members:
		max_total += float(member["max_hp"])
		total += float(member["hp"])
	return "%d / %d" % [int(ceil(total)), int(max_total)]


func set_selected(value: bool) -> void:
	selected = value
	_refresh_ring()


func set_hovered(value: bool) -> void:
	hovered = value
	_refresh_ring()


func _refresh_ring() -> void:
	if _ring == null or _ring_mat == null:
		return
	_ring.visible = (selected or hovered) and alive
	if selected:
		var c := Color(data["color"])
		_ring_mat.albedo_color = Color(c.r, c.g, c.b, 0.95)
	elif hovered:
		_ring_mat.albedo_color = Color(0.9, 0.9, 0.82, 0.55)
	if _range_ring != null:
		_range_ring.visible = selected and alive
		_range_mat.albedo_color = Color(Color(data["color"]).r, Color(data["color"]).g, Color(data["color"]).b, 0.13)


func refill_members() -> void:
	alive = true
	selected = false
	hovered = false
	moving = false
	path = PackedVector3Array()
	path_index = 0
	for i in range(members.size()):
		var member: Dictionary = members[i]
		member["hp"] = float(member["max_hp"])
		member["alive"] = true
		member["cooldown"] = randf_range(0.1, 0.5)
		member["hit_timer"] = 0.0
		member["lunge"] = 0.0
		member["mesh"].visible = true
		member["shadow"].visible = true
	if _banner != null:
		_banner.visible = true
	if _ring != null:
		_ring.visible = false


func teleport(spawn_pos: Vector3) -> void:
	center = spawn_pos
	position = center
	path = PackedVector3Array()
	path_index = 0
	moving = false
	for i in range(members.size()):
		var member: Dictionary = members[i]
		member["hit_timer"] = 0.0
		member["lunge"] = 0.0
	_apply_member_transforms(0.0)


func member_screen_positions(cam: Camera3D) -> Array:
	var out: Array = []
	for i in range(members.size()):
		if not bool(members[i]["alive"]):
			continue
		var p := get_member_position(i)
		if p != Vector3.ZERO:
			out.append(cam.unproject_position(p + Vector3(0, 0.8, 0)))
	return out


func screen_center(cam: Camera3D) -> Vector2:
	return cam.unproject_position(center + Vector3(0, 0.6, 0))


func _lerp_angle_rad(from: float, to: float, weight: float) -> float:
	return lerp_angle(from, to, weight)
