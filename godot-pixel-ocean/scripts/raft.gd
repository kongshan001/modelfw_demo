extends Node3D

# 木筏 + 小水手 + 猫。木筏不写死高度：每帧在水面取 5 个点（中心 + 四角），
# 用平均高度定 y、用前后差定俯仰、左右差定横滚，做平滑跟随。
# 根节点压到平均水位下方 DRAFT（吃水），让浮木真正没入水中；甲板抬高保留干舷。
# get_waterline_y() 返回当前水线高度，倒影镜像平面跟着它走。
# 所有模型和贴图都是本工程用代码生成的，无外部素材。

const HALF_WIDTH := 1.15
const HALF_DEPTH := 1.55
const DRAFT := 0.06  # 根节点低于平均水位的深度；浮木半径 0.17、中心 +0.06，水线过中线

var ocean

var _deck_y := 0.20  # 甲板抬高：浮木吃水时甲板仍有干舷，浪尖不会漫过船面
var _character: Node3D
var _character_base_y := 0.28
var _flag: MeshInstance3D
var _lantern_light: OmniLight3D
var _lantern_orb: MeshInstance3D
var _debug_marks: Node3D
var _marks: Array[MeshInstance3D] = []
var _debug_visible := false
var _anim_time := 0.0
var _night := 0.0
var _mark_positions: Array[Vector3] = []

var _wood_mat: StandardMaterial3D
var _wood_dark_mat: StandardMaterial3D
var _sail_mat: StandardMaterial3D
var _rope_mat: StandardMaterial3D
var _skin_mat: StandardMaterial3D
var _coat_mat: StandardMaterial3D
var _hat_mat: StandardMaterial3D
var _pants_mat: StandardMaterial3D
var _cat_mat: StandardMaterial3D
var _dark_mat: StandardMaterial3D
var _scarf_mat: StandardMaterial3D


func _ready() -> void:
	_wood_mat = _flat(Color(0.62, 0.40, 0.22), _wood_texture())
	_wood_dark_mat = _flat(Color(0.44, 0.28, 0.15), _wood_texture())
	_sail_mat = _sail_material()
	_rope_mat = _flat(Color(0.70, 0.60, 0.40))
	_skin_mat = _flat(Color(0.93, 0.72, 0.53))
	_coat_mat = _flat(Color(0.83, 0.33, 0.24))
	_hat_mat = _flat(Color(0.92, 0.79, 0.45))
	_pants_mat = _flat(Color(0.16, 0.25, 0.38))
	_cat_mat = _flat(Color(0.88, 0.51, 0.24))
	_dark_mat = _flat(Color(0.10, 0.10, 0.12))
	_scarf_mat = _flat(Color(0.63, 0.20, 0.16))

	_build_hull()
	_build_sail()
	_build_props()
	_build_character()
	_build_cat()
	_build_lantern()
	_build_debug_points()
	_update_marks()


# ── 船体 ─────────────────────────────────────────────────────────────────
func _build_hull() -> void:
	var plank_count := 9
	for i in plank_count:
		var plank := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.30, 0.10, 0.315)
		plank.mesh = box
		plank.material_override = _wood_mat if i % 2 == 0 else _wood_dark_mat
		plank.position = Vector3(0.0, _deck_y + sin(i * 2.3) * 0.006,
				-1.40 + i * 0.35)
		add_child(plank)

	# 两根浮木：中心抬到甲板下沿，半径 0.17，吃水约一半
	for sx in [-0.78, 0.78]:
		var log_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.17
		cyl.bottom_radius = 0.17
		cyl.height = 3.10
		cyl.radial_segments = 8
		cyl.rings = 1
		log_mesh.mesh = cyl
		log_mesh.material_override = _wood_dark_mat
		log_mesh.position = Vector3(sx, 0.06, 0.0)
		log_mesh.rotation.x = PI * 0.5
		add_child(log_mesh)

	# 简单的边梁，压住木板
	for sx in [-1.10, 1.10]:
		var rail := MeshInstance3D.new()
		var rail_box := BoxMesh.new()
		rail_box.size = Vector3(0.10, 0.12, 3.05)
		rail.mesh = rail_box
		rail.material_override = _wood_dark_mat
		rail.position = Vector3(sx, _deck_y + 0.06, 0.0)
		add_child(rail)


