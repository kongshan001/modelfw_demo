extends Node3D

# 原创废墟花园「暮色回廊」世界构建器。
# 全部几何为程序化低模（Box/Cylinder/Sphere/Tuft），全部材质来自本项目 shader，
# 不使用外部模型、贴图或参考视频素材。
#
# 静态几何按类别合并进 MultiMesh（石/木/树皮/树冠/草/花），把 draw call 压到
# Intel GL Compatibility 也能 30fps+ 的量级；灯、玻璃、辉光、水、光柱独立更新。

const TOON_SHADER := preload("res://shaders/garden_toon.gdshader")
const SKY_SHADER := preload("res://shaders/sky_dusk.gdshader")
const WATER_SHADER := preload("res://shaders/water_pool.gdshader")
const SHAFT_SHADER := preload("res://shaders/light_shaft.gdshader")
const KEEPER_SCRIPT := preload("res://scripts/keeper.gd")
const FIREFLY_SCRIPT := preload("res://scripts/fireflies.gd")

const POOL_CENTER := Vector3(-3.0, 0.0, -0.4)
const POOL_RADIUS := 3.30
const ARCH_POS := Vector3(0.3, 0.0, -9.0)
const START_POS := Vector3(0.75, 0.13, 7.0)
const PATH_POINTS: Array[Vector2] = [
	Vector2(0.55, 9.8), Vector2(0.85, 6.4), Vector2(1.55, 3.3),
	Vector2(1.05, 0.2), Vector2(0.35, -3.6), Vector2(0.30, -8.6),
]
const LAMP_SPECS := [
	{"pos": Vector3(-2.1, 0.0, 5.7), "threshold": 0.17},
	{"pos": Vector3(3.2, 0.0, 3.3), "threshold": 0.26},
	{"pos": Vector3(-6.7, 0.0, -0.2), "threshold": 0.35},
	{"pos": Vector3(3.5, 0.0, -2.7), "threshold": 0.45},
	{"pos": Vector3(-1.9, 0.0, -7.7), "threshold": 0.55},
	{"pos": Vector3(7.1, 0.0, 1.2), "threshold": 0.65},
]

var rng := RandomNumberGenerator.new()
var sky_mat: ShaderMaterial
var water_mat: ShaderMaterial
var sun_light: DirectionalLight3D
var env: Environment
var lamps: Array = []
var shaft_nodes: Array = []
var shaft_mats: Array = []
var keeper
var fireflies
var landmarks: Dictionary = {}

var _stone_xf: Array = []
var _stone_col: Array = []
var _stone_cyl_xf: Array = []
var _stone_cyl_col: Array = []
var _wood_xf: Array = []
var _wood_col: Array = []
var _bark_xf: Array = []
var _bark_col: Array = []
var _leaf_xf: Array = []
var _leaf_col: Array = []
var _outer_leaf_xf: Array = []
var _outer_leaf_col: Array = []
var _outer_bark_xf: Array = []
var _outer_bark_col: Array = []
var _grass_xf: Array = []
var _grass_col: Array = []
var _flower_xf: Array = []
var _flower_col: Array = []
var _lily_xf: Array = []
var _lily_col: Array = []

var _mats: Dictionary = {}
var _glow_tex: ImageTexture
var _spark_tex: ImageTexture
var _pool_tex: ImageTexture
var _lamp_metal_mesh: ArrayMesh
var _water_lamp_indices: Array[int] = []


func build() -> void:
	rng.seed = 20261127
	_glow_tex = _radial_texture(32, 2.1)
	_spark_tex = _radial_texture(32, 3.0)
	_pool_tex = _radial_texture(64, 1.90)
	_build_environment()
	_build_materials()
	_build_ground()
	_build_walls_columns()
	_build_arch()
	_build_pool()
	_build_trees()
	_build_outskirts()
	_build_grass_flowers()
	_build_benches_statue()
	_build_lamps()
	_build_shafts()
	_build_character()
	_build_fireflies()
	_flush_static_meshes()
	_build_colliders()
	landmarks = {
		"pool": POOL_CENTER,
		"arch": ARCH_POS,
		"big_tree": Vector3(7.0, 0.0, -3.4),
		"start": START_POS,
		"statue": Vector3(4.8, 0.0, 5.2),
		"bench": Vector3(5.2, 0.0, 2.4),
	}


# ── 环境 / 天空 / 主光 ─────────────────────────────────────────────────
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.027, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.43, 0.48)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)

	sun_light = DirectionalLight3D.new()
	sun_light.name = "KeyLight"
	sun_light.light_color = Color(1.0, 0.72, 0.46)
	sun_light.light_energy = 1.2
	sun_light.rotation_degrees = Vector3(-13.0, -125.0, 0.0)
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun_light.directional_shadow_max_distance = 48.0
	sun_light.shadow_bias = 0.045
	sun_light.shadow_normal_bias = 1.2
	sun_light.shadow_blur = 1.0
	add_child(sun_light)

	var dome := MeshInstance3D.new()
	dome.name = "SkyDome"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	dome.mesh = sphere
	dome.scale = Vector3(92, 92, 92)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	dome.material_override = sky_mat
	add_child(dome)


func _build_materials() -> void:
	# 多实例材质用白色 tint，颜色由 instance color 提供。
	# 石面刻意压低 rim（否则 400 块石板会变成发光网格）。
	_mats["stone_box"] = _toon(Color(1, 1, 1), 0.34, 0.035, 0.0, 1.0, 0.0, 0.16)
	_mats["stone_cyl"] = _toon(Color(1, 1, 1), 0.34, 0.05, 0.0, 1.0, 1.0, 0.15)
	_mats["wood"] = _toon(Color(1, 1, 1), 0.10, 0.05, 0.0, 1.0, 0.0, 0.12)
	_mats["bark"] = _toon(Color(0.28, 0.21, 0.15), 0.16, 0.06, 0.0, 1.0, 1.0, 0.14)
	_mats["leaf"] = _toon(Color(1, 1, 1), 0.0, 0.13, 0.055, 1.1, 1.0, 0.12)
	_mats["grass"] = _toon(Color(1, 1, 1), 0.0, 0.05, 0.060, 0.38, 0.0, 0.10)
	_mats["flower"] = _toon(Color(1, 1, 1), 0.0, 0.05, 0.045, 0.32, 0.0, 0.06)
	_mats["lily"] = _toon(Color(1, 1, 1), 0.0, 0.08, 0.010, 0.2, 0.0, 0.08)
	_mats["metal"] = _toon(Color(0.15, 0.17, 0.17), 0.0, 0.24, 0.0, 1.0, 0.0, 0.10)
	_mats["statue"] = _toon(Color(1, 1, 1), 0.42, 0.045, 0.0, 1.0, 0.0, 0.13)
	_mats["pool_bottom"] = _toon(Color(0.16, 0.21, 0.19), 0.35, 0.03, 0.0, 1.0, 1.0, 0.12)

	water_mat = ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	water_mat.set_shader_parameter("deep_color", Color(0.045, 0.11, 0.13))
	water_mat.set_shader_parameter("shallow_color", Color(0.16, 0.28, 0.25))
	water_mat.set_shader_parameter("stone_rim_color", Color(0.22, 0.26, 0.23))
	water_mat.set_shader_parameter("ripple_strength", 1.0)
	water_mat.set_shader_parameter("sparkle", 1.0)


func _toon(color: Color, moss: float = 0.0, rim: float = 0.1, sway: float = 0.0,
		sway_ref: float = 1.0, faceted: float = 0.0, grain: float = 0.1) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("moss_amount", moss)
	m.set_shader_parameter("rim_amount", rim)
	m.set_shader_parameter("rim_color", Color(0.95, 0.80, 0.58))
	m.set_shader_parameter("sway_amount", sway)
	m.set_shader_parameter("sway_ref", sway_ref)
	m.set_shader_parameter("faceted", faceted)
	m.set_shader_parameter("grain_amount", grain)
	m.set_shader_parameter("bands", 3.0)
	return m


