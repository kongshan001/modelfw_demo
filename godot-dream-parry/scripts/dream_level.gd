class_name DreamLevel
extends Node3D

# 程序化梦境关卡：醒梦庭 → 齿轮回廊 → 断桥秘园（隐藏）→ 无钟之间。
# 等轴相机从左前上方看，因此近侧（南/东）墙压低，远侧（北/西）墙做高剪影。

const FLOOR_SHADER := preload("res://shaders/dream_floor.gdshader")

const START_LAMP_POS := Vector3(-2.7, 0.0, 4.2)
const GATE_LAMP_POS := Vector3(16.2, 0.0, -21.3)
const RIFT_POS := Vector3(-8.0, 0.0, -22.0)
const ALTAR_POS := Vector3(4.5, 0.0, -27.2)
const VISIBLE_SHARD_POS := Vector3(0.0, 0.0, -26.7)
const HIDDEN_SHARD_POS := Vector3(-17.0, 0.0, -22.0)
const NORMAL_HOME := Vector3(0.0, 0.05, -23.0)
const BOSS_HOME := Vector3(28.5, 0.05, -23.0)

var checkpoints: Array = []
var shards: Array = []
var floaters: Array = []
var gears: Array = []
var lamps: Array = []
var bridge_body: StaticBody3D
var barrier_body: StaticBody3D
var bridge_root: Node3D
var barrier_visual: Node3D
var relic_prism: Node3D
var clock_hands: Node3D
var bell: Node3D
var environment: Environment

var _geometry: Node3D
var _decor: Node3D
var _time := 0.0
var _barrier_mat: StandardMaterial3D
var _shard_rings: Array = []
var _relic_ring: Node3D
var _relic_light: OmniLight3D

var _stone_a: StandardMaterial3D
var _stone_a_dark: StandardMaterial3D
var _stone_b: StandardMaterial3D
var _stone_c: StandardMaterial3D
var _stone_island: StandardMaterial3D
var _brass: StandardMaterial3D
var _wood: StandardMaterial3D
var _glow_teal: StandardMaterial3D
var _glow_gold: StandardMaterial3D
var _glow_rose: StandardMaterial3D
var _glow_violet: StandardMaterial3D
var _water: StandardMaterial3D


func _ready() -> void:
	_geometry = Node3D.new()
	_geometry.name = "Geometry"
	add_child(_geometry)
	_decor = Node3D.new()
	_decor.name = "Decor"
	add_child(_decor)
	_make_materials()
	_build_environment()
	_build_floors()
	_build_walls()
	_build_arches()
	_build_room_a()
	_build_room_b()
	_build_hidden_garden()
	_build_room_c()
	_build_bridge()
	_build_lamps()
	_build_shards()
	_build_relic_altar()
	_build_fragments()
	_build_dust()


# ------------------------------------------------------------------ 材质

func _make_materials() -> void:
	_stone_a = _std(Color(0.34, 0.44, 0.42), 0.0, 0.92)
	_stone_a_dark = _std(Color(0.19, 0.26, 0.29), 0.0, 0.95)
	_stone_b = _std(Color(0.41, 0.31, 0.33), 0.0, 0.9)
	_stone_c = _std(Color(0.35, 0.23, 0.32), 0.0, 0.9)
	_stone_island = _std(Color(0.22, 0.34, 0.34), 0.0, 0.92)
	_brass = _std(Color(0.59, 0.43, 0.24), 0.62, 0.34, Color(0.35, 0.2, 0.08), 0.12)
	_wood = _std(Color(0.18, 0.12, 0.09), 0.05, 0.8)
	_glow_teal = _glow(Color(0.48, 1.0, 0.86), 1.9)
	_glow_gold = _glow(Color(1.0, 0.78, 0.38), 2.0)
	_glow_rose = _glow(Color(1.0, 0.4, 0.62), 1.9)
	_glow_violet = _glow(Color(0.67, 0.48, 1.0), 1.8)
	_water = _std(Color(0.12, 0.42, 0.4), 0.15, 0.18, Color(0.05, 0.25, 0.24), 0.9)
	_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water.albedo_color.a = 0.62


func _std(color: Color, metallic := 0.0, roughness := 0.86, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat


func _glow(color: Color, energy := 1.6) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _alpha_glow(color: Color, alpha: float, energy := 1.0) -> StandardMaterial3D:
	var mat := _glow(color, energy)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	return mat


# ------------------------------------------------------------------ 基础几何

func _mesh_box(pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _decor).add_child(mesh_instance)
	return mesh_instance


func _solid_box(pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_instance)
	(parent if parent != null else _geometry).add_child(body)
	return body


func _collider_box(pos: Vector3, size: Vector3, parent: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	(parent if parent != null else _geometry).add_child(body)
	return body


func _mesh_cylinder(pos: Vector3, radius: float, height: float, mat: Material, rotation := Vector3.ZERO, segments := 14, parent: Node3D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 1
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	mesh_instance.rotation = rotation
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _decor).add_child(mesh_instance)
	return mesh_instance


func _mesh_cone(pos: Vector3, top_radius: float, bottom_radius: float, height: float, mat: Material, rotation := Vector3.ZERO, segments := 14, parent: Node3D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 1
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	mesh_instance.rotation = rotation
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _decor).add_child(mesh_instance)
	return mesh_instance


func _mesh_torus(pos: Vector3, inner: float, outer: float, mat: Material, rotation := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 32
	torus.ring_segments = 10
	mesh_instance.mesh = torus
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	mesh_instance.rotation = rotation
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _decor).add_child(mesh_instance)
	return mesh_instance


func _mesh_sphere(pos: Vector3, radius: float, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh_instance.mesh = sphere
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _decor).add_child(mesh_instance)
	return mesh_instance


# ------------------------------------------------------------------ 环境/灯光

func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.032, 0.046, 0.082)
	environment.background_energy_multiplier = 0.85
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.52, 0.62, 0.78)
	environment.ambient_light_energy = 1.05
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.18, 0.23, 0.35)
	environment.fog_light_energy = 0.8
	environment.fog_density = 0.024
	environment.fog_sky_affect = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.28
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.08
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = environment
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "MoonLight"
	sun.rotation_degrees = Vector3(-54.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.75)
	sun.light_energy = 1.65
	sun.shadow_enabled = false
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "DreamFill"
	fill.rotation_degrees = Vector3(-30.0, 142.0, 0.0)
	fill.light_color = Color(0.55, 0.7, 1.0)
	fill.light_energy = 0.7
	fill.shadow_enabled = false
	add_child(fill)
	_add_omni(Vector3(-3.0, 2.4, 3.4), Color(0.4, 0.95, 0.82), 1.25, 7.0)
	_add_omni(Vector3(0.0, 4.8, -26.5), Color(1.0, 0.66, 0.34), 1.1, 8.0)
	_add_omni(Vector3(28.0, 5.5, -25.0), Color(1.0, 0.42, 0.56), 1.3, 10.0)
	_add_omni(Vector3(-17.0, 2.8, -22.0), Color(0.36, 0.95, 0.82), 1.0, 7.0)
	_add_omni(Vector3(16.0, 3.0, -21.0), Color(1.0, 0.78, 0.4), 0.75, 5.5)


