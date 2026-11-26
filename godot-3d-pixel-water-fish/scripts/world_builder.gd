extends RefCounted

# 程序化场景构建：地形、草岛、石头、草簇、水草、水面、光柱、气泡、漂浮花。
# 全部几何由 SurfaceTool 生成；材质只使用本项目 shader；无外部贴图/模型。

const PondField = preload("res://scripts/pond_field.gd")

const SHADER_TOON = preload("res://shaders/scene_toon.gdshader")
const SHADER_WATER = preload("res://shaders/water_surface.gdshader")
const SHADER_SHAFT = preload("res://shaders/light_shaft.gdshader")

const TERRAIN_COLS := 121
const TERRAIN_ROWS := 89

var field_texture: ImageTexture
var water_material: ShaderMaterial
var shaft_material: ShaderMaterial
var toon_materials: Dictionary = {}
var terrain: MeshInstance3D
var water: MeshInstance3D
var shafts: MeshInstance3D
var light: DirectionalLight3D
var environment: WorldEnvironment
var grass_multimesh: MultiMeshInstance3D
var kelp_multimesh: MultiMeshInstance3D
var bubble_emitters: Array[CPUParticles3D] = []
var rocks: Array[MeshInstance3D] = []
var decor: MeshInstance3D

var _rng := RandomNumberGenerator.new()


func build(root: Node3D) -> void:
	_rng.seed = 20261126
	field_texture = PondField.build_field_texture()
	_build_environment(root)
	_build_light(root)
	_build_terrain(root)
	_build_islands(root)
	_build_rocks(root)
	_build_grass(root)
	_build_kelp(root)
	_build_algae(root)
	_build_water(root)
	_build_shafts(root)
	_build_floating_decor(root)
	_build_bubbles(root)


func _toon_material(key: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_TOON
	for k in params:
		m.set_shader_parameter(k, params[k])
	toon_materials[key] = m
	return m


func _build_environment(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.68, 0.84, 0.88)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.76, 0.87, 0.88)
	env.ambient_light_energy = 0.78
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = false
	env.glow_enabled = false
	env.adjustment_enabled = false
	var we := WorldEnvironment.new()
	we.name = "PondEnvironment"
	we.environment = env
	root.add_child(we)
	environment = we


func _build_light(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.light_energy = 1.32
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	root.add_child(sun)
	light = sun


# ── 地形 ────────────────────────────────────────────────────────────────
func _build_terrain(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size := PondField.BOUNDS_MAX - PondField.BOUNDS_MIN
	var verts: Array[Vector3] = []
	for iz in TERRAIN_ROWS:
		var v := float(iz) / float(TERRAIN_ROWS - 1)
		var z := PondField.BOUNDS_MIN.y + v * size.y
		for ix in TERRAIN_COLS:
			var u := float(ix) / float(TERRAIN_COLS - 1)
			var x := PondField.BOUNDS_MIN.x + u * size.x
			var p := Vector2(x, z)
			var y := PondField.terrain_y(p)
			var n := _terrain_normal(p)
			var col := _terrain_color(p, y)
			st.set_color(col)
			st.set_normal(n)
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3(x, y, z))
			verts.append(Vector3(x, y, z))
	for iz in TERRAIN_ROWS - 1:
		for ix in TERRAIN_COLS - 1:
			var i := iz * TERRAIN_COLS + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + TERRAIN_COLS)
			st.add_index(i + 1)
			st.add_index(i + TERRAIN_COLS + 1)
			st.add_index(i + TERRAIN_COLS)
	var mesh := st.commit()
	var mat := _toon_material("terrain", {
		"caustic_amount": 0.9,
		"rim_amount": 0.0,
		"wet_darken": 0.08,
		"tint": Color(1, 1, 1, 1),
	})
	var mi := MeshInstance3D.new()
	mi.name = "PondTerrain"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	terrain = mi


