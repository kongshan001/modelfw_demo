extends Node3D
## 原创低模雾林场景：起伏林地、树群、碎石、石柱拱门、踏石小径、浅潭、石灯笼、雾精灵、草叶。
## 全部程序化生成，不加载外部模型/贴图；材质使用 GL Compatibility 可用的 StandardMaterial3D
## 与两个轻量 custom spatial shader（水面/草叶），环境雾自动叠加。

const WORLD_SIZE := 110.0
const GRID := 72
const WATER_LEVEL := -0.35
const POOL_CENTER := Vector2(10.0, 6.0)
const POOL_RADIUS := 7.4
const RUIN_CENTER := Vector2(-1.0, -13.5)
const LANTERN_POSITIONS := [Vector2(6.2, 12.0), Vector2(-2.6, 3.2), Vector2(6.4, -5.4)]
const GRASS_COUNT := 1200

var ground_material: StandardMaterial3D
var water_material: ShaderMaterial
var grass_material: ShaderMaterial
var grass_multimesh: MultiMeshInstance3D
var grass_placed := 0
var lantern_orb_material: StandardMaterial3D
var lantern_glow_material: StandardMaterial3D
var lantern_pool_material: StandardMaterial3D
var lantern_orb_positions: Array[Vector3] = []
var wisp_material: StandardMaterial3D
var wisp_halo_material: StandardMaterial3D
var wisp_node: Node3D
var wisp_halo: MeshInstance3D
var water_mesh: MeshInstance3D
var water_uv_offset := Vector2.ZERO
# 角色碰撞用圆形障碍（树干/石柱/灯笼），由角色控制器做轻量推离。
var obstacle_circles: Array[Dictionary] = []
# 低矮石块不参与碰撞（可跨越），但用于挑选角色出生/机位时避免脚底穿石。
var rock_positions: Array[Vector2] = []
var _anim_time := 0.0

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _mist_texture: ImageTexture
var _glow_texture: ImageTexture
var _pool_texture: ImageTexture
var _leaf_texture: ImageTexture
var _detail_texture: ImageTexture


func _ready() -> void:
	_rng.seed = 20261124
	_noise.seed = 731
	_noise.frequency = 0.5
	_noise.fractal_octaves = 3
	_mist_texture = _make_mist_texture(256, 11)
	_glow_texture = _make_radial_texture(128, 0.0)
	_pool_texture = _make_pool_texture(128)
	_leaf_texture = _make_leaf_texture(64)
	_detail_texture = _make_detail_texture(128)
	_build_ground()
	_build_water()
	_build_lilies()
	_build_trees()
	_build_rocks()
	_build_ruins()
	_build_stones()
	_build_grass()
	_build_lanterns()
	_build_wisp()


func _process(delta: float) -> void:
	_anim_time += delta
	if water_material != null:
		water_uv_offset += Vector2(0.010, 0.006) * delta
	if wisp_node != null:
		wisp_node.position.y = _wisp_base_y + sin(_anim_time * 1.1) * 0.18
	if wisp_halo != null:
		var pulse := 0.92 + 0.08 * sin(_anim_time * 2.3)
		wisp_halo.scale = Vector3(pulse, pulse, pulse)


# ---------------------------------------------------------------- 地形

func terrain_height(x: float, z: float) -> float:
	var h := 0.55 * sin(x * 0.12) * cos(z * 0.10)
	h += 0.35 * sin((x + z) * 0.055)
	h += _noise.get_noise_2d(x * 1.7, z * 1.7) * 0.38
	var pool_d := Vector2(x - POOL_CENTER.x, z - POOL_CENTER.y).length()
	var rim_blend := 1.0 - smoothstep(POOL_RADIUS + 1.5, POOL_RADIUS + 6.0, pool_d)
	h = lerpf(h, 0.35, rim_blend)
	h -= 2.10 * (1.0 - smoothstep(2.0, POOL_RADIUS, pool_d))
	var ruin_d := Vector2(x - RUIN_CENTER.x, z - RUIN_CENTER.y).length()
	h += 0.20 * (1.0 - smoothstep(2.0, 7.0, ruin_d))
	return h