# ── 几何基础 ───────────────────────────────────────────────────────────
func _xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis(Vector3.UP, deg_to_rad(rot_deg.y))
	b = b * Basis(Vector3.RIGHT, deg_to_rad(rot_deg.x))
	b = b * Basis(Vector3.BACK, deg_to_rad(rot_deg.z))
	b.x *= scl.x
	b.y *= scl.y
	b.z *= scl.z
	return Transform3D(b, pos)


func _add_box(pos: Vector3, size: Vector3, rot_deg: Vector3, color: Color,
		wood: bool = false) -> void:
	var xf := _xf(pos, rot_deg, size)
	if wood:
		_wood_xf.append(xf)
		_wood_col.append(color)
	else:
		_stone_xf.append(xf)
		_stone_col.append(color)


func _add_cyl(pos: Vector3, radius: float, height: float, rot_deg: Vector3, color: Color) -> void:
	var xf := _xf(pos, rot_deg, Vector3(radius * 2.0, height, radius * 2.0))
	_stone_cyl_xf.append(xf)
	_stone_cyl_col.append(color)


func _add_leaf(pos: Vector3, scale_v: float, color: Color, squash: float = 0.8) -> void:
	var xf := _xf(pos, Vector3(rng.randf_range(-22, 22), rng.randf_range(0, 360), rng.randf_range(-22, 22)),
		Vector3(scale_v, scale_v * squash, scale_v))
	_leaf_xf.append(xf)
	_leaf_col.append(color)


func _pipe_append(st: SurfaceTool, mesh: Mesh, xf: Transform3D) -> void:
	for s in mesh.get_surface_count():
		st.append_from(mesh, s, xf)


func _make_multi(mesh: Mesh, mat: Material, xfs: Array, cols: Array, node_name: String,
		shadows: bool = true) -> MultiMeshInstance3D:
	if xfs.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	mm.custom_aabb = AABB(Vector3(-30, -2.5, -30), Vector3(60, 26, 60))
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	inst.extra_cull_margin = 45.0
	add_child(inst)
	return inst


func _radial_texture(size: int, power: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size - 1, size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c) / (size * 0.5)
			var a := pow(clampf(1.0 - d, 0.0, 1.0), power)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# ── 地面 / 石板路 ───────────────────────────────────────────────────────
func _build_ground() -> void:
	var base := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(38, 38)
	base.mesh = plane
	base.material_override = _toon(Color(0.18, 0.22, 0.15), 0.58, 0.02, 0.0, 1.0, 0.0, 0.24)
	base.position = Vector3(0, -0.015, 0)
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)

	# 石路 + 废墟庭院：路径上是暖色石板，庭院里只保留约六成石板，其余露出苔土。
	for iz in 20:
		for ix in 20:
			var x := -10.15 + ix * 1.065 + rng.randf_range(-0.035, 0.035)
			var z := -10.15 + iz * 1.065 + rng.randf_range(-0.035, 0.035)
			var dpool := Vector2(x - POOL_CENTER.x, z - POOL_CENTER.z).length()
			if dpool < POOL_RADIUS + 0.72:
				continue
			if Vector2(x, z).length() > 11.0:
				continue
			var path_d := _dist_to_path(x, z)
			var keep := 0.96 if path_d < 1.45 else 0.60
			if rng.randf() > keep:
				continue
			var h := 0.040 + rng.randf() * 0.028
			var sx := rng.randf_range(0.97, 1.045)
			var sz := rng.randf_range(0.96, 1.035)
			var pos := Vector3(x, h * 0.5, z)
			var rot := Vector3(0, rng.randf_range(-2.2, 2.2), 0)
			if rng.randf() < 0.07:
				rot.x = rng.randf_range(-1.7, 1.7)
				rot.z = rng.randf_range(-1.7, 1.7)
			_stone_xf.append(_xf(pos, rot, Vector3(sx, h, sz)))
			var col: Color
			if path_d < 1.45:
				col = Color(0.64, 0.55, 0.42).lerp(Color(0.77, 0.67, 0.51), rng.randf())
				if rng.randf() < 0.16:
					col = Color(0.53, 0.51, 0.43)
			else:
				col = Color(0.33, 0.37, 0.31).lerp(Color(0.46, 0.49, 0.40), rng.randf())
				if rng.randf() < 0.22:
					col = Color(0.29, 0.38, 0.27)
			col = col.darkened(rng.randf() * 0.10)
			_stone_col.append(col)
	# 缺砖处露出的碎石
	for i in 54:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(2.2, 10.5)
		var x := cos(ang) * r
		var z := sin(ang) * r
		if Vector2(x - POOL_CENTER.x, z - POOL_CENTER.z).length() < POOL_RADIUS + 0.5:
			continue
		var s := rng.randf_range(0.10, 0.26)
		_add_box(Vector3(x, s * 0.35, z), Vector3(s * 1.6, s, s * 1.2),
			Vector3(rng.randf_range(-10, 10), rng.randf_range(0, 360), rng.randf_range(-10, 10)),
			Color(0.38, 0.39, 0.33).darkened(rng.randf() * 0.15))


