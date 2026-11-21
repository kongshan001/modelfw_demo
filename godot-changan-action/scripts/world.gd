extends Node3D
class_name ChanganWorld

## 灯市街 — 90m 长安风虚构夜街。所有建筑/灯笼/摊位/鼓楼均为程序化几何，
## 无外部场景素材。低成本策略：重复构件用 MultiMesh，实光 ≤5（月光 + 相机补光
## 由 main 添加 + 三盏街灯），无实时阴影（角色用 blob 阴影）。

const STREET_HALF := 6.0
const STREET_END := 62.0
const PLAZA_HALF := 12.0
const PLAZA_Z := 90.0

const C_NIGHT := Color(0.055, 0.075, 0.155)
const C_WALL := Color(0.115, 0.125, 0.195)
const C_WALL_LIT := Color(0.155, 0.14, 0.19)
const C_WOOD := Color(0.115, 0.075, 0.055)
const C_WOOD_WARM := Color(0.20, 0.125, 0.075)
const C_STONE := Color(0.16, 0.17, 0.22)
const C_STONE_DARK := Color(0.09, 0.10, 0.14)
const C_GOLD := Color(0.98, 0.68, 0.27)
const C_VERMILION := Color(0.62, 0.16, 0.12)
const C_JADE := Color(0.20, 0.46, 0.38)
const C_PAPER := Color(0.94, 0.88, 0.74)

var font: SystemFont
var moon: DirectionalLight3D
var env: Environment
var archway_sign: Label3D

var lamps: Array[Dictionary] = []
var lit_count := 0
var plaza_light: OmniLight3D
var interactables: Array[Dictionary] = []
var lantern_count := 0
var lantern_halos: MultiMeshInstance3D
var lantern_bodies: MultiMeshInstance3D

var dark_active := false
var dark_timer := 0.0
var _dark_duration := 0.0
var _moon_base := 1.55
var _ambient_base := 0.98
var _fog_base := 0.0048
var _flicker_t := 0.0
var _lantern_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D

var ahe_pos := Vector3(-4.35, 0.0, 12.6)
var wenjiu_pos := Vector3(3.25, 0.0, 55.5)
var drum_pos := Vector3(4.7, 0.0, 57.2)
var player_spawn := Vector3(0.0, 0.05, 2.0)


func _ready() -> void:
	_build_font()
	_build_environment()
	_build_ground()
	_build_street_facades()
	_build_plaza()
	_build_archway()
	_build_stalls()
	_build_noodle_stall()
	_build_drum_tower()
	_build_hanging_lanterns()
	_build_street_lamps()
	_build_distant_roofs()
	_build_boundaries()
	_build_atmosphere()
	print("CHANGAN_WORLD_READY lanterns=%d lamps=%d" % [lantern_count, lamps.size()])


func _build_font() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
		"Microsoft YaHei", "Arial Unicode MS", "sans-serif",
	])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY


# ── helpers ─────────────────────────────────────────────────────────────────

func _mat(color: Color, roughness := 0.86, metallic := 0.0,
		emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	m.disable_receive_shadows = true
	return m


func _unshaded(color: Color, alpha := 1.0, additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_receive_shadows = true
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float,
		mat: Material, rot := Vector3.ZERO, sides := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _multimesh(parent: Node3D, mesh: Mesh, xforms: Array[Transform3D],
		colors: Array[Color], mat: Material) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


func _label(parent: Node3D, text: String, pos: Vector3, size := 40,
		color := C_GOLD, yaw := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.outline_size = maxi(6, size / 5)
	l.outline_modulate = Color(0.02, 0.02, 0.04, 0.95)
	l.modulate = color
	l.pixel_size = 0.0038
	l.position = pos
	l.rotation.y = yaw
	l.no_depth_test = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(l)
	return l


# ── environment ─────────────────────────────────────────────────────────────

func _build_environment() -> void:
	env = Environment.new()
	# 平涂夜空 + 星点：比 ProceduralSky 便宜约 5–7 fps（Intel HD 实测）
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.024, 0.034, 0.078)
	env.background_energy_multiplier = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.44, 0.70)
	env.ambient_light_energy = _ambient_base
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.11, 0.135, 0.245)
	env.fog_light_energy = 0.85
	env.fog_density = _fog_base
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.30
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_energy = _moon_base
	moon.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	moon.shadow_enabled = false
	add_child(moon)

	# 月亮：远景发光盘 + 柔光 billboard（无实光）
	var moon_mat := _unshaded(Color(0.92, 0.94, 1.0), 0.95, true)
	var moon_disc := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.0
	sm.height = 6.0
	sm.radial_segments = 24
	sm.rings = 12
	moon_disc.mesh = sm
	moon_disc.material_override = moon_mat
	moon_disc.position = Vector3(46.0, 58.0, 118.0)
	moon_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon_disc)
	var halo := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(16, 16)
	halo.mesh = qm
	var hm := _unshaded(Color(0.55, 0.66, 1.0), 0.24, true)
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo.material_override = hm
	halo.position = moon_disc.position
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)

	# 星点（1 个 MultiMesh draw）
	var star_quad := QuadMesh.new()
	star_quad.size = Vector2(0.35, 0.35)
	var star_mat := _unshaded(Color(0.82, 0.88, 1.0), 0.65, true)
	star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var star_xf: Array[Transform3D] = []
	for i in 140:
		var a := rng.randf_range(0.0, TAU)
		var y := rng.randf_range(24.0, 95.0)
		var r := rng.randf_range(80.0, 150.0)
		star_xf.append(Transform3D(Basis(), Vector3(cos(a) * r, y, sin(a) * r)))
	_multimesh(self, star_quad, star_xf, [], star_mat)


