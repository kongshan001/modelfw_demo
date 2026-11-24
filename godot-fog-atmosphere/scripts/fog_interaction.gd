extends Node3D
## 动态雾驱散：
## - 角色移动时，clear_amount 平滑升到 1：近处雾片淡出并径向推开、水平雾层出现“雾洞”、
##   近身雾粒子淡出；远处雾片/雾层保持不变。
## - 停下 0.35s 后按 recovery_time（默认 1.6s）平滑恢复。
## - 移动时留下雾浪/足迹粒子；F1 显示半径/局部雾量调试环。
## 说明：GL Compatibility 无法逐像素修改 WorldEnvironment 的全局深度/高度雾；
## 这里清除的是“看得见的雾体”（雾片/贴地雾层/近身雾粒子），TECH 已写明边界。

const BASE_RADIUS := 4.5
const MIN_RADIUS := 1.5
const MAX_RADIUS := 10.0
const BASE_STRENGTH := 0.85
const BASE_RECOVERY := 1.6
const MIN_RECOVERY := 0.6
const MAX_RECOVERY := 4.0
const RISE_TIME := 0.28
const IDLE_DELAY := 0.35
const WAKE_COUNT := 16
const LOW_WAKE_COUNT := 8
const WAKE_LIFE := 1.25
const WAKE_INTERVAL := 0.14
const MOTE_COUNT := 44
const LOW_MOTE_COUNT := 22
const BANK_COUNT := 8
const LOW_BANK_COUNT := 4

var world: Node3D
var fog_system: Node3D
var player: Node3D

var clear_radius := BASE_RADIUS
var clear_strength := BASE_STRENGTH
var recovery_time := BASE_RECOVERY
var clear_amount := 0.0
var moving := false
var debug_visible := false
var quality_high := true

var motes: CPUParticles3D
var footstep: CPUParticles3D
var wake_multimesh: MultiMeshInstance3D
var wake_material: StandardMaterial3D
var bank_multimesh: MultiMeshInstance3D
var bank_material: StandardMaterial3D
var ring_main: MeshInstance3D
var ring_falloff: MeshInstance3D

var _mote_material: StandardMaterial3D
var _foot_material: StandardMaterial3D
var _wake_color := Color(0.9, 0.93, 0.88)
var _idle_timer := 0.0
var _wake_timer := 0.0
var _step_timer := 0.0
var _time := 0.0
var _wakes: Array[Dictionary] = []
var _bank: Array[Dictionary] = []
var _bank_alpha := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_world: Node3D, p_fog: Node3D, p_player: Node3D) -> void:
	world = p_world
	fog_system = p_fog
	player = p_player
	_rng.seed = 20261124
	_build_motes()
	_build_footstep()
	_build_wake()
	_build_bank()
	_build_debug_rings()
	set_quality(true)


# ---------------------------------------------------------------- 构建

func _build_motes() -> void:
	_mote_material = _make_mist_material(0.20, false)
	motes = CPUParticles3D.new()
	motes.name = "LocalMistMotes"
	motes.amount = MOTE_COUNT
	motes.lifetime = 4.5
	motes.preprocess = 2.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 2.3
	motes.direction = Vector3(0.0, 0.25, 0.0)
	motes.spread = 180.0
	motes.gravity = Vector3(0.0, 0.035, 0.0)
	motes.initial_velocity_min = 0.04
	motes.initial_velocity_max = 0.20
	motes.scale_amount_min = 0.45
	motes.scale_amount_max = 1.25
	var quad := QuadMesh.new()
	quad.size = Vector2(0.20, 0.20)
	motes.mesh = quad
	motes.material_override = _mote_material
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)


func _build_footstep() -> void:
	_foot_material = _make_mist_material(0.36, false)
	footstep = CPUParticles3D.new()
	footstep.name = "FootstepMist"
	footstep.amount = 7
	footstep.lifetime = 0.75
	footstep.one_shot = true
	footstep.explosiveness = 1.0
	footstep.emitting = false
	footstep.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	footstep.emission_sphere_radius = 0.26
	footstep.direction = Vector3(0.0, 1.0, 0.0)
	footstep.spread = 65.0
	footstep.gravity = Vector3(0.0, 0.22, 0.0)
	footstep.initial_velocity_min = 0.18
	footstep.initial_velocity_max = 0.55
	footstep.scale_amount_min = 0.25
	footstep.scale_amount_max = 0.55
	var quad := QuadMesh.new()
	quad.size = Vector2(0.24, 0.24)
	footstep.mesh = quad
	footstep.material_override = _foot_material
	footstep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(footstep)