func _add_omni(pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	add_child(light)
	return light


# ------------------------------------------------------------------ 地面/墙体

func _floor(center: Vector3, size: Vector2, color_a: Color, color_b: Color, edge: Color, checker := 0.4, cell := 1.0, glow := 0.24) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = FLOOR_SHADER
	mat.set_shader_parameter("color_a", color_a)
	mat.set_shader_parameter("color_b", color_b)
	mat.set_shader_parameter("edge_color", edge)
	mat.set_shader_parameter("checker_amount", checker)
	mat.set_shader_parameter("cell_size", cell)
	mat.set_shader_parameter("edge_glow", glow)
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = plane
	mesh_instance.material_override = mat
	mesh_instance.position = center + Vector3(0.0, 0.008, 0.0)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geometry.add_child(mesh_instance)
	_collider_box(center + Vector3(0, -0.24, 0), Vector3(size.x, 0.48, size.y))


func _build_floors() -> void:
	_floor(Vector3(0, 0, 0), Vector2(16, 16), Color(0.15, 0.24, 0.24), Color(0.20, 0.30, 0.28), Color(0.32, 0.55, 0.5), 0.4, 1.35, 0.11)
	_floor(Vector3(0, 0, -11), Vector2(5.2, 6.2), Color(0.15, 0.24, 0.24), Color(0.20, 0.30, 0.28), Color(0.32, 0.55, 0.5), 0.4, 1.2, 0.11)
	_floor(Vector3(0, 0, -22), Vector2(16, 16), Color(0.31, 0.2, 0.23), Color(0.24, 0.17, 0.21), Color(0.65, 0.47, 0.28), 0.45, 1.2, 0.13)
	_floor(Vector3(13, 0, -22), Vector2(10, 4), Color(0.3, 0.2, 0.22), Color(0.23, 0.17, 0.2), Color(0.65, 0.47, 0.28), 0.4, 1.2, 0.13)
	_floor(Vector3(28, 0, -22), Vector2(20, 20), Color(0.4, 0.19, 0.28), Color(0.22, 0.16, 0.22), Color(0.74, 0.34, 0.46), 1.0, 1.5, 0.13)
	_floor(Vector3(-17, 0, -22), Vector2(6, 6), Color(0.16, 0.28, 0.28), Color(0.23, 0.38, 0.36), Color(0.38, 0.72, 0.65), 0.5, 1.0, 0.15)
	# 深渊底色：雾中看不见边界，只留下梦的深蓝。
	_mesh_box(Vector3(10, -3.0, -15), Vector3(96, 0.2, 96), _std(Color(0.04, 0.055, 0.09), 0.0, 1.0))
	_collider_box(Vector3(10, -6.0, -15), Vector3(120, 0.3, 120))


func _wall(pos: Vector3, size: Vector3, mat: Material, trim_mat: Material, low := false) -> void:
	_solid_box(pos, size, mat)
	# 墙顶的细金线，远景能读出轮廓。
	var trim_size := Vector3(size.x + 0.04, 0.035, 0.07) if size.x > size.z else Vector3(0.07, 0.035, size.z + 0.04)
	_mesh_box(Vector3(pos.x, pos.y + size.y * 0.5 + 0.025, pos.z), trim_size, trim_mat)
	# 残破压顶：只给高远墙做剪影；近侧矮墙保持干净。
	if low:
		return
	var count := 3
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		var off := Vector3.ZERO
		if size.x > size.z:
			off.x = (t - 0.5) * size.x * 0.78
		else:
			off.z = (t - 0.5) * size.z * 0.78
		var block_h := 0.16 + 0.12 * float((i + 1) % 3)
		_mesh_box(pos + Vector3(off.x, size.y * 0.5 + block_h * 0.5, off.z), Vector3(0.6 if size.x > size.z else size.x * 0.8, block_h, 0.6 if size.z > size.x else size.z * 0.8), mat)


func _build_walls() -> void:
	# ── 醒梦庭 ──
	_wall(Vector3(0, 0.23, 8.0), Vector3(16.8, 0.46, 0.5), _stone_a, _stone_a_dark, true)
	_wall(Vector3(8.0, 0.23, 0), Vector3(0.5, 0.46, 16.8), _stone_a, _stone_a_dark, true)
	_wall(Vector3(-8.0, 1.35, 0), Vector3(0.5, 2.7, 16.8), _stone_a_dark, _glow_teal)
	_wall(Vector3(-5.3, 1.35, -8.0), Vector3(5.4, 2.7, 0.5), _stone_a, _glow_teal)
	_wall(Vector3(5.3, 1.35, -8.0), Vector3(5.4, 2.7, 0.5), _stone_a, _glow_teal)
	# 回廊
	_wall(Vector3(2.6, 0.25, -11.05), Vector3(0.35, 0.5, 6.1), _stone_a, _stone_a_dark, true)
	_wall(Vector3(-2.6, 1.25, -11.05), Vector3(0.35, 2.5, 6.1), _stone_a_dark, _glow_teal)
	# ── 齿轮回廊 ──
	_wall(Vector3(-5.3, 0.24, -14.0), Vector3(5.4, 0.48, 0.5), _stone_b, _stone_b, true)
	_wall(Vector3(5.3, 0.24, -14.0), Vector3(5.4, 0.48, 0.5), _stone_b, _stone_b, true)
	_wall(Vector3(0, 1.45, -30.0), Vector3(16.8, 2.9, 0.5), _stone_b, _glow_gold)
	_wall(Vector3(-8.0, 1.45, -26.85), Vector3(0.5, 2.9, 6.3), _stone_b, _glow_gold)
	_wall(Vector3(-8.0, 1.45, -17.1), Vector3(0.5, 2.9, 6.2), _stone_b, _glow_gold)
	_wall(Vector3(8.0, 0.27, -27.1), Vector3(0.5, 0.54, 5.8), _stone_b, _stone_b, true)
	_wall(Vector3(8.0, 0.27, -16.9), Vector3(0.5, 0.54, 5.8), _stone_b, _stone_b, true)
	# 走廊 B → C
	_wall(Vector3(13, 1.25, -24.0), Vector3(10, 2.5, 0.4), _stone_b, _glow_gold)
	_wall(Vector3(13, 0.26, -20.0), Vector3(10, 0.52, 0.4), _stone_b, _stone_b, true)
	# ── 无钟之间 ──
	_wall(Vector3(18.0, 1.5, -28.1), Vector3(0.5, 3.0, 7.8), _stone_c, _glow_rose)
	_wall(Vector3(18.0, 1.5, -15.9), Vector3(0.5, 3.0, 7.8), _stone_c, _glow_rose)
	_wall(Vector3(28, 1.5, -32.0), Vector3(20.4, 3.0, 0.5), _stone_c, _glow_rose)
	_wall(Vector3(28, 0.24, -12.0), Vector3(20.4, 0.48, 0.5), _stone_c, _stone_c, true)
	_wall(Vector3(38, 0.24, -22.0), Vector3(0.5, 0.48, 20.4), _stone_c, _stone_c, true)
	# 断桥秘园护栏
	_wall(Vector3(-17, 0.25, -25.1), Vector3(6.2, 0.5, 0.4), _stone_island, _stone_island, true)
	_wall(Vector3(-17, 0.25, -18.9), Vector3(6.2, 0.5, 0.4), _stone_island, _stone_island, true)
	_wall(Vector3(-20.1, 0.25, -22.0), Vector3(0.4, 0.5, 6.2), _stone_island, _stone_island, true)


func _build_arches() -> void:
	_arch(Vector3(0, 0, -8.1), true, 5.2, 2.55, _stone_a, _glow_teal)
	_arch(Vector3(0, 0, -14.1), true, 5.2, 2.35, _stone_b, _glow_gold)
	_arch(Vector3(8.1, 0, -22), false, 4.6, 2.25, _stone_b, _glow_gold)
	_arch(Vector3(18.1, 0, -22), false, 4.6, 2.6, _stone_c, _glow_rose)


func _arch(center: Vector3, along_x: bool, opening: float, height: float, mat: Material, glow_mat: Material) -> void:
	var column_size := Vector3(0.36, height, 0.55) if along_x else Vector3(0.55, height, 0.36)
	var offset := Vector3(opening * 0.5, height * 0.5, 0) if along_x else Vector3(0, height * 0.5, opening * 0.5)
	_solid_box(center + offset, column_size, mat)
	_solid_box(center - offset, column_size, mat)
	var lintel_size := Vector3(opening + 0.72, 0.34, 0.55) if along_x else Vector3(0.55, 0.34, opening + 0.72)
	_mesh_box(center + Vector3(0, height, 0), lintel_size, mat)
	var trim_pos := center + Vector3(0, height - 0.12, 0)
	var trim_size := Vector3(opening + 0.5, 0.06, 0.6) if along_x else Vector3(0.6, 0.06, opening + 0.5)
	_mesh_box(trim_pos, trim_size, glow_mat)


# ------------------------------------------------------------------ 醒梦庭

func _build_room_a() -> void:
	# 月门：悬在西侧远墙前，作为“梦的出口/入口”符号。
	_mesh_torus(Vector3(-7.45, 3.2, 1.0), 2.15, 2.32, _glow_teal, Vector3(0, 0, PI * 0.5))
	var portal_disc := _mesh_cylinder(Vector3(-7.52, 3.2, 1.0), 2.1, 0.04, _alpha_glow(Color(0.2, 0.65, 0.55), 0.12, 0.4), Vector3(0, 0, PI * 0.5), 32)
	portal_disc.name = "MoonGateVeil"
	_mesh_box(Vector3(-7.35, 3.2, 1.0), Vector3(0.35, 4.4, 0.6), _stone_a_dark)
	for i in 6:
		var a := float(i) * TAU / 6.0
		_mesh_box(Vector3(-7.35 + cos(a) * 2.35, 3.2 + sin(a) * 2.35, 1.0), Vector3(0.16, 0.16, 0.16), _glow_teal)
	# 倒下的梦树 + 浮叶。
	var tree_root := Node3D.new()
	tree_root.position = Vector3(-4.35, 0, -1.9)
	_decor.add_child(tree_root)
	_mesh_cylinder(Vector3(0, 1.65, 0), 0.22, 3.3, _wood, Vector3(0.12, 0, 0.16), 8, tree_root)
	for branch in [
		[Vector3(0.6, 2.6, 0.1), Vector3(0.7, 0.16, 2.1), Vector3(0.1, 0.6, -0.9)],
		[Vector3(-0.5, 2.1, -0.3), Vector3(0.8, 0.13, 1.7), Vector3(-0.4, -0.7, -1.0)],
		[Vector3(0.2, 1.4, 0.2), Vector3(0.5, 0.12, 1.5), Vector3(0.9, 0.25, -0.4)],
	]:
		_mesh_cylinder(branch[0], 0.08, float(branch[1].z), _wood, branch[2], 6, tree_root)
	for i in 7:
		var a := float(i) * 1.7
		_mesh_sphere(Vector3(cos(a) * 1.2, 2.7 + sin(a * 1.3) * 0.7, sin(a) * 1.1), 0.09, _glow_teal if i % 2 == 0 else _glow_gold, tree_root)
	# 水池 + 花。
	_mesh_cylinder(Vector3(3.2, 0.03, -2.8), 1.7, 0.04, _water, Vector3.ZERO, 32)
	_mesh_torus(Vector3(3.2, 0.06, -2.8), 1.66, 1.78, _glow_teal, Vector3.ZERO)
	for i in 10:
		var a := float(i) * TAU / 10.0
		_mesh_sphere(Vector3(3.2 + cos(a) * (1.9 + 0.2 * sin(i * 2.2)), 0.18, -2.8 + sin(a) * (1.7 + 0.2 * cos(i * 1.4))), 0.06, _glow_teal if i % 3 else _glow_rose)
	# 入口的碎石与灯。
	for i in 5:
		_mesh_box(Vector3(-2.2 + i * 0.7, 0.08, 6.4 + 0.2 * sin(i * 2.0)), Vector3(0.5, 0.16, 0.4), _stone_a, _decor).rotation.y = i * 0.7
	_mesh_torus(Vector3(0, 0.02, 3.4), 2.35, 2.42, _alpha_glow(Color(0.5, 0.9, 0.8), 0.16, 0.4))


	# ── 引导石径：从残梦灯一路指向北门 ──
	for i in 7:
		var z := 2.7 - float(i) * 1.32
		var stone := _mesh_box(Vector3(0.18 * sin(float(i) * 1.7), 0.035, z), Vector3(1.35, 0.06, 0.72), _stone_a_dark if i % 2 == 0 else _stone_a)
		stone.rotation.y = 0.06 * sin(float(i) * 2.2)
		_mesh_box(Vector3(0.18 * sin(float(i) * 1.7), 0.045, z - 0.32), Vector3(0.5, 0.018, 0.035), _alpha_glow(Color(0.45, 0.9, 0.8), 0.38, 0.8))
	for i in 8:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * (1.5 + 0.25 * sin(float(i) * 2.4)), 0.13, 2.4 - float(i) * 1.12)
		_mesh_cylinder(p, 0.018, 0.26, _wood, Vector3.ZERO, 5)
		_mesh_sphere(p + Vector3(0, 0.18, 0), 0.065, _glow_gold if i % 3 == 0 else _glow_teal)
	# ── 立石与漂浮的梦境镜面 ──
	for i in 5:
		var a := 0.4 + float(i) * 1.12
		var p := Vector3(cos(a) * 6.2, 0.9 + 0.25 * sin(float(i) * 2.3), sin(a) * 6.2)
		var stone := _mesh_box(p, Vector3(0.5, 1.8 + 0.4 * sin(float(i)), 0.28), _stone_a_dark)
		stone.rotation.y = a
		stone.rotation.z = 0.06 * sin(float(i) * 1.9)
		_mesh_box(p + Vector3(0, 1.15, 0), Vector3(0.06, 0.08, 0.3), _glow_teal)
	var mirror_root := Node3D.new()
	mirror_root.position = Vector3(5.1, 0, 0.6)
	_decor.add_child(mirror_root)
	_mesh_cylinder(Vector3(-0.7, 1.3, 0), 0.16, 2.6, _stone_a, Vector3.ZERO, 8, mirror_root)
	_mesh_cylinder(Vector3(0.7, 0.95, 0), 0.13, 1.9, _stone_a, Vector3.ZERO, 8, mirror_root)
	var mirror := _mesh_box(Vector3(0, 1.45, 0), Vector3(1.3, 1.8, 0.06), _alpha_glow(Color(0.5, 0.9, 0.86), 0.18, 0.7), mirror_root)
	mirror.rotation.y = -0.32
	_mesh_torus(Vector3(0, 1.45, 0.02), 0.85, 0.93, _alpha_glow(Color(0.55, 0.95, 0.87), 0.55, 1.1), Vector3(PI * 0.5, 0, 0), mirror_root)
	for i in 3:
		_mesh_sphere(Vector3(-0.35 + i * 0.35, 1.3 + 0.18 * sin(i * 2.0), 0.12), 0.05, _glow_teal, mirror_root)