func _build_ground() -> void:
	var stone := _mat(C_STONE)
	var stone_dark := _mat(C_STONE_DARK)
	_box(self, Vector3(0, -0.16, 31.0), Vector3(13.0, 0.3, 63.0), stone_dark)
	_box(self, Vector3(0, -0.16, 76.0), Vector3(25.8, 0.3, 28.0), stone_dark)
	# 地面碰撞（视觉地面本身不是碰撞体，缺了它会掉出街）
	var floor_body := StaticBody3D.new()
	floor_body.name = "GroundCollision"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(26.5, 0.4, 92.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.2, 45.0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	_box(self, Vector3(0, -0.02, 31.0), Vector3(12.4, 0.06, 62.0), _mat(Color(0.155, 0.165, 0.215)))
	_box(self, Vector3(0, -0.02, 76.0), Vector3(25.2, 0.06, 27.6), _mat(Color(0.145, 0.155, 0.205)))

	# 石板：MultiMesh，一个 draw call
	var slab := BoxMesh.new()
	slab.size = Vector3(1.62, 0.035, 1.08)
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1447
	for z in range(0, 91, 2):
		var half := STREET_HALF - 0.35
		if z >= 62:
			half = PLAZA_HALF - 0.6
		var x := -half + 0.85
		while x < half:
			var jitter := Vector3(rng.randf_range(-0.08, 0.08), 0.0, rng.randf_range(-0.05, 0.05))
			xforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.02, 0.02)),
				Vector3(x, 0.005, z + jitter.z)))
			var g := rng.randf_range(0.14, 0.235)
			colors.append(Color(g * 0.92, g * 0.96, g * 1.18))
			x += 1.78
	var slab_mat := StandardMaterial3D.new()
	slab_mat.vertex_color_use_as_albedo = true
	slab_mat.roughness = 0.9
	slab_mat.disable_receive_shadows = true
	_multimesh(self, slab, xforms, colors, slab_mat)

	# 街道中线与排水沟
	_box(self, Vector3(0, 0.008, 30.5), Vector3(0.14, 0.02, 59.0), _mat(Color(0.08, 0.09, 0.13)))
	for side in [-1.0, 1.0]:
		_box(self, Vector3(side * 5.92, 0.035, 30.5), Vector3(0.26, 0.07, 60.0), stone)
		_box(self, Vector3(side * (PLAZA_HALF - 0.35), 0.035, 76.0), Vector3(0.3, 0.07, 27.0), stone)


# ── street facades ──────────────────────────────────────────────────────────

func _build_street_facades() -> void:
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(0.55, 5.4, 3.95)
	var eave_mesh := BoxMesh.new()
	eave_mesh.size = Vector3(1.15, 0.16, 4.2)
	var column_mesh := BoxMesh.new()
	column_mesh.size = Vector3(0.24, 5.1, 0.24)
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(0.08, 0.78, 1.02)
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.08, 2.0, 1.15)
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.10, 0.06, 1.05)

	var walls: Array[Transform3D] = []
	var wall_cols: Array[Color] = []
	var eaves: Array[Transform3D] = []
	var eave_cols: Array[Color] = []
	var columns: Array[Transform3D] = []
	var windows: Array[Transform3D] = []
	var win_cols: Array[Color] = []
	var doors: Array[Transform3D] = []
	var bars: Array[Transform3D] = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for side in [-1.0, 1.0]:
		var x := float(side) * 6.55
		for z in range(2, 62, 4):
			walls.append(Transform3D(Basis(), Vector3(x, 2.7, z + 2.0)))
			var warm := rng.randf() < 0.38
			wall_cols.append(C_WALL_LIT if warm else C_WALL)
			eaves.append(Transform3D(Basis(Vector3.BACK, side * 0.16), Vector3(x - side * 0.22, 5.35, z + 2.0)))
			eave_cols.append(C_WOOD)
			for dz in [-2.0, 2.0]:
				columns.append(Transform3D(Basis(), Vector3(side * 6.28, 2.55, z + dz + 2.0)))
			var count := 2 if rng.randf() < 0.55 else 1
			for k in count:
				var wy := 2.35 + k * 1.35 + rng.randf_range(-0.1, 0.1)
				var wz := z + 1.0 + rng.randf_range(0.1, 1.8)
				windows.append(Transform3D(Basis(), Vector3(side * 6.265, wy, wz)))
				win_cols.append(Color(1.0, 0.62 + rng.randf_range(0.0, 0.2), 0.3))
				bars.append(Transform3D(Basis(), Vector3(side * 6.22, wy, wz)))
			if rng.randf() < 0.4:
				doors.append(Transform3D(Basis(), Vector3(side * 6.26, 1.0, z + rng.randf_range(0.6, 3.2))))

	var wall_mat := StandardMaterial3D.new()
	wall_mat.vertex_color_use_as_albedo = true
	wall_mat.roughness = 0.94
	wall_mat.disable_receive_shadows = true
	_multimesh(self, wall_mesh, walls, wall_cols, wall_mat)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.vertex_color_use_as_albedo = true
	roof_mat.roughness = 0.8
	_multimesh(self, eave_mesh, eaves, eave_cols, roof_mat)
	_multimesh(self, column_mesh, columns, [], _mat(C_WOOD))
	var win_mat := StandardMaterial3D.new()
	win_mat.vertex_color_use_as_albedo = true
	win_mat.emission_enabled = true
	win_mat.emission = Color(1.0, 0.62, 0.26)
	win_mat.emission_energy_multiplier = 0.55
	win_mat.roughness = 0.55
	_multimesh(self, window_mesh, windows, win_cols, win_mat)
	_multimesh(self, door_mesh, doors, [], _mat(C_WOOD_WARM))
	_multimesh(self, bar_mesh, bars, [], _mat(Color(0.40, 0.16, 0.10)))

	# 屋顶轮廓
	var roof_boxes: Array[Transform3D] = []
	var roof_cols: Array[Color] = []
	for side in [-1.0, 1.0]:
		for z in range(0, 62, 8):
			roof_boxes.append(Transform3D(Basis(Vector3.BACK, side * 0.30),
				Vector3(side * 7.2, 5.8, z + 3.0)))
			roof_cols.append(Color(0.075, 0.085, 0.13))
	var roof_long := BoxMesh.new()
	roof_long.size = Vector3(2.3, 0.22, 8.4)
	_multimesh(self, roof_long, roof_boxes, roof_cols, wall_mat)


