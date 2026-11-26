class_name OceanScene
extends RefCounted

# 场景搭建与昼夜：海岛地形、植被、建筑、船、云、海鸥、鱼影、雨、天光。
# 颜色三层（白天/黄昏/夜晚）按太阳高度加权混合；所有道具均为程序化原创低模。

var parent: Node3D
var field: IslandField
var ocean: StylizedOcean

var terrain: MeshInstance3D
var sun: DirectionalLight3D
var env: Environment
var world_env: WorldEnvironment
var sky_dome: MeshInstance3D
var sky_material: ShaderMaterial
var cloud_material: ShaderMaterial

var hut: Node3D
var tower: Node3D
var boat: Node3D
var raft: Node3D
var boat_phase := 0.35
var raft_phase := 2.9
var boat_radius := 46.0
var raft_radius := 35.0

var shadow_multimesh: MultiMeshInstance3D
var hut_glow: MeshInstance3D
var tower_glow: MeshInstance3D
var _shadow_entries: Array[Dictionary] = []
var clouds: Array[Node3D] = []
var cloud_offsets: Array[float] = []
var birds: MultiMeshInstance3D
var bird_data: Array[Dictionary] = []
var fish: MultiMeshInstance3D
var fish_data: Array[Dictionary] = []

var rain: CPUParticles3D
var hut_light: OmniLight3D
var tower_light: OmniLight3D
var beacon_mat: StandardMaterial3D

var rock_material: ShaderMaterial
var terrain_material: ShaderMaterial
var palm_crown_material: ShaderMaterial
var grass_material: ShaderMaterial
var shrub_material: Material

var hour := 11.5
var night_weight := 0.0
var dusk_weight := 0.0
var day_weight := 1.0
var current_sun_dir := Vector3(0.3, 0.8, 0.25)
var palette: Dictionary = {}
var ambient_energy := 0.5

var _rng := RandomNumberGenerator.new()

# ── 三套调色板（对照参考帧采样） ────────────────────────────────
const DAY := {
	"deep": Color("#12669d"), "mid": Color("#1a74a8"), "shelf": Color("#1a97b3"),
	"lagoon": Color("#3fc4c5"), "sandwater": Color("#a8cbb8"),
	"sky_reflect": Color("#c2e9f2"), "foam": Color("#fbffff"),
	"caustic": Color("#eafff6"), "fog": Color("#b9dce8"),
	"sun": Color("#fff3dd"), "sky_zenith": Color("#2a7bc4"),
	"sky_horizon": Color("#cfeff7"), "sky_ground": Color("#8fc6d4"),
	"cloud_light": Color("#fffdf8"), "cloud_shade": Color("#c2d2e2"),
	"ambient": Color("#e2f0f5"), "sand_dry": Color("#ece5d3"),
	"sand_light": Color("#f6efdf"), "sand_damp": Color("#d3cbbc"),
	"sand_wet": Color("#b4ab98"), "sand_edge": Color("#8e948e"),
	"sand_under": Color("#c3ba9e"), "sand_deep": Color("#5f7c78"),
}
const DUSK := {
	"deep": Color("#1b4a6e"), "mid": Color("#2c6f8f"), "shelf": Color("#3f93a2"),
	"lagoon": Color("#67b8b4"), "sandwater": Color("#cbb999"),
	"sky_reflect": Color("#ffd2a6"), "foam": Color("#fff3e2"),
	"caustic": Color("#ffe6c4"), "fog": Color("#e8c6a2"),
	"sun": Color("#ffb16a"), "sky_zenith": Color("#4b6fa8"),
	"sky_horizon": Color("#ffc48c"), "sky_ground": Color("#a8795f"),
	"cloud_light": Color("#ffe6c9"), "cloud_shade": Color("#b58f9a"),
	"ambient": Color("#e9c4a3"), "sand_dry": Color("#eedcbf"),
	"sand_light": Color("#f8e8cc"), "sand_damp": Color("#d9c4a4"),
	"sand_wet": Color("#b7a58a"), "sand_edge": Color("#918b7d"),
	"sand_under": Color("#b8a98b"), "sand_deep": Color("#5c716e"),
}
const NIGHT := {
	"deep": Color("#0a2a4e"), "mid": Color("#0c3559"), "shelf": Color("#0f4767"),
	"lagoon": Color("#1a6576"), "sandwater": Color("#2d6f72"),
	"sky_reflect": Color("#17345c"), "foam": Color("#c6dcec"),
	"caustic": Color("#2f5f78"), "fog": Color("#12233a"),
	"sun": Color("#b9d2ff"), "sky_zenith": Color("#06101f"),
	"sky_horizon": Color("#132842"), "sky_ground": Color("#0a1826"),
	"cloud_light": Color("#9fb3c9"), "cloud_shade": Color("#4a5c74"),
	"ambient": Color("#5f7fa8"), "sand_dry": Color("#8f9cae"),
	"sand_light": Color("#a4b0c1"), "sand_damp": Color("#7d8b9d"),
	"sand_wet": Color("#6f7f92"), "sand_edge": Color("#5c6d7c"),
	"sand_under": Color("#6f7c85"), "sand_deep": Color("#40545f"),
}