func _dist_to_path(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 999.0
	for i in PATH_POINTS.size() - 1:
		var a := PATH_POINTS[i]
		var b := PATH_POINTS[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		best = minf(best, d)
	return best


# ── 围墙 / 断柱 ────────────────────────────────────────────────────────
func _build_walls_columns() -> void:
	var wall_cols := [Color(0.45, 0.47, 0.41), Color(0.38, 0.41, 0.35), Color(0.51, 0.50, 0.43)]
	# 北墙（中部留缺口给拱门后的天空）
	for i in 15:
		var x := -11.0 + (i + 0.5) * 22.0 / 15.0
		if absf(x - ARCH_POS.x) < 2.3:
			continue
		_wall_block(Vector3(x, 0, -11.5), rng.randf_range(0.5, 1.5), 0.0, wall_cols)
	# 南墙（入口缺口）
	for i in 15:
		var x := -11.0 + (i + 0.5) * 22.0 / 15.0
		if absf(x - 0.7) < 1.8:
			continue
		_wall_block(Vector3(x, 0, 11.5), rng.randf_range(0.5, 1.6), 0.0, wall_cols)
	# 东西墙
	for i in 15:
		var z := -11.0 + (i + 0.5) * 22.0 / 15.0
		if rng.randf() < 0.12:
			continue
		_wall_block(Vector3(-11.5, 0, z), rng.randf_range(0.45, 1.7), 90.0, wall_cols)
		_wall_block(Vector3(11.5, 0, z + rng.randf_range(-0.2, 0.2)), rng.randf_range(0.45, 1.55), 90.0, wall_cols)
	# 四角柱基
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_add_box(Vector3(sx * 11.5, 0.7, sz * 11.5), Vector3(1.5, 1.4, 1.5),
				Vector3(0, rng.randf_range(0, 90), 0), Color(0.47, 0.47, 0.41))
			_forbid_collision_at(Vector3(sx * 11.5, 0.7, sz * 11.5), 1.1, 1.4)

	# 断裂石柱（不同高度、轻微倾斜）
	var col_specs := [
		{"pos": Vector3(-8.8, 0, -1.8), "h": 3.5, "tilt": Vector3(0, 0, 2.5), "r": 0.38},
		{"pos": Vector3(-7.7, 0, -6.9), "h": 2.3, "tilt": Vector3(-3.0, 0, 0), "r": 0.40},
		{"pos": Vector3(8.7, 0, -6.6), "h": 4.1, "tilt": Vector3(1.5, 0, -2.0), "r": 0.42},
		{"pos": Vector3(9.4, 0, 4.8), "h": 2.7, "tilt": Vector3(0, 0, -4.0), "r": 0.36},
		{"pos": Vector3(5.7, 0, 8.8), "h": 3.1, "tilt": Vector3(3.0, 0, 1.0), "r": 0.39},
		{"pos": Vector3(-5.0, 0, 8.6), "h": 2.0, "tilt": Vector3(0, 0, 0), "r": 0.37},
	]
	for c in col_specs:
		var p: Vector3 = c["pos"]
		var h: float = c["h"]
		var tilt: Vector3 = c["tilt"]
		var r: float = c["r"]
		_add_box(p + Vector3(0, 0.22, 0), Vector3(r * 2.6, 0.44, r * 2.6), Vector3.ZERO, Color(0.47, 0.47, 0.40))
		_add_cyl(p + Vector3(0, h * 0.5 + 0.4, 0), r, h, tilt, Color(0.53, 0.52, 0.45))
		# 断口：一高一低的碎石
		_add_box(p + Vector3(0, h + 0.45, 0), Vector3(r * 1.5, 0.20, r * 1.4),
			Vector3(0, 20, 6), Color(0.46, 0.46, 0.39))
		_add_leaf(p + Vector3(r * 0.5, 0.55, 0), rng.randf_range(0.18, 0.30),
			Color(0.20, 0.29, 0.18).lerp(Color(0.30, 0.40, 0.22), rng.randf()), 0.5)
		_cylinder_collision(p, r * 1.3, h + 0.6)
	# 倒下的柱鼓
	var drums := [
		{"pos": Vector3(7.2, 0.36, 6.7), "rot": Vector3(0, 20, 90)},
		{"pos": Vector3(-9.0, 0.36, 4.2), "rot": Vector3(0, -35, 90)},
		{"pos": Vector3(3.0, 0.34, 9.3), "rot": Vector3(0, 70, 90)},
	]
	for d in drums:
		_add_cyl(d["pos"], 0.38, 1.4, d["rot"], Color(0.49, 0.49, 0.42))

	# 墙头 / 柱脚苔藓与爬藤
	for i in 24:
		var side := rng.randi() % 4
		var pos: Vector3
		match side:
			0: pos = Vector3(rng.randf_range(-11, 11), rng.randf_range(0.9, 1.5), -11.35)
			1: pos = Vector3(rng.randf_range(-11, 11), rng.randf_range(0.9, 1.5), 11.35)
			2: pos = Vector3(-11.35, rng.randf_range(0.9, 1.5), rng.randf_range(-11, 11))
			_: pos = Vector3(11.35, rng.randf_range(0.9, 1.5), rng.randf_range(-11, 11))
		_add_leaf(pos, rng.randf_range(0.22, 0.45),
			Color(0.19, 0.28, 0.17).lerp(Color(0.29, 0.38, 0.20), rng.randf()), 0.55)


func _wall_block(pos: Vector3, h: float, yaw: float, palette: Array) -> void:
	var w := rng.randf_range(1.35, 1.8)
	var color: Color = palette[rng.randi() % palette.size()]
	color = color.darkened(rng.randf() * 0.12)
	_add_box(pos + Vector3(0, h * 0.5, 0), Vector3(w, h, rng.randf_range(0.55, 0.75)),
		Vector3(0, yaw + rng.randf_range(-2, 2), 0), color)


func _build_arch() -> void:
	var stone_a := Color(0.57, 0.55, 0.46)
	var stone_b := Color(0.47, 0.47, 0.39)
	var stone_c := Color(0.40, 0.42, 0.35)
	var base := ARCH_POS
	# 两座立柱：三层石块 + 柱头
	for side in [-1, 1]:
		var x: float = base.x + float(side) * 1.95
		for layer in 3:
			_add_box(Vector3(x, 0.45 + layer * 0.75, base.z),
				Vector3(0.95, 0.74, 0.95), Vector3(0, rng.randf_range(-3, 3), 0),
				stone_a if layer % 2 == 0 else stone_b)
		_add_box(Vector3(x, 2.58, base.z), Vector3(1.15, 0.24, 1.15),
			Vector3(0, rng.randf_range(-6, 6), 0), stone_c)
		_add_leaf(Vector3(x + side * 0.35, 2.62, base.z + 0.25), rng.randf_range(0.28, 0.45),
			Color(0.21, 0.30, 0.18), 0.5)
		_forbid_collision_at(Vector3(x, 1.4, base.z), 0.62, 2.8)
	# 拱券：11 块楔石，右上断开
	for i in 11:
		var a := PI * float(i) / 10.0
		var x := base.x + cos(a) * 1.95
		var y := 2.70 + sin(a) * 1.55
		if i == 6 or i == 7:
			continue
		_add_box(Vector3(x, y, base.z), Vector3(0.62, 0.52, 0.95),
			Vector3(0, 0, rad_to_deg(a) + 90.0),
			stone_b if i % 2 == 0 else stone_a)
	# 塌落在右侧的楔石
	_add_box(Vector3(base.x + 2.8, 0.35, base.z + 0.6), Vector3(0.9, 0.45, 0.62),
		Vector3(0, 28, 80), stone_a)
	_add_box(Vector3(base.x + 2.2, 0.28, base.z + 1.3), Vector3(0.7, 0.34, 0.55),
		Vector3(0, -18, 70), stone_c)
	# 拱顶残存藤蔓
	for i in 7:
		var a := PI * float(i + 2) / 9.0
		_add_leaf(Vector3(base.x + cos(a) * 2.0, 3.0 + sin(a) * 1.5, base.z + rng.randf_range(-0.2, 0.25)),
			rng.randf_range(0.16, 0.30), Color(0.18, 0.27, 0.16), 0.7)


# ── 水池 / 喷泉 / 睡莲 ─────────────────────────────────────────────────
func _build_pool() -> void:
	# 池底
	var bottom := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = POOL_RADIUS - 0.08
	cyl.bottom_radius = POOL_RADIUS - 0.02
	cyl.height = 0.30
	cyl.radial_segments = 28
	bottom.mesh = cyl
	bottom.material_override = _mats["pool_bottom"]
	bottom.position = POOL_CENTER + Vector3(0, -0.21, 0)
	bottom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bottom)
	# 池沿石块
	for i in 16:
		var a := TAU * float(i) / 16.0
		var pos := POOL_CENTER + Vector3(cos(a) * (POOL_RADIUS + 0.28), 0.15, sin(a) * (POOL_RADIUS + 0.28))
		var col := Color(0.53, 0.51, 0.43).lerp(Color(0.42, 0.44, 0.38), rng.randf())
		_add_box(pos, Vector3(1.35, 0.36, 0.55), Vector3(0, -rad_to_deg(a) + 90.0, 0), col)
	# 池底小石
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.4, 2.9)
		_add_box(POOL_CENTER + Vector3(cos(a) * r, -0.31, sin(a) * r),
			Vector3(rng.randf_range(0.12, 0.28), 0.10, rng.randf_range(0.12, 0.28)),
			Vector3(0, rng.randf_range(0, 360), 0), Color(0.20, 0.25, 0.21))
	# 水面
	var water := MeshInstance3D.new()
	water.name = "PoolWater"
	water.mesh = _disc_mesh(POOL_RADIUS - 0.02, 36)
	water.material_override = water_mat
	water.position = POOL_CENTER + Vector3(0, 0.035, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(water)
	# 池心残破喷泉
	var fx := POOL_CENTER
	_add_box(fx + Vector3(0, 0.20, 0), Vector3(1.0, 0.4, 1.0), Vector3(0, 12, 0), Color(0.45, 0.46, 0.39))
	_add_cyl(fx + Vector3(0, 0.65, 0), 0.28, 0.75, Vector3(0, 0, 1.5), Color(0.51, 0.51, 0.43))
	_add_cyl(fx + Vector3(0.02, 1.02, 0), 0.72, 0.15, Vector3(3, 0, -4), Color(0.48, 0.49, 0.41))
	_add_cyl(fx + Vector3(-0.15, 1.13, 0.05), 0.10, 0.24, Vector3(0, 0, 0), Color(0.44, 0.46, 0.38))
	_add_leaf(fx + Vector3(0.25, 1.02, 0.2), 0.30, Color(0.20, 0.30, 0.18), 0.45)
	# 睡莲
	for i in 9:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.9, 2.85)
		var p := POOL_CENTER + Vector3(cos(a) * r, 0.050, sin(a) * r)
		var s := rng.randf_range(0.22, 0.45)
		_lily_xf.append(_xf(p, Vector3(0, rng.randf_range(0, 360), 0), Vector3(s, 1.0, s)))
		_lily_col.append(Color(0.24, 0.38, 0.20).lerp(Color(0.36, 0.47, 0.24), rng.randf()))
	# 池边芦苇
	for i in 46:
		var a := rng.randf() * TAU
		var r := POOL_RADIUS + rng.randf_range(0.42, 1.15)
		if r < POOL_RADIUS + 0.4:
			continue
		var p := POOL_CENTER + Vector3(cos(a) * r, 0.02, sin(a) * r)
		if _dist_to_path(p.x, p.z) < 0.8:
			continue
		_grass_xf.append(_xf(p, Vector3(0, rng.randf_range(0, 360), 0),
			Vector3(rng.randf_range(0.7, 1.15), rng.randf_range(1.5, 2.7), rng.randf_range(0.7, 1.15))))
		_grass_col.append(Color(0.28, 0.36, 0.20).lerp(Color(0.40, 0.46, 0.24), rng.randf()))


