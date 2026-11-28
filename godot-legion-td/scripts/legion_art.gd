class_name LegionArt
extends RefCounted

# Legionfall · 余烬荒原 art kit (T-20261127-020).
# Original low-poly geometry built with LegionMeshKit, merged into 1 draw per
# body/limb/tower part. Palette + silhouettes follow the T-019 production brief.
# No external models/textures; all shapes are Godot primitives + vertex colors.

const D := preload("res://scripts/legion_data.gd")
const Kit := preload("res://scripts/legion_mesh_kit.gd")

# ---- brief palette --------------------------------------------------------
const P_BRONZE := Color("#3FC9AB")
const P_BRONZE_LIGHT := Color("#8FFFE0")
const P_BRONZE_DARK := Color("#1A7C6B")
const P_BONE := Color("#F2E9D8")
const P_IRON := Color("#B7BFC4")
const P_IRON_DARK := Color("#5A6068")
const P_LEATHER := Color("#4A3A2E")
const P_GOLD := Color("#F0B23C")
const P_AMBER := Color("#FFB35C")

const E_BRUISE := Color("#B87AD8")
const E_PURPLE := Color("#E8C4FA")
const E_ABYSS := Color("#351B45")
const E_ACID := Color("#CBFF4D")
const E_BONE := Color("#D8CFC4")
const E_MOLTEN := Color("#FF6B35")

const T_STONE := Color("#9A90A4")
const T_STONE_DARK := Color("#3A3430")

static var _mats: Dictionary = {}
static var _tex: Dictionary = {}


# ---------------------------------------------------------------- materials

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
		m.emission_energy_multiplier = 0.85
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