func path_center_x(z: float) -> float:
	return 2.6 * sin((z + 8.0) * 0.075) + 1.0


func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := WORLD_SIZE * 0.5
	var step := WORLD_SIZE / float(GRID)
	for zi in range(GRID):
		for xi in range(GRID):
			var x0 := -half + xi * step
			var z0 := -half + zi * step
			var x1 := x0 + step
			var z1 := z0 + step
			var p00 := Vector3(x0, terrain_height(x0, z0), z0)
			var p10 := Vector3(x1, terrain_height(x1, z0), z0)
			var p01 := Vector3(x0, terrain_height(x0, z1), z1)
			var p11 := Vector3(x1, terrain_height(x1, z1), z1)
			_add_ground_tri(st, p00, p01, p11)
			_add_ground_tri(st, p00, p11, p10)
	st.generate_normals()
	ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.92, 0.94, 0.88)
	ground_material.albedo_texture = _detail_texture
	ground_material.vertex_color_use_as_albedo = true
	ground_material.roughness = 1.0
	ground_material.metallic = 0.0
	ground_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = st.commit()
	mi.material_override = ground_material
	add_child(mi)


func _add_ground_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p in [a, b, c]:
		var pool_d := Vector2(p.x - POOL_CENTER.x, p.z - POOL_CENTER.y).length()
		var path_d := absf(p.x - path_center_x(p.z))
		var n := _noise.get_noise_2d(p.x * 0.9, p.z * 0.9)
		var n2 := _noise.get_noise_2d(p.x * 3.3 + 17.0, p.z * 3.3 + 31.0)
		var moss := Color(0.20, 0.30, 0.12).lerp(Color(0.34, 0.39, 0.18), 0.5 + n * 0.5)
		moss = moss.lerp(Color(0.12, 0.17, 0.08), 0.25 + 0.25 * sin(p.x * 0.3 + p.z * 0.2))
		var dirt := Color(0.37, 0.29, 0.19).lerp(Color(0.27, 0.22, 0.15), 0.5 + n * 0.5)
		var path_mask := 1.0 - smoothstep(1.1, 3.2, path_d)
		var col := moss.lerp(dirt, clampf(path_mask * 0.9, 0.0, 1.0))
		var litter := smoothstep(0.15, 0.75, n2) * 0.4 * (1.0 - path_mask)
		col = col.lerp(Color(0.38, 0.29, 0.15), litter)
		var wet := 1.0 - smoothstep(POOL_RADIUS - 2.2, POOL_RADIUS + 2.4, pool_d)
		col = col.lerp(Color(0.10, 0.14, 0.11), wet * 0.7)
		var ruin_d := Vector2(p.x - RUIN_CENTER.x, p.z - RUIN_CENTER.y).length()
		col = col.lerp(Color(0.28, 0.27, 0.21), (1.0 - smoothstep(2.0, 6.0, ruin_d)) * 0.35)
		st.set_color(col)
		st.set_uv(Vector2(p.x, p.z) * 0.20)
		st.add_vertex(p)


# ---------------------------------------------------------------- 水面

func _build_water() -> void:
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://shaders/water.gdshader")
	var disc := CylinderMesh.new()
	disc.top_radius = POOL_RADIUS + 0.15
	disc.bottom_radius = POOL_RADIUS + 0.15
	disc.height = 0.06
	disc.radial_segments = 36
	disc.rings = 1
	water_mesh = MeshInstance3D.new()
	water_mesh.name = "Pool"
	water_mesh.mesh = disc
	water_mesh.material_override = water_material
	water_mesh.position = Vector3(POOL_CENTER.x, WATER_LEVEL, POOL_CENTER.y)
	add_child(water_mesh)
	water_uv_offset = Vector2.ZERO