func _build_sail() -> void:
	var mast := MeshInstance3D.new()
	var mast_cyl := CylinderMesh.new()
	mast_cyl.top_radius = 0.045
	mast_cyl.bottom_radius = 0.065
	mast_cyl.height = 2.35
	mast_cyl.radial_segments = 7
	mast.mesh = mast_cyl
	mast.material_override = _wood_dark_mat
	mast.position = Vector3(0.02, 1.27, -0.92)
	add_child(mast)

	var yard := MeshInstance3D.new()
	var yard_cyl := CylinderMesh.new()
	yard_cyl.top_radius = 0.035
	yard_cyl.bottom_radius = 0.035
	yard_cyl.height = 1.75
	yard_cyl.radial_segments = 6
	yard.mesh = yard_cyl
	yard.material_override = _wood_dark_mat
	yard.rotation.z = PI * 0.5
	yard.position = Vector3(0.72, 2.38, -0.92)
	add_child(yard)

	var sail := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.45, 1.30)
	sail.mesh = quad
	sail.material_override = _sail_mat
	sail.position = Vector3(0.72, 1.70, -0.90)
	add_child(sail)

	_flag = MeshInstance3D.new()
	var flag_box := BoxMesh.new()
	flag_box.size = Vector3(0.34, 0.16, 0.02)
	_flag.mesh = flag_box
	_flag.material_override = _flat(Color(0.80, 0.24, 0.20))
	_flag.position = Vector3(0.22, 2.48, -0.92)
	add_child(_flag)


func _build_props() -> void:
	var barrel := MeshInstance3D.new()
	var barrel_cyl := CylinderMesh.new()
	barrel_cyl.top_radius = 0.17
	barrel_cyl.bottom_radius = 0.17
	barrel_cyl.height = 0.38
	barrel_cyl.radial_segments = 9
	barrel.mesh = barrel_cyl
	barrel.material_override = _wood_dark_mat
	barrel.position = Vector3(0.82, _deck_y + 0.24, 0.95)
	add_child(barrel)

	var hoop := MeshInstance3D.new()
	var hoop_cyl := CylinderMesh.new()
	hoop_cyl.top_radius = 0.18
	hoop_cyl.bottom_radius = 0.18
	hoop_cyl.height = 0.035
	hoop_cyl.radial_segments = 9
	hoop.mesh = hoop_cyl
	hoop.material_override = _dark_mat
	hoop.position = Vector3(0.82, _deck_y + 0.34, 0.95)
	add_child(hoop)

	var crate := MeshInstance3D.new()
	var crate_box := BoxMesh.new()
	crate_box.size = Vector3(0.40, 0.38, 0.40)
	crate.mesh = crate_box
	crate.material_override = _wood_mat
	crate.position = Vector3(-0.80, _deck_y + 0.24, -1.02)
	crate.rotation.y = 0.18
	add_child(crate)


# ── 小水手 ───────────────────────────────────────────────────────────────
func _build_character() -> void:
	_character = Node3D.new()
	_character.name = "Sailor"
	_character.position = Vector3(-0.42, _character_base_y, 0.52)
	_character.rotation.y = 0.55
	add_child(_character)

	for sx in [-0.07, 0.07]:
		_part(_character, _box(Vector3(0.095, 0.22, 0.105)), _pants_mat,
				Vector3(sx, 0.11, 0.0))
	_part(_character, _box(Vector3(0.30, 0.30, 0.20)), _coat_mat,
			Vector3(0.0, 0.36, 0.0))
	for sx in [-0.19, 0.19]:
		var arm := _part(_character, _box(Vector3(0.075, 0.24, 0.085)), _coat_mat,
				Vector3(sx, 0.38, 0.02))
		arm.rotation.z = -sx * 1.5
	var head := MeshInstance3D.new()
	var head_sphere := SphereMesh.new()
	head_sphere.radius = 0.105
	head_sphere.height = 0.21
	head_sphere.radial_segments = 8
	head_sphere.rings = 5
	head.mesh = head_sphere
	head.material_override = _skin_mat
	head.position = Vector3(0.0, 0.60, 0.0)
	_character.add_child(head)

	var brim := MeshInstance3D.new()
	var brim_cyl := CylinderMesh.new()
	brim_cyl.top_radius = 0.185
	brim_cyl.bottom_radius = 0.185
	brim_cyl.height = 0.028
	brim_cyl.radial_segments = 10
	brim.mesh = brim_cyl
	brim.material_override = _hat_mat
	brim.position = Vector3(0.0, 0.685, 0.0)
	_character.add_child(brim)

	var crown := MeshInstance3D.new()
	var crown_cyl := CylinderMesh.new()
	crown_cyl.top_radius = 0.10
	crown_cyl.bottom_radius = 0.115
	crown_cyl.height = 0.11
	crown_cyl.radial_segments = 8
	crown.mesh = crown_cyl
	crown.material_override = _hat_mat
	crown.position = Vector3(0.0, 0.735, 0.0)
	_character.add_child(crown)

	for sx in [-0.042, 0.042]:
		_part(_character, _box(Vector3(0.022, 0.03, 0.012)), _dark_mat,
				Vector3(sx, 0.605, 0.102))
	# 围巾
	_part(_character, _box(Vector3(0.22, 0.055, 0.21)), _scarf_mat,
			Vector3(0.0, 0.49, 0.0))


