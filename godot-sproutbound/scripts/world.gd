extends Node3D
class_name SproutWorld

## 苔野远行 — 程序化低模草甸。
## 一块 76×64m 的向阳草甸，被木栅栏分成两片空地；北端石拱门在菌怪清空后开启。
## 地面 / 草叶 / 花 / 树 / 石头 / 栅栏 / 云 / 光尘全部程序化生成，无外部素材。

const GROUND_W := 76.0
const GROUND_D := 64.0
const GROUND_C := Vector3(0.0, 0.0, 18.0)
const PORTAL_POS := Vector3(0.0, 0.0, 39.2)
const PORTAL_TRIGGER := 2.3

const ENEMY_SPAWNS := [
	{"kind": "cap", "pos": Vector3(-4.5, 0.0, 6.0)},
	{"kind": "cap", "pos": Vector3(5.0, 0.0, 8.5)},
	{"kind": "cap", "pos": Vector3(-7.5, 0.0, 13.5)},
	{"kind": "cap", "pos": Vector3(4.5, 0.0, 15.5)},
	{"kind": "spitter", "pos": Vector3(10.5, 0.0, 11.0)},
	{"kind": "cap", "pos": Vector3(-5.0, 0.0, 25.0)},
	{"kind": "cap", "pos": Vector3(6.5, 0.0, 26.5)},
	{"kind": "spitter", "pos": Vector3(-9.5, 0.0, 31.0)},
	{"kind": "warden", "pos": Vector3(1.0, 0.0, 30.5)},
	{"kind": "cap", "pos": Vector3(7.5, 0.0, 33.5)},
]

const SEED_SPOTS := [
	Vector3(-11.5, 0.0, 2.0),
	Vector3(12.0, 0.0, 4.8),
	Vector3(-13.0, 0.0, 21.0),
	Vector3(13.0, 0.0, 24.0),
	Vector3(-6.0, 0.0, 35.5),
	Vector3(9.0, 0.0, 36.0),
	Vector3(-16.0, 0.0, 15.5),
	Vector3(16.5, 0.0, 17.0),
]

const HEART_SPOTS := [
	Vector3(-2.0, 0.0, 10.5),
	Vector3(8.0, 0.0, 21.5),
	Vector3(0.0, 0.0, 34.0),
]

const FENCE_LINES := [
	[Vector3(-17.0, 0.0, -8.0), Vector3(-17.0, 0.0, 18.0)],
	[Vector3(17.0, 0.0, -8.0), Vector3(17.0, 0.0, 18.0)],
	[Vector3(-17.0, 0.0, -8.0), Vector3(17.0, 0.0, -8.0)],
	[Vector3(-17.0, 0.0, 18.0), Vector3(-3.4, 0.0, 18.0)],
	[Vector3(3.4, 0.0, 18.0), Vector3(17.0, 0.0, 18.0)],
	[Vector3(-14.0, 0.0, 22.0), Vector3(-14.0, 0.0, 42.0)],
	[Vector3(14.0, 0.0, 22.0), Vector3(14.0, 0.0, 42.0)],
]

var portal_active := false
var portal_root: Node3D
var portal_field: MeshInstance3D
var portal_field_mat: ShaderMaterial
var portal_rings: Array[MeshInstance3D] = []
var portal_rune_mats: Array[StandardMaterial3D] = []
var portal_light: OmniLight3D
var portal_motes: CPUParticles3D

var _t := 0.0
var _portal_glow := 0.0
var _rng := RandomNumberGenerator.new()
var _contact_shadows: Array[Transform3D] = []


func _ready() -> void:
	_rng.seed = 20261126
	_build_environment()
	_build_ground()
	_build_path_stones()
	_build_grass()
	_build_flowers()
	_build_trees()
	_build_bushes()
	_build_rocks()
	_build_fences()
	_build_portal()
	_build_motes()
	_build_contact_shadows()


func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if portal_active else 0.0
	_portal_glow = move_toward(_portal_glow, target, delta * 1.4)
	if portal_field_mat != null:
		portal_field_mat.set_shader_parameter("active_amount", _portal_glow)
	if portal_light != null:
		portal_light.light_energy = lerpf(0.0, 3.2, _portal_glow) * (0.9 + 0.1 * sin(_t * 3.1))
	if portal_motes != null:
		portal_motes.emitting = portal_active
	for i in portal_rune_mats.size():
		portal_rune_mats[i].emission_energy_multiplier = \
			(0.35 + 0.25 * sin(_t * 2.0 + i)) + _portal_glow * 2.2
	for ring in portal_rings:
		if ring != null:
			ring.scale = Vector3.ONE * (1.0 + 0.025 * sin(_t * 1.4) * _portal_glow)


func set_portal_active(active: bool) -> void:
	portal_active = active


func get_portal_pos() -> Vector3:
	return PORTAL_POS


func ground_y(x: float, z: float) -> float:
	return _ground_height(x, z)


func get_enemy_spawn_defs() -> Array:
	return ENEMY_SPAWNS


