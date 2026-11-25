extends Node3D
## 苔光浮庭 · 原创程序化浮岛场景。
## 场景构成：浮空苔岛 + 石径 + 月树 + 苔灯 + 水塘锦鲤 + 小茶亭 + 苔猫 + 玻璃风铃。
## 所有模型、贴图与材质的噪声均在本文件/geo.gd 内生成；无外部美术资源。
## 微动画：草/花风摆、树冠呼吸、岛体轻浮、水波与鱼、萤火/浮尘/落花/雨、灯光呼吸。

signal interaction_feedback(id: String, message: String, anchor: Vector3)

const Geo = preload("res://scripts/geo.gd")
const GROUND_SHADER = preload("res://shaders/ground.gdshader")
const WIND_SHADER = preload("res://shaders/wind_foliage.gdshader")
const WATER_SHADER = preload("res://shaders/water.gdshader")
const PATH_SHADER = preload("res://shaders/path.gdshader")
const MoonLanternScript = preload("res://scripts/moon_lantern.gd")
const MossCatScript = preload("res://scripts/moss_cat.gd")
const WindChimeScript = preload("res://scripts/wind_chime.gd")

const ISLAND_RX := 11.8
const ISLAND_RZ := 8.5
const TREE_BASE := Vector3(-3.4, 0.0, -2.5)
const PAVILION_BASE := Vector3(5.05, 0.0, -2.85)
const PAVILION_ROT := -0.18
const POND_CENTER := Vector3(4.35, 0.0, 2.1)
const POND_RX := 2.55
const POND_RZ := 1.65
const POND_ROT := -0.16
const CAT_POS := Vector3(1.85, 0.02, -0.35)
const LANTERN_POSITIONS := [
	Vector3(-1.85, 0.0, 1.05),
	Vector3(6.80, 0.0, 0.15),
]
const PATH_MAIN := [
	Vector3(-2.35, 0.03, 7.15), Vector3(-1.15, 0.03, 5.45),
	Vector3(0.05, 0.03, 3.95), Vector3(0.52, 0.03, 2.30),
	Vector3(-0.15, 0.03, 0.45), Vector3(-1.35, 0.03, -1.20),
	Vector3(-2.45, 0.03, -2.35),
]
const PATH_SPUR := [
	Vector3(0.30, 0.03, -0.20), Vector3(1.45, 0.03, -0.85),
	Vector3(2.65, 0.03, -1.55), Vector3(3.80, 0.03, -2.10),
]

var island_root: Node3D
var ground: MeshInstance3D
var path_mesh: MeshInstance3D
var side_mesh: MeshInstance3D
var boulder_multimesh: MultiMeshInstance3D
var water_mesh: MeshInstance3D
var pond_bottom: MeshInstance3D
var lily_mesh: MeshInstance3D
var grass_multimesh: MultiMeshInstance3D
var daisy_multimesh: MultiMeshInstance3D
var lavender_multimesh: MultiMeshInstance3D
var bush_multimesh: MultiMeshInstance3D
var fern_multimesh: MultiMeshInstance3D
var mushroom_multimesh: MultiMeshInstance3D
var fallen_petals: MeshInstance3D
var tree_root: Node3D
var canopy_pivots: Array[Dictionary] = []
var pods_root: Node3D
var pod_light: OmniLight3D
var pod_material: StandardMaterial3D
var tree_warm_light: OmniLight3D
var pavilion_root: Node3D
var pavilion_lamp: Node3D
var pavilion_lamp_material: StandardMaterial3D
var pavilion_lamp_halo_material: StandardMaterial3D
var pavilion_lamp_light: OmniLight3D
var steam: CPUParticles3D
var lanterns: Array = []
var cat = null
var wind_chime = null
var interactables: Array = []
var koi_data: Array[Dictionary] = []
var fireflies: GPUParticles3D
var pollen: GPUParticles3D
var falling_petals: CPUParticles3D
var rain: CPUParticles3D
var bokeh: Array[Dictionary] = []
var mist_cards: Array[MeshInstance3D] = []
var mist_material: StandardMaterial3D
var floating_shards: Array[Dictionary] = []
var _mist_base: Array[Vector3] = []
var _mist_phase: Array[float] = []

var ground_material: ShaderMaterial
var grass_material: ShaderMaterial
var canopy_material: ShaderMaterial
var flower_material: ShaderMaterial
var understory_material: ShaderMaterial
var mushroom_material: ShaderMaterial
var water_material: ShaderMaterial
var path_material: ShaderMaterial
var stone_material: StandardMaterial3D
var petals_ground_material: StandardMaterial3D

var anim_time := 0.0
var nightness := 1.0
var rain_amount := 0.0
var quality_high := true
var wind_gust := 0.0
var grass_placed := 0
var daisy_placed := 0
var lavender_placed := 0
var _built := false
var _rng := RandomNumberGenerator.new()
var _soft_tex: ImageTexture
var _cloud_tex: ImageTexture
var _path_clear_points: Array[Vector2] = []
var _boulder_transforms: Array[Transform3D] = []
var _boulder_colors: Array[Color] = []
var _floor_y := 0.0


func setup() -> void:
	if _built:
		return
	_built = true
	_rng.seed = 20261125
	_soft_tex = Geo.make_radial_texture(48, 2.0)
	_cloud_tex = Geo.make_cloud_texture(128)
	_build_materials()
	island_root = Node3D.new()
	island_root.name = "Island"
	add_child(island_root)
	_build_island()
	_build_paths()
	_build_pond()
	_build_boulders()
	_build_grass()
	_build_flower_fields()
	_build_understory()
	_build_main_tree()
	_build_small_trees()
	_build_pavilion()
	_build_lanterns()
	_build_cat()
	_build_particles()
	_build_bokeh()
	_build_mist()
	_build_floating_shards()
	_build_ground_shadows()