func _build_plaza() -> void:
	var wall := _mat(Color(0.115, 0.115, 0.18))
	for side in [-1.0, 1.0]:
		_box(self, Vector3(side * 12.65, 4.5, 76.0), Vector3(0.6, 9.0, 28.0), wall)
		_box(self, Vector3(side * 12.4, 9.1, 76.0), Vector3(1.4, 0.3, 28.6), _mat(C_WOOD))
		for z in range(64, 90, 6):
			_box(self, Vector3(side * 12.32, 2.4, z), Vector3(0.1, 1.0, 1.3),
				_mat(Color(0.9, 0.5, 0.2), 0.7, 0.0, Color(1.0, 0.55, 0.2), 0.55))
	_box(self, Vector3(0, 5.0, 90.0), Vector3(25.8, 10.0, 0.6), wall)
	_box(self, Vector3(0, 1.0, 61.8), Vector3(25.8, 2.0, 0.5), _mat(Color(0.10, 0.10, 0.16)))
	# 广场入口门柱
	for side in [-1.0, 1.0]:
		_box(self, Vector3(side * 6.4, 3.4, 62.0), Vector3(0.8, 6.8, 0.8), _mat(C_WOOD))
		_box(self, Vector3(side * 6.4, 7.0, 62.0), Vector3(1.5, 0.25, 1.2), _mat(C_WOOD))
	_box(self, Vector3(0, 7.4, 62.0), Vector3(13.0, 0.5, 0.9), _mat(C_WOOD))
	_label(self, "鼓楼", Vector3(0, 6.35, 61.55), 52, C_GOLD, PI)
	# 火盆（合并为两个 MultiMesh）
	var brazier_positions := [Vector3(-9.2, 0.0, 67.0), Vector3(9.2, 0.0, 67.0),
		Vector3(-9.6, 0.0, 82.0), Vector3(9.6, 0.0, 82.0)]
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.7, 0.7, 0.7)
	var fire_mesh := SphereMesh.new()
	fire_mesh.radius = 0.26
	fire_mesh.height = 0.85
	var base_xf: Array[Transform3D] = []
	var fire_xf: Array[Transform3D] = []
	for p in brazier_positions:
		base_xf.append(Transform3D(Basis(), p + Vector3(0, 0.35, 0)))
		fire_xf.append(Transform3D(Basis(), p + Vector3(0, 1.05, 0)))
	_multimesh(self, base_mesh, base_xf, [], _mat(Color(0.16, 0.12, 0.1)))
	_multimesh(self, fire_mesh, fire_xf, [], _unshaded(Color(1.0, 0.48, 0.14), 0.9, true))

	# 鼓楼前灯串：Boss 战的可读光源（正常关闭；熄灯时启用，仍保持 ≤5 实光）
	var plaza_lantern_positions := [Vector3(-3.2, 4.4, 72.0), Vector3(0.0, 4.7, 73.4),
		Vector3(3.2, 4.4, 72.0), Vector3(-3.2, 4.4, 80.0), Vector3(0.0, 4.7, 81.2),
		Vector3(3.2, 4.4, 80.0)]
	var pl_body := CylinderMesh.new()
	pl_body.top_radius = 0.25
	pl_body.bottom_radius = 0.27
	pl_body.height = 0.46
	pl_body.radial_segments = 10
	var pl_mat := StandardMaterial3D.new()
	pl_mat.albedo_color = Color(1.0, 0.62, 0.28)
	pl_mat.emission_enabled = true
	pl_mat.emission = Color(1.0, 0.46, 0.16)
	pl_mat.emission_energy_multiplier = 0.95
	var pl_xf: Array[Transform3D] = []
	for p in plaza_lantern_positions:
		pl_xf.append(Transform3D(Basis(), p))
	var pl_halo_mesh := QuadMesh.new()
	pl_halo_mesh.size = Vector2(0.95, 0.95)
	var pl_halo_mat := _unshaded(Color(1.0, 0.46, 0.16), 0.22, true)
	pl_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pl_halo_mat.albedo_texture = _soft_texture(48)
	_multimesh(self, pl_body, pl_xf, [], pl_mat)
	_multimesh(self, pl_halo_mesh, pl_xf, [], pl_halo_mat)
	plaza_light = OmniLight3D.new()
	plaza_light.light_color = Color(1.0, 0.58, 0.26)
	plaza_light.light_energy = 0.0
	plaza_light.omni_range = 20.0
	plaza_light.omni_attenuation = 1.1
	plaza_light.shadow_enabled = false
	plaza_light.position = Vector3(0.0, 3.6, 76.0)
	add_child(plaza_light)


func _build_archway() -> void:
	var root := Node3D.new()
	root.name = "Archway"
	root.position = Vector3(0, 0, 8)
	add_child(root)
	var wood := _mat(C_WOOD_WARM)
	var verm := _mat(C_VERMILION, 0.7)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(side * 4.7, 0.3, 0), Vector3(1.0, 0.6, 1.0), _mat(C_STONE))
		_box(root, Vector3(side * 4.7, 3.4, 0), Vector3(0.46, 6.2, 0.46), wood)
		_box(root, Vector3(side * 4.4, 3.2, 0), Vector3(0.12, 5.0, 0.12), verm)
	_box(root, Vector3(0, 5.9, 0), Vector3(10.4, 0.44, 0.6), wood)
	_box(root, Vector3(0, 6.55, 0), Vector3(11.2, 0.32, 0.85), wood)
	_box(root, Vector3(0, 6.95, 0), Vector3(12.0, 0.20, 2.3), _mat(Color(0.075, 0.085, 0.14)))
	_box(root, Vector3(0, 7.18, 0), Vector3(10.4, 0.16, 1.8), _mat(Color(0.09, 0.10, 0.16)))
	archway_sign = _label(root, "灯 市 街", Vector3(0, 5.05, -0.33), 64, C_GOLD, PI)
	# 牌楼挂灯
	for side in [-1.0, 1.0]:
		_lantern_mesh(root, Vector3(side * 3.1, 4.9, 0.0), 0.30, Color(1.0, 0.42, 0.16))
	# 牌楼柱碰撞
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	for side in [-1.0, 1.0]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.7, 6.4, 0.7)
		cs.shape = bs
		cs.position = Vector3(side * 4.7, 3.2, 0)
		sb.add_child(cs)
	root.add_child(sb)