func _build_lilies() -> void:
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 0.55
	pad_mesh.bottom_radius = 0.55
	pad_mesh.height = 0.025
	pad_mesh.radial_segments = 12
	pad_mesh.rings = 1
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.78, 0.86, 0.62)
	pad_mat.vertex_color_use_as_albedo = true
	pad_mat.roughness = 1.0
	pad_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = pad_mesh
	mm.instance_count = 9
	for i in range(mm.instance_count):
		var ang := _rng.randf_range(0.0, TAU)
		var rad := _rng.randf_range(1.6, 4.8)
		var p := POOL_CENTER + Vector2(cos(ang), sin(ang)) * rad
		var s := _rng.randf_range(0.6, 1.35)
		var basis := Basis.from_euler(Vector3(0.0, _rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(s, 1.0, s * _rng.randf_range(0.8, 1.2)))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, WATER_LEVEL + 0.055, p.y)))
		mm.set_instance_color(i, Color(0.55, 0.72, 0.42).lerp(Color(0.82, 0.78, 0.40), _rng.randf() * 0.5))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "LilyPads"
	mmi.multimesh = mm
	mmi.material_override = pad_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ---------------------------------------------------------------- 树 / 石

func _build_trees() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.42
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 7
	trunk_mesh.rings = 1
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.28, 0.24, 0.19)
	trunk_mat.vertex_color_use_as_albedo = true
	trunk_mat.roughness = 1.0
	trunk_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 0.5
	canopy_mesh.height = 1.0
	canopy_mesh.radial_segments = 7
	canopy_mesh.rings = 4
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.75, 0.85, 0.62)
	canopy_mat.vertex_color_use_as_albedo = true
	canopy_mat.roughness = 1.0
	canopy_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var tree_spots: Array[Vector2] = []
	var attempts := 0
	while tree_spots.size() < 26 and attempts < 200:
		attempts += 1
		var ang := _rng.randf_range(0.0, TAU)
		var rad := _rng.randf_range(14.0, 34.0)
		var p := Vector2(cos(ang) * rad, sin(ang) * rad * 0.9)
		if not _tree_spot_is_clear(p):
			continue
		tree_spots.append(p)
	tree_spots.append(Vector2(-11.0, -3.0))
	tree_spots.append(Vector2(14.0, -9.0))
	tree_spots.append(Vector2(-9.0, 15.0))

	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.use_colors = true
	trunk_mm.mesh = trunk_mesh
	trunk_mm.instance_count = tree_spots.size()
	var canopy_mm := MultiMesh.new()
	canopy_mm.transform_format = MultiMesh.TRANSFORM_3D
	canopy_mm.use_colors = true
	canopy_mm.mesh = canopy_mesh
	canopy_mm.instance_count = tree_spots.size() * 3

	var canopy_index := 0
	for i in range(tree_spots.size()):
		var p := tree_spots[i]
		var h := terrain_height(p.x, p.y)
		var trunk_h := _rng.randf_range(5.5, 9.0)
		var trunk_w := _rng.randf_range(0.8, 1.35)
		obstacle_circles.append({"pos": p, "radius": 0.42 * trunk_w + 0.22, "height": trunk_h})
		var trunk_xform := Transform3D(
			Basis.from_scale(Vector3(trunk_w, trunk_h, trunk_w)),
			Vector3(p.x, h + trunk_h * 0.5, p.y)
		)
		trunk_mm.set_instance_transform(i, trunk_xform)
		trunk_mm.set_instance_color(i, Color(0.70, 0.72, 0.68).lerp(Color(0.98, 0.94, 0.88), _rng.randf()))
		var crown_y := h + trunk_h
		var crown_col := Color(0.10, 0.17, 0.085).lerp(Color(0.20, 0.28, 0.12), _rng.randf())
		var blobs := 2 + (1 if _rng.randf() < 0.5 else 0)
		for b in range(3):
			var bx := p.x + _rng.randf_range(-1.3, 1.3) * (1.0 if b > 0 else 0.0)
			var bz := p.y + _rng.randf_range(-1.3, 1.3) * (1.0 if b > 0 else 0.0)
			var by := crown_y + _rng.randf_range(-0.3, 0.9) + (0.8 if b == 0 else 0.0)
			var sx := _rng.randf_range(3.3, 5.2)
			var sy := _rng.randf_range(1.6, 2.6)
			var sz := _rng.randf_range(3.0, 4.8)
			if b >= blobs:
				sx *= 0.001
				sy *= 0.001
				sz *= 0.001
			var basis := Basis.from_euler(Vector3(0.0, _rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(sx, sy, sz))
			canopy_mm.set_instance_transform(canopy_index, Transform3D(basis, Vector3(bx, by, bz)))
			canopy_mm.set_instance_color(canopy_index, crown_col.lerp(Color(0.17, 0.25, 0.11), _rng.randf() * 0.6))
			canopy_index += 1

	var trunk_mmi := MultiMeshInstance3D.new()
	trunk_mmi.name = "Trunks"
	trunk_mmi.multimesh = trunk_mm
	trunk_mmi.material_override = trunk_mat
	trunk_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(trunk_mmi)
	var canopy_mmi := MultiMeshInstance3D.new()
	canopy_mmi.name = "Canopies"
	canopy_mmi.multimesh = canopy_mm
	canopy_mmi.material_override = canopy_mat
	canopy_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(canopy_mmi)


func _tree_spot_is_clear(p: Vector2) -> bool:
	if Vector2(p.x - POOL_CENTER.x, p.y - POOL_CENTER.y).length() < POOL_RADIUS + 3.0:
		return false
	if Vector2(p.x - RUIN_CENTER.x, p.y - RUIN_CENTER.y).length() < 7.5:
		return false
	if absf(p.x - path_center_x(p.y)) < 3.2:
		return false
	return true


func _build_rocks() -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.5
	rock_mesh.height = 1.0
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 3
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.82, 0.84, 0.80)
	rock_mat.vertex_color_use_as_albedo = true
	rock_mat.roughness = 1.0
	rock_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var rock_mm := MultiMesh.new()
	rock_mm.transform_format = MultiMesh.TRANSFORM_3D
	rock_mm.use_colors = true
	rock_mm.mesh = rock_mesh
	rock_mm.instance_count = 34
	var idx := 0
	# 潭边石
	for i in range(9):
		var a := TAU * float(i) / 9.0 + _rng.randf_range(-0.15, 0.15)
		var p := POOL_CENTER + Vector2(cos(a), sin(a)) * (POOL_RADIUS + _rng.randf_range(-0.4, 1.6))
		idx = _set_rock(rock_mm, idx, p)
	while idx < rock_mm.instance_count:
		var p := Vector2(_rng.randf_range(-38.0, 38.0), _rng.randf_range(-38.0, 38.0))
		if absf(p.x - path_center_x(p.y)) < 1.6:
			continue
		idx = _set_rock(rock_mm, idx, p)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Rocks"
	mmi.multimesh = rock_mm
	mmi.material_override = rock_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)