func _build_materials() -> void:
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER

	grass_material = _make_foliage_material(true, 0.055, 0.018, 0.0)
	canopy_material = _make_foliage_material(false, 0.018, 0.012, 0.0)
	flower_material = _make_foliage_material(false, 0.016, 0.006, 0.10)
	understory_material = _make_foliage_material(false, 0.028, 0.010, 0.0)
	mushroom_material = _make_foliage_material(false, 0.005, 0.003, 0.85)

	water_material = ShaderMaterial.new()
	water_material.shader = WATER_SHADER
	path_material = ShaderMaterial.new()
	path_material.shader = PATH_SHADER

	stone_material = Geo.make_vcol_material(0.92)
	stone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	petals_ground_material = Geo.make_vcol_material(0.90)
	petals_ground_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _make_foliage_material(uv_height: bool, sway: float, flutter: float, glow: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WIND_SHADER
	mat.set_shader_parameter("u_time", 0.0)
	mat.set_shader_parameter("sway", sway)
	mat.set_shader_parameter("flutter", flutter)
	mat.set_shader_parameter("wind_gust", 0.0)
	mat.set_shader_parameter("glow_strength", glow)
	mat.set_shader_parameter("tint", Color(1, 1, 1))
	mat.set_shader_parameter("use_uv_height", uv_height)
	mat.set_shader_parameter("root_bend", 0.0)
	return mat


# ────────────────────────────────────────────────────────────────────────
# 浮岛地形
# ────────────────────────────────────────────────────────────────────────

func _build_island() -> void:
	var top := Geo.surface()
	var sides := Geo.surface()
	var count := 72
	var center := Vector3(0, 0, 0)
	for i in range(count):
		var a := _contour_point(i, count, 1.0, 0.0)
		var b := _contour_point(i + 1, count, 1.0, 0.0)
		Geo.add_tri(top, center, b, a, Color(1, 1, 1), Vector3.UP)

	ground = MeshInstance3D.new()
	ground.name = "MossGround"
	ground.mesh = Geo.finish(top)
	ground.material_override = ground_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	island_root.add_child(ground)

	var bands := [
		{"scale": 1.0, "y": -0.02, "color": Color(0.17, 0.25, 0.15)},
		{"scale": 1.005, "y": -0.33, "color": Color(0.30, 0.23, 0.17)},
		{"scale": 0.985, "y": -1.15, "color": Color(0.33, 0.30, 0.43)},
		{"scale": 0.84, "y": -2.35, "color": Color(0.23, 0.22, 0.33)},
		{"scale": 0.60, "y": -3.55, "color": Color(0.15, 0.15, 0.24)},
	]
	var rings: Array[Array] = []
	for band_index in range(bands.size()):
		var band: Dictionary = bands[band_index]
		var ring: Array[Vector3] = []
		for i in range(count):
			var p := _contour_point(i, count, float(band["scale"]), float(band["y"]))
			var wobble := 0.035 * sin(float(i) * 2.17 + float(band_index) * 1.3)
			p.y += wobble
			ring.append(p)
		rings.append(ring)

	for level in range(rings.size() - 1):
		var upper: Array = rings[level]
		var lower: Array = rings[level + 1]
		var c0: Color = bands[level]["color"]
		var c1: Color = bands[level + 1]["color"]
		for i in range(count):
			var j := (i + 1) % count
			var shade := c0.lerp(c1, 0.35)
			shade = shade.lightened(_rng.randf_range(-0.035, 0.055))
			if level <= 1 and _rng.randf() < 0.30:
				shade = Color(0.30, 0.39, 0.24).lerp(shade, 0.55)
			Geo.add_quad(sides, upper[i], upper[j], lower[j], lower[i], shade)

	var bottom_ring: Array = rings[rings.size() - 1]
	var tip := Vector3(0.15, -5.1, -0.1)
	for i in range(count):
		var j := (i + 1) % count
		var shade := Color(0.16, 0.15, 0.24).lightened(_rng.randf_range(-0.02, 0.035))
		Geo.add_tri(sides, bottom_ring[i], bottom_ring[j], tip, shade)

	side_mesh = MeshInstance3D.new()
	side_mesh.name = "IslandStrata"
	side_mesh.mesh = Geo.finish(sides)
	side_mesh.material_override = stone_material
	side_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	island_root.add_child(side_mesh)

	# 岛缘垂下的细根，打破硬边。
	_build_rim_roots()


func _build_rim_roots() -> void:
	var st := Geo.surface()
	var count := 72
	for i in range(0, count, 4):
		if _rng.randf() < 0.42:
			continue
		var p := _contour_point(i, count, 0.985, -0.25)
		p.x *= 1.01
		p.z *= 1.01
		var down := _rng.randf_range(0.55, 1.8)
		var sway := Vector3(_rng.randf_range(-0.28, 0.28), 0, _rng.randf_range(-0.28, 0.28))
		var c := Color(0.23, 0.20, 0.13).lerp(Color(0.22, 0.31, 0.18), _rng.randf())
		Geo.add_cylinder(st, p, p + Vector3(0, -down, 0) + sway,
				0.035, 0.009, 4, c)
		if _rng.randf() > 0.35:
			var leaf := p + Vector3(0, -down * _rng.randf_range(0.5, 0.95), 0) + sway * 0.6
			Geo.add_leaf_card(st, leaf, 0.15, 0.19,
					Color(0.25, 0.37, 0.21), _rng, 0.05)
	var mi := MeshInstance3D.new()
	mi.name = "HangingRoots"
	mi.mesh = Geo.finish(st)
	mi.material_override = stone_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island_root.add_child(mi)


func _contour_point(i: int, count: int, scale: float, y: float) -> Vector3:
	var a := TAU * float(i) / float(count)
	var wave := 1.0 + 0.055 * sin(3.0 * a + 0.42) + 0.026 * sin(7.0 * a + 1.3) \
			+ 0.011 * sin(13.0 * a + 2.6)
	return Vector3(cos(a) * ISLAND_RX * wave * scale, y, sin(a) * ISLAND_RZ * wave * scale)


func _inside_island(x: float, z: float, margin := 1.0) -> bool:
	var a := atan2(z / ISLAND_RZ, x / ISLAND_RX)
	var wave := 1.0 + 0.055 * sin(3.0 * a + 0.42) + 0.026 * sin(7.0 * a + 1.3) \
			+ 0.011 * sin(13.0 * a + 2.6)
	var rho := sqrt((x / ISLAND_RX) * (x / ISLAND_RX) + (z / ISLAND_RZ) * (z / ISLAND_RZ))
	return rho <= wave * margin


func _pond_local(x: float, z: float) -> Vector2:
	var rel := Vector2(x - POND_CENTER.x, z - POND_CENTER.z)
	return rel.rotated(-POND_ROT)


func _inside_pond(x: float, z: float, margin := 1.0) -> bool:
	var local := _pond_local(x, z)
	return (local.x * local.x) / pow(POND_RX * margin, 2.0) \
			+ (local.y * local.y) / pow(POND_RZ * margin, 2.0) <= 1.0


func _near_path(x: float, z: float, radius: float) -> bool:
	var p := Vector2(x, z)
	for q in _path_clear_points:
		if p.distance_squared_to(q) < radius * radius:
			return true
	return false


func _dist2(ax: float, az: float, bx: float, bz: float) -> float:
	var dx := ax - bx
	var dz := az - bz
	return sqrt(dx * dx + dz * dz)


func _can_place_ground(x: float, z: float, island_margin: float, path_clear: float) -> bool:
	if not _inside_island(x, z, island_margin):
		return false
	if _near_path(x, z, path_clear):
		return false
	if _inside_pond(x, z, 1.15):
		return false
	var pav := Vector2(PAVILION_BASE.x, PAVILION_BASE.z)
	if Vector2(x, z).distance_to(pav) < 2.65:
		return false
	if _dist2(x, z, TREE_BASE.x, TREE_BASE.z) < 0.72:
		return false
	if _dist2(x, z, CAT_POS.x, CAT_POS.z) < 0.72:
		return false
	for pos in LANTERN_POSITIONS:
		if _dist2(x, z, pos.x, pos.z) < 0.55:
			return false
	return true


# ────────────────────────────────────────────────────────────────────────
# 踏石径 / 浮岛边缘与池塘卵石
# ────────────────────────────────────────────────────────────────────────

func _build_paths() -> void:
	var sand_st := Geo.surface()
	var edge_st := Geo.surface()
	var stone_st := Geo.surface()
	_add_path_curve(sand_st, edge_st, stone_st, PATH_MAIN, 86, 1.15, 5)
	_add_path_curve(sand_st, edge_st, stone_st, PATH_SPUR, 42, 0.82, 3)

	var edge := MeshInstance3D.new()
	edge.name = "PathSoftEdge"
	edge.mesh = Geo.finish(edge_st)
	edge.material_override = stone_material
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island_root.add_child(edge)

	path_mesh = MeshInstance3D.new()
	path_mesh.name = "SandPath"
	path_mesh.mesh = Geo.finish(sand_st)
	path_mesh.material_override = path_material
	path_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island_root.add_child(path_mesh)

	var stones := MeshInstance3D.new()
	stones.name = "PathPebbles"
	stones.mesh = Geo.finish(stone_st)
	stones.material_override = stone_material
	stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	island_root.add_child(stones)


func _add_path_curve(sand_st: SurfaceTool, edge_st: SurfaceTool, stone_st: SurfaceTool,
		control_points: Array, samples: int, base_width: float, accent_stones: int) -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 0.18
	for p in control_points:
		curve.add_point(p)
	var length := curve.get_baked_length()
	var pts: Array[Vector3] = []
	var widths: Array[float] = []
	for i in range(samples + 1):
		var t := float(i) / float(samples)
		var p := curve.sample_baked(t * length)
		p.y = 0.048
		var taper := 0.80 + 0.20 * sin(t * PI)
		var w := base_width * taper * (0.88 + 0.12 * sin(t * 41.0 + 0.7))
		pts.append(p)
		widths.append(w)
	# 分开画砂面与 soil 收边，避免两套颜色混在同一材质里。
	var edge_pts: Array[Vector3] = []
	for p in pts:
		edge_pts.append(Vector3(p.x, 0.035, p.z))
	Geo.add_ribbon(edge_st, edge_pts, _widen(widths, 0.20), Color(0.28, 0.27, 0.20), Color(0.25, 0.24, 0.18))
	Geo.add_ribbon(sand_st, pts, widths, Color.WHITE, Color.WHITE)

	for i in range(accent_stones):
		var t := (float(i) + 0.6) / float(accent_stones + 1)
		var p := curve.sample_baked(t * length)
		var tangent := curve.sample_baked(minf(length, t * length + 0.11)) - p
		var angle := atan2(tangent.z, tangent.x) + PI * 0.5
		var side := Vector3(-tangent.z, 0, tangent.x).normalized() * _rng.randf_range(-0.34, 0.34)
		p += side + Vector3(0, 0.048, 0)
		var rx := _rng.randf_range(0.11, 0.22)
		var rz := _rng.randf_range(0.09, 0.17)
		var top_col := Color(0.56, 0.50, 0.40).lerp(Color(0.68, 0.61, 0.48), _rng.randf())
		var side_col := Color(0.34, 0.32, 0.28)
		Geo.add_stone(stone_st, p, rx, rz, 0.025, 6, 400 + i,
				top_col, side_col, angle + _rng.randf_range(-0.3, 0.3))
	# 用于后续植物避让。
	for i in range(32):
		var p := curve.sample_baked(float(i) / 31.0 * length)
		_path_clear_points.append(Vector2(p.x, p.z))


func _widen(widths: Array[float], extra: float) -> Array[float]:
	var out: Array[float] = []
	for w in widths:
		out.append(w + extra)
	return out


func _build_pond() -> void:
	var count := 44
	var bottom_st := Geo.surface()
	var ring_pts: Array[Vector3] = []
	for i in range(count):
		ring_pts.append(_pond_point(i, count, 1.0, 0.02, 1.0))
	var center := Vector3(POND_CENTER.x, 0.025, POND_CENTER.z)
	for i in range(count):
		var j := (i + 1) % count
		Geo.add_tri(bottom_st, center, ring_pts[j], ring_pts[i],
				Color(0.10, 0.24, 0.23), Vector3.UP)
	pond_bottom = MeshInstance3D.new()
	pond_bottom.name = "PondBottom"
	pond_bottom.mesh = Geo.finish(bottom_st)
	pond_bottom.material_override = Geo.make_vcol_material(0.97)
	pond_bottom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island_root.add_child(pond_bottom)

	var water_st := Geo.surface()
	var water_center := Vector3(POND_CENTER.x, 0.065, POND_CENTER.z)
	var uv_center := Vector2(0.5, 0.5)
	var water_ring: Array[Vector3] = []
	var water_uvs: Array[Vector2] = []
	for i in range(count):
		water_ring.append(_pond_point(i, count, 1.0, 0.065, 1.0))
		var a := TAU * float(i) / float(count)
		water_uvs.append(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
	for i in range(count):
		var j := (i + 1) % count
		Geo.add_tri_uv(water_st, water_center, water_ring[j], water_ring[i],
				uv_center, water_uvs[j], water_uvs[i], Color.WHITE, Vector3.UP)
	water_mesh = MeshInstance3D.new()
	water_mesh.name = "PondWater"
	water_mesh.mesh = Geo.finish(water_st)
	water_mesh.material_override = water_material
	water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	island_root.add_child(water_mesh)
	_apply_water_state()

	_build_lilies()
	_build_koi()


func _pond_point(i: int, count: int, scale: float, y: float, r_noise := 1.0) -> Vector3:
	var a := TAU * float(i) / float(count)
	var wave := 1.0 + 0.055 * sin(4.0 * a + 0.6) + 0.032 * sin(7.0 * a + 2.2)
	var local := Vector2(cos(a) * POND_RX * wave * scale, sin(a) * POND_RZ * wave * scale)
	var rotated := local.rotated(POND_ROT)
	return Vector3(POND_CENTER.x + rotated.x, y, POND_CENTER.z + rotated.y)


func _build_lilies() -> void:
	var st := Geo.surface()
	var pads := [
		{"p": Vector2(-0.65, 0.22), "r": 0.40, "a": 0.35},
		{"p": Vector2(0.42, -0.42), "r": 0.31, "a": 1.8},
		{"p": Vector2(1.02, 0.34), "r": 0.26, "a": 2.6},
		{"p": Vector2(-0.10, 0.64), "r": 0.22, "a": 4.1},
		{"p": Vector2(1.35, -0.16), "r": 0.19, "a": 5.0},
	]
	for pad in pads:
		var local: Vector2 = (pad["p"] as Vector2).rotated(POND_ROT)
		var center := Vector3(POND_CENTER.x + local.x, 0.082, POND_CENTER.z + local.y)
		_build_lily_pad(st, center, float(pad["r"]), float(pad["a"]), pad["r"] > 0.29)
	lily_mesh = MeshInstance3D.new()
	lily_mesh.name = "LilyPads"
	lily_mesh.mesh = Geo.finish(st)
	var mat := Geo.make_vcol_material(0.78)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	lily_mesh.material_override = mat
	lily_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island_root.add_child(lily_mesh)


func _build_lily_pad(st: SurfaceTool, center: Vector3, radius: float, gap_angle: float, flower: bool) -> void:
	var points: Array[Vector3] = []
	var n := 11
	for i in range(n):
		var a := gap_angle + 0.32 + (TAU - 0.64) * float(i) / float(n - 1)
		var r := radius * _rng.randf_range(0.90, 1.10)
		points.append(center + Vector3(cos(a) * r, 0, sin(a) * r))
	var c_green := Color(0.24, 0.43, 0.27).lerp(Color(0.39, 0.55, 0.30), _rng.randf())
	for i in range(points.size() - 1):
		Geo.add_tri(st, center, points[i + 1], points[i],
				c_green.lightened(_rng.randf_range(-0.03, 0.05)), Vector3.UP)
	if flower:
		var top := center + Vector3(0, 0.045, 0)
		var petal_col := Color(0.96, 0.88, 0.72)
		for i in range(6):
			var a := TAU * float(i) / 6.0 + 0.2
			var dir := Vector3(cos(a), 0, sin(a)) * (radius * 0.28)
			Geo.add_tri(st, top, top + dir.rotated(Vector3.UP, 0.4), top + dir,
					petal_col, Vector3.UP)
		Geo.add_ico(st, top + Vector3(0, 0.015, 0), Vector3(0.022, 0.012, 0.022),
				Color(0.95, 0.72, 0.38), Basis.IDENTITY, 510, 0.05)


func _build_koi() -> void:
	var configs := [
		{"phase": 0.3, "speed": 0.30, "rx": 1.24, "rz": 0.72, "col": Color(0.95, 0.42, 0.22), "scale": 1.0},
		{"phase": 3.4, "speed": -0.22, "rx": 1.52, "rz": 0.58, "col": Color(0.97, 0.77, 0.38), "scale": 0.82},
	]
	for cfg in configs:
		var root := Node3D.new()
		root.name = "Koi"
		island_root.add_child(root)
		var body_st := Geo.surface()
		Geo.add_ico(body_st, Vector3(0, 0, 0.02), Vector3(0.135, 0.055, 0.31),
				Color(0.96, 0.88, 0.75), Basis.IDENTITY, 610 + int(cfg["phase"]), 0.08)
		Geo.add_ico(body_st, Vector3(0.05, 0.035, 0.10), Vector3(0.085, 0.035, 0.12),
				cfg["col"], Basis.IDENTITY, 612 + int(cfg["phase"]), 0.10)
		Geo.add_ico(body_st, Vector3(-0.04, 0.045, -0.04), Vector3(0.06, 0.03, 0.09),
				cfg["col"].lightened(0.12), Basis.IDENTITY, 614 + int(cfg["phase"]), 0.10)
		var body := MeshInstance3D.new()
		body.name = "KoiBody"
		body.mesh = Geo.finish(body_st)
		var body_mat := Geo.make_vcol_material(0.42)
		body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		body.material_override = body_mat
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(body)

		var tail := Node3D.new()
		tail.name = "Tail"
		tail.position = Vector3(0, 0.0, -0.28)
		root.add_child(tail)
		var tail_st := Geo.surface()
		Geo.add_tri(tail_st, Vector3(0, 0, 0), Vector3(-0.16, 0.01, -0.26),
				Vector3(0.16, 0.01, -0.26), Color(0.98, 0.72, 0.43), Vector3.UP)
		Geo.add_tri(tail_st, Vector3(0, 0.0, 0), Vector3(0.03, 0.02, -0.20),
				Vector3(-0.03, 0.02, -0.20), Color(0.99, 0.85, 0.62), Vector3.UP)
		var tail_mesh := MeshInstance3D.new()
		tail_mesh.mesh = Geo.finish(tail_st)
		var tail_mat := Geo.make_vcol_material(0.55)
		tail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		tail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tail_mesh.material_override = tail_mat
		tail_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tail.add_child(tail_mesh)
		var anchor := Node3D.new()
		anchor.name = "FishAnchor"
		root.add_child(anchor)
		root.scale = Vector3.ONE * float(cfg["scale"]) * 1.15
		koi_data.append({
			"root": root,
			"tail": tail,
			"phase": float(cfg["phase"]),
			"speed": float(cfg["speed"]),
			"rx": float(cfg["rx"]),
			"rz": float(cfg["rz"]),
		})
	_update_koi(0.0)


func _build_boulders() -> void:
	var boulder_st := Geo.surface()
	Geo.add_ico(boulder_st, Vector3(0, 0, 0), Vector3(1.0, 0.72, 0.94),
			Color(0.88, 0.88, 0.88), Basis.IDENTITY, 801, 0.20)
	Geo.add_ico(boulder_st, Vector3(0.33, 0.02, -0.22), Vector3(0.48, 0.46, 0.52),
			Color(0.78, 0.78, 0.78), Basis.IDENTITY, 802, 0.24)
	var boulder_mesh := Geo.finish(boulder_st)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = boulder_mesh

	var count := 72
	for i in range(count):
		var a := TAU * float(i) / float(count) + _rng.randf_range(-0.022, 0.022)
		var pos := _contour_point(i, count, 1.0, -0.06)
		pos.x += cos(a) * _rng.randf_range(-0.10, 0.38)
		pos.z += sin(a) * _rng.randf_range(-0.10, 0.38)
		var s := _rng.randf_range(0.30, 0.78)
		if _rng.randf() < 0.14:
			s = _rng.randf_range(0.92, 1.25)
		var sy := s * _rng.randf_range(0.55, 0.95)
		var t := Transform3D(Basis.from_euler(Vector3(
				_rng.randf_range(-0.3, 0.3), _rng.randf_range(0, TAU), _rng.randf_range(-0.3, 0.3))
				).scaled(Vector3(s, sy, s * _rng.randf_range(0.8, 1.2))),
				pos + Vector3(0, -0.04 + sy * 0.25, 0))
		var col := Color(0.34, 0.32, 0.44).lerp(Color(0.51, 0.47, 0.58), _rng.randf())
		if _rng.randf() < 0.24:
			col = Color(0.29, 0.38, 0.30)
		_boulder_transforms.append(t)
		_boulder_colors.append(col)

	# 池塘围石：奶油色小石头，参考视频的水塘边缘。
	var pebble_ring_count := 30
	for i in range(pebble_ring_count):
		var p := _pond_point(i, pebble_ring_count, 1.075, 0.035, 1.0)
		var s := _rng.randf_range(0.23, 0.45)
		_boulder_transforms.append(Transform3D(
				Basis.from_euler(Vector3(0, _rng.randf_range(0, TAU), 0)).scaled(
						Vector3(s * 1.5, s * 0.68, s)),
				p + Vector3(0, 0.02, 0)))
		_boulder_colors.append(Color(0.73, 0.66, 0.55).lerp(Color(0.88, 0.80, 0.65), _rng.randf()))

	# 踏石路边缘散落的小石与右上方的坐石。
	for i in range(24):
		var p := Vector3(_rng.randf_range(-5.2, 3.0), 0.02, _rng.randf_range(-2.0, 7.0))
		if not _inside_island(p.x, p.z, 0.88) or _inside_pond(p.x, p.z, 1.4):
			continue
		if _near_path(p.x, p.z, 0.35):
			continue
		var s := _rng.randf_range(0.10, 0.24)
		_boulder_transforms.append(Transform3D(
				Basis.from_euler(Vector3(0, _rng.randf_range(0, TAU), 0)).scaled(
						Vector3(s, s * 0.55, s * 1.2)),
				p))
		_boulder_colors.append(Color(0.50, 0.47, 0.44).lerp(Color(0.66, 0.59, 0.48), _rng.randf()))

	# 树根与亭子边的三块大石。
	var feature_pos := [
		Vector3(TREE_BASE.x + 1.2, 0.2, TREE_BASE.z + 0.9),
		Vector3(PAVILION_BASE.x - 1.8, 0.12, PAVILION_BASE.z + 1.5),
		Vector3(-6.2, 0.15, 3.7),
	]
	for i in range(feature_pos.size()):
		var s := _rng.randf_range(0.7, 1.05)
		_boulder_transforms.append(Transform3D(
				Basis.from_euler(Vector3(0, _rng.randf_range(0, TAU), 0.1)).scaled(
						Vector3(s * 1.4, s * 0.7, s)),
				feature_pos[i]))
		_boulder_colors.append(Color(0.43, 0.42, 0.52).lerp(Color(0.54, 0.56, 0.43), _rng.randf()))

	mm.instance_count = _boulder_transforms.size()
	for i in range(_boulder_transforms.size()):
		mm.set_instance_transform(i, _boulder_transforms[i])
		mm.set_instance_color(i, _boulder_colors[i])
	boulder_multimesh = MultiMeshInstance3D.new()
	boulder_multimesh.name = "Boulders"
	boulder_multimesh.multimesh = mm
	boulder_multimesh.material_override = Geo.make_vcol_material(0.94)
	boulder_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	boulder_multimesh.custom_aabb = AABB(Vector3(-15, -2, -12), Vector3(30, 8, 24))
	island_root.add_child(boulder_multimesh)


# ────────────────────────────────────────────────────────────────────────
# 草、花、灌丛、蘑菇
# ────────────────────────────────────────────────────────────────────────

func _build_grass() -> void:
	var clump := _make_grass_clump()
	var target := 2200
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = clump
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var attempts := 0
	while transforms.size() < target and attempts < target * 16:
		attempts += 1
		var x := _rng.randf_range(-ISLAND_RX * 1.02, ISLAND_RX * 1.02)
		var z := _rng.randf_range(-ISLAND_RZ * 1.02, ISLAND_RZ * 1.02)
		var edge := not _inside_island(x, z, 0.80)
		if not _can_place_ground(x, z, 0.93, 0.48):
			continue
		var s := _rng.randf_range(0.72, 1.22)
		if edge or _rng.randf() < 0.08:
			s *= 1.35
		var sy := s * _rng.randf_range(0.85, 1.28)
		var basis := Basis.from_euler(Vector3(
				_rng.randf_range(-0.08, 0.08), _rng.randf_range(0, TAU), _rng.randf_range(-0.08, 0.08))
				).scaled(Vector3(s, sy, s))
		transforms.append(Transform3D(basis, Vector3(x, 0.001, z)))
		var hue_shift := _rng.randf_range(-0.06, 0.06)
		var col := Color(0.29 + hue_shift, 0.54 + _rng.randf_range(-0.09, 0.12), 0.25 + hue_shift)
		if _rng.randf() < 0.18:
			col = Color(0.48, 0.54, 0.29)
		colors.append(col)
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	grass_placed = transforms.size()
	grass_multimesh = MultiMeshInstance3D.new()
	grass_multimesh.name = "GrassField"
	grass_multimesh.multimesh = mm
	grass_multimesh.material_override = grass_material
	grass_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass_multimesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	grass_multimesh.custom_aabb = AABB(Vector3(-13, -0.2, -10), Vector3(26, 2.4, 20))
	island_root.add_child(grass_multimesh)


func _make_grass_clump() -> ArrayMesh:
	var st := Geo.surface()
	var blades := 6
	for b in range(blades):
		var ang := TAU * float(b) / float(blades) + _rng.randf_range(-0.2, 0.2)
		var side := Vector3(cos(ang), 0, sin(ang))
		var base := side * _rng.randf_range(0.0, 0.045)
		var h := _rng.randf_range(0.28, 0.55)
		var lean := Vector3(cos(ang + 1.3), 0, sin(ang + 1.3)) * _rng.randf_range(0.04, 0.12)
		var w := _rng.randf_range(0.032, 0.052)
		var p0 := base - side * w
		var p1 := base + side * w
		var mid := base + Vector3(0, h * 0.55, 0) + lean * 0.55
		var mid_l := mid - side * w * 0.55
		var mid_r := mid + side * w * 0.55
		var tip := base + Vector3(0, h, 0) + lean
		var c0 := Color(0.40, 0.43, 0.34).lerp(Color(0.55, 0.55, 0.42), _rng.randf())
		var c1 := Color(0.79, 0.82, 0.62).lerp(Color(0.92, 0.82, 0.58), _rng.randf())
		Geo.add_tri_uv(st, p0, p1, mid_r, Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.55), c0)
		Geo.add_tri_uv(st, p0, mid_r, mid_l, Vector2(0, 0), Vector2(1, 0.55), Vector2(0, 0.55), c0.lerp(c1, 0.5))
		Geo.add_tri_uv(st, mid_l, mid_r, tip, Vector2(0, 0.55), Vector2(1, 0.55), Vector2(0.5, 1.0), c1)
	return Geo.finish(st)


func _build_flower_fields() -> void:
	var daisy_mesh := _make_daisy_mesh()
	var daisy_target := 300
	var dmm := MultiMesh.new()
	dmm.transform_format = MultiMesh.TRANSFORM_3D
	dmm.use_colors = true
	dmm.mesh = daisy_mesh
	var d_trans: Array[Transform3D] = []
	var d_cols: Array[Color] = []
	var clusters := 54
	for c in range(clusters):
		var center := _find_flower_center()
		if center == Vector2.INF:
			continue
		var count := _rng.randi_range(4, 9)
		for i in range(count):
			var x := center.x + _rng.randf_range(-1.15, 1.15)
			var z := center.y + _rng.randf_range(-1.15, 1.15)
			if not _can_place_ground(x, z, 0.92, 0.35):
				continue
			var s := _rng.randf_range(0.95, 1.55)
			d_trans.append(Transform3D(
					Basis.from_euler(Vector3(0, _rng.randf_range(0, TAU), 0)).scaled(
							Vector3(s, s * _rng.randf_range(0.9, 1.25), s)),
					Vector3(x, 0.012, z)))
			var ccol := Color(1.0, 0.98, 0.88)
			var roll := _rng.randf()
			if roll < 0.15:
				ccol = Color(1.0, 0.91, 0.56)
			elif roll < 0.26:
				ccol = Color(0.88, 0.86, 1.0)
			d_cols.append(ccol)
			if d_trans.size() >= daisy_target:
				break
		if d_trans.size() >= daisy_target:
			break
	dmm.instance_count = d_trans.size()
	for i in range(d_trans.size()):
		dmm.set_instance_transform(i, d_trans[i])
		dmm.set_instance_color(i, d_cols[i])
	daisy_placed = d_trans.size()
	daisy_multimesh = MultiMeshInstance3D.new()
	daisy_multimesh.name = "MoonDaisies"
	daisy_multimesh.multimesh = dmm
	daisy_multimesh.material_override = flower_material
	daisy_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	daisy_multimesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	daisy_multimesh.custom_aabb = AABB(Vector3(-13, -0.2, -10), Vector3(26, 2.0, 20))
	island_root.add_child(daisy_multimesh)

	var lavender_mesh := _make_lavender_mesh()
	var lavender_target := 230
	var lmm := MultiMesh.new()
	lmm.transform_format = MultiMesh.TRANSFORM_3D
	lmm.use_colors = true
	lmm.mesh = lavender_mesh
	var l_trans: Array[Transform3D] = []
	var l_cols: Array[Color] = []
	for c in range(46):
		var center := _find_flower_center()
		if center == Vector2.INF:
			continue
		var count := _rng.randi_range(3, 7)
		for i in range(count):
			var x := center.x + _rng.randf_range(-1.2, 1.2)
			var z := center.y + _rng.randf_range(-1.2, 1.2)
			if not _can_place_ground(x, z, 0.91, 0.36):
				continue
			var s := _rng.randf_range(0.95, 1.55)
			l_trans.append(Transform3D(
					Basis.from_euler(Vector3(0, _rng.randf_range(0, TAU), 0)).scaled(
							Vector3(s, s * _rng.randf_range(0.9, 1.3), s)),
					Vector3(x, 0.012, z)))
			var col := Color(0.78, 0.70, 1.0).lerp(Color(0.92, 0.84, 1.0), _rng.randf())
			l_cols.append(col)
			if l_trans.size() >= lavender_target:
				break
		if l_trans.size() >= lavender_target:
			break
	lmm.instance_count = l_trans.size()
	for i in range(l_trans.size()):
		lmm.set_instance_transform(i, l_trans[i])
		lmm.set_instance_color(i, l_cols[i])
	lavender_placed = l_trans.size()
	lavender_multimesh = MultiMeshInstance3D.new()
	lavender_multimesh.name = "LavenderSpikes"
	lavender_multimesh.multimesh = lmm
	lavender_multimesh.material_override = flower_material
	lavender_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lavender_multimesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	lavender_multimesh.custom_aabb = AABB(Vector3(-13, -0.2, -10), Vector3(26, 2.4, 20))
	island_root.add_child(lavender_multimesh)

	_build_fallen_petals()


func _find_flower_center() -> Vector2:
	for attempt in range(30):
		var x := _rng.randf_range(-ISLAND_RX * 0.86, ISLAND_RX * 0.86)
		var z := _rng.randf_range(-ISLAND_RZ * 0.86, ISLAND_RZ * 0.86)
		if _can_place_ground(x, z, 0.91, 0.32):
			return Vector2(x, z)
	return Vector2.INF


func _make_daisy_mesh() -> ArrayMesh:
	var st := Geo.surface()
	var stem := Color(0.25, 0.38, 0.22)
	var light := Color(0.98, 0.95, 0.85)
	Geo.add_tri(st, Vector3(-0.012, 0, 0), Vector3(0.012, 0, 0),
			Vector3(0.015, 0.24, 0), stem, Vector3(0.7, 0.2, 0.7))
	Geo.add_tri(st, Vector3(-0.012, 0, 0), Vector3(0.015, 0.24, 0),
			Vector3(-0.015, 0.24, 0), stem, Vector3(-0.7, 0.2, -0.7))
	Geo.add_tri(st, Vector3(0, 0.12, 0), Vector3(-0.10, 0.17, 0.03),
			Vector3(-0.02, 0.22, 0.04), stem.lightened(0.10), Vector3.UP)
	var top := Vector3(0, 0.255, 0)
	for i in range(6):
		var a := TAU * float(i) / 6.0 + 0.2
		var side_a := a - 0.22
		var side_b := a + 0.22
		var p1 := top + Vector3(cos(side_a) * 0.06, 0, sin(side_a) * 0.06)
		var p2 := top + Vector3(cos(side_b) * 0.06, 0, sin(side_b) * 0.06)
		Geo.add_tri(st, top, p1, p2, light, Vector3.UP)
		Geo.add_tri(st, top + Vector3(0, 0.002, 0), p2, p1, light.darkened(0.03), Vector3.DOWN)
	Geo.add_ico(st, top + Vector3(0, 0.008, 0), Vector3(0.028, 0.012, 0.028),
			Color(0.94, 0.72, 0.32), Basis.IDENTITY, 901, 0.10)
	return Geo.finish(st)


func _make_lavender_mesh() -> ArrayMesh:
	var st := Geo.surface()
	var stem := Color(0.23, 0.35, 0.22)
	var purple := Color(0.56, 0.44, 0.80)
	Geo.add_tri(st, Vector3(-0.012, 0, 0), Vector3(0.012, 0, 0),
			Vector3(0.01, 0.35, 0), stem, Vector3(0.8, 0, 0.6))
	Geo.add_tri(st, Vector3(-0.012, 0, 0), Vector3(0.01, 0.35, 0),
			Vector3(-0.01, 0.35, 0), stem, Vector3(-0.8, 0, -0.6))
	for i in range(6):
		var y := 0.22 + 0.035 * float(i)
		var r := 0.033 - 0.003 * float(i)
		var ang := float(i) * 1.6
		var p := Vector3(cos(ang) * 0.022, y, sin(ang) * 0.022)
		Geo.add_ico(st, p, Vector3(r, r * 0.8, r), purple.lightened(float(i) * 0.035),
				Basis.IDENTITY, 920 + i, 0.15)
	return Geo.finish(st)


func _build_understory() -> void:
	_build_bushes()
	_build_ferns()
	_build_mushrooms()


func _build_bushes() -> void:
	var mesh := _make_bush_mesh(1401)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var trans: Array[Transform3D] = []
	var cols: Array[Color] = []
	var attempts := 0
	while trans.size() < 38 and attempts < 900:
		attempts += 1
		var x := _rng.randf_range(-ISLAND_RX * 0.88, ISLAND_RX * 0.88)
		var z := _rng.randf_range(-ISLAND_RZ * 0.88, ISLAND_RZ * 0.88)
		if not _can_place_ground(x, z, 0.93, 0.95):
			continue
		var s := _rng.randf_range(0.55, 1.12)
		trans.append(Transform3D(
				Basis.from_euler(Vector3(0, _rng.randf_range(0, TAU), 0)).scaled(
						Vector3(s, s * _rng.randf_range(0.8, 1.20), s)),
				Vector3(x, 0.0, z)))
		cols.append(Color(0.78, 0.90, 0.70).lerp(Color(0.95, 1.0, 0.78), _rng.randf()))
	mm.instance_count = trans.size()
	for i in range(trans.size()):
		mm.set_instance_transform(i, trans[i])
		mm.set_instance_color(i, cols[i])
	bush_multimesh = MultiMeshInstance3D.new()
	bush_multimesh.name = "MossBushes"
	bush_multimesh.multimesh = mm
	bush_multimesh.material_override = understory_material
	bush_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	bush_multimesh.custom_aabb = AABB(Vector3(-13, -0.2, -10), Vector3(26, 3.2, 20))
	island_root.add_child(bush_multimesh)


func _make_bush_mesh(seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := Geo.surface()
	for i in range(4):
		var off := Vector3(rng.randf_range(-0.30, 0.30), rng.randf_range(0.22, 0.45),
				rng.randf_range(-0.30, 0.30))
		var radii := Vector3(rng.randf_range(0.36, 0.58), rng.randf_range(0.22, 0.38),
				rng.randf_range(0.34, 0.56))
		Geo.add_ico(st, off, radii,
				Color(0.18, 0.31, 0.18).lerp(Color(0.31, 0.43, 0.22), rng.randf()),
				Basis.from_euler(Vector3(0, rng.randf_range(0, TAU), 0)), seed + i, 0.22)
	for i in range(30):
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 1), rng.randf_range(-1, 1))
		dir = dir.normalized()
		var p := Vector3(0, 0.30, 0) + dir * Vector3(
				rng.randf_range(0.30, 0.72), rng.randf_range(0.10, 0.48), rng.randf_range(0.26, 0.70))
		var col := Color(0.22, 0.38, 0.20).lerp(Color(0.44, 0.55, 0.26), rng.randf())
		Geo.add_leaf_card(st, p, rng.randf_range(0.13, 0.26),
				rng.randf_range(0.14, 0.25), col, rng, 0.02)
	return Geo.finish(st)


