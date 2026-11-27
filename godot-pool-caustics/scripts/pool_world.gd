extends Node3D

# 原创石盆场景：平缓下沉的河床、六块主景圆石、半圈岸边石，以及一层很淡的水面高光。
# 所有几何/贴图在运行时程序化生成；焦散由 floor / rock 两个 shader 共用核心。

const FLOOR_SIZE := Vector2(40.0, 31.0)
const ROCK_VARIANTS := 3
const Riverbed = preload("res://scripts/riverbed_texture.gd")

var floor_material: ShaderMaterial
var rock_materials: Array[ShaderMaterial] = []
var water_material: ShaderMaterial
var floor_mesh: MeshInstance3D
var water_veil: MeshInstance3D
var bed_texture: ImageTexture
var rock_root: Node3D
var rocks: Array[MeshInstance3D] = []
var shadow_data := PackedVector4Array()

var _rock_meshes: Array[ArrayMesh] = []
var _shared_params := {
	"u_time": 0.0,
	"u_scale": 0.72,
	"u_width": 0.050,
	"u_softness": 0.95,
	"u_brightness": 0.98,
	"u_speed": 0.46,
	"u_warp_amount": 0.68,
	"u_junction": 1.35,
	"u_gather": 0.84,
	"u_soft_light": 0.95,
	"u_search_3x3": 1.0,
	"u_debug": 0,
	"u_style": 0.0,
	"u_gap_threshold": 0.0,
	"u_flow_angle": -31.0,
	"u_seed": 0.0,
	"u_line_color": Color(0.58, 0.98, 0.97, 1.0),
	"u_glow_color": Color(0.025, 0.52, 0.64, 1.0),
	"u_focus": Vector4(0.0, 0.0, 0.0, 0.0),
}


func build() -> void:
	var t0 := Time.get_ticks_msec()
	rock_root = Node3D.new()
	rock_root.name = "Rocks"
	add_child(rock_root)

	_build_materials()
	_build_floor()
	_build_rocks()
	_build_water_veil()
	print("POOL_WORLD_READY rocks=%d materials=%d build_ms=%d" % [
			rocks.size(), rock_materials.size() + 2, Time.get_ticks_msec() - t0])


func _build_materials() -> void:
	bed_texture = Riverbed.build(640)

	floor_material = ShaderMaterial.new()
	floor_material.shader = load("res://shaders/pool_floor.gdshader")
	floor_material.set_shader_parameter("u_bed_texture", bed_texture)
	floor_material.set_shader_parameter("u_floor_extent", FLOOR_SIZE)
	floor_material.set_shader_parameter("u_floor_tint", Color(0.50, 0.72, 0.74))
	floor_material.set_shader_parameter("u_deep_tint", Color(0.004, 0.036, 0.043))
	floor_material.set_shader_parameter("u_rock_count", 8)

	var hero := ShaderMaterial.new()
	hero.shader = load("res://shaders/pool_rock.gdshader")
	hero.set_shader_parameter("u_rock_light", Color(0.33, 0.46, 0.45))
	hero.set_shader_parameter("u_rock_dark", Color(0.016, 0.050, 0.048))
	hero.set_shader_parameter("u_moss_color", Color(0.18, 0.30, 0.17))
	hero.set_shader_parameter("u_moss_amount", 0.68)
	hero.set_shader_parameter("u_caustic_amount", 0.34)
	hero.set_shader_parameter("u_wet_spec", 0.42)
	hero.set_shader_parameter("u_rim", 0.22)

	var rim := ShaderMaterial.new()
	rim.shader = load("res://shaders/pool_rock.gdshader")
	rim.set_shader_parameter("u_rock_light", Color(0.19, 0.30, 0.27))
	rim.set_shader_parameter("u_rock_dark", Color(0.012, 0.036, 0.039))
	rim.set_shader_parameter("u_moss_color", Color(0.18, 0.29, 0.18))
	rim.set_shader_parameter("u_moss_amount", 0.44)
	rim.set_shader_parameter("u_caustic_amount", 0.22)
	rim.set_shader_parameter("u_wet_spec", 0.12)
	rim.set_shader_parameter("u_rim", 0.16)
	rim.set_shader_parameter("u_light_wrap", 0.18)

	rock_materials = [hero, rim]
	for mat in [floor_material] + rock_materials:
		_apply_shared_params(mat)


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = FLOOR_SIZE
	plane.subdivide_width = 36
	plane.subdivide_depth = 28
	floor_mesh = MeshInstance3D.new()
	floor_mesh.name = "Riverbed"
	floor_mesh.mesh = plane
	floor_mesh.material_override = floor_material
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mesh)