func _build_stalls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var defs := [
		[Vector3(-4.65, 0, 23.0), 0.0, C_VERMILION],
		[Vector3(4.65, 0, 27.0), PI, C_JADE],
		[Vector3(-4.65, 0, 35.5), 0.0, C_JADE],
		[Vector3(4.65, 0, 38.5), PI, C_VERMILION],
		[Vector3(-4.65, 0, 47.0), 0.0, Color(0.45, 0.30, 0.55)],
		[Vector3(4.65, 0, 49.5), PI, C_VERMILION],
	]
	var counter_mesh := BoxMesh.new()
	counter_mesh.size = Vector3(2.5, 0.12, 1.15)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.10, 3.0, 0.10)
	var awning_mesh := BoxMesh.new()
	awning_mesh.size = Vector3(2.65, 0.06, 1.9)
	var front_mesh := BoxMesh.new()
	front_mesh.size = Vector3(2.5, 0.4, 0.05)
	var goods_mesh := BoxMesh.new()
	goods_mesh.size = Vector3(0.34, 0.22, 0.28)
	var lantern_mesh := SphereMesh.new()
	lantern_mesh.radius = 0.17
	lantern_mesh.height = 0.30
	lantern_mesh.radial_segments = 10
	lantern_mesh.rings = 6
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(0.62, 0.62)

	var counters: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var awnings: Array[Transform3D] = []
	var awning_cols: Array[Color] = []
	var fronts: Array[Transform3D] = []
	var front_cols: Array[Color] = []
	var goods: Array[Transform3D] = []
	var goods_cols: Array[Color] = []
	var lanterns: Array[Transform3D] = []
	var halos: Array[Transform3D] = []
	for d in defs:
		var pos: Vector3 = d[0]
		var yaw: float = d[1]
		var cloth: Color = d[2]
		var b := Basis(Vector3.UP, yaw)
		counters.append(Transform3D(b, pos + b * Vector3(0, 0.82, 0)))
		for sx in [-1.0, 1.0]:
			posts.append(Transform3D(b, pos + b * Vector3(sx * 1.05, 1.5, 0.45)))
		awnings.append(Transform3D(b * Basis(Vector3.RIGHT, 0.13), pos + b * Vector3(0, 2.68, 0)))
		awning_cols.append(cloth)
		fronts.append(Transform3D(b, pos + b * Vector3(0, 2.45, 0.92)))
		front_cols.append(cloth)
		for i in 3:
			var gp := Vector3(-0.75 + i * 0.7, 1.0, -0.1 + rng.randf_range(-0.2, 0.2))
			goods.append(Transform3D(b, pos + b * gp))
			goods_cols.append([C_JADE, C_VERMILION, Color(0.8, 0.62, 0.24)][i % 3])
		var lp := pos + b * Vector3(1.25, 2.35, 0.9)
		lanterns.append(Transform3D(Basis(), lp))
		halos.append(Transform3D(Basis(), lp))
		# 摊位碰撞
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.6, 1.2, 1.3)
		cs.shape = bs
		cs.position = Vector3(0, 0.6, 0)
		sb.add_child(cs)
		sb.position = pos
		sb.rotation.y = yaw
		add_child(sb)

	var wood := _mat(C_WOOD_WARM)
	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.vertex_color_use_as_albedo = true
	cloth_mat.roughness = 0.9
	var goods_mat := StandardMaterial3D.new()
	goods_mat.vertex_color_use_as_albedo = true
	goods_mat.roughness = 0.85
	var lantern_mat := StandardMaterial3D.new()
	lantern_mat.albedo_color = Color(1.0, 0.95, 0.9)
	lantern_mat.emission_enabled = true
	lantern_mat.emission = Color(1.0, 0.45, 0.16)
	lantern_mat.emission_energy_multiplier = 0.9
	var halo_mat := _unshaded(Color(1.0, 0.45, 0.16), 0.24, true)
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_mat.albedo_texture = _soft_texture(48)
	_multimesh(self, counter_mesh, counters, [], wood).visibility_range_end = 44.0
	_multimesh(self, post_mesh, posts, [], wood).visibility_range_end = 44.0
	_multimesh(self, awning_mesh, awnings, awning_cols, cloth_mat).visibility_range_end = 44.0
	_multimesh(self, front_mesh, fronts, front_cols, cloth_mat).visibility_range_end = 44.0
	_multimesh(self, goods_mesh, goods, goods_cols, goods_mat).visibility_range_end = 44.0
	_multimesh(self, lantern_mesh, lanterns, [], lantern_mat).visibility_range_end = 44.0
	_multimesh(self, halo_mesh, halos, [], halo_mat).visibility_range_end = 44.0

	# 酒坛 / 竹筐（合并为 2 个 MultiMesh）
	var jar_mesh := CylinderMesh.new()
	jar_mesh.top_radius = 0.28
	jar_mesh.bottom_radius = 0.28
	jar_mesh.height = 0.68
	jar_mesh.radial_segments = 8
	var jar_top := CylinderMesh.new()
	jar_top.top_radius = 0.12
	jar_top.bottom_radius = 0.12
	jar_top.height = 0.10
	jar_top.radial_segments = 6
	var basket_mesh := CylinderMesh.new()
	basket_mesh.top_radius = 0.34
	basket_mesh.bottom_radius = 0.34
	basket_mesh.height = 0.6
	basket_mesh.radial_segments = 8
	var jar_xf: Array[Transform3D] = []
	var jar_top_xf: Array[Transform3D] = []
	var basket_xf: Array[Transform3D] = []
	for p in [Vector3(-5.0, 0.0, 29.8), Vector3(-4.5, 0.0, 30.6), Vector3(5.0, 0.0, 41.5), Vector3(-5.1, 0.0, 46.0)]:
		jar_xf.append(Transform3D(Basis(), p + Vector3(0, 0.34, 0)))
		jar_top_xf.append(Transform3D(Basis(), p + Vector3(0, 0.70, 0)))
	for p in [Vector3(4.9, 0.0, 31.0), Vector3(-4.7, 0.0, 42.8), Vector3(4.4, 0.0, 46.0)]:
		basket_xf.append(Transform3D(Basis(), p + Vector3(0, 0.3, 0)))
	var jar_mat := _mat(Color(0.24, 0.20, 0.17), 0.55)
	var basket_mat := _mat(Color(0.36, 0.28, 0.16), 0.9)
	_multimesh(self, jar_mesh, jar_xf, [], jar_mat)
	_multimesh(self, jar_top, jar_top_xf, [], jar_mat)
	_multimesh(self, basket_mesh, basket_xf, [], basket_mat)