func _set_rock(mm: MultiMesh, idx: int, p: Vector2) -> int:
	rock_positions.append(p)
	var h := terrain_height(p.x, p.y)
	var sx := _rng.randf_range(0.5, 1.7)
	var sy := _rng.randf_range(0.28, 0.85)
	var sz := _rng.randf_range(0.5, 1.6)
	var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.25, 0.25))).scaled(Vector3(sx, sy, sz))
	mm.set_instance_transform(idx, Transform3D(basis, Vector3(p.x, h + sy * 0.18, p.y)))
	var g := _rng.randf_range(0.30, 0.44)
	var col := Color(g, g * 1.02, g * 0.92)
	if _rng.randf() < 0.45:
		col = col.lerp(Color(0.22, 0.33, 0.16), 0.55)
	mm.set_instance_color(idx, col)
	return idx + 1


# ---------------------------------------------------------------- 遗迹

func _build_ruins() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.86, 0.86, 0.80)
	stone_mat.vertex_color_use_as_albedo = true
	stone_mat.roughness = 1.0
	stone_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	# 立柱（圆柱）MultiMesh
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.48
	pillar_mesh.bottom_radius = 0.58
	pillar_mesh.height = 1.0
	pillar_mesh.radial_segments = 8
	pillar_mesh.rings = 2
	var pillar_mm := MultiMesh.new()
	pillar_mm.transform_format = MultiMesh.TRANSFORM_3D
	pillar_mm.use_colors = true
	pillar_mm.mesh = pillar_mesh
	var pillar_data := [
		[Vector3(-3.6, 0.0, -14.8), 3.6, 0.05],
		[Vector3(2.4, 0.0, -15.8), 2.2, -0.08],
		[Vector3(4.8, 0.0, -11.6), 4.1, 0.12],
		[Vector3(-6.0, 0.0, -11.2), 1.2, 0.20],
	]
	pillar_mm.instance_count = pillar_data.size()
	for i in range(pillar_data.size()):
		var entry: Array = pillar_data[i]
		var pos: Vector3 = entry[0]
		var ph: float = entry[1]
		var tilt: float = entry[2]
		var h := terrain_height(pos.x, pos.z)
		obstacle_circles.append({"pos": Vector2(pos.x, pos.z), "radius": 0.78, "height": ph})
		var basis := Basis.from_euler(Vector3(tilt, _rng.randf_range(0.0, TAU), tilt * 0.6)).scaled(Vector3(1.0, ph, 1.0))
		pillar_mm.set_instance_transform(i, Transform3D(basis, Vector3(pos.x, h + ph * 0.5, pos.z)))
		pillar_mm.set_instance_color(i, Color(0.55, 0.54, 0.47).lerp(Color(0.38, 0.44, 0.30), _rng.randf() * 0.7))
	var pillar_mmi := MultiMeshInstance3D.new()
	pillar_mmi.name = "RuinPillars"
	pillar_mmi.multimesh = pillar_mm
	pillar_mmi.material_override = stone_mat
	pillar_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(pillar_mmi)

	# 拱门 + 倒塌石块（单位 box 的 MultiMesh）
	var block_mesh := BoxMesh.new()
	block_mesh.size = Vector3.ONE
	var block_mm := MultiMesh.new()
	block_mm.transform_format = MultiMesh.TRANSFORM_3D
	block_mm.use_colors = true
	block_mm.mesh = block_mesh
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var arch_center := Vector3(-0.7, 0.0, -17.3)
	var base_y := terrain_height(arch_center.x, arch_center.z) + 3.7
	for side: int in [-1, 1]:
		var px: float = arch_center.x + side * 1.75
		var h := terrain_height(px, arch_center.z)
		xforms.append(Transform3D(Basis.from_scale(Vector3(0.8, 3.9, 0.95)), Vector3(px, h + 1.95, arch_center.z)))
		colors.append(Color(0.55, 0.54, 0.47))
	for i in range(7):
		var a := PI * (float(i) + 0.5) / 7.0
		var r := 1.85
		var pos := Vector3(arch_center.x + cos(a) * r, base_y + sin(a) * r * 0.85, arch_center.z)
		var basis := Basis.from_euler(Vector3(0.0, 0.0, a - PI * 0.5)).scaled(Vector3(0.62, 0.42, 0.95))
		xforms.append(Transform3D(basis, pos))
		colors.append(Color(0.58, 0.57, 0.50).lerp(Color(0.42, 0.48, 0.33), _rng.randf() * 0.4))
	for i in range(8):
		var p := RUIN_CENTER + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-3.0, 6.0))
		var h := terrain_height(p.x, p.y)
		var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.25, 0.25))).scaled(Vector3(_rng.randf_range(0.8, 1.8), _rng.randf_range(0.4, 0.75), _rng.randf_range(0.7, 1.5)))
		xforms.append(Transform3D(basis, Vector3(p.x, h + 0.25, p.y)))
		colors.append(Color(0.52, 0.51, 0.44).lerp(Color(0.36, 0.42, 0.28), _rng.randf() * 0.6))
	block_mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		block_mm.set_instance_transform(i, xforms[i])
		block_mm.set_instance_color(i, colors[i])
	var block_mmi := MultiMeshInstance3D.new()
	block_mmi.name = "RuinBlocks"
	block_mmi.multimesh = block_mm
	block_mmi.material_override = stone_mat
	block_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(block_mmi)