func _disc_mesh(radius: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * float(i) / segments
		var a1 := TAU * float(i + 1) / segments
		var p0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var uv0 := Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5)
		var uv1 := Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.set_uv(uv1)
		st.add_vertex(p1)
		st.set_normal(Vector3.UP)
		st.set_uv(uv0)
		st.add_vertex(p0)
	return st.commit()


# ── 树 ─────────────────────────────────────────────────────────────────
func _build_trees() -> void:
	_add_tree(Vector3(7.0, 0, -3.4), 4.4, 2.6, false, Vector3(4.0, 0, -3.0))
	_add_tree(Vector3(-7.9, 0, -6.9), 3.4, 1.9, false, Vector3(-3.0, 0, 3.0))
	_add_tree(Vector3(8.8, 0, 5.3), 3.7, 2.0, false, Vector3(-2.0, 0, 2.0))
	_add_tree(Vector3(-8.4, 0, 5.4), 3.2, 1.2, true, Vector3(2.0, 0, 1.0))
	# 小灌木
	for i in 14:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(5.5, 10.5)
		var p := Vector3(cos(ang) * r, rng.randf_range(0.25, 0.45), sin(ang) * r)
		if p.distance_to(POOL_CENTER) < POOL_RADIUS + 0.8:
			continue
		if p.distance_to(Vector3(START_POS.x, 0, START_POS.z)) < 1.2:
			continue
		# 别让灌木长在石路上（会挡住第三人称视线与电影镜头）。
		if _dist_to_path(p.x, p.z) < 1.75:
			continue
		_add_leaf(p, rng.randf_range(0.35, 0.72),
			Color(0.18, 0.28, 0.17).lerp(Color(0.30, 0.40, 0.21), rng.randf()), 0.7)


func _build_outskirts() -> void:
	# 墙外树林剪影：填住墙外的空白，不可进入、不加碰撞、不投影
	# （否则低角度夕阳会被外圈树冠切成一地碎影）。
	for i in 14:
		var a := TAU * float(i) / 14.0 + rng.randf_range(-0.13, 0.13)
		var r := rng.randf_range(19.0, 27.0)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var h := rng.randf_range(3.0, 4.8)
		_outer_bark_xf.append(_xf(p + Vector3(0, h * 0.46, 0),
			Vector3(rng.randf_range(-4, 4), rng.randf_range(0, 360), rng.randf_range(-4, 4)),
			Vector3(h * 0.09, h * 0.92, h * 0.09)))
		_outer_bark_col.append(Color(0.15, 0.15, 0.13).lerp(Color(0.23, 0.20, 0.16), rng.randf()))
		for j in 4:
			var ca := rng.randf() * TAU
			var cr := rng.randf_range(0.0, 1.2)
			var cp := p + Vector3(cos(ca) * cr, h * 0.92 + rng.randf_range(-0.3, 0.9), sin(ca) * cr)
			var s := rng.randf_range(0.55, 1.05)
			_outer_leaf_xf.append(_xf(cp,
				Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 360), rng.randf_range(-20, 20)),
				Vector3(s, s * 0.8, s)))
			_outer_leaf_col.append(Color(0.09, 0.14, 0.11).lerp(Color(0.16, 0.23, 0.15), rng.randf()))
	# 墙根外侧灌木，遮住墙脚与地面的接缝（不投影）。
	for i in 28:
		var a := rng.randf() * TAU
		var r := rng.randf_range(12.2, 13.8)
		var p := Vector3(cos(a) * r, rng.randf_range(0.35, 0.8), sin(a) * r)
		var s := rng.randf_range(0.35, 0.8)
		_outer_leaf_xf.append(_xf(p,
			Vector3(rng.randf_range(-16, 16), rng.randf_range(0, 360), rng.randf_range(-16, 16)),
			Vector3(s, s * 0.65, s)))
		_outer_leaf_col.append(Color(0.12, 0.20, 0.13).lerp(Color(0.21, 0.30, 0.17), rng.randf()))


func _add_tree(pos: Vector3, height: float, canopy: float, dead: bool, lean: Vector3) -> void:
	var lean_rot := Vector3(lean.z, rng.randf_range(0, 360), lean.x)
	# 主干
	_bark_xf.append(_xf(pos + Vector3(0, height * 0.48, 0), lean_rot,
		Vector3(height * 0.115, height * 0.98, height * 0.115)))
	_bark_col.append(Color(0.30, 0.24, 0.18).lerp(Color(0.37, 0.29, 0.21), rng.randf()))
	# 枝
	var branch_count := 2 if dead else 5
	for i in branch_count:
		var a := rng.randf() * TAU
		var h := height * rng.randf_range(0.55, 0.86)
		var len := height * rng.randf_range(0.25, 0.42)
		var outward := Vector3(cos(a), 0, sin(a))
		var bpos := pos + Vector3(0, h, 0) + outward * len * 0.5
		var rot := Vector3(rng.randf_range(35, 62), -rad_to_deg(a), rng.randf_range(-18, 18))
		_bark_xf.append(_xf(bpos, rot, Vector3(height * 0.05, len, height * 0.05)))
		_bark_col.append(Color(0.28, 0.22, 0.16))
		if not dead and rng.randf() < 0.6:
			var tip := pos + Vector3(0, h + len * 0.55, 0) + outward * len * 0.8
			_add_leaf(tip, canopy * rng.randf_range(0.30, 0.48),
				Color(0.22, 0.33, 0.19).lerp(Color(0.34, 0.45, 0.22), rng.randf()), 0.75)
	if dead:
		# 枯树：仅剩几根折枝
		for i in 4:
			var a := rng.randf() * TAU
			var h := height * rng.randf_range(0.4, 0.8)
			var outward := Vector3(cos(a), 0, sin(a))
			_bark_xf.append(_xf(pos + Vector3(0, h, 0) + outward * 0.8, Vector3(38, -rad_to_deg(a), 0),
				Vector3(height * 0.035, height * 0.32, height * 0.035)))
			_bark_col.append(Color(0.26, 0.21, 0.16))
	else:
		# 树冠：一组低模分面球
		var center := pos + Vector3(0, height * 0.92, 0)
		var count := 9 if canopy > 2.0 else 7
		for i in count:
			var a := rng.randf() * TAU
			var r := canopy * sqrt(rng.randf()) * 0.9
			var p := center + Vector3(cos(a) * r, rng.randf_range(-0.35, 0.65) * canopy, sin(a) * r)
			var s := canopy * rng.randf_range(0.34, 0.58)
			var base_col := Color(0.20, 0.31, 0.18).lerp(Color(0.33, 0.45, 0.23), rng.randf())
			if rng.randf() < 0.25:
				base_col = base_col.lightened(0.10)
			_add_leaf(p, s, base_col, rng.randf_range(0.65, 0.92))
		# 悬垂在路径上的枝冠
		if canopy > 2.2:
			_add_leaf(pos + Vector3(-2.2, height * 0.78, 1.6), canopy * 0.32,
				Color(0.19, 0.30, 0.17), 0.6)
			_add_leaf(pos + Vector3(-3.1, height * 0.62, 0.7), canopy * 0.22,
				Color(0.24, 0.36, 0.20), 0.55)
	_cylinder_collision(pos, maxf(0.35, height * 0.10), height * 0.9)


