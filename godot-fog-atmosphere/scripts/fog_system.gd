extends Node3D
## 体积观感补足层：贴地雾片（MultiMesh billboard）、水平雾层、浮尘/流萤/落叶粒子、
## 交叉面片伪光束。环境深度/高度雾由 WorldEnvironment 负责；这里只做“看得到的雾”。
## 预算：高质量 22 雾片 + 2 水平层 + 282 粒子 + 4 光束；低质量减半。

const PUFF_COUNT := 20
const LOW_PUFF_COUNT := 9
const PUFF_AREA := 38.0
const BEAM_COUNT := 4

var world: Node3D
var quality_high := true
var fog_level_index := 2
var wind_speed := 1.4
var nightness := 0.0

var puff_multimesh: MultiMeshInstance3D
var puff_material: StandardMaterial3D
var layer_nodes: Array[MeshInstance3D] = []
var layer_materials: Array[StandardMaterial3D] = []
var beam_nodes: Array[Node3D] = []
var beam_materials: Array[ShaderMaterial] = []
var pollen: CPUParticles3D
var fireflies: CPUParticles3D
var leaves: CPUParticles3D

var _puffs: Array[Dictionary] = []
var _puff_uv := Vector2.ZERO
var _layer_uv: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _mist_texture: ImageTexture
var _patch_texture: ImageTexture
var _glow_texture: ImageTexture
var _leaf_texture: ImageTexture
var _pollen_material: StandardMaterial3D
var _firefly_material: StandardMaterial3D
var _leaf_material: StandardMaterial3D
var _puff_base_alpha := 0.42
var _layer_base_alpha := [0.15, 0.08]
var _wind_dir := Vector2(0.82, 0.57)
var _rng := RandomNumberGenerator.new()
var _tint_base := Color(0.95, 0.97, 0.94)
var _anim_time := 0.0


func setup(p_world: Node3D) -> void:
	world = p_world
	_rng.seed = 5150
	_mist_texture = world.call("_make_mist_texture", 256, 23)
	_patch_texture = world.make_patch_texture()
	_glow_texture = world.make_particle_texture()
	_leaf_texture = world.make_leaf_particle_texture()
	_build_puffs()
	_build_layers()
	_build_particles()
	_build_beams()
	set_quality(true)


# ---------------------------------------------------------------- 雾片

func _build_puffs() -> void:
	puff_material = StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.albedo_texture = _mist_texture
	puff_material.albedo_color = Color(0.95, 0.97, 0.94, _puff_base_alpha)
	puff_material.vertex_color_use_as_albedo = true
	puff_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	puff_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = PUFF_COUNT
	for i in range(PUFF_COUNT):
		var pos := Vector2(_rng.randf_range(-PUFF_AREA, PUFF_AREA), _rng.randf_range(-PUFF_AREA, PUFF_AREA))
		_puffs.append({
			"pos": pos,
			"size": _rng.randf_range(7.5, 19.0),
			"y_off": _rng.randf_range(0.35, 1.65),
			"phase": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-0.22, 0.22),
			"drift": _rng.randf_range(0.55, 1.35),
			"tint": _rng.randf_range(0.86, 1.0),
		})
		mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 1.0))
	puff_multimesh = MultiMeshInstance3D.new()
	puff_multimesh.name = "FogPuffs"
	puff_multimesh.multimesh = mm
	puff_multimesh.material_override = puff_material
	puff_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff_multimesh.extra_cull_margin = 24.0
	add_child(puff_multimesh)


func _build_layers() -> void:
	for i in range(2):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = _patch_texture
		mat.albedo_color = Color(0.95, 0.97, 0.94, _layer_base_alpha[i])
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat.uv1_scale = Vector3(2.4, 2.4, 1.0)
		layer_materials.append(mat)
		var plane := PlaneMesh.new()
		plane.size = Vector2(62, 62)
		var mi := MeshInstance3D.new()
		mi.name = "FogLayer%d" % i
		mi.mesh = plane
		mi.material_override = mat
		mi.position.y = 0.75 + float(i) * 0.85
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		layer_nodes.append(mi)