func _build_ferns() -> void:
	var mesh := _make_fern_mesh(1601)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var trans: Array[Transform3D] = []
	var cols: Array[Color] = []
	var attempts := 0
	while trans.size() < 72 and attempts < 1400:
		attempts += 1
		var x := _rng.randf_range(-ISLAND_RX * 0.9, ISLAND_RX * 0.9)
		var z := _rng.randf_range(-ISLAND_RZ * 0.9, ISLAND_RZ * 0.9)
		if not _can_place_ground(x, z, 0.91, 0.60):
			continue
		var near_pond := _inside_pond(x, z, 1.36)
		var near_tree := _dist2(x, z, TREE_BASE.x, TREE_BASE.z) < 4.2
		if not (near_pond or near_tree or _rng.randf() < 0.25):
			continue
		var s := _rng.randf_range(0.55, 1.12)
		trans.append(Transform3D(
				Basis.from_euler(Vector3(0, _rng.randf_range(0, TAU), 0)).scaled(
						Vector3(s, s * _rng.randf_range(0.8, 1.25), s)),
				Vector3(x, 0.0, z)))
		cols.append(Color(0.78, 0.92, 0.70).lerp(Color(0.94, 1.0, 0.80), _rng.randf()))
	mm.instance_count = trans.size()
	for i in range(trans.size()):
		mm.set_instance_transform(i, trans[i])
		mm.set_instance_color(i, cols[i])
	fern_multimesh = MultiMeshInstance3D.new()
	fern_multimesh.name = "Ferns"
	fern_multimesh.multimesh = mm
	fern_multimesh.material_override = understory_material
	fern_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fern_multimesh.custom_aabb = AABB(Vector3(-13, -0.2, -10), Vector3(26, 2.4, 20))
	island_root.add_child(fern_multimesh)