# ------------------------------------------------------------------ 齿轮回廊

func _build_room_b() -> void:
	_gear(Vector3(0.0, 3.5, -29.45), 2.05, 14, 0.18, _brass)
	_gear(Vector3(2.45, 4.3, -29.4), 1.22, 10, -0.28, _brass)
	_gear(Vector3(-2.5, 2.2, -29.4), 0.82, 8, 0.4, _brass)
	# 背后巨大的断轴，强化“停滞的钟表”母题。
	_mesh_cylinder(Vector3(0, 3.5, -29.75), 0.35, 0.45, _stone_b, Vector3(PI * 0.5, 0, 0), 16)
	_mesh_torus(Vector3(0, 3.5, -29.62), 2.3, 2.4, _alpha_glow(Color(0.9, 0.62, 0.3), 0.35, 0.6), Vector3(0, 0, 0))
	# 赭金色的记忆池与翻倒的椅子，暗示这里是“被翻修过的梦”。
	_mesh_cylinder(Vector3(-3.7, 0.03, -18.5), 1.25, 0.04, _alpha_glow(Color(0.55, 0.33, 0.18), 0.22, 0.2), Vector3.ZERO, 28)
	for i in 4:
		var z := -17.0 - i * 2.1
		_mesh_box(Vector3(5.8, 0.18, z), Vector3(0.3, 0.36, 1.3), _stone_b).rotation.z = 0.2 * sin(i)
	# 隐藏断桥的观景点：两根残柱。
	_mesh_cylinder(Vector3(-7.4, 1.2, -24.0), 0.27, 2.4, _stone_b, Vector3(0, 0, 0.1), 8)
	_mesh_cylinder(Vector3(-7.4, 1.0, -20.0), 0.22, 2.0, _stone_b, Vector3(0, 0, -0.12), 8)
	_mesh_torus(Vector3(-7.35, 2.5, -22.0), 2.1, 2.23, _alpha_glow(Color(0.45, 0.9, 0.82), 0.32, 0.6), Vector3(0, 0, PI * 0.5))
	for i in 5:
		_mesh_sphere(Vector3(-7.0 + sin(i * 3.0) * 0.35, 0.8 + i * 0.45, -23.7 + cos(i * 2.0) * 1.5), 0.045, _glow_teal)


