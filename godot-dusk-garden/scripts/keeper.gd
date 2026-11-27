extends CharacterBody3D

# 原创角色「苔灯」：提灯的守园学徒。
# 宽檐草帽 + 墨绿工作披风 + 锈橙围巾 + 铜灯笼手杖，刻意与参考视频里的红裙金发小女孩区分。
# 全部由低模图元程序化搭建；行走/待机由脚本驱动，无外部动画资产。

const TOON_SHADER := preload("res://shaders/garden_toon.gdshader")

const COAT := Color(0.30, 0.42, 0.36)
const COAT_DARK := Color(0.20, 0.29, 0.26)
const SCARF := Color(0.74, 0.33, 0.20)
const SKIN := Color(0.88, 0.68, 0.50)
const HAIR := Color(0.16, 0.13, 0.11)
const HAT := Color(0.40, 0.32, 0.18)
const HAT_BAND := Color(0.55, 0.25, 0.15)
const TROUSER := Color(0.20, 0.21, 0.24)
const BOOT := Color(0.30, 0.22, 0.15)
const COPPER := Color(0.55, 0.32, 0.16)
const METAL_DARK := Color(0.17, 0.18, 0.18)
const LEATHER := Color(0.38, 0.26, 0.16)
const GLASS_WARM := Color(1.0, 0.76, 0.40)

const WALK_SPEED := 2.15
const RUN_SPEED := 3.85
const ACCEL := 13.0

var move_dir_test := Vector3.ZERO
var move_target := Vector3.ZERO
var has_move_target := false
var running := false
var speed_current := 0.0
var walk_phase := 0.0
var idle_time := 0.0
var preview_walk := false
var preview_phase := 0.0
var lantern_energy_target := 0.7

var _visual: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _head_group: Node3D
var _body: Node3D
var _staff: Node3D
var _lantern_pivot: Node3D
var _lantern_light: OmniLight3D
var _lantern_glass_mat: StandardMaterial3D
var _lantern_glow_mat: StandardMaterial3D
var _ground_pool_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _last_dir := Vector3(0, 0, -1)
var _anim_t := 0.0


func _ready() -> void:
	_rng.seed = 20261127
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.35
	up_direction = Vector3.UP
	_build_body()
	_build_visual()
	_apply_pose(0.0, false)


func _build_body() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.26
	shape.height = 1.15
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.62, 0)
	add_child(col)