func _make_fern_mesh(seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := Geo.surface()
	for i in range(11):
		var ang := TAU * float(i) / 11.0 + rng.randf_range(-0.2, 0.2)
		var base := Vector3(cos(ang) * 0.06, 0.02, sin(ang) * 0.06)
		var reach := rng.randf_range(0.30, 0.52)
		var lift := rng.randf_range(0.20, 0.42)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var bend := Vector3.UP * lift + dir * reach
		var side := Vector3(-dir.z, 0, dir.x) * rng.randf_range(0.055, 0.09)
		var col := Color(0.23, 0.37, 0.20).lerp(Color(0.44, 0.55, 0.25), rng.randf())
		Geo.add_tri(st, base - side, base + side, base + bend * 0.45 + Vector3.UP * 0.02, col, Vector3.UP)
		# 每枝 5 片细长羽叶。
		for j in range(5):
			var t := 0.25 + float(j) * 0.16
			var p := base + bend * t + Vector3.UP * sin(t * PI) * 0.13
			var left := side.normalized() * (0.08 - 0.011 * float(j))
			Geo.add_tri(st, p, p + left + dir * 0.07, p + dir * 0.11, col.lightened(0.04 * float(j)), Vector3.UP)
			Geo.add_tri(st, p, p + dir * 0.11, p - left + dir * 0.06, col.lightened(0.025 * float(j)), Vector3.UP)
	return Geo.finish(st)


func _build_mushrooms() -> void:
	var mesh := _make_mushroom_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var trans: Array[Transform3D] = []
	var cols: Array[Color] = []
	var attempts := 0
	while trans.size() < 34 and attempts < 1000:
		attempts += 1
		var x: float
		var z: float
		if _rng.randf() < 0.68:
			var ang := _rng.randf_range(0, TAU)
			var r := _rng.randf_range(1.0, 4.2)
			x = TREE_BASE.x + cos(ang) * r
			z = TREE_BASE.z + sin(ang) * r
		else:
			x = _rng.randf_range(-ISLAND_RX * 0.84, ISLAND_RX * 0.84)
			z = _rng.randf_range(-ISLAND_RZ * 0.84, ISLAND_RZ * 0.84)
		if not _can_place_ground(x, z, 0.90, 0.36):
			continue
		var s := _rng.randf_range(0.6, 1.25)
		trans.append(Transform3D(
				Basis.from_euler(Vector3(0, _rng.randf_range(0, TAU), 0)).scaled(
						Vector3(s, s, s)),
				Vector3(x, 0.015, z)))
		var roll := _rng.randf()
		cols.append(Color(0.98, 0.78, 0.50) if roll < 0.55 else Color(0.56, 0.82, 0.72))
	mm.instance_count = trans.size()
	for i in range(trans.size()):
		mm.set_instance_transform(i, trans[i])
		mm.set_instance_color(i, cols[i])
	mushroom_multimesh = MultiMeshInstance3D.new()
	mushroom_multimesh.name = "GlowMushrooms"
	mushroom_multimesh.multimesh = mm
	mushroom_multimesh.material_override = mushroom_material
	mushroom_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mushroom_multimesh.custom_aabb = AABB(Vector3(-13, -0.2, -10), Vector3(26, 1.4, 20))
	island_root.add_child(mushroom_multimesh)


func _make_mushroom_mesh() -> ArrayMesh:
	var st := Geo.surface()
	Geo.add_cylinder(st, Vector3(0, 0, 0), Vector3(0, 0.095, 0),
			0.016, 0.011, 5, Color(0.88, 0.82, 0.66))
	Geo.add_ico(st, Vector3(0, 0.115, 0), Vector3(0.083, 0.040, 0.078),
			Color(0.98, 0.86, 0.67), Basis.IDENTITY, 1701, 0.10)
	Geo.add_ico(st, Vector3(-0.028, 0.128, 0.016), Vector3(0.017, 0.009, 0.014),
			Color(1.0, 0.94, 0.79), Basis.IDENTITY, 1702, 0.05)
	return Geo.finish(st)


func _build_fallen_petals() -> void:
	var st := Geo.surface()
	for i in range(58):
		var x: float
		var z: float
		if i < 34:
			var a := _rng.randf_range(0, TAU)
			var r := _rng.randf_range(0.5, 3.2)
			x = TREE_BASE.x + cos(a) * r
			z = TREE_BASE.z + sin(a) * r
		else:
			x = _rng.randf_range(-5.0, 3.4)
			z = _rng.randf_range(-2.0, 7.2)
		if not _inside_island(x, z, 0.88) or _inside_pond(x, z, 1.02):
			continue
		var size := _rng.randf_range(0.035, 0.075)
		var ang := _rng.randf_range(0, TAU)
		var dir := Vector3(cos(ang), 0, sin(ang)) * size
		var side := Vector3(-dir.z, 0, dir.x) * 0.40
		var c := Color(0.94, 0.82, 0.65).lerp(Color(0.92, 0.68, 0.65), _rng.randf())
		var p := Vector3(x, 0.022 + _rng.randf_range(0, 0.01), z)
		Geo.add_tri(st, p - dir - side, p + dir - side, p + dir * 0.3 + side * 0.7, c, Vector3.UP)
	fallen_petals = MeshInstance3D.new()
	fallen_petals.name = "FallenPetals"
	fallen_petals.mesh = Geo.finish(st)
	fallen_petals.material_override = petals_ground_material
	fallen_petals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island_root.add_child(fallen_petals)


# ────────────────────────────────────────────────────────────────────────
# 月树与配景树
# ────────────────────────────────────────────────────────────────────────

func _build_main_tree() -> void:
	tree_root = Node3D.new()
	tree_root.name = "MoonTree"
	tree_root.position = TREE_BASE
	island_root.add_child(tree_root)

	var bark := Geo.make_vcol_material(0.98)
	var wood := Geo.surface()
	var trunk_pts := [
		Vector3(0.0, 0.0, 0.0), Vector3(0.15, 0.9, 0.08),
		Vector3(-0.08, 1.9, 0.02), Vector3(-0.30, 2.9, -0.15),
		Vector3(-0.20, 3.7, -0.25), Vector3(0.05, 4.40, -0.35),
	]
	var trunk_radii := [0.58, 0.50, 0.43, 0.34, 0.245, 0.12]
	_add_limb(wood, trunk_pts, trunk_radii,
			Color(0.27, 0.21, 0.16), Color(0.41, 0.32, 0.22))

	var branches := [
		{
			"pts": [Vector3(-0.18, 3.00, -0.18), Vector3(-1.2, 3.8, 0.35),
					Vector3(-2.1, 4.45, 0.75), Vector3(-2.6, 4.8, 1.1)],
			"radii": [0.22, 0.16, 0.10, 0.04],
		},
		{
			"pts": [Vector3(0.0, 3.65, -0.30), Vector3(1.0, 4.3, -0.1),
					Vector3(2.0, 4.75, -0.35), Vector3(2.5, 4.95, -0.7)],
			"radii": [0.20, 0.15, 0.09, 0.035],
		},
		{
			"pts": [Vector3(-0.20, 3.35, -0.20), Vector3(-0.5, 4.0, 1.0),
					Vector3(-0.7, 4.45, 1.8)],
			"radii": [0.18, 0.12, 0.04],
		},
		{
			"pts": [Vector3(-0.10, 3.80, -0.30), Vector3(0.2, 4.2, -1.3),
					Vector3(0.3, 4.6, -2.0)],
			"radii": [0.17, 0.11, 0.035],
		},
		{
			"pts": [Vector3(-0.30, 2.70, -0.10), Vector3(-1.5, 3.2, 0.15),
					Vector3(-2.4, 3.5, 0.1)],
			"radii": [0.14, 0.09, 0.03],
		},
	]
	for branch in branches:
		_add_limb(wood, branch["pts"], branch["radii"],
				Color(0.27, 0.21, 0.16), Color(0.38, 0.30, 0.21))

	# 露出地面的根与三缕苔痕。
	var roots := [
		[Vector3(0.0, 0.55, 0.0), Vector3(0.82, 0.16, 0.30), Vector3(1.32, -0.06, 0.52)],
		[Vector3(-0.05, 0.50, 0.0), Vector3(-0.75, 0.14, 0.48), Vector3(-1.18, -0.05, 0.78)],
		[Vector3(0.05, 0.45, -0.05), Vector3(0.38, 0.12, -0.80), Vector3(0.52, -0.04, -1.34)],
		[Vector3(-0.15, 0.42, 0.0), Vector3(-0.48, 0.11, -0.74), Vector3(-0.75, -0.04, -1.12)],
	]
	for root in roots:
		_add_limb(wood, root, [0.18, 0.11, 0.04],
				Color(0.24, 0.19, 0.14), Color(0.32, 0.25, 0.18))
	Geo.add_ico(wood, Vector3(0.18, 0.16, 0.16), Vector3(0.44, 0.09, 0.34),
			Color(0.26, 0.38, 0.22), Basis.IDENTITY, 1801, 0.20)
	Geo.add_ico(wood, Vector3(-0.30, 0.14, -0.20), Vector3(0.36, 0.075, 0.30),
			Color(0.27, 0.40, 0.23), Basis.IDENTITY, 1802, 0.20)

	# 从枝端垂下的细藤和小叶。
	for i in range(7):
		var start := Vector3(
				_rng.randf_range(-2.4, 1.8), _rng.randf_range(3.4, 4.6),
				_rng.randf_range(-1.6, 1.4))
		var length := _rng.randf_range(0.35, 1.15)
		Geo.add_cylinder(wood, start, start + Vector3(_rng.randf_range(-0.1, 0.1), -length, 0),
				0.012, 0.005, 4, Color(0.22, 0.31, 0.18))
		Geo.add_leaf_card(wood, start + Vector3(0.02, -length * 0.8, 0),
				0.13, 0.16, Color(0.28, 0.44, 0.24), _rng, 0.03)

	var trunk_mesh := MeshInstance3D.new()
	trunk_mesh.name = "MoonTreeTrunk"
	trunk_mesh.mesh = Geo.finish(wood)
	trunk_mesh.material_override = bark
	trunk_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	tree_root.add_child(trunk_mesh)

	var clusters := [
		{"pos": Vector3(-2.38, 4.95, 0.78), "size": 1.55, "seed": 2001},
		{"pos": Vector3(2.10, 5.05, -0.42), "size": 1.50, "seed": 2002},
		{"pos": Vector3(-0.68, 5.0, 1.62), "size": 1.42, "seed": 2003},
		{"pos": Vector3(0.22, 5.25, -1.70), "size": 1.54, "seed": 2004},
		{"pos": Vector3(-0.08, 5.62, -0.05), "size": 1.72, "seed": 2005},
		{"pos": Vector3(-1.62, 3.82, 1.0), "size": 0.86, "seed": 2006},
		{"pos": Vector3(1.18, 3.98, 0.24), "size": 0.78, "seed": 2007},
		{"pos": Vector3(-0.12, 4.22, 1.4), "size": 0.84, "seed": 2008},
	]
	for c in clusters:
		var pivot := Node3D.new()
		pivot.name = "CanopyPivot"
		pivot.position = c["pos"]
		tree_root.add_child(pivot)
		var mesh := MeshInstance3D.new()
		mesh.name = "Canopy"
		mesh.mesh = _make_canopy_mesh(int(c["seed"]), float(c["size"]),
				Color(0.23, 0.40, 0.22), Color(0.60, 0.71, 0.34))
		mesh.material_override = canopy_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if int(c["seed"]) >= 2006:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mesh)
		canopy_pivots.append({
			"pivot": pivot,
			"mesh": mesh,
			"phase": _rng.randf_range(0, TAU),
			"amp": _rng.randf_range(0.008, 0.017),
			"speed": _rng.randf_range(0.33, 0.61),
			"base": pivot.rotation,
		})

	_build_moon_pods()