func _build_wake() -> void:
	wake_material = _make_mist_material(0.34, true)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = WAKE_COUNT
	for i in range(WAKE_COUNT):
		mm.set_instance_color(i, Color(1, 1, 1, 0))
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3.ZERO))
		_wakes.append({"age": 1.0, "life": 1.0, "pos": Vector3.ZERO, "dir": Vector2.ZERO, "active": false})
	wake_multimesh = MultiMeshInstance3D.new()
	wake_multimesh.name = "FogWake"
	wake_multimesh.multimesh = mm
	wake_multimesh.material_override = wake_material
	wake_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wake_multimesh.extra_cull_margin = 12.0
	add_child(wake_multimesh)


func _build_bank() -> void:
	# 跟随角色的近身雾团（8 片低 alpha 小雾片）：雾的“局部密度”主要靠它可读地消失/恢复。
	bank_material = _make_mist_material(0.20, true)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = BANK_COUNT
	for i in range(BANK_COUNT):
		mm.set_instance_color(i, Color(1, 1, 1, 0))
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3.ZERO))
		_bank.append({
			"angle": _rng.randf_range(0.0, TAU),
			"radius": _rng.randf_range(2.2, 5.0),
			"size": _rng.randf_range(2.6, 4.6),
			"y": _rng.randf_range(0.45, 1.35),
			"phase": _rng.randf_range(0.0, TAU),
			"drift": _rng.randf_range(-0.06, 0.06),
		})
	bank_multimesh = MultiMeshInstance3D.new()
	bank_multimesh.name = "LocalFogBank"
	bank_multimesh.multimesh = mm
	bank_multimesh.material_override = bank_material
	bank_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bank_multimesh.extra_cull_margin = 10.0
	add_child(bank_multimesh)


func _build_debug_rings() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.972
	torus.outer_radius = 1.0
	torus.rings = 72
	torus.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.62, 1.0, 0.86, 0.85)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	ring_main = MeshInstance3D.new()
	ring_main.name = "ClearRadiusRing"
	ring_main.mesh = torus
	ring_main.material_override = mat
	ring_main.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_main.visible = false
	add_child(ring_main)

	var falloff_mat := mat.duplicate() as StandardMaterial3D
	falloff_mat.albedo_color = Color(0.45, 0.82, 1.0, 0.34)
	ring_falloff = MeshInstance3D.new()
	ring_falloff.name = "ClearFalloffRing"
	ring_falloff.mesh = torus
	ring_falloff.material_override = falloff_mat
	ring_falloff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_falloff.visible = false
	add_child(ring_falloff)


func _make_mist_material(alpha: float, vertex_alpha: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if not vertex_alpha else BaseMaterial3D.BILLBOARD_DISABLED
	mat.albedo_texture = fog_system.mist_texture()
	mat.albedo_color = Color(0.9, 0.93, 0.88, alpha)
	mat.vertex_color_use_as_albedo = vertex_alpha
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


# ---------------------------------------------------------------- 更新

func _process(delta: float) -> void:
	if player == null or fog_system == null:
		return
	_time += delta
	moving = player.is_moving()
	if moving:
		_idle_timer = 0.0
		clear_amount = minf(1.0, clear_amount + delta / RISE_TIME)
	else:
		_idle_timer += delta
		if _idle_timer >= IDLE_DELAY:
			clear_amount = maxf(0.0, clear_amount - delta / recovery_time)
	fog_system.set_clear_source(player.global_position, clear_radius, clear_strength, clear_amount)
	_wake_color = _fog_color()
	player.set_fog_tint(_wake_color)
	_update_motes(delta)
	_update_bank()
	_update_wake(delta)
	_update_footstep(delta)
	_update_debug_rings()


func _update_motes(_delta: float) -> void:
	if motes == null:
		return
	motes.position = player.global_position + Vector3(0.0, 1.05, 0.0)
	var tint := _wake_color
	var alpha := 0.20 * (1.0 - 0.88 * clear_strength * clear_amount)
	_mote_material.albedo_color = Color(tint.r, tint.g, tint.b, alpha)


func _update_bank() -> void:
	if bank_multimesh == null:
		return
	var active := BANK_COUNT if quality_high else LOW_BANK_COUNT
	var cam := get_viewport().get_camera_3d()
	var cam_yaw := cam.global_rotation.y if cam != null else 0.0
	var base_alpha: float = clampf(fog_system.puff_material.albedo_color.a * 0.55, 0.06, 0.26)
	# 近身雾团被“推开”到清除半径外，而不是直接消失：形成一圈可读的雾墙。
	var push: float = clear_radius * 0.52 * clear_strength * clear_amount
	_bank_alpha = base_alpha * (0.30 + 0.70 * (1.0 - 0.90 * clear_strength * clear_amount))
	var p := player.global_position
	for i in range(BANK_COUNT):
		if i >= active:
			bank_multimesh.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3.ZERO))
			bank_multimesh.multimesh.set_instance_color(i, Color(1, 1, 1, 0))
			continue
		var entry: Dictionary = _bank[i]
		var angle: float = float(entry["angle"]) + _time * float(entry["drift"]) + sin(_time * 0.21 + float(entry["phase"])) * 0.22
		var radius: float = float(entry["radius"]) + sin(_time * 0.33 + float(entry["phase"])) * 0.35
		radius += push
		var pos := Vector3(p.x + cos(angle) * radius, 0.0, p.z + sin(angle) * radius)
		pos.y = world.terrain_height(pos.x, pos.z) + float(entry["y"]) + sin(_time * 0.5 + float(entry["phase"])) * 0.10
		var size: float = float(entry["size"]) * (1.0 + 0.25 * clear_strength * clear_amount)
		var basis := Basis.from_euler(Vector3(0.0, cam_yaw, 0.0)).scaled(Vector3(size, size * 0.55, 1.0))
		bank_multimesh.multimesh.set_instance_transform(i, Transform3D(basis, pos))
		bank_multimesh.multimesh.set_instance_color(i, Color(_wake_color.r, _wake_color.g, _wake_color.b, _bank_alpha))