# ---------------------------------------------------------------- 粒子

func _particle_base(amount: int, lifetime: float, box: Vector3, mat: StandardMaterial3D, quad_size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = minf(lifetime * 0.5, 4.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = Vector3(0.15, 0.3, 0.08)
	p.spread = 55.0
	p.gravity = Vector3(0.02, 0.0, -0.015)
	p.initial_velocity_min = 0.04
	p.initial_velocity_max = 0.22
	p.angular_velocity_min = -12.0
	p.angular_velocity_max = 12.0
	p.scale_amount_min = 0.65
	p.scale_amount_max = 1.25
	var quad := QuadMesh.new()
	quad.size = Vector2(quad_size, quad_size)
	p.mesh = quad
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_particle_material(tex: Texture2D, blend_add: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if blend_add else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.vertex_color_use_as_albedo = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


func _build_particles() -> void:
	_pollen_material = _make_particle_material(_glow_texture, true)
	_pollen_material.albedo_color = Color(1.0, 0.86, 0.50, 0.75)
	pollen = _particle_base(190, 12.0, Vector3(30, 3.0, 30), _pollen_material, 0.13)
	pollen.name = "Pollen"
	pollen.position = Vector3(0, 3.4, 0)
	var pg := Gradient.new()
	pg.set_color(0, Color(1.0, 0.90, 0.55, 0.0))
	pg.set_color(1, Color(1.0, 0.82, 0.42, 0.0))
	pg.add_point(0.25, Color(1.0, 0.88, 0.50, 1.0))
	pg.add_point(0.8, Color(1.0, 0.80, 0.40, 0.75))
	pollen.color_ramp = pg
	pollen.gravity = Vector3(0.02, 0.015, -0.01)
	pollen.scale_amount_min = 0.5
	pollen.scale_amount_max = 1.3

	_firefly_material = _make_particle_material(_glow_texture, true)
	_firefly_material.albedo_color = Color(0.92, 1.0, 0.62, 0.9)
	fireflies = _particle_base(34, 7.0, Vector3(22, 2.6, 22), _firefly_material, 0.20)
	fireflies.name = "Fireflies"
	fireflies.position = Vector3(0, 2.0, 0)
	var fg := Gradient.new()
	fg.set_color(0, Color(0.85, 1.0, 0.55, 0.0))
	fg.set_color(1, Color(0.85, 1.0, 0.55, 0.0))
	fg.add_point(0.3, Color(0.90, 1.0, 0.60, 1.0))
	fg.add_point(0.7, Color(0.80, 1.0, 0.45, 0.35))
	fireflies.color_ramp = fg
	fireflies.gravity = Vector3(0.0, 0.0, 0.0)
	fireflies.initial_velocity_max = 0.12
	fireflies.scale_amount_min = 0.6
	fireflies.scale_amount_max = 1.6

	_leaf_material = _make_particle_material(_leaf_texture, false)
	_leaf_material.albedo_color = Color(0.72, 0.76, 0.32, 0.95)
	leaves = _particle_base(24, 14.0, Vector3(26, 6.5, 26), _leaf_material, 0.28)
	leaves.name = "Leaves"
	leaves.position = Vector3(0, 7.0, 0)
	var lg := Gradient.new()
	lg.set_color(0, Color(0.75, 0.82, 0.30, 0.0))
	lg.set_color(1, Color(0.62, 0.66, 0.22, 0.0))
	lg.add_point(0.2, Color(0.78, 0.84, 0.34, 1.0))
	lg.add_point(0.75, Color(0.70, 0.74, 0.28, 1.0))
	leaves.color_ramp = lg
	leaves.gravity = Vector3(0.10, -0.16, 0.05)
	leaves.initial_velocity_max = 0.35
	leaves.angular_velocity_min = -60.0
	leaves.angular_velocity_max = 60.0
	leaves.scale_amount_min = 0.7
	leaves.scale_amount_max = 1.5


# ---------------------------------------------------------------- 伪光束

func _build_beams() -> void:
	var beam_spots := [
		[Vector3(-1.0, 0.0, -13.5), 16.0, 2.4],
		[Vector3(10.0, 0.0, 6.0), 18.0, 3.0],
		[Vector3(-8.5, 0.0, 2.0), 14.0, 2.0],
		[Vector3(5.5, 0.0, -1.0), 15.0, 2.2],
	]
	for i in range(BEAM_COUNT):
		var entry: Array = beam_spots[i]
		var base: Vector3 = entry[0]
		var height: float = entry[1]
		var width: float = entry[2]
		base.y = world.terrain_height(base.x, base.z)
		var pivot := Node3D.new()
		pivot.name = "Beam%d" % i
		pivot.position = base
		pivot.rotation.y = _rng.randf_range(0.0, TAU)
		pivot.rotation.z = _rng.randf_range(-0.16, -0.05)
		add_child(pivot)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/beam.gdshader")
		mat.set_shader_parameter("seed", float(i) * 7.3)
		mat.set_shader_parameter("beam_color", Color(0.95, 0.88, 0.70, 1.0))
		mat.set_shader_parameter("intensity", 0.04)
		beam_materials.append(mat)
		for cross in range(2):
			var quad := QuadMesh.new()
			quad.size = Vector2(width, height)
			var mi := MeshInstance3D.new()
			mi.mesh = quad
			mi.material_override = mat
			mi.position.y = height * 0.5
			mi.rotation.y = float(cross) * PI * 0.5
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(mi)
		beam_nodes.append(pivot)


# ---------------------------------------------------------------- 更新

func _process(delta: float) -> void:
	_anim_time += delta
	_update_puffs(delta)
	_update_layers(delta)


func _update_puffs(delta: float) -> void:
	var count := _active_puff_count()
	var cam := get_viewport().get_camera_3d()
	var cam_yaw := 0.0
	if cam != null:
		cam_yaw = cam.global_rotation.y
	var wind := wind_speed
	_puff_uv.x += delta * 0.012 * wind
	_puff_uv.y += delta * 0.005 * wind
	# 共享材质：UV 滚动由材质 uv1_offset 承担
	puff_material.uv1_offset = Vector3(_puff_uv.x, _puff_uv.y, 0.0)
	for i in range(count):
		var puff: Dictionary = _puffs[i]
		var pos: Vector2 = puff["pos"]
		pos += _wind_dir * wind * float(puff["drift"]) * delta * 0.6
		if pos.x > PUFF_AREA:
			pos.x -= PUFF_AREA * 2.0
		elif pos.x < -PUFF_AREA:
			pos.x += PUFF_AREA * 2.0
		if pos.y > PUFF_AREA:
			pos.y -= PUFF_AREA * 2.0
		elif pos.y < -PUFF_AREA:
			pos.y += PUFF_AREA * 2.0
		puff["pos"] = pos
		var size: float = puff["size"]
		var gy: float = world.terrain_height(pos.x, pos.y)
		var wobble := sin(_anim_time * 0.5 + float(puff["phase"])) * 0.12
		var y := gy + float(puff["y_off"]) + wobble
		var yaw := cam_yaw + float(puff["spin"]) * 2.0 + sin(_anim_time * 0.3 + float(puff["phase"])) * 0.15
		var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3(size, size * 0.52, 1.0))
		puff_multimesh.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(pos.x, y, pos.y)))
		var tint: float = puff["tint"]
		puff_multimesh.multimesh.set_instance_color(i, Color(tint, tint, tint, 1.0))