func build(p_parent: Node3D, p_field: IslandField, p_ocean: StylizedOcean) -> void:
	parent = p_parent
	field = p_field
	ocean = p_ocean
	_rng.seed = 424242
	_build_environment()
	_build_terrain()
	_build_palms()
	_build_rocks()
	_build_ground_cover()
	_build_structures()
	_build_boats()
	_build_clouds()
	_build_birds()
	_build_fish()
	_build_rain()
	set_time(hour)
	_build_blob_shadows()
	_bake_shore_map()


# ───────────────────────── 环境 / 天空 / 光 ─────────────────────────
func _build_environment() -> void:
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#bfe4ee")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d7ecf5")
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0
	env.glow_enabled = false
	env.glow_intensity = 0.32
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("#b9dce8")
	env.fog_light_energy = 0.6
	env.fog_density = 0.0011
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.0
	world_env.environment = env
	parent.add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = false
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_split_1 = 0.35
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.4
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 0.0
	parent.add_child(sun)

	# 天空穹顶（半径 900，相机始终在内部；俯视时几乎不可见）
	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/sky_dome.gdshader")
	var dome := MeshInstance3D.new()
	dome.name = "SkyDome"
	var sphere := SphereMesh.new()
	sphere.radius = 900.0
	sphere.height = 1800.0
	sphere.radial_segments = 32
	sphere.rings = 16
	dome.mesh = sphere
	dome.material_override = sky_material
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.extra_cull_margin = 2000.0
	parent.add_child(dome)
	sky_dome = dome

	cloud_material = ShaderMaterial.new()
	cloud_material.shader = preload("res://shaders/cloud.gdshader")

	# 夜间灯晕（billboard 加法发光面）
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.albedo_texture = TexFactory.glow_texture()
	glow_mat.albedo_color = Color(1.0, 0.72, 0.42, 0.26)
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_mat.no_depth_test = false
	var glow_mesh := QuadMesh.new()
	glow_mesh.size = Vector2(7, 7)
	glow_mesh.material = glow_mat
	hut_glow = MeshInstance3D.new()
	hut_glow.name = "HutGlow"
	hut_glow.mesh = glow_mesh
	hut_glow.visible = false
	parent.add_child(hut_glow)
	var glow_mesh2 := QuadMesh.new()
	glow_mesh2.size = Vector2(10, 10)
	glow_mesh2.material = glow_mat
	tower_glow = MeshInstance3D.new()
	tower_glow.name = "TowerGlow"
	tower_glow.mesh = glow_mesh2
	tower_glow.visible = false
	parent.add_child(tower_glow)

	hut_light = OmniLight3D.new()
	hut_light.name = "HutLantern"
	hut_light.omni_range = 10.0
	hut_light.light_energy = 0.0
	hut_light.light_color = Color("#ffbd7a")
	parent.add_child(hut_light)
	tower_light = OmniLight3D.new()
	tower_light.name = "TowerBeaconLight"
	tower_light.omni_range = 14.0
	tower_light.light_energy = 0.0
	tower_light.light_color = Color("#ff9a5c")
	parent.add_child(tower_light)