func _add_limb(st: SurfaceTool, points: Array, radii: Array, dark: Color, light: Color) -> void:
	for i in range(points.size() - 1):
		var t := float(i) / maxf(1.0, float(points.size() - 2))
		var c := dark.lerp(light, t * 0.75)
		Geo.add_cylinder(st, points[i], points[i + 1],
				float(radii[i]), float(radii[i + 1]), 6, c, false)
	if points.size() > 1:
		Geo.add_ico(st, points[points.size() - 1],
				Vector3(float(radii[radii.size() - 1]), float(radii[radii.size() - 1]),
						float(radii[radii.size() - 1])),
				light, Basis.IDENTITY, 1850, 0.12)


func _make_canopy_mesh(seed: int, size: float, dark_green: Color, light_green: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := Geo.surface()
	# 低模体积底衬。
	for i in range(5):
		var off := Vector3(rng.randf_range(-0.50, 0.50), rng.randf_range(-0.22, 0.40),
				rng.randf_range(-0.50, 0.50)) * size
		var radii := Vector3(
				rng.randf_range(0.40, 0.66) * size,
				rng.randf_range(0.30, 0.48) * size,
				rng.randf_range(0.42, 0.64) * size)
		var c := dark_green.lerp(light_green, rng.randf_range(0.05, 0.55))
		Geo.add_ico(st, off, radii, c,
				Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2),
						rng.randf_range(0, TAU), rng.randf_range(-0.2, 0.2))),
				seed * 13 + i, 0.22)
	# 卡片式叶簇：产生透光与细碎轮廓。
	var cards := 115
	for i in range(cards):
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.52, 0.92),
				rng.randf_range(-1, 1))
		dir = dir.normalized()
		var rad := size * rng.randf_range(0.30, 0.96)
		var p := dir * rad + Vector3(rng.randf_range(-0.18, 0.18), rng.randf_range(-0.12, 0.16),
				rng.randf_range(-0.18, 0.18)) * size
		var roll := rng.randf()
		var c := dark_green.lerp(light_green, clampf(0.30 + rad / maxf(size, 0.01) * 0.55
				+ rng.randf_range(-0.16, 0.16), 0.0, 1.0))
		if roll < 0.018:
			c = Color(0.93, 0.82, 0.58)
		elif roll < 0.11:
			c = Color(0.64, 0.74, 0.39)
		Geo.add_leaf_card(st, p, rng.randf_range(0.15, 0.28) * size,
				rng.randf_range(0.13, 0.24) * size, c, rng, 0.015)
	# 少量奶油色花簇在冠缘。
	for i in range(6):
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1),
				rng.randf_range(-1, 1)).normalized()
		var p := dir * size * rng.randf_range(0.70, 1.02)
		Geo.add_ico(st, p, Vector3(0.038, 0.026, 0.034) * size,
				Color(0.98, 0.86, 0.62).lerp(Color(0.97, 0.72, 0.62), rng.randf()),
				Basis.IDENTITY, seed * 31 + i, 0.18)
	return Geo.finish(st)


func _build_moon_pods() -> void:
	pods_root = Node3D.new()
	pods_root.name = "MoonPods"
	tree_root.add_child(pods_root)
	var stems := Geo.surface()
	var pods := Geo.surface()
	var pod_positions := [
		Vector3(-1.95, 3.92, 0.95), Vector3(-0.60, 3.62, 1.36),
		Vector3(1.55, 3.72, 0.12), Vector3(0.88, 3.48, -1.12),
		Vector3(-1.05, 3.82, -0.84), Vector3(0.28, 4.20, 0.42),
	]
	for i in range(pod_positions.size()):
		var p: Vector3 = pod_positions[i]
		var top := p + Vector3(_rng.randf_range(-0.14, 0.14), _rng.randf_range(0.7, 1.25), 0)
		Geo.add_cylinder(stems, top, p, 0.009, 0.006, 4, Color(0.22, 0.20, 0.14))
		Geo.add_ico(pods, p, Vector3(0.073, 0.115, 0.073),
				Color(1.0, 0.82, 0.50).lerp(Color(1.0, 0.70, 0.36), _rng.randf()),
				Basis.IDENTITY, 2100 + i, 0.10)
		Geo.add_ico(pods, p + Vector3(0, 0.11, 0), Vector3(0.02, 0.035, 0.02),
				Color(0.35, 0.45, 0.25), Basis.IDENTITY, 2110 + i, 0.05)
	var stem_mesh := MeshInstance3D.new()
	stem_mesh.name = "PodStems"
	stem_mesh.mesh = Geo.finish(stems)
	stem_mesh.material_override = stone_material
	stem_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pods_root.add_child(stem_mesh)

	pod_material = StandardMaterial3D.new()
	pod_material.vertex_color_use_as_albedo = true
	pod_material.vertex_color_is_srgb = true
	pod_material.roughness = 0.5
	pod_material.emission_enabled = true
	pod_material.emission = Color(1.0, 0.44, 0.12)
	pod_material.emission_energy_multiplier = 0.9
	var pod_mesh := MeshInstance3D.new()
	pod_mesh.name = "GlowPods"
	pod_mesh.mesh = Geo.finish(pods)
	pod_mesh.material_override = pod_material
	pod_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pods_root.add_child(pod_mesh)

	tree_warm_light = OmniLight3D.new()
	tree_warm_light.name = "PodsWarmLight"
	tree_warm_light.position = Vector3(0.0, 3.6, 0.0)
	tree_warm_light.light_color = Color(1.0, 0.48, 0.17)
	tree_warm_light.omni_range = 5.8
	tree_warm_light.omni_attenuation = 1.15
	tree_warm_light.light_energy = 0.9
	tree_warm_light.shadow_enabled = false
	tree_root.add_child(tree_warm_light)


func _build_small_trees() -> void:
	# 左前景的小树，让视野边缘不死板。
	var sapling := Node3D.new()
	sapling.name = "LittleMoonTree"
	sapling.position = Vector3(-7.35, 0, 0.55)
	island_root.add_child(sapling)
	var st := Geo.surface()
	_add_limb(st,
		[Vector3(0, 0, 0), Vector3(0.12, 0.9, 0.05), Vector3(0.02, 1.8, -0.04),
				Vector3(-0.18, 2.55, 0.02)],
		[0.20, 0.15, 0.10, 0.035],
		Color(0.28, 0.22, 0.16), Color(0.40, 0.31, 0.21))
	_add_limb(st, [Vector3(0.02, 1.8, -0.04), Vector3(-0.75, 2.35, 0.18), Vector3(-1.0, 2.7, 0.3)],
		[0.10, 0.055, 0.02], Color(0.28, 0.22, 0.16), Color(0.36, 0.29, 0.20))
	Geo.add_ico(st, Vector3(-0.05, 0.08, 0.05), Vector3(0.28, 0.055, 0.22),
			Color(0.26, 0.38, 0.22), Basis.IDENTITY, 2301, 0.18)
	var trunk := MeshInstance3D.new()
	trunk.mesh = Geo.finish(st)
	trunk.material_override = stone_material
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sapling.add_child(trunk)

	for info in [
		{"pos": Vector3(-0.20, 2.90, 0.04), "size": 0.88, "seed": 2401},
		{"pos": Vector3(-0.92, 2.52, 0.25), "size": 0.64, "seed": 2402},
	]:
		var pivot := Node3D.new()
		pivot.name = "SaplingCanopy"
		pivot.position = info["pos"]
		sapling.add_child(pivot)
		var mesh := MeshInstance3D.new()
		mesh.mesh = _make_canopy_mesh(int(info["seed"]), float(info["size"]),
				Color(0.29, 0.43, 0.22), Color(0.66, 0.72, 0.36))
		mesh.material_override = canopy_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mesh)
		canopy_pivots.append({
			"pivot": pivot,
			"mesh": mesh,
			"phase": _rng.randf_range(0, TAU),
			"amp": _rng.randf_range(0.012, 0.022),
			"speed": _rng.randf_range(0.42, 0.68),
			"base": pivot.rotation,
		})

	# 两棵远景树：替代廉价的锥形松，给浮岛左右收边。
	_build_guardian_tree(Vector3(-8.85, 0, -5.15), 0.78, 5501,
			Color(0.22, 0.38, 0.22), Color(0.55, 0.66, 0.31))
	_build_guardian_tree(Vector3(8.65, 0, -5.35), 0.86, 5502,
			Color(0.20, 0.35, 0.22), Color(0.50, 0.62, 0.29))


func _build_guardian_tree(pos: Vector3, tree_scale: float, seed: int,
		dark: Color, light: Color) -> void:
	var tree := Node3D.new()
	tree.name = "GuardianTree"
	tree.position = pos
	tree.scale = Vector3.ONE * tree_scale
	tree.rotation.y = float(seed % 17) * 0.23
	island_root.add_child(tree)
	var st := Geo.surface()
	var trunk := [
		Vector3(0, 0, 0), Vector3(0.18, 0.9, 0.06), Vector3(-0.06, 1.9, 0.02),
		Vector3(0.10, 2.8, -0.08),
	]
	_add_limb(st, trunk, [0.28, 0.22, 0.14, 0.04],
			Color(0.27, 0.21, 0.15), Color(0.38, 0.29, 0.19))
	_add_limb(st, [Vector3(0.05, 1.9, 0.0), Vector3(-0.8, 2.6, 0.35),
			Vector3(-1.25, 3.0, 0.5)],
			[0.11, 0.06, 0.025], Color(0.27, 0.21, 0.15), Color(0.36, 0.28, 0.18))
	_add_limb(st, [Vector3(0.05, 2.2, 0.0), Vector3(0.7, 2.8, -0.3),
			Vector3(1.1, 3.15, -0.5)],
			[0.10, 0.055, 0.02], Color(0.27, 0.21, 0.15), Color(0.36, 0.28, 0.18))
	Geo.add_ico(st, Vector3(0, 0.08, 0), Vector3(0.32, 0.055, 0.27),
			Color(0.25, 0.37, 0.21), Basis.IDENTITY, seed, 0.18)
	var trunk_mesh := MeshInstance3D.new()
	trunk_mesh.mesh = Geo.finish(st)
	trunk_mesh.material_override = stone_material
	trunk_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.add_child(trunk_mesh)

	var clusters := [
		{"pos": Vector3(-0.85, 3.15, 0.35), "size": 1.06, "seed": seed + 11},
		{"pos": Vector3(0.65, 3.35, -0.30), "size": 0.98, "seed": seed + 12},
		{"pos": Vector3(-0.05, 3.90, 0.18), "size": 1.18, "seed": seed + 13},
	]
	for info in clusters:
		var pivot := Node3D.new()
		pivot.name = "BackgroundCanopy"
		pivot.position = info["pos"]
		tree.add_child(pivot)
		var mesh := MeshInstance3D.new()
		mesh.mesh = _make_canopy_mesh(int(info["seed"]), float(info["size"]), dark, light)
		mesh.material_override = canopy_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mesh)
		canopy_pivots.append({
			"pivot": pivot,
			"mesh": mesh,
			"phase": _rng.randf_range(0, TAU),
			"amp": _rng.randf_range(0.010, 0.019),
			"speed": _rng.randf_range(0.36, 0.62),
			"base": pivot.rotation,
		})

# ────────────────────────────────────────────────────────────────────────
# 茶亭 / 风铃 / 茶具 / 纸灯
# ────────────────────────────────────────────────────────────────────────