func _update_layers(delta: float) -> void:
	for i in range(layer_materials.size()):
		_layer_uv[i] += Vector2(delta * (0.006 + float(i) * 0.004), delta * 0.0025) * wind_speed
		layer_materials[i].uv1_offset = Vector3(_layer_uv[i].x, _layer_uv[i].y, 0.0)


func _active_puff_count() -> int:
	return PUFF_COUNT if quality_high else LOW_PUFF_COUNT


func set_quality(high: bool) -> void:
	quality_high = high
	if puff_multimesh != null:
		puff_multimesh.multimesh.visible_instance_count = _active_puff_count()
	for i in range(layer_nodes.size()):
		layer_nodes[i].visible = high or i == 0
	var pollen_amount := 190 if high else 80
	var firefly_amount := 34 if high else 15
	var leaf_amount := 24 if high else 9
	_set_particle_amount(pollen, pollen_amount)
	_set_particle_amount(fireflies, firefly_amount)
	_set_particle_amount(leaves, leaf_amount)
	for i in range(beam_nodes.size()):
		beam_nodes[i].visible = high or i < 2
	apply_phase(nightness)


func _set_particle_amount(p: CPUParticles3D, amount: int) -> void:
	if p == null:
		return
	p.amount = amount
	p.emitting = true
	p.restart()