func _build_cat() -> void:
	var cat := Node3D.new()
	cat.name = "Cat"
	cat.position = Vector3(0.62, _deck_y + 0.16, 1.05)
	cat.rotation.y = -0.5
	add_child(cat)

	var body := MeshInstance3D.new()
	var body_sphere := SphereMesh.new()
	body_sphere.radius = 0.12
	body_sphere.height = 0.20
	body_sphere.radial_segments = 7
	body_sphere.rings = 4
	body.mesh = body_sphere
	body.material_override = _cat_mat
	body.scale = Vector3(1.0, 0.8, 1.35)
	cat.add_child(body)

	var head := MeshInstance3D.new()
	var head_sphere := SphereMesh.new()
	head_sphere.radius = 0.085
	head_sphere.height = 0.17
	head_sphere.radial_segments = 7
	head_sphere.rings = 4
	head.mesh = head_sphere
	head.material_override = _cat_mat
	head.position = Vector3(0.0, 0.10, 0.12)
	cat.add_child(head)

	for sx in [-0.05, 0.05]:
		var ear := _part(cat, _box(Vector3(0.055, 0.055, 0.02)), _cat_mat,
				Vector3(sx, 0.175, 0.11))
		ear.rotation.z = PI * 0.25

	var tail := MeshInstance3D.new()
	var tail_cyl := CylinderMesh.new()
	tail_cyl.top_radius = 0.02
	tail_cyl.bottom_radius = 0.03
	tail_cyl.height = 0.30
	tail_cyl.radial_segments = 5
	tail.mesh = tail_cyl
	tail.material_override = _cat_mat
	tail.position = Vector3(0.0, 0.05, -0.18)
	tail.rotation.x = -0.9
	cat.add_child(tail)

	for sx in [-0.032, 0.032]:
		_part(cat, _box(Vector3(0.014, 0.02, 0.01)), _dark_mat,
				Vector3(sx, 0.12, 0.195))


func _build_lantern() -> void:
	var pole := MeshInstance3D.new()
	var pole_cyl := CylinderMesh.new()
	pole_cyl.top_radius = 0.022
	pole_cyl.bottom_radius = 0.03
	pole_cyl.height = 0.85
	pole_cyl.radial_segments = 6
	pole.mesh = pole_cyl
	pole.material_override = _rope_mat
	pole.position = Vector3(1.0, _deck_y + 0.43, 0.55)
	add_child(pole)

	var arm := MeshInstance3D.new()
	var arm_box := BoxMesh.new()
	arm_box.size = Vector3(0.26, 0.03, 0.03)
	arm.mesh = arm_box
	arm.material_override = _rope_mat
	arm.position = Vector3(0.90, _deck_y + 0.84, 0.55)
	add_child(arm)

	_lantern_orb = MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.075
	orb.height = 0.15
	orb.radial_segments = 8
	orb.rings = 5
	_lantern_orb.mesh = orb
	var emissive := _flat(Color(1.0, 0.65, 0.28))
	emissive.emission_enabled = true
	emissive.emission = Color(1.0, 0.58, 0.22)
	emissive.emission_energy_multiplier = 2.4
	emissive.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lantern_orb.material_override = emissive
	_lantern_orb.position = Vector3(0.75, _deck_y + 0.72, 0.55)
	add_child(_lantern_orb)

	_lantern_light = OmniLight3D.new()
	_lantern_light.position = Vector3(0.75, _deck_y + 0.72, 0.55)
	_lantern_light.light_color = Color(1.0, 0.63, 0.30)
	_lantern_light.light_energy = 0.0
	_lantern_light.omni_range = 4.0
	_lantern_light.shadow_enabled = false
	add_child(_lantern_light)