func _build_pavilion() -> void:
	pavilion_root = Node3D.new()
	pavilion_root.name = "TeaPavilion"
	pavilion_root.position = PAVILION_BASE
	pavilion_root.rotation.y = PAVILION_ROT
	pavilion_root.scale = Vector3.ONE * 0.92
	island_root.add_child(pavilion_root)

	var platform_st := Geo.surface()
	Geo.add_stone(platform_st, Vector3(0, 0.02, 0), 1.95, 1.50, 0.16, 10, 3001,
			Color(0.48, 0.47, 0.45), Color(0.31, 0.30, 0.34), 0.18)
	Geo.add_stone(platform_st, Vector3(-1.72, 0.03, 1.42), 0.52, 0.38, 0.10, 7, 3002,
			Color(0.58, 0.55, 0.47), Color(0.34, 0.33, 0.33), 0.6)
	Geo.add_stone(platform_st, Vector3(1.62, 0.03, 1.36), 0.38, 0.32, 0.095, 7, 3003,
			Color(0.49, 0.47, 0.44), Color(0.30, 0.30, 0.32), 1.2)
	Geo.add_ico(platform_st, Vector3(-1.42, 0.12, -0.9), Vector3(0.40, 0.035, 0.30),
			Color(0.30, 0.42, 0.27), Basis.IDENTITY, 3004, 0.18)
	Geo.add_ico(platform_st, Vector3(1.38, 0.11, -1.02), Vector3(0.33, 0.03, 0.25),
			Color(0.29, 0.40, 0.26), Basis.IDENTITY, 3005, 0.18)
	var platform := MeshInstance3D.new()
	platform.name = "PavilionPlatform"
	platform.mesh = Geo.finish(platform_st)
	platform.material_override = stone_material
	platform.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pavilion_root.add_child(platform)

	var wood_st := Geo.surface()
	var post_dark := Color(0.250, 0.185, 0.135)
	var post_light := Color(0.390, 0.300, 0.205)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bottom := Vector3(1.23 * sx, 0.12, 0.92 * sz)
			var top := Vector3(1.33 * sx, 2.23, 0.80 * sz)
			Geo.add_cylinder(wood_st, bottom, top, 0.078, 0.062, 6, post_dark.lerp(post_light, 0.35))
			Geo.add_ico(wood_st, bottom + Vector3(0, 0.02, 0), Vector3(0.10, 0.04, 0.10),
					Color(0.29, 0.38, 0.26), Basis.IDENTITY, 3010 + int(sx * 3.0 + sz), 0.12)
	# 横向梁与斜撑。
	Geo.add_cylinder(wood_st, Vector3(-1.36, 2.20, 0.82), Vector3(1.36, 2.20, 0.82),
			0.055, 0.055, 6, post_dark.lerp(post_light, 0.5))
	Geo.add_cylinder(wood_st, Vector3(-1.36, 2.20, -0.82), Vector3(1.36, 2.20, -0.82),
			0.055, 0.055, 6, post_dark.lerp(post_light, 0.5))
	Geo.add_cylinder(wood_st, Vector3(-1.28, 2.20, -0.85), Vector3(-1.28, 2.20, 0.85),
			0.050, 0.050, 6, post_dark.lerp(post_light, 0.45))
	Geo.add_cylinder(wood_st, Vector3(1.28, 2.20, -0.85), Vector3(1.28, 2.20, 0.85),
			0.050, 0.050, 6, post_dark.lerp(post_light, 0.45))
	for sx in [-1.0, 1.0]:
		Geo.add_cylinder(wood_st, Vector3(sx * 1.25, 1.45, 0.85), Vector3(sx * 1.25, 2.18, 0.87),
				0.035, 0.035, 5, post_light)
	# 茶桌与两把小凳。
	Geo.add_cylinder(wood_st, Vector3(0, 0.58, -0.05), Vector3(0, 0.66, -0.05),
			0.50, 0.50, 10, Color(0.45, 0.33, 0.22), true)
	Geo.add_cylinder(wood_st, Vector3(0, 0.16, -0.05), Vector3(0, 0.60, -0.05),
			0.075, 0.075, 6, post_dark)
	for sx in [-1.0, 1.0]:
		Geo.add_cylinder(wood_st, Vector3(0.63 * sx, 0.18, 0.23), Vector3(0.63 * sx, 0.30, 0.23),
				0.22, 0.24, 8, Color(0.41, 0.31, 0.22), true)
		Geo.add_cylinder(wood_st, Vector3(0.63 * sx, 0.08, 0.23), Vector3(0.63 * sx, 0.18, 0.23),
				0.05, 0.05, 5, post_dark)
	# 风铃横臂。
	Geo.add_cylinder(wood_st, Vector3(1.25, 2.24, 1.02), Vector3(0.98, 2.34, 1.42),
			0.035, 0.028, 5, post_light)
	Geo.add_ico(wood_st, Vector3(0.98, 2.34, 1.42), Vector3(0.06, 0.045, 0.06),
			Color(0.48, 0.35, 0.22), Basis.IDENTITY, 3020, 0.10)
	# 屋顶椽木（在瓦面以下可见）。
	for i in range(4):
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var end := Vector3(cos(ang) * 1.62, 2.30, sin(ang) * 1.18)
		Geo.add_cylinder(wood_st, Vector3(0, 2.60, 0), end, 0.035, 0.022, 5, post_dark)
	var frame := MeshInstance3D.new()
	frame.name = "PavilionFrame"
	frame.mesh = Geo.finish(wood_st)
	frame.material_override = stone_material
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pavilion_root.add_child(frame)

	var roof_st := _make_roof_surface()
	var roof := MeshInstance3D.new()
	roof.name = "CurvedTeaRoof"
	roof.mesh = Geo.finish(roof_st)
	var roof_mat := Geo.make_vcol_material(0.74)
	roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	roof_mat.metallic = 0.08
	roof.material_override = roof_mat
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pavilion_root.add_child(roof)

	_build_tea_set()
	_build_pavilion_lamp_and_chime()


func _make_roof_surface() -> SurfaceTool:
	var st := Geo.surface()
	var apex := Vector3(0, 3.36, 0)
	var corners := [
		Vector3(-2.12, 2.52, 1.58), Vector3(2.12, 2.52, 1.58),
		Vector3(2.12, 2.52, -1.58), Vector3(-2.12, 2.52, -1.58),
	]
	var mids := [
		Vector3(0, 2.31, 1.79), Vector3(2.29, 2.31, 0),
		Vector3(0, 2.31, -1.79), Vector3(-2.29, 2.31, 0),
	]
	var panel_cols := [
		Color(0.11, 0.25, 0.23), Color(0.10, 0.22, 0.21),
		Color(0.09, 0.20, 0.19), Color(0.11, 0.23, 0.21),
	]
	for q in range(4):
		var a: Vector3 = corners[q]
		var m: Vector3 = mids[q]
		var b: Vector3 = corners[(q + 1) % 4]
		Geo.add_tri(st, apex, a, m, panel_cols[q].lightened(0.035))
		Geo.add_tri(st, apex, m, b, panel_cols[q])
		# 檐口厚度 + 暖木封檐。
		var drop := Vector3(0, -0.11, 0)
		Geo.add_quad(st, a + drop, m + drop, m, a, Color(0.10, 0.16, 0.14))
		Geo.add_quad(st, m + drop, b + drop, b, m, Color(0.10, 0.16, 0.14))
		Geo.add_quad(st, a + drop, m + drop, m + Vector3(0, -0.035, 0), a + Vector3(0, -0.035, 0),
				Color(0.40, 0.30, 0.19))
		Geo.add_quad(st, m + drop, b + drop, b + Vector3(0, -0.035, 0), m + Vector3(0, -0.035, 0),
				Color(0.40, 0.30, 0.19))
		# 每条瓦面补 3 根浅色细脊，暗示瓦垄。
		for r in range(1, 4):
			var u := float(r) / 4.0
			var edge_p1 := a.lerp(m, u)
			var edge_p2 := m.lerp(b, u)
			var p1 := apex.lerp(edge_p1, u)
			var p2 := apex.lerp(edge_p2, u)
			Geo.add_cylinder(st, apex + Vector3(0, 0.022, 0), p1 + Vector3(0, 0.01, 0),
					0.012, 0.018, 4, Color(0.15, 0.29, 0.25))
			Geo.add_cylinder(st, apex + Vector3(0, 0.022, 0), p2 + Vector3(0, 0.01, 0),
					0.012, 0.018, 4, Color(0.15, 0.29, 0.25))
	# 顶脊 / 四角脊线。
	for i in range(4):
		Geo.add_cylinder(st, apex + Vector3(0, 0.02, 0), corners[i] + Vector3(0, 0.015, 0),
				0.030, 0.042, 5, Color(0.08, 0.17, 0.15))
		Geo.add_cylinder(st, apex, mids[i], 0.020, 0.026, 5, Color(0.14, 0.27, 0.22))
	# 顶饰：一小枚暖色果实。
	Geo.add_ico(st, apex + Vector3(0, 0.18, 0), Vector3(0.085, 0.13, 0.085),
			Color(0.92, 0.67, 0.36), Basis.IDENTITY, 3030, 0.10)
	Geo.add_cylinder(st, apex + Vector3(0, 0.05, 0), apex + Vector3(0, 0.15, 0),
			0.028, 0.022, 5, Color(0.20, 0.30, 0.22))
	return st


func _build_tea_set() -> void:
	var st := Geo.surface()
	var ceramic := Color(0.76, 0.84, 0.76)
	var ceramic_light := Color(0.91, 0.91, 0.82)
	var clay := Color(0.58, 0.44, 0.33)
	# 茶壶：圆身 + 短流 + 小钮。
	Geo.add_ico(st, Vector3(0.06, 0.79, -0.02), Vector3(0.13, 0.085, 0.12),
			ceramic, Basis.IDENTITY, 3101, 0.09)
	Geo.add_ico(st, Vector3(0.06, 0.865, -0.02), Vector3(0.075, 0.025, 0.07),
			ceramic_light, Basis.IDENTITY, 3102, 0.06)
	Geo.add_cylinder(st, Vector3(0.15, 0.79, -0.02), Vector3(0.27, 0.86, -0.06),
			0.035, 0.012, 5, clay)
	Geo.add_cylinder(st, Vector3(-0.06, 0.79, -0.02), Vector3(-0.14, 0.81, 0.08),
			0.015, 0.012, 5, clay)
	Geo.add_ico(st, Vector3(0.06, 0.905, -0.02), Vector3(0.022, 0.018, 0.022),
			ceramic_light, Basis.IDENTITY, 3103, 0.05)
	# 两只茶杯。
	for pos in [Vector3(-0.25, 0.70, 0.14), Vector3(-0.06, 0.70, 0.24)]:
		Geo.add_cylinder(st, pos, pos + Vector3(0, 0.06, 0), 0.058, 0.052, 7,
				ceramic_light, true)
		Geo.add_cylinder(st, pos + Vector3(0, 0.045, 0), pos + Vector3(0, 0.047, 0),
				0.040, 0.040, 7, Color(0.44, 0.60, 0.43), true)
	var mesh := MeshInstance3D.new()
	mesh.name = "TeaSet"
	mesh.mesh = Geo.finish(st)
	mesh.material_override = Geo.make_vcol_material(0.52)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pavilion_root.add_child(mesh)

	# 茶汤热气：极轻的上升雾，给静止画面一点呼吸。
	var steam_mat := StandardMaterial3D.new()
	steam_mat.albedo_texture = _soft_tex
	steam_mat.albedo_color = Color(0.86, 0.88, 0.82, 0.16)
	steam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steam_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	steam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	steam_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	steam_mat.no_depth_test = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.24, 0.24)
	steam = CPUParticles3D.new()
	steam.name = "TeaSteam"
	steam.amount = 9
	steam.lifetime = 2.8
	steam.randomness = 0.55
	steam.mesh = quad
	steam.material_override = steam_mat
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.035
	steam.direction = Vector3.UP
	steam.spread = 22.0
	steam.initial_velocity_min = 0.025
	steam.initial_velocity_max = 0.075
	steam.gravity = Vector3(0, 0.035, 0)
	steam.scale_amount_min = 0.25
	steam.scale_amount_max = 0.70
	steam.color = Color(0.93, 0.92, 0.84, 0.25)
	steam.position = Vector3(0.06, 0.96, -0.02)
	steam.local_coords = false
	pavilion_root.add_child(steam)