func _gear(pos: Vector3, radius: float, teeth: int, speed: float, mat: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	_decor.add_child(root)
	_mesh_cylinder(Vector3.ZERO, radius, 0.16, mat, Vector3(PI * 0.5, 0, 0), 24, root)
	for i in teeth:
		var angle := float(i) * TAU / float(teeth)
		var tooth := _mesh_box(Vector3(cos(angle) * radius * 1.04, sin(angle) * radius * 1.04, 0), Vector3(radius * 0.19, radius * 0.3, 0.18), mat, root)
		tooth.rotation.z = angle
	for i in 4:
		var angle := float(i) * TAU / 4.0
		var spoke := _mesh_box(Vector3(cos(angle) * radius * 0.42, sin(angle) * radius * 0.42, 0.1), Vector3(radius * 0.08, radius * 0.75, 0.12), _std(Color(0.24, 0.17, 0.1), 0.4, 0.5), root)
		spoke.rotation.z = angle
	_mesh_cylinder(Vector3(0, 0, 0.11), radius * 0.22, 0.22, _brass, Vector3(PI * 0.5, 0, 0), 16, root)
	_mesh_torus(Vector3(0, 0, 0.12), radius * 0.55, radius * 0.61, _alpha_glow(Color(0.85, 0.58, 0.27), 0.25, 0.5), Vector3.ZERO, root)
	gears.append({"node": root, "speed": speed})


	_mesh_torus(Vector3(0, 0.035, -22), 3.3, 3.42, _alpha_glow(Color(0.72, 0.5, 0.26), 0.07, 0.25))
	_mesh_torus(Vector3(0, 0.04, -22), 1.3, 1.36, _alpha_glow(Color(0.72, 0.5, 0.26), 0.04, 0.18))
	for i in 3:
		var x := -2.0 + i * 2.0
		_mesh_cylinder(Vector3(x, 3.7, -20.0), 0.018, 3.2, _std(Color(0.3, 0.24, 0.17), 0.45, 0.4), Vector3.ZERO, 5)
	# 祭坛旁的小火盆
	_mesh_cylinder(Vector3(3.0, 0.55, -26.0), 0.22, 1.1, _brass, Vector3.ZERO, 8)
	_mesh_cone(Vector3(3.0, 1.2, -26.0), 0.0, 0.32, 0.38, _glow_gold, Vector3.ZERO, 8)


# ------------------------------------------------------------------ 断桥秘园

func _build_hidden_garden() -> void:
	# 岛上的小祭坛与背后的月拱。
	_mesh_torus(Vector3(-17, 3.05, -24.3), 1.75, 1.9, _glow_teal, Vector3(PI * 0.5, 0, 0))
	_mesh_cylinder(Vector3(-18.2, 1.2, -24.3), 0.24, 2.4, _stone_island, Vector3.ZERO, 8)
	_mesh_cylinder(Vector3(-15.8, 1.2, -24.3), 0.24, 2.4, _stone_island, Vector3.ZERO, 8)
	# 断桥边的雾墙。
	barrier_visual = Node3D.new()
	barrier_visual.name = "IllusionBarrier"
	barrier_visual.position = Vector3(-8.12, 1.3, -22.0)
	_decor.add_child(barrier_visual)
	var veil := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.1, 2.6)
	veil.mesh = quad
	_barrier_mat = _alpha_glow(Color(0.35, 0.85, 0.78), 0.13, 0.8)
	veil.material_override = _barrier_mat
	veil.rotation.y = PI * 0.5
	barrier_visual.add_child(veil)
	for i in 5:
		_mesh_box(Vector3(0.02, 0.05, -1.25 + i * 0.62), Vector3(0.05, 2.25, 0.035), _alpha_glow(Color(0.48, 1.0, 0.86), 0.25, 0.9), barrier_visual)
	# 隐形门碰撞：显形前挡住断桥。
	barrier_body = _collider_box(Vector3(-8.15, 1.3, -22.0), Vector3(0.35, 2.6, 3.1))
	# 断桥：先隐藏，显形后可走。
	bridge_root = Node3D.new()
	bridge_root.name = "HiddenBridge"
	bridge_root.visible = false
	_decor.add_child(bridge_root)
	var spirit_wood := _std(Color(0.24, 0.4, 0.38), 0.05, 0.55, Color(0.16, 0.55, 0.48), 0.42)
	for i in 9:
		var x := -8.55 - float(i) * 0.63
		var plank := _mesh_box(Vector3(x, 0.06 + 0.035 * sin(float(i) * 1.7), -22.0), Vector3(0.58, 0.12, 2.35), spirit_wood, bridge_root)
		plank.rotation.y = 0.035 * sin(float(i) * 2.1)
		plank.rotation.z = 0.012 * cos(float(i) * 1.4)
		_mesh_box(Vector3(x, 0.13, 0.9), Vector3(0.55, 0.02, 0.05), _alpha_glow(Color(0.55, 1.0, 0.86), 0.72, 1.2), bridge_root)
		_mesh_box(Vector3(x, 0.13, -0.9), Vector3(0.55, 0.02, 0.05), _alpha_glow(Color(0.55, 1.0, 0.86), 0.72, 1.2), bridge_root)
		_mesh_box(Vector3(x, 0.135, 0.0), Vector3(0.28, 0.018, 0.07), _alpha_glow(Color(0.6, 1.0, 0.86), 0.45, 0.9), bridge_root)
	# 两侧灵光扶手，强化“显形后的桥”。
	_mesh_box(Vector3(-11.05, 0.52, -23.15), Vector3(5.65, 0.035, 0.035), _alpha_glow(Color(0.55, 1.0, 0.86), 0.6, 1.0), bridge_root)
	_mesh_box(Vector3(-11.05, 0.52, -20.85), Vector3(5.65, 0.035, 0.035), _alpha_glow(Color(0.55, 1.0, 0.86), 0.6, 1.0), bridge_root)
	for i in 4:
		var x := -8.5 - i * 1.65
		for side in [-1.0, 1.0]:
			_mesh_cylinder(Vector3(x, 0.4, -22.0 + side * 1.15), 0.035, 0.8, _brass, Vector3.ZERO, 6, bridge_root)
	bridge_body = _collider_box(Vector3(-11.05, -0.24, -22.0), Vector3(6.5, 0.48, 2.7))
	bridge_body.collision_layer = 0
	# 岛上的花。
	for i in 9:
		var a := float(i) * TAU / 9.0
		var base := Vector3(-17 + cos(a) * 2.2, 0.1, -22 + sin(a) * 2.2)
		_mesh_cylinder(base + Vector3(0, 0.12, 0), 0.018, 0.26, _wood, Vector3.ZERO, 5)
		_mesh_sphere(base + Vector3(0, 0.3, 0), 0.075, _glow_teal if i % 2 else _glow_rose)
	_mesh_box(Vector3(-17, 0.18, -22), Vector3(1.1, 0.36, 1.1), _stone_island)