# ── 草 / 花 ────────────────────────────────────────────────────────────
func _build_grass_flowers() -> void:
	# 环形草丛：池边、墙脚、树下、石缝。
	for i in 430:
		var a := rng.randf() * TAU
		var r := rng.randf_range(8.0, 10.9)
		_add_grass(Vector3(cos(a) * r, 0, sin(a) * r), rng.randf_range(0.8, 1.5))
	for i in 150:
		var a := rng.randf() * TAU
		var r := POOL_RADIUS + rng.randf_range(0.65, 1.9)
		_add_grass(POOL_CENTER + Vector3(cos(a) * r, 0, sin(a) * r), rng.randf_range(0.7, 1.3))
	for i in 280:
		var p := _random_courtyard_point(1.6, 10.3)
		if _dist_to_path(p.x, p.z) < 0.55:
			continue
		_add_grass(p, rng.randf_range(0.55, 1.2))
	var tree_pts := [Vector3(7.0, 0, -3.4), Vector3(-7.9, 0, -6.9), Vector3(8.8, 0, 5.3), Vector3(-8.4, 0, 5.4)]
	for tp in tree_pts:
		for i in 70:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.5, 2.8)
			_add_grass(tp + Vector3(cos(a) * r, 0, sin(a) * r), rng.randf_range(0.7, 1.35))
	for i in 120:
		var p := _path_edge_point()
		_add_grass(p, rng.randf_range(0.55, 0.95))
	# 灌木丛边的花
	for i in 90:
		var p := _random_courtyard_point(2.0, 10.4)
		if _dist_to_path(p.x, p.z) < 0.7:
			continue
		if Vector2(p.x - POOL_CENTER.x, p.z - POOL_CENTER.z).length() < POOL_RADIUS + 0.4:
			continue
		_flower_xf.append(_xf(p, Vector3(0, rng.randf_range(0, 360), 0),
			Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.8, 1.5), rng.randf_range(0.8, 1.4))))
		var fc := Color(0.92, 0.82, 0.58)
		var roll := rng.randf()
		if roll < 0.25:
			fc = Color(0.82, 0.56, 0.62)
		elif roll < 0.45:
			fc = Color(0.68, 0.72, 0.88)
		elif roll < 0.6:
			fc = Color(0.95, 0.90, 0.70)
		_flower_col.append(fc)

	# 苔藓斑块：贴地的压扁球，专门打散石板网格。
	for i in 150:
		var p := _random_courtyard_point(1.0, 10.6)
		if Vector2(p.x - POOL_CENTER.x, p.z - POOL_CENTER.z).length() < POOL_RADIUS + 0.2:
			continue
		if _dist_to_path(p.x, p.z) < 0.62:
			continue
		var s := rng.randf_range(0.10, 0.44)
		_leaf_xf.append(_xf(Vector3(p.x, 0.058, p.z), Vector3(0, rng.randf_range(0, 360), 0),
			Vector3(s, 0.018, s * rng.randf_range(0.7, 1.1))))
		_leaf_col.append(Color(0.18, 0.27, 0.15).lerp(Color(0.31, 0.41, 0.20), rng.randf()))
	# 落叶：沿路缘的橙褐色小片，给黄昏加一点暖色碎点。
	for i in 90:
		var p := _path_edge_point()
		var s := rng.randf_range(0.05, 0.11)
		_leaf_xf.append(_xf(Vector3(p.x, 0.066, p.z), Vector3(0, rng.randf_range(0, 360), 0),
			Vector3(s, 0.014, s * 0.75)))
		_leaf_col.append(Color(0.62, 0.40, 0.18).lerp(Color(0.80, 0.56, 0.24), rng.randf()))
	# 墙脚 / 外圈的厚草，压住空旷感。
	for i in 190:
		var p := _random_courtyard_point(8.4, 10.9)
		_add_grass(p, rng.randf_range(0.9, 1.6))
	for i in 150:
		var p := _path_edge_point()
		_add_grass(p, rng.randf_range(0.7, 1.2))


func _add_grass(pos: Vector3, scale_v: float) -> void:
	if Vector2(pos.x - POOL_CENTER.x, pos.z - POOL_CENTER.z).length() < POOL_RADIUS + 0.25:
		return
	if Vector2(pos.x, pos.z).length() > 11.1:
		return
	var h := scale_v * rng.randf_range(0.85, 1.25)
	_grass_xf.append(_xf(Vector3(pos.x, 0.055, pos.z), Vector3(0, rng.randf_range(0, 360), 0),
		Vector3(scale_v * rng.randf_range(0.9, 1.2), h, scale_v * rng.randf_range(0.9, 1.2))))
	var g := Color(0.25, 0.34, 0.19).lerp(Color(0.42, 0.51, 0.25), rng.randf())
	if rng.randf() < 0.15:
		g = g.lightened(0.08)
	_grass_col.append(g)


func _random_courtyard_point(rmin: float, rmax: float) -> Vector3:
	var a := rng.randf() * TAU
	var r := rng.randf_range(rmin, rmax)
	return Vector3(cos(a) * r, 0, sin(a) * r)


func _path_edge_point() -> Vector3:
	var idx := rng.randi() % (PATH_POINTS.size() - 1)
	var a := PATH_POINTS[idx]
	var b := PATH_POINTS[idx + 1]
	var t := rng.randf()
	var p := a.lerp(b, t)
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * (rng.randf_range(0.85, 1.25) * (1.0 if rng.randf() > 0.5 else -1.0))
	return Vector3(p.x + n.x, 0, p.y + n.y)


func _build_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var a := rng.randf() * TAU
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.08)
		var h := rng.randf_range(0.24, 0.40)
		var w := rng.randf_range(0.028, 0.045)
		var side := Vector3(cos(a + PI * 0.5), 0, sin(a + PI * 0.5)) * w
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.05, 0.16)
		var tip := base + Vector3(0, h, 0) + lean
		var n := Vector3(cos(a), 0.8, sin(a)).normalized()
		var dark := Color(0.55, 0.62, 0.42)
		var light := Color(0.95, 1.0, 0.72)
		# 正面
		st.set_color(dark); st.set_normal(n); st.set_uv(Vector2(0, 0)); st.add_vertex(base - side)
		st.set_color(dark); st.set_normal(n); st.set_uv(Vector2(1, 0)); st.add_vertex(base + side)
		st.set_color(light); st.set_normal(n); st.set_uv(Vector2(0.5, 1)); st.add_vertex(tip)
		# 背面
		st.set_color(dark); st.set_normal(-n); st.set_uv(Vector2(0, 0)); st.add_vertex(base + side)
		st.set_color(dark); st.set_normal(-n); st.set_uv(Vector2(1, 0)); st.add_vertex(base - side)
		st.set_color(light); st.set_normal(-n); st.set_uv(Vector2(0.5, 1)); st.add_vertex(tip)
	return st.commit()


func _build_flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	var stem := CylinderMesh.new()
	stem.top_radius = 0.006
	stem.bottom_radius = 0.008
	stem.height = 0.24
	stem.radial_segments = 4
	stem.rings = 1
	_pipe_append(st, stem, Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)))
	var head := SphereMesh.new()
	head.radius = 0.045
	head.height = 0.09
	head.radial_segments = 5
	head.rings = 3
	_pipe_append(st, head, Transform3D(Basis.IDENTITY, Vector3(0, 0.255, 0)))
	return st.commit()