# ---------------------------------------------------------------- 踏石

func _build_stones() -> void:
	var stone_mesh := CylinderMesh.new()
	stone_mesh.top_radius = 0.5
	stone_mesh.bottom_radius = 0.55
	stone_mesh.height = 0.12
	stone_mesh.radial_segments = 7
	stone_mesh.rings = 1
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.80, 0.80, 0.74)
	stone_mat.vertex_color_use_as_albedo = true
	stone_mat.roughness = 1.0
	stone_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = stone_mesh
	mm.instance_count = 15
	for i in range(mm.instance_count):
		var z := 23.0 - float(i) * 2.45
		var x := path_center_x(z) + _rng.randf_range(-0.55, 0.55)
		var h := terrain_height(x, z)
		var basis := Basis.from_euler(Vector3(0.0, _rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(_rng.randf_range(0.75, 1.25), 1.0, _rng.randf_range(0.7, 1.15)))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, h + 0.04, z)))
		mm.set_instance_color(i, Color(0.52, 0.53, 0.47).lerp(Color(0.34, 0.42, 0.29), _rng.randf() * 0.55))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "PathStones"
	mmi.multimesh = mm
	mmi.material_override = stone_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ---------------------------------------------------------------- 草

func _build_grass() -> void:
	grass_material = ShaderMaterial.new()
	grass_material.shader = load("res://shaders/grass.gdshader")
	var blade_mesh := _make_grass_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade_mesh
	mm.instance_count = GRASS_COUNT
	var placed := 0
	for i in range(26):
		if placed >= GRASS_COUNT:
			break
		var ang := TAU * float(i) / 26.0 + _rng.randf_range(-0.12, 0.12)
		var rad := _rng.randf_range(6.7, 7.5)
		var p := POOL_CENTER + Vector2(cos(ang), sin(ang)) * rad
		var h := terrain_height(p.x, p.y)
		var basis := Basis.from_euler(Vector3(0.0, _rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(1.15, _rng.randf_range(1.8, 2.7), 1.15))
		mm.set_instance_transform(placed, Transform3D(basis, Vector3(p.x, h, p.y)))
		mm.set_instance_color(placed, Color(0.48, 0.58, 0.28).lerp(Color(0.74, 0.70, 0.34), _rng.randf() * 0.5))
		placed += 1
	var clusters := 0
	while placed < GRASS_COUNT and clusters < 420:
		clusters += 1
		var center := Vector2(_rng.randf_range(-31.0, 31.0), _rng.randf_range(-31.0, 31.0))
		var center_pool := Vector2(center.x - POOL_CENTER.x, center.y - POOL_CENTER.y).length()
		if center_pool < POOL_RADIUS - 0.2:
			continue
		if absf(center.x - path_center_x(center.y)) < 1.0 and _rng.randf() < 0.85:
			continue
		var blades := _rng.randi_range(5, 10)
		for b in range(blades):
			if placed >= GRASS_COUNT:
				break
			var p := center + Vector2(_rng.randf_range(-0.9, 0.9), _rng.randf_range(-0.9, 0.9))
			var pool_d := Vector2(p.x - POOL_CENTER.x, p.y - POOL_CENTER.y).length()
			if pool_d < POOL_RADIUS - 0.4:
				continue
			var h := terrain_height(p.x, p.y)
			var s := _rng.randf_range(0.7, 1.25)
			var basis := Basis.from_euler(Vector3(0.0, _rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(s * 1.25, _rng.randf_range(0.8, 1.5), s * 1.25))
			mm.set_instance_transform(placed, Transform3D(basis, Vector3(p.x, h, p.y)))
			var col := Color(0.42, 0.56, 0.30).lerp(Color(0.78, 0.74, 0.36), _rng.randf() * 0.5)
			mm.set_instance_color(placed, col)
			placed += 1
	grass_placed = placed
	mm.visible_instance_count = placed
	grass_multimesh = MultiMeshInstance3D.new()
	grass_multimesh.name = "Grass"
	grass_multimesh.multimesh = mm
	grass_multimesh.material_override = grass_material
	grass_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass_multimesh)


func _make_grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade_count := 7
	for i in range(blade_count):
		var ang := TAU * float(i) / float(blade_count) + 0.37 * sin(float(i) * 2.3)
		var height := 0.46 + 0.24 * absf(sin(float(i) * 1.7 + 0.4))
		var lean := 0.10 + 0.13 * absf(cos(float(i) * 2.1))
		var width := 0.032 + 0.016 * absf(sin(float(i) * 3.1))
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var side := Vector3(-sin(ang), 0.0, cos(ang))
		var base_l := -side * width
		var base_r := side * width
		var tip := dir * lean + Vector3(0.0, height, 0.0)
		var n := (dir * 0.25 + Vector3(0.0, 1.0, 0.0)).normalized()
		st.set_normal(n)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(base_l)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(base_r)
		st.set_uv(Vector2(0.5, 1.0))
		st.add_vertex(tip)
	return st.commit()


# ---------------------------------------------------------------- 灯笼 / 精灵

func _build_lanterns() -> void:
	lantern_orb_material = StandardMaterial3D.new()
	lantern_orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lantern_orb_material.albedo_color = Color(1.35, 0.95, 0.52)
	lantern_glow_material = _make_glow_material(Color(1.0, 0.66, 0.28, 0.55), 1.0)
	lantern_pool_material = _make_pool_material(Color(1.0, 0.62, 0.24, 0.30))

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.40, 0.39, 0.34)
	stone_mat.roughness = 1.0
	stone_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.82, 0.22, 0.82)
	var column_mesh := CylinderMesh.new()
	column_mesh.top_radius = 0.16
	column_mesh.bottom_radius = 0.23
	column_mesh.height = 1.25
	column_mesh.radial_segments = 7
	column_mesh.rings = 1
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.03
	cap_mesh.bottom_radius = 0.42
	cap_mesh.height = 0.34
	cap_mesh.radial_segments = 7
	cap_mesh.rings = 1
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.16
	orb_mesh.height = 0.32
	orb_mesh.radial_segments = 10
	orb_mesh.rings = 6
	var glow_quad := QuadMesh.new()
	glow_quad.size = Vector2(1.8, 1.8)
	var pool_quad := PlaneMesh.new()
	pool_quad.size = Vector2(4.2, 4.2)

	for i in range(LANTERN_POSITIONS.size()):
		var p: Vector2 = LANTERN_POSITIONS[i]
		var h := terrain_height(p.x, p.y)
		obstacle_circles.append({"pos": p, "radius": 0.58, "height": 1.8})
		var node := Node3D.new()
		node.name = "Lantern%d" % i
		node.position = Vector3(p.x, h, p.y)
		node.rotation.y = _rng.randf_range(0.0, TAU)
		add_child(node)
		var base := MeshInstance3D.new()
		base.mesh = base_mesh
		base.material_override = stone_mat
		base.position.y = 0.11
		node.add_child(base)
		var column := MeshInstance3D.new()
		column.mesh = column_mesh
		column.material_override = stone_mat
		column.position.y = 0.85
		node.add_child(column)
		var cap := MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.material_override = stone_mat
		cap.position.y = 1.7
		node.add_child(cap)
		var orb := MeshInstance3D.new()
		orb.mesh = orb_mesh
		orb.material_override = lantern_orb_material
		orb.position.y = 1.44
		node.add_child(orb)
		lantern_orb_positions.append(Vector3(p.x, h + 1.44, p.y))
		var glow := MeshInstance3D.new()
		glow.mesh = glow_quad
		glow.material_override = lantern_glow_material
		glow.position.y = 1.44
		node.add_child(glow)
		var pool := MeshInstance3D.new()
		pool.mesh = pool_quad
		pool.material_override = lantern_pool_material
		pool.position.y = 0.06
		node.add_child(pool)