func _terrain_normal(p: Vector2) -> Vector3:
	var e := 0.08
	var hx := PondField.terrain_y(p + Vector2(e, 0)) - PondField.terrain_y(p - Vector2(e, 0))
	var hz := PondField.terrain_y(p + Vector2(0, e)) - PondField.terrain_y(p - Vector2(0, e))
	return Vector3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)).normalized()


func _terrain_color(p: Vector2, y: float) -> Color:
	var n1 := 0.5 + 0.5 * sin(p.x * 0.9 + p.y * 0.6)
	var n2 := 0.5 + 0.5 * sin(p.x * 2.3 - p.y * 1.7 + 1.7)
	var patch := clampf(n1 * 0.65 + n2 * 0.35, 0.0, 1.0)
	if PondField.is_water(p):
		var df := PondField.depth_factor(p)
		var sand := Color(0.82, 0.88, 0.8)
		var algae := Color(0.44, 0.68, 0.58)
		var col := sand.lerp(algae, clampf(df * 0.75 + patch * 0.2, 0.0, 1.0))
		# 浅水亮沙斑
		col = col.lerp(Color(0.94, 0.95, 0.86), smoothstep(0.5, 0.85, patch) * (1.0 - df * 0.7) * 0.6)
		col = col.lerp(Color(0.55, 0.78, 0.68), smoothstep(0.55, 0.9, patch) * df * 0.35)
		return col
	var out := -PondField.shore_distance(p)
	var bank := PondField.bank_y(p)
	var sand := Color(0.88, 0.82, 0.62)
	var grass := Color(0.54, 0.72, 0.35).lerp(Color(0.66, 0.8, 0.4), patch)
	var t := smoothstep(0.02, 0.16, bank) * smoothstep(0.0, 0.35, out)
	var col := sand.lerp(grass, t)
	return col


# ── 草岛 ────────────────────────────────────────────────────────────────
func _build_islands(root: Node3D) -> void:
	var mat := _toon_material("island", {
		"caustic_amount": 0.35,
		"rim_amount": 0.06,
		"shore_band": 1.0,
		"foam_color": Color(0.97, 1.0, 0.98, 1.0),
		"wet_darken": 0.1,
	})
	for idx in PondField.ISLANDS.size():
		var cfg: Dictionary = PondField.ISLANDS[idx]
		var mi := MeshInstance3D.new()
		mi.name = "GrassIsland%d" % idx
		mi.mesh = _island_mesh(idx)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


func _island_outline(idx: int, scale: float = 1.0) -> PackedVector2Array:
	var cfg: Dictionary = PondField.ISLANDS[idx]
	var center: Vector2 = cfg["center"]
	var radii: Vector2 = cfg["radii"]
	var rot: float = cfg["rot"]
	var seed: float = float(cfg["seed"])
	var pts := PackedVector2Array()
	var n := 44
	for i in n:
		var ang := TAU * float(i) / float(n)
		var wob := 1.0 + 0.055 * sin(ang * 3.0 + seed) + 0.035 * sin(ang * 7.0 - seed * 0.7)
		var local := Vector2(cos(ang) * radii.x, sin(ang) * radii.y) * wob * scale
		pts.append(center + local.rotated(rot))
	return pts