func _build_pavilion_lamp_and_chime() -> void:
	pavilion_lamp = Node3D.new()
	pavilion_lamp.name = "PaperLampPivot"
	pavilion_lamp.position = Vector3(0.10, 2.29, 0.03)
	pavilion_root.add_child(pavilion_lamp)

	var cord_st := Geo.surface()
	Geo.add_cylinder(cord_st, Vector3(0, 0.12, 0), Vector3(0, -0.20, 0),
			0.007, 0.007, 4, Color(0.26, 0.22, 0.17))
	Geo.add_ico(cord_st, Vector3(0, -0.19, 0), Vector3(0.09, 0.045, 0.09),
			Color(0.18, 0.23, 0.18), Basis.IDENTITY, 3201, 0.06)
	var cord := MeshInstance3D.new()
	cord.mesh = Geo.finish(cord_st)
	cord.material_override = stone_material
	cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pavilion_lamp.add_child(cord)

	var paper_mesh := SphereMesh.new()
	paper_mesh.radius = 0.17
	paper_mesh.height = 0.34
	paper_mesh.radial_segments = 12
	paper_mesh.rings = 6
	pavilion_lamp_material = StandardMaterial3D.new()
	pavilion_lamp_material.albedo_color = Color(1.0, 0.54, 0.23)
	pavilion_lamp_material.emission_enabled = true
	pavilion_lamp_material.emission = Color(1.0, 0.44, 0.12)
	pavilion_lamp_material.emission_energy_multiplier = 1.2
	pavilion_lamp_material.roughness = 0.6
	var paper := MeshInstance3D.new()
	paper.name = "PaperLantern"
	paper.mesh = paper_mesh
	paper.material_override = pavilion_lamp_material
	paper.position = Vector3(0, -0.38, 0)
	paper.scale = Vector3(1.05, 1.0, 1.05)
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pavilion_lamp.add_child(paper)

	pavilion_lamp_halo_material = StandardMaterial3D.new()
	pavilion_lamp_halo_material.albedo_texture = _soft_tex
	pavilion_lamp_halo_material.albedo_color = Color(1.0, 0.37, 0.10, 0.22)
	pavilion_lamp_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pavilion_lamp_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pavilion_lamp_halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pavilion_lamp_halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pavilion_lamp_halo_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	pavilion_lamp_halo_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var halo_quad := QuadMesh.new()
	halo_quad.size = Vector2(1.70, 1.70)
	var halo := MeshInstance3D.new()
	halo.mesh = halo_quad
	halo.material_override = pavilion_lamp_halo_material
	halo.position = Vector3(0, -0.38, 0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pavilion_lamp.add_child(halo)

	pavilion_lamp_light = OmniLight3D.new()
	pavilion_lamp_light.name = "PaperLampLight"
	pavilion_lamp_light.position = Vector3(0, -0.40, 0)
	pavilion_lamp_light.light_color = Color(1.0, 0.48, 0.18)
	pavilion_lamp_light.omni_range = 6.0
	pavilion_lamp_light.omni_attenuation = 0.86
	pavilion_lamp_light.light_energy = 3.4
	pavilion_lamp_light.shadow_enabled = false
	pavilion_lamp.add_child(pavilion_lamp_light)

	# 亭内暖色地面光池：不必依赖高成本体积光。
	var floor_pool_mat := StandardMaterial3D.new()
	floor_pool_mat.albedo_texture = _soft_tex
	floor_pool_mat.albedo_color = Color(1.0, 0.30, 0.04, 0.24)
	floor_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	floor_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	floor_pool_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	floor_pool_mat.disable_receive_shadows = true
	floor_pool_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var floor_pool_quad := QuadMesh.new()
	floor_pool_quad.size = Vector2(4.0, 3.2)
	var floor_pool := MeshInstance3D.new()
	floor_pool.name = "PavilionWarmPool"
	floor_pool.mesh = floor_pool_quad
	floor_pool.material_override = floor_pool_mat
	floor_pool.position = Vector3(0, 0.19, -0.1)
	floor_pool.rotation_degrees = Vector3(-90, 0, 0)
	floor_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pavilion_root.add_child(floor_pool)

	var chime = WindChimeScript.new()
	chime.name = "GlassWindChime"
	chime.position = Vector3(1.02, 2.31, 1.47)
	chime.scale = Vector3.ONE * 1.22
	chime.display_name = "风铃"
	chime.display_id = "wind_chime"
	pavilion_root.add_child(chime)
	wind_chime = chime
	_register_interactable(chime)


# ────────────────────────────────────────────────────────────────────────
# 可交互小物
# ────────────────────────────────────────────────────────────────────────

func _build_lanterns() -> void:
	var names := ["苔灯", "水灯"]
	var ids := ["lantern_path", "lantern_water"]
	for i in range(LANTERN_POSITIONS.size()):
		var lamp = MoonLanternScript.new()
		lamp.name = "MoonLantern%d" % i
		lamp.position = LANTERN_POSITIONS[i]
		lamp.display_name = names[i]
		lamp.display_id = ids[i]
		island_root.add_child(lamp)
		lanterns.append(lamp)
		_register_interactable(lamp)


func _build_cat() -> void:
	cat = MossCatScript.new()
	cat.name = "MossCat"
	cat.position = CAT_POS
	cat.scale = Vector3.ONE * 1.30
	cat.rotation.y = -0.16
	island_root.add_child(cat)
	_register_interactable(cat)


func _register_interactable(node) -> void:
	if node == null or interactables.has(node):
		return
	interactables.append(node)
	node.interacted.connect(_on_target_interacted)


func _on_target_interacted(id: String, message: String, anchor: Vector3) -> void:
	interaction_feedback.emit(id, message, anchor)


# ────────────────────────────────────────────────────────────────────────
# 粒子、萤火、雾、浮岩与地表柔光
# ────────────────────────────────────────────────────────────────────────

func _make_billboard_material(color: Color, additive: bool, use_vertex_color: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _soft_tex
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.vertex_color_use_as_albedo = use_vertex_color
	mat.vertex_color_is_srgb = true
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_receive_shadows = true
	return mat


func _build_particles() -> void:
	_build_fireflies()
	_build_pollen()
	_build_falling_petals()
	_build_rain()


func _build_fireflies() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.19, 0.19)
	var mat := _make_billboard_material(Color(1.0, 0.80, 0.42, 0.90), true, true)
	fireflies = GPUParticles3D.new()
	fireflies.name = "Fireflies"
	fireflies.amount = 104
	fireflies.lifetime = 9.0
	fireflies.preprocess = 8.0
	fireflies.randomness = 0.65
	fireflies.local_coords = true
	fireflies.position = Vector3(0.0, 1.25, 0.0)
	fireflies.draw_pass_1 = quad
	fireflies.material_override = mat
	fireflies.visibility_aabb = AABB(Vector3(-14, -2, -11), Vector3(28, 10, 22))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10.6, 1.7, 7.8)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.015
	pm.initial_velocity_max = 0.10
	pm.gravity = Vector3(0, 0.006, 0)
	pm.scale_min = 0.65
	pm.scale_max = 1.85
	pm.angular_velocity_min = -35.0
	pm.angular_velocity_max = 35.0
	pm.hue_variation_min = -0.10
	pm.hue_variation_max = 0.12
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.22
	pm.turbulence_noise_scale = 2.4
	pm.turbulence_noise_speed = Vector3(0.13, 0.13, 0.13)
	pm.turbulence_influence_min = 0.15
	pm.turbulence_influence_max = 0.55
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.88, 0.53, 0.15),
		Color(1.0, 0.75, 0.33, 0.90),
		Color(0.58, 0.92, 0.58, 0.05),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	pm.lifetime_randomness = 0.45
	fireflies.process_material = pm
	fireflies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island_root.add_child(fireflies)


func _build_pollen() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.060, 0.060)
	var mat := _make_billboard_material(Color(1.0, 0.90, 0.66, 0.62), true, false)
	pollen = GPUParticles3D.new()
	pollen.name = "Pollen"
	pollen.amount = 86
	pollen.lifetime = 11.0
	pollen.preprocess = 9.0
	pollen.randomness = 0.6
	pollen.local_coords = true
	pollen.position = Vector3(0, 1.9, 0)
	pollen.draw_pass_1 = quad
	pollen.material_override = mat
	pollen.visibility_aabb = AABB(Vector3(-14, -1, -11), Vector3(28, 10, 22))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9.4, 2.4, 6.8)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.008
	pm.initial_velocity_max = 0.055
	pm.gravity = Vector3(0, 0.003, 0)
	pm.scale_min = 0.45
	pm.scale_max = 1.10
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.15
	pm.turbulence_noise_scale = 2.8
	pm.turbulence_noise_speed = Vector3(0.09, 0.09, 0.09)
	pm.lifetime_randomness = 0.50
	pollen.process_material = pm
	pollen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island_root.add_child(pollen)


func _build_falling_petals() -> void:
	var petal_mesh := _make_petal_mesh()
	var mat := Geo.make_vcol_material(0.92)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_is_srgb = true
	falling_petals = CPUParticles3D.new()
	falling_petals.name = "FallingPetals"
	falling_petals.amount = 34
	falling_petals.lifetime = 9.0
	falling_petals.preprocess = 5.0
	falling_petals.randomness = 0.62
	falling_petals.local_coords = true
	falling_petals.position = TREE_BASE + Vector3(0, 4.8, 0)
	falling_petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	falling_petals.emission_box_extents = Vector3(2.7, 0.8, 2.5)
	falling_petals.direction = Vector3(0, -1, 0)
	falling_petals.spread = 48.0
	falling_petals.initial_velocity_min = 0.10
	falling_petals.initial_velocity_max = 0.40
	falling_petals.gravity = Vector3(0, -0.16, 0)
	falling_petals.angular_velocity_min = -105.0
	falling_petals.angular_velocity_max = 105.0
	falling_petals.scale_amount_min = 0.75
	falling_petals.scale_amount_max = 1.35
	falling_petals.color = Color(1.0, 0.89, 0.80, 0.92)
	falling_petals.mesh = petal_mesh
	falling_petals.material_override = mat
	falling_petals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island_root.add_child(falling_petals)


func _make_petal_mesh() -> ArrayMesh:
	var st := Geo.surface()
	var center := Vector3(0, 0, 0)
	var left := Vector3(-0.055, 0.005, 0.025)
	var tip := Vector3(0.012, 0.022, -0.12)
	var right := Vector3(0.060, 0.002, 0.026)
	var c := Color(0.98, 0.84, 0.70)
	Geo.add_tri(st, center, left, tip, c, Vector3.UP)
	Geo.add_tri(st, center, tip, right, c.lightened(0.04), Vector3.UP)
	Geo.add_tri(st, center, tip, left, c.darkened(0.03), Vector3.DOWN)
	Geo.add_tri(st, center, right, tip, c.darkened(0.02), Vector3.DOWN)
	return Geo.finish(st)


func _build_rain() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.014, 0.62, 0.014)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.64, 0.75, 0.84, 0.46)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	rain = CPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 460
	rain.lifetime = 1.9
	rain.randomness = 0.4
	rain.local_coords = true
	rain.position = Vector3(0.0, 10.8, 0.0)
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(11.3, 0.35, 8.7)
	rain.direction = Vector3(0, -1, 0)
	rain.spread = 3.0
	rain.initial_velocity_min = 8.5
	rain.initial_velocity_max = 12.5
	rain.gravity = Vector3(0, -4.5, 0)
	rain.scale_amount_min = 0.75
	rain.scale_amount_max = 1.15
	rain.color = Color(0.74, 0.83, 0.92, 0.60)
	rain.mesh = box
	rain.material_override = mat
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.emitting = false
	rain.visible = false
	island_root.add_child(rain)


