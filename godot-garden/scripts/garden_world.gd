class_name GardenWorld
extends Node3D

# 程序化废墟花园：石径、水池、拱门与石柱、树、十字草叶、灯柱、小女孩、
# 萤火、光束、云影与水面。全部用 Godot 原语 + 自定义 shader，无外部美术。

const PATH_POINTS := [
	Vector3(11, 0, 11),
	Vector3(5, 0, 9),
	Vector3(-1, 0, 8),
	Vector3(-8, 0, 6),
	Vector3(-11, 0, 1),
	Vector3(-9, 0, -5),
	Vector3(-4, 0, -9),
	Vector3(3, 0, -10),
	Vector3(9, 0, -6),
	Vector3(12, 0, 0),
]
const POND_CENTER := Vector3(-5, 0, 3)
const POND_RADIUS := 4.2
const CIRCLE_CENTER := Vector3(8, 0, 5)
const HERO_START := Vector3(2.0, 0, 4.2)
const QUEST_GIVER := Vector3(-1.0, 0, 1.8)
const QUEST_RETURN := Vector3(0.9, 0, 4.2)
const MONSTER_SPAWNS := [
	Vector3(6.2, 0, 6.8),
	Vector3(9.2, 0, 5.6),
	Vector3(7.4, 0, 2.6),
]
# 巡逻路线：手工按水池/石圈/拱柱/石像安全距离校验，闭环；提灯路线内收 6% 远离路灯。
const PATROL_ROUTES := [
	{
		"role": "lantern",
		"waypoints": [
			Vector3(1.58, 0, 3.0),
			Vector3(-0.35, 0, 7.65),
			Vector3(-5.0, 0, 9.58),
			Vector3(-9.65, 0, 7.65),
			Vector3(-11.58, 0, 3.0),
			Vector3(-9.65, 0, -1.65),
			Vector3(-5.0, 0, -3.58),
			Vector3(-0.35, 0, -1.65),
		],
	},
	{
		"role": "sweeper",
		"waypoints": [
			Vector3(11.95, 0, 6.44),
			Vector3(7.85, 0, 9.2),
			Vector3(3.96, 0, 6.16),
			Vector3(5.65, 0, 1.52),
			Vector3(10.59, 0, 1.69),
		],
	},
	{
		"role": "fox",
		"waypoints": [
			Vector3(0.5, 0, -8.0),
			Vector3(4.5, 0, -8.5),
			Vector3(7.6, 0, -8.0),
			Vector3(7.0, 0, -5.5),
			Vector3(2.5, 0, -5.0),
		],
	},
]
const NAV_MIN := -18.0
const NAV_CELL := 1.0
const NAV_SIZE := 36

var camera: Camera3D
var path_curve: Curve3D
var path_length := 0.0
var lamps: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var fireflies: GPUParticles3D
var firefly_mat: StandardMaterial3D
var water_mat: ShaderMaterial
var foam_mat: ShaderMaterial
var cloud_mat: ShaderMaterial
var mist_mat: ShaderMaterial
var octopus: GardenOctopus
var hero: GardenHero
var monsters: Array[GardenMonster] = []
var patrols: Array[GardenPatrol] = []
var quest: GardenQuest
var nav_grid: AStarGrid2D
var nav_obstacles: Array[Dictionary] = []
var _quest_marker: Label3D

var _rng := RandomNumberGenerator.new()
var _stone: Array[ShaderMaterial] = []
var _moss: StandardMaterial3D
var _dirt: StandardMaterial3D
var _wood: StandardMaterial3D
var _iron: StandardMaterial3D
var _leaves: Array[ShaderMaterial] = []
var _glass: StandardMaterial3D
var _halo_tex: ImageTexture
var _halo_core_tex: ImageTexture
var _shadow_tex: ImageTexture
var _water_perimeter: Array[Vector2] = []
var _path_samples: Array[Vector3] = []
var _reflections: Array[Dictionary] = []

func build(camera_ref: Camera3D) -> void:
	camera = camera_ref
	_rng.seed = 20261029
	_make_materials()
	_make_textures()
	_make_path_curve()
	_build_ground()
	_build_path()
	_build_pond()
	_build_ruins()
	_build_trees()
	_build_grass()
	_build_flowers()
	_build_bushes()
	_build_leaves()
	_build_lamps()
	_build_octopus()
	_build_nav_grid()
	_build_gameplay()
	_build_patrols()
	_build_fireflies()
	_build_beams()
	_build_clouds()
	_build_mist()

# ---------------------------------------------------------------- 材质与贴图