func _build_terrain() -> void:
	# 近岸加密 + 水下环带延伸到 72 m：浅水改为真透明后，海底沙床要真实出现在水下，
	# 且要在水体 alpha 到 1 之前覆盖到 ~5.5 m 水深处，避免看到天空背景。
	var segs := 288
	var radii := PackedFloat32Array()
	var inner := 128
	for i in inner + 1:
		radii.append(38.0 * float(i) / float(inner))
	var r := 38.0
	var growth := pow(72.0 / 38.0, 1.0 / 28.0)
	for k in 28:
		r *= growth
		radii.append(r)
	var rings := radii.size() - 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in radii.size():
		var rr := radii[i]
		for j in segs:
			var a := TAU * float(j) / float(segs)
			var x := cos(a) * rr
			var z := sin(a) * rr
			var h := field.height(x, z)
			verts.append(Vector3(x, h, z))
			var e := 0.28
			var hx := field.height(x + e, z) - field.height(x - e, z)
			var hz := field.height(x, z + e) - field.height(x, z - e)
			normals.append(Vector3(-hx, 2.0 * e, -hz).normalized())
	for i in rings:
		for j in segs:
			var j2 := (j + 1) % segs
			var a := i * segs + j
			var b := i * segs + j2
			var c := (i + 1) * segs + j
			var d := (i + 1) * segs + j2
			indices.append_array([a, c, b, b, c, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	terrain = MeshInstance3D.new()
	terrain.name = "IslandTerrain"
	terrain.mesh = mesh
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = preload("res://shaders/terrain.gdshader")
	terrain_material.set_shader_parameter("foam_tex", TexFactory.foam_texture())
	terrain_material.set_shader_parameter("caustic_tex", TexFactory.caustic_texture())
	terrain_material.set_shader_parameter("shore_area", IslandField.AREA)
	terrain_material.set_shader_parameter("shore_range", IslandField.SHORE_RANGE * 2.0)
	terrain_material.set_shader_parameter("foam_amount", 0.85)
	terrain.material_override = terrain_material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(terrain)


# ───────────────────────── 棕榈 ─────────────────────────
var palm_positions: Array[Vector3] = []


# 岸距场烘焙：等棕榈/礁石都摆好后进行，把道具接触带一起写入 G 通道。
func _bake_shore_map() -> void:
	var t0 := Time.get_ticks_msec()
	var extras: Array[Dictionary] = []
	for p in palm_positions:
		if field.height(p.x, p.z) < 1.9:
			extras.append({"pos": Vector2(p.x, p.z), "core": 0.55, "width": 0.75, "weight": 0.5})
	var tex := field.bake_shore_texture(extras)
	ocean.set_shore_map(tex)
	if terrain_material != null:
		terrain_material.set_shader_parameter("shore_map", tex)
	print("[ocean] shore map 1024² baked in %d ms" % (Time.get_ticks_msec() - t0))


func _build_palms() -> void:
	var trunk_mesh := OceanProps.make_palm_trunk_mesh()
	var crown_mesh := OceanProps.make_palm_crown_mesh()
	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.mesh = trunk_mesh
	var crown_mm := MultiMesh.new()
	crown_mm.transform_format = MultiMesh.TRANSFORM_3D
	crown_mm.mesh = crown_mesh
	var positions: Array[Vector3] = []
	var attempts := 0
	while positions.size() < 21 and attempts < 260:
		attempts += 1
		var theta := _rng.randf_range(0.0, TAU)
		var r := sqrt(_rng.randf()) * 23.0 + 4.0
		var x := cos(theta) * r
		var z := sin(theta) * r
		var h := field.height(x, z)
		if h < 0.75:
			continue
		if absf(x - 2.5) < 4.0 and absf(z + 10.5) < 4.0:
			continue
		if absf(x + 9.5) < 6.0 and absf(z - 4.5) < 5.0:
			continue
		var ok := true
		for p in positions:
			if Vector2(p.x - x, p.z - z).length() < 3.1:
				ok = false
				break
		if ok:
			positions.append(Vector3(x, h, z))
	# 参考帧里棕榈更集中在岛缘：补几棵沿边缘
	for i in 6:
		var theta := TAU * (float(i) / 6.0) + 0.55
		var r := _rng.randf_range(20.0, 24.0)
		var x := cos(theta) * r
		var z := sin(theta) * r
		positions.append(Vector3(x, field.height(x, z), z))
	palm_positions = positions.duplicate()
	trunk_mm.instance_count = positions.size()
	crown_mm.use_custom_data = true
	crown_mm.instance_count = positions.size()
	for i in positions.size():
		var pos := positions[i]
		var s := _rng.randf_range(0.9, 1.35)
		var yaw := _rng.randf_range(0.0, TAU)
		var tilt := Vector3(_rng.randf_range(-0.05, 0.05), 0.0, _rng.randf_range(-0.05, 0.05))
		var basis := Basis.from_euler(Vector3(tilt.x, yaw, tilt.z)).scaled(Vector3(s, s, s))
		var tr := Transform3D(basis, pos - Vector3(0, 0.15, 0))
		trunk_mm.set_instance_transform(i, tr)
		crown_mm.set_instance_transform(i, tr)
		crown_mm.set_instance_custom_data(i, Color(_rng.randf(), 0, 0, 0))
	var trunk_mi := MultiMeshInstance3D.new()
	trunk_mi.name = "PalmTrunks"
	trunk_mi.multimesh = trunk_mm
	trunk_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(trunk_mi)
	var crown_mi := MultiMeshInstance3D.new()
	crown_mi.name = "PalmCrowns"
	crown_mi.multimesh = crown_mm
	crown_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(crown_mi)
	palm_crown_material = crown_mesh.surface_get_material(0)


# ───────────────────────── 礁石 ─────────────────────────
func _build_rocks() -> void:
	var meshes := [OceanProps.make_rock_mesh(101, 1, false),
			OceanProps.make_rock_mesh(207, 1, false),
			OceanProps.make_rock_mesh(313, 1, true)]
	var variant_of: Array[int] = []
	var counts := [0, 0, 0]
	for site in field.rock_sites:
		var k := _rng.randi_range(0, 2)
		variant_of.append(k)
		counts[k] += 1
	var mms: Array[MultiMesh] = []
	for k in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[k]
		mm.instance_count = counts[k]
		mms.append(mm)
	var idxs := [0, 0, 0]
	for i in field.rock_sites.size():
		var site = field.rock_sites[i]
		var k: int = variant_of[i]
		var pos: Vector2 = site["pos"]
		var size: float = site["size"]
		var ground := field.height(pos.x, pos.y)
		var y := ground
		if site["water"]:
			y = maxf(ground, -0.15)
		var s := size * _rng.randf_range(0.85, 1.15)
		var yaw := _rng.randf_range(0.0, TAU)
		var b := Basis.from_euler(Vector3(_rng.randf_range(-0.12, 0.12), yaw,
				_rng.randf_range(-0.12, 0.12))).scaled(Vector3(s, s * 0.85, s))
		var t := Transform3D(b, Vector3(pos.x, y + s * 0.55, pos.y))
		mms[k].set_instance_transform(idxs[k], t)
		idxs[k] += 1
	rock_material = ShaderMaterial.new()
	rock_material.shader = preload("res://shaders/rock.gdshader")
	rock_material.set_shader_parameter("foam_tex", TexFactory.foam_texture())
	rock_material.set_shader_parameter("foam_color", Color("#fbffff"))
	for k in 3:
		var mi := MultiMeshInstance3D.new()
		mi.name = "Rocks%d" % k
		mi.multimesh = mms[k]
		mi.material_override = rock_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(mi)


# ───────────────────────── 草丛 / 灌木 ─────────────────────────
func _build_ground_cover() -> void:
	var grass_mesh := OceanProps.make_grass_mesh()
	var gm := MultiMesh.new()
	gm.transform_format = MultiMesh.TRANSFORM_3D
	gm.mesh = grass_mesh
	gm.use_custom_data = true
	var grass_n := 110
	gm.instance_count = grass_n
	var placed := 0
	var attempts := 0
	while placed < grass_n and attempts < 1000:
		attempts += 1
		var theta := _rng.randf_range(0.0, TAU)
		var r := sqrt(_rng.randf()) * 22.0 + 3.0
		var x := cos(theta) * r
		var z := sin(theta) * r
		var h := field.height(x, z)
		if h < 0.7:
			continue
		var s := _rng.randf_range(0.7, 1.5)
		var b := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
		gm.set_instance_transform(placed, Transform3D(b, Vector3(x, h - 0.03, z)))
		gm.set_instance_custom_data(placed, Color(_rng.randf(), 0, 0, 0))
		placed += 1
	gm.instance_count = placed
	var gmi := MultiMeshInstance3D.new()
	gmi.name = "GrassTufts"
	gmi.multimesh = gm
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(gmi)
	grass_material = grass_mesh.surface_get_material(0)

	var shrub_mesh := OceanProps.make_shrub_mesh(9)
	var sm := MultiMesh.new()
	sm.transform_format = MultiMesh.TRANSFORM_3D
	sm.mesh = shrub_mesh
	sm.use_custom_data = true
	var shrub_n := 20
	sm.instance_count = shrub_n
	var placed2 := 0
	attempts = 0
	while placed2 < shrub_n and attempts < 500:
		attempts += 1
		var theta := _rng.randf_range(0.0, TAU)
		var r := sqrt(_rng.randf()) * 20.0 + 6.0
		var x := cos(theta) * r
		var z := sin(theta) * r
		var h := field.height(x, z)
		if h < 0.9:
			continue
		var s := _rng.randf_range(0.7, 1.35)
		var b := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
		sm.set_instance_transform(placed2, Transform3D(b, Vector3(x, h - 0.1, z)))
		sm.set_instance_custom_data(placed2, Color(_rng.randf(), 0, 0, 0))
		placed2 += 1
	sm.instance_count = placed2
	var smi := MultiMeshInstance3D.new()
	smi.name = "Shrubs"
	smi.multimesh = sm
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(smi)
	shrub_material = shrub_mesh.surface_get_material(0)


func _build_structures() -> void:
	hut = OceanProps.make_hut()
	hut.scale = Vector3(1.25, 1.25, 1.25)
	hut.position = Vector3(-9.5, field.height(-9.5, 4.5) - 0.1, 4.5)
	hut.rotation_degrees.y = 12.0
	parent.add_child(hut)
	hut_light.position = hut.position + Vector3(0, 3.4, 0)
	if hut_glow != null:
		hut_glow.position = hut.position + Vector3(0, 3.5, 0)

	tower = OceanProps.make_tower()
	tower.scale = Vector3(1.2, 1.25, 1.2)
	tower.position = Vector3(2.5, field.height(2.5, -10.5) - 0.1, -10.5)
	parent.add_child(tower)
	tower_light.position = tower.position + Vector3(0, 8.4, 0)
	if tower_glow != null:
		tower_glow.position = tower.position + Vector3(0, 8.8, 0)
	var beacon_mesh := tower.get_child(tower.get_child_count() - 1) as MeshInstance3D
	if beacon_mesh != null:
		beacon_mat = beacon_mesh.material_override as StandardMaterial3D


func _build_boats() -> void:
	boat = OceanProps.make_boat()
	boat.scale = Vector3(1.6, 1.6, 1.6)
	parent.add_child(boat)
	raft = OceanProps.make_raft()
	parent.add_child(raft)


# ───────────────────────── 软接触阴影（无阴影贴图开销，艺术可控） ─────────────────────────
func _make_shadow_quad() -> ArrayMesh:
	var verts := PackedVector3Array([
		Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1),
		Vector3(-1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1),
	])
	var uvs := PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),
		Vector2(0, 0), Vector2(1, 1), Vector2(0, 1),
	])
	var normals := PackedVector3Array()
	for i in 6:
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _build_blob_shadows() -> void:
	_shadow_entries.clear()
	for pos in palm_positions:
		_shadow_entries.append({"pos": pos, "length": 6.6, "width": 3.6})
	for site in field.rock_sites:
		if site["water"]:
			continue
		var p: Vector2 = site["pos"]
		var sz: float = site["size"]
		_shadow_entries.append({"pos": Vector3(p.x, field.height(p.x, p.y), p.y),
				"length": sz * 2.0, "width": sz * 1.8})
	if hut != null:
		_shadow_entries.append({"pos": hut.position, "length": 9.6, "width": 6.8})
	if tower != null:
		_shadow_entries.append({"pos": tower.position, "length": 5.6, "width": 5.6})

	var mesh := _make_shadow_quad()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = TexFactory.shadow_texture()
	mat.albedo_color = Color(1, 1, 1, 0.5)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = _shadow_entries.size()
	shadow_multimesh = MultiMeshInstance3D.new()
	shadow_multimesh.name = "ContactShadows"
	shadow_multimesh.multimesh = mm
	shadow_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shadow_multimesh)
	_update_shadow_transforms()