func _build_noodle_stall() -> void:
	var root := Node3D.new()
	root.name = "NoodleStall"
	root.position = Vector3(-4.75, 0, 12.6)
	root.rotation.y = 0.0
	add_child(root)
	var wood := _mat(C_WOOD_WARM)
	_box(root, Vector3(0, 0.85, 0.0), Vector3(2.6, 0.14, 1.15), wood)
	_box(root, Vector3(0, 0.4, 0.0), Vector3(2.4, 0.8, 1.0), _mat(Color(0.16, 0.11, 0.08)))
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(sx * 1.1, 1.5, 0.5), Vector3(0.11, 3.0, 0.11), wood)
	_box(root, Vector3(0, 2.78, 0.0), Vector3(2.9, 0.07, 1.95), _mat(C_VERMILION, 0.9), Vector3(0.13, 0, 0))
	_box(root, Vector3(0, 2.48, 0.95), Vector3(2.7, 0.36, 0.05), _mat(C_PAPER, 0.9))
	_label(root, "阿禾面摊", Vector3(0, 2.50, 0.99), 34, C_VERMILION, 0.0)
	# 汤锅 + 蒸汽
	_cyl(root, Vector3(-0.55, 1.05, 0.15), 0.30, 0.26, _mat(Color(0.22, 0.22, 0.24), 0.4, 0.6))
	_cyl(root, Vector3(-0.55, 1.16, 0.15), 0.22, 0.06, _mat(Color(0.75, 0.62, 0.35), 0.6))
	for i in 4:
		_cyl(root, Vector3(-0.1 + i * 0.18, 0.98, 0.15), 0.07, 0.05, _mat(C_PAPER, 0.5), Vector3.ZERO, 8)
	var steam := CPUParticles3D.new()
	steam.amount = 22
	steam.lifetime = 1.6
	steam.local_coords = false
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.20
	steam.direction = Vector3.UP
	steam.spread = 16.0
	steam.gravity = Vector3(0, 0.35, 0)
	steam.initial_velocity_min = 0.25
	steam.initial_velocity_max = 0.55
	steam.scale_amount_min = 0.25
	steam.scale_amount_max = 0.55
	steam.color = Color(0.85, 0.87, 0.9, 0.22)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.28, 0.28)
	var pm := _unshaded(Color(0.9, 0.9, 0.95), 0.30)
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = pm
	steam.mesh = qm
	steam.position = Vector3(-0.55, 1.25, 0.15)
	steam.emitting = true
	root.add_child(steam)
	_lantern_mesh(root, Vector3(1.35, 2.42, 0.92), 0.20, Color(1.0, 0.5, 0.18))
	for i in 2:
		_cyl(root, Vector3(0.55 + i * 0.55, 0.24, 1.05), 0.20, 0.05, wood, Vector3.ZERO, 8)
		_cyl(root, Vector3(0.55 + i * 0.55, 0.42, 1.05), 0.05, 0.36, wood, Vector3.ZERO, 8)
	# 告示牌
	var sign := Node3D.new()
	sign.position = Vector3(-1.05, 0, -1.30)
	sign.rotation.y = 0.35
	root.add_child(sign)
	_cyl(sign, Vector3(0, 0.7, 0), 0.05, 1.4, wood, Vector3.ZERO, 6)
	_box(sign, Vector3(0, 1.45, 0), Vector3(0.85, 0.62, 0.05), _mat(C_PAPER, 0.9))
	_label(sign, "灯市夜禁", Vector3(0, 1.45, 0.04), 24, Color(0.25, 0.12, 0.08))
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.7, 1.2, 1.3)
	cs.shape = bs
	cs.position = Vector3(0, 0.6, 0)
	sb.add_child(cs)
	root.add_child(sb)


func _build_drum_tower() -> void:
	var root := Node3D.new()
	root.name = "DrumTower"
	root.position = Vector3(0, 0, 84.5)
	add_child(root)
	var wood := _mat(Color(0.16, 0.10, 0.075))
	var wall := _mat(Color(0.13, 0.12, 0.17))
	var roof := _mat(Color(0.07, 0.08, 0.13))
	_box(root, Vector3(0, 0.6, 0), Vector3(12.0, 1.2, 8.0), _mat(Color(0.12, 0.12, 0.16)))
	_box(root, Vector3(0, 3.6, 0), Vector3(8.0, 6.0, 6.4), wall)
	for sx in [-1.0, 1.0]:
		for zz in [-3.0, 3.0]:
			_box(root, Vector3(sx * 4.0, 3.4, zz), Vector3(0.3, 6.6, 0.3), wood)
	_box(root, Vector3(0, 7.6, 0), Vector3(9.4, 0.4, 7.4), roof)
	_box(root, Vector3(0, 9.0, 0), Vector3(6.2, 2.8, 5.0), wall)
	_box(root, Vector3(0, 10.6, 0), Vector3(7.2, 0.32, 5.8), roof)
	_box(root, Vector3(0, 11.1, 0), Vector3(5.8, 0.3, 4.6), roof)
	for i in 2:
		_box(root, Vector3(0, 1.5 + i * 2.2, 3.24), Vector3(1.1, 1.4, 0.08),
			_mat(Color(0.95, 0.55, 0.22), 0.7, 0.0, Color(1.0, 0.55, 0.2), 0.8))
	_box(root, Vector3(0, 2.7, 3.26), Vector3(2.4, 0.12, 0.10), wood)
	_label(root, "鼓 楼", Vector3(0, 6.7, 3.35), 56, C_GOLD)
	# 楼前朱砂幡：Boss 战背景的暖气与地标
	for sx in [-1.0, 1.0]:
		var banner := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.25, 3.1, 0.06)
		banner.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.42, 0.08, 0.06)
		bmat.emission_enabled = true
		bmat.emission = Color(0.55, 0.10, 0.05)
		bmat.emission_energy_multiplier = 0.35
		bmat.roughness = 0.9
		banner.material_override = bmat
		banner.position = Vector3(sx * 3.0, 4.8, 3.26)
		banner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(banner)
		_box(root, Vector3(sx * 3.0, 6.40, 3.30), Vector3(1.4, 0.10, 0.10), _mat(Color(0.78, 0.56, 0.22), 0.4, 0.6))
		_box(root, Vector3(sx * 3.0, 3.22, 3.30), Vector3(1.4, 0.10, 0.10), _mat(Color(0.78, 0.56, 0.22), 0.4, 0.6))
	# 大鼓（在广场上，闻九身边）
	var drum := Node3D.new()
	drum.name = "Drum"
	drum.position = Vector3(4.7, 0, 57.2)
	add_child(drum)
	_cyl(drum, Vector3(0, 0.55, 0), 0.85, 1.1, _mat(Color(0.42, 0.12, 0.09), 0.7), Vector3.ZERO, 20)
	_cyl(drum, Vector3(0, 0.55, 0.56), 0.86, 0.04, _mat(Color(0.85, 0.72, 0.5), 0.85), Vector3.ZERO, 20)
	_cyl(drum, Vector3(0, 0.55, -0.56), 0.86, 0.04, _mat(Color(0.85, 0.72, 0.5), 0.85), Vector3.ZERO, 20)
	for sx in [-1.0, 1.0]:
		_box(drum, Vector3(sx * 1.15, 0.9, 0), Vector3(0.18, 1.8, 0.18), wood)
	# 鼓楼广场：楼前大鼓 + 暖窗格（Boss 战背景地标）
	var plaza_drum := Node3D.new()
	plaza_drum.name = "PlazaDrum"
	plaza_drum.position = Vector3(0, 0, 79.4)
	add_child(plaza_drum)
	_box(plaza_drum, Vector3(0, 0.12, 0), Vector3(4.0, 0.24, 2.4), _mat(Color(0.14, 0.12, 0.14)))
	_cyl(plaza_drum, Vector3(0, 1.18, 0), 1.25, 1.7,
		_mat(Color(0.38, 0.09, 0.07), 0.75), Vector3.ZERO, 22)
	_cyl(plaza_drum, Vector3(0, 1.18, 0.86), 1.27, 0.05,
		_mat(Color(0.78, 0.62, 0.40), 0.8), Vector3.ZERO, 22)
	_cyl(plaza_drum, Vector3(0, 1.18, -0.86), 1.27, 0.05,
		_mat(Color(0.78, 0.62, 0.40), 0.8), Vector3.ZERO, 22)
	for sx in [-1.0, 1.0]:
		_box(plaza_drum, Vector3(sx * 1.55, 1.25, 0), Vector3(0.20, 2.5, 0.20), wood)
	for i in 3:
		_box(root, Vector3(0, 2.3 + i * 1.8, 3.27), Vector3(2.6, 0.18, 0.06),
			_mat(Color(0.95, 0.55, 0.22), 0.7, 0.0, Color(1.0, 0.55, 0.2), 0.8))
		_box(root, Vector3(0, 3.6 + i * 1.9, 3.27), Vector3(3.2, 1.25, 0.06),
			_mat(Color(0.38, 0.10, 0.07), 0.9, 0.0, Color(0.5, 0.10, 0.05), 0.35))
	# 鼓架碰撞
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(12.0, 8.0, 8.0)
	cs.shape = bs
	cs.position = Vector3(0, 4.0, 0)
	sb.add_child(cs)
	root.add_child(sb)