# ------------------------------------------------------------------ 无钟之间

func _build_room_c() -> void:
	_mesh_torus(Vector3(28, 0.03, -22), 6.8, 6.92, _alpha_glow(Color(0.9, 0.38, 0.55), 0.34, 0.8))
	_mesh_torus(Vector3(28, 0.035, -22), 4.1, 4.18, _alpha_glow(Color(0.9, 0.38, 0.55), 0.2, 0.6))
	for i in 4:
		var a := float(i) * TAU / 4.0
		var p := Vector3(28 + cos(a) * 8.4, 0, -22 + sin(a) * 8.4)
		_mesh_cylinder(p + Vector3(0, 1.3, 0), 0.35, 2.6, _stone_c, Vector3(0, 0, 0.05 * sin(a)), 8)
		_solid_box(p + Vector3(0, 1.3, 0), Vector3(0.72, 2.6, 0.72), _stone_c)
		_mesh_sphere(p + Vector3(0, 2.9, 0), 0.11, _glow_rose)
	# 巨钟：挂在竞技场上方，给 Boss 一个高剪影。
	bell = Node3D.new()
	bell.name = "BrokenBell"
	bell.position = Vector3(28, 7.2, -22)
	_decor.add_child(bell)
	_mesh_cone(Vector3(0, -1.25, 0), 0.3, 2.0, 2.6, _std(Color(0.23, 0.15, 0.14), 0.45, 0.42, Color(0.35, 0.15, 0.16), 0.3), Vector3.ZERO, 24, bell)
	_mesh_torus(Vector3(0, -2.5, 0), 1.8, 1.96, _brass, Vector3.ZERO, bell)
	_mesh_box(Vector3(0, -1.1, 1.72), Vector3(0.22, 1.4, 0.06), _glow_rose, bell)
	for i in 3:
		var a := float(i) * TAU / 3.0
		_mesh_cylinder(Vector3(cos(a) * 0.9, 1.8, sin(a) * 0.9), 0.025, 3.8, _std(Color(0.31, 0.25, 0.18), 0.5, 0.5), Vector3.ZERO, 5, bell)
	# 背后的巨钟面 + 指针。
	_mesh_cylinder(Vector3(28, 5.2, -31.1), 3.25, 0.22, _std(Color(0.14, 0.09, 0.12), 0.4, 0.5, Color(0.35, 0.09, 0.22), 0.25), Vector3(PI * 0.5, 0, 0), 40)
	_mesh_torus(Vector3(28, 5.2, -30.95), 3.25, 3.36, _glow_rose, Vector3(PI * 0.5, 0, 0))
	for i in 12:
		var a := float(i) * TAU / 12.0
		_mesh_box(Vector3(28 + cos(a) * 2.75, 5.2 + sin(a) * 2.75, -30.9), Vector3(0.08, 0.35, 0.06), _glow_gold)
	clock_hands = Node3D.new()
	clock_hands.position = Vector3(28, 5.2, -30.86)
	_decor.add_child(clock_hands)
	_mesh_box(Vector3(0, 1.2, 0), Vector3(0.09, 2.4, 0.06), _glow_rose, clock_hands)
	_mesh_box(Vector3(0.65, 0.0, 0.02), Vector3(1.5, 0.1, 0.06), _glow_gold, clock_hands)
	# 台边的香料与飘带。
	for i in 6:
		_mesh_box(Vector3(20.4 + i * 0.12, 0.35 + i * 0.4, -30.5), Vector3(0.035, 0.45, 0.035), _alpha_glow(Color(0.9, 0.4, 0.55), 0.28, 0.5))