# ---------------------------------------------------------------- environment

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SproutStyle.SKY_TOP
	sky_mat.sky_horizon_color = SproutStyle.SKY_HORIZON
	sky_mat.sky_curve = 0.16
	sky_mat.sky_energy_multiplier = 0.95
	sky_mat.ground_bottom_color = Color(0.36, 0.46, 0.31)
	sky_mat.ground_horizon_color = Color(0.73, 0.81, 0.72)
	sky_mat.sun_angle_max = 24.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.53
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.12
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.71, 0.83, 0.79)
	env.fog_light_energy = 0.58
	env.fog_density = 0.0038
	env.fog_sky_affect = 0.16
	env.fog_aerial_perspective = 0.28
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.79)
	sun.light_energy = 1.6
	# 该 Intel/GL 组合上方向光实时阴影无可见输出且增加约 270 个阴影 pass 绘制，
	# 因此改用程序化接地阴影（soft_shadow.gdshader），见 TECH.md。
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 34.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation_degrees = Vector3(-28.0, 142.0, 0.0)
	fill.light_color = Color(0.62, 0.78, 0.96)
	fill.light_energy = 0.16
	fill.shadow_enabled = false
	add_child(fill)


# -------------------------------------------------------------------- ground

func _ground_height(x: float, z: float) -> float:
	var edge := smoothstep(24.0, 34.0, absf(x)) + smoothstep(36.0, 48.0, z) \
		+ smoothstep(6.0, 12.0, -z)
	var h := sin(x * 0.33) * cos(z * 0.27) * 0.075 \
		+ sin(x * 0.91 + 1.3) * sin(z * 0.73) * 0.045
	var path_mask := smoothstep(2.6, 5.0, absf(x))
	h *= lerpf(0.2, 1.0, path_mask)
	return h + edge * 0.55 * (0.55 + 0.45 * sin(x * 0.17 + z * 0.13))


func _ground_color(x: float, z: float, h: float) -> Color:
	var w := 0.5 + 0.5 * sin(x * 0.21 + z * 0.17) * cos(z * 0.13 - x * 0.09)
	var c: Color = SproutStyle.GRASS_A.lerp(SproutStyle.GRASS_B, w)
	var path_center := sin(z * 0.09) * 0.7
	var path_d := absf(x - path_center)
	if z > -7.0 and z < 39.5:
		var path := 1.0 - smoothstep(2.1, 3.4, path_d)
		c = c.lerp(SproutStyle.PATH, path * 0.9)
	var rim := smoothstep(0.25, 0.85, h)
	c = c.lerp(SproutStyle.GRASS_DARK, rim * 0.55)
	c = c.lerp(SproutStyle.PATH.darkened(0.18), 0.12 * (0.5 + 0.5 * sin(x * 0.7 + z * 0.4)))
	return c


func _build_ground() -> void:
	var nx := 76
	var nz := 64
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for iz in nz + 1:
		for ix in nx + 1:
			var x := -GROUND_W * 0.5 + GROUND_W * float(ix) / float(nx)
			var z := GROUND_C.z - GROUND_D * 0.5 + GROUND_D * float(iz) / float(nz)
			var h := _ground_height(x, z)
			verts.append(Vector3(x, h, z + 0.0))
			colors.append(_ground_color(x, z, h))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz:
		for ix in nx:
			var a := iz * (nx + 1) + ix
			var b := a + 1
			var c := a + (nx + 1)
			var d := c + 1
			for idx in [a, c, b, b, c, d]:
				st.set_color(colors[idx])
				st.set_normal(_ground_normal(verts[idx]))
				st.add_vertex(verts[idx])
	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.98
	mat.metallic_specular = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	# 用 HeightMapShape3D 做地面碰撞：比运行时 trimesh 更稳，也更省。
	var hm := HeightMapShape3D.new()
	hm.map_width = nx + 1
	hm.map_depth = nz + 1
	var heights := PackedFloat32Array()
	for iz2 in nz + 1:
		for ix2 in nx + 1:
			var x2 := -GROUND_W * 0.5 + GROUND_W * float(ix2) / float(nx)
			var z2 := GROUND_C.z - GROUND_D * 0.5 + GROUND_D * float(iz2) / float(nz)
			heights.append(_ground_height(x2, z2))
	hm.map_data = heights
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0.0, 0.0, GROUND_C.z)
	var col := CollisionShape3D.new()
	col.shape = hm
	body.add_child(col)
	add_child(body)


func _ground_normal(p: Vector3) -> Vector3:
	var e := 0.35
	var dx := _ground_height(p.x + e, p.z) - _ground_height(p.x - e, p.z)
	var dz := _ground_height(p.x, p.z + e) - _ground_height(p.x, p.z - e)
	return Vector3(-dx / (2.0 * e), 1.0, -dz / (2.0 * e)).normalized()


func _build_path_stones() -> void:
	var stone := StandardMaterial3D.new()
	stone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stone.albedo_color = Color(0.62, 0.55, 0.39)
	var mesh := SproutStyle.low_cylinder(0.22, 0.27, 0.04, 6)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 26
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "PathStones"
	mmi.multimesh = mm
	mmi.material_override = stone
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	mm.custom_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 3.0, 46.0))
	for i in 26:
		var z := -2.0 + i * 1.55 + _rng.randf_range(-0.35, 0.35)
		var x := sin(z * 0.09) * 0.7 + _rng.randf_range(-0.55, 0.55)
		var s := _rng.randf_range(0.6, 1.05)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(
			Vector3(s, _rng.randf_range(0.5, 1.0), s))
		mm.set_instance_transform(i, Transform3D(basis,
			Vector3(x, _ground_height(x, z) + 0.02, z)))


# ---------------------------------------------------------------- vegetation