# ── 长椅 / 石狐雕像 ────────────────────────────────────────────────────
func _build_benches_statue() -> void:
	_bench(Vector3(5.2, 0, 2.4), -55.0)
	_bench(Vector3(-6.0, 0, -4.4), 115.0)

	var base := Vector3(4.8, 0, 5.2)
	var stone := Color(0.58, 0.58, 0.49)
	_add_box(base + Vector3(0, 0.35, 0), Vector3(1.0, 0.7, 0.9), Vector3(0, -20, 0), Color(0.47, 0.48, 0.41))
	# 石狐：坐姿，头朝池心
	var yaw := -125.0
	var rot := Basis(Vector3.UP, deg_to_rad(yaw))
	var fwd := rot * Vector3(0, 0, -1)
	var right := rot * Vector3(1, 0, 0)
	var top := base + Vector3(0, 0.7, 0)
	_add_box(top + Vector3(0, 0.38, 0), Vector3(0.48, 0.62, 0.72), Vector3(0, yaw, 0), stone)
	_add_box(top + Vector3(0, 0.48, 0) + fwd * 0.22, Vector3(0.40, 0.36, 0.30), Vector3(0, yaw, 0), stone)
	_add_box(top + Vector3(0, 0.78, 0) + fwd * 0.34, Vector3(0.36, 0.32, 0.34), Vector3(0, yaw - 8, 0), stone)
	_add_box(top + Vector3(0, 0.76, 0) + fwd * 0.53, Vector3(0.18, 0.14, 0.22), Vector3(0, yaw, 0), stone.darkened(0.05))
	for sx in [-1, 1]:
		_add_box(top + Vector3(0, 0.96, 0) + fwd * 0.30 + right * (sx * 0.11),
			Vector3(0.11, 0.20, 0.10), Vector3(0, yaw, sx * 8), stone)
		_add_box(top + Vector3(0, 0.18, 0) + fwd * 0.18 + right * (sx * 0.13),
			Vector3(0.10, 0.36, 0.12), Vector3(0, yaw, 0), stone.darkened(0.03))
	# 尾巴：三节弯曲
	var tail_base := top + Vector3(0, 0.35, 0) - fwd * 0.32
	_add_cyl(tail_base, 0.10, 0.55, Vector3(0, yaw, 55), stone)
	_add_cyl(tail_base + Vector3(0, 0.22, 0) - fwd * 0.28, 0.08, 0.42, Vector3(0, yaw + 20, 20), stone)
	_add_cyl(tail_base + Vector3(0, 0.38, 0) - fwd * 0.42, 0.06, 0.30, Vector3(0, yaw + 40, -10), stone)
	# 苔藓
	_add_leaf(top + Vector3(0, 0.98, 0) + fwd * 0.30, 0.20, Color(0.23, 0.33, 0.18), 0.35)
	_add_leaf(top + Vector3(0, 0.70, 0) - fwd * 0.10, 0.22, Color(0.20, 0.30, 0.17), 0.4)
	_forbid_collision_at(base + Vector3(0, 0.6, 0), 0.65, 1.2)


func _bench(pos: Vector3, yaw: float) -> void:
	var rot := Basis(Vector3.UP, deg_to_rad(yaw))
	var wood := Color(0.42, 0.29, 0.19)
	for i in 3:
		var local := Vector3(0, 0.46, -0.18 + i * 0.18)
		_add_box(pos + rot * local, Vector3(1.55, 0.065, 0.16), Vector3(0, yaw, 0), wood)
	for i in 2:
		var local := Vector3(0, 0.66 + i * 0.20, 0.26)
		_add_box(pos + rot * local, Vector3(1.55, 0.08, 0.06), Vector3(0, yaw, 0), wood.lightened(0.04))
	for sx in [-1, 1]:
		var local := Vector3(sx * 0.62, 0.23, 0.02)
		_add_box(pos + rot * local, Vector3(0.16, 0.46, 0.58), Vector3(0, yaw, 0), Color(0.44, 0.44, 0.37))
	_forbid_collision_at(pos + Vector3(0, 0.45, 0), 0.95, 0.9, yaw)


# ── 路灯 ───────────────────────────────────────────────────────────────
func _build_lamps() -> void:
	_lamp_metal_mesh = _make_lamp_metal_mesh()
	var lamp_warm := Color(1.0, 0.70, 0.36)
	for i in LAMP_SPECS.size():
		var spec: Dictionary = LAMP_SPECS[i]
		var pos: Vector3 = spec["pos"]
		var root := Node3D.new()
		root.name = "Lamp%d" % i
		root.position = pos
		add_child(root)
		var metal := MeshInstance3D.new()
		metal.mesh = _lamp_metal_mesh
		metal.material_override = _mats["metal"]
		metal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(metal)
		var glass_mat := StandardMaterial3D.new()
		glass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glass_mat.albedo_color = Color(0.16, 0.11, 0.07)
		glass_mat.disable_receive_shadows = true
		var glass := MeshInstance3D.new()
		var gbox := BoxMesh.new()
		gbox.size = Vector3(0.19, 0.26, 0.19)
		glass.mesh = gbox
		glass.material_override = glass_mat
		glass.position = Vector3(0, 2.24, 0)
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(glass)
		var light := OmniLight3D.new()
		light.name = "Flame"
		light.light_color = lamp_warm
		light.light_energy = 0.0
		light.omni_range = 5.4
		light.omni_attenuation = 1.35
		light.shadow_enabled = false
		light.position = Vector3(0, 2.24, 0)
		root.add_child(light)
		# 灯笼辉光（billboard 加色）
		var glow_mat := StandardMaterial3D.new()
		glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		glow_mat.albedo_texture = _glow_tex
		glow_mat.albedo_color = Color(lamp_warm.r, lamp_warm.g, lamp_warm.b, 0.0)
		glow_mat.disable_receive_shadows = true
		glow_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var glow := MeshInstance3D.new()
		var gq := QuadMesh.new()
		gq.size = Vector2(0.95, 0.95)
		glow.mesh = gq
		glow.material_override = glow_mat
		glow.position = Vector3(0, 2.24, 0)
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		root.add_child(glow)
		# 地面光池
		var pool_mat := StandardMaterial3D.new()
		pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		pool_mat.albedo_texture = _pool_tex
		pool_mat.albedo_color = Color(lamp_warm.r, lamp_warm.g, lamp_warm.b, 0.0)
		pool_mat.disable_receive_shadows = true
		pool_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var pool := MeshInstance3D.new()
		var pq := PlaneMesh.new()
		pq.size = Vector2(5.8, 5.8)
		pool.mesh = pq
		pool.material_override = pool_mat
		pool.position = Vector3(0, 0.115, 0)
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pool.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		root.add_child(pool)
		lamps.append({
			"root": root,
			"pos": pos,
			"threshold": float(spec["threshold"]),
			"light": light,
			"glass_mat": glass_mat,
			"glow_mat": glow_mat,
			"glow": glow,
			"pool_mat": pool_mat,
			"pool": pool,
			"reflect_mat": null,
			"reflect": null,
		})
		# 灯座碰撞
		_cylinder_collision(pos, 0.28, 2.6)

	# 离水池最近的一盏加水面倒影条（其余靠 water shader 的 3 盏暖斑）。
	var dists: Array = []
	for i in lamps.size():
		dists.append({"i": i, "d": lamps[i]["pos"].distance_to(POOL_CENTER)})
	dists.sort_custom(func(a, b): return a["d"] < b["d"])
	_water_lamp_indices.clear()
	for k in mini(3, dists.size()):
		_water_lamp_indices.append(int(dists[k]["i"]))
	var refl_idx := int(dists[0]["i"])
	var lamp_pos: Vector3 = lamps[refl_idx]["pos"]
	var to_center := (POOL_CENTER - Vector3(lamp_pos.x, 0, lamp_pos.z)).normalized()
	var rp := Vector3(lamp_pos.x, 0.055, lamp_pos.z) + to_center * (lamp_pos.distance_to(POOL_CENTER) - POOL_RADIUS + 0.9)
	var reflect := MeshInstance3D.new()
	var rq := PlaneMesh.new()
	rq.size = Vector2(0.9, 2.3)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rmat.albedo_texture = _glow_tex
	rmat.albedo_color = Color(lamp_warm.r, lamp_warm.g, lamp_warm.b, 0.0)
	rmat.disable_receive_shadows = true
	rmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	reflect.mesh = rq
	reflect.material_override = rmat
	reflect.position = rp
	reflect.rotation_degrees.y = rad_to_deg(atan2(to_center.x, to_center.z))
	reflect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reflect.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(reflect)
	lamps[refl_idx]["reflect_mat"] = rmat
	lamps[refl_idx]["reflect"] = reflect