# ── lanterns ────────────────────────────────────────────────────────────────

func _soft_texture(size := 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5).length() / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _lantern_mesh(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = color.darkened(0.20)
	body_mat.emission_enabled = true
	body_mat.emission = color
	body_mat.emission_energy_multiplier = 0.95
	body_mat.roughness = 0.65
	body_mat.disable_receive_shadows = true
	_cyl(root, Vector3.ZERO, radius, radius * 1.7, body_mat, Vector3.ZERO, 10)
	return _lantern_glow(root, radius, color)


func _lantern_glow(root: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var glow := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius * 0.92
	sm.height = radius * 1.6
	sm.radial_segments = 12
	sm.rings = 6
	glow.mesh = sm
	glow.material_override = _unshaded(color, 0.9, true)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	var halo := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(radius * 4.2, radius * 4.2)
	halo.mesh = qm
	var hm := _unshaded(color, 0.26, true)
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_texture = _soft_texture(48)
	hm.vertex_color_use_as_albedo = true
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	return glow


func _build_hanging_lanterns() -> void:
	var positions: Array[Vector3] = []
	var colors: Array[Color] = []
	var z := 3.0
	var side := -1.0
	while z < 60.0:
		positions.append(Vector3(side * 5.35, 3.62 + (0.06 if int(z) % 8 == 0 else 0.0), z))
		colors.append(Color(1.0, 0.36 + 0.08 * (int(z) % 3), 0.12))
		z += 1.95
		side = -side
	for p in [Vector3(-8.2, 3.8, 66.0), Vector3(8.2, 3.8, 66.0),
			Vector3(-8.6, 3.8, 80.0), Vector3(8.6, 3.8, 80.0),
			Vector3(-3.0, 3.6, 61.0), Vector3(3.0, 3.6, 61.0)]:
		positions.append(p)
		colors.append(Color(1.0, 0.42, 0.16))
	lantern_count = positions.size()

	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.19
	body_mesh.height = 0.34
	body_mesh.radial_segments = 10
	body_mesh.rings = 6
	var body_mat := StandardMaterial3D.new()
	body_mat.vertex_color_use_as_albedo = true
	body_mat.albedo_color = Color(1.0, 0.95, 0.9)
	body_mat.emission_enabled = true
	body_mat.emission = Color(1.0, 0.38, 0.12)
	body_mat.emission_energy_multiplier = 1.5
	body_mat.roughness = 0.6
	var xforms: Array[Transform3D] = []
	for p in positions:
		xforms.append(Transform3D(Basis(), p))
	lantern_bodies = _multimesh(self, body_mesh, xforms, colors, body_mat)

	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(0.42, 0.42)
	_halo_mat = _unshaded(Color(1.0, 0.44, 0.16), 0.16, true)
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_mat.albedo_texture = _soft_texture(48)
	_halo_mat.vertex_color_use_as_albedo = true
	var halos: Array[Transform3D] = []
	for p in positions:
		halos.append(Transform3D(Basis(), p))
	lantern_halos = _multimesh(self, halo_mesh, halos, colors, _halo_mat)

	# 吊绳
	var string_mesh := BoxMesh.new()
	string_mesh.size = Vector3(0.018, 0.85, 0.018)
	var strings: Array[Transform3D] = []
	for p in positions:
		strings.append(Transform3D(Basis(), p + Vector3(0, 0.58, 0)))
	_multimesh(self, string_mesh, strings, [], _mat(Color(0.08, 0.06, 0.05)))
	_lantern_mat = body_mat


func _build_street_lamps() -> void:
	var defs := [
		[Vector3(3.4, 0, 30.0), "灯一"],
		[Vector3(-3.4, 0, 42.0), "灯二"],
		[Vector3(3.4, 0, 52.0), "灯三"],
	]
	var metal := _mat(Color(0.16, 0.15, 0.14), 0.55, 0.5)
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.7, 0.44, 0.7)
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.13, 4.3, 0.13)
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.9, 0.10, 0.10)
	var hanger_mesh := BoxMesh.new()
	hanger_mesh.size = Vector3(0.05, 0.25, 0.05)
	var base_xf: Array[Transform3D] = []
	var pole_xf: Array[Transform3D] = []
	var arm_xf: Array[Transform3D] = []
	var hanger_xf: Array[Transform3D] = []
	for i in defs.size():
		var pos_i: Vector3 = defs[i][0]
		base_xf.append(Transform3D(Basis(), pos_i + Vector3(0, 0.22, 0)))
		pole_xf.append(Transform3D(Basis(), pos_i + Vector3(0, 2.35, 0)))
		arm_xf.append(Transform3D(Basis(), pos_i + Vector3(-0.42, 4.45, 0)))
		hanger_xf.append(Transform3D(Basis(), pos_i + Vector3(-0.84, 4.32, 0)))
	_multimesh(self, base_mesh, base_xf, [], _mat(C_STONE))
	_multimesh(self, pole_mesh, pole_xf, [], metal)
	_multimesh(self, arm_mesh, arm_xf, [], metal)
	_multimesh(self, hanger_mesh, hanger_xf, [], metal)
	for i in defs.size():
		var pos: Vector3 = defs[i][0]
		var root := Node3D.new()
		root.name = "StreetLamp%d" % (i + 1)
		root.position = pos
		add_child(root)
		var glow_mat := StandardMaterial3D.new()
		glow_mat.albedo_color = Color(0.35, 0.20, 0.10)
		glow_mat.emission_enabled = true
		glow_mat.emission = Color(1.0, 0.55, 0.18)
		glow_mat.emission_energy_multiplier = 0.18
		glow_mat.roughness = 0.7
		var body := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.34
		sm.height = 0.62
		sm.radial_segments = 14
		sm.rings = 8
		body.mesh = sm
		body.material_override = glow_mat
		body.position = Vector3(-0.84, 3.92, 0)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(body)
		var halo := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.6, 1.6)
		halo.mesh = qm
		var hm := _unshaded(Color(1.0, 0.52, 0.18), 0.0, true)
		hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		hm.albedo_texture = _soft_texture(48)
		halo.material_override = hm
		halo.position = Vector3(-0.84, 3.92, 0)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(halo)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.68, 0.36)
		light.light_energy = 0.0
		light.omni_range = 12.0
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		light.position = Vector3(-0.84, 3.85, 0)
		root.add_child(light)
		lamps.append({
			"root": root, "body": body, "halo": halo, "light": light,
			"mat": glow_mat, "pos": pos, "lit": false, "name": defs[i][1],
		})
		interactables.append({
			"id": "lamp%d" % i, "pos": pos + Vector3(0, 0, 1.0),
			"radius": 2.2, "prompt": "E  点亮%s街灯" % defs[i][1], "kind": "lamp", "index": i,
		})
	interactables.append({
		"id": "drum", "pos": drum_pos + Vector3(0, 0, 1.2),
		"radius": 2.0, "prompt": "E  敲鼓", "kind": "drum", "index": 0,
	})