func _build_rocks() -> void:
	for i in ROCK_VARIANTS:
		_rock_meshes.append(_make_rock_mesh(11 + i * 37, 20, 30))

	# 主景石：左中一块大石，右/后/前错落小块，构图避开右侧 UI 面板。
	var hero_specs := [
		{"pos": Vector3(-1.30, 1.02, 0.15), "scale": Vector3(2.62, 1.62, 2.24),
				"yaw": 18.0, "mesh": 0, "mat": 0, "shadow": 1.0},
		{"pos": Vector3(3.25, 0.60, 1.18), "scale": Vector3(1.62, 1.12, 1.42),
				"yaw": -34.0, "mesh": 1, "mat": 0, "shadow": 0.82},
		{"pos": Vector3(-4.65, 0.40, -2.05), "scale": Vector3(1.28, 0.88, 1.20),
				"yaw": 63.0, "mesh": 2, "mat": 0, "shadow": 0.64},
		{"pos": Vector3(0.72, 0.27, -3.55), "scale": Vector3(0.78, 0.55, 0.72),
				"yaw": 105.0, "mesh": 1, "mat": 0, "shadow": 0.46},
		{"pos": Vector3(4.72, 0.43, -2.02), "scale": Vector3(1.02, 0.70, 0.96),
				"yaw": -78.0, "mesh": 2, "mat": 0, "shadow": 0.52},
		{"pos": Vector3(-5.48, 0.32, 2.82), "scale": Vector3(0.92, 0.60, 0.86),
				"yaw": 12.0, "mesh": 0, "mat": 0, "shadow": 0.50},
	]
	for i in hero_specs.size():
		var spec: Dictionary = hero_specs[i]
		var node := _add_rock(spec["pos"], spec["scale"], spec["yaw"],
				spec["mesh"], rock_materials[spec["mat"]], "HeroRock_%02d" % i)
		rocks.append(node)
		var r: float = maxf(spec["scale"].x, spec["scale"].z) * 0.94
		shadow_data.append(Vector4(spec["pos"].x, spec["pos"].z, r, spec["shadow"]))

	# 岸边石：留出正前方开口，避免挡住镜头；它们提供石盆边界和深色剪影。
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC1057
	var added_shadows := 0
	for i in 18:
		var a := TAU * float(i) / 18.0 + rng.randf_range(-0.055, 0.055)
		var deg := rad_to_deg(a)
		# 正前方缺口（相机一侧）。
		if deg > 54.0 and deg < 126.0:
			continue
		var rx := 12.9
		var rz := 10.0
		var pos := Vector3(cos(a) * rx + rng.randf_range(-0.5, 0.5),
				0.22, sin(a) * rz + rng.randf_range(-0.5, 0.5))
		var sx := rng.randf_range(1.55, 2.55)
		var sy := rng.randf_range(0.65, 1.20)
		var sz := rng.randf_range(1.45, 2.35)
		_add_rock(pos, Vector3(sx, sy, sz), rad_to_deg(a) + rng.randf_range(-30.0, 30.0),
				i % ROCK_VARIANTS, rock_materials[1], "RimRock_%02d" % i)
		if added_shadows < 2 and deg > 180.0:
			shadow_data.append(Vector4(pos.x, pos.z, sx * 0.7, 0.40))
			added_shadows += 2

	# 下方前景石：只露出深色剪影，增加近景层次。
	_add_rock(Vector3(-7.8, 0.34, 6.2), Vector3(3.0, 1.05, 2.2), 22.0,
			1, rock_materials[1], "ForegroundStone_L")
	_add_rock(Vector3(8.4, 0.26, 7.1), Vector3(2.2, 0.82, 1.8), -14.0,
			2, rock_materials[1], "ForegroundStone_R")

	# 固定 8 槽，不足补零；floor shader 用 u_rock_count 控制有效的数量。
	while shadow_data.size() < 8:
		shadow_data.append(Vector4.ZERO)
	floor_material.set_shader_parameter("u_rock_count", mini(shadow_data.size(), 8))
	floor_material.set_shader_parameter("u_rock_shadows", shadow_data)