func _update_shadow_transforms() -> void:
	if shadow_multimesh == null or shadow_multimesh.multimesh == null:
		return
	var sun_xz := Vector2(-current_sun_dir.x, -current_sun_dir.z).normalized()
	var yaw := atan2(-sun_xz.y, sun_xz.x)
	var mm := shadow_multimesh.multimesh
	if mm.instance_count != _shadow_entries.size():
		mm.instance_count = _shadow_entries.size()
	for i in _shadow_entries.size():
		var e: Dictionary = _shadow_entries[i]
		var pos: Vector3 = e["pos"]
		var offset := Vector3(sun_xz.x, 0, sun_xz.y) * (float(e["length"]) * 0.24)
		var center := pos + offset
		var ground := field.height(center.x, center.z) + 0.06
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(float(e["length"]) * 0.5, 1.0,
				float(e["width"]) * 0.5))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(center.x, ground, center.z)))


func _build_clouds() -> void:
	var specs := [
		[Vector3(-38.0, 24.0, 38.0), 1.1, 5],
		[Vector3(47.0, 27.0, 30.0), 0.75, 7],
		[Vector3(-20.0, 33.0, -44.0), 1.0, 11],
		[Vector3(54.0, 31.0, -15.0), 0.95, 13],
		[Vector3(-54.0, 26.0, -26.0), 1.0, 17],
	]
	for i in specs.size():
		var spec: Array = specs[i]
		var cloud := MeshInstance3D.new()
		cloud.name = "Cloud%d" % i
		cloud.mesh = OceanProps.make_cloud_mesh(int(spec[2]))
		cloud.material_override = cloud_material
		cloud.position = spec[0]
		cloud.scale = Vector3.ONE * float(spec[1])
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(cloud)
		clouds.append(cloud)
		cloud_offsets.append(_rng.randf_range(0.0, 10.0))