static func _vcol_glow_mat() -> StandardMaterial3D:
	if _mats.has("vcglow"):
		return _mats["vcglow"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_BACK
	_mats["vcglow"] = m
	return m


static func vcol_alpha_material() -> StandardMaterial3D:
	return _vcol_alpha_mat()


static func _vcol_alpha_mat() -> StandardMaterial3D:
	if _mats.has("vcalpha"):
		return _mats["vcalpha"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_mats["vcalpha"] = m
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
			a = pow(a, 1.8)
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
			a = clampf(a * 0.30 * edge, 0.0, 1.0)
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
	m.albedo_color = Color(0.02, 0.015, 0.025, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["shadow"] = m
	return m


# ---------------------------------------------------------------- primitive helpers (legacy / world)

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


# ---------------------------------------------------------------- merged mesh helpers

static func _kit_instance(kit: LegionMeshKit, kind: String = "lit", node_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if node_name != "":
		mi.name = node_name
	var material: Material
	if kind == "glow":
		material = _vcol_glow_mat()
	elif kind == "alpha":
		material = _vcol_alpha_mat()
	else:
		material = vcol_mat(1.0, true)
	mi.mesh = kit.commit(material)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _glow_dot(kit: LegionMeshKit, pos: Vector3, radius: float, color: Color) -> void:
	kit.sphere(radius, pos, color, Vector3.ONE, 6, 3)


# ---------------------------------------------------------------- units

static func _unit_palette(kind: String) -> Dictionary:
	match kind:
		"hero":
			return {
				"main": P_BRONZE, "light": P_BRONZE_LIGHT, "dark": P_BRONZE_DARK,
				"bone": P_BONE, "iron": P_IRON, "gold": P_GOLD, "leather": P_LEATHER,
				"glow": P_GOLD, "skin": Color("#D8A97F"),
			}
		"adept":
			return {
				"main": P_BRONZE, "light": P_BRONZE_LIGHT, "dark": P_BRONZE_DARK,
				"bone": P_BONE, "iron": P_IRON, "gold": P_AMBER, "leather": P_LEATHER,
				"glow": P_AMBER, "skin": Color("#C6A184"),
			}
		_:
			return {
				"main": P_BRONZE, "light": P_BRONZE_LIGHT, "dark": P_BRONZE_DARK,
				"bone": P_BONE, "iron": P_IRON, "gold": P_AMBER, "leather": P_LEATHER,
				"glow": P_AMBER, "skin": Color("#C6A184"),
			}


static func build_unit(kind: String) -> Dictionary:
	var pal := _unit_palette(kind)
	var root := Node3D.new()
	root.name = "UnitModel"
	var rig := {"root": root, "legs": [], "arms": [], "height": float(D.unit_def(kind).height)}

	var shadow_r := 0.85 if kind == "hero" else 0.68
	add_shadow(root, shadow_r)

	# --- body mesh (torso / head / pauldrons / shield / backpack) ---
	var body := Kit.new()
	var hip_y := 1.12
	if kind == "hero":
		hip_y = 1.28
	elif kind == "adept":
		hip_y = 1.05
	var shoulder_y := hip_y + 0.68
	if kind == "hero":
		shoulder_y = hip_y + 0.74
	if kind == "adept":
		shoulder_y = 1.62

	if kind == "adept":
		# robe cone hides the legs; bone hem + chest sash
		body.cyl(0.17, 0.46, 1.72, Vector3(0, 0.88, 0), pal.main, 7)
		body.cyl(0.47, 0.51, 0.13, Vector3(0, 0.10, 0), pal.dark, 7)
		body.cyl(0.49, 0.49, 0.05, Vector3(0, 0.16, 0), pal.bone, 7)
		body.box(Vector3(0.22, 0.62, 0.05), Vector3(0, 1.18, 0.40), pal.bone, Vector3(-4, 0, 0))
		body.box(Vector3(0.30, 0.12, 0.06), Vector3(0, 1.42, 0.50), pal.gold)
		body.box(Vector3(0.48, 0.20, 0.30), Vector3(0, 1.60, 0.0), pal.dark)
		body.box(Vector3(0.16, 0.55, 0.10), Vector3(0, 1.90, -0.02), pal.main, Vector3(0, 0, 0))
		var head := Vector3(0, 2.03, 0.04)
		body.sphere(0.19, head, pal.skin, Vector3.ONE, 7, 4)
		body.cone(0.29, 0.68, Vector3(0, 2.38, -0.02), pal.main, 7)
		body.box(Vector3(0.28, 0.20, 0.06), Vector3(0, 2.05, 0.20), pal.bone)
		body.box(Vector3(0.10, 0.30, 0.05), Vector3(0, 1.98, 0.235), pal.dark)
		for side in [-1, 1]:
			body.box(Vector3(0.13, 0.48, 0.13), Vector3(0.30 * side, 1.55, 0.0), pal.dark,
				Vector3(0, 0, 8 * side))
		body.box(Vector3(0.46, 0.06, 0.06), Vector3(0, 1.68, 0.24), pal.gold)
	else:
		# hip / legs are separate; torso block
		body.box(Vector3(0.50, 0.24, 0.34), Vector3(0, hip_y + 0.06, 0), pal.dark)
		body.box(Vector3(0.62, 0.42, 0.40), Vector3(0, hip_y + 0.34, 0), pal.main)
		body.box(Vector3(0.66, 0.16, 0.43), Vector3(0, hip_y + 0.52, 0), pal.dark)
		body.box(Vector3(0.56, 0.20, 0.44), Vector3(0, hip_y + 0.30, 0), pal.iron)
		if kind == "guard":
			body.box(Vector3(0.22, 0.52, 0.03), Vector3(0, hip_y - 0.14, 0.21), pal.bone,
				Vector3(-2, 0, 0))
		else:
			body.box(Vector3(0.26, 0.34, 0.03), Vector3(0, hip_y + 0.12, 0.21), pal.leather)
		# pauldrons
		for side in [-1, 1]:
			body.box(Vector3(0.32, 0.22, 0.44), Vector3(0.44 * side, shoulder_y + 0.02, 0),
				pal.iron, Vector3(0, 0, -10 * side))
			if kind == "hero":
				# wing-like pauldron blades (hero silhouette)
				body.box(Vector3(0.10, 0.52, 0.34), Vector3(0.62 * side, shoulder_y + 0.24, -0.02),
					pal.bone, Vector3(0, 0, -46 * side))
				body.box(Vector3(0.08, 0.40, 0.26), Vector3(0.74 * side, shoulder_y + 0.48, -0.04),
					pal.gold, Vector3(0, 0, -58 * side))
			else:
				body.box(Vector3(0.30, 0.05, 0.46), Vector3(0.44 * side, shoulder_y + 0.14, 0),
					pal.bone, Vector3(0, 0, -10 * side))
		# neck + head
		body.cyl(0.10, 0.12, 0.16, Vector3(0, shoulder_y + 0.18, 0), pal.dark, 6)
		var head_y := shoulder_y + 0.42
		body.sphere(0.19, Vector3(0, head_y, 0.02), pal.skin, Vector3.ONE, 7, 4)
		# helmet
		body.cyl(0.215, 0.235, 0.28, Vector3(0, head_y + 0.12, 0), pal.iron, 6)
		body.box(Vector3(0.05, 0.20, 0.38), Vector3(0, head_y + 0.17, 0.02), pal.dark)
		if kind == "guard":
			body.box(Vector3(0.08, 0.30, 0.34), Vector3(0, head_y + 0.34, -0.02), pal.bone,
				Vector3(-12, 0, 0))
			body.box(Vector3(0.30, 0.07, 0.05), Vector3(0, head_y + 0.03, 0.185), pal.gold)
		elif kind == "bolt":
			# hood instead of helmet
			body.cone(0.31, 0.52, Vector3(0, head_y + 0.20, -0.04), pal.main, 7)
			body.box(Vector3(0.28, 0.08, 0.05), Vector3(0, head_y + 0.05, 0.19), pal.gold)
		elif kind == "hero":
			# crown spikes
			for i in 5:
				var ang := -1.0 + i * 0.5
				body.cone(0.045, 0.30, Vector3(sin(ang) * 0.20, head_y + 0.33, cos(ang) * 0.12 - 0.02),
					pal.gold, 4, Vector3(0, 0, -rad_to_deg(ang) * 0.25))
			body.box(Vector3(0.26, 0.07, 0.06), Vector3(0, head_y + 0.09, 0.19), pal.gold)
		# backs / silhouette breakers
		if kind == "bolt":
			# long coat flares the lower silhouette (distinct from the shield guard)
			body.box(Vector3(0.56, 0.78, 0.36), Vector3(0, hip_y - 0.26, -0.02), pal.leather,
				Vector3(-4, 0, 0))
			body.box(Vector3(0.66, 0.16, 0.40), Vector3(0, hip_y - 0.62, 0.0), pal.main)
			# quiver + arrows sticking above the hood on the back-left
			body.cyl(0.10, 0.12, 0.58, Vector3(-0.30, hip_y + 0.52, -0.28), pal.leather, 6,
				Vector3(12, 0, 18))
			for i in 3:
				body.box(Vector3(0.035, 0.92, 0.035), Vector3(-0.40 + i * 0.075, hip_y + 1.02, -0.30),
					pal.bone, Vector3(8, 0, 4))
				body.box(Vector3(0.16, 0.12, 0.02), Vector3(-0.40 + i * 0.075, hip_y + 1.42, -0.30),
					pal.gold, Vector3(8, 0, 4))
		if kind == "guard":
			# kite shield on the left, bone rim + bronze face + boss
			body.box(Vector3(1.18, 1.56, 0.05), Vector3(-0.62, 1.34, 0.22), pal.bone, Vector3(0, -14, 0))
			body.box(Vector3(1.02, 1.38, 0.06), Vector3(-0.62, 1.34, 0.27), pal.main, Vector3(0, -14, 0))
			body.box(Vector3(0.22, 0.98, 0.03), Vector3(-0.62, 1.34, 0.31), pal.bone, Vector3(0, -14, 0))
			body.box(Vector3(0.15, 0.58, 0.03), Vector3(-0.62, 1.34, 0.33), pal.iron, Vector3(0, -14, 0))
			body.box(Vector3(0.13, 0.46, 0.13), Vector3(-0.42, 1.62, 0.06), pal.dark,
				Vector3(0, 0, 20))
		if kind == "hero":
			# chest sigil + halberd shoulder guard
			body.box(Vector3(0.18, 0.22, 0.04), Vector3(0, hip_y + 0.36, 0.22), pal.gold)
			body.box(Vector3(0.34, 0.05, 0.05), Vector3(0, hip_y + 0.36, 0.225), pal.bone)

	var hips := Node3D.new()
	hips.name = "Hips"
	root.add_child(hips)
	rig["body"] = hips
	hips.add_child(_kit_instance(body, "lit", "Body"))

	# glow accents (eyes / shield boss / crown gem)
	var glow := Kit.new()
	if kind == "adept":
		_glow_dot(glow, Vector3(0, 2.02, 0.225), 0.045, pal.glow)
		_glow_dot(glow, Vector3(-0.09, 2.04, 0.22), 0.030, pal.glow)
		_glow_dot(glow, Vector3(0.09, 2.04, 0.22), 0.030, pal.glow)
	elif kind == "bolt":
		_glow_dot(glow, Vector3(-0.08, hip_y + 0.47, 0.19), 0.030, pal.glow)
		_glow_dot(glow, Vector3(0.08, hip_y + 0.47, 0.19), 0.030, pal.glow)
	else:
		var ey := 2.46 if kind == "hero" else 2.24
		_glow_dot(glow, Vector3(-0.08, ey, 0.21), 0.032, pal.glow)
		_glow_dot(glow, Vector3(0.08, ey, 0.21), 0.032, pal.glow)
	if kind == "guard":
		_glow_dot(glow, Vector3(-0.62, 1.34, 0.34), 0.11, pal.glow)
	if kind == "hero":
		_glow_dot(glow, Vector3(0, hip_y + 0.36, 0.24), 0.07, pal.gold)
	hips.add_child(_kit_instance(glow, "glow", "Glow"))

	# --- arms (one pivot; weapon + both arms swing together) ---
	var arms := Node3D.new()
	arms.name = "Arms"
	arms.position = Vector3(0, shoulder_y, 0)
	hips.add_child(arms)
	rig["arms"] = [arms]
	var ak := Kit.new()
	ak.box(Vector3(0.14, 0.52, 0.16), Vector3(-0.46, -0.26, 0.02), pal.main, Vector3(0, 0, -6))
	ak.box(Vector3(0.16, 0.16, 0.18), Vector3(-0.47, -0.53, 0.04), pal.iron)
	ak.box(Vector3(0.14, 0.52, 0.16), Vector3(0.46, -0.26, 0.02), pal.main, Vector3(0, 0, 6))
	ak.box(Vector3(0.16, 0.16, 0.18), Vector3(0.47, -0.53, 0.04), pal.iron)

	if kind == "guard":
		# 2.2m spear in the right hand
		ak.cyl(0.035, 0.045, 2.15, Vector3(0.50, -0.15, 0.12), pal.leather, 5, Vector3(8, 0, 0))
		ak.box(Vector3(0.18, 0.26, 0.03), Vector3(0.52, 0.82, 0.26), pal.bone, Vector3(8, 0, 0))
		ak.box(Vector3(0.30, 0.14, 0.02), Vector3(0.53, 0.98, 0.28), pal.gold, Vector3(8, 0, 0))
	elif kind == "bolt":
		# 1.7m crossbow T held forward: the strongest ranged silhouette cue
		ak.box(Vector3(0.09, 0.09, 0.78), Vector3(0.30, -0.24, 0.32), Color("#3A2B22"))
		ak.box(Vector3(1.70, 0.09, 0.10), Vector3(0.02, -0.16, 0.62), pal.iron)
		for side in [-1, 1]:
			ak.cone(0.075, 0.34, Vector3(0.02 + 0.85 * side, -0.16, 0.72), pal.bone, 4,
				Vector3(90, 0, 90 * side))
		ak.box(Vector3(0.10, 0.22, 0.10), Vector3(0.02, -0.26, 0.60), pal.dark)
		ak.box(Vector3(0.06, 0.06, 0.34), Vector3(0.02, -0.16, 0.86), pal.gold)
	elif kind == "adept":
		# 2.6m staff + ember prongs, orb floats above the head
		ak.cyl(0.04, 0.05, 2.90, Vector3(0.46, -0.12, 0.10), pal.leather, 5, Vector3(4, 0, 0))
		ak.torus(0.09, 0.13, Vector3(0.46, 0.84, 0.18), pal.gold, Vector3(90, 0, 0))
		ak.box(Vector3(0.05, 0.26, 0.05), Vector3(0.40, 0.96, 0.18), pal.gold, Vector3(0, 0, 25))
		ak.box(Vector3(0.05, 0.26, 0.05), Vector3(0.52, 0.96, 0.18), pal.gold, Vector3(0, 0, -25))
	elif kind == "hero":
		# 2.8m halberd with axe blade
		ak.cyl(0.045, 0.06, 2.7, Vector3(0.54, -0.97, 0.10), Color("#5A3D2C"), 5, Vector3(6, 0, 0))
		ak.box(Vector3(0.56, 0.46, 0.06), Vector3(0.72, 0.92, 0.24), pal.iron, Vector3(6, 0, -18))
		ak.box(Vector3(0.46, 0.30, 0.03), Vector3(0.74, 0.92, 0.28), pal.gold, Vector3(6, 0, -18))
		ak.cone(0.09, 0.34, Vector3(0.55, 1.18, 0.26), pal.bone, 4, Vector3(6, 0, 0))
	ak.box(Vector3(0.12, 0.12, 0.12), Vector3(0.46, -0.50, 0.12), pal.iron)
	arms.add_child(_kit_instance(ak, "lit", "ArmsMesh"))
	var aglow := Kit.new()
	if kind == "guard":
		_glow_dot(aglow, Vector3(0.53, 0.86, 0.30), 0.055, pal.glow)
	elif kind == "bolt":
		aglow.box(Vector3(1.44, 0.02, 0.02), Vector3(0.02, -0.16, 0.64), pal.glow)
		_glow_dot(aglow, Vector3(0.02, -0.16, 0.88), 0.045, pal.glow)
	elif kind == "adept":
		_glow_dot(aglow, Vector3(0.46, 1.28, 0.20), 0.17, pal.glow)
		_glow_dot(aglow, Vector3(0.46, 1.28, 0.20), 0.09, Color("#FFE0A8"))
	elif kind == "hero":
		_glow_dot(aglow, Vector3(0.74, 0.92, 0.31), 0.05, pal.gold)
	arms.add_child(_kit_instance(aglow, "glow", "ArmGlow"))

	# --- legs (2 pivots; robe classes hide them) ---
	if kind != "adept":
		for side in [-1, 1]:
			var leg := Node3D.new()
			leg.name = "LegL" if side < 0 else "LegR"
			leg.position = Vector3(0.17 * side, hip_y, 0)
			hips.add_child(leg)
			var lk := Kit.new()
			lk.box(Vector3(0.19, 0.86, 0.22), Vector3(0, -0.43, 0), pal.dark)
			lk.box(Vector3(0.20, 0.20, 0.30), Vector3(0, -0.90, 0.0), pal.iron)
			lk.box(Vector3(0.22, 0.14, 0.08), Vector3(0, -0.99, 0.14), pal.iron)
			leg.add_child(_kit_instance(lk, "lit", "LegMesh"))
			rig["legs"].append(leg)

	# --- hero cape (secondary motion) ---
	if kind == "hero":
		var cape := Node3D.new()
		cape.name = "Cape"
		cape.position = Vector3(0, shoulder_y + 0.02, -0.22)
		hips.add_child(cape)
		var ck := Kit.new()
		ck.box(Vector3(0.72, 1.42, 0.05), Vector3(0, -0.62, -0.10), P_BRONZE_DARK, Vector3(-8, 0, 0))
		ck.box(Vector3(0.78, 0.10, 0.06), Vector3(0, -1.30, -0.20), P_GOLD, Vector3(-8, 0, 0))
		ck.box(Vector3(0.10, 0.10, 0.10), Vector3(-0.32, 0.02, 0), P_GOLD)
		ck.box(Vector3(0.10, 0.10, 0.10), Vector3(0.32, 0.02, 0), P_GOLD)
		cape.add_child(_kit_instance(ck, "lit", "CapeMesh"))
		rig["cape"] = cape

	# markers used by older code paths
	rig["height"] = float(D.unit_def(kind).height)
	rig["weapon_tip"] = Vector3(0, float(D.unit_def(kind).height), 0.7)
	return rig


# ---------------------------------------------------------------- enemies

static func build_enemy(kind: String) -> Dictionary:
	var root := Node3D.new()
	root.name = "EnemyModel"
	var rig := {"root": root, "legs": [], "arms": [], "height": float(D.enemy_def(kind).height)}
	add_shadow(root, 1.55 if kind == "colossus" else 0.75)

	var body := Kit.new()
	var glow := Kit.new()
	var hips := Node3D.new()
	hips.name = "Hips"
	root.add_child(hips)
	rig["body"] = hips

	if kind == "crawler":
		# low quadruped, sickle jaws, bright carapace ridges
		var hip_y := 0.62
		body.sphere(0.46, Vector3(0, hip_y + 0.20, -0.10), E_BRUISE, Vector3(1.5, 0.62, 1.05), 7, 4)
		body.sphere(0.30, Vector3(0, hip_y + 0.16, 0.55), E_ABYSS, Vector3(0.9, 0.65, 0.9), 6, 4)
		body.box(Vector3(0.34, 0.16, 0.40), Vector3(0, hip_y + 0.44, -0.05), E_PURPLE, Vector3(8, 0, 0))
		for i in 3:
			body.box(Vector3(0.12, 0.32, 0.44), Vector3(0, hip_y + 0.40, -0.42 + i * 0.30), E_BONE,
				Vector3(18, 0, 0))
			body.box(Vector3(0.08, 0.40, 0.12), Vector3(0.22, hip_y + 0.30, -0.30 + i * 0.34), E_BONE,
				Vector3(0, 0, 18))
		# sickle jaws (0.5m, bone)
		for side in [-1, 1]:
			body.cyl(0.025, 0.075, 0.52, Vector3(0.17 * side, hip_y - 0.02, 0.92), E_BONE, 4,
				Vector3(84, 0, -26 * side))
			body.box(Vector3(0.10, 0.16, 0.20), Vector3(0.17 * side, hip_y + 0.15, 0.80), E_ABYSS)
		for side in [-1, 1]:
			var leg := Node3D.new()
			leg.position = Vector3(0.34 * side, hip_y, 0.08)
			hips.add_child(leg)
			var lk := Kit.new()
			lk.box(Vector3(0.10, 0.44, 0.10), Vector3(0.20 * side, -0.18, 0), E_ABYSS, Vector3(0, 0, 36 * side))
			lk.box(Vector3(0.10, 0.10, 0.38), Vector3(0.36 * side, -0.40, 0.08), E_BRUISE)
			lk.cone(0.06, 0.24, Vector3(0.42 * side, -0.46, 0.28), E_BONE, 4, Vector3(70, 0, 0))
			leg.add_child(_kit_instance(lk, "lit", "LegMesh"))
			rig["legs"].append(leg)
		_glow_dot(glow, Vector3(-0.16, hip_y + 0.20, 0.80), 0.055, E_ACID)
		_glow_dot(glow, Vector3(0.16, hip_y + 0.20, 0.80), 0.055, E_ACID)
		glow.box(Vector3(0.16, 0.04, 0.24), Vector3(0, hip_y + 0.52, 0.02), E_ACID)

	elif kind == "spitter":
		# hunched sac body with a tail cannon above the head
		var hip_y := 0.72
		body.sphere(0.58, Vector3(0, hip_y + 0.34, -0.30), E_BRUISE, Vector3(1.0, 0.95, 1.25), 7, 4)
		body.sphere(0.26, Vector3(0, hip_y + 0.50, -0.42), E_PURPLE, Vector3(1.0, 0.85, 1.0), 6, 4)
		body.sphere(0.22, Vector3(0, hip_y + 0.22, 0.52), E_ABYSS, Vector3(0.9, 0.8, 1.1), 6, 4)
		body.box(Vector3(0.44, 0.18, 0.30), Vector3(0, hip_y + 0.52, -0.10), E_PURPLE, Vector3(-12, 0, 0))
		for i in 3:
			body.box(Vector3(0.10, 0.26, 0.36), Vector3(-0.22 + i * 0.22, hip_y + 0.66, -0.42), E_BONE,
				Vector3(-24, 0, 0))
		# tail cannon, muzzle above head height
		body.cyl(0.09, 0.17, 1.25, Vector3(0, hip_y + 1.20, -0.34), E_ABYSS, 6, Vector3(-24, 0, 0))
		body.cyl(0.17, 0.20, 0.12, Vector3(0, hip_y + 1.80, -0.16), E_PURPLE, 6, Vector3(-24, 0, 0))
		for side in [-1, 1]:
			body.box(Vector3(0.08, 0.24, 0.08), Vector3(0.18 * side, hip_y + 0.34, 0.66), E_BONE,
				Vector3(0, 0, 24 * side))
		for side in [-1, 1]:
			var leg := Node3D.new()
			leg.position = Vector3(0.38 * side, hip_y, 0.06)
			hips.add_child(leg)
			var lk := Kit.new()
			lk.box(Vector3(0.12, 0.52, 0.12), Vector3(0.18 * side, -0.22, 0), E_ABYSS, Vector3(0, 0, 28 * side))
			lk.box(Vector3(0.12, 0.10, 0.40), Vector3(0.32 * side, -0.48, 0.10), E_BRUISE)
			leg.add_child(_kit_instance(lk, "lit", "LegMesh"))
			rig["legs"].append(leg)
		_glow_dot(glow, Vector3(-0.14, hip_y + 0.26, 0.66), 0.05, E_ACID)
		_glow_dot(glow, Vector3(0.14, hip_y + 0.26, 0.66), 0.05, E_ACID)
		glow.sphere(0.30, Vector3(0, hip_y + 0.58, -0.30), Color(E_ACID.r, E_ACID.g, E_ACID.b, 0.85),
			Vector3(1.0, 0.75, 1.0), 7, 4)
		glow.torus(0.16, 0.21, Vector3(0, hip_y + 1.86, -0.12), E_ACID, Vector3(-24, 0, 0))

	else:
		# colossus: plate hulk, one oversized fist, chest furnace
		var hip_y := 1.18
		body.box(Vector3(1.30, 1.30, 0.92), Vector3(0, hip_y + 0.95, 0), E_BRUISE)
		body.box(Vector3(1.52, 0.34, 1.02), Vector3(0, hip_y + 1.62, 0), E_ABYSS)
		body.box(Vector3(0.60, 0.58, 0.62), Vector3(0, hip_y + 1.95, 0.10), E_PURPLE)
		body.box(Vector3(0.98, 0.20, 0.86), Vector3(0, hip_y + 0.32, 0), E_ABYSS)
		for i in 3:
			body.cone(0.18, 0.62 - i * 0.08, Vector3(0, hip_y + 1.78, -0.34 - i * 0.22), E_PURPLE.darkened(0.15),
				4, Vector3(26, 0, 0))
		for side in [-1, 1]:
			body.box(Vector3(0.50, 0.40, 0.70), Vector3(0.78 * side, hip_y + 1.48, 0), E_ABYSS,
				Vector3(0, 0, 14 * side))
			for i in 2:
				body.cone(0.12, 0.55 - i * 0.12, Vector3(0.86 * side, hip_y + 1.72 + i * 0.14, -0.12),
					E_BONE, 4, Vector3(-18 - i * 10, 0, 32 * side))
			body.box(Vector3(0.40, 0.90, 0.42), Vector3(0.86 * side, hip_y + 0.86, 0.04), E_BRUISE,
				Vector3(0, 0, 5 * side))
		for i in 3:
			body.box(Vector3(0.16, 0.24, 0.52), Vector3(-0.34 + i * 0.34, hip_y + 1.18, 0.48), E_BONE,
				Vector3(0, 0, 12 - i * 8))
		# oversized right fist
		body.box(Vector3(0.72, 0.56, 0.68), Vector3(0.98, hip_y + 0.20, 0.12), E_ABYSS)
		for i in 3:
			body.box(Vector3(0.18, 0.16, 0.20), Vector3(1.06, hip_y + 0.42 - i * 0.17, 0.38), E_BONE)
		# left shield plate
		body.box(Vector3(0.34, 0.85, 0.72), Vector3(-1.02, hip_y + 0.76, 0.12), E_ABYSS, Vector3(0, 0, -8))
		for side in [-1, 1]:
			var leg := Node3D.new()
			leg.position = Vector3(0.46 * side, hip_y, 0)
			hips.add_child(leg)
			var lk := Kit.new()
			lk.box(Vector3(0.36, 0.92, 0.42), Vector3(0, -0.46, 0), E_BRUISE)
			lk.box(Vector3(0.48, 0.22, 0.62), Vector3(0, -0.98, 0.08), E_ABYSS)
			leg.add_child(_kit_instance(lk, "lit", "LegMesh"))
			rig["legs"].append(leg)
		glow.sphere(0.32, Vector3(0, hip_y + 1.06, 0.47), E_MOLTEN, Vector3(1.0, 1.0, 0.55), 7, 4)
		glow.torus(0.34, 0.42, Vector3(0, hip_y + 1.06, 0.47), E_MOLTEN, Vector3(90, 0, 0))
		_glow_dot(glow, Vector3(-0.20, hip_y + 1.92, 0.34), 0.07, E_ACID)
		_glow_dot(glow, Vector3(0.20, hip_y + 1.92, 0.34), 0.07, E_ACID)
		for i in 3:
			glow.box(Vector3(0.06, 0.04, 0.26), Vector3(-0.30 + i * 0.30, hip_y + 1.34, 0.47), E_MOLTEN)

	hips.add_child(_kit_instance(body, "lit", "Body"))
	hips.add_child(_kit_instance(glow, "glow", "Glow"))

	# enemy attack telegraph decal (hidden; shown by actor while winding up)
	var tele := MeshInstance3D.new()
	tele.name = "Telegraph"
	var q := PlaneMesh.new()
	q.size = Vector2(2.8, 2.8) if kind == "colossus" else Vector2(1.6, 1.6)
	tele.mesh = q
	tele.material_override = ground_glow_material(Color(E_ACID.r, E_ACID.g, E_ACID.b, 0.22),
		radial_texture(48, 0.28), false)
	tele.position = Vector3(0, 0.05, 0.9)
	tele.visible = false
	tele.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tele)
	rig["telegraph"] = tele

	rig["height"] = float(D.enemy_def(kind).height)
	return rig


# ---------------------------------------------------------------- towers

static func build_tower(kind: String, level: int = 1) -> Dictionary:
	var def := D.tower_def(kind)
	var root := Node3D.new()
	root.name = "TowerModel"
	var rig := {"root": root, "level": level}
	var accent := Color(def.accent)
	add_shadow(root, 1.55)

	# --- shared octagonal base ---
	var base := Kit.new()
	base.cyl(1.45, 1.62, 0.50, Vector3(0, 0.25, 0), T_STONE, 8)
	base.cyl(1.34, 1.44, 0.14, Vector3(0, 0.56, 0), Color("#5A535F"), 8)
	for i in 8:
		var a := i * TAU / 8.0 + PI / 8.0
		base.box(Vector3(0.26, 0.30, 0.26), Vector3(cos(a) * 1.48, 0.20, sin(a) * 1.48),
			T_STONE_DARK, Vector3(0, -rad_to_deg(a), 0))
	for i in 3:
		var a := deg_to_rad(90.0 + i * 120.0)
		base.box(Vector3(0.34, 0.10, 0.34), Vector3(cos(a) * 1.15, 0.64, sin(a) * 1.15),
			Color("#26232C"), Vector3(0, -rad_to_deg(a), 0))
	root.add_child(_kit_instance(base, "lit", "Base"))

	# --- level flags (1/2/3 diamonds, team color) ---
	var acc := Kit.new()
	acc.torus(1.20, 1.30, Vector3(0, 0.64, 0), Color(accent.r, accent.g, accent.b, 0.55), Vector3.ZERO)
	for i in level:
		var a := deg_to_rad(90.0 + i * 120.0)
		var fp := Vector3(cos(a) * 1.68, 1.32, sin(a) * 1.68)
		acc.box(Vector3(0.44, 0.94, 0.05), fp, accent, Vector3(0, -rad_to_deg(a), 45))
		acc.cyl(0.045, 0.055, 0.98, fp - Vector3(0, 0.62, 0), T_STONE_DARK, 4)

	# --- head + silhouette per type ---
	var head := Node3D.new()
	head.name = "Head"
	root.add_child(head)
	rig["head"] = head
	var hk := Kit.new()
	var hg := Kit.new()
	var muzzle_y := 2.0

	if kind == "prism":
		# needle spire: single shard L1 → twin L2 → tri crown L3
		hk.cyl(0.42, 0.62, 1.60, Vector3(0, 1.40, 0), Color("#4A4350"), 6)
		hk.cyl(0.30, 0.42, 0.55, Vector3(0, 2.40, 0), P_IRON_DARK, 6)
		var lv_scale := 1.0 + 0.06 * (level - 1)
		var forks := 1 if level <= 1 else (2 if level == 2 else 3)
		for i in forks:
			var ang := 0.0 if forks == 1 else (-0.42 + i * 0.42)
			var off := Vector3(sin(ang) * 0.34, 0, cos(ang) * 0.10)
			var h := (1.55 + (0.22 if i == 1 else 0.0)) * lv_scale
			hg.cyl(0.0, 0.17, h, Vector3(0, 2.75 + h * 0.5, 0) + off, accent, 4,
				Vector3(0, rad_to_deg(ang), 0))
			hg.sphere(0.09, Vector3(0, 2.72, 0) + off, Color("#D8FFF5"), Vector3.ONE, 6, 3)
		for i in level - 1:
			acc.torus(0.55 + i * 0.16, 0.60 + i * 0.16, Vector3(0, 3.05 + i * 0.42, 0), accent,
				Vector3(88 + i * 16, 12 * i, 0))
		muzzle_y = 3.75 * lv_scale
		rig["muzzle"] = Vector3(0, muzzle_y, 0)

	elif kind == "mortar":
		# squat bowl, 25° barrel; L2 twin barrels, L3 cauldron + chimneys
		hk.cyl(0.95, 1.20, 0.70, Vector3(0, 0.95, 0), Color("#4A4350"), 7)
		hk.sphere(0.86, Vector3(0, 1.35, 0), T_STONE, Vector3(1.0, 0.42, 1.0), 8, 4)
		if level >= 3:
			hk.cyl(0.92, 0.66, 0.55, Vector3(0, 1.62, 0), Color("#2E2A30"), 8)
		var barrel := Node3D.new()
		barrel.position = Vector3(0, 1.55, 0)
		barrel.rotation_degrees = Vector3(-25, 0, 0)
		head.add_child(barrel)
		hk.cyl(0.17, 0.27, 1.05, Vector3(0, 0.42, 0), P_IRON_DARK, 7)
		hk.cyl(0.27, 0.29, 0.16, Vector3(0, 0.96, 0), T_STONE, 7)
		hg.torus(0.20, 0.26, Vector3(0, 1.02, 0), accent, Vector3.ZERO)
		if level == 2:
			for side in [-1, 1]:
				hk.cyl(0.16, 0.24, 0.85, Vector3(0.66 * side, 1.62, 0.10), P_IRON_DARK, 7,
					Vector3(0, 0, 28 * side))
				hg.torus(0.18, 0.23, Vector3(0.82 * side, 1.92, 0.10), accent, Vector3(0, 0, 28 * side))
		if level >= 3:
			hg.cyl(0.34, 0.46, 0.22, Vector3(0, 2.12, 0), accent, 8)
		if level >= 2:
			hk.box(Vector3(0.16, 0.72, 0.16), Vector3(-0.82, 1.62, -0.30), Color("#2A262E"), Vector3(0, 0, 12))
			hk.box(Vector3(0.16, 0.62, 0.16), Vector3(0.82, 1.55, -0.26), Color("#2A262E"), Vector3(0, 0, -10))
		if level >= 3:
			for i in 3:
				var a := i * TAU / 3.0 + 0.4
				hk.cyl(0.16, 0.20, 0.85, Vector3(cos(a) * 0.62, 2.05, sin(a) * 0.62),
					Color("#2A262E"), 6, Vector3(0, -rad_to_deg(a), 0))
				hg.torus(0.13, 0.17, Vector3(cos(a) * 0.62, 2.50, sin(a) * 0.62), accent, Vector3.ZERO)
		muzzle_y = 2.4 if level >= 2 else 2.5
		rig["muzzle"] = Vector3(0, muzzle_y, 0.9)
		rig["barrel"] = head

	else:
		# frost stele: rings 1/2/3, ice spikes at L2, ground frost at L3
		hk.box(Vector3(0.86, 0.34, 0.86), Vector3(0, 0.78, 0), Color("#2E2A30"))
		hk.cyl(0.42, 0.60, 1.70, Vector3(0, 1.60, 0), Color("#4A4854"), 6)
		hk.box(Vector3(0.58, 1.55, 0.14), Vector3(0, 1.60, 0.40), Color("#4A4F55"), Vector3(-3, 0, 0))
		hg.sphere(0.22, Vector3(0, 2.55, 0.42), accent, Vector3(0.8, 1.35, 0.55), 6, 4)
		for i in level:
			acc.torus(0.52 + i * 0.12, 0.56 + i * 0.12, Vector3(0, 2.18 + i * 0.38, 0), accent,
				Vector3(90, 10 + i * 25, 0))
		if level >= 2:
			for i in 4:
				var a := i * TAU / 4.0 + PI / 4.0
				hg.cone(0.13, 0.95, Vector3(cos(a) * 0.74, 1.70, sin(a) * 0.74), accent, 4,
					Vector3(28 * sin(a), 0, -28 * cos(a)))
			hg.sphere(0.28, Vector3(0, 2.62, 0.42), accent, Vector3(0.85, 1.5, 0.6), 6, 4)
		if level >= 3:
			for i in 2:
				acc.torus(0.62 + i * 0.15, 0.67 + i * 0.15, Vector3(0, 2.45 + i * 0.3, 0), accent,
					Vector3(70, 30 * i, 20))
			var frost := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 9.5
			disc.bottom_radius = 9.5
			disc.height = 0.02
			disc.radial_segments = 24
			frost.mesh = disc
			frost.material_override = ground_glow_material(Color(accent.r, accent.g, accent.b, 0.16),
				radial_texture(64, 0.42), false)
			frost.position = Vector3(0, 0.04, 0)
			frost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(frost)
		muzzle_y = 2.55
		rig["muzzle"] = Vector3(0, muzzle_y, 0)

	head.add_child(_kit_instance(hk, "lit", "HeadBody"))
	head.add_child(_kit_instance(hg, "glow", "HeadGlow"))
	head.scale = Vector3(1.0, 1.0 + 0.06 * (level - 1), 1.0)
	root.add_child(_kit_instance(acc, "alpha", "Accents"))

	# muzzle flash (toggled by tower.gd)
	var flash_mi := MeshInstance3D.new()
	flash_mi.name = "MuzzleFlash"
	var fk := Kit.new()
	fk.sphere(0.24, Vector3(0, muzzle_y, 0.0) if kind != "mortar" else Vector3(0, muzzle_y, 0.9),
		accent, Vector3.ONE, 6, 3)
	fk.torus(0.26, 0.34, Vector3(0, muzzle_y, 0.0), accent, Vector3(90, 0, 0))
	flash_mi.mesh = fk.commit(_vcol_glow_mat())
	flash_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_mi.visible = false
	head.add_child(flash_mi)
	rig["muzzle_flash"] = flash_mi
	rig["beam_color"] = accent
	return rig


# ---------------------------------------------------------------- core / portal / pads

static func build_core() -> Dictionary:
	var root := Node3D.new()
	root.name = "Core"
	var stone := Color("#8A8194")
	var dark := Color("#3A3430")
	var teal := D.C_TEAL

	var base := Kit.new()
	base.cyl(6.2, 6.8, 0.34, Vector3(0, 0.17, 0), Color("#221F26"), 8)
	base.cyl(4.6, 5.1, 0.30, Vector3(0, 0.48, 0), Color("#4A4550"), 8)
	base.cyl(2.2, 3.0, 0.62, Vector3(0, 0.92, 0), Color("#3A3540"), 8)
	for i in 6:
		var a := i * TAU / 6.0
		base.box(Vector3(0.46, 1.30, 0.46), Vector3(cos(a) * 3.4, 1.15, sin(a) * 3.4),
			Color("#6B6275"), Vector3(0, -rad_to_deg(a), 0))
		base.box(Vector3(0.56, 0.18, 0.56), Vector3(cos(a) * 3.4, 1.86, sin(a) * 3.4),
			dark, Vector3(0, -rad_to_deg(a), 0))
	# 4 braziers
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		var p := Vector3(cos(a) * 6.2, 0, sin(a) * 6.2)
		base.cyl(0.30, 0.44, 0.55, p + Vector3(0, 0.30, 0), dark, 6)
		base.cyl(0.48, 0.34, 0.26, p + Vector3(0, 0.68, 0), stone, 6)
		base.box(Vector3(0.10, 1.10, 0.10), p + Vector3(0, 0.55, 0), stone, Vector3(0, 0, 0))
	# flag poles + teal banners
	for i in 4:
		var a := i * TAU / 4.0 + 0.2
		var p := Vector3(cos(a) * 8.6, 0, sin(a) * 8.6)
		base.cyl(0.12, 0.16, 4.6, p + Vector3(0, 2.3, 0), Color("#3A2F2A"), 5)
		base.box(Vector3(1.3, 0.75, 0.05), p + Vector3(cos(a + 0.6) * 0.55, 4.1, sin(a + 0.6) * 0.55),
			Color("#1F8F7C"), Vector3(0, -rad_to_deg(a + 0.6), 0))
		base.box(Vector3(1.38, 0.10, 0.06), p + Vector3(cos(a + 0.6) * 0.55, 4.48, sin(a + 0.6) * 0.55),
			P_GOLD, Vector3(0, -rad_to_deg(a + 0.6), 0))
	root.add_child(_kit_instance(base, "lit", "CoreBase"))

	# glow kit: orbit rings + rune ring + brazier flames merged
	var glow := Kit.new()
	glow.torus(4.9, 5.02, Vector3(0, 0.55, 0), Color(teal.r, teal.g, teal.b, 0.30), Vector3.ZERO)
	for i in 2:
		glow.torus(1.9 + i * 0.35, 1.97 + i * 0.35, Vector3(0, 3.6 + i * 1.1, 0), teal,
			Vector3(88 + (i * 2 - 1) * 14, 22 * i, 0))
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		glow.sphere(0.30, Vector3(cos(a) * 6.2, 1.05, sin(a) * 6.2), Color("#FF8A3C"),
			Vector3(1.0, 1.8, 1.0), 6, 3)
	root.add_child(_kit_instance(glow, "alpha", "CoreGlow"))

	# central crystal (unique material so damage states can dim it)
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color("#2FB9AE")
	core_mat.emission_enabled = true
	core_mat.emission = teal
	core_mat.emission_energy_multiplier = 0.75
	core_mat.roughness = 0.3
	core_mat.metallic = 0.0
	core_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var ck := Kit.new()
	ck.sphere(1.05, Vector3(0, 0, 0), Color.WHITE, Vector3(0.88, 2.60, 0.88), 7, 5)
	ck.cone(0.55, 0.9, Vector3(0, 2.55, 0), Color.WHITE, 4, Vector3(0, 0, 0))
	var crystal := MeshInstance3D.new()
	crystal.name = "CoreCrystal"
	crystal.mesh = ck.commit(core_mat)
	crystal.position = Vector3(0, 3.6, 0)
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(crystal)

	# cracks (hidden at full HP)
	var cracks := Kit.new()
	for i in 3:
		var a := i * TAU / 3.0 + 0.3
		cracks.box(Vector3(0.06, 1.9 + i * 0.5, 0.04),
			Vector3(cos(a) * 0.55, 3.6 + i * 0.9, sin(a) * 0.55), Color("#0B2A28"),
			Vector3(0, -rad_to_deg(a), 12 - i * 14))
	var crack_node := _kit_instance(cracks, "lit", "Cracks")
	crack_node.visible = false
	root.add_child(crack_node)

	return {"root": root, "crystal": crystal, "material": core_mat, "cracks": crack_node}


static func build_portal(tint: Color, style: int = 0) -> Dictionary:
	var root := Node3D.new()
	root.name = "Portal"
	var stone := Color("#302C28")
	var dark := Color("#1C1917")
	var trim := Color("#4A443C")

	# ground stain
	add_quad_flat(root, Vector3(12, 0, 12), Vector3(0, 0.04, 0),
		ground_glow_material(Color(tint.r, tint.g, tint.b, 0.16), radial_texture(64, 0.3), false))

	var frame := Kit.new()
	var glow := Kit.new()
	if style == 0:
		# north: double-horn gate
		for side in [-1, 1]:
			frame.cyl(0.22, 0.44, 6.4, Vector3(2.3 * side, 3.2, 0), stone, 6,
				Vector3(0, 0, -7 * side))
			frame.cyl(0.10, 0.22, 2.4, Vector3(2.75 * side, 6.9, 0), stone, 5,
				Vector3(0, 0, -22 * side))
			frame.box(Vector3(0.9, 0.5, 0.9), Vector3(2.3 * side, 0.30, 0), dark)
			glow.torus(0.42, 0.48, Vector3(2.75 * side, 6.9, 0), tint, Vector3(0, 0, 0))
		frame.box(Vector3(6.2, 0.55, 0.7), Vector3(0, 6.35, 0), trim, Vector3(0, 0, 0))
		frame.box(Vector3(0.5, 0.9, 0.5), Vector3(0, 6.75, 0), stone)
	elif style == 1:
		# west: broken arch
		frame.cyl(0.30, 0.52, 5.4, Vector3(-2.2, 2.7, 0), stone, 6, Vector3(0, 0, 5))
		frame.cyl(0.24, 0.42, 3.4, Vector3(2.2, 1.7, 0), stone, 6, Vector3(0, 0, -12))
		frame.box(Vector3(3.2, 0.6, 0.8), Vector3(-0.5, 5.0, 0), trim, Vector3(0, 0, -8))
		frame.box(Vector3(1.4, 0.5, 0.7), Vector3(1.7, 3.15, 0), trim, Vector3(0, 0, 16))
		frame.box(Vector3(1.0, 0.6, 1.0), Vector3(-2.2, 0.30, 0), dark)
		frame.box(Vector3(0.8, 0.4, 0.8), Vector3(2.2, 0.20, 0), dark)
		glow.box(Vector3(0.18, 2.6, 0.08), Vector3(-2.19, 3.0, 0.30), tint)
	else:
		# east: half-sunken ring
		frame.torus(3.4, 3.85, Vector3(0, 1.6, 0), stone, Vector3(90, 0, 0))
		for side in [-1, 1]:
			frame.box(Vector3(1.0, 1.5, 1.4), Vector3(3.4 * side, 0.55, 0), dark,
				Vector3(0, 0, 12 * side))
		frame.box(Vector3(1.2, 2.2, 1.0), Vector3(0, 0.6, -0.9), stone)
		glow.torus(3.30, 3.42, Vector3(0, 1.6, 0.10), tint, Vector3(90, 0, 0))
		for i in 5:
			var a := -PI * 0.5 + i * PI / 4.0
			glow.box(Vector3(0.14, 0.42, 0.06), Vector3(cos(a) * 3.36, 1.6 + sin(a) * 3.36, 0.12),
				tint, Vector3(0, 0, rad_to_deg(a)))
	# team pennant
	frame.cyl(0.07, 0.10, 1.5, Vector3(0, 7.6 if style == 0 else 5.6, 0), Color("#3A2F2A"), 4)
	frame.box(Vector3(0.8, 0.46, 0.03), Vector3(0.42, 8.05 if style == 0 else 6.05, 0), E_PURPLE)
	root.add_child(_kit_instance(frame, "lit", "PortalFrame"))
	root.add_child(_kit_instance(glow, "glow", "PortalRunes"))

	# vortex veil (billboard, purple, never white-hot)
	var veil := add_billboard(root, 4.8 if style != 2 else 5.8, Vector3(0, 2.6 if style != 2 else 1.9, 0),
		Color(tint.r * 0.72, tint.g * 0.55, tint.b * 0.92, 0.5), radial_texture(64, 0.10), false)
	veil.name = "Veil"
	var inner := add_billboard(root, 2.6, Vector3(0, 2.2 if style != 2 else 1.7, 0.05),
		Color(tint.r * 0.55, tint.g * 0.35, tint.b * 0.75, 0.55), radial_texture(64, 0.2), false)
	inner.name = "VeilInner"

	# orbiting shards (one merged, rotating cluster)
	var shards := Node3D.new()
	shards.position = Vector3(0, 3.4 if style != 2 else 2.2, 0)
	root.add_child(shards)
	var sk := Kit.new()
	for i in 3:
		var a := i * TAU / 3.0
		sk.box(Vector3(0.18, 0.52, 0.07), Vector3(cos(a) * 1.9, sin(a) * 0.5, sin(a) * 1.9), tint,
			Vector3(0, rad_to_deg(a), 18))
	shards.add_child(_kit_instance(sk, "glow", "Shards"))

	return {"root": root, "veil": veil, "veil_inner": inner, "shards": shards, "tint": tint, "style": style}


static func build_pad(index: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Pad%d" % index
	var base := Kit.new()
	base.cyl(1.85, 2.05, 0.26, Vector3(0, 0.13, 0), Color("#3F3A45"), 8)
	base.cyl(1.62, 1.78, 0.12, Vector3(0, 0.32, 0), Color("#4E4854"), 8)
	for i in 3:
		var a := deg_to_rad(90.0 + i * 120.0)
		base.box(Vector3(0.42, 0.10, 0.42), Vector3(cos(a) * 1.28, 0.40, sin(a) * 1.28),
			Color("#26232A"), Vector3(0, -rad_to_deg(a), 0))
	for i in 4:
		var a := i * TAU / 4.0 + 0.3
		base.box(Vector3(0.24, 0.38, 0.24), Vector3(cos(a) * 1.62, 0.30, sin(a) * 1.62),
			Color("#4E4854"), Vector3(0, -rad_to_deg(a), 0))
	root.add_child(_kit_instance(base, "lit", "PadBase"))

	var rune := Kit.new()
	for i in 12:
		var a := i * TAU / 12.0
		rune.box(Vector3(0.22, 0.02, 0.05), Vector3(cos(a) * 1.40, 0.41, sin(a) * 1.40),
			Color(D.C_TEAL.r, D.C_TEAL.g, D.C_TEAL.b, 0.55), Vector3(0, -rad_to_deg(a), 0))
	var rune_mi := _kit_instance(rune, "glow", "Rune")
	root.add_child(rune_mi)

	var plus := Node3D.new()
	plus.name = "Plus"
	plus.position.y = 0.45
	root.add_child(plus)
	var pk := Kit.new()
	pk.box(Vector3(0.92, 0.05, 0.12), Vector3.ZERO, D.C_TEAL)
	pk.box(Vector3(0.12, 0.05, 0.92), Vector3.ZERO, D.C_TEAL)
	pk.box(Vector3(0.28, 0.05, 0.28), Vector3(0, 0.02, 0), D.C_TEAL.lightened(0.35))
	plus.add_child(_kit_instance(pk, "glow", "PlusIcon"))
	return {"root": root, "rune": rune_mi, "plus": plus}


static func build_barracks() -> Dictionary:
	var root := Node3D.new()
	root.name = "Barracks"
	var stone := Color("#5D576B")
	var dark := Color("#2E2A35")
	var teal := D.C_TEAL
	var base := Kit.new()
	base.cyl(3.4, 3.8, 0.32, Vector3(0, 0.16, 0), Color("#221F26"), 8)
	base.box(Vector3(3.6, 2.3, 2.8), Vector3(0, 1.5, 0), stone)
	base.box(Vector3(4.0, 0.34, 3.1), Vector3(0, 2.78, 0), dark)
	base.cyl(1.5, 1.7, 0.95, Vector3(0, 3.4, 0), dark, 6)
	base.cone(1.65, 1.9, Vector3(0, 4.75, 0), Color("#1F4A44"), 6)
	base.box(Vector3(1.4, 1.9, 0.14), Vector3(0, 1.15, 1.42), Color("#191820"))
	base.box(Vector3(1.7, 0.18, 0.22), Vector3(0, 2.20, 1.46), teal)
	base.box(Vector3(0.24, 0.78, 0.16), Vector3(-0.6, 1.10, 1.46), teal)
	base.box(Vector3(0.24, 0.78, 0.16), Vector3(0.6, 1.10, 1.46), teal)
	for side in [-1, 1]:
		base.box(Vector3(0.22, 1.1, 0.22), Vector3(1.5 * side, 1.0, 1.5), Color("#3A2F2A"),
			Vector3(0, 0, 6 * side))
		base.box(Vector3(0.9, 0.55, 0.04), Vector3(1.5 * side + 0.42, 1.95, 1.5), Color("#1F8F7C"),
			Vector3(0, 0, 0))
	root.add_child(_kit_instance(base, "lit", "BarracksBase"))
	var glow := Kit.new()
	glow.torus(2.9, 3.02, Vector3(0, 0.34, 0), Color(teal.r, teal.g, teal.b, 0.40), Vector3.ZERO)
	glow.box(Vector3(1.5, 0.10, 0.16), Vector3(0, 2.42, 1.46), teal)
	root.add_child(_kit_instance(glow, "glow", "BarracksGlow"))
	return {"root": root}


static func build_rally_flag() -> Node3D:
	var root := Node3D.new()
	root.name = "RallyFlag"
	var pole := Kit.new()
	pole.cyl(0.05, 0.09, 2.2, Vector3(0, 1.1, 0), Color("#5A4534"), 5)
	pole.box(Vector3(0.82, 0.5, 0.04), Vector3(0.44, 1.9, 0), D.C_TEAL)
	pole.box(Vector3(0.9, 0.08, 0.05), Vector3(0.44, 2.18, 0), P_GOLD)
	root.add_child(_kit_instance(pole, "lit", "FlagPole"))
	var glow := Kit.new()
	glow.sphere(0.09, Vector3(0, 2.26, 0), D.C_TEAL, Vector3.ONE, 5, 3)
	glow.torus(0.9, 0.97, Vector3(0, 0.05, 0), Color(D.C_TEAL.r, D.C_TEAL.g, D.C_TEAL.b, 0.35), Vector3.ZERO)
	root.add_child(_kit_instance(glow, "glow", "FlagGlow"))
	return root


# ---------------------------------------------------------------- rings / vfx

static func build_selection_ring(radius: float, color: Color, strength: float = 1.0) -> Node3D:
	var root := Node3D.new()
	var k := Kit.new()
	k.torus(radius - 0.09, radius, Vector3(0, 0.06, 0),
		Color(color.r, color.g, color.b, 0.85 * strength), Vector3.ZERO)
	k.torus(radius - 0.28, radius - 0.22, Vector3(0, 0.06, 0),
		Color(color.r, color.g, color.b, 0.22 * strength), Vector3.ZERO)
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		k.box(Vector3(0.34, 0.02, 0.07),
			Vector3(cos(a) * (radius + 0.10), 0.06, sin(a) * (radius + 0.10)),
			Color(color.r, color.g, color.b, 0.9 * strength), Vector3(0, -rad_to_deg(a), 0))
	k.disc(radius - 0.05, Vector3(0, 0.045, 0), Color(color.r, color.g, color.b, 0.06 * strength), 16)
	var mi := _kit_instance(k, "alpha", "Ring")
	root.add_child(mi)
	return root


static func build_range_ring(radius: float, color: Color, strength: float = 1.0) -> Node3D:
	var root := Node3D.new()
	var k := Kit.new()
	k.torus(radius - 0.07, radius, Vector3(0, 0.07, 0), Color(color.r, color.g, color.b, 0.42 * strength),
		Vector3.ZERO)
	for i in 18:
		var a := i * TAU / 18.0
		k.box(Vector3(0.16, 0.015, 0.05), Vector3(cos(a) * radius, 0.07, sin(a) * radius),
			Color(color.r, color.g, color.b, 0.30 * strength), Vector3(0, -rad_to_deg(a), 0))
	k.disc(radius - 0.2, Vector3(0, 0.05, 0), Color(color.r, color.g, color.b, 0.025 * strength), 24)
	root.add_child(_kit_instance(k, "alpha", "RangeRing"))
	return root


static func build_shockwave(radius: float, color: Color) -> Node3D:
	var root := Node3D.new()
	var k := Kit.new()
	var s := color.a if color.a < 1.0 else 1.0
	k.torus(radius - 0.14, radius, Vector3(0, 0.10, 0), Color(color.r, color.g, color.b, 0.34 * s), Vector3.ZERO)
	k.torus(radius - 0.42, radius - 0.35, Vector3(0, 0.09, 0), Color(color.r, color.g, color.b, 0.12 * s),
		Vector3.ZERO)
	root.add_child(_kit_instance(k, "alpha", "Wave"))
	return root


static func build_slash(color: Color, size: float = 1.0) -> Node3D:
	var root := Node3D.new()
	var k := Kit.new()
	for i in 3:
		var a := -0.8 + i * 0.55
		k.box(Vector3(0.12 * size, 0.05, 0.62 * size),
			Vector3(sin(a) * size * 0.5, 0, cos(a) * size * 0.5),
			Color(color.r, color.g, color.b, 0.75), Vector3(0, rad_to_deg(a), 0))
	k.torus(0.55 * size, 0.62 * size, Vector3.ZERO, Color(color.r, color.g, color.b, 0.30),
		Vector3(90, 0, 0))
	root.add_child(_kit_instance(k, "alpha", "Slash"))
	return root


static func build_projectile_visual(kind: String) -> Node3D:
	var root := Node3D.new()
	var color := Color("#8CE8FF")
	var radius := 0.12
	if kind == "fire":
		color = Color("#FF9A4F")
		radius = 0.17
	elif kind == "mortar":
		color = Color("#FFB35C")
		radius = 0.22
	elif kind == "acid":
		color = Color("#B9E84A")
		radius = 0.15
	elif kind == "frost":
		color = Color("#9FE8FF")
		radius = 0.13
	var k := Kit.new()
	k.sphere(radius, Vector3.ZERO, color, Vector3.ONE, 6, 3)
	k.sphere(radius * 0.55, Vector3.ZERO, color.lightened(0.35), Vector3.ONE, 6, 3)
	k.box(Vector3(radius * 0.8, radius * 0.8, radius * 3.2), Vector3(0, 0, -radius * 2.0),
		Color(color.r, color.g, color.b, 0.35))
	root.add_child(_kit_instance(k, "alpha", "Projectile"))
	return root


static func build_impact_burst(color: Color, size: float) -> Node3D:
	var root := Node3D.new()
	var k := Kit.new()
	k.sphere(0.12 * size, Vector3.ZERO, color, Vector3.ONE, 5, 3)
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		k.box(Vector3(0.04 * size, 0.04 * size, 0.42 * size),
			Vector3(cos(a) * 0.30 * size, 0.06, sin(a) * 0.30 * size),
			Color(color.r, color.g, color.b, 0.8), Vector3(0, rad_to_deg(a), 0))
	k.torus(0.30 * size, 0.36 * size, Vector3(0, 0.02, 0), Color(color.r, color.g, color.b, 0.35),
		Vector3.ZERO)
	root.add_child(_kit_instance(k, "alpha", "Burst"))
	return root


static func build_hero_skill_fx(radius: float, color: Color) -> Node3D:
	# three concentric rings + ember spokes; near-white surface kept under 4%
	var root := Node3D.new()
	var k := Kit.new()
	k.torus(radius - 0.55, radius, Vector3(0, 0.065, 0), Color(0.05, 0.03, 0.02, 0.34), Vector3.ZERO)
	k.disc(radius, Vector3(0, 0.062, 0), Color(0.08, 0.04, 0.02, 0.18), 32)
	for i in 3:
		var r := radius * (1.0 - i * 0.28)
		k.torus(r - 0.28, r, Vector3(0, 0.10 + i * 0.015, 0),
			Color(color.r, color.g, color.b, 0.74 - i * 0.15), Vector3.ZERO)
	for i in 18:
		var a := i * TAU / 18.0
		k.box(Vector3(0.16, 0.05, 0.85), Vector3(cos(a) * radius * 0.74, 0.14, sin(a) * radius * 0.74),
			Color(color.r, color.g, color.b, 0.75), Vector3(0, -rad_to_deg(a), 0))
		k.box(Vector3(0.10, 0.10, 0.10), Vector3(cos(a) * radius * 0.95, 0.5, sin(a) * radius * 0.95),
			Color(color.r, color.g, color.b, 0.85), Vector3(0, 0, 45))
	k.disc(radius * 0.62, Vector3(0, 0.08, 0), Color(color.r * 0.8, color.g * 0.55, color.b * 0.30, 0.12), 24)
	# low golden pillar, alpha kept low so unit silhouettes stay readable
	k.cyl(0.42, 0.62, 5.2, Vector3(0, 2.6, 0), Color(color.r, color.g, color.b, 0.10), 8)
	root.add_child(_kit_instance(k, "alpha", "HeroSkill"))
	return root