func _grass_blade_mesh(height: float, c_base: Color, c_tip: Color) -> ArrayMesh:
	# 3 片交叉叶片，每片 2 个三角形；UV.y 供风摆做着根权重。
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in 3:
		var yaw := float(b) * PI / 3.0 + 0.25
		var dir := Vector3(sin(yaw), 0.0, cos(yaw))
		var side := Vector3(cos(yaw), 0.0, -sin(yaw))
		var w := 0.03
		var tip := 0.005
		var lean := 0.05 + 0.035 * float(b % 2)
		var p0 := -side * w * 0.5
		var p1 := side * w * 0.5
		var p2 := side * tip * 0.5 + dir * lean + Vector3.UP * height
		var p3 := -side * tip * 0.5 + dir * lean + Vector3.UP * height
		var verts := [p0, p1, p2, p0, p2, p3]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),
			Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
		var cols := [c_base, c_base, c_tip, c_base, c_tip, c_tip]
		for k in 6:
			st.set_color(cols[k])
			st.set_uv(uvs[k])
			st.set_normal(Vector3.UP)
			st.add_vertex(verts[k])
	return st.commit()


func _build_grass() -> void:
	var shader: Shader = load("res://shaders/grass_wind.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("sway_amount", 0.05)
	mat.set_shader_parameter("sway_speed", 1.7)

	var mesh_a := _grass_blade_mesh(0.31, Color(0.09, 0.21, 0.03), Color(0.28, 0.50, 0.12))
	var mesh_b := _grass_blade_mesh(0.23, Color(0.12, 0.25, 0.05), Color(0.35, 0.55, 0.14))

	var mm_a := MultiMesh.new()
	mm_a.transform_format = MultiMesh.TRANSFORM_3D
	mm_a.mesh = mesh_a
	mm_a.instance_count = 4200
	var mmi_a := MultiMeshInstance3D.new()
	mmi_a.name = "GrassA"
	mmi_a.multimesh = mm_a
	mmi_a.material_override = mat
	mmi_a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi_a.visibility_range_end = 60.0
	mm_a.custom_aabb = AABB(Vector3(-32.0, -2.0, -12.0), Vector3(64.0, 8.0, 60.0))
	add_child(mmi_a)

	var mm_b := MultiMesh.new()
	mm_b.transform_format = MultiMesh.TRANSFORM_3D
	mm_b.mesh = mesh_b
	mm_b.instance_count = 2600
	var mmi_b := MultiMeshInstance3D.new()
	mmi_b.name = "GrassB"
	mmi_b.multimesh = mm_b
	mmi_b.material_override = mat
	mmi_b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi_b.visibility_range_end = 55.0
	mm_b.custom_aabb = AABB(Vector3(-28.0, -2.0, -12.0), Vector3(56.0, 8.0, 60.0))
	add_child(mmi_b)

	for i in 4200:
		var x := _rng.randf_range(-27.0, 27.0)
		var z := _rng.randf_range(-9.0, 46.0)
		var pd := absf(x - sin(z * 0.09) * 0.7)
		if pd < 2.2:
			x += 2.8 * (1.0 if x >= 0.0 else -1.0)
		var s := _rng.randf_range(0.7, 1.35)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
		mm_a.set_instance_transform(i, Transform3D(basis,
			Vector3(x, _ground_height(x, z) - 0.01, z)))
	for i in 2600:
		var x := _rng.randf_range(-22.0, 22.0)
		var z := _rng.randf_range(-8.0, 45.0)
		if absf(x - sin(z * 0.09) * 0.7) < 2.4:
			x += 2.5 * (1.0 if x >= 0.0 else -1.0)
		var s := _rng.randf_range(0.65, 1.25)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
		mm_b.set_instance_transform(i, Transform3D(basis,
			Vector3(x, _ground_height(x, z) - 0.01, z)))

	# 栅栏脚下的高草簇
	var mesh_c := _grass_blade_mesh(0.54, Color(0.10, 0.24, 0.04), Color(0.32, 0.52, 0.11))
	var mm_c := MultiMesh.new()
	mm_c.transform_format = MultiMesh.TRANSFORM_3D
	mm_c.mesh = mesh_c
	mm_c.instance_count = 300
	var mmi_c := MultiMeshInstance3D.new()
	mmi_c.name = "GrassTall"
	mmi_c.multimesh = mm_c
	mmi_c.material_override = mat
	mmi_c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi_c.visibility_range_end = 50.0
	mm_c.custom_aabb = AABB(Vector3(-20.0, -2.0, -10.0), Vector3(40.0, 8.0, 30.0))
	add_child(mmi_c)
	for i in 300:
		var side := 1.0 if i % 2 == 0 else -1.0
		var x := side * _rng.randf_range(16.2, 18.4)
		var z := _rng.randf_range(-8.0, 17.6)
		var s := _rng.randf_range(0.85, 1.5)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
		mm_c.set_instance_transform(i, Transform3D(basis,
			Vector3(x, _ground_height(x, z) - 0.01, z)))


func _flower_mesh(petal: Color, stem_h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem_lo := Color(0.30, 0.48, 0.24)
	var stem_hi := Color(0.40, 0.60, 0.30)
	for k in 2:
		var yaw := float(k) * PI / 2.0
		var side := Vector3(cos(yaw), 0.0, -sin(yaw)) * 0.015
		var verts := [-side, side, side + Vector3.UP * stem_h,
			-side, side + Vector3.UP * stem_h, -side + Vector3.UP * stem_h]
		var cols := [stem_lo, stem_lo, stem_hi, stem_lo, stem_hi, stem_hi]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),
			Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
		for i in 6:
			st.set_color(cols[i])
			st.set_uv(uvs[i])
			st.set_normal(Vector3.UP)
			st.add_vertex(verts[i])
	# 5 片花瓣：朝上的小三角
	var center := Vector3(0.0, stem_h, 0.0)
	for p in 5:
		var a := float(p) * TAU / 5.0
		var d := Vector3(sin(a), 0.0, cos(a))
		var side := Vector3(cos(a), 0.0, -sin(a))
		var tip := center + d * 0.16 + Vector3.UP * 0.02
		var l := center + side * 0.055 + d * 0.02
		var r := center - side * 0.055 + d * 0.02
		var cols2 := [petal, petal.darkened(0.08), petal.lightened(0.18)]
		var verts2 := [center, l, tip, center, tip, r]
		var uvs2 := [Vector2(0.5, 0.5), Vector2(0, 1), Vector2(1, 1),
			Vector2(0.5, 0.5), Vector2(1, 1), Vector2(0, 1)]
		for i in 6:
			st.set_color(cols2[i % 3])
			st.set_uv(uvs2[i])
			st.set_normal(Vector3.UP)
			st.add_vertex(verts2[i])
	# 花心
	var heart := Color(0.96, 0.80, 0.34)
	for p in 6:
		var a := float(p) * TAU / 6.0
		var a2 := float(p + 1) * TAU / 6.0
		var c := center + Vector3(0.0, 0.028, 0.0)
		for v in [c, c + Vector3(sin(a), 0.0, cos(a)) * 0.035,
				c + Vector3(sin(a2), 0.0, cos(a2)) * 0.035]:
			st.set_color(heart)
			st.set_uv(Vector2(0.5, 0.5))
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


func _build_flowers() -> void:
	var shader: Shader = load("res://shaders/grass_wind.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("sway_amount", 0.028)
	mat.set_shader_parameter("sway_speed", 1.5)
	var variants := [
		{"color": Color(0.98, 0.96, 0.86), "mesh": _flower_mesh(Color(0.98, 0.96, 0.86), 0.4)},
		{"color": Color(1.0, 0.84, 0.42), "mesh": _flower_mesh(Color(1.0, 0.84, 0.42), 0.32)},
		{"color": Color(0.94, 0.62, 0.68), "mesh": _flower_mesh(Color(0.94, 0.62, 0.68), 0.46)},
	]
	for vi in variants.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = variants[vi].mesh
		mm.instance_count = 64
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Flowers%d" % vi
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 45.0
		mm.custom_aabb = AABB(Vector3(-18.0, -1.0, -8.0), Vector3(36.0, 4.0, 52.0))
		add_child(mmi)
		var placed := 0
		while placed < 64:
			var x := _rng.randf_range(-15.5, 15.5)
			var z := _rng.randf_range(-7.0, 42.0)
			if absf(x - sin(z * 0.09) * 0.7) < 2.6:
				continue
			var s := _rng.randf_range(0.95, 1.55)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
			mm.set_instance_transform(placed, Transform3D(basis,
				Vector3(x, _ground_height(x, z) - 0.01, z)))
			placed += 1


func _build_trees() -> void:
	var trunk_mat := SproutStyle.mat(SproutStyle.TRUNK, 0.95)
	var leaf_mat_a := SproutStyle.mat(SproutStyle.LEAF_A, 0.92)
	var leaf_mat_b := SproutStyle.mat(SproutStyle.LEAF_B, 0.92)
	var trunk_mesh := SproutStyle.low_cylinder(0.16, 0.3, 2.3, 6)
	var leaf_mesh := SproutStyle.low_sphere(1.0, 7, 4)
	var leaf_mesh_b := SproutStyle.low_sphere(0.72, 6, 3)

	var trees := [
		Vector3(-14.0, 0.0, 2.0), Vector3(15.5, 0.0, 3.2),
		Vector3(-18.5, 0.0, 15.0), Vector3(19.5, 0.0, 17.5),
		Vector3(-12.5, 0.0, 21.5), Vector3(16.0, 0.0, 23.5),
		Vector3(-17.5, 0.0, 33.0), Vector3(17.0, 0.0, 35.5),
		Vector3(-23.0, 0.0, 8.0), Vector3(24.5, 0.0, 10.5),
		Vector3(-25.0, 0.0, 29.0), Vector3(25.5, 0.0, 31.0),
		Vector3(-7.5, 0.0, 43.5), Vector3(8.5, 0.0, 44.0),
		Vector3(0.0, 0.0, 47.5), Vector3(-21.0, 0.0, 44.5),
		Vector3(21.5, 0.0, 45.0),
	]
	var far_trees: Array[Vector3] = []
	for i in 18:
		var a := -PI * 0.15 + PI * 1.3 * float(i) / 17.0
		far_trees.append(Vector3(sin(a) * _rng.randf_range(33.0, 40.0),
			0.0, 19.0 + cos(a) * _rng.randf_range(28.0, 36.0)))

	var trunk_xf: Array[Transform3D] = []
	var leaf_a_xf: Array[Transform3D] = []
	var leaf_b_xf: Array[Transform3D] = []
	var leaf_colors: Array[Color] = []
	for i in trees.size() + far_trees.size():
		var base: Vector3 = trees[i] if i < trees.size() else far_trees[i - trees.size()]
		var near := i < trees.size()
		var scale := _rng.randf_range(0.85, 1.35) * (1.0 if near else _rng.randf_range(0.8, 1.1))
		var yaw := _rng.randf() * TAU
		var h := _ground_height(base.x, base.z)
		var root := Vector3(base.x, h, base.z)
		var tl := _rng.randf_range(0.95, 1.25) * scale
		trunk_xf.append(Transform3D(
			Basis(Vector3.UP, yaw).scaled(Vector3(scale, tl, scale)),
			root + Vector3(0.0, 1.15 * tl, 0.0)))
		var top := root + Vector3(0.0, 2.3 * tl, 0.0)
		var crown := Vector3(scale * _rng.randf_range(1.45, 1.95),
			scale * _rng.randf_range(1.15, 1.55), scale * _rng.randf_range(1.45, 1.95))
		var tint := Color(1.0, 1.0, 1.0).lerp(
			Color(0.82, 0.94, 0.72), _rng.randf() * 0.5)
		leaf_a_xf.append(Transform3D(
			Basis(Vector3.UP, yaw).scaled(crown), top + Vector3(0, 0.7 * scale, 0)))
		leaf_colors.append(tint)
		for k in 2:
			var off := Vector3(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.1, 0.5),
				_rng.randf_range(-0.7, 0.7)) * scale
			var sc := _rng.randf_range(0.65, 1.05) * scale
			leaf_b_xf.append(Transform3D(
				Basis(Vector3.UP, yaw + 1.3).scaled(Vector3(sc, sc * 0.9, sc)),
				top + off + Vector3(0.0, 0.55, 0.0)))
			leaf_colors.append(tint)
		_contact_shadows.append(Transform3D(
			Basis(Vector3.UP, yaw).scaled(Vector3(crown.x * 1.25, 1.0, crown.z * 1.25)),
			root + Vector3(0.55 * scale, 0.025, -0.45 * scale)))
		if near:
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.position = root + Vector3(0.0, 1.2, 0.0)
			var cs := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = 0.34 * scale
			shape.height = 2.4
			cs.shape = shape
			body.add_child(cs)
			add_child(body)

	_make_multimesh("TreeTrunks", trunk_mesh, trunk_mat, trunk_xf, true, false)
	_make_multimesh("TreeLeavesA", leaf_mesh, leaf_mat_a, leaf_a_xf, true, true, leaf_colors)
	var leaf_colors_b: Array[Color] = []
	for i in leaf_b_xf.size():
		leaf_colors_b.append(leaf_colors[i % leaf_colors.size()])
	_make_multimesh("TreeLeavesB", leaf_mesh_b, leaf_mat_b, leaf_b_xf, true, true, leaf_colors_b)


func _make_multimesh(node_name: String, mesh: Mesh, mat: Material,
		xf: Array, shadows: bool, colors_used: bool,
		colors: Array = []) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.use_colors = colors_used and not colors.is_empty()
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i % colors.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# 手动设置 AABB：MultiMesh 不会自动重算实例包围盒，否则整批会被错误剔除
	var box := AABB()
	var first := true
	for xf_one in xf:
		var b := _transform_aabb(mesh.get_aabb(), xf_one)
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	if not first:
		mm.custom_aabb = box.grow(0.35)
	# MultiMesh 实例色需要材质开启顶点色通道才能作为乘色
	if mm.use_colors:
		mat.vertex_color_use_as_albedo = true


func _transform_aabb(local: AABB, xf: Transform3D) -> AABB:
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for i in 8:
		var corner := local.position + Vector3(
			local.size.x if (i & 1) != 0 else 0.0,
			local.size.y if (i & 2) != 0 else 0.0,
			local.size.z if (i & 4) != 0 else 0.0)
		var p := xf * corner
		mn = mn.min(p)
		mx = mx.max(p)
	return AABB(mn, mx - mn)


func _build_bushes() -> void:
	var mat := SproutStyle.mat(Color.WHITE, 0.94)
	var mesh := SproutStyle.low_sphere(0.55, 6, 3)
	var centers := [
		Vector3(-13.2, 0.0, 4.5), Vector3(13.8, 0.0, 6.0),
		Vector3(-15.5, 0.0, 22.0), Vector3(15.2, 0.0, 24.5),
		Vector3(-9.0, 0.0, 18.5), Vector3(9.5, 0.0, 19.5),
		Vector3(-11.5, 0.0, 30.5), Vector3(10.5, 0.0, 31.5),
		Vector3(-5.0, 0.0, 42.5), Vector3(5.5, 0.0, 42.0),
		Vector3(-20.0, 0.0, 12.0), Vector3(20.5, 0.0, 14.5),
		Vector3(-21.5, 0.0, 33.0), Vector3(22.0, 0.0, 35.0),
		Vector3(-3.0, 0.0, -5.5), Vector3(6.0, 0.0, -6.0),
		Vector3(12.0, 0.0, 38.5), Vector3(-12.5, 0.0, 38.0),
	]
	var xf: Array[Transform3D] = []
	var colors: Array[Color] = []
	var palette := [
		Color(0.30, 0.52, 0.21), Color(0.24, 0.45, 0.18),
		Color(0.38, 0.58, 0.24), Color(0.28, 0.48, 0.20),
	]
	for c in centers:
		var base: Vector3 = c
		base.y = _ground_height(base.x, base.z)
		for k in 2:
			var off := Vector3(_rng.randf_range(-0.55, 0.55), 0.0,
				_rng.randf_range(-0.5, 0.5))
			var sc := _rng.randf_range(0.75, 1.5)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(
				Vector3(sc * 1.3, sc * 0.72, sc * 1.2))
			xf.append(Transform3D(basis, base + off + Vector3(0.0, 0.3 * sc, 0.0)))
			colors.append(palette[_rng.randi_range(0, palette.size() - 1)])
			_contact_shadows.append(Transform3D(
				Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc * 1.25, 1.0, sc * 1.15)),
				base + off + Vector3(0.25 * sc, 0.021, -0.2 * sc)))
	var flower_mesh := SproutStyle.low_sphere(0.07, 5, 3)
	var fl_xf: Array[Transform3D] = []
	var fl_colors: Array[Color] = []
	for c in centers:
		var base: Vector3 = c
		base.y = _ground_height(base.x, base.z)
		for k in 3:
			var off := Vector3(_rng.randf_range(-1.4, 1.4), _rng.randf_range(0.28, 0.5),
				_rng.randf_range(-1.4, 1.4))
			fl_xf.append(Transform3D(Basis.from_scale(Vector3(1.0, 0.5, 1.0)),
				base + off))
			fl_colors.append(palette[k % palette.size()].lightened(0.45))
	_make_multimesh("Bushes", mesh, mat, xf, false, true, colors)
	_make_multimesh("BushFlowers", flower_mesh, mat, fl_xf, false, true, fl_colors)