func _build_water_veil() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(44.0, 34.0)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://shaders/water_veil.gdshader")
	water_material.set_shader_parameter("u_amount", 0.85)
	water_material.set_shader_parameter("u_color", Color(0.32, 0.82, 0.90))
	water_veil = MeshInstance3D.new()
	water_veil.name = "WaterVeil"
	water_veil.mesh = plane
	water_veil.position.y = 5.45
	water_veil.material_override = water_material
	water_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_veil)


func _add_rock(pos: Vector3, scl: Vector3, yaw: float, mesh_idx: int,
		mat: ShaderMaterial, node_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = _rock_meshes[mesh_idx % _rock_meshes.size()]
	node.position = pos
	node.rotation_degrees = Vector3(0.0, yaw, 0.0)
	node.scale = scl
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rock_root.add_child(node)
	return node


func _make_rock_mesh(seed_value: int, rings: int, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := float(seed_value)
	var verts := PackedVector3Array()
	for iy in rings + 1:
		var theta := PI * float(iy) / float(rings)
		var stheta := sin(theta)
		var ctheta := cos(theta)
		for ix in segments:
			var phi := TAU * float(ix) / float(segments)
			var dir := Vector3(stheta * cos(phi), ctheta, stheta * sin(phi))
			var lumps := 0.080 * sin(dir.x * 3.3 + s * 0.17)
			lumps += 0.052 * sin(dir.y * 4.1 - s * 0.11)
			lumps += 0.042 * sin(dir.z * 4.9 + s * 0.07)
			lumps += 0.026 * sin((dir.x + dir.y + dir.z) * 7.1 + s)
			var radius := 1.0 + lumps
			var v := dir * radius
			# 底部略平，方便埋进河床。
			v.y = maxf(v.y, -0.72)
			# 非均匀横向漂移，避免所有石头都是标准球。
			v.x += 0.04 * sin(dir.z * 2.4 + s * 0.2)
			v.z += 0.035 * cos(dir.x * 2.7 - s * 0.16)
			verts.append(v)

	var indices := PackedInt32Array()
	for iy in rings:
		for ix in segments:
			var a := iy * segments + ix
			var b := iy * segments + (ix + 1) % segments
			var c := (iy + 1) * segments + ix
			var d := (iy + 1) * segments + (ix + 1) % segments
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	for v in verts:
		st.add_vertex(v)
	for idx in indices:
		st.add_index(idx)
	st.generate_normals()
	return st.commit()


func _apply_shared_params(mat: ShaderMaterial) -> void:
	for key in _shared_params:
		mat.set_shader_parameter(key, _shared_params[key])


func set_shared_param(name: String, value: Variant) -> void:
	_shared_params[name] = value
	for mat in [floor_material] + rock_materials:
		if mat != null:
			mat.set_shader_parameter(name, value)


func get_shared_param(name: String) -> Variant:
	return _shared_params.get(name)


func all_caustic_materials() -> Array[ShaderMaterial]:
	var mats: Array[ShaderMaterial] = [floor_material]
	mats.append_array(rock_materials)
	return mats


func set_time(value: float) -> void:
	set_shared_param("u_time", value)
	if water_material != null:
		water_material.set_shader_parameter("u_time", value)