func _mat(color: Color, roughness := 1.0, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _make_materials() -> void:
	_stone = [
		_stone_material(Color(0.55, 0.52, 0.45), Color(0.3, 0.29, 0.26)),
		_stone_material(Color(0.46, 0.43, 0.37), Color(0.25, 0.24, 0.22)),
		_stone_material(Color(0.38, 0.36, 0.32), Color(0.2, 0.2, 0.18)),
	]
	_moss = _mat(Color(0.2, 0.3, 0.14))
	_dirt = _mat(Color(0.28, 0.23, 0.17))
	_dirt.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wood = _mat(Color(0.25, 0.17, 0.11))
	_iron = _mat(Color(0.045, 0.05, 0.05), 0.45, 0.55)
	_leaves = [
		_foliage_material(Color(0.14, 0.25, 0.11)),
		_foliage_material(Color(0.2, 0.34, 0.14)),
		_foliage_material(Color(0.28, 0.43, 0.18)),
	]
	_glass = _mat(Color(0.8, 0.64, 0.38), 0.35)
	_glass.emission_enabled = true
	_glass.emission = Color(1.0, 0.72, 0.36)
	_glass.emission_energy_multiplier = 0.05

	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	foam_mat = ShaderMaterial.new()
	foam_mat.shader = load("res://shaders/foam.gdshader")
	cloud_mat = ShaderMaterial.new()
	cloud_mat.shader = load("res://shaders/cloud_shadow.gdshader")
	mist_mat = ShaderMaterial.new()
	mist_mat.shader = load("res://shaders/mist.gdshader")

func _stone_material(base: Color, dark: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/stone.gdshader")
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("dark_color", dark)
	material.set_shader_parameter("pond_center", POND_CENTER)
	material.set_shader_parameter("pond_radius", POND_RADIUS)
	return material

func _foliage_material(base: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/foliage.gdshader")
	material.set_shader_parameter("base_color", base)
	return material

func _make_textures() -> void:
	_halo_tex = _radial_texture(64, Color(1, 1, 1), 2.2)
	_halo_core_tex = _radial_texture(64, Color(1, 1, 1), 0.9)
	_shadow_tex = _radial_texture(64, Color(0, 0, 0), 1.3)

func _radial_texture(size: int, color: Color, power: float) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size - 1, size - 1) * 0.5
	var radius := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center) / radius
			var a := pow(maxf(0.0, 1.0 - d), power)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(image)

func _make_path_curve() -> void:
	path_curve = Curve3D.new()
	for point in PATH_POINTS:
		path_curve.add_point(point)
	path_curve.add_point(PATH_POINTS[0])
	path_curve.bake_interval = 0.2
	path_length = path_curve.get_baked_length()
	for index in 180:
		_path_samples.append(path_curve.sample_baked(float(index) / 180.0 * path_length))

# ---------------------------------------------------------------- 地面 / 石径

func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://shaders/ground.gdshader")
	mesh.material_override = ground_mat
	mesh.position = Vector3(0, -0.03, 0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

func _build_path() -> void:
	_build_path_ribbon()
	var s := 0.0
	while s < path_length:
		var pos := path_curve.sample_baked(s)
		var tangent := _path_tangent(s)
		var side := Vector3(tangent.z, 0, -tangent.x).normalized()
		var yaw := atan2(tangent.x, tangent.z)
		var offset := _rng.randf_range(-0.28, 0.28)
		var jitter := Vector3(_rng.randf_range(-0.1, 0.1), 0, _rng.randf_range(-0.1, 0.1))
		var slab_pos := pos + side * offset + jitter + Vector3(0, 0.075, 0)
		var slab_size := Vector3(_rng.randf_range(1.0, 1.45), 0.07, _rng.randf_range(0.55, 0.8))
		var material: Material = _stone[_rng.randi_range(0, _stone.size() - 1)]
		var slab := _add_cylinder(self, slab_pos, 0.46, 0.56, slab_size.y, material, 6 + _rng.randi_range(0, 2))
		slab.scale = Vector3(slab_size.x, 1.0, slab_size.z)
		slab.rotation.y = yaw + _rng.randf_range(-0.14, 0.14)
		slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		s += _rng.randf_range(0.55, 0.78)
	# 路边碎石
	for index in 46:
		var t := _rng.randf_range(0.0, path_length)
		var p := path_curve.sample_baked(t)
		var tangent := _path_tangent(t)
		var side := Vector3(tangent.z, 0, -tangent.x).normalized()
		var off := _rng.randf_range(1.3, 2.1) * (1.0 if _rng.randf() < 0.5 else -1.0)
		_add_sphere(self, p + side * off + Vector3(0, 0.06, 0),
			_rng.randf_range(0.05, 0.16), _stone[_rng.randi_range(0, 2)], Vector3(1.0, 0.55, 1.0))

func _build_path_ribbon() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 110
	var width := 1.8
	for index in steps:
		var t0 := float(index) / steps * path_length
		var t1 := float(index + 1) / steps * path_length
		var p0 := path_curve.sample_baked(t0)
		var p1 := path_curve.sample_baked(t1)
		var tan0 := _path_tangent(t0)
		var tan1 := _path_tangent(t1)
		var side0 := Vector3(tan0.z, 0, -tan0.x).normalized() * width * 0.5
		var side1 := Vector3(tan1.z, 0, -tan1.x).normalized() * width * 0.5
		var a := p0 + side0 + Vector3(0, 0.02, 0)
		var b := p0 - side0 + Vector3(0, 0.02, 0)
		var c := p1 + side1 + Vector3(0, 0.02, 0)
		var d := p1 - side1 + Vector3(0, 0.02, 0)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
		st.add_vertex(b)
		st.add_vertex(d)
		st.add_vertex(c)
	var mesh := st.commit()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _dirt
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _path_tangent(s: float) -> Vector3:
	var before := path_curve.sample_baked(fposmod(s - 0.2, path_length))
	var after := path_curve.sample_baked(fposmod(s + 0.2, path_length))
	return (after - before).normalized()

# ---------------------------------------------------------------- 水池

func _build_pond() -> void:
	_add_nav_obstacle(Vector2(POND_CENTER.x, POND_CENTER.z), POND_RADIUS + 0.9)
	for index in 48:
		var angle := TAU * float(index) / 48.0
		var radius := POND_RADIUS + sin(angle * 3.0 + 1.2) * 0.35 + _rng.randf_range(-0.12, 0.12)
		_water_perimeter.append(Vector2(cos(angle) * radius, sin(angle) * radius))

	# 水面
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0, 0.055, 0)
	for index in _water_perimeter.size():
		var a := _water_perimeter[index]
		var b := _water_perimeter[(index + 1) % _water_perimeter.size()]
		st.add_vertex(center)
		st.add_vertex(Vector3(a.x, 0.055, a.y))
		st.add_vertex(Vector3(b.x, 0.055, b.y))
	var water := MeshInstance3D.new()
	water.mesh = st.commit()
	water.material_override = water_mat
	water.position = POND_CENTER
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	# 浅色岸线
	var foam := SurfaceTool.new()
	foam.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in _water_perimeter.size():
		var a := _water_perimeter[index]
		var b := _water_perimeter[(index + 1) % _water_perimeter.size()]
		var a0 := a * 0.965
		var b0 := b * 0.965
		var a1 := a * 1.07
		var b1 := b * 1.07
		foam.add_vertex(Vector3(a0.x, 0.07, a0.y))
		foam.add_vertex(Vector3(a1.x, 0.07, a1.y))
		foam.add_vertex(Vector3(b0.x, 0.07, b0.y))
		foam.add_vertex(Vector3(b0.x, 0.07, b0.y))
		foam.add_vertex(Vector3(a1.x, 0.07, a1.y))
		foam.add_vertex(Vector3(b1.x, 0.07, b1.y))
	var foam_mesh := MeshInstance3D.new()
	foam_mesh.mesh = foam.commit()
	foam_mesh.material_override = foam_mat
	foam_mesh.position = POND_CENTER
	foam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foam_mesh)

	# 岸边石块
	for index in 26:
		var angle := TAU * float(index) / 26.0 + _rng.randf_range(-0.05, 0.05)
		var radius := POND_RADIUS + _rng.randf_range(0.15, 0.85)
		var pos := POND_CENTER + Vector3(cos(angle) * radius, 0.08, sin(angle) * radius)
		_add_rock(pos, _rng.randf_range(0.22, 0.62), _rng.randf() < 0.35)
	# 水中石
	for offset in [Vector3(-1.8, 0, -1.0), Vector3(0.9, 0, 1.6), Vector3(-2.8, 0, 1.2)]:
		_add_rock(POND_CENTER + offset + Vector3(0, 0.16, 0), _rng.randf_range(0.45, 0.8), false)
	_add_lamp_reflection(POND_CENTER + Vector3(1.5, 0.075, 2.9), -0.4)
	_add_lamp_reflection(POND_CENTER + Vector3(-2.6, 0.075, -1.4), 0.8)

	# 睡莲叶 + 岸边芦苇
	for offset in [Vector3(-1.6, 0, -1.8), Vector3(0.7, 0, -2.3), Vector3(-2.4, 0, 1.1), Vector3(1.9, 0, 1.5)]:
		var pad := _add_cylinder(self, POND_CENTER + offset + Vector3(0, 0.075, 0),
			_rng.randf_range(0.32, 0.52), _rng.randf_range(0.32, 0.52), 0.012, _leaves[1], 10)
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_sphere(self, POND_CENTER + offset + Vector3(0, 0.11, 0), 0.07, _mat(Color(0.9, 0.85, 0.68)))
	for index in 6:
		var angle := TAU * float(index) / 6.0 + 0.4
		var shore := POND_CENTER + Vector3(cos(angle) * (POND_RADIUS + 0.35), 0.1, sin(angle) * (POND_RADIUS + 0.35))
		if _distance_to_path(shore.x, shore.z) < 1.3:
			continue
		_add_cylinder(self, shore + Vector3(0, 0.45, 0), 0.018, 0.03, 0.9, _moss, 5)
		_add_sphere(self, shore + Vector3(0, 0.9, 0), 0.06, _mat(Color(0.45, 0.3, 0.16)))