func _island_mesh(idx: int) -> ArrayMesh:
	var cfg: Dictionary = PondField.ISLANDS[idx]
	var height: float = float(cfg["height"])
	var rim := _island_outline(idx, 1.0)
	var inner := _island_outline(idx, 0.58)
	var n := rim.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center: Vector2 = cfg["center"]

	# 草帽顶面：外圈→内圈→中心
	var grass_rim := Color(0.62, 0.79, 0.38)
	var grass_mid := Color(0.66, 0.82, 0.41)
	var grass_top := Color(0.7, 0.85, 0.44)
	for i in n:
		var j := (i + 1) % n
		var a := Vector3(rim[i].x, height, rim[i].y)
		var b := Vector3(rim[j].x, height, rim[j].y)
		var c := Vector3(inner[j].x, height + 0.07, inner[j].y)
		var d := Vector3(inner[i].x, height + 0.07, inner[i].y)
		_add_tri(st, a, b, c, grass_rim, grass_mid, Vector3.UP)
		_add_tri(st, a, c, d, grass_rim, grass_mid, Vector3.UP)
	for i in n:
		var j := (i + 1) % n
		var a := Vector3(inner[i].x, height + 0.07, inner[i].y)
		var b := Vector3(inner[j].x, height + 0.07, inner[j].y)
		var c := Vector3(center.x, height + 0.15, center.y)
		_add_tri(st, a, b, c, grass_mid, grass_top, Vector3.UP)

	# 土壤侧壁 + 岛缘下垂草：四圈（顶、上、水线、底）
	var ring_top := _island_outline(idx, 1.0)
	var ring_upper := _island_outline(idx, 1.02)
	var ring_water := _island_outline(idx, 1.01)
	var ring_bottom := _island_outline(idx, 0.9)
	var top_col := Color(0.38, 0.52, 0.24)
	var upper_col := Color(0.44, 0.32, 0.24)
	var water_col := Color(0.36, 0.27, 0.21)
	var bottom_col := Color(0.26, 0.2, 0.17)
	for i in n:
		var j := (i + 1) % n
		var ang_i := TAU * float(i) / float(n)
		var outward := Vector3(cos(ang_i + float(cfg["rot"])), 0.1, sin(ang_i + float(cfg["rot"]))).normalized()
		var a := Vector3(ring_top[i].x, height - 0.02, ring_top[i].y)
		var b := Vector3(ring_top[j].x, height - 0.02, ring_top[j].y)
		var c := Vector3(ring_upper[j].x, 0.17, ring_upper[j].y)
		var d := Vector3(ring_upper[i].x, 0.17, ring_upper[i].y)
		_add_tri_n(st, a, b, c, top_col, upper_col, outward)
		_add_tri_n(st, a, c, d, top_col, upper_col, outward)
		var e := Vector3(ring_water[j].x, 0.01, ring_water[j].y)
		var f := Vector3(ring_water[i].x, 0.01, ring_water[i].y)
		_add_tri_n(st, d, c, e, upper_col, water_col, outward)
		_add_tri_n(st, d, e, f, upper_col, water_col, outward)
		var g := Vector3(ring_bottom[j].x, -0.55, ring_bottom[j].y)
		var h := Vector3(ring_bottom[i].x, -0.55, ring_bottom[i].y)
		_add_tri_n(st, f, e, g, water_col, bottom_col, outward)
		_add_tri_n(st, f, g, h, water_col, bottom_col, outward)
	return st.commit()


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, n: Vector3) -> void:
	st.set_normal(n)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_color(cb)
	st.add_vertex(c)


func _add_tri_n(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, n: Vector3) -> void:
	_add_tri(st, a, b, c, ca, cb, n)


# ── 石头 ────────────────────────────────────────────────────────────────
func _build_rocks(root: Node3D) -> void:
	var mat := _toon_material("rock", {
		"caustic_amount": 0.55,
		"rim_amount": 0.16,
		"tint": Color(1, 1, 1, 1),
	})
	for rock in PondField.ROCKS:
		var p: Vector2 = rock["pos"]
		var radius: float = float(rock["radius"])
		var height: float = float(rock["height"])
		var seed: int = int(rock["seed"])
		var base_y := 0.0
		var island_idx := int(rock["on_island"])
		if island_idx >= 0 and island_idx < PondField.ISLANDS.size():
			base_y = PondField.island_top_y(island_idx, p) - 0.03
		else:
			base_y = -0.3
		var mi := MeshInstance3D.new()
		mi.name = "Rock%d" % seed
		mi.mesh = _rock_mesh(seed, radius, height)
		mi.material_override = mat
		mi.position = Vector3(p.x, base_y, p.y)
		mi.rotation.y = float(seed) * 0.37
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		rocks.append(mi)