func _build_wisp() -> void:
	wisp_node = Node3D.new()
	wisp_node.name = "Wisp"
	_wisp_base_y = WATER_LEVEL + 1.35
	wisp_node.position = Vector3(POOL_CENTER.x, _wisp_base_y, POOL_CENTER.y)
	add_child(wisp_node)

	wisp_material = StandardMaterial3D.new()
	wisp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wisp_material.albedo_color = Color(1.5, 2.3, 2.5)
	var orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.13
	orb_mesh.height = 0.26
	orb_mesh.radial_segments = 10
	orb_mesh.rings = 6
	orb.mesh = orb_mesh
	orb.material_override = wisp_material
	wisp_node.add_child(orb)

	wisp_halo_material = _make_glow_material(Color(0.62, 0.92, 1.0, 0.55), 1.0)
	wisp_halo = MeshInstance3D.new()
	var halo_quad := QuadMesh.new()
	halo_quad.size = Vector2(2.1, 2.1)
	wisp_halo.mesh = halo_quad
	wisp_halo.material_override = wisp_halo_material
	wisp_node.add_child(wisp_halo)


var _wisp_base_y := 0.0


func _make_glow_material(color: Color, scale: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _glow_texture
	mat.albedo_color = color
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


func _make_pool_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = _pool_texture
	mat.albedo_color = color
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


# ---------------------------------------------------------------- 程序化贴图

func _make_mist_texture(size: int, seed_value: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x, y).distance_to(center) / (size * 0.5)
			var edge := 1.0 - smoothstep(0.35, 1.0, d)
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var n2 := noise.get_noise_2d(x * 2.7 + 40.0, y * 2.7 + 13.0) * 0.5 + 0.5
			var a := edge * (0.35 + 0.65 * smoothstep(0.35, 0.8, n * 0.65 + n2 * 0.35))
			a = pow(a, 1.6)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _make_radial_texture(size: int, hardness: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x, y).distance_to(center) / (size * 0.5)
			var a := pow(clampf(1.0 - d, 0.0, 1.0), 2.2 + hardness)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _make_pool_texture(size: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 99
	noise.frequency = 0.08
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x, y).distance_to(center) / (size * 0.5)
			var ring := 0.55 + 0.45 * sin(d * 18.0 + noise.get_noise_2d(x, y) * 3.0)
			var a := pow(clampf(1.0 - d, 0.0, 1.0), 2.6) * ring
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _make_leaf_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	for y in range(size):
		for x in range(size):
			var p := Vector2(x, y)
			var d := p.distance_to(center) / (size * 0.5)
			var angle := atan2(p.y - center.y, p.x - center.x)
			var leaf := 1.0 - smoothstep(0.32, 0.48, d + absf(cos(angle * 1.0)) * 0.06)
			var a := clampf(leaf, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _make_detail_texture(size: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 313
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in range(size):
		for x in range(size):
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var v := lerpf(0.68, 1.0, n)
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _make_patch_texture(size: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 57
	noise.frequency = 0.016
	noise.fractal_octaves = 4
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var u := float(x) / float(size)
			var v := float(y) / float(size)
			var n00 := noise.get_noise_2d(x, y)
			var n10 := noise.get_noise_2d(x - size, y)
			var n01 := noise.get_noise_2d(x, y - size)
			var n11 := noise.get_noise_2d(x - size, y - size)
			var n := n00 * (1.0 - u) * (1.0 - v) + n10 * u * (1.0 - v) + n01 * (1.0 - u) * v + n11 * u * v
			var n2 := noise.get_noise_2d(x * 3.1 + 17.0, y * 3.1 + 31.0)
			var n2w := n2 * 0.6 + noise.get_noise_2d(x * 3.1 + 17.0 - size, y * 3.1 + 31.0) * 0.4
			var a := smoothstep(-0.35, 0.28, n * 0.72 + n2w * 0.28)
			a = pow(a, 1.25)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func make_patch_texture() -> ImageTexture:
	return _make_patch_texture(256)


func make_particle_texture() -> ImageTexture:
	return _glow_texture


func make_leaf_particle_texture() -> ImageTexture:
	return _leaf_texture


func pool_center() -> Vector3:
	return Vector3(POOL_CENTER.x, WATER_LEVEL, POOL_CENTER.y)


func pool_radius() -> float:
	return POOL_RADIUS


func walk_boundary_radius() -> float:
	return WORLD_SIZE * 0.30


func ruin_center() -> Vector3:
	return Vector3(RUIN_CENTER.x, terrain_height(RUIN_CENTER.x, RUIN_CENTER.y), RUIN_CENTER.y)