func _build_bridge() -> void:
	# 桥体本身在隐藏区完成，这里仅补一条从走廊望向断桥的引导光带。
	for i in 5:
		_mesh_sphere(Vector3(9.5 + i * 1.5, 0.04, -22.0), 0.045, _glow_gold)


	for i in 2:
		var bx := 22.8 + i * 10.4
		_mesh_box(Vector3(bx, 2.6, -31.55), Vector3(1.5, 3.4, 0.06), _std(Color(0.35, 0.1, 0.2), 0.0, 0.8, Color(0.35, 0.08, 0.18), 0.35))
		_mesh_box(Vector3(bx, 4.2, -31.5), Vector3(1.8, 0.12, 0.1), _glow_rose)
		_mesh_sphere(Vector3(bx, 0.25, -31.3), 0.16, _glow_gold)
	for i in 4:
		var a := float(i) * TAU / 4.0 + 0.35
		_mesh_cylinder(Vector3(28 + cos(a) * 9.2, 0.6, -22 + sin(a) * 9.2), 0.06, 1.2, _brass, Vector3.ZERO, 6)
		_mesh_sphere(Vector3(28 + cos(a) * 9.2, 1.3, -22 + sin(a) * 9.2), 0.1, _glow_rose)


# ------------------------------------------------------------------ 灯 / 残片 / 遗物