func _rock_mesh(seed: int, radius: float, height: float) -> ArrayMesh:
	var rings := 7
	var segs := 10
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for r in rings:
		var row: Array = []
		var theta := PI * float(r) / float(rings)
		for s in segs:
			var ang := TAU * float(s) / float(segs)
			var dir := Vector3(sin(theta) * cos(ang), cos(theta), sin(theta) * sin(ang))
			var wobble := 1.0 + 0.16 * sin(ang * 3.0 + seed) * sin(theta * 2.1) + 0.08 * sin(theta * 5.0 - seed)
			var pos := Vector3(dir.x * radius * wobble, (0.5 - dir.y * 0.5) * height * wobble, dir.z * radius * wobble)
			row.append(pos)
		grid.append(row)
	# 顶点 + 面，显式设平滑法线
	for r in rings - 1:
		for s in segs:
			var s2 := (s + 1) % segs
			var a: Vector3 = grid[r][s]
			var b: Vector3 = grid[r][s2]
			var c: Vector3 = grid[r + 1][s2]
			var d: Vector3 = grid[r + 1][s]
			var n_face := (b - a).cross(c - a).normalized()
			if n_face.y < 0.0:
				n_face = -n_face
			var ca := _rock_color(a, radius, height, seed)
			var cb := _rock_color(b, radius, height, seed)
			var cc := _rock_color(c, radius, height, seed)
			var cd := _rock_color(d, radius, height, seed)
			st.set_color(ca); st.set_normal(n_face); st.add_vertex(a)
			st.set_color(cb); st.set_normal(n_face); st.add_vertex(b)
			st.set_color(cc); st.set_normal(n_face); st.add_vertex(c)
			st.set_color(ca); st.set_normal(n_face); st.add_vertex(a)
			st.set_color(cc); st.set_normal(n_face); st.add_vertex(c)
			st.set_color(cd); st.set_normal(n_face); st.add_vertex(d)
	return st.commit()


func _rock_color(p: Vector3, radius: float, height: float, seed: int) -> Color:
	var up := clampf(p.y / max(height, 0.001), 0.0, 1.0)
	var crack := 0.5 + 0.5 * sin(atan2(p.z, p.x) * 9.0 + seed * 0.7)
	var base := Color(0.55, 0.52, 0.6).lerp(Color(0.7, 0.65, 0.74), crack * 0.5)
	var moss := Color(0.55, 0.7, 0.4)
	var col := base.lerp(moss, smoothstep(0.55, 0.95, up) * 0.7)
	return col.darkened((1.0 - up) * 0.16)


# ── 草簇 / 水草 ─────────────────────────────────────────────────────────
func _build_grass(root: Node3D) -> void:
	var mat := _toon_material("grass", {
		"caustic_amount": 0.2,
		"rim_amount": 0.12,
		"sway_amount": 0.05,
		"sway_ref": 0.11,
		"sway_speed": 1.35,
		"tint": Color(1, 1, 1, 1),
	})
	var blade := _tuft_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	# 岛顶与岛缘
	for idx in PondField.ISLANDS.size():
		var cfg: Dictionary = PondField.ISLANDS[idx]
		var center: Vector2 = cfg["center"]
		var radii: Vector2 = cfg["radii"]
		var rot: float = cfg["rot"]
		var height: float = float(cfg["height"])
		for k in 44:
			var ang := _rng.randf() * TAU
			var rad := sqrt(_rng.randf()) * 0.95
			var local := Vector2(cos(ang) * radii.x * rad, sin(ang) * radii.y * rad).rotated(rot)
			var p := center + local
			var y := PondField.island_top_y(idx, p) + 0.02
			transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.4)), Vector3(p.x, y, p.y)))
			colors.append(Color(0.68, 0.84, 0.44).lerp(Color(0.88, 0.96, 0.56), _rng.randf()))
		# 岛缘下垂草
		var rim := _island_outline(idx, 0.99)
		for k in rim.size():
			if k % 2 != 0:
				continue
			var p := rim[k]
			var y := height - 0.01
			transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1.15, _rng.randf_range(0.45, 0.7), 1.15)), Vector3(p.x, y, p.y)))
			colors.append(Color(0.66, 0.83, 0.42))
	# 外圈岸草
	var placed := 0
	var guard := 0
	while placed < 240 and guard < 1600:
		guard += 1
		var x := _rng.randf_range(PondField.BOUNDS_MIN.x, PondField.BOUNDS_MAX.x)
		var z := _rng.randf_range(PondField.BOUNDS_MIN.y, PondField.BOUNDS_MAX.y)
		var p := Vector2(x, z)
		if PondField.is_water(p):
			continue
		if -PondField.shore_distance(p) > 3.2:
			continue
		var y := PondField.bank_y(p) + 0.01
		transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.7, 1.25)), Vector3(x, y, z)))
		colors.append(Color(0.5, 0.68, 0.34).lerp(Color(0.68, 0.8, 0.42), _rng.randf()))
		placed += 1
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GrassTufts"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	grass_multimesh = mmi