# ── 建造角色 ───────────────────────────────────────────────────────────
func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	# 地面接触阴影（灯光无阴影时的可读性补强）。
	var blob := MeshInstance3D.new()
	blob.name = "ContactShadow"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.05, 1.05)
	blob.mesh = quad
	blob.rotation_degrees.x = -90.0
	blob.position = Vector3(0, 0.04, 0)
	var blob_mat := StandardMaterial3D.new()
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.albedo_texture = _make_glow_texture(32, 1.8)
	blob_mat.albedo_color = Color(0.02, 0.03, 0.03, 0.42)
	blob_mat.disable_receive_shadows = true
	blob_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	blob.material_override = blob_mat
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(blob)

	# 提灯地面光池：加色贴地，替代过强的点光近场（避免杖身/手被照爆）。
	var pool_mesh := PlaneMesh.new()
	pool_mesh.size = Vector2(2.6, 2.6)
	var pool := MeshInstance3D.new()
	pool.name = "LanternPool"
	pool.mesh = pool_mesh
	pool.position = Vector3(0, 0.082, 0)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_ground_pool_mat = StandardMaterial3D.new()
	_ground_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ground_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ground_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ground_pool_mat.albedo_texture = _make_glow_texture(32, 1.9)
	_ground_pool_mat.albedo_color = Color(1.0, 0.66, 0.32, 0.0)
	_ground_pool_mat.disable_receive_shadows = true
	_ground_pool_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pool.material_override = _ground_pool_mat
	add_child(pool)

	var mat_coat := _toon(COAT, 0.09)
	var mat_coat_dark := _toon(COAT_DARK, 0.07)
	var mat_scarf := _toon(SCARF, 0.08)
	var mat_skin := _toon(SKIN, 0.05)
	var mat_hair := _toon(HAIR, 0.06)
	var mat_hat := _toon(HAT, 0.06)
	var mat_hat_band := _toon(HAT_BAND, 0.06)
	var mat_trouser := _toon(TROUSER, 0.05)
	var mat_boot := _toon(BOOT, 0.05)
	var mat_copper := _toon(COPPER, 0.12)
	var mat_dark := _toon(METAL_DARK, 0.10)
	var mat_leather := _toon(LEATHER, 0.06)

	# 躯干 / 外衣 / 披肩 / 围巾
	_body = Node3D.new()
	_body.name = "Body"
	_visual.add_child(_body)
	_add_mesh(_body, _cyl(0.17, 0.235, 0.44, 8), mat_coat, Vector3(0, 0.60, 0))
	_add_mesh(_body, _cyl(0.22, 0.30, 0.20, 8), mat_coat_dark, Vector3(0, 0.46, 0))
	_add_mesh(_body, _cyl(0.10, 0.29, 0.24, 8), mat_coat_dark, Vector3(0, 0.82, 0))
	_add_mesh(_body, _cyl(0.155, 0.16, 0.075, 8), mat_scarf, Vector3(0, 0.865, 0))
	# 围巾垂尾
	_add_mesh(_body, _box(0.085, 0.20, 0.04), mat_scarf, Vector3(0.10, 0.76, -0.15), Vector3(8, 12, -6))
	# 斜挎包 + 背卷
	_add_mesh(_body, _box(0.16, 0.18, 0.075), mat_leather, Vector3(0.205, 0.53, 0.075), Vector3(0, -18, 10))
	_add_mesh(_body, _cyl(0.075, 0.075, 0.30, 7), mat_coat_dark, Vector3(-0.06, 0.68, 0.19), Vector3(0, 0, 90))
	_add_mesh(_body, _box(0.035, 0.42, 0.018), mat_leather, Vector3(0.06, 0.66, -0.155), Vector3(0, 0, 28))

	# 腿
	_leg_l = Node3D.new()
	_leg_l.position = Vector3(-0.105, 0.40, 0)
	_visual.add_child(_leg_l)
	_add_mesh(_leg_l, _cyl(0.058, 0.07, 0.34, 6), mat_trouser, Vector3(0, -0.17, 0))
	_add_mesh(_leg_l, _box(0.11, 0.10, 0.17), mat_boot, Vector3(0, -0.35, -0.025))
	_leg_r = Node3D.new()
	_leg_r.position = Vector3(0.105, 0.40, 0)
	_visual.add_child(_leg_r)
	_add_mesh(_leg_r, _cyl(0.058, 0.07, 0.34, 6), mat_trouser, Vector3(0, -0.17, 0))
	_add_mesh(_leg_r, _box(0.11, 0.10, 0.17), mat_boot, Vector3(0, -0.35, -0.025))

	# 手臂
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.225, 0.80, 0)
	_arm_l.rotation_degrees.z = 8.0
	_visual.add_child(_arm_l)
	_add_mesh(_arm_l, _cyl(0.047, 0.055, 0.32, 6), mat_coat, Vector3(0, -0.16, 0))
	_add_mesh(_arm_l, _sphere(0.052, 6, 4), mat_skin, Vector3(0, -0.33, 0))
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.225, 0.80, 0)
	_arm_r.rotation_degrees.z = -8.0
	_visual.add_child(_arm_r)
	_add_mesh(_arm_r, _cyl(0.047, 0.055, 0.32, 6), mat_coat, Vector3(0, -0.16, 0))
	_add_mesh(_arm_r, _sphere(0.052, 6, 4), mat_skin, Vector3(0, -0.33, 0))

	# 灯笼手杖：挂在右手，杖顶铜灯笼 + 点光 + 加色辉光。
	_staff = Node3D.new()
	_staff.name = "Staff"
	_staff.position = Vector3(0.02, -0.33, -0.04)
	_staff.rotation_degrees.z = 3.0
	_arm_r.add_child(_staff)
	_add_mesh(_staff, _cyl(0.017, 0.022, 0.78, 6), mat_leather, Vector3(0, 0.18, 0))
	_add_mesh(_staff, _sphere(0.030, 6, 4), mat_copper, Vector3(0, 0.575, 0))
	_add_mesh(_staff, _box(0.11, 0.022, 0.022), mat_copper, Vector3(0.045, 0.555, 0))
	# 挂钩
	_add_mesh(_staff, _cyl(0.008, 0.008, 0.09, 5), mat_copper, Vector3(0.095, 0.505, 0))

	_lantern_pivot = Node3D.new()
	_lantern_pivot.name = "LanternPivot"
	_lantern_pivot.position = Vector3(0.095, 0.50, 0)
	_staff.add_child(_lantern_pivot)
	# 灯笼框架
	_add_mesh(_lantern_pivot, _box(0.16, 0.026, 0.16), mat_copper, Vector3(0, -0.015, 0))
	_add_mesh(_lantern_pivot, _box(0.13, 0.018, 0.13), mat_copper, Vector3(0, -0.235, 0))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_add_mesh(_lantern_pivot, _box(0.018, 0.22, 0.018), mat_copper,
				Vector3(sx * 0.07, -0.125, sz * 0.07))
	_add_mesh(_lantern_pivot, _cyl(0.02, 0.115, 0.09, 4), mat_dark, Vector3(0, -0.275, 0), Vector3(0, 45, 0))
	# 玻璃芯：独立材质，由外部控制亮度。
	_lantern_glass_mat = StandardMaterial3D.new()
	_lantern_glass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lantern_glass_mat.albedo_color = GLASS_WARM * 0.66
	_lantern_glass_mat.disable_receive_shadows = true
	var glass := _add_mesh(_lantern_pivot, _box(0.118, 0.19, 0.118), _lantern_glass_mat, Vector3(0, -0.13, 0))
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = Color(1.0, 0.72, 0.42)
	_lantern_light.light_energy = 0.30
	_lantern_light.omni_range = 2.8
	_lantern_light.omni_attenuation = 1.8
	_lantern_light.shadow_enabled = false
	_lantern_light.position = Vector3(0, -0.13, 0)
	_lantern_pivot.add_child(_lantern_light)

	var glow_quad := QuadMesh.new()
	glow_quad.size = Vector2(0.42, 0.42)
	var glow := MeshInstance3D.new()
	glow.mesh = glow_quad
	glow.position = Vector3(0, -0.13, 0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_lantern_glow_mat = StandardMaterial3D.new()
	_lantern_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lantern_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lantern_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_lantern_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_lantern_glow_mat.albedo_texture = _make_glow_texture(32, 2.2)
	_lantern_glow_mat.albedo_color = Color(1.0, 0.72, 0.38, 0.22)
	_lantern_glow_mat.disable_receive_shadows = true
	_lantern_glow_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glow.material_override = _lantern_glow_mat
	_lantern_pivot.add_child(glow)

	# 头 / 发 / 帽 / 五官
	_head_group = Node3D.new()
	_head_group.position = Vector3(0, 1.0, 0)
	_visual.add_child(_head_group)
	_add_mesh(_head_group, _sphere(0.16, 8, 5), mat_skin, Vector3(0, 0, 0))
	_add_mesh(_head_group, _sphere(0.172, 8, 4), mat_hair, Vector3(0, 0.028, 0.045), Vector3(0, 0, 0), Vector3(1.03, 0.95, 0.92))
	_add_mesh(_head_group, _box(0.20, 0.055, 0.06), mat_hair, Vector3(0, 0.105, -0.135), Vector3(8, 0, 0))
	_add_mesh(_head_group, _box(0.055, 0.12, 0.09), mat_hair, Vector3(-0.145, -0.005, 0.0))
	_add_mesh(_head_group, _box(0.055, 0.12, 0.09), mat_hair, Vector3(0.145, -0.005, 0.0))
	# 眼睛
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(0.06, 0.05, 0.045)
	_add_mesh(_head_group, _box(0.038, 0.050, 0.018), eye_mat, Vector3(-0.060, 0.008, -0.158))
	_add_mesh(_head_group, _box(0.038, 0.050, 0.018), eye_mat, Vector3(0.060, 0.008, -0.158))
	var mouth_mat := StandardMaterial3D.new()
	mouth_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mouth_mat.albedo_color = Color(0.42, 0.20, 0.18)
	_add_mesh(_head_group, _box(0.036, 0.012, 0.014), mouth_mat, Vector3(0, -0.058, -0.156))
	# 宽檐草帽
	_add_mesh(_head_group, _cyl(0.35, 0.36, 0.028, 12), mat_hat, Vector3(0, 0.158, 0), Vector3(6, 0, 0))
	_add_mesh(_head_group, _cyl(0.02, 0.325, 0.17, 12), mat_hat, Vector3(0, 0.248, 0), Vector3(6, 0, 0))
	_add_mesh(_head_group, _cyl(0.325, 0.335, 0.035, 12), mat_hat_band, Vector3(0, 0.19, 0), Vector3(6, 0, 0))
	# 帽穗
	_add_mesh(_head_group, _cyl(0.008, 0.012, 0.13, 5), mat_hat_band, Vector3(0.22, 0.152, -0.02), Vector3(6, 0, 28))

	# 角色挂灯的整体点光由主控按夜晚强度驱动；自身先给基础亮度。
	lantern_energy_target = 0.7


func _toon(color: Color, rim: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("rim_amount", rim)
	m.set_shader_parameter("rim_color", Color(0.86, 0.70, 0.50))
	m.set_shader_parameter("bands", 3.0)
	m.set_shader_parameter("grain_amount", 0.08)
	return m


func _cyl(top: float, bottom: float, height: float, seg: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = seg
	mesh.rings = 1
	return mesh


func _sphere(radius: float, seg: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = seg
	mesh.rings = rings
	return mesh


func _box(x: float, y: float, z: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(x, y, z)
	return mesh


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


func _make_glow_texture(size: int, power: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size - 1, size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c) / (size * 0.5)
			var a := pow(clampf(1.0 - d, 0.0, 1.0), power)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# ── 移动 / 动画 ────────────────────────────────────────────────────────
func set_move_dir(dir: Vector3) -> void:
	move_dir_test = dir


func walk_to(world_pos: Vector3) -> void:
	move_target = Vector3(world_pos.x, global_position.y, world_pos.z)
	has_move_target = true


func clear_move_target() -> void:
	has_move_target = false


func teleport(pos: Vector3, yaw: float = 0.0) -> void:
	global_position = Vector3(pos.x, pos.y, pos.z)
	velocity = Vector3.ZERO
	speed_current = 0.0
	has_move_target = false
	move_dir_test = Vector3.ZERO
	rotation.y = yaw
	_last_dir = Vector3(-sin(yaw), 0, -cos(yaw))


func set_walk_preview(active: bool, phase: float = 0.0) -> void:
	preview_walk = active
	preview_phase = phase


func get_lantern_position() -> Vector3:
	if _lantern_pivot == null:
		return global_position + Vector3(0, 1, 0)
	return _lantern_pivot.global_position


func get_head_position() -> Vector3:
	return global_position + Vector3(0, 1.15, 0)


func set_lantern_energy(value: float) -> void:
	lantern_energy_target = value


func set_paused(value: bool) -> void:
	set_physics_process(not value)


func _physics_process(delta: float) -> void:
	_anim_t += delta
	var keyboard_dir := Vector3.ZERO
	if move_dir_test.length_squared() > 0.0001:
		keyboard_dir = move_dir_test
	else:
		keyboard_dir = _read_keyboard()
	var desired := Vector3.ZERO
	if keyboard_dir.length_squared() > 0.0001:
		desired = keyboard_dir.normalized()
		has_move_target = false
	elif has_move_target:
		var to := move_target - global_position
		to.y = 0.0
		if to.length() < 0.14:
			has_move_target = false
		else:
			desired = to.normalized()

	var target_speed := 0.0
	if desired.length_squared() > 0.001:
		target_speed = RUN_SPEED if running else WALK_SPEED
	speed_current = move_toward(speed_current, target_speed, ACCEL * delta)
	var vel := desired * speed_current
	velocity.x = vel.x
	velocity.z = vel.z
	if is_on_floor():
		velocity.y = -0.15
	else:
		velocity.y -= 18.0 * delta
	move_and_slide()

	if desired.length_squared() > 0.001:
		_last_dir = desired
		var target_yaw := atan2(-desired.x, -desired.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 11.0, 0.0, 1.0))

	var moving := speed_current > 0.18
	if moving:
		walk_phase += delta * (2.6 + speed_current * 2.1)
	else:
		idle_time += delta
		walk_phase = lerpf(walk_phase, round(walk_phase / PI) * PI, clampf(delta * 5.0, 0.0, 1.0))
	_apply_pose(delta, moving)
	_update_lantern(delta, moving)


func _read_keyboard() -> Vector3:
	var x := 0.0
	var z := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		z += 1.0
	if x == 0.0 and z == 0.0:
		return Vector3.ZERO
	# 由主控按相机朝向注入；这里仅作为未注入时的兜底（世界坐标）。
	return Vector3(x, 0, z)


func _apply_pose(delta: float, moving: bool) -> void:
	if _visual == null:
		return
	var phase := walk_phase
	if preview_walk:
		phase = preview_phase
		moving = true
	var swing := sin(phase)
	var swing2 := sin(phase * 2.0)
	var amp := 0.58 if moving else 0.0
	_leg_l.rotation.x = swing * amp
	_leg_r.rotation.x = -swing * amp
	_arm_l.rotation.x = -swing * amp * 0.65
	_arm_l.rotation.z = 8.0 * PI / 180.0 + (0.05 if not moving else 0.0)
	_arm_r.rotation.x = swing * amp * 0.35
	_arm_r.rotation.z = -8.0 * PI / 180.0 - (0.03 if not moving else 0.0)
	var bob := absf(swing2) * 0.035 if moving else sin(idle_time * 1.7) * 0.008
	_visual.position.y = bob
	_body.rotation.z = sin(phase) * 0.035 * (1.0 if moving else 0.0)
	_body.position.y = 0.0
	# 待机时轻轻转头/看灯。
	var head_turn := 0.0
	var head_tilt := 0.0
	if moving:
		head_turn = sin(phase) * 0.06
	else:
		head_turn = sin(idle_time * 0.55) * 0.13
		head_tilt = sin(idle_time * 0.9) * 0.03
	_head_group.rotation.y = head_turn
	_head_group.rotation.z = head_tilt + (0.02 if not moving else 0.0)
	if _staff != null:
		_staff.rotation.z = 3.0 * PI / 180.0 + sin(phase) * 0.05 * (1.0 if moving else 0.0)
		_staff.rotation.x = -sin(phase) * 0.04 * (1.0 if moving else 0.0)


func _update_lantern(delta: float, moving: bool) -> void:
	if _lantern_pivot == null:
		return
	# 灯笼像钟摆：行走时摆动更明显，待机时慢呼吸。
	var drive := 1.0 if moving else 0.45
	var sway_x := sin(_anim_t * (3.1 if moving else 1.1) + 0.7) * 0.13 * drive
	var sway_z := sin(_anim_t * (2.2 if moving else 0.8) + 1.9) * 0.10 * drive
	_lantern_pivot.rotation.x = sway_x
	_lantern_pivot.rotation.z = sway_z
	var e := lantern_energy_target
	if _lantern_light != null:
		_lantern_light.light_energy = lerpf(_lantern_light.light_energy, e, clampf(delta * 4.0, 0.0, 1.0))
	if _lantern_glass_mat != null:
		_lantern_glass_mat.albedo_color = GLASS_WARM * clampf(0.60 + e * 0.35, 0.60, 0.98)
	if _lantern_glow_mat != null:
		var c := _lantern_glow_mat.albedo_color
		_lantern_glow_mat.albedo_color = Color(c.r, c.g, c.b, clampf(e * 0.24, 0.0, 0.36))
	if _ground_pool_mat != null:
		var pc := _ground_pool_mat.albedo_color
		_ground_pool_mat.albedo_color = Color(pc.r, pc.g, pc.b, clampf(e * 0.20, 0.0, 0.28))


func get_speed() -> float:
	return speed_current


func is_walking() -> bool:
	return speed_current > 0.18 or preview_walk


func get_walk_phase() -> float:
	return walk_phase