func _build_bokeh() -> void:
	var defs := [
		{"p": Vector3(-9.8, 4.6, 1.8), "s": 1.35, "c": Color(1.0, 0.74, 0.34, 0.34), "phase": 0.3},
		{"p": Vector3(9.1, 3.6, 2.5), "s": 1.05, "c": Color(0.70, 0.92, 0.62, 0.28), "phase": 1.7},
		{"p": Vector3(-7.4, 2.4, -6.1), "s": 1.55, "c": Color(1.0, 0.68, 0.32, 0.30), "phase": 2.9},
		{"p": Vector3(7.7, 2.1, -5.7), "s": 1.15, "c": Color(0.74, 0.62, 0.98, 0.26), "phase": 4.1},
		{"p": Vector3(-2.0, 6.8, -5.5), "s": 0.94, "c": Color(1.0, 0.86, 0.52, 0.28), "phase": 5.2},
		{"p": Vector3(3.5, 4.0, 7.7), "s": 1.12, "c": Color(0.66, 0.88, 0.72, 0.22), "phase": 0.9},
		{"p": Vector3(-12.5, 8.6, -5.8), "s": 1.75, "c": Color(1.0, 0.72, 0.40, 0.24), "phase": 3.1},
		{"p": Vector3(11.8, 7.4, -7.2), "s": 1.40, "c": Color(0.78, 0.72, 1.0, 0.20), "phase": 5.7},
		{"p": Vector3(-3.0, 10.2, -12.0), "s": 2.10, "c": Color(1.0, 0.82, 0.48, 0.18), "phase": 1.4},
		{"p": Vector3(2.0, 7.8, 9.8), "s": 1.30, "c": Color(0.64, 0.88, 0.68, 0.16), "phase": 2.8},
		{"p": Vector3(13.2, 4.2, 3.5), "s": 0.95, "c": Color(1.0, 0.80, 0.45, 0.26), "phase": 4.4},
	]
	for i in range(defs.size()):
		var def: Dictionary = defs[i]
		var mat := _make_billboard_material(def["c"], true, false)
		var quad := QuadMesh.new()
		quad.size = Vector2(float(def["s"]), float(def["s"]))
		var mi := MeshInstance3D.new()
		mi.name = "Bokeh%d" % i
		mi.mesh = quad
		mi.material_override = mat
		mi.position = def["p"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		island_root.add_child(mi)
		bokeh.append({
			"node": mi,
			"material": mat,
			"base": def["p"],
			"alpha": (def["c"] as Color).a,
			"phase": float(def["phase"]),
		})


func _build_mist() -> void:
	mist_material = StandardMaterial3D.new()
	mist_material.albedo_texture = _cloud_tex
	mist_material.albedo_color = Color(0.55, 0.62, 0.72, 0.08)
	mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mist_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mist_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mist_material.disable_receive_shadows = true
	mist_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var defs := [
		{"p": Vector3(-6.8, 0.42, 5.8), "s": Vector2(5.2, 2.0)},
		{"p": Vector3(5.8, 0.50, 6.1), "s": Vector2(4.4, 1.8)},
		{"p": Vector3(7.2, 0.45, -3.7), "s": Vector2(4.2, 1.7)},
	]
	for i in range(defs.size()):
		var quad := QuadMesh.new()
		quad.size = defs[i]["s"]
		var mi := MeshInstance3D.new()
		mi.name = "GroundMist%d" % i
		mi.mesh = quad
		mi.material_override = mist_material
		mi.position = defs[i]["p"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		island_root.add_child(mi)
		mist_cards.append(mi)
		_mist_base.append(defs[i]["p"])
		_mist_phase.append(float(i) * 1.21 + 0.4)


func _build_floating_shards() -> void:
	var st := Geo.surface()
	Geo.add_ico(st, Vector3.ZERO, Vector3(0.24, 0.18, 0.20),
			Color(0.42, 0.39, 0.52), Basis.IDENTITY, 4101, 0.22)
	Geo.add_ico(st, Vector3(0.12, 0.04, -0.04), Vector3(0.10, 0.08, 0.11),
			Color(0.30, 0.43, 0.30), Basis.IDENTITY, 4102, 0.18)
	var mesh := Geo.finish(st)
	var mat := Geo.make_vcol_material(0.93)
	var defs := [
		{"p": Vector3(-12.8, 2.1, 2.0), "s": 1.0, "phase": 0.3},
		{"p": Vector3(12.2, 3.3, -1.4), "s": 0.8, "phase": 2.1},
		{"p": Vector3(1.5, -3.1, 10.2), "s": 0.48, "phase": 1.2},
	]
	for i in range(defs.size()):
		var mi := MeshInstance3D.new()
		mi.name = "FloatingShard%d" % i
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = defs[i]["p"]
		mi.scale = Vector3.ONE * float(defs[i]["s"])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		island_root.add_child(mi)
		floating_shards.append({
			"node": mi,
			"base": defs[i]["p"],
			"phase": float(defs[i]["phase"]),
		})


func _build_ground_shadows() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _soft_tex
	mat.albedo_color = Color(0.02, 0.045, 0.035, 0.24)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.disable_receive_shadows = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	for def in [
		{"p": TREE_BASE + Vector3(0.0, 0.024, 0.2), "s": Vector2(9.0, 6.4)},
		{"p": PAVILION_BASE + Vector3(0.0, 0.024, 0.2), "s": Vector2(4.9, 3.8)},
	]:
		var quad := QuadMesh.new()
		quad.size = def["s"]
		var mi := MeshInstance3D.new()
		mi.name = "SoftContactShadow"
		mi.mesh = quad
		mi.material_override = mat
		mi.position = def["p"]
		mi.rotation_degrees = Vector3(-90, 0, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		island_root.add_child(mi)


# ────────────────────────────────────────────────────────────────────────
# 动画与状态
# ────────────────────────────────────────────────────────────────────────

func tick(delta: float, night: float, rain_value: float, high: bool) -> void:
	anim_time += delta
	nightness = clampf(night, 0.0, 1.0)
	rain_amount = clampf(rain_value, 0.0, 1.0)
	quality_high = high

	wind_gust = 0.08 + rain_amount * 0.95
	_update_foliage()
	_apply_water_state()
	_update_island_float()
	_update_canopies()
	_update_tree_warmth()
	_update_pavilion()
	_update_koi(delta)
	_update_fireflies()
	_update_bokeh()
	_update_mist()
	_update_floating_shards()
	for node in interactables:
		node.tick(delta, anim_time, nightness, rain_amount, quality_high)


func _update_foliage() -> void:
	for mat in [grass_material, canopy_material, understory_material, flower_material,
			mushroom_material]:
		if mat != null:
			mat.set_shader_parameter("u_time", anim_time)
			mat.set_shader_parameter("wind_gust", wind_gust)
	flower_material.set_shader_parameter("glow_strength", 0.012 + nightness * 0.13)
	mushroom_material.set_shader_parameter("glow_strength", 0.10 + nightness * 1.05)


func _apply_water_state() -> void:
	if water_material == null:
		return
	water_material.set_shader_parameter("u_time", anim_time)
	water_material.set_shader_parameter("rain_amount", rain_amount)
	water_material.set_shader_parameter("moon_dir", Vector3(-0.34, 0.68, -0.66))
	water_material.set_shader_parameter("wave_scale", 0.66 + rain_amount * 0.35)
	var dayness := 1.0 - nightness
	var deep := Color(0.028, 0.120, 0.125).lerp(Color(0.10, 0.25, 0.24), dayness)
	var shallow := Color(0.08, 0.36, 0.32).lerp(Color(0.30, 0.58, 0.46), dayness)
	var sky := Color(0.10, 0.28, 0.36).lerp(Color(0.55, 0.75, 0.78), dayness)
	deep = deep.lerp(Color(0.08, 0.13, 0.16), rain_amount * 0.40)
	shallow = shallow.lerp(Color(0.22, 0.32, 0.34), rain_amount * 0.40)
	sky = sky.lerp(Color(0.46, 0.51, 0.57), rain_amount * 0.55)
	water_material.set_shader_parameter("deep_color", deep)
	water_material.set_shader_parameter("shallow_color", shallow)
	water_material.set_shader_parameter("sky_color", sky)
	water_material.set_shader_parameter("glint_color",
			Color(1.0, 0.82, 0.50).lerp(Color(1.0, 0.95, 0.78), dayness))
	water_material.set_shader_parameter("glint_strength", lerpf(0.95, 0.48, dayness) * (1.0 - rain_amount * 0.35))
	water_material.set_shader_parameter("warm_strength", 0.14 + nightness * 0.82)
	var warm_pos := POND_CENTER + Vector3(2.2, 1.0, -0.8)
	if lanterns.size() > 1:
		warm_pos = lanterns[1].global_position + Vector3(0, 1.0, 0)
	water_material.set_shader_parameter("warm_light_pos", warm_pos)
	water_material.set_shader_parameter("warm_color", Color(1.0, 0.36, 0.07))


func _update_island_float() -> void:
	if island_root == null:
		return
	island_root.position.y = sin(anim_time * 0.37) * 0.055
	island_root.rotation.z = sin(anim_time * 0.23) * 0.0016
	island_root.rotation.x = cos(anim_time * 0.19) * 0.0012


func _update_canopies() -> void:
	for item in canopy_pivots:
		var pivot: Node3D = item["pivot"]
		var phase: float = item["phase"]
		var amp: float = item["amp"]
		var speed: float = item["speed"]
		var base: Vector3 = item["base"]
		var wind_mul := 1.0 + rain_amount * 1.7
		pivot.rotation = base + Vector3(
			cos(anim_time * speed + phase) * amp * 0.65 * wind_mul,
			0.0,
			sin(anim_time * speed + phase) * amp * wind_mul)
		pivot.scale = Vector3(
			1.0 + sin(anim_time * speed * 0.84 + phase) * 0.004,
			1.0 + sin(anim_time * speed * 0.64 + phase + 1.1) * 0.006,
			1.0)


func _update_tree_warmth() -> void:
	if pod_material != null:
		pod_material.emission_energy_multiplier = (0.30 + nightness * 1.5) * (1.0 - rain_amount * 0.12)
	if tree_warm_light != null:
		tree_warm_light.light_energy = (0.30 + nightness * 0.95) * (1.0 + sin(anim_time * 1.2) * 0.05)
	if pods_root != null:
		pods_root.rotation = Vector3(
			cos(anim_time * 0.43) * 0.012,
			0.0,
			sin(anim_time * 0.36) * 0.016)


func _update_pavilion() -> void:
	if pavilion_lamp != null:
		pavilion_lamp.rotation.z = sin(anim_time * 0.58 + 0.8) * 0.022 \
				+ sin(anim_time * 1.37 + 2.0) * 0.006
		pavilion_lamp.rotation.x = cos(anim_time * 0.44 + 1.3) * 0.013
	if pavilion_lamp_material != null:
		pavilion_lamp_material.emission_energy_multiplier = \
				(0.40 + nightness * 1.55) * (1.0 + sin(anim_time * 2.1) * 0.025)
	if pavilion_lamp_light != null:
		pavilion_lamp_light.light_energy = (0.55 + nightness * 2.9) * (1.0 - rain_amount * 0.12)
	if pavilion_lamp_halo_material != null:
		var a := 0.06 + nightness * 0.18
		pavilion_lamp_halo_material.albedo_color = Color(1.0, 0.40, 0.12, a)
	if steam != null:
		steam.emitting = true


func _update_koi(delta: float) -> void:
	for fish in koi_data:
		var root: Node3D = fish["root"]
		var theta: float = float(fish["phase"]) + anim_time * float(fish["speed"])
		var rx: float = fish["rx"]
		var rz: float = fish["rz"]
		var local := Vector2(cos(theta) * rx, sin(theta) * rz).rotated(POND_ROT)
		var y := 0.010 + sin(anim_time * 1.7 + float(fish["phase"])) * 0.007
		root.position = Vector3(POND_CENTER.x + local.x, y, POND_CENTER.z + local.y)
		var sign_speed := signf(float(fish["speed"]))
		var tangent_local := Vector2(-sin(theta) * rx, cos(theta) * rz) * sign_speed
		var tangent := tangent_local.rotated(POND_ROT)
		root.rotation.y = atan2(tangent.x, tangent.y)
		var tail: Node3D = fish["tail"]
		tail.rotation.y = sin(anim_time * (4.6 + absf(float(fish["speed"])) * 2.0) \
				+ float(fish["phase"])) * 0.44


func _update_fireflies() -> void:
	if fireflies != null:
		var ratio := nightness * (1.0 - rain_amount * 0.72)
		if not quality_high:
			ratio *= 0.62
		fireflies.emitting = ratio > 0.02
		fireflies.amount_ratio = clampf(maxf(ratio, 0.02), 0.0, 1.0)
	if pollen != null:
		var ratio := (0.30 + 0.70 * (1.0 - nightness)) * (1.0 - rain_amount * 0.70)
		if not quality_high:
			ratio *= 0.68
		pollen.emitting = ratio > 0.02
		pollen.amount_ratio = clampf(maxf(ratio, 0.02), 0.0, 1.0)
	if rain != null:
		rain.visible = rain_amount > 0.025
		rain.emitting = rain_amount > 0.025
	if falling_petals != null:
		falling_petals.emitting = true
		falling_petals.speed_scale = 0.75 + rain_amount * 0.55


func _update_bokeh() -> void:
	for item in bokeh:
		var node: MeshInstance3D = item["node"]
		var base: Vector3 = item["base"]
		var phase: float = item["phase"]
		node.position = base + Vector3(
			sin(anim_time * 0.11 + phase) * 0.36,
			sin(anim_time * 0.20 + phase * 1.7) * 0.20,
			cos(anim_time * 0.09 + phase) * 0.30)
		var mat: StandardMaterial3D = item["material"]
		var alpha: float = item["alpha"]
		var pulse := 0.72 + 0.28 * sin(anim_time * 0.79 + phase * 1.9)
		mat.albedo_color.a = alpha * pulse * (0.34 + nightness * 1.05) * (1.0 - rain_amount * 0.30)


func _update_mist() -> void:
	if mist_material == null:
		return
	mist_material.albedo_color = Color(0.53, 0.61, 0.72,
			0.030 + nightness * 0.022 + rain_amount * 0.11)
	for i in range(mist_cards.size()):
		var node := mist_cards[i]
		var base := _mist_base[i]
		node.position = base + Vector3(
			sin(anim_time * 0.045 + _mist_phase[i]) * 0.62,
			sin(anim_time * 0.16 + _mist_phase[i]) * 0.045,
			cos(anim_time * 0.037 + _mist_phase[i]) * 0.45)


func _update_floating_shards() -> void:
	for item in floating_shards:
		var node: MeshInstance3D = item["node"]
		var base: Vector3 = item["base"]
		var phase: float = item["phase"]
		node.position = base + Vector3(
			sin(anim_time * 0.22 + phase) * 0.16,
			sin(anim_time * 0.34 + phase * 1.7) * 0.22,
			cos(anim_time * 0.17 + phase) * 0.12)
		node.rotation = Vector3(
			sin(anim_time * 0.19 + phase) * 0.18,
			anim_time * 0.08 + phase,
			cos(anim_time * 0.14 + phase) * 0.12)


func set_quality(high: bool) -> void:
	quality_high = high
	if grass_multimesh != null:
		grass_multimesh.multimesh.visible_instance_count = \
				grass_placed if high else int(grass_placed * 0.56)
	if daisy_multimesh != null:
		daisy_multimesh.multimesh.visible_instance_count = \
				daisy_placed if high else int(daisy_placed * 0.60)
	if lavender_multimesh != null:
		lavender_multimesh.multimesh.visible_instance_count = \
				lavender_placed if high else int(lavender_placed * 0.60)
	if bush_multimesh != null:
		bush_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if high \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if boulder_multimesh != null:
		boulder_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if high \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for item in canopy_pivots:
		var mesh: MeshInstance3D = item["mesh"]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if high \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if falling_petals != null:
		falling_petals.amount = 34 if high else 18
	if rain != null:
		rain.amount = 460 if high else 210
	for i in range(bokeh.size()):
		var node: MeshInstance3D = bokeh[i]["node"]
		node.visible = high or i < 4
	_update_fireflies()


func reset_state() -> void:
	anim_time = 0.0
	nightness = 1.0
	rain_amount = 0.0
	quality_high = true
	for node in interactables:
		node.reset()
	set_quality(true)
	tick(0.0, 1.0, 0.0, true)


func get_interaction_targets() -> Array:
	return interactables


func get_budget() -> Dictionary:
	return {
		"grass": grass_placed,
		"daisies": daisy_placed,
		"lavender": lavender_placed,
		"bushes": bush_multimesh.multimesh.visible_instance_count if bush_multimesh != null else 0,
		"ferns": fern_multimesh.multimesh.visible_instance_count if fern_multimesh != null else 0,
		"boulders": boulder_multimesh.multimesh.instance_count if boulder_multimesh != null else 0,
		"canopies": canopy_pivots.size(),
		"interactables": interactables.size(),
		"fireflies": fireflies.amount if fireflies != null else 0,
		"pollen": pollen.amount if pollen != null else 0,
		"petals": falling_petals.amount if falling_petals != null else 0,
		"rain": rain.amount if rain != null else 0,
		"canopy_shadows": quality_high,
	}


func get_time() -> float:
	return anim_time


func get_fish_positions() -> Array:
	var out: Array = []
	for fish in koi_data:
		out.append((fish["root"] as Node3D).position)
	return out