func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 5
	for k in n:
		var ang := TAU * float(k) / float(n) + 0.35
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x) * 0.06
		var base := Vector3(dir.x * 0.025, 0.0, dir.y * 0.025)
		var tip := Vector3(dir.x * 0.18, 0.11, dir.y * 0.18)
		var ca := Color(0.6, 0.78, 0.36)
		var ct := Color(0.92, 1.0, 0.62)
		var l := Vector3(base.x + side.x, 0.0, base.z + side.y)
		var r := Vector3(base.x - side.x, 0.0, base.z - side.y)
		st.set_normal(Vector3.UP); st.set_color(ca); st.add_vertex(l)
		st.set_normal(Vector3.UP); st.set_color(ca); st.add_vertex(r)
		st.set_normal(Vector3.UP); st.set_color(ct); st.add_vertex(tip)
	return st.commit()


func _build_kelp(root: Node3D) -> void:
	var mat := _toon_material("kelp", {
		"caustic_amount": 0.55,
		"rim_amount": 0.18,
		"sway_amount": 0.11,
		"sway_ref": 1.0,
		"sway_speed": 0.85,
		"tint": Color(1, 1, 1, 1),
	})
	var ribbon := _kelp_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = ribbon
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var centers: Array[Vector2] = []
	var guard := 0
	while centers.size() < 9 and guard < 300:
		guard += 1
		var x := _rng.randf_range(PondField.BOUNDS_MIN.x + 2.5, PondField.BOUNDS_MAX.x - 2.5)
		var z := _rng.randf_range(PondField.BOUNDS_MIN.y + 2.0, PondField.BOUNDS_MAX.y - 2.0)
		var p := Vector2(x, z)
		if not PondField.is_water(p):
			continue
		if PondField.depth_factor(p) < 0.3:
			continue
		if PondField.fish_blocked(p, 1.0):
			continue
		centers.append(p)
	var placed := 0
	for c in centers:
		for k in 7:
			var p := c + Vector2(_rng.randf_range(-0.85, 0.85), _rng.randf_range(-0.7, 0.7))
			if not PondField.is_water(p):
				continue
			if PondField.depth_factor(p) < 0.2:
				continue
			if PondField.fish_blocked(p, 0.6):
				continue
			var y := PondField.floor_y(p) + 0.02
			var sc := _rng.randf_range(0.55, 1.25)
			transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.7, 1.05), sc)), Vector3(p.x, y, p.y)))
			colors.append(Color(0.52, 0.72, 0.46).lerp(Color(0.72, 0.88, 0.58), _rng.randf()))
			placed += 1
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Kelp"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	kelp_multimesh = mmi