# ---------------------------------------------------------------- 废墟

func _build_ruins() -> void:
	_create_arch(Vector3(4.5, 0, -3.0), deg_to_rad(24.0), 2.2, 2.5, 8, 9)
	_create_arch(Vector3(-2.2, 0, -7.0), deg_to_rad(-38.0), 1.5, 1.2, 9, 12, 1.5)
	_create_column(Vector3(8.0, 0, 1.6), 3.2, false)
	_create_column(Vector3(7.4, 0, -4.4), 1.1, true)
	_create_column(Vector3(-2.6, 0, 6.4), 2.3, false)
	_create_column(Vector3(-8.0, 0, -1.8), 0.7, true)
	_create_column(Vector3(1.4, 0, -10.2), 2.7, false)
	_create_wall(Vector3(10.4, 0, -7.2), 4.0, 0.9, deg_to_rad(-14.0))
	_create_wall(Vector3(-10.2, 0, 7.4), 3.2, 0.72, deg_to_rad(38.0))
	_create_wall(Vector3(6.4, 0, 9.4), 2.6, 0.6, deg_to_rad(8.0))
	_create_wall(Vector3(14.2, 0, 8.5), 2.4, 0.55, deg_to_rad(72.0))
	_create_wall(Vector3(-6.8, 0, -10.4), 2.2, 0.5, deg_to_rad(16.0))
	_create_stone_circle()
	_create_statue(Vector3(-1.0, 0, 1.8))
	for index in 34:
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(0.0, 8.0)
		var pos := Vector3(4.0 + cos(angle) * radius, 0.0, -3.0 + sin(angle) * radius)
		if _distance_to_path(pos.x, pos.z) < 1.5 or _pond_distance(pos.x, pos.z) < POND_RADIUS + 0.8:
			continue
		_add_rock(pos + Vector3(0, 0.05, 0), _rng.randf_range(0.12, 0.42), _rng.randf() < 0.3)

func _add_lamp_reflection(pos: Vector3, yaw: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = _halo_tex
	material.albedo_color = Color(1.0, 0.62, 0.3, 0.0)
	material.disable_receive_shadows = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 3.8)
	quad.material = material
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = yaw
	add_child(pivot)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.rotation.x = -PI * 0.5
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mesh)
	_reflections.append({"mesh": mesh, "material": material, "phase": yaw * 3.0})