func _build_rocks() -> void:
	var rock_mat := SproutStyle.mat(SproutStyle.STONE, 0.98)
	rock_mat.metallic_specular = 0.0
	var moss_mat := SproutStyle.mat(Color(0.45, 0.60, 0.34), 0.95)
	var rock_mesh := SproutStyle.low_sphere(0.7, 5, 3)
	var moss_mesh := SproutStyle.low_sphere(0.32, 5, 2)
	var spots := [
		Vector3(-11.0, 0.0, -3.0), Vector3(12.0, 0.0, -2.5),
		Vector3(-16.0, 0.0, 6.5), Vector3(16.5, 0.0, 7.5),
		Vector3(-9.0, 0.0, 17.8), Vector3(11.0, 0.0, 19.5),
		Vector3(-12.8, 0.0, 27.0), Vector3(12.5, 0.0, 28.5),
		Vector3(-6.5, 0.0, 39.0), Vector3(7.0, 0.0, 40.5),
		Vector3(-19.0, 0.0, 23.5), Vector3(21.0, 0.0, 26.0),
		Vector3(-20.0, 0.0, 36.0), Vector3(22.0, 0.0, 38.0),
		Vector3(2.0, 0.0, 43.0), Vector3(-3.0, 0.0, 44.0),
	]
	var rock_xf: Array[Transform3D] = []
	var moss_xf: Array[Transform3D] = []
	for i in spots.size():
		var p: Vector3 = spots[i]
		var h := _ground_height(p.x, p.z)
		var s := _rng.randf_range(0.7, 1.7)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(
			Vector3(s * 1.2, s * 0.7, s))
		rock_xf.append(Transform3D(basis, Vector3(p.x, h + s * 0.22, p.z)))
		_contact_shadows.append(Transform3D(
			Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s * 1.5, 1.0, s * 1.3)),
			Vector3(p.x + 0.5 * s, h + 0.022, p.z - 0.35 * s)))
		if i % 3 == 0:
			moss_xf.append(Transform3D(
				Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * 0.35, s)),
				Vector3(p.x, h + s * 0.55, p.z)))
		if s > 1.15 and absf(p.x) < 18.0:
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.position = Vector3(p.x, h + s * 0.2, p.z)
			var cs := CollisionShape3D.new()
			var shape := SphereShape3D.new()
			shape.radius = s * 0.6
			cs.shape = shape
			body.add_child(cs)
			add_child(body)
	_make_multimesh("Rocks", rock_mesh, rock_mat, rock_xf, true, false)
	if not moss_xf.is_empty():
		_make_multimesh("RockMoss", moss_mesh, moss_mat, moss_xf, false, false)