func _make_lamp_metal_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := BoxMesh.new()
	base.size = Vector3(0.52, 0.24, 0.52)
	_pipe_append(st, base, Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.045
	pole.bottom_radius = 0.075
	pole.height = 1.86
	pole.radial_segments = 6
	pole.rings = 1
	_pipe_append(st, pole, Transform3D(Basis.IDENTITY, Vector3(0, 1.12, 0)))
	var collar := BoxMesh.new()
	collar.size = Vector3(0.18, 0.07, 0.18)
	_pipe_append(st, collar, Transform3D(Basis.IDENTITY, Vector3(0, 2.04, 0)))
	var plate := BoxMesh.new()
	plate.size = Vector3(0.31, 0.055, 0.31)
	_pipe_append(st, plate, Transform3D(Basis.IDENTITY, Vector3(0, 2.08, 0)))
	var post := BoxMesh.new()
	post.size = Vector3(0.022, 0.30, 0.022)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_pipe_append(st, post, Transform3D(Basis.IDENTITY, Vector3(sx * 0.135, 2.25, sz * 0.135)))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.02
	roof.bottom_radius = 0.27
	roof.height = 0.18
	roof.radial_segments = 4
	roof.rings = 1
	var rb := Basis(Vector3.UP, deg_to_rad(45.0))
	_pipe_append(st, roof, Transform3D(rb, Vector3(0, 2.49, 0)))
	var finial := SphereMesh.new()
	finial.radius = 0.038
	finial.height = 0.076
	finial.radial_segments = 6
	finial.rings = 3
	_pipe_append(st, finial, Transform3D(Basis.IDENTITY, Vector3(0, 2.62, 0)))
	return st.commit()


# ── 光柱 ───────────────────────────────────────────────────────────────
func _build_shafts() -> void:
	var base_specs := [
		{"pos": Vector3(0.3, 8.0, -10.0), "rot": Vector3(5, 0, -14), "mult": 1.0, "radius": 1.7},
		{"pos": Vector3(6.8, 8.0, -4.6), "rot": Vector3(3, 0, -11), "mult": 0.5, "radius": 1.1},
		{"pos": Vector3(-5.4, 8.0, -0.5), "rot": Vector3(2, 0, -8), "mult": 0.35, "radius": 0.9},
	]
	for spec in base_specs:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.32
		mesh.bottom_radius = float(spec["radius"])
		mesh.height = 16.0
		mesh.radial_segments = 12
		mesh.rings = 3
		mesh.cap_top = false
		mesh.cap_bottom = false
		var mi := MeshInstance3D.new()
		mi.name = "LightShaft"
		mi.mesh = mesh
		mi.position = spec["pos"]
		mi.rotation_degrees = spec["rot"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var mat := ShaderMaterial.new()
		mat.shader = SHAFT_SHADER
		mat.set_shader_parameter("shaft_color", Color(1.0, 0.72, 0.44))
		mat.set_shader_parameter("intensity", 0.5)
		mat.set_shader_parameter("height", 16.0)
		mat.set_shader_parameter("streak_scale", 1.0)
		mi.material_override = mat
		add_child(mi)
		shaft_nodes.append(mi)
		shaft_mats.append({"mat": mat, "mult": float(spec["mult"])})


# ── 角色 / 萤火 ────────────────────────────────────────────────────────
func _build_character() -> void:
	keeper = KEEPER_SCRIPT.new()
	keeper.name = "LanternKeeper"
	add_child(keeper)
	keeper.teleport(START_POS, 0.0)


func _build_fireflies() -> void:
	fireflies = FIREFLY_SCRIPT.new()
	fireflies.name = "Fireflies"
	add_child(fireflies)
	var zones := [
		{"center": POOL_CENTER + Vector3(0, 0.85, 0), "radius": 3.1, "min_y": 0.45, "spread_y": 1.5, "weight": 0.26},
		{"center": Vector3(7.0, 1.5, -3.2), "radius": 2.6, "min_y": 0.5, "spread_y": 1.8, "weight": 0.20},
		{"center": Vector3(-7.0, 1.0, 3.8), "radius": 2.3, "min_y": 0.35, "spread_y": 1.4, "weight": 0.16},
		{"center": Vector3(0.3, 1.3, -7.2), "radius": 2.1, "min_y": 0.4, "spread_y": 1.6, "weight": 0.12},
		{"center": Vector3(1.8, 1.0, 3.8), "radius": 2.0, "min_y": 0.3, "spread_y": 1.3, "weight": 0.10},
		{"center": Vector3(1.1, 1.2, 0.4), "radius": 2.6, "min_y": 0.3, "spread_y": 1.4, "weight": 0.12},
		{"center": Vector3(1.2, 1.0, 4.8), "radius": 2.2, "min_y": 0.3, "spread_y": 1.2, "weight": 0.08},
		{"center": Vector3(8.4, 1.1, 6.6), "radius": 2.2, "min_y": 0.3, "spread_y": 1.5, "weight": 0.05},
		{"center": Vector3(-9.0, 1.4, -5.2), "radius": 2.0, "min_y": 0.4, "spread_y": 1.6, "weight": 0.05},
	]
	fireflies.setup(160, zones, 20261127, _spark_tex)


# ── 静态批次 ───────────────────────────────────────────────────────────
func _flush_static_meshes() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_make_multi(box, _mats["stone_box"], _stone_xf, _stone_col, "StoneBoxes", true)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	_make_multi(cyl, _mats["stone_cyl"], _stone_cyl_xf, _stone_cyl_col, "StoneCylinders", true)
	_make_multi(box, _mats["wood"], _wood_xf, _wood_col, "Wood", true)
	var bark := CylinderMesh.new()
	bark.top_radius = 0.5
	bark.bottom_radius = 0.5
	bark.height = 1.0
	bark.radial_segments = 7
	bark.rings = 1
	_make_multi(bark, _mats["bark"], _bark_xf, _bark_col, "TreeTrunks", true)
	var leaf := SphereMesh.new()
	leaf.radius = 1.0
	leaf.height = 2.0
	leaf.radial_segments = 7
	leaf.rings = 4
	_make_multi(leaf, _mats["leaf"], _leaf_xf, _leaf_col, "Foliage", true)
	_make_multi(leaf, _mats["leaf"], _outer_leaf_xf, _outer_leaf_col, "OuterFoliage", false)
	_make_multi(bark, _mats["bark"], _outer_bark_xf, _outer_bark_col, "OuterTrunks", false)
	_make_multi(_build_tuft_mesh(), _mats["grass"], _grass_xf, _grass_col, "Grass", false)
	_make_multi(_build_flower_mesh(), _mats["flower"], _flower_xf, _flower_col, "Flowers", false)
	var pad := CylinderMesh.new()
	pad.top_radius = 1.0
	pad.bottom_radius = 1.0
	pad.height = 0.018
	pad.radial_segments = 10
	pad.rings = 1
	_make_multi(pad, _mats["lily"], _lily_xf, _lily_col, "LilyPads", false)


# ── 静态碰撞 ───────────────────────────────────────────────────────────
var _pending_colliders: Array = []


func _forbid_collision_at(pos: Vector3, radius: float, height: float, yaw: float = 0.0) -> void:
	_pending_colliders.append({"kind": "box", "pos": pos, "radius": radius, "height": height, "yaw": yaw})


func _cylinder_collision(pos: Vector3, radius: float, height: float) -> void:
	_pending_colliders.append({"kind": "cyl", "pos": pos + Vector3(0, height * 0.5, 0), "radius": radius, "height": height, "yaw": 0.0})


func _build_colliders() -> void:
	# 地面
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var gshape := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(30, 1.2, 30)
	gshape.shape = gbox
	gshape.position = Vector3(0, -0.525, 0)
	ground.add_child(gshape)
	add_child(ground)
	# 边界（墙外）
	for sx in [-1, 1]:
		var b := StaticBody3D.new()
		b.collision_layer = 1
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.8, 6, 26)
		cs.shape = box
		cs.position = Vector3(sx * 12.15, 3, 0)
		b.add_child(cs)
		add_child(b)
	for sz in [-1, 1]:
		var b := StaticBody3D.new()
		b.collision_layer = 1
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(26, 6, 0.8)
		cs.shape = box
		cs.position = Vector3(0, 3, sz * 12.15)
		b.add_child(cs)
		add_child(b)
	# 水池不可走入（layer 4：角色挡住，相机射线不受影响）
	var pool_body := StaticBody3D.new()
	pool_body.collision_layer = 4
	pool_body.position = POOL_CENTER + Vector3(0, 0.3, 0)
	var pcol := CollisionShape3D.new()
	var pcyl := CylinderShape3D.new()
	pcyl.radius = POOL_RADIUS + 0.15
	pcyl.height = 0.6
	pcol.shape = pcyl
	pool_body.add_child(pcol)
	add_child(pool_body)
	# 柱 / 树 / 灯 / 长椅 / 雕像
	for c in _pending_colliders:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		if c["kind"] == "cyl":
			var shape := CylinderShape3D.new()
			shape.radius = float(c["radius"])
			shape.height = float(c["height"])
			cs.shape = shape
			body.position = c["pos"]
		else:
			var shape := BoxShape3D.new()
			shape.size = Vector3(float(c["radius"]) * 1.6, float(c["height"]), float(c["radius"]) * 1.2)
			cs.shape = shape
			body.position = c["pos"]
			body.rotation_degrees.y = float(c["yaw"])
		body.add_child(cs)
		add_child(body)


# ── 时间/环境应用 ──────────────────────────────────────────────────────
func apply_environment(state: Dictionary) -> void:
	if sun_light != null:
		var sun_e := float(state.get("sun_energy", 1.0))
		var moon_e := float(state.get("moon_energy", 0.0))
		var use_moon := moon_e > sun_e
		var elev := float(state.get("moon_elev", 30.0)) if use_moon else float(state.get("sun_elev", 10.0))
		var azim := float(state.get("moon_azim", 55.0)) if use_moon else float(state.get("sun_azim", -125.0))
		sun_light.rotation_degrees = Vector3(-elev, azim, 0.0)
		var light_col: Color = state.get("moon_color", Color(0.55, 0.66, 0.92)) if use_moon else state.get("sun_color", Color(1, 0.7, 0.45))
		sun_light.light_color = light_col
		sun_light.light_energy = maxf(sun_e, moon_e)
		sun_light.shadow_enabled = sun_light.light_energy > 0.08
	if env != null:
		env.ambient_light_color = state.get("ambient_color", Color(0.5, 0.42, 0.5))
		env.ambient_light_energy = float(state.get("ambient_energy", 0.55))
	if sky_mat != null:
		sky_mat.set_shader_parameter("sun_dir", state.get("sun_dir", Vector3(-0.7, 0.2, -0.6)))
		sky_mat.set_shader_parameter("sun_glow_color", state.get("sun_glow", Color(1, 0.62, 0.32)))
		sky_mat.set_shader_parameter("sun_strength", float(state.get("sun_sky", 1.0)))
		sky_mat.set_shader_parameter("moon_dir", state.get("moon_dir", Vector3(0.7, 0.5, 0.7)))
		sky_mat.set_shader_parameter("moon_strength", float(state.get("moon_sky", 0.0)))
		sky_mat.set_shader_parameter("cloud_highlight", state.get("cloud_highlight", Color(0.95, 0.7, 0.55)))
		sky_mat.set_shader_parameter("cloud_density", float(state.get("cloud_density", 0.8)))
	if water_mat != null:
		water_mat.set_shader_parameter("deep_color", state.get("water_deep", Color(0.045, 0.11, 0.13)))
		water_mat.set_shader_parameter("shallow_color", state.get("water_shallow", Color(0.16, 0.28, 0.25)))
		water_mat.set_shader_parameter("ripple_strength", 0.8 + float(state.get("wind", 1.0)) * 0.35)
		water_mat.set_shader_parameter("moon_dir", state.get("moon_dir", Vector3(0, 0.7, 0.7)))
		water_mat.set_shader_parameter("moon_strength", float(state.get("moon_sky", 0.0)))
		water_mat.set_shader_parameter("sun_dir", state.get("sun_dir", Vector3(-0.5, 0.2, -0.8)))
		water_mat.set_shader_parameter("sun_strength", float(state.get("sun_sky", 1.0)))
		water_mat.set_shader_parameter("sun_glow_color", state.get("sun_glow", Color(1.0, 0.62, 0.30)))
	for s in shaft_mats:
		var mat: ShaderMaterial = s["mat"]
		mat.set_shader_parameter("shaft_color", state.get("shaft_color", Color(1, 0.72, 0.44)))
		mat.set_shader_parameter("intensity", float(state.get("shaft_i", 0.3)) * float(s["mult"]))
	if keeper != null:
		var night := float(state.get("night", 0.0))
		keeper.set_lantern_energy(0.18 + night * 0.25)


func apply_lamp_levels(levels: Array) -> void:
	for i in lamps.size():
		var lamp: Dictionary = lamps[i]
		var lv := clampf(float(levels[i]) if i < levels.size() else 0.0, 0.0, 1.0)
		var warm := Color(1.0, 0.70, 0.36)
		var light: OmniLight3D = lamp["light"]
		light.light_energy = pow(lv, 0.85) * 1.55
		var glass_mat: StandardMaterial3D = lamp["glass_mat"]
		glass_mat.albedo_color = Color(0.16, 0.11, 0.07).lerp(Color(1.0, 0.84, 0.52), lv)
		var glow_mat: StandardMaterial3D = lamp["glow_mat"]
		glow_mat.albedo_color = Color(warm.r, warm.g, warm.b, lv * 0.62)
		var glow: MeshInstance3D = lamp["glow"]
		glow.scale = Vector3.ONE * (0.8 + lv * 0.45)
		var pool_mat: StandardMaterial3D = lamp["pool_mat"]
		pool_mat.albedo_color = Color(warm.r, warm.g, warm.b, lv * 0.34)
		var refl: MeshInstance3D = lamp.get("reflect", null)
		if refl != null:
			refl.visible = lv > 0.02
			var rmat: StandardMaterial3D = lamp["reflect_mat"]
			rmat.albedo_color = Color(warm.r, warm.g, warm.b, lv * 0.5)
	# 水面：喂入最近的 3 盏
	if water_mat != null:
		var pos_arr := PackedVector3Array()
		var energy := PackedFloat32Array()
		for idx in _water_lamp_indices:
			var lp: Vector3 = lamps[idx]["pos"]
			pos_arr.append(Vector3(lp.x, 0.055, lp.z))
			energy.append(clampf(float(levels[idx]) if idx < levels.size() else 0.0, 0.0, 1.0))
		while pos_arr.size() < 3:
			pos_arr.append(Vector3.ZERO)
			energy.append(0.0)
		water_mat.set_shader_parameter("lamp_pos", pos_arr)
		water_mat.set_shader_parameter("lamp_energy", energy)
		water_mat.set_shader_parameter("lamp_count", 3)


func prewarm_fireflies(seconds: float) -> void:
	if fireflies != null:
		fireflies.advance(seconds)


func set_paused(value: bool) -> void:
	if fireflies != null:
		fireflies.set_paused(value)
	if keeper != null:
		keeper.set_paused(value)


func get_lamp_thresholds() -> Array[float]:
	var out: Array[float] = []
	for l in lamps:
		out.append(float(l["threshold"]))
	return out


func get_lamp_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for l in lamps:
		out.append(l["pos"])
	return out


func get_lamp_levels() -> Array[float]:
	var out: Array[float] = []
	for l in lamps:
		var light: OmniLight3D = l["light"]
		out.append(clampf(light.light_energy / 1.85, 0.0, 1.0))
	return out