# ── 五点浮力 ─────────────────────────────────────────────────────────────
func update_buoyancy(delta: float) -> void:
	if ocean == null:
		return
	var x := global_position.x
	var z := global_position.z
	var heights: Array[float] = ocean.sample_five(x, z)
	var center := heights[0]
	var front := heights[1]
	var back := heights[2]
	var left := heights[3]
	var right := heights[4]

	var average := (center + front + back + left + right) / 5.0
	var target_y := average - DRAFT
	var target_pitch := atan2(front - back, HALF_DEPTH * 2.0)
	var target_roll := atan2(right - left, HALF_WIDTH * 2.0)

	var k := 1.0 - exp(-7.0 * delta)
	position.y = lerpf(position.y, target_y, k)
	rotation.x = lerpf(rotation.x, target_pitch, k)
	rotation.z = lerpf(rotation.z, target_roll, k)

	_anim_time += delta
	if _character != null:
		_character.position.y = _character_base_y + sin(_anim_time * 1.6) * 0.007
		_character.rotation.z = sin(_anim_time * 1.1) * 0.02
	if _flag != null:
		_flag.rotation.y = sin(_anim_time * 3.2) * 0.18
	if _lantern_light != null:
		var flicker := 0.92 + 0.08 * sin(_anim_time * 9.0) + 0.04 * sin(_anim_time * 23.0)
		_lantern_light.light_energy = lerpf(0.05, 1.45, _night) * flicker
	if _lantern_orb != null:
		var mat := _lantern_orb.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = lerpf(0.6, 2.8, _night)

	_mark_positions.clear()
	_mark_positions.append(Vector3(x, center + 0.04, z))
	_mark_positions.append(Vector3(x, front + 0.04, z - HALF_DEPTH))
	_mark_positions.append(Vector3(x, back + 0.04, z + HALF_DEPTH))
	_mark_positions.append(Vector3(x - HALF_WIDTH, left + 0.04, z))
	_mark_positions.append(Vector3(x + HALF_WIDTH, right + 0.04, z))
	_update_marks()


func get_waterline_y() -> float:
	# 木筏所在水面的平均高度（= 根节点 + 吃水），倒影镜像平面用它，
	# 保证倒影顶部贴在船体水线上，而不是按 y=0 镜像后悬在水面下方。
	return global_position.y + DRAFT


func set_night_factor(value: float) -> void:
	_night = clampf(value, 0.0, 1.0)


func set_debug_points(value: bool) -> void:
	_debug_visible = value
	if _debug_marks != null:
		_debug_marks.visible = value


func get_sample_heights():
	if ocean == null:
		return [0.0, 0.0, 0.0, 0.0, 0.0]
	return ocean.sample_five(global_position.x, global_position.z)


func get_mark_positions() -> Array[Vector3]:
	return _mark_positions


# ── 内部工具 ─────────────────────────────────────────────────────────────
func _build_debug_points() -> void:
	_debug_marks = Node3D.new()
	_debug_marks.name = "BuoyancyPoints"
	_debug_marks.top_level = true
	add_child(_debug_marks)
	_debug_marks.visible = false

	var mark_mat := _flat(Color(1.0, 0.86, 0.24))
	mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark_mat.no_depth_test = true
	var center_mat := _flat(Color(0.35, 1.0, 0.85))
	center_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	center_mat.no_depth_test = true
	for i in 5:
		var mark := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.09
		sphere.height = 0.18
		sphere.radial_segments = 6
		sphere.rings = 3
		mark.mesh = sphere
		mark.material_override = center_mat if i == 0 else mark_mat
		mark.layers = 0x7FFFFFFF
		_debug_marks.add_child(mark)
		_marks.append(mark)


func _update_marks() -> void:
	if _marks.size() < 5 or _mark_positions.size() < 5:
		return
	for i in 5:
		_marks[i].global_position = _mark_positions[i]
		_marks[i].visible = _debug_visible


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	return instance


func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


func _flat(color: Color, tex: Texture2D = null) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if tex != null:
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat


func _sail_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _sail_texture()
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat


func _wood_texture() -> ImageTexture:
	var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 16:
			var n := float((x * 13 + y * 7 + (x * y) % 5) % 7) / 7.0
			var color := Color(0.55, 0.34, 0.18).lerp(Color(0.72, 0.50, 0.28), n * 0.7)
			if y == 0 or y == 7:
				color = color.darkened(0.38)
			if (x + y * 2) % 9 == 0:
				color = color.darkened(0.18)
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func _sail_texture() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var color := Color(0.97, 0.92, 0.80)
			if y >= 6 and y <= 8:
				color = Color(0.72, 0.26, 0.21)
			if y == 0 or y == 15 or x == 0 or x == 15:
				color = color.darkened(0.16)
			var noise := float((x * 5 + y * 11) % 4) * 0.015
			color = color.darkened(noise)
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