func _update_wake(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var cam_yaw := cam.global_rotation.y if cam != null else 0.0
	if moving and clear_amount > 0.03:
		_wake_timer += delta
		while _wake_timer >= WAKE_INTERVAL:
			_wake_timer -= WAKE_INTERVAL
			_spawn_wake()
	else:
		_wake_timer = 0.0
	var count := WAKE_COUNT if quality_high else LOW_WAKE_COUNT
	for i in range(WAKE_COUNT):
		var wake: Dictionary = _wakes[i]
		if not bool(wake["active"]) or i >= count:
			wake_multimesh.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3.ZERO))
			wake_multimesh.multimesh.set_instance_color(i, Color(1, 1, 1, 0))
			continue
		var age: float = float(wake["age"]) + delta
		var life: float = float(wake["life"])
		wake["age"] = age
		if age >= life:
			wake["active"] = false
			wake_multimesh.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3.ZERO))
			wake_multimesh.multimesh.set_instance_color(i, Color(1, 1, 1, 0))
			continue
		var t := age / life
		var pos: Vector3 = wake["pos"]
		var dir: Vector2 = wake["dir"]
		pos += Vector3(dir.x, 0.0, dir.y) * delta * 0.55
		pos.y = world.terrain_height(pos.x, pos.z) + 0.20 + t * 0.22
		wake["pos"] = pos
		var size := 0.65 + t * 2.45
		var basis := Basis.from_euler(Vector3(0.0, cam_yaw, 0.0)).scaled(Vector3(size, size * 0.46, 1.0))
		wake_multimesh.multimesh.set_instance_transform(i, Transform3D(basis, pos))
		var alpha := pow(1.0 - t, 1.4) * 0.40 * (0.35 + 0.65 * clear_strength * clear_amount)
		wake_multimesh.multimesh.set_instance_color(i, Color(_wake_color.r, _wake_color.g, _wake_color.b, alpha))


func _spawn_wake() -> void:
	var slot := -1
	for i in range(_wakes.size()):
		if not bool(_wakes[i]["active"]):
			slot = i
			break
	if slot < 0:
		return
	var speed_dir := Vector2(player.velocity.x, player.velocity.z)
	if speed_dir.length() < 0.01:
		speed_dir = Vector2(0.0, 1.0)
	speed_dir = speed_dir.normalized()
	var side := Vector2(-speed_dir.y, speed_dir.x)
	var off := -speed_dir * _rng.randf_range(0.15, 0.55) + side * _rng.randf_range(-0.28, 0.28)
	var pos := player.global_position + Vector3(off.x, 0.18, off.y)
	pos.y = world.terrain_height(pos.x, pos.z) + 0.18
	_wakes[slot] = {
		"age": 0.0,
		"life": WAKE_LIFE * _rng.randf_range(0.8, 1.15),
		"pos": pos,
		"dir": (speed_dir + side * _rng.randf_range(-0.20, 0.20)).normalized(),
		"active": true,
	}