func _build_birds() -> void:
	var mesh := OceanProps.make_bird_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.use_custom_data = true
	mm.instance_count = 10
	bird_data.clear()
	for i in 10:
		bird_data.append({
			"radius": _rng.randf_range(28.0, 48.0),
			"height": _rng.randf_range(18.0, 28.0),
			"phase": _rng.randf_range(0.0, TAU),
			"speed": _rng.randf_range(0.09, 0.16),
			"scale": _rng.randf_range(0.22, 0.34),
			"flap": _rng.randf_range(0.0, 1.0),
		})
		mm.set_instance_custom_data(i, Color(bird_data[i]["flap"], 0, 0, 0))
	birds = MultiMeshInstance3D.new()
	birds.name = "Seagulls"
	birds.multimesh = mm
	birds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(birds)


func _build_fish() -> void:
	var mesh := OceanProps.make_fish_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 16
	fish_data.clear()
	for i in 16:
		fish_data.append({
			"radius": _rng.randf_range(32.0, 42.0),
			"phase": _rng.randf_range(0.0, TAU),
			"speed": _rng.randf_range(0.10, 0.22),
			"scale": _rng.randf_range(0.55, 0.95) * (1.0 if i % 3 == 0 else 0.8),
			"offset": _rng.randf_range(-1.2, 1.2),
		})
	fish = MultiMeshInstance3D.new()
	fish.name = "FishSchool"
	fish.multimesh = mm
	fish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fish)