func _build_fences() -> void:
	var post_mat := SproutStyle.mat(Color(0.52, 0.39, 0.25), 0.95)
	var rail_mat := SproutStyle.mat(Color(0.58, 0.45, 0.30), 0.95)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.16, 1.06, 0.16)
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(1.0, 0.1, 0.07)
	var post_xf: Array[Transform3D] = []
	var rail_xf: Array[Transform3D] = []
	for line in FENCE_LINES:
		var a: Vector3 = line[0]
		var b: Vector3 = line[1]
		var delta := b - a
		var length := delta.length()
		var dir := delta / length
		var yaw := atan2(-dir.z, dir.x)
		var count := maxi(2, int(round(length / 2.0)) + 1)
		for i in count:
			var t := float(i) / float(count - 1)
			var p := a.lerp(b, t)
			var h := _ground_height(p.x, p.z)
			post_xf.append(Transform3D(
				Basis(Vector3.UP, yaw + _rng.randf_range(-0.03, 0.03)),
				Vector3(p.x, h + 0.53, p.z)))
			if i < count - 1:
				var t2 := float(i + 0.5) / float(count - 1)
				var mid := a.lerp(b, t2)
				var mh := _ground_height(mid.x, mid.z)
				var seg_len := length / float(count - 1)
				for rail_y in [0.42, 0.82]:
					var basis := Basis(Vector3.UP, yaw).scaled(
						Vector3(seg_len, 1.0, 1.0))
					rail_xf.append(Transform3D(basis,
						Vector3(mid.x, mh + rail_y, mid.z)))
		# 碰撞：按整段一条薄墙，避免穿栏
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var mid_all: Vector3 = a.lerp(b, 0.5)
		body.position = Vector3(mid_all.x, _ground_height(mid_all.x, mid_all.z) + 0.55, mid_all.z)
		body.rotation.y = yaw
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(length, 1.1, 0.16)
		cs.shape = shape
		body.add_child(cs)
		add_child(body)
	_make_multimesh("FencePosts", post_mesh, post_mat, post_xf, true, false)
	_make_multimesh("FenceRails", rail_mesh, rail_mat, rail_xf, true, false)