func _update_footstep(delta: float) -> void:
	if footstep == null:
		return
	var speed: float = player.horizontal_speed()
	if speed > 0.6:
		_step_timer += delta
		var interval := 0.22 if speed > 3.0 else 0.34
		if _step_timer >= interval:
			_step_timer = 0.0
			footstep.global_position = player.global_position + Vector3(0.0, 0.16, 0.0)
			footstep.restart()
			footstep.emitting = true
	else:
		_step_timer = 0.0
	var tint := _wake_color
	_foot_material.albedo_color = Color(tint.r, tint.g, tint.b, 0.30 * (0.4 + 0.6 * clampf(speed / 4.6, 0.0, 1.0)))


func _update_debug_rings() -> void:
	if ring_main == null:
		return
	var visible_now := debug_visible
	ring_main.visible = visible_now
	ring_falloff.visible = visible_now
	if not visible_now:
		return
	var ground := player.global_position
	ground.y = world.terrain_height(ground.x, ground.z) + 0.06
	ring_main.global_position = ground
	ring_main.scale = Vector3(clear_radius, 1.0, clear_radius)
	ring_falloff.global_position = ground + Vector3(0.0, 0.01, 0.0)
	ring_falloff.scale = Vector3(clear_radius * 1.55, 1.0, clear_radius * 1.55)


func _fog_color() -> Color:
	if fog_system != null and fog_system.puff_material != null:
		var c: Color = fog_system.puff_material.albedo_color
		return Color(c.r, c.g, c.b)
	return Color(0.9, 0.93, 0.88)


# ---------------------------------------------------------------- 参数 / API

func set_clear_radius(value: float) -> void:
	clear_radius = clampf(value, MIN_RADIUS, MAX_RADIUS)


func adjust_radius(step: float) -> void:
	set_clear_radius(clear_radius + step)


func set_clear_strength(value: float) -> void:
	clear_strength = clampf(value, 0.0, 1.0)


func adjust_strength(step: float) -> void:
	set_clear_strength(clear_strength + step)


func set_recovery_time(value: float) -> void:
	recovery_time = clampf(value, MIN_RECOVERY, MAX_RECOVERY)


func adjust_recovery(step: float) -> void:
	set_recovery_time(recovery_time + step)


func set_debug_visible(value: bool) -> void:
	debug_visible = value


func set_quality(high: bool) -> void:
	quality_high = high
	if motes != null:
		motes.amount = MOTE_COUNT if high else LOW_MOTE_COUNT
		motes.emitting = true
		motes.restart()
	if footstep != null:
		footstep.amount = 7 if high else 4
	if wake_multimesh != null:
		wake_multimesh.multimesh.visible_instance_count = WAKE_COUNT if high else LOW_WAKE_COUNT
	if bank_multimesh != null:
		bank_multimesh.multimesh.visible_instance_count = BANK_COUNT if high else LOW_BANK_COUNT


func reset() -> void:
	clear_radius = BASE_RADIUS
	clear_strength = BASE_STRENGTH
	recovery_time = BASE_RECOVERY
	clear_amount = 0.0
	_idle_timer = 0.0
	_wake_timer = 0.0
	_step_timer = 0.0
	debug_visible = false
	for i in range(_wakes.size()):
		_wakes[i]["active"] = false
	if ring_main != null:
		ring_main.visible = false
		ring_falloff.visible = false
	if fog_system != null and player != null:
		fog_system.set_clear_source(player.global_position, clear_radius, clear_strength, clear_amount)


func get_local_factor_at(point: Vector3) -> float:
	if fog_system == null:
		return 1.0
	return fog_system.visibility_factor_at(point)


func active_wake_count() -> int:
	var count := 0
	for wake in _wakes:
		if bool(wake["active"]):
			count += 1
	return count


func state() -> Dictionary:
	return {
		"radius": clear_radius,
		"strength": clear_strength,
		"recovery": recovery_time,
		"amount": clear_amount,
		"moving": moving,
		"debug": debug_visible,
		"local_factor": get_local_factor_at(player.global_position) if player != null else 1.0,
		"wakes": active_wake_count(),
		"mote_alpha": _mote_material.albedo_color.a if _mote_material != null else 0.0,
		"bank_alpha": _bank_alpha,
	}