func _kelp_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var ang := TAU * float(k) / 3.0
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x)
		var lean := Vector2(cos(ang + 0.7), sin(ang + 0.7)) * 0.18
		var segs := 7
		for s in segs:
			var t0 := float(s) / float(segs)
			var t1 := float(s + 1) / float(segs)
			var bend0 := lean * t0 * t0
			var bend1 := lean * t1 * t1
			var w0 := lerpf(0.035, 0.08, t0)
			var w1 := lerpf(0.035, 0.08, t1)
			var y0 := t0 * 1.0
			var y1 := t1 * 1.0
			var a := Vector3(bend0.x - side.x * w0, y0, bend0.y - side.y * w0)
			var b := Vector3(bend0.x + side.x * w0, y0, bend0.y + side.y * w0)
			var c := Vector3(bend1.x + side.x * w1, y1, bend1.y + side.y * w1)
			var d := Vector3(bend1.x - side.x * w1, y1, bend1.y - side.y * w1)
			var ca := Color(0.3, 0.52, 0.32).lerp(Color(0.55, 0.76, 0.46), t0)
			var cb := Color(0.3, 0.52, 0.32).lerp(Color(0.55, 0.76, 0.46), t1)
			st.set_normal(Vector3(0, 0.6, 0.8)); st.set_color(ca); st.add_vertex(a)
			st.set_normal(Vector3(0, 0.6, 0.8)); st.set_color(ca); st.add_vertex(b)
			st.set_normal(Vector3(0, 0.6, 0.8)); st.set_color(cb); st.add_vertex(c)
			st.set_normal(Vector3(0, 0.6, 0.8)); st.set_color(ca); st.add_vertex(a)
			st.set_normal(Vector3(0, 0.6, 0.8)); st.set_color(cb); st.add_vertex(c)
			st.set_normal(Vector3(0, 0.6, 0.8)); st.set_color(cb); st.add_vertex(d)
	return st.commit()