func _build_lamps() -> void:
	_build_lamp(START_LAMP_POS, "醒梦灯", Vector3(0, 0.05, 3.4), 0.0, _glow_teal, Color(0.42, 0.95, 0.8), "起点")
	_build_lamp(GATE_LAMP_POS, "门前残灯", Vector3(16.2, 0.05, -22.0), -PI * 0.5, _glow_gold, Color(1.0, 0.78, 0.42), "门前")


func _build_lamp(pos: Vector3, lamp_name: String, spawn: Vector3, yaw: float, orb_mat: Material, light_color: Color, tag: String) -> void:
	var root := Node3D.new()
	root.position = pos
	_decor.add_child(root)
	_mesh_cylinder(Vector3(0, 0.22, 0), 0.34, 0.44, _stone_a if tag == "起点" else _stone_b, Vector3.ZERO, 8, root)
	_mesh_cylinder(Vector3(0, 0.73, 0), 0.08, 0.62, _brass, Vector3.ZERO, 6, root)
	_mesh_torus(Vector3(0, 0.34, 0), 0.45, 0.52, orb_mat, Vector3.ZERO, root)
	var orb := _mesh_sphere(Vector3(0, 1.35, 0), 0.16, orb_mat, root)
	_mesh_torus(Vector3(0, 1.35, 0), 0.22, 0.27, _alpha_glow(light_color, 0.55, 1.2), Vector3(PI * 0.5, 0, 0), root)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.35, 0)
	light.light_color = light_color
	light.light_energy = 1.0
	light.omni_range = 4.5
	light.shadow_enabled = false
	root.add_child(light)
	lamps.append({"node": root, "orb": orb, "base_y": 1.35, "phase": pos.x * 0.7 + pos.z * 0.3})
	checkpoints.append({
		"kind": "checkpoint",
		"pos": pos,
		"name": lamp_name,
		"spawn": spawn,
		"yaw": yaw,
		"tag": tag,
	})


func _build_shards() -> void:
	_build_shard(Vector3(VISIBLE_SHARD_POS.x, 1.38, VISIBLE_SHARD_POS.z), "巡游者的残片")
	_build_shard(Vector3(HIDDEN_SHARD_POS.x, 1.38, HIDDEN_SHARD_POS.z), "断桥下的记忆")


func _build_shard(pos: Vector3, label: String) -> void:
	var root := Node3D.new()
	root.position = pos
	_decor.add_child(root)
	var shard_mat := _glow(Color(0.58, 1.0, 0.91), 2.0)
	var shard_top := _mesh_cone(Vector3(0, 0.22, 0), 0.0, 0.24, 0.5, shard_mat, Vector3.ZERO, 6, root)
	var shard_bottom := _mesh_cone(Vector3(0, -0.22, 0), 0.0, 0.24, 0.5, shard_mat, Vector3(PI, 0, 0), 6, root)
	var ring := Node3D.new()
	root.add_child(ring)
	_mesh_torus(Vector3.ZERO, 0.36, 0.39, _alpha_glow(Color(0.55, 1.0, 0.9), 0.6, 1.1), Vector3(PI * 0.35, 0.2, 0), ring)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.2, 0)
	light.light_color = Color(0.5, 1.0, 0.9)
	light.light_energy = 0.8
	light.omni_range = 3.4
	light.shadow_enabled = false
	root.add_child(light)
	# 底座用世界坐标，避免跟着漂浮的残片一起升空。
	_mesh_cylinder(Vector3(pos.x, 0.3, pos.z), 0.3, 0.6, _stone_a_dark, Vector3.ZERO, 8)
	_mesh_box(Vector3(pos.x, 0.03, pos.z), Vector3(0.9, 0.06, 0.9), _alpha_glow(Color(0.5, 0.95, 0.82), 0.2, 0.3))
	shards.append({"node": root, "base": pos, "label": label, "collected": false, "ring": ring, "phase": pos.x * 0.4})
	_shard_rings.append(ring)


func _build_relic_altar() -> void:
	var root := Node3D.new()
	root.position = ALTAR_POS
	_decor.add_child(root)
	_mesh_cylinder(Vector3(0, 0.35, 0), 0.52, 0.7, _stone_b, Vector3.ZERO, 8, root)
	_mesh_cylinder(Vector3(0, 0.72, 0), 0.32, 0.12, _brass, Vector3.ZERO, 8, root)
	_mesh_torus(Vector3(0, 0.76, 0), 0.55, 0.62, _alpha_glow(Color(0.55, 1.0, 0.85), 0.36, 0.9), Vector3.ZERO, root)
	relic_prism = Node3D.new()
	relic_prism.position = Vector3(0, 1.55, 0)
	root.add_child(relic_prism)
	_mesh_cone(Vector3(0, 0.26, 0), 0.0, 0.26, 0.55, _glow_teal, Vector3.ZERO, 6, relic_prism)
	_mesh_cone(Vector3(0, -0.26, 0), 0.0, 0.26, 0.55, _glow_teal, Vector3(PI, 0, 0), 6, relic_prism)
	_relic_ring = Node3D.new()
	relic_prism.add_child(_relic_ring)
	_mesh_torus(Vector3.ZERO, 0.44, 0.48, _alpha_glow(Color(0.7, 1.0, 0.86), 0.7, 1.2), Vector3(PI * 0.4, 0.3, 0), _relic_ring)
	_relic_light = OmniLight3D.new()
	_relic_light.light_color = Color(0.5, 1.0, 0.85)
	_relic_light.light_energy = 1.1
	_relic_light.omni_range = 4.0
	_relic_light.shadow_enabled = false
	root.add_child(_relic_light)
	# 碑文与断轴
	_mesh_box(Vector3(0.95, 1.0, 0), Vector3(0.16, 2.0, 0.8), _stone_b).rotation.z = -0.08
	_mesh_box(Vector3(-0.85, 0.35, 0.2), Vector3(0.5, 0.3, 1.4), _stone_b).rotation.y = 0.12