func _build_rain() -> void:
	rain = CPUParticles3D.new()
	rain.name = "Rain"
	rain.emitting = false
	rain.visible = false
	rain.amount = 650
	rain.lifetime = 1.1
	rain.preprocess = 0.5
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(70, 3, 70)
	rain.direction = Vector3(0, -1, 0)
	rain.spread = 3.0
	rain.initial_velocity_min = 18.0
	rain.initial_velocity_max = 24.0
	rain.gravity = Vector3(0, -6.0, 0)
	rain.position = Vector3(0, 30, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.032, 0.62)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.82, 0.93, 1.0, 0.42)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	rain.mesh = quad
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rain)


# ───────────────────────── 昼夜 ─────────────────────────
static func _mix(a: Color, b: Color, c: Color, wa: float, wb: float, wc: float) -> Color:
	return Color(
		a.r * wa + b.r * wb + c.r * wc,
		a.g * wa + b.g * wb + c.g * wc,
		a.b * wa + b.b * wb + c.b * wc, 1.0)


func set_time(p_hour: float) -> void:
	hour = clampf(p_hour, 5.0, 21.5)
	var elev := sin((hour - 6.0) / 12.0 * PI)
	night_weight = smoothstep(0.02, -0.38, elev)
	var not_night := 1.0 - night_weight
	dusk_weight = not_night * (1.0 - smoothstep(0.10, 0.55, elev))
	day_weight = clampf(1.0 - night_weight - dusk_weight, 0.0, 1.0)
	var w := [day_weight, dusk_weight, night_weight]

	for key in DAY.keys():
		palette[key] = _mix(DAY[key], DUSK[key], NIGHT[key], w[0], w[1], w[2])

	# 太阳/月亮方向：白天偏西北高角，黄昏西沉，夜晚月光高角
	var az: float = 210.0 * float(w[0]) + 248.0 * float(w[1]) + 205.0 * float(w[2])
	var el: float = 58.0 * float(w[0]) + 9.0 * float(w[1]) + 48.0 * float(w[2])
	if hour < 6.0:
		el = lerpf(48.0, 58.0, clampf((hour - 5.0), 0.0, 1.0))
	var az_r := deg_to_rad(az)
	var el_r := deg_to_rad(el)
	current_sun_dir = Vector3(cos(el_r) * cos(az_r), sin(el_r), cos(el_r) * sin(az_r)).normalized()

	# 注意：GL Compatibility 下 DirectionalLight3D 若放在相机视锥外会被剔除，
	# 因此保持灯光节点在原点，仅用朝向着色方向（-Z 指向光线传播方向）。
	sun.global_transform = Transform3D(Basis.looking_at(-current_sun_dir, Vector3.UP), Vector3.ZERO)
	sun.light_color = palette["sun"]
	sun.light_energy = 0.0
	sun.shadow_enabled = false
	env.ambient_light_color = palette["ambient"]
	env.ambient_light_energy = 0.95 * day_weight + 0.7 * dusk_weight + 0.4 * night_weight
	ambient_energy = env.ambient_light_energy
	env.background_color = palette["sky_horizon"]
	env.fog_light_color = palette["fog"]

	ocean.set_night(night_weight)
	ocean.set_palette({
		"deep": palette["deep"], "mid": palette["mid"], "shelf": palette["shelf"],
		"lagoon": palette["lagoon"], "sandwater": palette["sandwater"],
		"sky_reflect": palette["sky_reflect"], "foam": palette["foam"],
		"caustic": palette["caustic"], "fog": palette["fog"],
	}, palette["sun"], current_sun_dir)

	sky_material.set_shader_parameter("zenith_color", palette["sky_zenith"])
	sky_material.set_shader_parameter("horizon_color", palette["sky_horizon"])
	sky_material.set_shader_parameter("ground_color", palette["sky_ground"])
	sky_material.set_shader_parameter("sun_color", palette["sun"])
	sky_material.set_shader_parameter("sun_dir", current_sun_dir)
	sky_material.set_shader_parameter("night", night_weight)
	sky_material.set_shader_parameter("sun_strength", 1.0 * day_weight + 1.1 * dusk_weight + 0.55 * night_weight)

	cloud_material.set_shader_parameter("light_color", palette["cloud_light"])
	cloud_material.set_shader_parameter("shade_color", palette["cloud_shade"])
	cloud_material.set_shader_parameter("sun_dir", current_sun_dir)

	terrain_material.set_shader_parameter("sand_dry", palette["sand_dry"])
	terrain_material.set_shader_parameter("sand_light", palette["sand_light"])
	terrain_material.set_shader_parameter("sand_damp", palette["sand_damp"])
	terrain_material.set_shader_parameter("sand_wet", palette["sand_wet"])
	terrain_material.set_shader_parameter("sand_edge", palette["sand_edge"])
	terrain_material.set_shader_parameter("sand_under", palette["sand_under"])
	terrain_material.set_shader_parameter("sand_deep", palette["sand_deep"])
	terrain_material.set_shader_parameter("foam_color", palette["foam"])
	terrain_material.set_shader_parameter("caustic_color", palette["caustic"])
	terrain_material.set_shader_parameter("sky_sheen", palette["sky_reflect"])
	terrain_material.set_shader_parameter("sun_dir", current_sun_dir)
	terrain_material.set_shader_parameter("sun_tint", Color("#fffaf0"))
	terrain_material.set_shader_parameter("shade_tint", Color("#b8c8da"))
	terrain_material.set_shader_parameter("night_level", night_weight)
	var fake_sun: Color = Color("#fffdf6") if night_weight < 0.5 else Color("#cfe0ff")
	var fake_shade: Color = Color("#c3d1dd") if night_weight < 0.5 else Color("#5c7690")
	var fake_level: float = 1.06 * day_weight + 0.9 * dusk_weight + 0.58 * night_weight
	if rock_material != null:
		rock_material.set_shader_parameter("sun_dir", current_sun_dir)
		rock_material.set_shader_parameter("sun_tint", fake_sun)
		rock_material.set_shader_parameter("shade_tint", fake_shade)
		rock_material.set_shader_parameter("light_level", fake_level)
		rock_material.set_shader_parameter("foam_color", palette["foam"])
		rock_material.set_shader_parameter("night_level", night_weight)
	for fm in [palm_crown_material, grass_material, shrub_material]:
		if fm is ShaderMaterial:
			fm.set_shader_parameter("sun_dir", current_sun_dir)
			fm.set_shader_parameter("sun_tint", fake_sun)
			fm.set_shader_parameter("shade_tint", fake_shade)
			fm.set_shader_parameter("light_level", fake_level)

	_update_shadow_transforms()
	if hut_glow != null:
		hut_glow.visible = night_weight > 0.08
		tower_glow.visible = night_weight > 0.08
	hut_light.light_energy = 2.2 * night_weight + 0.5 * dusk_weight
	tower_light.light_energy = 2.8 * night_weight + 0.6 * dusk_weight
	if beacon_mat != null:
		beacon_mat.emission_energy_multiplier = 1.2 + 2.6 * night_weight