# ── 水下藻丘 ───────────────────────────────────────────────────────────
func _build_algae(root: Node3D) -> void:
	var mat := _toon_material("algae", {
		"caustic_amount": 0.8,
		"rim_amount": 0.05,
		"tint": Color(1, 1, 1, 1),
	})
	var spots := [
		Vector2(-6.4, 0.8), Vector2(-3.0, -3.6), Vector2(3.2, 2.8),
		Vector2(6.6, -2.2), Vector2(0.4, -4.6), Vector2(7.2, 4.0),
		Vector2(-8.4, -1.8), Vector2(-1.8, 4.6),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in spots.size():
		var p: Vector2 = spots[i]
		if not PondField.is_water(p):
			continue
		var df := PondField.depth_factor(p)
		if df < 0.25:
			continue
		var y := PondField.floor_y(p) + 0.03
		var r := 0.6 + df * 0.6 + 0.12 * sin(float(i) * 2.3)
		var h := 0.1 + df * 0.13
		_add_algae_dome(st, Vector3(p.x, y, p.y), r, h, i)
	var mi := MeshInstance3D.new()
	mi.name = "AlgaeMounds"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func _add_algae_dome(st: SurfaceTool, center: Vector3, r: float, h: float, seed: int) -> void:
	var rings := 4
	var segs := 10
	var pos: Array = []
	for ring in rings + 1:
		var phi := (PI * 0.5) * float(ring) / float(rings)
		var row: Array = []
		for s in segs:
			var ang := TAU * float(s) / float(segs)
			var wob := 1.0 + 0.12 * sin(ang * 3.0 + float(seed) * 1.7)
			var p := Vector3(cos(ang) * r * sin(phi) * wob, h * cos(phi), sin(ang) * r * sin(phi) * wob)
			row.append(center + p)
		pos.append(row)
	var c0 := Color(0.55, 0.72, 0.44)
	var c1 := Color(0.68, 0.82, 0.52)
	for ring in rings:
		for s in segs:
			var s2 := (s + 1) % segs
			var a: Vector3 = pos[ring][s]
			var b: Vector3 = pos[ring][s2]
			var c: Vector3 = pos[ring + 1][s2]
			var d: Vector3 = pos[ring + 1][s]
			var n := (b - a).cross(c - a).normalized()
			if n.y < 0.0:
				n = -n
			var t := float(ring) / float(rings)
			var col := c0.lerp(c1, t)
			st.set_normal(n); st.set_color(col); st.add_vertex(a)
			st.set_normal(n); st.set_color(col); st.add_vertex(b)
			st.set_normal(n); st.set_color(col); st.add_vertex(c)
			st.set_normal(n); st.set_color(col); st.add_vertex(a)
			st.set_normal(n); st.set_color(col); st.add_vertex(c)
			st.set_normal(n); st.set_color(col); st.add_vertex(d)


# ── 水面 / 光柱 / 漂浮花 / 气泡 ─────────────────────────────────────────
func _build_water(root: Node3D) -> void:
	var pm := PlaneMesh.new()
	var size := PondField.BOUNDS_MAX - PondField.BOUNDS_MIN
	pm.size = size
	pm.subdivide_width = 1
	pm.subdivide_depth = 1
	var mi := MeshInstance3D.new()
	mi.name = "WaterSurface"
	mi.mesh = pm
	mi.position = Vector3((PondField.BOUNDS_MIN.x + PondField.BOUNDS_MAX.x) * 0.5, PondField.WATER_LEVEL, (PondField.BOUNDS_MIN.y + PondField.BOUNDS_MAX.y) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 10.0
	water_material = ShaderMaterial.new()
	water_material.shader = SHADER_WATER
	water_material.set_shader_parameter("field_tex", field_texture)
	water_material.set_shader_parameter("field_origin", PondField.BOUNDS_MIN)
	water_material.set_shader_parameter("field_size", size)
	water_material.set_shader_parameter("shallow_color", Color(0.68, 0.94, 0.9))
	water_material.set_shader_parameter("deep_color", Color(0.4, 0.76, 0.82))
	water_material.set_shader_parameter("foam_color", Color(0.95, 0.99, 0.97))
	water_material.set_shader_parameter("sky_color", Color(0.68, 0.86, 0.92))
	water_material.set_shader_parameter("sun_color", Color(1.0, 0.97, 0.86))
	mi.material_override = water_material
	water = mi
	root.add_child(mi)


func _build_shafts(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spots := [
		Vector2(-3.0, 0.6), Vector2(2.6, -1.4), Vector2(5.6, 2.1), Vector2(-1.4, 3.4),
		Vector2(-6.2, -2.2), Vector2(0.6, -0.4), Vector2(4.2, 4.0), Vector2(-1.0, -3.4)
	]
	for i in spots.size():
		var p: Vector2 = spots[i]
		var w := 0.55 + 0.25 * float(i % 3)
		var top := Vector3(p.x + 0.8, -0.02, p.y)
		var bottom := Vector3(p.x - 0.9, -1.95, p.y - 0.4)
		var dirs := [Vector2(1, 0), Vector2(0, 1)]
		for dir in dirs:
			var side := Vector3(dir.y, 0, dir.x) * w
			var a := top - side
			var b := top + side
			var c := bottom + side * 1.35
			var d := bottom - side * 1.35
			_add_uv_tri(st, a, b, c, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
			_add_uv_tri(st, a, c, d, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))
	var mi := MeshInstance3D.new()
	mi.name = "LightShafts"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 10.0
	shaft_material = ShaderMaterial.new()
	shaft_material.shader = SHADER_SHAFT
	shaft_material.render_priority = -1
	mi.material_override = shaft_material
	shafts = mi
	root.add_child(mi)


func _add_uv_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)


func _build_floating_decor(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 白色五瓣花
	var flower_spots := [
		Vector2(0.5, 1.4), Vector2(-1.9, 2.6), Vector2(5.3, 0.1), Vector2(-4.5, -2.6),
		Vector2(2.4, -2.8), Vector2(-6.1, 0.9), Vector2(6.2, -0.7), Vector2(1.9, 3.3)
	]
	for p in flower_spots:
		if not PondField.is_water(p):
			continue
		_add_flower(st, p, _rng.randf() * TAU, 0.09)
	# 花瓣
	for k in 14:
		var x := _rng.randf_range(PondField.BOUNDS_MIN.x + 3.0, PondField.BOUNDS_MAX.x - 3.0)
		var z := _rng.randf_range(PondField.BOUNDS_MIN.y + 2.0, PondField.BOUNDS_MAX.y - 2.0)
		var p := Vector2(x, z)
		if not PondField.is_water(p):
			continue
		var ang := _rng.randf() * TAU
		var col := Color(0.95, 0.96, 0.9)
		var c := Vector3(p.x, 0.025, p.y)
		var a := c + Vector3(cos(ang), 0, sin(ang)) * 0.05
		var b := c + Vector3(cos(ang + 2.1), 0, sin(ang + 2.1)) * 0.04
		var d := c + Vector3(cos(ang + 3.9), 0, sin(ang + 3.9)) * 0.045
		_add_flat_tri(st, c, a, b, col)
		_add_flat_tri(st, c, b, d, col)
	# 荷叶
	for p in [Vector2(-1.1, -2.3), Vector2(4.8, 2.9), Vector2(-5.2, -0.4), Vector2(0.9, -1.1)]:
		if not PondField.is_water(p):
			continue
		_add_lily_pad(st, p, 0.45 + 0.2 * sin(p.x * 2.0), _rng.randf() * TAU)
	var mi := MeshInstance3D.new()
	mi.name = "FloatingDecor"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	decor = mi
	root.add_child(mi)


func _add_flower(st: SurfaceTool, p: Vector2, rot: float, size: float) -> void:
	var center := Vector3(p.x, 0.03, p.y)
	var petal_col := Color(0.95, 0.97, 0.9)
	var heart_col := Color(0.94, 0.82, 0.42)
	for k in 5:
		var ang := rot + TAU * float(k) / 5.0
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var tip := center + dir * size + Vector3(0, 0.002, 0)
		var l := center + side * size * 0.35
		var r := center - side * size * 0.35
		_add_flat_tri(st, center, l, tip, petal_col)
		_add_flat_tri(st, center, tip, r, petal_col)
	_add_flat_tri(st, center + Vector3(-0.012, 0.004, 0), center + Vector3(0.012, 0.004, 0), center + Vector3(0, 0.004, 0.02), heart_col)


func _add_lily_pad(st: SurfaceTool, p: Vector2, radius: float, rot: float) -> void:
	var center := Vector3(p.x, 0.02, p.y)
	var col := Color(0.55, 0.72, 0.4).lerp(Color(0.68, 0.82, 0.45), 0.4)
	var segs := 14
	for k in segs:
		if k == 2:
			continue
		var a0 := rot + TAU * float(k) / float(segs)
		var a1 := rot + TAU * float(k + 1) / float(segs)
		var v0 := center + Vector3(cos(a0), 0, sin(a0)) * radius
		var v1 := center + Vector3(cos(a1), 0, sin(a1)) * radius
		_add_flat_tri(st, center, v0, v1, col)


func _add_flat_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_normal(Vector3.UP)
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(b)
	st.set_color(col)
	st.add_vertex(c)


func _build_bubbles(root: Node3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.82, 0.94, 1.0, 0.62)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for p in [Vector3(2.2, -0.9, 1.8), Vector3(-5.5, -0.8, -2.0), Vector3(5.4, -1.0, 2.8)]:
		var cp := CPUParticles3D.new()
		cp.name = "Bubbles"
		cp.amount = 20
		cp.lifetime = 4.2
		cp.preprocess = 2.0
		cp.mesh = quad
		cp.material_override = mat
		cp.position = p
		cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		cp.emission_sphere_radius = 0.28
		cp.direction = Vector3(0, 1, 0)
		cp.spread = 16.0
		cp.initial_velocity_min = 0.06
		cp.initial_velocity_max = 0.13
		cp.gravity = Vector3(0, 0.32, 0)
		cp.scale_amount_min = 0.55
		cp.scale_amount_max = 1.35
		cp.color = Color(0.8, 0.95, 1.0, 0.75)
		cp.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2))
		root.add_child(cp)
		bubble_emitters.append(cp)