func set_street_lamp(index: int, lit: bool) -> void:
	if index < 0 or index >= lamps.size():
		return
	var lamp: Dictionary = lamps[index]
	if lamp["lit"] == lit:
		return
	lamp["lit"] = lit
	lit_count = 0
	for l in lamps:
		if l["lit"]:
			lit_count += 1
	var mat: StandardMaterial3D = lamp["mat"]
	var light: OmniLight3D = lamp["light"]
	var halo: MeshInstance3D = lamp["halo"]
	var target_energy := 2.1 if lit else 0.18
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mat, "emission_energy_multiplier", target_energy, 0.8)
	tw.tween_property(halo.material_override, "albedo_color:a", 0.42 if lit else 0.0, 0.8)
	tw.tween_property(halo, "scale", Vector3.ONE * (1.0 if lit else 0.5), 0.8)
	if lit:
		_spawn_lamp_wash(lamp["pos"])


## 只让玩家附近的一盏街灯使用实光（街道很长；远处灯保持 emissive 可见）。
## 这仍保留“3 盏街灯”的玩法与视觉，但把实光预算压到 moon + camera + 1 盏。
func update_lamp_lights(player_pos: Vector3) -> void:
	for lamp in lamps:
		var light: OmniLight3D = lamp["light"]
		var target := 0.0
		if lamp["lit"] and not dark_active:
			var d := Vector2(lamp["pos"].x - player_pos.x, lamp["pos"].z - player_pos.z).length()
			if d < 18.0:
				target = 2.4 * clampf(1.0 - (d - 10.0) / 8.0, 0.35, 1.0)
		light.light_energy = lerpf(light.light_energy, target, 0.18)