# ───────────────────────── 每帧环境动画 ─────────────────────────
func tick(delta: float, sim_time: float) -> void:
	if ocean == null:
		return
	# 小船绕岛巡游 + 浮力
	boat_phase += delta * 0.014
	var bp := Vector2(cos(boat_phase), sin(boat_phase)) * boat_radius
	var by := ocean.get_wave_height_at(bp.x, bp.y)
	var tangent := Vector2(-sin(boat_phase), cos(boat_phase))
	boat.position = Vector3(bp.x, by + 0.02, bp.y)
	boat.rotation = Vector3(
		sin(sim_time * 1.3) * 0.045,
		-atan2(tangent.y, tangent.x),
		cos(sim_time * 1.1) * 0.05)
	# 小筏
	raft_phase += delta * 0.006
	var rp := Vector2(cos(raft_phase), sin(raft_phase)) * raft_radius
	var ry := ocean.get_wave_height_at(rp.x, rp.y)
	raft.position = Vector3(rp.x, ry + 0.06, rp.y)
	raft.rotation = Vector3(sin(sim_time * 1.7) * 0.06, -raft_phase + 0.6,
			cos(sim_time * 1.4) * 0.06)

	# 云漂移
	for i in clouds.size():
		var c := clouds[i]
		c.position.x += delta * (0.55 + float(i) * 0.07)
		if c.position.x > 70.0:
			c.position.x = -70.0
		c.position.y += sin(sim_time * 0.12 + cloud_offsets[i]) * delta * 0.05

	# 海鸥
	if birds != null:
		var mm := birds.multimesh
		for i in bird_data.size():
			var bd: Dictionary = bird_data[i]
			var ang: float = float(bd["phase"]) + sim_time * float(bd["speed"])
			var rad: float = bd["radius"]
			var pos := Vector3(cos(ang) * rad, bd["height"] + sin(sim_time * 0.5 + i) * 0.8,
					sin(ang) * rad)
			var fwd := Vector3(-sin(ang), 0, cos(ang))
			var basis := Basis.looking_at(fwd, Vector3.UP)
			basis = basis.scaled(Vector3.ONE * float(bd["scale"]))
			mm.set_instance_transform(i, Transform3D(basis, pos))

	# 鱼群（水面下浅色阴影，贴合参考的鱼群剪影）
	if fish != null:
		var fmm := fish.multimesh
		for i in fish_data.size():
			var fd: Dictionary = fish_data[i]
			var ang: float = float(fd["phase"]) + sim_time * float(fd["speed"])
			var rad: float = fd["radius"] + sin(sim_time * 0.4 + i * 1.7) * 1.4
			var px := cos(ang) * rad
			var pz := sin(ang) * rad
			var pos := Vector3(px, 0.08 + ocean.get_wave_height_at(px, pz) * 0.22, pz)
			var fwd := Vector3(-sin(ang), 0, cos(ang))
			var basis := Basis.looking_at(fwd, Vector3.UP)
			basis = basis.scaled(Vector3.ONE * float(fd["scale"]))
			fmm.set_instance_transform(i, Transform3D(basis, pos))


func set_clouds_visible(v: bool) -> void:
	for c in clouds:
		c.visible = v


func set_rain(on: bool) -> void:
	if rain == null:
		return
	rain.visible = on
	rain.emitting = on
	if terrain_material != null:
		terrain_material.set_shader_parameter("rain", 1.0 if on else 0.0)


func set_waves_time(t: float) -> void:
	terrain_material.set_shader_parameter("time", t)
	if rock_material != null:
		rock_material.set_shader_parameter("time", t)


func boat_position() -> Vector3:
	return boat.position if boat != null else Vector3.ZERO