func _build_clouds() -> void:
	var mat := SproutStyle.unshaded(Color(0.98, 0.99, 0.97, 0.92))
	var puff := SproutStyle.low_sphere(1.0, 7, 4)
	var clusters := [
		Vector3(-36.0, 30.0, 82.0), Vector3(14.0, 34.0, 92.0),
		Vector3(48.0, 28.0, 74.0), Vector3(-62.0, 36.0, 38.0),
	]
	for c in clusters:
		var root := Node3D.new()
		root.position = c
		add_child(root)
		for i in 3:
			var mi := MeshInstance3D.new()
			mi.mesh = puff
			mi.material_override = mat
			mi.position = Vector3(float(i) * 2.6 - 2.6, _rng.randf_range(-0.3, 0.4),
				_rng.randf_range(-0.6, 0.6))
			mi.scale = Vector3(_rng.randf_range(2.8, 4.8), _rng.randf_range(1.0, 1.5),
				_rng.randf_range(1.8, 2.6))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)


func _build_contact_shadows() -> void:
	if _contact_shadows.is_empty():
		return
	var disc := SproutStyle.low_cylinder(1.0, 1.0, 0.01, 20)
	var core: Array[Transform3D] = []
	var halo: Array[Transform3D] = []
	for xf in _contact_shadows:
		core.append(xf)
		var b := xf.basis
		var p0 := xf.origin
		halo.append(Transform3D(
			b.scaled(Vector3(1.45, 1.0, 1.45)),
			Vector3(p0.x, p0.y - 0.003, p0.z)))
	_make_shadow_layer("ContactShadowHalo", disc, halo,
		Color(0.05, 0.09, 0.045, 0.10))
	_make_shadow_layer("ContactShadows", disc, core,
		Color(0.05, 0.09, 0.045, 0.28))