func _spawn_lamp_wash(pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 0.85
	tm.rings = 40
	tm.ring_segments = 6
	ring.mesh = tm
	var rm := _unshaded(Color(1.0, 0.62, 0.28), 0.7, true)
	ring.material_override = rm
	ring.position = pos + Vector3(0, 0.06, 0)
	ring.scale = Vector3(0.4, 1, 0.4)
	add_child(ring)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(5.0, 1, 5.0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(ring.queue_free)


func extinguish(duration: float) -> void:
	dark_active = true
	dark_timer = duration
	_dark_duration = duration
	var tw := create_tween().set_parallel(true)
	# 不把画面压到全黑：保留月光底 + 鼓楼灯串，越少街灯越暗
	var lamp_ratio := clampf(float(lit_count) / 3.0, 0.0, 1.0)
	tw.tween_property(moon, "light_energy", 0.46 + 0.16 * lamp_ratio, 0.6)
	tw.tween_property(env, "ambient_light_energy", 0.48 + 0.16 * lamp_ratio, 0.6)
	tw.tween_property(env, "fog_density", 0.009, 0.6)
	# 关掉远处街灯，启用广场灯串：任意时刻实光 ≤5
	if plaza_light != null:
		tw.tween_property(plaza_light, "light_energy", 0.9 + 0.5 * lamp_ratio, 0.5)


func restore_light() -> void:
	dark_active = false
	dark_timer = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(moon, "light_energy", _moon_base, 0.8)
	tw.tween_property(env, "ambient_light_energy", _ambient_base, 0.8)
	tw.tween_property(env, "fog_density", _fog_base, 0.8)
	if plaza_light != null:
		tw.tween_property(plaza_light, "light_energy", 0.0, 0.7)


func _process(delta: float) -> void:
	_flicker_t += delta
	if _lantern_mat != null:
		_lantern_mat.emission_energy_multiplier = 1.38 + 0.14 * sin(_flicker_t * 2.7) + 0.05 * sin(_flicker_t * 9.1)
	if dark_active:
		dark_timer -= delta
		# 熄灯期间：街灯残余闪烁，Boss 的可读性靠自身橙光
		var k := clampf(dark_timer / maxf(_dark_duration, 0.001), 0.0, 1.0)
		var lamp_ratio := clampf(float(lit_count) / 3.0, 0.0, 1.0)
		moon.light_energy = 0.46 + 0.16 * lamp_ratio + 0.05 * sin(_flicker_t * 7.0) * k
		if plaza_light != null:
			plaza_light.light_energy = (0.9 + 0.5 * lamp_ratio) * (0.90 + 0.10 * sin(_flicker_t * 5.0))
		if dark_timer <= 0.0:
			restore_light()


# ── backdrop / boundaries / atmosphere ─────────────────────────────────────

func _build_distant_roofs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	var xforms: Array[Transform3D] = []
	var cols: Array[Color] = []
	for side in [-1.0, 1.0]:
		for i in 46:
			var z := rng.randf_range(-6.0, 98.0)
			var x := float(side) * rng.randf_range(9.0, 26.0)
			var h := rng.randf_range(3.0, 12.0)
			var w := rng.randf_range(3.0, 7.5)
			xforms.append(Transform3D(
				Basis(Vector3.UP, rng.randf_range(-0.12, 0.12)).scaled(Vector3(w, h, w * 0.7)),
				Vector3(x, h * 0.5, z)))
			cols.append(Color(0.035, 0.045, 0.085).lightened(rng.randf_range(0.0, 0.06)))
	# 远景塔影
	var tower_cols: Array[Color] = []
	for p in [Vector3(-18, 14, 78), Vector3(19, 11, 35), Vector3(-16, 10, 22), Vector3(22, 16, 66)]:
		xforms.append(Transform3D(Basis(), p))
		cols.append(Color(0.03, 0.04, 0.075))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.disable_receive_shadows = true
	_multimesh(self, mesh, xforms, cols, mat)

	# 远处窗火
	var wy: Array[Transform3D] = []
	for i in 54:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		wy.append(Transform3D(Basis(), Vector3(side * rng.randf_range(9.5, 23.0),
			rng.randf_range(2.0, 9.0), rng.randf_range(2.0, 94.0))))
	var window_box := BoxMesh.new()
	window_box.size = Vector3(0.09, 0.18, 0.26)
	var wm := StandardMaterial3D.new()
	wm.emission_enabled = true
	wm.emission = Color(1.0, 0.58, 0.24)
	wm.emission_energy_multiplier = 1.2
	wm.albedo_color = Color(1.0, 0.6, 0.3)
	_multimesh(self, window_box, wy, [], wm)


func _build_boundaries() -> void:
	var sb := StaticBody3D.new()
	sb.name = "Boundaries"
	sb.collision_layer = 1
	sb.collision_mask = 0
	var walls := [
		[Vector3(-6.85, 2.5, 31.0), Vector3(0.3, 5.0, 66.0)],
		[Vector3(6.85, 2.5, 31.0), Vector3(0.3, 5.0, 66.0)],
		[Vector3(-12.9, 2.5, 76.0), Vector3(0.3, 5.0, 30.0)],
		[Vector3(12.9, 2.5, 76.0), Vector3(0.3, 5.0, 30.0)],
		[Vector3(0, 2.5, 91.0), Vector3(26.0, 5.0, 0.3)],
		[Vector3(0, 2.5, -0.8), Vector3(14.0, 5.0, 0.3)],
	]
	for w in walls:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = w[1]
		cs.shape = bs
		cs.position = w[0]
		sb.add_child(cs)
	add_child(sb)
	# 广场与街道之间两侧不可穿
	var gate := StaticBody3D.new()
	gate.collision_layer = 1
	gate.collision_mask = 0
	for side in [-1.0, 1.0]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(6.0, 5.0, 0.4)
		cs.shape = bs
		cs.position = Vector3(side * 9.6, 2.5, 62.0)
		gate.add_child(cs)
	add_child(gate)


func _build_atmosphere() -> void:
	# 街面浮尘 / 灯火星屑
	var embers := CPUParticles3D.new()
	embers.name = "LanternMotes"
	embers.amount = 70
	embers.lifetime = 7.0
	embers.preprocess = 4.0
	embers.local_coords = false
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(6.0, 4.0, 30.0)
	embers.direction = Vector3(0.15, 1.0, 0.05)
	embers.spread = 35.0
	embers.gravity = Vector3(0.0, 0.06, 0.0)
	embers.initial_velocity_min = 0.10
	embers.initial_velocity_max = 0.4
	embers.scale_amount_min = 0.25
	embers.scale_amount_max = 0.85
	embers.color = Color(1.0, 0.62, 0.26, 0.55)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.12, 0.12)
	var pm := _unshaded(Color(1.0, 0.65, 0.3), 0.65, true)
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pm.albedo_texture = _soft_texture(24)
	qm.material = pm
	embers.mesh = qm
	embers.position = Vector3(0, 2.2, 32.0)
	embers.emitting = true
	add_child(embers)

	# 地雾：低面片半透明面，缓慢漂移
	for i in 3:
		var fog_plane := MeshInstance3D.new()
		var pm2 := PlaneMesh.new()
		pm2.size = Vector2(12.0, 26.0)
		fog_plane.mesh = pm2
		var fm := _unshaded(Color(0.35, 0.42, 0.65), 0.035 + i * 0.01)
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		fog_plane.material_override = fm
		fog_plane.position = Vector3(0, 0.7 + i * 1.5, 26.0 + i * 10.0)
		fog_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fog_plane)