# ------------------------------------------------------------------ 漂浮碎片 / 尘埃

func _build_fragments() -> void:
	var positions := [
		Vector3(-5.5, 2.2, 2.8), Vector3(-2.8, 3.1, -2.0), Vector3(4.4, 2.0, 3.4),
		Vector3(5.8, 3.4, -5.2), Vector3(1.2, 4.1, -6.4), Vector3(-6.4, 4.2, -6.1),
		Vector3(2.5, 2.4, 7.2), Vector3(-1.0, 5.2, 0.5),
		Vector3(0.8, 2.4, -16.5), Vector3(-2.1, 3.8, -19.8), Vector3(3.2, 4.4, -24.5),
		Vector3(-4.8, 2.8, -27.0), Vector3(6.2, 3.2, -20.6),
		Vector3(21.0, 3.1, -18.2), Vector3(25.2, 5.4, -24.0), Vector3(31.0, 2.7, -15.4),
		Vector3(34.4, 4.8, -27.0), Vector3(22.8, 6.2, -28.4), Vector3(30.4, 3.2, -30.0),
		Vector3(26.0, 2.4, -12.8), Vector3(35.2, 5.4, -21.0),
		Vector3(-14.2, 2.2, -20.0), Vector3(-17.0, 4.3, -22.0), Vector3(-19.4, 2.9, -23.5),
	]
	var colors := [_glow_teal, _glow_gold, _glow_rose]
	for i in positions.size():
		var mat := colors[i % colors.size()].duplicate() as StandardMaterial3D
		if i % 5 == 0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.albedo_color = Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b, 0.35)
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.32, 0.025, 0.12) if i % 2 == 0 else Vector3(0.12, 0.16, 0.035)
		mesh_instance.mesh = box
		mesh_instance.material_override = mat
		mesh_instance.position = positions[i]
		mesh_instance.rotation = Vector3(float(i) * 0.7, float(i) * 1.1, float(i) * 0.4)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_decor.add_child(mesh_instance)
		floaters.append({
			"node": mesh_instance,
			"base": positions[i],
			"phase": float(i) * 0.77,
			"spin": 0.12 + 0.03 * float(i % 4),
		})


func _build_dust() -> void:
	_dust_particles(Vector3(0, 1.8, -1.0), Color(0.5, 0.95, 0.85), 34, 6.0)
	_dust_particles(Vector3(28, 2.5, -22.0), Color(0.95, 0.52, 0.72), 42, 8.0)
	_dust_particles(Vector3(-17, 2.0, -22.0), Color(0.55, 0.95, 0.82), 18, 3.5)


func _dust_particles(center: Vector3, color: Color, amount: int, radius: float) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 7.5
	particles.preprocess = 4.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.gravity = Vector3(0.03, 0.02, 0.0)
	particles.initial_velocity_min = 0.08
	particles.initial_velocity_max = 0.35
	particles.scale_amount_min = 0.55
	particles.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.055, 0.055)
	particles.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	particles.material_override = mat
	particles.position = center
	particles.emitting = true
	add_child(particles)


# ------------------------------------------------------------------ 动画与门控

func animate_level(delta: float) -> void:
	_time += delta
	for item in floaters:
		var node: Node3D = item["node"]
		var base: Vector3 = item["base"]
		var phase: float = item["phase"]
		node.position = base + Vector3(sin(_time * 0.45 + phase) * 0.18, sin(_time * 0.72 + phase * 1.7) * 0.24, cos(_time * 0.38 + phase) * 0.12)
		node.rotation.y += delta * float(item["spin"])
		node.rotation.x += delta * float(item["spin"]) * 0.3
	for item in gears:
		var gear_node: Node3D = item["node"]
		gear_node.rotation.z += delta * float(item["speed"])
	for item in lamps:
		var orb: MeshInstance3D = item["orb"]
		var base_y: float = item["base_y"]
		var phase: float = item["phase"]
		orb.position.y = base_y + sin(_time * 1.3 + phase) * 0.06
	for shard in shards:
		if bool(shard["collected"]):
			continue
		var node: Node3D = shard["node"]
		var base: Vector3 = shard["base"]
		node.position.y = base.y + sin(_time * 1.6 + float(shard["phase"])) * 0.1
		node.rotation.y += delta * 0.9
		var ring: Node3D = shard["ring"]
		ring.rotation.y += delta * 1.8
		ring.rotation.z += delta * 0.6
	if relic_prism != null and relic_prism.visible:
		relic_prism.position.y = 1.55 + sin(_time * 1.35) * 0.1
		relic_prism.rotation.y += delta * 0.75
		if _relic_ring != null:
			_relic_ring.rotation.z += delta * 1.2
	if clock_hands != null:
		clock_hands.rotation.z -= delta * 0.11
	if bell != null:
		bell.rotation.z = sin(_time * 0.42) * 0.022
		bell.rotation.x = sin(_time * 0.31 + 1.0) * 0.012
	if barrier_visual != null and barrier_visual.visible and _barrier_mat != null:
		_barrier_mat.albedo_color.a = 0.1 + 0.06 * (0.5 + 0.5 * sin(_time * 2.1))


func set_bridge_open(open: bool) -> void:
	if bridge_root == null:
		return
	bridge_root.visible = open
	bridge_body.collision_layer = 1 if open else 0
	barrier_body.collision_layer = 0 if open else 1
	barrier_visual.visible = not open


func set_relic_taken(taken: bool) -> void:
	if relic_prism != null:
		relic_prism.visible = not taken
	if _relic_light != null:
		_relic_light.light_energy = 0.0 if taken else 1.1


func shard_node(index: int) -> Node3D:
	return shards[index]["node"]