func set_fog_level(level: int) -> void:
	fog_level_index = clampi(level, 0, 3)
	apply_phase(nightness)


func set_tint(color: Color) -> void:
	_tint_base = color.lerp(Color(1, 1, 1), 0.45)
	apply_phase(nightness)


func set_wind(speed: float) -> void:
	wind_speed = clampf(speed, 0.2, 3.0)
	if pollen != null:
		pollen.speed_scale = 0.7 + wind_speed * 0.35
	if fireflies != null:
		fireflies.speed_scale = 0.6 + wind_speed * 0.3
	if leaves != null:
		leaves.speed_scale = 0.7 + wind_speed * 0.45
		leaves.gravity.x = 0.06 + wind_speed * 0.09
	for mat in beam_materials:
		mat.set_shader_parameter("animation_speed", 0.6 + wind_speed * 0.5)


func apply_phase(night_t: float) -> void:
	nightness = clampf(night_t, 0.0, 1.0)
	var day_fog := _tint_base
	var night_fog := Color(0.56, 0.65, 0.80)
	var fog_tint := day_fog.lerp(night_fog, nightness)
	var level_factor: float = [0.25, 0.65, 1.0, 1.30][fog_level_index]
	if puff_material != null:
		puff_material.albedo_color = Color(fog_tint.r, fog_tint.g, fog_tint.b, _puff_base_alpha * level_factor)
	for i in range(layer_materials.size()):
		layer_materials[i].albedo_color = Color(fog_tint.r, fog_tint.g, fog_tint.b, _layer_base_alpha[i] * level_factor)
	var beam_col := Color(0.90, 0.84, 0.66).lerp(Color(0.55, 0.68, 0.92), nightness)
	var beam_strength := lerpf(0.04, 0.42, nightness)
	for mat in beam_materials:
		mat.set_shader_parameter("beam_color", beam_col)
		mat.set_shader_parameter("intensity", beam_strength)
	if _pollen_material != null:
		_pollen_material.albedo_color = Color(1.0, 0.86, 0.50, 0.75).lerp(Color(0.72, 0.86, 1.0, 0.8), nightness)
	if _firefly_material != null:
		_firefly_material.albedo_color = Color(0.92, 1.0, 0.62, 0.9).lerp(Color(0.78, 1.0, 0.72, 1.0), nightness)
	if _leaf_material != null:
		_leaf_material.albedo_color = Color(0.72, 0.76, 0.32, 0.95).lerp(Color(0.40, 0.48, 0.30, 0.85), nightness)


func get_counts() -> Dictionary:
	var total := 0
	for p in [pollen, fireflies, leaves]:
		if p != null and p.visible:
			total += p.amount
	var visible_beams := 0
	for b in beam_nodes:
		if b.visible:
			visible_beams += 1
	return {
		"puffs": _active_puff_count(),
		"layers": 2 if quality_high else 1,
		"particles": total,
		"beams": visible_beams,
	}


func set_particles_visible(value: bool) -> void:
	for p in [pollen, fireflies, leaves]:
		if p != null:
			p.visible = value