func _make_shadow_layer(node_name: String, disc: CylinderMesh,
		xfs: Array, tint: Color) -> void:
	var mat := SproutStyle.unshaded(tint)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = disc
	mm.instance_count = xfs.size()
	var box := AABB()
	var first := true
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		var b := _transform_aabb(disc.get_aabb(), xfs[i])
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	mm.custom_aabb = box.grow(0.5)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_motes() -> void:
	var p := CPUParticles3D.new()
	p.name = "Motes"
	p.amount = 42
	p.lifetime = 9.0
	p.position = Vector3(0.0, 2.4, 18.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22.0, 2.2, 26.0)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 180.0
	p.initial_velocity_min = 0.04
	p.initial_velocity_max = 0.22
	p.gravity = Vector3(0.03, 0.01, 0.02)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.8
	p.color = Color(1.0, 0.95, 0.66, 0.55)
	var mesh := SproutStyle.low_sphere(0.06, 4, 2)
	var mat := SproutStyle.unshaded(Color(1.0, 0.96, 0.72, 0.8), true)
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.mesh = mesh
	p.emitting = true
	add_child(p)


# -------------------------------------------------------------------- portal

func _build_portal() -> void:
	portal_root = Node3D.new()
	portal_root.name = "Portal"
	portal_root.position = PORTAL_POS
	add_child(portal_root)

	var stone := SproutStyle.mat(Color(0.58, 0.56, 0.47), 0.98)
	stone.metallic_specular = 0.0
	var stone_dark := SproutStyle.mat(Color(0.44, 0.44, 0.37), 0.98)
	stone_dark.metallic_specular = 0.0
	var moss := SproutStyle.mat(Color(0.42, 0.58, 0.32), 0.95)

	# 拱门基座 + 立柱 + 门楣
	for side in [-1.0, 1.0]:
		var base := MeshInstance3D.new()
		base.mesh = BoxMesh.new()
		base.mesh.size = Vector3(1.25, 0.38, 1.3)
		base.material_override = stone_dark
		base.position = Vector3(1.72 * side, 0.19, 0.0)
		base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		portal_root.add_child(base)
		var pillar := MeshInstance3D.new()
		pillar.mesh = BoxMesh.new()
		pillar.mesh.size = Vector3(0.78, 3.35, 0.82)
		pillar.material_override = stone
		pillar.position = Vector3(1.72 * side, 1.95, 0.0)
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		portal_root.add_child(pillar)
		var cap := MeshInstance3D.new()
		cap.mesh = BoxMesh.new()
		cap.mesh.size = Vector3(1.02, 0.26, 1.04)
		cap.material_override = stone_dark
		cap.position = Vector3(1.72 * side, 3.72, 0.0)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		portal_root.add_child(cap)
		# 青苔斑点
		for k in 3:
			var m := MeshInstance3D.new()
			m.mesh = SproutStyle.low_sphere(0.22, 5, 2)
			m.material_override = moss
			m.position = Vector3(1.72 * side + _rng.randf_range(-0.3, 0.3),
				0.7 + k * 1.0, 0.42)
			m.scale = Vector3(1.0, 0.35, 0.5)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			portal_root.add_child(m)
		# 符石灯
		for k in 3:
			var rune_mat := SproutStyle.mat(Color(0.55, 0.95, 0.7), 0.4,
				Color(0.55, 1.0, 0.72), 1.0)
			rune_mat.emission_energy_multiplier = 0.35
			portal_rune_mats.append(rune_mat)
			var rune := MeshInstance3D.new()
			rune.mesh = BoxMesh.new()
			rune.mesh.size = Vector3(0.15, 0.24, 0.06)
			rune.material_override = rune_mat
			rune.position = Vector3(1.72 * side - 0.42 * side * 0.2, 1.2 + k * 0.75, -0.44)
			rune.rotation.z = PI / 4.0
			rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			portal_root.add_child(rune)

	var lintel := MeshInstance3D.new()
	lintel.mesh = BoxMesh.new()
	lintel.mesh.size = Vector3(5.0, 0.62, 0.9)
	lintel.material_override = stone
	lintel.position = Vector3(0.0, 3.95, 0.0)
	lintel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	portal_root.add_child(lintel)
	var lintel_top := MeshInstance3D.new()
	lintel_top.mesh = BoxMesh.new()
	lintel_top.mesh.size = Vector3(5.5, 0.22, 1.02)
	lintel_top.material_override = stone_dark
	lintel_top.position = Vector3(0.0, 4.34, 0.0)
	lintel_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	portal_root.add_child(lintel_top)
	# 门楣上的苔草
	for i in 7:
		var tuft := MeshInstance3D.new()
		tuft.mesh = SproutStyle.low_sphere(0.2, 5, 2)
		tuft.material_override = moss
		tuft.position = Vector3(_rng.randf_range(-2.2, 2.2), 4.48,
			_rng.randf_range(-0.35, 0.35))
		tuft.scale = Vector3(1.0, 0.4, 0.8)
		tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		portal_root.add_child(tuft)

	# 光场
	portal_field_mat = ShaderMaterial.new()
	portal_field_mat.shader = load("res://shaders/portal_field.gdshader")
	portal_field_mat.set_shader_parameter("active_amount", 0.0)
	portal_field = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.55, 2.95)
	portal_field.mesh = quad
	portal_field.material_override = portal_field_mat
	portal_field.position = Vector3(0.0, 2.02, 0.0)
	portal_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portal_root.add_child(portal_field)

	# 双环
	for i in 2:
		var ring_mat := SproutStyle.mat(Color(0.50, 0.94, 0.68), 0.4,
			Color(0.55, 1.0, 0.72), 1.0)
		ring_mat.emission_energy_multiplier = 0.8
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.31 + i * 0.18
		torus.outer_radius = 1.38 + i * 0.18
		torus.rings = 30
		torus.ring_segments = 5
		ring.mesh = torus
		ring.material_override = ring_mat
		ring.position = Vector3(0.0, 2.02, 0.06)
		ring.rotation.x = PI / 2.0
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		portal_root.add_child(ring)
		portal_rings.append(ring)

	# 地面圆坛与立石
	var disc := MeshInstance3D.new()
	disc.mesh = SproutStyle.low_cylinder(3.5, 3.7, 0.14, 16)
	disc.material_override = stone_dark
	disc.position = Vector3(0.0, 0.05, -0.6)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portal_root.add_child(disc)
	var circle := MeshInstance3D.new()
	var torus2 := TorusMesh.new()
	torus2.inner_radius = 2.55
	torus2.outer_radius = 2.85
	torus2.rings = 36
	torus2.ring_segments = 5
	circle.mesh = torus2
	circle.material_override = SproutStyle.mat(Color(0.66, 0.72, 0.60), 0.95)
	circle.position = Vector3(0.0, 0.13, -0.6)
	circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portal_root.add_child(circle)
	for i in 8:
		var a := float(i) * TAU / 8.0
		var mar := MeshInstance3D.new()
		mar.mesh = BoxMesh.new()
		mar.mesh.size = Vector3(0.18, _rng.randf_range(0.5, 0.9), 0.18)
		mar.material_override = stone
		mar.position = Vector3(sin(a) * 3.05, 0.3, cos(a) * 3.05 - 0.6)
		mar.rotation.y = a
		mar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		portal_root.add_child(mar)

	# 激活光
	portal_light = OmniLight3D.new()
	portal_light.position = Vector3(0.0, 2.0, -0.8)
	portal_light.light_color = Color(0.55, 1.0, 0.72)
	portal_light.omni_range = 9.0
	portal_light.light_energy = 0.0
	portal_light.shadow_enabled = false
	portal_root.add_child(portal_light)

	portal_motes = CPUParticles3D.new()
	portal_motes.amount = 26
	portal_motes.lifetime = 2.6
	portal_motes.position = Vector3(0.0, 1.6, 0.0)
	portal_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	portal_motes.emission_box_extents = Vector3(1.32, 1.5, 0.3)
	portal_motes.direction = Vector3(0.0, 1.0, 0.0)
	portal_motes.spread = 35.0
	portal_motes.initial_velocity_min = 0.25
	portal_motes.initial_velocity_max = 0.9
	portal_motes.gravity = Vector3(0.0, 0.15, 0.0)
	portal_motes.scale_amount_min = 0.25
	portal_motes.scale_amount_max = 0.7
	portal_motes.color = Color(0.7, 1.0, 0.8, 0.9)
	var mote_mesh := SproutStyle.low_sphere(0.045, 4, 2)
	var mote_mat := SproutStyle.unshaded(Color(0.8, 1.0, 0.85, 1.0), true)
	mote_mat.vertex_color_use_as_albedo = true
	mote_mesh.material = mote_mat
	portal_motes.mesh = mote_mesh
	portal_motes.emitting = false
	portal_root.add_child(portal_motes)

	# 拱门碰撞
	for side in [-1.0, 1.0]:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = PORTAL_POS + Vector3(1.72 * side, 1.8, 0.0)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.9, 3.6, 0.95)
		cs.shape = shape
		body.add_child(cs)
		add_child(body)
