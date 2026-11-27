class_name LegionArt
extends RefCounted

# 程序化低模工厂：地形之外的岩石、单位、塔、传送门、核心与光效。
# 全部由 Godot 原语 / 自写 shader / 运行时贴图生成，无外部美术资源。

const D := preload("res://scripts/legion_data.gd")

static var _mats: Dictionary = {}
static var _tex: Dictionary = {}
static var _toon_shader: Shader


# ---------------------------------------------------------------- 材质 / 贴图

static func mat(color: Color, emission: Color = Color(0, 0, 0, 0), rough: float = 0.95) -> StandardMaterial3D:
	var key := "m:%s:%s:%.2f" % [color.to_html(), emission.to_html(), rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if emission.a > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 1.25
	_mats[key] = m
	return m


static func glow_mat(color: Color, additive: bool = true) -> StandardMaterial3D:
	var key := "g:%s:%s" % [color.to_html(), additive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.no_depth_test = false
	_mats[key] = m
	return m


static func vcol_mat(rough: float = 1.0, toon: bool = true) -> StandardMaterial3D:
	var key := "vc:%.2f:%s" % [rough, toon]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic = 0.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON if toon else BaseMaterial3D.DIFFUSE_LAMBERT
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_BACK
	_mats[key] = m
	return m


static func radial_texture(size: int = 64, soft: float = 0.55) -> ImageTexture:
	var key := "radial:%d:%.2f" % [size, soft]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / (size * 0.5)
			var a := clampf(1.0 - smoothstep(soft, 1.0, d), 0.0, 1.0)
			a = pow(a, 1.6)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


static func smoke_texture(size: int = 96) -> ImageTexture:
	var key := "smoke:%d" % size
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 77123
	var blobs: Array[Vector3] = []
	for i in 9:
		blobs.append(Vector3(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8), rng.randf_range(0.10, 0.24)))
	for y in size:
		for x in size:
			var u := x / float(size - 1)
			var v := y / float(size - 1)
			var a := 0.0
			for b in blobs:
				var d := Vector2(u - b.x, v - b.y).length()
				a += clampf(1.0 - d / b.z, 0.0, 1.0)
			var edge := clampf(1.0 - Vector2(u - 0.5, v - 0.5).length() * 2.0, 0.0, 1.0)
			a = clampf(a * 0.36 * edge, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


static func white_texture() -> ImageTexture:
	if _tex.has("white"):
		return _tex["white"]
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_tex["white"] = tex
	return tex


static func billboard_material(color: Color, tex: Texture2D, additive: bool = true) -> StandardMaterial3D:
	var key := "bb:%s:%s:%s" % [color.to_html(), tex.get_instance_id(), additive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mats[key] = m
	return m


static func ground_glow_material(color: Color, tex: Texture2D = null, additive: bool = true) -> StandardMaterial3D:
	var key := "gg:%s:%s:%s" % [color.to_html(), tex.get_instance_id() if tex != null else 0, additive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.albedo_texture = tex if tex != null else radial_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mats[key] = m
	return m


static func shadow_material() -> StandardMaterial3D:
	if _mats.has("shadow"):
		return _mats["shadow"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = radial_texture(48, 0.25)
	m.albedo_color = Color(0.02, 0.01, 0.03, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["shadow"] = m
	return m


# ---------------------------------------------------------------- 基础几何

static func add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color,
		rot_deg: Vector3 = Vector3.ZERO, material: Material = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material if material != null else mat(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func add_cyl(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3,
		color: Color, sides: int = 6, rot_deg: Vector3 = Vector3.ZERO,
		material: Material = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material if material != null else mat(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func add_sphere(parent: Node3D, radius: float, pos: Vector3, color: Color,
		scale: Vector3 = Vector3.ONE, material: Material = null, seg: int = 8, rings: int = 4) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = seg
	mesh.rings = rings
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material if material != null else mat(color)
	mi.position = pos
	mi.scale = scale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func add_cone(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color,
		sides: int = 5, rot_deg: Vector3 = Vector3.ZERO, material: Material = null) -> MeshInstance3D:
	return add_cyl(parent, 0.0, radius, height, pos, color, sides, rot_deg, material)


static func add_torus(parent: Node3D, inner: float, outer: float, pos: Vector3, color: Color,
		rot_deg: Vector3 = Vector3.ZERO, material: Material = null) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material if material != null else mat(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func add_quad_flat(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size.x, size.z)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func add_billboard(parent: Node3D, size: float, pos: Vector3, color: Color,
		tex: Texture2D = null, additive: bool = true) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = billboard_material(color, tex if tex != null else radial_texture(), additive)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func add_shadow(parent: Node3D, radius: float, y: float = 0.03) -> MeshInstance3D:
	return add_quad_flat(parent, Vector3(radius * 2.0, 0, radius * 2.0), Vector3(0, y, 0), shadow_material())


# ---------------------------------------------------------------- 单位模型

static func build_unit(kind: String) -> Dictionary:
	var def := D.unit_def(kind)
	var root := Node3D.new()
	root.name = "UnitModel"
	var rig := {"root": root, "legs": [], "arms": [], "height": float(def.height)}
	add_shadow(root, 0.62 if kind != "hero" else 0.85)
	var dark := Color(def.color).darkened(0.25)
	var cloth := Color(def.color)
	var accent := Color(def.accent)
	var skin := Color("#c6a184") if kind != "hero" else Color("#d8a97f")
	var metal := Color("#7a828c").darkened(0.1)
	var trim := Color("#d9c49a")

	var torso := Node3D.new()
	torso.name = "Torso"
	torso.position.y = 0.82
	root.add_child(torso)
	rig["body"] = torso

	if kind == "adept":
		# 长袍术士：袍摆 + 兜帽 + 法杖
		add_cyl(torso, 0.26, 0.52, 1.05, Vector3(0, 0.45, 0), cloth, 7)
		add_cyl(torso, 0.34, 0.4, 0.18, Vector3(0, 0.96, 0), dark, 7)
		add_sphere(torso, 0.17, Vector3(0, 1.33, 0.02), skin, Vector3.ONE, null, 7, 4)
		add_cone(torso, 0.27, 0.42, Vector3(0, 1.55, -0.03), dark, 7)
		add_box(torso, Vector3(0.30, 0.05, 0.10), Vector3(0, 1.30, 0.18), accent, Vector3.ZERO,
			glow_mat(accent))
		var arm_l := Node3D.new()
		arm_l.position = Vector3(-0.29, 1.18, 0)
		torso.add_child(arm_l)
		add_box(arm_l, Vector3(0.12, 0.5, 0.12), Vector3(0, -0.24, 0), cloth)
		var arm_r := Node3D.new()
		arm_r.position = Vector3(0.29, 1.18, 0)
		torso.add_child(arm_r)
		add_box(arm_r, Vector3(0.12, 0.48, 0.12), Vector3(0, -0.22, 0), cloth)
		add_cyl(arm_r, 0.045, 0.055, 1.55, Vector3(0.08, -0.38, 0.18), Color("#5a3d2c"), 5,
			Vector3(16, 0, 0))
		add_sphere(arm_r, 0.14, Vector3(0.10, -0.55, 0.7), accent, Vector3.ONE,
			glow_mat(accent), 7, 4)
		rig["arms"] = [arm_l, arm_r]
		rig["weapon_tip"] = Vector3(0.10, 0.75, 0.7)
		return rig

	# 腿 / 靴
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(0.17 * side, 0.82, 0)
		root.add_child(leg)
		add_box(leg, Vector3(0.17, 0.62, 0.19), Vector3(0, -0.31, 0), dark)
		add_box(leg, Vector3(0.20, 0.16, 0.30), Vector3(0, -0.64, 0.05), metal)
		rig["legs"].append(leg)

	# 躯干
	add_box(torso, Vector3(0.52, 0.54, 0.30), Vector3(0, 0.24, 0), cloth)
	add_box(torso, Vector3(0.58, 0.20, 0.34), Vector3(0, 0.46, 0), dark)
	add_box(torso, Vector3(0.10, 0.34, 0.02), Vector3(0, 0.24, 0.17), accent, Vector3.ZERO,
		glow_mat(accent))
	# 肩甲
	for side in [-1, 1]:
		add_box(torso, Vector3(0.22, 0.16, 0.30), Vector3(0.33 * side, 0.42, 0), metal,
			Vector3(0, 0, -12 * side))
	# 头 / 头盔
	add_sphere(torso, 0.165, Vector3(0, 0.69, 0.02), skin, Vector3.ONE, null, 7, 4)
	if kind == "guard":
		add_cyl(torso, 0.20, 0.23, 0.25, Vector3(0, 0.80, 0), dark, 6)
		add_box(torso, Vector3(0.30, 0.05, 0.06), Vector3(0, 0.75, 0.17), accent, Vector3.ZERO,
			glow_mat(accent))
		add_cone(torso, 0.08, 0.22, Vector3(0, 0.95, -0.02), trim, 4)
	elif kind == "bolt":
		add_cone(torso, 0.26, 0.40, Vector3(0, 0.79, -0.05), cloth, 7)
		add_box(torso, Vector3(0.20, 0.03, 0.05), Vector3(0, 0.70, 0.18), accent, Vector3.ZERO,
			glow_mat(accent))
	else:
		# 英雄：冠冕 + 披风 + 长枪
		add_cyl(torso, 0.18, 0.22, 0.22, Vector3(0, 0.82, 0), dark, 6)
		for i in 5:
			var ang := -0.9 + i * 0.45
			add_cone(torso, 0.035, 0.17, Vector3(sin(ang) * 0.17, 0.97, cos(ang) * 0.12 - 0.02),
				trim, 4, Vector3(0, 0, -rad_to_deg(ang) * 0.5))
		add_box(torso, Vector3(0.26, 0.06, 0.06), Vector3(0, 0.76, 0.17), accent, Vector3.ZERO,
			glow_mat(accent))

	# 手臂
	var arm_l := Node3D.new()
	arm_l.position = Vector3(-0.34, 0.43, 0)
	torso.add_child(arm_l)
	add_box(arm_l, Vector3(0.13, 0.46, 0.14), Vector3(0, -0.22, 0), cloth)
	add_box(arm_l, Vector3(0.13, 0.12, 0.14), Vector3(0, -0.45, 0), metal)
	var arm_r := Node3D.new()
	arm_r.position = Vector3(0.34, 0.43, 0)
	torso.add_child(arm_r)
	add_box(arm_r, Vector3(0.13, 0.46, 0.14), Vector3(0, -0.22, 0), cloth)
	add_box(arm_r, Vector3(0.13, 0.12, 0.14), Vector3(0, -0.45, 0), metal)
	rig["arms"] = [arm_l, arm_r]

	if kind == "guard":
		# 左手盾，右手剑
		add_box(arm_l, Vector3(0.48, 0.62, 0.07), Vector3(-0.12, -0.30, 0.12), cloth,
			Vector3(0, -12, 0))
		add_cyl(arm_l, 0.10, 0.10, 0.04, Vector3(-0.12, -0.30, 0.17), accent, 4,
			Vector3(90, 0, 0), glow_mat(accent))
		add_box(arm_r, Vector3(0.06, 0.62, 0.05), Vector3(0.02, -0.62, 0.10), metal,
			Vector3(8, 0, 0))
		add_box(arm_r, Vector3(0.24, 0.05, 0.08), Vector3(0.02, -0.34, 0.07), trim)
	elif kind == "bolt":
		# 弩：横杆 + 弓臂 + 发光弦
		add_box(arm_r, Vector3(0.08, 0.08, 0.55), Vector3(0, -0.35, 0.22), Color("#4a3428"))
		add_box(arm_r, Vector3(0.52, 0.05, 0.08), Vector3(0, -0.35, 0.44), metal,
			Vector3(0, 8, 0))
		add_box(arm_r, Vector3(0.36, 0.02, 0.02), Vector3(0, -0.32, 0.44), accent,
			Vector3.ZERO, glow_mat(accent))
		add_box(torso, Vector3(0.16, 0.36, 0.12), Vector3(-0.25, 0.24, -0.20), dark,
			Vector3(0, 0, 12))
	else:
		# 英雄长枪 + 披风
		var cape := Node3D.new()
		cape.position = Vector3(0, 0.55, -0.16)
		torso.add_child(cape)
		add_box(cape, Vector3(0.56, 0.95, 0.04), Vector3(0, -0.45, -0.06), Color("#7d2f4a"),
			Vector3(-10, 0, 0))
		add_box(cape, Vector3(0.60, 0.08, 0.05), Vector3(0, -0.90, -0.13), trim)
		rig["cape"] = cape
		add_cyl(arm_r, 0.045, 0.045, 1.75, Vector3(0.02, -0.40, 0.24), Color("#5a3d2c"), 5,
			Vector3(12, 0, 0))
		add_box(arm_r, Vector3(0.16, 0.34, 0.05), Vector3(0.02, 0.47, 0.40), accent,
			Vector3(0, 0, 0), glow_mat(accent))
		add_box(arm_r, Vector3(0.08, 0.10, 0.08), Vector3(0.02, 0.26, 0.36), trim)
		add_torus(root, 0.72, 0.80, Vector3(0, 0.04, 0), accent, Vector3.ZERO,
			glow_mat(Color(accent.r, accent.g, accent.b, 0.55)))
		rig["weapon_tip"] = Vector3(0, 1.8, 0.5)

	return rig


static func build_enemy(kind: String) -> Dictionary:
	var def := D.enemy_def(kind)
	var root := Node3D.new()
	root.name = "EnemyModel"
	var rig := {"root": root, "legs": [], "arms": [], "height": float(def.height)}
	add_shadow(root, 0.7 if kind != "colossus" else 1.5)
	var carapace := Color(def.color)
	var accent := Color(def.accent)
	var dark := carapace.darkened(0.35)

	if kind == "crawler":
		var body := Node3D.new()
		body.position.y = 0.55
		root.add_child(body)
		rig["body"] = body
		add_sphere(body, 0.42, Vector3(0, 0.18, -0.05), carapace, Vector3(1.5, 0.7, 0.9), null, 7, 4)
		add_sphere(body, 0.30, Vector3(0, 0.12, 0.55), dark, Vector3(1.0, 0.75, 0.9), null, 6, 4)
		add_sphere(body, 0.09, Vector3(-0.15, 0.18, 0.78), accent, Vector3.ONE,
			glow_mat(accent), 6, 3)
		add_sphere(body, 0.09, Vector3(0.15, 0.18, 0.78), accent, Vector3.ONE,
			glow_mat(accent), 6, 3)
		# 背刺
		for i in 4:
			add_cone(body, 0.10, 0.34 + i * 0.05, Vector3(0, 0.34 + i * 0.02, -0.35 + i * 0.22),
				accent.darkened(0.15), 4, Vector3(20, 0, 0))
		# 六足
		for side in [-1, 1]:
			for i in 3:
				var leg := Node3D.new()
				leg.position = Vector3(0.30 * side, 0.42, 0.32 - i * 0.36)
				root.add_child(leg)
				add_box(leg, Vector3(0.08, 0.55, 0.08), Vector3(0.18 * side, -0.22, 0), carapace,
					Vector3(0, 0, 28 * side))
				add_box(leg, Vector3(0.08, 0.08, 0.30), Vector3(0.30 * side, -0.44, 0.12), dark)
				rig["legs"].append(leg)
		# 颚
		add_cone(body, 0.07, 0.30, Vector3(-0.16, 0.06, 0.82), accent, 4, Vector3(72, 0, -18))
		add_cone(body, 0.07, 0.30, Vector3(0.16, 0.06, 0.82), accent, 4, Vector3(72, 0, 18))
		return rig

	if kind == "spitter":
		var body := Node3D.new()
		body.position.y = 0.6
		root.add_child(body)
		rig["body"] = body
		add_sphere(body, 0.55, Vector3(0, 0.30, -0.25), carapace, Vector3(1.05, 0.95, 1.35),
			null, 7, 4)
		add_sphere(body, 0.22, Vector3(0, 0.28, 0.58), dark, Vector3(1.0, 0.9, 1.15), null, 6, 4)
		add_sphere(body, 0.34, Vector3(0, 0.55, -0.10), accent, Vector3(1.0, 0.75, 1.0),
			glow_mat(Color(accent.r * 0.7, accent.g, accent.b * 0.5, 0.9)), 7, 4)
		# 发射管
		add_cyl(body, 0.10, 0.16, 0.75, Vector3(0, 0.38, 0.88), dark, 6, Vector3(68, 0, 0))
		add_torus(body, 0.13, 0.17, Vector3(0, 0.68, 1.02), accent, Vector3(68, 0, 0),
			glow_mat(accent))
		add_sphere(body, 0.08, Vector3(-0.14, 0.42, 0.72), accent, Vector3.ONE,
			glow_mat(accent), 5, 3)
		add_sphere(body, 0.08, Vector3(0.14, 0.42, 0.72), accent, Vector3.ONE,
			glow_mat(accent), 5, 3)
		for side in [-1, 1]:
			for i in 2:
				var leg := Node3D.new()
				leg.position = Vector3(0.36 * side, 0.42, 0.18 - i * 0.42)
				root.add_child(leg)
				add_box(leg, Vector3(0.09, 0.62, 0.09), Vector3(0.16 * side, -0.24, 0), carapace,
					Vector3(0, 0, 24 * side))
				add_box(leg, Vector3(0.09, 0.08, 0.34), Vector3(0.28 * side, -0.52, 0.12), dark)
				rig["legs"].append(leg)
		return rig

	# colossus 精英
	var body := Node3D.new()
	body.position.y = 0.95
	root.add_child(body)
	rig["body"] = body
	add_box(body, Vector3(1.00, 0.95, 0.70), Vector3(0, 0.65, 0), carapace, Vector3.ZERO)
	add_box(body, Vector3(1.20, 0.30, 0.82), Vector3(0, 1.14, 0), dark)
	add_box(body, Vector3(0.55, 0.55, 0.55), Vector3(0, 1.55, 0.06), carapace)
	add_sphere(body, 0.22, Vector3(0, 1.55, 0.40), accent, Vector3(1.0, 0.7, 0.7),
		glow_mat(accent), 6, 3)
	add_sphere(body, 0.12, Vector3(-0.20, 1.62, 0.30), accent, Vector3.ONE, glow_mat(accent), 5, 3)
	add_sphere(body, 0.12, Vector3(0.20, 1.62, 0.30), accent, Vector3.ONE, glow_mat(accent), 5, 3)
	# 胸口熔核
	add_sphere(body, 0.28, Vector3(0, 0.75, 0.37), accent, Vector3(1.0, 1.0, 0.5),
		glow_mat(accent), 7, 4)
	add_torus(body, 0.28, 0.34, Vector3(0, 0.75, 0.37), accent, Vector3(90, 0, 0),
		glow_mat(accent))
	# 肩甲 / 巨拳
	for side in [-1, 1]:
		add_box(body, Vector3(0.42, 0.34, 0.62), Vector3(0.72 * side, 1.20, 0), dark,
			Vector3(0, 0, 12 * side))
		var arm := Node3D.new()
		arm.position = Vector3(0.76 * side, 0.95, 0)
		root.add_child(arm)
		add_box(arm, Vector3(0.34, 0.85, 0.36), Vector3(0.05 * side, -0.42, 0), carapace)
		add_box(arm, Vector3(0.50, 0.44, 0.52), Vector3(0.08 * side, -0.92, 0.05), dark)
		add_sphere(arm, 0.10, Vector3(0.10 * side, -0.98, 0.32), accent, Vector3.ONE,
			glow_mat(accent), 5, 3)
		rig["arms"].append(arm)
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(0.34 * side, 0.85, 0)
		root.add_child(leg)
		add_box(leg, Vector3(0.32, 0.82, 0.36), Vector3(0, -0.44, 0), carapace)
		add_box(leg, Vector3(0.44, 0.20, 0.56), Vector3(0, -0.90, 0.08), dark)
		rig["legs"].append(leg)
	# 背部尖刺
	for i in 3:
		add_cone(body, 0.16, 0.65 - i * 0.1, Vector3(0, 1.45, -0.28 - i * 0.22), accent.darkened(0.2),
			4, Vector3(24, 0, 0))
	return rig


# ---------------------------------------------------------------- 塔 / 核心

static func build_tower(kind: String, level: int = 1) -> Dictionary:
	var def := D.tower_def(kind)
	var root := Node3D.new()
	root.name = "TowerModel"
	var rig := {"root": root, "level": level}
	var stone := Color("#6b6275")
	var dark := Color("#443c4c")
	var accent := Color(def.accent)
	var head := Node3D.new()
	root.add_child(head)
	rig["head"] = head

	# 共用基座
	add_cyl(root, 1.18, 1.35, 0.45, Vector3(0, 0.22, 0), stone, 8)
	add_cyl(root, 0.95, 1.10, 0.18, Vector3(0, 0.53, 0), dark, 8)
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		add_box(root, Vector3(0.22, 0.5, 0.22), Vector3(cos(a) * 1.05, 0.25, sin(a) * 1.05),
			stone, Vector3(0, -rad_to_deg(a), 0))
	add_torus(root, 1.08, 1.18, Vector3(0, 0.55, 0), accent, Vector3.ZERO,
		glow_mat(Color(accent.r, accent.g, accent.b, 0.4)))

	if kind == "prism":
		add_cyl(root, 0.50, 0.72, 0.85, Vector3(0, 0.95, 0), dark, 6)
		add_cyl(root, 0.34, 0.50, 0.55, Vector3(0, 1.60, 0), stone, 6)
		var crystal := add_sphere(head, 0.42, Vector3(0, 2.35, 0), accent,
			Vector3(0.75, 2.3, 0.75), glow_mat(accent), 6, 4)
		crystal.name = "Crystal"
		rig["crystal"] = crystal
		for i in 3:
			add_torus(head, 0.62 + i * 0.10, 0.67 + i * 0.10, Vector3(0, 1.72 + i * 0.43, 0),
				accent, Vector3(90 + 14 * (i - 1), 12 * i, 0),
				glow_mat(Color(accent.r, accent.g, accent.b, 0.55)))
		add_cone(head, 0.18, 0.55, Vector3(0, 3.25, 0), accent, 4, Vector3.ZERO,
			glow_mat(Color(accent.r, accent.g, accent.b, 0.75)))
		rig["muzzle"] = Vector3(0, 2.75, 0)
		rig["beam_color"] = accent
	elif kind == "mortar":
		add_cyl(root, 0.80, 0.95, 0.58, Vector3(0, 0.88, 0), dark, 7)
		add_sphere(root, 0.68, Vector3(0, 1.12, 0), stone, Vector3(1.0, 0.45, 1.0), null, 8, 4)
		var barrel := Node3D.new()
		barrel.position = Vector3(0, 1.35, 0)
		barrel.rotation_degrees = Vector3(-38, 0, 0)
		head.add_child(barrel)
		add_cyl(barrel, 0.20, 0.30, 1.35, Vector3(0, 0.52, 0), stone, 7)
		add_cyl(barrel, 0.24, 0.24, 0.15, Vector3(0, 1.22, 0), accent, 7, Vector3.ZERO,
			glow_mat(accent))
		add_torus(barrel, 0.26, 0.31, Vector3(0, 1.28, 0), accent, Vector3(0, 0, 0),
			glow_mat(accent))
		add_box(root, Vector3(0.10, 0.55, 0.10), Vector3(-0.5, 1.45, -0.2), dark, Vector3(0, 0, 18))
		add_box(root, Vector3(0.10, 0.45, 0.10), Vector3(0.52, 1.40, -0.15), dark, Vector3(0, 0, -15))
		rig["barrel"] = barrel
		rig["muzzle"] = Vector3(0, 1.9, 1.0)
		rig["beam_color"] = accent
	else:
		add_cyl(root, 0.62, 0.86, 0.60, Vector3(0, 0.92, 0), dark, 7)
		for i in 3:
			add_cyl(root, 0.52 - i * 0.08, 0.62 - i * 0.08, 0.22, Vector3(0, 1.25 + i * 0.28, 0),
				stone, 7, Vector3(0, i * 24, 0))
		var crystal := add_sphere(head, 0.34, Vector3(0, 2.28, 0), accent,
			Vector3(0.8, 1.9, 0.8), glow_mat(accent), 6, 4)
		crystal.name = "Crystal"
		rig["crystal"] = crystal
		for i in 2:
			add_torus(head, 0.55 + i * 0.15, 0.59 + i * 0.15, Vector3(0, 1.82 + i * 0.55, 0),
				accent, Vector3(90, 0, 18 + i * 30), glow_mat(Color(accent.r, accent.g, accent.b, 0.6)))
		for i in 4:
			var a := i * TAU / 4.0
			add_cone(head, 0.08, 0.30, Vector3(cos(a) * 0.48, 1.9, sin(a) * 0.48), accent, 4,
				Vector3(0, 0, 20), glow_mat(Color(accent.r, accent.g, accent.b, 0.6)))
		rig["muzzle"] = Vector3(0, 2.28, 0)
		rig["beam_color"] = accent

	# 等级标记：额外冠环
	for l in range(1, level):
		add_torus(root, 1.30 + l * 0.08, 1.37 + l * 0.08, Vector3(0, 0.10, 0), accent,
			Vector3.ZERO, glow_mat(Color(accent.r, accent.g, accent.b, 0.45)))
	add_billboard(root, 3.0, Vector3(0, 0.7, 0), Color(accent.r, accent.g, accent.b, 0.22))
	return rig


static func build_core() -> Dictionary:
	var root := Node3D.new()
	root.name = "Core"
	var stone := Color("#656070")
	var dark := Color("#3d3947")
	var teal := D.C_TEAL
	# 台阶与基座
	add_cyl(root, 4.2, 4.8, 0.30, Vector3(0, 0.15, 0), Color("#2d2b35"), 8)
	add_cyl(root, 3.5, 4.0, 0.30, Vector3(0, 0.45, 0), stone, 8)
	add_cyl(root, 1.5, 2.6, 0.55, Vector3(0, 0.88, 0), dark, 8)
	for i in 6:
		var a := i * TAU / 6.0
		add_box(root, Vector3(0.35, 1.0, 0.35), Vector3(cos(a) * 3.0, 1.0, sin(a) * 3.0),
			stone, Vector3(0, -rad_to_deg(a), 0))
		add_sphere(root, 0.16, Vector3(cos(a) * 3.0, 1.55, sin(a) * 3.0), teal, Vector3.ONE,
			glow_mat(teal), 5, 3)
	# 中央水晶：实体发光材质，避免叠加发光被压成白团。
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color("#2fb9ae")
	core_mat.emission_enabled = true
	core_mat.emission = teal
	core_mat.emission_energy_multiplier = 0.85
	core_mat.roughness = 0.32
	core_mat.metallic = 0.0
	core_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var crystal := add_sphere(root, 0.95, Vector3(0, 3.2, 0), teal,
		Vector3(0.9, 2.5, 0.9), core_mat, 7, 4)
	crystal.name = "CoreCrystal"
	# 环绕石环
	for i in 2:
		add_torus(root, 1.55 + i * 0.25, 1.63 + i * 0.25, Vector3(0, 2.4 + i * 0.9, 0), teal,
			Vector3(90 + (i * 2 - 1) * 12, 20 * i, 0),
			glow_mat(Color(teal.r, teal.g, teal.b, 0.55)))
	# 四座小尖塔 / 旗帜
	for i in 4:
		var a := i * TAU / 4.0 + 0.2
		var p := Vector3(cos(a) * 5.7, 0, sin(a) * 5.7)
		add_cyl(root, 0.10, 0.14, 3.1, p + Vector3(0, 1.55, 0), Color("#4a3a33"), 5)
		add_box(root, Vector3(0.9, 0.55, 0.04),
			p + Vector3(cos(a + 0.5) * 0.4, 2.75, sin(a + 0.5) * 0.4), Color("#276e68"),
			Vector3(0, -rad_to_deg(a + 0.5), 0))
		add_sphere(root, 0.09, p + Vector3(0, 3.1, 0), teal, Vector3.ONE, glow_mat(teal), 5, 3)
	add_billboard(root, 6.5, Vector3(0, 3.4, 0), Color(teal.r, teal.g, teal.b, 0.12))
	add_billboard(root, 4.2, Vector3(0, 0.35, 0), Color(teal.r, teal.g, teal.b, 0.08))
	return {"root": root, "crystal": crystal, "material": core_mat}


static func build_portal(tint: Color) -> Dictionary:
	var root := Node3D.new()
	root.name = "Portal"
	var stone := Color("#554b66")
	var dark := Color("#332c40")
	add_quad_flat(root, Vector3(10, 0, 10), Vector3(0, 0.04, 0),
		ground_glow_material(Color(tint.r, tint.g, tint.b, 0.22), radial_texture(64, 0.3), true))
	# 环状立石
	for i in 7:
		var a := i * TAU / 7.0
		var h := 2.2 + (0.45 if i % 2 == 0 else 0.0)
		var p := Vector3(cos(a) * 2.6, h * 0.5, sin(a) * 2.6)
		add_box(root, Vector3(0.55, h, 0.55), p, stone, Vector3(0, -rad_to_deg(a), 8))
		add_box(root, Vector3(0.62, 0.14, 0.62), p + Vector3(0, h * 0.5, 0), dark,
			Vector3(0, -rad_to_deg(a), 8))
		add_sphere(root, 0.10, p + Vector3(0, h * 0.5 + 0.2, 0), tint, Vector3.ONE,
			glow_mat(tint), 5, 3)
	# 门的骨架
	add_cyl(root, 0.12, 0.16, 4.2, Vector3(-1.7, 2.1, 0), stone, 5, Vector3(0, 0, 12))
	add_cyl(root, 0.12, 0.16, 4.2, Vector3(1.7, 2.1, 0), stone, 5, Vector3(0, 0, -12))
	add_box(root, Vector3(3.4, 0.25, 0.3), Vector3(0, 4.0, 0), stone, Vector3(0, 0, 0))
	add_torus(root, 1.35, 1.55, Vector3(0, 2.3, 0), tint, Vector3(90, 0, 0),
		glow_mat(tint))
	var veil := add_billboard(root, 4.4, Vector3(0, 2.2, 0), Color(tint.r, tint.g, tint.b, 0.42),
		radial_texture(64, 0.12), true)
	veil.name = "Veil"
	# 门内光柱
	add_cyl(root, 0.22, 0.55, 3.9, Vector3(0, 1.95, 0), tint, 6, Vector3.ZERO,
		glow_mat(Color(tint.r, tint.g, tint.b, 0.35)))
	var shards: Array[Node3D] = []
	for i in 3:
		var sh := Node3D.new()
		sh.position = Vector3(0, 3.4 + i * 0.5, 0)
		root.add_child(sh)
		add_box(sh, Vector3(0.18, 0.6, 0.08), Vector3.ZERO, tint, Vector3(0, i * 40, 0),
			glow_mat(tint))
		shards.append(sh)
	return {"root": root, "veil": veil, "shards": shards, "tint": tint}


static func build_pad(index: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Pad%d" % index
	add_cyl(root, 1.75, 1.95, 0.22, Vector3(0, 0.11, 0), Color("#34313c"), 8)
	add_cyl(root, 1.48, 1.62, 0.12, Vector3(0, 0.26, 0), Color("#25232c"), 8)
	var rune := add_torus(root, 1.20, 1.32, Vector3(0, 0.33, 0), D.C_TEAL, Vector3.ZERO,
		glow_mat(Color(D.C_TEAL.r, D.C_TEAL.g, D.C_TEAL.b, 0.55)))
	var plus := Node3D.new()
	plus.position.y = 0.36
	root.add_child(plus)
	add_box(plus, Vector3(0.9, 0.03, 0.10), Vector3.ZERO, D.C_TEAL, Vector3.ZERO,
		glow_mat(Color(D.C_TEAL.r, D.C_TEAL.g, D.C_TEAL.b, 0.7)))
	add_box(plus, Vector3(0.10, 0.03, 0.9), Vector3.ZERO, D.C_TEAL, Vector3.ZERO,
		glow_mat(Color(D.C_TEAL.r, D.C_TEAL.g, D.C_TEAL.b, 0.7)))
	for i in 4:
		var a := i * TAU / 4.0 + 0.3
		add_box(root, Vector3(0.22, 0.45, 0.22), Vector3(cos(a) * 1.55, 0.4, sin(a) * 1.55),
			Color("#3a3542"), Vector3(0, -rad_to_deg(a), 0))
	return {"root": root, "rune": rune, "plus": plus}


static func build_barracks() -> Dictionary:
	var root := Node3D.new()
	root.name = "Barracks"
	var stone := Color("#5d576b")
	var dark := Color("#3c3747")
	var teal := D.C_TEAL
	add_cyl(root, 3.3, 3.7, 0.3, Vector3(0, 0.15, 0), Color("#2b2933"), 8)
	add_box(root, Vector3(3.4, 2.1, 2.6), Vector3(0, 1.35, 0), stone)
	add_box(root, Vector3(3.8, 0.35, 3.0), Vector3(0, 2.55, 0), dark)
	add_cyl(root, 1.4, 1.6, 0.9, Vector3(0, 3.1, 0), dark, 6)
	add_cone(root, 1.5, 1.7, Vector3(0, 4.4, 0), Color("#2b4d4a"), 6)
	add_box(root, Vector3(1.3, 1.7, 0.12), Vector3(0, 1.05, 1.32), Color("#1b1a20"))
	add_box(root, Vector3(1.5, 0.16, 0.2), Vector3(0, 2.0, 1.36), teal, Vector3.ZERO,
		glow_mat(teal))
	add_box(root, Vector3(0.2, 0.7, 0.14), Vector3(-0.55, 1.0, 1.36), teal, Vector3.ZERO,
		glow_mat(teal))
	add_box(root, Vector3(0.2, 0.7, 0.14), Vector3(0.55, 1.0, 1.36), teal, Vector3.ZERO,
		glow_mat(teal))
	add_torus(root, 2.6, 2.75, Vector3(0, 0.32, 0), teal, Vector3.ZERO,
		glow_mat(Color(teal.r, teal.g, teal.b, 0.4)))
	add_billboard(root, 7.0, Vector3(0, 2.0, 0), Color(teal.r, teal.g, teal.b, 0.14))
	return {"root": root}


static func build_rally_flag() -> Node3D:
	var root := Node3D.new()
	root.name = "RallyFlag"
	add_cyl(root, 0.05, 0.08, 1.8, Vector3(0, 0.9, 0), Color("#6b5a44"), 5)
	add_box(root, Vector3(0.7, 0.42, 0.03), Vector3(0.38, 1.55, 0), D.C_TEAL, Vector3.ZERO)
	add_sphere(root, 0.07, Vector3(0, 1.82, 0), D.C_TEAL, Vector3.ONE, glow_mat(D.C_TEAL), 5, 3)
	add_quad_flat(root, Vector3(1.6, 0, 1.6), Vector3(0, 0.04, 0),
		ground_glow_material(Color(D.C_TEAL.r, D.C_TEAL.g, D.C_TEAL.b, 0.18), radial_texture(), true))
	return root


# ---------------------------------------------------------------- 光效

static func build_selection_ring(radius: float, color: Color, strength: float = 1.0) -> Node3D:
	var root := Node3D.new()
	add_torus(root, radius - 0.06, radius, Vector3(0, 0.06, 0), color, Vector3.ZERO,
		glow_mat(Color(color.r * 0.64, color.g * 0.86, color.b * 0.86, 0.55 * strength)))
	add_torus(root, radius - 0.20, radius - 0.14, Vector3(0, 0.055, 0), color, Vector3.ZERO,
		glow_mat(Color(color.r * 0.64, color.g * 0.86, color.b * 0.86, 0.22 * strength)))
	var disc := add_quad_flat(root, Vector3(radius * 2.0, 0, radius * 2.0), Vector3(0, 0.045, 0),
		ground_glow_material(Color(color.r, color.g, color.b, 0.05 * strength), radial_texture(), true))
	disc.name = "Disc"
	return root


static func build_range_ring(radius: float, color: Color, strength: float = 1.0) -> Node3D:
	var root := Node3D.new()
	add_torus(root, radius - 0.08, radius, Vector3(0, 0.07, 0), color, Vector3.ZERO,
		glow_mat(Color(color.r * 0.52, color.g * 0.70, color.b * 0.70, 0.48 * strength)))
	var disc := add_quad_flat(root, Vector3(radius * 2.0, 0, radius * 2.0), Vector3(0, 0.05, 0),
		ground_glow_material(Color(color.r, color.g, color.b, 0.035 * strength), radial_texture(64, 0.15), true))
	disc.name = "Disc"
	return root


static func build_shockwave(radius: float, color: Color) -> Node3D:
	var root := Node3D.new()
	add_torus(root, radius - 0.18, radius, Vector3(0, 0.10, 0), color, Vector3.ZERO,
		glow_mat(Color(color.r, color.g, color.b, 0.52)))
	add_torus(root, radius - 0.5, radius - 0.4, Vector3(0, 0.09, 0), color, Vector3.ZERO,
		glow_mat(Color(color.r, color.g, color.b, 0.24)))
	return root


static func build_slash(color: Color, size: float = 1.0) -> Node3D:
	var root := Node3D.new()
	var m := glow_mat(Color(color.r, color.g, color.b, 0.85))
	add_torus(root, size * 0.8, size, Vector3(0, 0, 0), color, Vector3(90, 0, 0), m)
	return root


static func build_projectile_visual(kind: String) -> Node3D:
	var root := Node3D.new()
	var color := Color("#8ce8ff")
	var radius := 0.12
	if kind == "fire":
		color = Color("#ff9a4f")
		radius = 0.16
	elif kind == "mortar":
		color = Color("#ffb35c")
		radius = 0.20
	elif kind == "acid":
		color = Color("#b5ff8e")
		radius = 0.15
	elif kind == "frost":
		color = Color("#a8ecff")
		radius = 0.13
	add_sphere(root, radius, Vector3.ZERO, color, Vector3.ONE, glow_mat(color), 6, 3)
	add_billboard(root, radius * 5.0, Vector3.ZERO, Color(color.r, color.g, color.b, 0.5))
	return root


static func build_impact_burst(color: Color, size: float) -> Node3D:
	var root := Node3D.new()
	add_billboard(root, size * 2.6, Vector3(0, size * 0.4, 0), Color(color.r, color.g, color.b, 0.52))
	add_sphere(root, size * 0.28, Vector3.ZERO, color, Vector3.ONE, glow_mat(color), 6, 3)
	return root