func _create_arch(pos: Vector3, yaw: float, radius: float, pillar_height: float,
		broken_from: int, broken_to: int, pillar_scale := 1.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	for side in [-1.0, 1.0]:
		var pillar_world := root.to_global(Vector3(side * radius, 0, 0))
		_add_nav_obstacle(Vector2(pillar_world.x, pillar_world.z), 0.75)
	for side in [-1.0, 1.0]:
		var h: float = pillar_height * (pillar_scale if side > 0.0 else 1.0)
		_add_box(root, Vector3(side * radius, 0.12, 0), Vector3(0.95, 0.24, 0.95), _stone[2])
		_add_cylinder(root, Vector3(side * radius, h * 0.5 + 0.2, 0), 0.27, 0.34, h, _stone[1])
		_add_box(root, Vector3(side * radius, h + 0.28, 0), Vector3(0.8, 0.18, 0.8), _stone[0])
		if _rng.randf() < 0.5:
			_add_box(root, Vector3(side * radius, h + 0.38, 0), Vector3(0.5, 0.04, 0.5), _moss)
	for index in 13:
		if index >= broken_from and index <= broken_to:
			continue
		var angle := PI * float(index) / 12.0
		var point := Vector3(cos(angle) * radius, pillar_height + 0.35 + sin(angle) * radius, 0)
		var segment := _add_box(root, point, Vector3(0.46, 0.34, 0.56), _stone[index % 3])
		segment.rotation.z = angle + PI * 0.5
		if _rng.randf() < 0.22:
			var moss := _add_box(segment, Vector3(0, 0.19, 0), Vector3(0.3, 0.02, 0.4), _moss)
			moss.rotation.z = 0.0
	# 垂藤
	for vine_index in 2:
		var vine_x := -radius * 0.45 if vine_index == 0 else radius * 0.3
		var vine_y := pillar_height + radius * 0.55
		_add_box(root, Vector3(vine_x, vine_y - 0.5, 0.22), Vector3(0.05, 1.0, 0.05), _moss)
		_add_sphere(root, Vector3(vine_x, vine_y - 1.05, 0.22), 0.12, _leaves[1])

func _create_column(pos: Vector3, height: float, broken: bool) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_add_nav_obstacle(Vector2(pos.x, pos.z), 0.7)
	_add_box(root, Vector3(0, 0.12, 0), Vector3(0.82, 0.24, 0.82), _stone[2])
	_add_cylinder(root, Vector3(0, height * 0.5 + 0.2, 0), 0.26, 0.31, height, _stone[1])
	if broken:
		var chunk := _add_box(root, Vector3(0, height + 0.24, 0), Vector3(0.45, 0.18, 0.45), _stone[0])
		chunk.rotation = Vector3(_rng.randf_range(-0.2, 0.2), 0.0, _rng.randf_range(-0.2, 0.2))
	else:
		_add_box(root, Vector3(0, height + 0.3, 0), Vector3(0.72, 0.18, 0.72), _stone[0])
	if _rng.randf() < 0.6:
		_add_box(root, Vector3(0.02, height + 0.4, 0), Vector3(0.3, 0.035, 0.3), _moss)

func _create_wall(pos: Vector3, length: float, height: float, yaw: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	for t in [-0.35, 0.0, 0.35]:
		var wall_world := root.to_global(Vector3(t * length, 0, 0))
		_add_nav_obstacle(Vector2(wall_world.x, wall_world.z), 0.55)
	var count := int(ceil(length / 1.4))
	for index in count:
		if _rng.randf() < 0.18:
			continue
		var x := -length * 0.5 + (index + 0.5) * (length / count)
		var h := height * _rng.randf_range(0.75, 1.0)
		_add_box(root, Vector3(x, h * 0.5, 0), Vector3(length / count * 1.02, h, 0.48), _stone[index % 3])
		if _rng.randf() < 0.5:
			_add_box(root, Vector3(x, h + 0.015, 0), Vector3(length / count * 0.7, 0.03, 0.3), _moss)

func _create_stone_circle() -> void:
	var root := Node3D.new()
	root.position = CIRCLE_CENTER
	add_child(root)
	var disc := _add_cylinder(root, Vector3(0, 0.02, 0), 2.25, 2.25, 0.04, _stone[2], 24)
	disc.material_override = _mat(Color(0.2, 0.2, 0.17))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index in 14:
		if _rng.randf() < 0.12:
			continue
		var angle := TAU * float(index) / 14.0
		var p := Vector3(cos(angle) * 2.35, 0.09, sin(angle) * 2.35)
		var stone := _add_box(root, p, Vector3(0.92, 0.16, 0.48), _stone[index % 3])
		stone.rotation.y = -angle + PI * 0.5
	_add_box(root, Vector3(0, 0.24, 0), Vector3(0.75, 0.4, 0.75), _stone[0])

func _create_statue(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_add_nav_obstacle(Vector2(pos.x, pos.z), 1.2)
	_add_box(root, Vector3(0, 0.28, 0), Vector3(1.0, 0.56, 1.0), _stone[1])
	_add_cylinder(root, Vector3(0, 1.1, 0), 0.2, 0.3, 1.2, _stone[0])
	_add_sphere(root, Vector3(0, 1.85, 0), 0.24, _stone[0])
	var head := _add_sphere(root, Vector3(0.04, 1.96, 0), 0.18, _stone[0])
	head.rotation.z = 0.3
	_add_box(root, Vector3(0, 0.58, 0), Vector3(1.1, 0.06, 1.1), _moss)

# ---------------------------------------------------------------- 树木 / 草

func _build_trees() -> void:
	var positions := [
		Vector3(-13.5, 0, -6.0), Vector3(-12.2, 0, 7.5), Vector3(-7.0, 0, 12.5),
		Vector3(2.0, 0, 13.5), Vector3(10.5, 0, 11.0), Vector3(14.0, 0, 3.0),
		Vector3(13.2, 0, -8.0), Vector3(5.0, 0, -13.5), Vector3(-5.0, 0, -13.5),
		Vector3(-14.0, 0, 1.0),
	]
	for index in positions.size():
		_create_tree(positions[index], _rng.randf_range(0.85, 1.25), index)

func _create_tree(pos: Vector3, tree_scale: float, variant: int) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * tree_scale
	add_child(root)
	_add_nav_obstacle(Vector2(pos.x, pos.z), 1.4)
	_add_cylinder(root, Vector3(0, 1.6, 0), 0.2, 0.34, 3.2, _wood, 8)
	var branch := _add_cylinder(root, Vector3(0.45, 3.0, 0.1), 0.08, 0.15, 1.8, _wood, 6)
	branch.rotation.z = -0.7
	var branch2 := _add_cylinder(root, Vector3(-0.35, 2.7, -0.2), 0.06, 0.13, 1.4, _wood, 6)
	branch2.rotation.z = 0.9
	var canopy_count := 8
	for index in canopy_count:
		var angle := TAU * float(index) / canopy_count + variant * 0.7
		var radius := _rng.randf_range(0.85, 1.55)
		var p := Vector3(cos(angle) * _rng.randf_range(0.4, 1.5), 3.1 + (index % 4) * 0.55, sin(angle) * _rng.randf_range(0.4, 1.5))
		var leaf := _add_sphere(root, p, radius, _leaves[(index + variant) % _leaves.size()])
		leaf.scale = Vector3(_rng.randf_range(0.9, 1.3), _rng.randf_range(0.65, 1.0), _rng.randf_range(0.9, 1.3))
		leaf.rotation.y = _rng.randf_range(0.0, TAU)
	var under := _add_sphere(root, Vector3(0, 2.9, 0), _rng.randf_range(1.3, 1.8), _leaves[variant % _leaves.size()])
	under.scale = Vector3(1.2, 0.55, 1.2)
	_add_sphere(root, Vector3(0, 5.1, 0), _rng.randf_range(1.1, 1.6), _leaves[(variant + 1) % _leaves.size()])
	for index in 5:
		var angle := TAU * float(index) / 5.0 + variant * 1.3
		var p := Vector3(cos(angle) * _rng.randf_range(1.2, 2.0), 3.4 + _rng.randf_range(0.0, 1.5), sin(angle) * _rng.randf_range(1.2, 2.0))
		var edge := _add_sphere(root, p, _rng.randf_range(0.5, 0.9), _leaves[(index + variant + 1) % _leaves.size()])
		edge.scale = Vector3(_rng.randf_range(0.9, 1.3), _rng.randf_range(0.7, 1.0), _rng.randf_range(0.9, 1.3))

func _build_grass() -> void:
	# 3 种草型：中草铺底、短草补缝、高草在边缘/水边做剪影。
	var medium := _grass_material(Color(0.06, 0.14, 0.045), Color(0.38, 0.56, 0.22), 0.09)
	var short := _grass_material(Color(0.04, 0.1, 0.035), Color(0.22, 0.38, 0.13), 0.055)
	var tall := _grass_material(Color(0.1, 0.16, 0.05), Color(0.5, 0.56, 0.26), 0.13)
	_build_grass_field(2800, 0.6, 1.1, medium)
	_build_grass_field(1600, 0.35, 0.65, short)
	_build_grass_field(700, 1.0, 1.5, tall)

func _grass_material(root_color: Color, tip_color: Color, wind: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/grass.gdshader")
	material.set_shader_parameter("root_color", root_color)
	material.set_shader_parameter("tip_color", tip_color)
	material.set_shader_parameter("wind", wind)
	return material

func _build_grass_field(count: int, min_scale: float, max_scale: float, material: Material) -> void:
	var blade_mesh := _make_grass_mesh()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = blade_mesh
	var transforms: Array[Transform3D] = []
	var customs: Array[Color] = []
	for index in count:
		var x := _rng.randf_range(-17.0, 17.0)
		var z := _rng.randf_range(-17.0, 17.0)
		if _pond_distance(x, z) < POND_RADIUS + 1.0:
			continue
		if Vector2(x - CIRCLE_CENTER.x, z - CIRCLE_CENTER.z).length() < 3.0:
			continue
		if _distance_to_path(x, z) < 1.9:
			continue
		if absf(x) > 16.5 or absf(z) > 16.5:
			continue
		var s := _rng.randf_range(min_scale, max_scale)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
		transforms.append(Transform3D(basis, Vector3(x, 0.0, z)))
		customs.append(Color(_rng.randf(), _rng.randf(), 0.0, 1.0))
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_custom_data(index, customs[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _make_grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := 0.16
	var height := 0.5
	# 交叉两片
	for plane in 2:
		var a := Vector3(-width, 0, 0)
		var b := Vector3(width, 0, 0)
		var c := Vector3(width, height, 0)
		var d := Vector3(-width, height, 0)
		if plane == 1:
			a = Vector3(0, 0, -width)
			b = Vector3(0, 0, width)
			c = Vector3(0, height, width)
			d = Vector3(0, height, -width)
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var verts := [a, b, c, a, c, d]
		var uvs_order := [uvs[0], uvs[1], uvs[2], uvs[0], uvs[2], uvs[3]]
		for index in 6:
			st.set_uv(uvs_order[index])
			st.add_vertex(verts[index])
	st.generate_normals()
	return st.commit()

func _build_flowers() -> void:
	_build_flower_field(Color(0.86, 0.88, 0.78), Color(0.92, 0.72, 0.28), 380)
	_build_flower_field(Color(0.45, 0.55, 0.9), Color(0.8, 0.85, 0.5), 160)

func _build_flower_field(petal: Color, center: Color, count: int) -> void:
	var mesh := _make_flower_mesh()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/flower.gdshader")
	material.set_shader_parameter("petal_color", petal)
	material.set_shader_parameter("center_color", center)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	var placed: Array[Transform3D] = []
	for index in count:
		var x := _rng.randf_range(-15.0, 15.0)
		var z := _rng.randf_range(-15.0, 15.0)
		if _pond_distance(x, z) < POND_RADIUS + 1.0 or _distance_to_path(x, z) < 1.6:
			continue
		if Vector2(x - CIRCLE_CENTER.x, z - CIRCLE_CENTER.z).length() < 3.0:
			continue
		var s := _rng.randf_range(0.8, 1.4)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
		placed.append(Transform3D(basis, Vector3(x, 0.06, z)))
	multimesh.instance_count = placed.size()
	for index in placed.size():
		multimesh.set_instance_transform(index, placed[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _make_flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := 0.11
	var height := 0.36
	for plane in 2:
		var a := Vector3(-width, 0, 0)
		var b := Vector3(width, 0, 0)
		var c := Vector3(width, height, 0)
		var d := Vector3(-width, height, 0)
		if plane == 1:
			a = Vector3(0, 0, -width)
			b = Vector3(0, 0, width)
			c = Vector3(0, height, width)
			d = Vector3(0, height, -width)
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var verts := [a, b, c, a, c, d]
		var uvs_order := [uvs[0], uvs[1], uvs[2], uvs[0], uvs[2], uvs[3]]
		for index in 6:
			st.set_uv(uvs_order[index])
			st.add_vertex(verts[index])
	st.generate_normals()
	return st.commit()

# ---------------------------------------------------------------- 灯柱

func _build_bushes() -> void:
	var spots := [
		Vector3(1.6, 0, -4.6), Vector3(-3.4, 0, 1.4), Vector3(9.2, 0, 4.0),
		Vector3(-7.0, 0, -5.4), Vector3(5.2, 0, 8.2), Vector3(-4.0, 0, 8.6),
	]
	for spot in spots:
		if _distance_to_path(spot.x, spot.z) < 1.5 or _pond_distance(spot.x, spot.z) < POND_RADIUS + 0.8:
			continue
		var root := Node3D.new()
		root.position = spot
		add_child(root)
		for index in 5:
			var angle := TAU * float(index) / 5.0 + _rng.randf_range(-0.3, 0.3)
			var pos := Vector3(cos(angle) * _rng.randf_range(0.25, 0.8), _rng.randf_range(0.25, 0.6), sin(angle) * _rng.randf_range(0.25, 0.8))
			var bush := _add_sphere(root, pos, _rng.randf_range(0.35, 0.7), _leaves[_rng.randi_range(0, 2)])
			bush.scale = Vector3(1.1, 0.7, 1.1)

func _build_leaves() -> void:
	var leaf_mats := [
		_mat(Color(0.32, 0.19, 0.07)),
		_mat(Color(0.43, 0.27, 0.09)),
		_mat(Color(0.5, 0.22, 0.08)),
	]
	for index in 140:
		var x := _rng.randf_range(-13.0, 13.0)
		var z := _rng.randf_range(-13.0, 13.0)
		if _pond_distance(x, z) < POND_RADIUS + 0.3:
			continue
		if _distance_to_path(x, z) > 4.0 and _rng.randf() < 0.5:
			continue
		var leaf := _add_box(self, Vector3(x, 0.015, z),
			Vector3(_rng.randf_range(0.08, 0.18), 0.012, _rng.randf_range(0.05, 0.12)),
			leaf_mats[index % 3], _rng.randf_range(0.0, TAU))
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_lamps() -> void:
	var fractions := [0.04, 0.16, 0.29, 0.41, 0.54, 0.67, 0.79, 0.91]
	for index in fractions.size():
		var s := path_length * float(fractions[index])
		var p := path_curve.sample_baked(s)
		var tangent := _path_tangent(s)
		var side := Vector3(tangent.z, 0, -tangent.x).normalized()
		var offset := 1.75 if index % 2 == 0 else -1.75
		_create_lamp(p + side * offset, index * 1.7)

func _create_lamp(pos: Vector3, phase: float) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_add_nav_obstacle(Vector2(pos.x, pos.z), 0.45)
	_add_cylinder(root, Vector3(0, 0.12, 0), 0.2, 0.24, 0.24, _iron, 8)
	_add_cylinder(root, Vector3(0, 1.25, 0), 0.055, 0.07, 2.25, _iron, 7)
	_add_box(root, Vector3(0, 2.38, 0), Vector3(0.38, 0.05, 0.38), _iron)
	_add_box(root, Vector3(0, 2.72, 0), Vector3(0.38, 0.05, 0.38), _iron)
	for sx in [-0.15, 0.15]:
		for sz in [-0.15, 0.15]:
			_add_box(root, Vector3(sx, 2.55, sz), Vector3(0.025, 0.3, 0.025), _iron)
	var pane := _add_box(root, Vector3(0, 2.55, 0), Vector3(0.25, 0.3, 0.25), _glass)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cap := PrismMesh.new()
	cap.size = Vector3(0.44, 0.18, 0.44)
	var cap_instance := MeshInstance3D.new()
	cap_instance.mesh = cap
	cap_instance.material_override = _iron
	cap_instance.position = Vector3(0, 2.83, 0)
	cap_instance.rotation.y = PI * 0.25
	root.add_child(cap_instance)
	_add_sphere(root, Vector3(0, 2.95, 0), 0.045, _iron)

	var halo := Sprite3D.new()
	halo.texture = _halo_tex
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	halo.pixel_size = 0.012
	halo.scale = Vector3.ONE * 2.8
	halo.position = Vector3(0, 2.55, 0)
	halo.modulate = Color(1.0, 0.8, 0.45, 0.0)
	root.add_child(halo)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.5, 0)
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 0.0
	light.omni_range = 7.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	root.add_child(light)
	lamps.append({"node": root, "light": light, "halo": halo, "phase": phase})

func set_lamp_level(level: float, time: float) -> void:
	_glass.emission_energy_multiplier = level * 1.6
	for lamp in lamps:
		var phase: float = lamp["phase"]
		var flicker := 0.94 + 0.04 * sin(time * 7.0 + phase) + 0.02 * sin(time * 21.0 + phase * 2.0)
		var light: OmniLight3D = lamp["light"]
		var halo: Sprite3D = lamp["halo"]
		light.light_energy = level * 2.15 * flicker
		halo.modulate = Color(1.0, 0.8, 0.45, level * (0.62 + 0.12 * flicker))
		halo.visible = level > 0.02
	for reflection in _reflections:
		var material: StandardMaterial3D = reflection["material"]
		var phase: float = reflection["phase"]
		material.albedo_color = Color(1.0, 0.62, 0.3, level * (0.22 + 0.05 * sin(time * 2.0 + phase)))

# ---------------------------------------------------------------- 寻路 / 任务 / 战斗

func _build_octopus() -> void:
	octopus = GardenOctopus.new()
	octopus.name = "Octopus"
	octopus.position = QUEST_GIVER
	octopus.shadow_texture = _shadow_tex
	add_child(octopus)
	_add_nav_obstacle(Vector2(QUEST_GIVER.x, QUEST_GIVER.z), 2.0)

func set_octopus_time(night: float) -> void:
	if octopus != null:
		octopus.set_night(night)

func _build_patrols() -> void:
	for route in PATROL_ROUTES:
		var npc := GardenPatrol.new()
		npc.name = "Patrol_" + String(route["role"])
		npc.role = String(route["role"])
		npc.waypoints.assign(route["waypoints"])
		npc.shadow_texture = _shadow_tex
		npc.halo_texture = _halo_tex
		npc.halo_core_texture = _halo_core_tex
		npc.camera_ref = camera
		match npc.role:
			GardenPatrol.ROLE_LANTERN:
				npc.speed = 0.72
			GardenPatrol.ROLE_SWEEPER:
				npc.speed = 0.55
				npc.pause_min = 2.2
				npc.pause_max = 4.0
			GardenPatrol.ROLE_FOX:
				npc.speed = 1.05
				npc.pause_min = 0.9
				npc.pause_max = 2.0
		add_child(npc)
		patrols.append(npc)

func set_patrol_night(night: float, dusk := 0.0) -> void:
	for npc in patrols:
		npc.set_night(night, dusk)

func set_patrol_visible(value: bool) -> void:
	for npc in patrols:
		npc.visible = value

func _build_gameplay() -> void:
	quest = GardenQuest.new()
	for spawn in MONSTER_SPAWNS:
		var monster := GardenMonster.new()
		monster.position = spawn
		monster.shadow_texture = _shadow_tex
		monster.halo_texture = _halo_tex
		add_child(monster)
		monster.died.connect(_on_monster_died)
		monsters.append(monster)

	hero = GardenHero.new()
	hero.name = "Hero"
	hero.shadow_texture = _shadow_tex
	hero.halo_texture = _halo_tex
	hero.world = self
	hero.quest = quest
	hero.monsters = monsters
	hero.respawn_position = HERO_START
	hero.turn_in_position = QUEST_RETURN
	hero.position = HERO_START
	add_child(hero)
	for monster in monsters:
		monster.hero = hero
	quest.completed.connect(_on_quest_completed)
	_build_quest_marker()

func _build_quest_marker() -> void:
	_quest_marker = Label3D.new()
	_quest_marker.text = "!"
	_quest_marker.font = ThemeDB.fallback_font
	_quest_marker.font_size = 96
	_quest_marker.pixel_size = 0.006
	_quest_marker.outline_size = 12
	_quest_marker.modulate = Color(1.0, 0.82, 0.4)
	_quest_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_quest_marker.no_depth_test = true
	_quest_marker.position = Vector3(0.0, 2.9, 2.0)
	add_child(_quest_marker)
	var bob := create_tween().set_loops()
	bob.tween_property(_quest_marker, "position:y", 3.15, 1.0).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_quest_marker, "position:y", 2.9, 1.0).set_trans(Tween.TRANS_SINE)

func _on_monster_died(_monster: GardenMonster) -> void:
	if quest != null:
		quest.add_kill()

func _on_quest_completed() -> void:
	if _quest_marker != null:
		_quest_marker.visible = false
	spawn_click_marker(QUEST_GIVER + Vector3(0.0, 0.2, 1.5))

# ---------------------------------------------------------------- A* 网格

func _build_nav_grid() -> void:
	nav_grid = AStarGrid2D.new()
	nav_grid.region = Rect2i(0, 0, NAV_SIZE, NAV_SIZE)
	nav_grid.cell_size = Vector2(NAV_CELL, NAV_CELL)
	nav_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	nav_grid.update()
	for obstacle in nav_obstacles:
		var center: Vector2 = obstacle["center"]
		var radius: float = obstacle["radius"]
		var min_cell := _world_to_cell(center - Vector2(radius, radius))
		var max_cell := _world_to_cell(center + Vector2(radius, radius))
		for x in range(min_cell.x, max_cell.x + 1):
			for z in range(min_cell.y, max_cell.y + 1):
				var cell := Vector2i(x, z)
				var world := _cell_to_world(cell)
				if Vector2(world.x, world.z).distance_to(center) <= radius:
					nav_grid.set_point_solid(cell, true)
	nav_grid.update()

func _add_nav_obstacle(center: Vector2, radius: float) -> void:
	nav_obstacles.append({"center": center, "radius": radius})

func _world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(floor((point.x - NAV_MIN) / NAV_CELL)), 0, NAV_SIZE - 1),
		clampi(int(floor((point.y - NAV_MIN) / NAV_CELL)), 0, NAV_SIZE - 1)
	)

func _cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		NAV_MIN + (float(cell.x) + 0.5) * NAV_CELL,
		0.0,
		NAV_MIN + (float(cell.y) + 0.5) * NAV_CELL
	)

func _nearest_walkable(cell: Vector2i) -> Vector2i:
	if not nav_grid.is_point_solid(cell):
		return cell
	for radius in range(1, 9):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dz) != radius:
					continue
				var candidate := cell + Vector2i(dx, dz)
				if candidate.x < 0 or candidate.y < 0 or candidate.x >= NAV_SIZE or candidate.y >= NAV_SIZE:
					continue
				if not nav_grid.is_point_solid(candidate):
					return candidate
	return cell

func find_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if nav_grid == null:
		return result
	var from_cell := _nearest_walkable(_world_to_cell(Vector2(from.x, from.z)))
	var to_cell := _nearest_walkable(_world_to_cell(Vector2(to.x, to.z)))
	var ids: Array[Vector2i] = nav_grid.get_id_path(from_cell, to_cell)
	for cell in ids:
		result.append(_cell_to_world(cell))
	return result

func quest_giver_position() -> Vector3:
	return QUEST_GIVER

func quest_return_position() -> Vector3:
	return QUEST_RETURN

func nearest_monster(point: Vector3, radius: float) -> GardenMonster:
	var best: GardenMonster = null
	var best_distance := radius * radius
	for monster in monsters:
		if monster == null or not is_instance_valid(monster) or not monster.is_alive():
			continue
		var dx := monster.global_position.x - point.x
		var dz := monster.global_position.z - point.z
		var d := dx * dx + dz * dz
		if d <= best_distance:
			best_distance = d
			best = monster
	return best

func spawn_click_marker(point: Vector3) -> void:
	if _halo_tex == null:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = _halo_tex
	material.albedo_color = Color(1.0, 0.8, 0.38, 0.5)
	material.disable_receive_shadows = true
	quad.material = material
	var marker := MeshInstance3D.new()
	marker.mesh = quad
	marker.material_override = material
	marker.rotation.x = -PI * 0.5
	marker.position = Vector3(point.x, 0.06, point.z)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(marker, "scale", Vector3.ONE * 1.7, 0.45)
	# MeshInstance3D 没有 modulate，淡出走材质的 albedo alpha
	tween.tween_method(func(alpha: float) -> void: material.albedo_color.a = alpha, 0.5, 0.0, 0.5)
	tween.chain().tween_callback(marker.queue_free)

# ---------------------------------------------------------------- 萤火

func _build_fireflies() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.13)
	firefly_mat = StandardMaterial3D.new()
	firefly_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	firefly_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	firefly_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	firefly_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	firefly_mat.albedo_texture = _halo_tex
	firefly_mat.albedo_color = Color(0.8, 1.0, 0.45, 1.0)
	firefly_mat.vertex_color_use_as_albedo = true
	firefly_mat.emission_enabled = true
	firefly_mat.emission = Color(0.75, 1.0, 0.42)
	firefly_mat.emission_energy_multiplier = 2.0
	firefly_mat.disable_receive_shadows = true
	firefly_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = firefly_mat

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(15.0, 1.6, 15.0)
	process.direction = Vector3(0, 0.2, 1)
	process.spread = 180.0
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.12
	process.gravity = Vector3.ZERO
	process.scale_min = 0.7
	process.scale_max = 1.9
	var ramp := Gradient.new()
	ramp.add_point(0.0, Color(0.8, 1.0, 0.45, 0.0))
	ramp.add_point(0.18, Color(0.8, 1.0, 0.45, 1.0))
	ramp.add_point(0.7, Color(0.8, 1.0, 0.45, 1.0))
	ramp.add_point(1.0, Color(0.8, 1.0, 0.45, 0.0))
	var texture := GradientTexture1D.new()
	texture.gradient = ramp
	process.color_ramp = texture

	fireflies = GPUParticles3D.new()
	fireflies.amount = 220
	fireflies.lifetime = 7.0
	fireflies.preprocess = 4.0
	fireflies.fixed_fps = 30
	fireflies.interpolate = true
	fireflies.position = Vector3(0, 1.8, 0)
	fireflies.process_material = process
	fireflies.draw_pass_1 = quad
	fireflies.visibility_aabb = AABB(Vector3(-20, -4, -20), Vector3(40, 24, 40))
	fireflies.emitting = false
	fireflies.amount_ratio = 0.0
	add_child(fireflies)

func set_firefly_level(level: float) -> void:
	if fireflies == null:
		return
	fireflies.emitting = level > 0.02
	fireflies.amount_ratio = clampf(level, 0.06, 1.0)
	firefly_mat.emission_energy_multiplier = 1.0 + level * 2.6

# ---------------------------------------------------------------- 光束 / 云影 / 雾

func _build_beams() -> void:
	var sun_beams := [
		{"anchor": Vector3(-12.0, 5.0, -8.0), "width": 1.8, "length": 8.0, "weight": 0.55},
		{"anchor": Vector3(-6.0, 5.4, -12.0), "width": 1.4, "length": 8.0, "weight": 0.4},
	]
	for item in sun_beams:
		_create_beam(item["anchor"], item["width"], item["length"], Color(1.0, 0.72, 0.42, 0.09), item["weight"], "sun")
	_create_beam(Vector3(2.0, 7.0, -3.0), 1.2, 7.0, Color(0.55, 0.72, 1.0, 0.11), 0.45, "moon")

func _create_beam(anchor: Vector3, width: float, length: float, color: Color, weight: float, kind: String) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, length)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/light_shaft.gdshader")
	material.set_shader_parameter("beam_color", color)
	material.set_shader_parameter("intensity", 0.0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visible = false
	add_child(mesh)
	beams.append({"mesh": mesh, "anchor": anchor, "length": length, "weight": weight, "kind": kind})

func set_beam_level(level: float, sun_dir: Vector3, cam_pos: Vector3, night: float) -> void:
	for beam in beams:
		var kind: String = beam["kind"]
		var dir := Vector3(0, -1, 0) if kind == "moon" else sun_dir.normalized()
		var intensity := (night * 0.5 if kind == "moon" else level) * float(beam["weight"])
		var mesh: MeshInstance3D = beam["mesh"]
		mesh.visible = intensity > 0.015
		if not mesh.visible:
			continue
		var anchor: Vector3 = beam["anchor"]
		var length: float = beam["length"]
		var to_cam := (cam_pos - anchor).normalized()
		var right := dir.cross(to_cam)
		if right.length() < 0.01:
			right = Vector3.RIGHT
		right = right.normalized()
		var normal := right.cross(dir).normalized()
		mesh.global_transform = Transform3D(Basis(right, dir, normal), anchor + dir * length * 0.5)
		var material: ShaderMaterial = mesh.material_override
		material.set_shader_parameter("intensity", intensity)

func _build_clouds() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(48, 48)
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = cloud_mat
	mesh.position = Vector3(0, 4.2, 0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

func set_cloud_level(strength: float) -> void:
	cloud_mat.set_shader_parameter("u_strength", strength)

func _build_mist() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(15, 12)
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = mist_mat
	mesh.position = POND_CENTER + Vector3(0, 0.45, 0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

func set_mist_level(night: float) -> void:
	mist_mat.set_shader_parameter("u_strength", night * 0.16)

func set_water_state(night: float, lamp: float, sun_dir: Vector3, sunset: float) -> void:
	water_mat.set_shader_parameter("u_night", night)
	water_mat.set_shader_parameter("u_lamp", lamp)
	water_mat.set_shader_parameter("u_sunset", sunset)
	water_mat.set_shader_parameter("sun_dir", sun_dir.normalized())
	foam_mat.set_shader_parameter("u_intensity", 0.38 + night * 0.1)

# ---------------------------------------------------------------- 通用构造

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material,
		yaw := 0.0, pitch := 0.0, roll := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation = Vector3(pitch, yaw, roll)
	parent.add_child(instance)
	return instance

func _add_cylinder(parent: Node3D, pos: Vector3, top_radius: float, bottom_radius: float,
		height: float, material: Material, segments := 8) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance

func _add_sphere(parent: Node3D, pos: Vector3, radius: float, material: Material,
		scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.scale = scale
	parent.add_child(instance)
	return instance

func _add_rock(pos: Vector3, radius: float, mossy: bool) -> void:
	var stone := _add_sphere(self, pos, radius, _stone[_rng.randi_range(0, 2)])
	stone.scale = Vector3(_rng.randf_range(0.8, 1.4), _rng.randf_range(0.5, 0.9), _rng.randf_range(0.8, 1.4))
	stone.rotation.y = _rng.randf_range(0.0, TAU)
	if mossy:
		var moss := _add_sphere(self, pos + Vector3(0, radius * 0.42, 0), radius * 0.85, _moss)
		moss.scale = Vector3(1.0, 0.25, 1.0)

func _pond_distance(x: float, z: float) -> float:
	return Vector2(x - POND_CENTER.x, z - POND_CENTER.z).length()

func _distance_to_path(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var best := 1e20
	for sample in _path_samples:
		var d := point.distance_squared_to(Vector2(sample.x, sample.z))
		if d < best:
			best = d
	return sqrt(best)
