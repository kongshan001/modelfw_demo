class_name MistModels
extends RefCounted
## 全部模型均为运行时程序化低模：顶点色 + 单材质合并，控制 draw call。
## 无外部模型/贴图；造型、配色、阵营符号均为本项目原创。

const Balance = preload("res://scripts/balance.gd")
const UI = preload("res://scripts/ui_style.gd")

static var _unit_material: StandardMaterial3D
static var _flat_material: StandardMaterial3D
static var _ring_materials: Dictionary = {}
static var _mesh_cache: Dictionary = {}
static var _prim_cache: Dictionary = {}
static var _soft_texture: ImageTexture


# ---------------------------------------------------------------- materials

static func soft_particle_texture() -> ImageTexture:
	if _soft_texture == null:
		var size := 32
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in range(size):
			for x in range(size):
				var dx := (float(x) + 0.5 - float(size) * 0.5) / (float(size) * 0.5)
				var dy := (float(y) + 0.5 - float(size) * 0.5) / (float(size) * 0.5)
				var d := sqrt(dx * dx + dy * dy)
				var a := clampf(1.0 - d, 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_soft_texture = ImageTexture.create_from_image(img)
	return _soft_texture


static func unit_material() -> StandardMaterial3D:
	if _unit_material == null:
		_unit_material = StandardMaterial3D.new()
		_unit_material.vertex_color_use_as_albedo = true
		_unit_material.roughness = 0.82
		_unit_material.metallic = 0.0
		_unit_material.metallic_specular = 0.18
		_unit_material.cull_mode = BaseMaterial3D.CULL_BACK
	return _unit_material


static func flat_material() -> StandardMaterial3D:
	if _flat_material == null:
		_flat_material = StandardMaterial3D.new()
		_flat_material.vertex_color_use_as_albedo = true
		_flat_material.roughness = 0.96
		_flat_material.metallic = 0.0
		_flat_material.metallic_specular = 0.06
	return _flat_material


static func ring_material(color: Color, alpha := 0.95) -> StandardMaterial3D:
	var key := color.to_html() + ":" + str(alpha)
	if _ring_materials.has(key):
		return _ring_materials[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	_ring_materials[key] = material
	return material


static func glow_material(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func make_disc(radius: float, color: Color, alpha := 0.25) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 12
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func bar_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 2
	return material


# ---------------------------------------------------------------- primitive merge

static func _xform(pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	var b := Basis.IDENTITY
	b = b.rotated(Vector3.RIGHT, deg_to_rad(rot_deg.x))
	b = b.rotated(Vector3.UP, deg_to_rad(rot_deg.y))
	b = b.rotated(Vector3.BACK, deg_to_rad(rot_deg.z))
	b = b.scaled(scl)
	return Transform3D(b, pos)


static func _append_prim(st: SurfaceTool, mesh: Mesh, xform: Transform3D, color: Color) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var raw_normals = arrays[Mesh.ARRAY_NORMAL]
	var normals: PackedVector3Array = raw_normals if raw_normals != null else PackedVector3Array()
	var raw_indices = arrays[Mesh.ARRAY_INDEX]
	var indices: PackedInt32Array = raw_indices if raw_indices != null else PackedInt32Array()
	var basis := xform.basis
	if indices.size() > 0:
		for idx in indices:
			var v: Vector3 = xform * verts[idx]
			var n: Vector3 = (basis * normals[idx]).normalized() if idx < normals.size() else Vector3.UP
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(v)
	else:
		for i in range(verts.size()):
			var v: Vector3 = xform * verts[i]
			var n: Vector3 = (basis * normals[i]).normalized() if i < normals.size() else Vector3.UP
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(v)


static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "box:" + str(size)
	if not _prim_cache.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_prim_cache[key] = mesh
	return _prim_cache[key] as BoxMesh


static func _cyl_mesh(radius: float, height: float, segments := 7) -> CylinderMesh:
	var key := "cyl:" + str(radius) + ":" + str(height) + ":" + str(segments)
	if not _prim_cache.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = segments
		mesh.rings = 1
		_prim_cache[key] = mesh
	return _prim_cache[key] as CylinderMesh


static func _cone_mesh(radius: float, height: float, segments := 7) -> CylinderMesh:
	var key := "cone:" + str(radius) + ":" + str(height) + ":" + str(segments)
	if not _prim_cache.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = segments
		mesh.rings = 1
		_prim_cache[key] = mesh
	return _prim_cache[key] as CylinderMesh


static func _sphere_mesh(radius: float, segments := 6, rings := 4) -> SphereMesh:
	var key := "sph:" + str(radius) + ":" + str(segments) + ":" + str(rings)
	if not _prim_cache.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = segments
		mesh.rings = rings
		_prim_cache[key] = mesh
	return _prim_cache[key] as SphereMesh


static func _add_box(st: SurfaceTool, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> void:
	_append_prim(st, _box_mesh(size), _xform(pos, rot), color)


static func _add_cyl(st: SurfaceTool, radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, segments := 7) -> void:
	_append_prim(st, _cyl_mesh(radius, height, segments), _xform(pos, rot), color)


static func _add_cone(st: SurfaceTool, radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, segments := 7) -> void:
	_append_prim(st, _cone_mesh(radius, height, segments), _xform(pos, rot), color)


static func _add_sphere(st: SurfaceTool, radius: float, pos: Vector3, color: Color, segments := 6, rings := 4) -> void:
	_append_prim(st, _sphere_mesh(radius, segments, rings), _xform(pos), color)


static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for v in [a, b, c]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(v)


static func _add_limb(st: SurfaceTool, from: Vector3, to: Vector3, radius: float, color: Color, segments := 6) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return
	var mid := (from + to) * 0.5
	var basis := Basis(Quaternion(Vector3.UP, delta.normalized()))
	_append_prim(st, _cyl_mesh(radius, length, segments), Transform3D(basis, mid), color)


static func _add_tip(st: SurfaceTool, from: Vector3, to: Vector3, radius: float, color: Color, segments := 6) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return
	var mid := (from + to) * 0.5
	var basis := Basis(Quaternion(Vector3.UP, delta.normalized()))
	_append_prim(st, _cone_mesh(radius, length, segments), Transform3D(basis, mid), color)


static func _vary(color: Color, variant: int) -> Color:
	var amount := (float(variant) - 1.0) * 0.035
	return color.lightened(amount) if amount >= 0.0 else color.darkened(-amount)


# ---------------------------------------------------------------- units

static func soldier_mesh(class_id: String, variant := 0) -> ArrayMesh:
	var key := "soldier:" + class_id + ":" + str(variant)
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var data := Balance.player_class(class_id)
	var coat := _vary(Color("3f6d8c") if class_id == "shield" else (Color("4b7a68") if class_id == "archer" else Color("5d6f93")), variant)
	var accent := Color(data["accent"])
	var skin := Color("d9b28c")
	var steel := Color("b9c4c5")
	var leather := Color("5a4433")
	var dark := Color("233437")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# legs + boots
	_add_box(st, Vector3(0.17, 0.48, 0.20), Vector3(-0.15, 0.25, 0.0), dark)
	_add_box(st, Vector3(0.17, 0.48, 0.20), Vector3(0.15, 0.25, 0.0), dark)
	_add_box(st, Vector3(0.20, 0.13, 0.27), Vector3(-0.15, 0.07, -0.03), leather)
	_add_box(st, Vector3(0.20, 0.13, 0.27), Vector3(0.15, 0.07, -0.03), leather)

	# torso, belt, cloak
	_add_box(st, Vector3(0.50, 0.56, 0.30), Vector3(0, 0.79, 0), coat)
	_add_box(st, Vector3(0.54, 0.08, 0.32), Vector3(0, 0.55, 0), leather)
	_add_box(st, Vector3(0.46, 0.62, 0.07), Vector3(0, 0.76, 0.20), coat.darkened(0.18), Vector3(4, 0, 0))
	_add_box(st, Vector3(0.60, 0.10, 0.34), Vector3(0, 1.07, 0), accent)
	_add_box(st, Vector3(0.10, 0.10, 0.36), Vector3(0, 0.98, 0), accent.darkened(0.15))

	# head / neck / helmet
	_add_cyl(st, 0.08, 0.09, Vector3(0, 1.15, 0), skin)
	_add_sphere(st, 0.155, Vector3(0, 1.30, 0), skin)
	match class_id:
		"shield":
			_add_cyl(st, 0.185, 0.20, Vector3(0, 1.36, 0), steel, Vector3.ZERO, 7)
			_add_box(st, Vector3(0.06, 0.16, 0.20), Vector3(0, 1.32, -0.16), steel)
			_add_cone(st, 0.12, 0.20, Vector3(0, 1.55, 0.02), accent, Vector3.ZERO, 6)
		"archer":
			_add_cyl(st, 0.19, 0.14, Vector3(0, 1.38, 0), coat.darkened(0.18), Vector3.ZERO, 7)
			_add_cone(st, 0.22, 0.30, Vector3(0, 1.50, 0.02), coat.darkened(0.05), Vector3.ZERO, 6)
			_add_box(st, Vector3(0.28, 0.06, 0.09), Vector3(0, 1.30, -0.13), accent.darkened(0.2))
		"spear":
			_add_cyl(st, 0.18, 0.16, Vector3(0, 1.37, 0), leather, Vector3.ZERO, 7)
			_add_box(st, Vector3(0.07, 0.20, 0.18), Vector3(0, 1.33, -0.14), steel)
			_add_box(st, Vector3(0.05, 0.24, 0.05), Vector3(0, 1.53, 0.01), accent)

	# arms
	_add_limb(st, Vector3(-0.30, 1.03, 0), Vector3(-0.37, 0.80, -0.10), 0.075, coat)
	_add_limb(st, Vector3(0.30, 1.03, 0), Vector3(0.38, 0.82, -0.09), 0.075, coat)
	_add_sphere(st, 0.075, Vector3(-0.38, 0.79, -0.11), skin, 5, 3)
	_add_sphere(st, 0.075, Vector3(0.39, 0.81, -0.10), skin, 5, 3)

	# class equipment
	match class_id:
		"shield":
			_add_cyl(st, 0.31, 0.07, Vector3(-0.42, 0.84, -0.27), accent, Vector3(90, 0, 0), 10)
			_add_cyl(st, 0.11, 0.03, Vector3(-0.42, 0.84, -0.32), Color("f0d49a"), Vector3(90, 0, 0), 8)
			_add_box(st, Vector3(0.34, 0.045, 0.035), Vector3(-0.42, 0.84, -0.35), Color("6e4a2e"))
			_add_box(st, Vector3(0.045, 0.34, 0.035), Vector3(-0.42, 0.84, -0.35), Color("6e4a2e"))
			_add_box(st, Vector3(0.055, 0.55, 0.09), Vector3(0.43, 0.85, -0.12), steel, Vector3(0, 0, -16))
			_add_box(st, Vector3(0.20, 0.055, 0.20), Vector3(0.43, 0.61, -0.06), accent.darkened(0.3))
		"archer":
			# 三段弓身 + 弦
			_add_limb(st, Vector3(-0.44, 1.08, -0.12), Vector3(-0.53, 0.86, -0.18), 0.026, Color("a97a4f"))
			_add_limb(st, Vector3(-0.53, 0.86, -0.18), Vector3(-0.47, 0.62, -0.12), 0.026, Color("a97a4f"))
			_add_limb(st, Vector3(-0.44, 1.08, -0.12), Vector3(-0.47, 0.62, -0.12), 0.009, Color("e8dfc8"))
			_add_box(st, Vector3(0.22, 0.30, 0.12), Vector3(0.24, 0.94, 0.22), leather, Vector3(0, 0, -12))
			_add_cyl(st, 0.018, 0.48, Vector3(0.34, 0.98, 0.23), Color("d9cbb0"), Vector3(12, 0, -22))
			_add_cyl(st, 0.018, 0.48, Vector3(0.28, 0.96, 0.20), Color("d9cbb0"), Vector3(12, 0, -22))
		"spear":
			var shaft_from := Vector3(0.40, 0.30, 0.10)
			var shaft_to := Vector3(0.26, 2.55, -0.72)
			_add_limb(st, shaft_from, shaft_to, 0.026, Color("a98254"), 6)
			_add_tip(st, shaft_to, shaft_to + Vector3(-0.035, 0.32, -0.10), 0.075, steel, 5)
			_add_box(st, Vector3(0.10, 0.08, 0.10), Vector3(0.27, 2.50, -0.70), accent)
			_add_cyl(st, 0.16, 0.05, Vector3(0.40, 0.84, -0.08), accent.darkened(0.1), Vector3(90, 0, 0), 8)

	if variant >= 2:
		_add_box(st, Vector3(0.12, 0.16, 0.04), Vector3(0.16, 0.92, -0.17), accent.lightened(0.15))

	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func enemy_mesh(type_id: String, variant := 0) -> ArrayMesh:
	var key := "enemy:" + type_id + ":" + str(variant)
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var data := Balance.enemy_type(type_id)
	var coat := _vary(Color(data["color"]), variant)
	var iron := Color("777d7e")
	var leather := Color("4b382c")
	var skin := Color("c79a76")
	var cloth := Color("323638")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_box(st, Vector3(0.18, 0.50, 0.21), Vector3(-0.16, 0.26, 0), cloth)
	_add_box(st, Vector3(0.18, 0.50, 0.21), Vector3(0.16, 0.26, 0), cloth)
	_add_box(st, Vector3(0.22, 0.13, 0.29), Vector3(-0.16, 0.07, -0.03), leather)
	_add_box(st, Vector3(0.22, 0.13, 0.29), Vector3(0.16, 0.07, -0.03), leather)
	_add_box(st, Vector3(0.54, 0.58, 0.32), Vector3(0, 0.80, 0), coat)
	_add_box(st, Vector3(0.60, 0.14, 0.36), Vector3(0, 1.06, 0), Color("6b6255"))
	_add_box(st, Vector3(0.50, 0.62, 0.08), Vector3(0, 0.76, 0.21), coat.darkened(0.22), Vector3(4, 0, 0))
	_add_cyl(st, 0.08, 0.09, Vector3(0, 1.15, 0), skin)
	_add_sphere(st, 0.155, Vector3(0, 1.30, 0), skin)
	_add_cyl(st, 0.19, 0.17, Vector3(0, 1.37, 0), iron, Vector3.ZERO, 6)
	_add_box(st, Vector3(0.06, 0.16, 0.20), Vector3(0, 1.32, -0.16), iron)
	_add_limb(st, Vector3(-0.31, 1.03, 0), Vector3(-0.39, 0.80, -0.11), 0.08, coat)
	_add_limb(st, Vector3(0.31, 1.03, 0), Vector3(0.39, 0.82, -0.10), 0.08, coat)
	_add_sphere(st, 0.075, Vector3(-0.40, 0.79, -0.12), skin, 5, 3)
	_add_sphere(st, 0.075, Vector3(0.40, 0.81, -0.11), skin, 5, 3)

	match type_id:
		"raider":
			_add_cyl(st, 0.28, 0.06, Vector3(-0.43, 0.84, -0.26), Color("8a4f3c"), Vector3(90, 0, 0), 9)
			_add_cyl(st, 0.09, 0.025, Vector3(-0.43, 0.84, -0.30), Color("d4b98c"))
			_add_box(st, Vector3(0.05, 0.55, 0.08), Vector3(0.43, 0.85, -0.10), Color("6a4a34"), Vector3(0, 0, -12))
			_add_box(st, Vector3(0.26, 0.16, 0.05), Vector3(0.48, 1.11, -0.12), iron, Vector3(0, 0, -28))
		"brute":
			_add_box(st, Vector3(0.48, 0.62, 0.08), Vector3(-0.42, 0.86, -0.28), Color("7b4a37"), Vector3(0, 0, 6))
			_add_box(st, Vector3(0.52, 0.08, 0.10), Vector3(-0.42, 1.10, -0.28), Color("40332c"))
			_add_box(st, Vector3(0.52, 0.08, 0.10), Vector3(-0.42, 0.62, -0.28), Color("40332c"))
			_add_cyl(st, 0.10, 0.035, Vector3(-0.42, 0.86, -0.34), Color("c5a46b"))
			_add_box(st, Vector3(0.06, 0.68, 0.10), Vector3(0.45, 0.92, -0.10), Color("6a4a34"), Vector3(0, 0, -8))
			_add_box(st, Vector3(0.30, 0.20, 0.06), Vector3(0.56, 1.22, -0.13), iron, Vector3(0, 0, -30))
			_add_cone(st, 0.15, 0.18, Vector3(0, 1.55, 0), Color("5a4438"), Vector3.ZERO, 6)
		"skirmisher":
			_add_cone(st, 0.21, 0.27, Vector3(0, 1.49, 0.02), Color("5c4b3b"), Vector3.ZERO, 6)
			_add_box(st, Vector3(0.05, 0.46, 0.07), Vector3(0.43, 0.87, -0.10), Color("6a4a34"), Vector3(0, 0, -16))
			_add_box(st, Vector3(0.24, 0.13, 0.05), Vector3(0.48, 1.10, -0.12), Color("8d8f8a"), Vector3(0, 0, -24))
			_add_box(st, Vector3(0.22, 0.28, 0.11), Vector3(0.24, 0.95, 0.22), leather, Vector3(0, 0, -12))
			_add_cyl(st, 0.018, 0.44, Vector3(0.32, 0.97, 0.22), Color("c8b898"), Vector3(10, 0, -20))
		"chieftain":
			_add_box(st, Vector3(0.58, 0.70, 0.10), Vector3(-0.45, 0.90, -0.28), Color("863e30"), Vector3(0, 0, 4))
			_add_cyl(st, 0.11, 0.04, Vector3(-0.45, 0.90, -0.35), Color("e0bd74"))
			_add_box(st, Vector3(0.07, 0.78, 0.11), Vector3(0.48, 0.98, -0.10), Color("5b3d2c"), Vector3(0, 0, -6))
			_add_box(st, Vector3(0.38, 0.24, 0.07), Vector3(0.62, 1.36, -0.13), iron, Vector3(0, 0, -28))
			_add_box(st, Vector3(0.05, 1.80, 0.05), Vector3(0.30, 1.55, 0.28), Color("6b4f37"))
			_add_box(st, Vector3(0.46, 0.34, 0.02), Vector3(0.51, 2.30, 0.28), Color("a23f34"))
			_add_box(st, Vector3(0.10, 0.16, 0.10), Vector3(0, 1.58, 0), Color("a23f34"))
			_add_cone(st, 0.09, 0.26, Vector3(0, 1.68, 0), Color("e0bd74"), Vector3.ZERO, 5)

	if variant == 2:
		_add_box(st, Vector3(0.12, 0.16, 0.04), Vector3(0.16, 0.93, -0.18), Color("c5a46b"))

	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func arrow_mesh(kind := "arrow") -> ArrayMesh:
	var key := "projectile:" + kind
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == "axe":
		_add_cyl(st, 0.025, 0.52, Vector3(0, 0, 0), Color("6a4a34"), Vector3(90, 0, 0), 5)
		_add_box(st, Vector3(0.24, 0.16, 0.04), Vector3(0, 0.04, -0.22), Color("8d8f8a"))
	else:
		_add_limb(st, Vector3(0, 0, 0.36), Vector3(0, 0, -0.34), 0.018, Color("c8b898"), 5)
		_add_tip(st, Vector3(0, 0, -0.32), Vector3(0, 0, -0.50), 0.055, Color("b9c4c5"), 5)
		_add_box(st, Vector3(0.10, 0.02, 0.12), Vector3(0, 0, 0.30), Color("d8cbb0"), Vector3(0, 0, 12))
		_add_box(st, Vector3(0.10, 0.02, 0.12), Vector3(0, 0, 0.30), Color("a84f3f"), Vector3(0, 0, -12))
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


# ---------------------------------------------------------------- structures

static func house_mesh(variant := 0) -> ArrayMesh:
	var key := "house:" + str(variant)
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var wall := Color("e6d9bd").darkened(float(variant) * 0.025)
	var wood := Color("5b4332")
	var roof := Color("b85c43") if variant != 1 else Color("a65442")
	var stone := Color("8d8b80")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 4.2 + float(variant) * 0.25
	var d := 3.4
	var h := 2.25
	_add_box(st, Vector3(w + 0.3, 0.35, d + 0.3), Vector3(0, 0.18, 0), stone)
	_add_box(st, Vector3(w, h, d), Vector3(0, 0.35 + h * 0.5, 0), wall)
	# timber frame
	for x in [-w * 0.5 + 0.12, w * 0.5 - 0.12]:
		_add_box(st, Vector3(0.16, h, 0.16), Vector3(x, 0.35 + h * 0.5, -d * 0.5 - 0.02), wood)
		_add_box(st, Vector3(0.16, h, 0.16), Vector3(x, 0.35 + h * 0.5, d * 0.5 + 0.02), wood)
	_add_box(st, Vector3(w, 0.16, 0.16), Vector3(0, 0.42 + h * 0.5, -d * 0.5 - 0.03), wood)
	_add_box(st, Vector3(w, 0.16, 0.16), Vector3(0, 0.42 + h * 0.5, d * 0.5 + 0.03), wood)
	# door
	_add_box(st, Vector3(0.72, 1.35, 0.10), Vector3(0, 1.02, -d * 0.5 - 0.06), wood.darkened(0.12))
	_add_box(st, Vector3(0.82, 1.45, 0.06), Vector3(0, 1.02, -d * 0.5 - 0.02), wood.lightened(0.18))
	_add_sphere(st, 0.045, Vector3(0.25, 1.02, -d * 0.5 - 0.10), Color("d8b25f"), 4, 2)
	# 窗户与木框（窗面由独立自发光网格覆盖）
	for wx in [-1.05, 1.05]:
		_add_box(st, Vector3(0.62, 0.08, 0.08), Vector3(wx, 1.77, -d * 0.5 - 0.03), wood)
		_add_box(st, Vector3(0.62, 0.08, 0.08), Vector3(wx, 1.34, -d * 0.5 - 0.03), wood)
		_add_box(st, Vector3(0.08, 0.52, 0.08), Vector3(wx - 0.28, 1.55, -d * 0.5 - 0.03), wood)
		_add_box(st, Vector3(0.08, 0.52, 0.08), Vector3(wx + 0.28, 1.55, -d * 0.5 - 0.03), wood)
		_add_box(st, Vector3(0.56, 0.045, 0.05), Vector3(wx, 1.55, -d * 0.5 - 0.06), wood.darkened(0.2))
	# roof slabs
	var roof_y := 0.35 + h + 0.72
	_add_box(st, Vector3(w + 0.7, 0.20, 2.15), Vector3(0, roof_y, -0.94), roof, Vector3(-33, 0, 0))
	_add_box(st, Vector3(w + 0.7, 0.20, 2.15), Vector3(0, roof_y, 0.94), roof, Vector3(33, 0, 0))
	_add_box(st, Vector3(w + 0.8, 0.22, 0.22), Vector3(0, roof_y + 0.62, 0), roof.darkened(0.22))
	# 封闭山墙（双面，避免空洞）
	var eave_y := 0.35 + h - 0.05
	var ridge_y := roof_y + 0.68
	for end_x in [-w * 0.5, w * 0.5]:
		var ga := Vector3(end_x, eave_y, -d * 0.5)
		var gb := Vector3(end_x, eave_y, d * 0.5)
		var gc := Vector3(end_x, ridge_y, 0.0)
		var gable_col := wall.darkened(0.04)
		_add_tri(st, ga, gb, gc, gable_col)
		_add_tri(st, ga, gc, gb, gable_col)
		_add_box(st, Vector3(0.10, 0.12, d + 0.1), Vector3(end_x, eave_y, 0), wood)
	# chimney
	_add_box(st, Vector3(0.52, 1.05, 0.52), Vector3(w * 0.28, roof_y + 0.45, 0.52), stone)
	_add_box(st, Vector3(0.62, 0.14, 0.62), Vector3(w * 0.28, roof_y + 1.0, 0.52), stone.darkened(0.12))
	# porch & side lean-to
	_add_box(st, Vector3(w + 0.5, 0.12, 0.8), Vector3(0, 0.22, -d * 0.5 - 0.55), wood)
	_add_box(st, Vector3(0.14, 1.0, 0.14), Vector3(-w * 0.42, 0.62, -d * 0.5 - 0.9), wood)
	_add_box(st, Vector3(0.14, 1.0, 0.14), Vector3(w * 0.42, 0.62, -d * 0.5 - 0.9), wood)
	if variant == 2:
		_add_box(st, Vector3(1.4, 0.7, 0.9), Vector3(-w * 0.38, 0.35, d * 0.35), wood)
		_add_box(st, Vector3(1.5, 0.12, 1.0), Vector3(-w * 0.38, 0.74, d * 0.35), roof.darkened(0.15), Vector3(20, 0, 0))
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func house_window_mesh(variant := 0) -> ArrayMesh:
	var key := "house_window:" + str(variant)
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, Vector3(0.48, 0.42, 0.05), Vector3(-1.05, 1.55, -1.75), Color("f6c66e"))
	_add_box(st, Vector3(0.48, 0.42, 0.05), Vector3(1.05, 1.55, -1.75), Color("f6c66e"))
	_add_box(st, Vector3(0.05, 0.42, 0.46), Vector3(2.13, 1.55, 0.5), Color("f6c66e"))
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func boat_mesh(variant := 0) -> ArrayMesh:
	var key := "boat:" + str(variant)
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var wood := Color("5d4735")
	var dark := Color("3f3128")
	var sail := Color("ded3b8") if variant == 0 else Color("c9bca2")
	var trim := Color("9a4638")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# hull: 3 tapered sections
	_add_box(st, Vector3(1.15, 0.52, 2.2), Vector3(0, 0.38, 0), wood)
	_add_box(st, Vector3(0.72, 0.46, 0.9), Vector3(0, 0.40, -1.45), wood, Vector3(0, 0, 0))
	_add_tip(st, Vector3(0, 0.42, -1.9), Vector3(0, 0.42, -2.55), 0.48, wood, 4)
	_add_tip(st, Vector3(0, 0.42, 1.9), Vector3(0, 0.42, 2.35), 0.42, wood, 4)
	_add_box(st, Vector3(1.22, 0.16, 2.5), Vector3(0, 0.63, 0.05), trim)
	for x in [-0.58, 0.58]:
		_add_box(st, Vector3(0.10, 0.34, 3.6), Vector3(x, 0.60, 0), dark)
	# mast + yard + sail
	_add_cyl(st, 0.07, 3.6, Vector3(0, 2.0, 0.15), dark, Vector3.ZERO, 5)
	_add_cyl(st, 0.05, 2.25, Vector3(0, 3.15, 0.15), dark, Vector3(0, 0, 90), 5)
	_add_box(st, Vector3(2.05, 1.65, 0.05), Vector3(0, 2.55, 0.18), sail)
	_add_box(st, Vector3(2.05, 0.22, 0.06), Vector3(0, 1.80, 0.18), trim)
	_add_box(st, Vector3(0.36, 0.36, 0.06), Vector3(0, 2.55, 0.15), trim)
	# oars
	for i in range(4):
		var z := -0.75 + float(i) * 0.55
		_add_box(st, Vector3(1.9, 0.045, 0.06), Vector3(0.0, 0.52, z), Color("7a5c40"), Vector3(0, 12 if i % 2 == 0 else -12, 0))
	# prow ornament (original wave-crest)
	_add_cone(st, 0.15, 0.55, Vector3(0, 0.95, -2.0), trim, Vector3(-20, 0, 0), 4)
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func ring_mesh(inner := 0.78, outer := 1.0) -> TorusMesh:
	var key := "ring:" + str(inner) + ":" + str(outer)
	if _mesh_cache.has(key):
		return _mesh_cache[key] as TorusMesh
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 6
	_mesh_cache[key] = mesh
	return mesh


static func make_ring(color: Color, inner := 0.78, outer := 1.0, alpha := 0.95) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = ring_mesh(inner, outer)
	var mat := ring_material(color, alpha).duplicate() as StandardMaterial3D
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


# ---------------------------------------------------------------- scenery (merged by island)

static func append_pine(st: SurfaceTool, pos: Vector3, height: float, variant: int) -> void:
	var trunk := Color("5b4431")
	var leaf := Color("3f6b58").lightened(float(variant) * 0.03)
	var leaf_dark := Color("345a4b")
	_add_cyl(st, 0.95, 0.02, pos + Vector3(0, 0.035, 0), Color("4a5d3f"), Vector3.ZERO, 8)
	_add_limb(st, pos, pos + Vector3(0, height * 0.55, 0), 0.11, trunk, 5)
	var base := pos + Vector3(0, height * 0.30, 0)
	_add_cone(st, height * 0.25, height * 0.52, base + Vector3(0, height * 0.22, 0), leaf_dark, Vector3.ZERO, 6)
	_add_cone(st, height * 0.19, height * 0.42, base + Vector3(0, height * 0.50, 0), leaf, Vector3.ZERO, 6)
	_add_cone(st, height * 0.12, height * 0.30, base + Vector3(0, height * 0.74, 0), leaf.lightened(0.05), Vector3.ZERO, 5)


static func append_broadleaf(st: SurfaceTool, pos: Vector3, height: float, variant: int) -> void:
	var trunk := Color("624a35")
	var leaf := Color("517b58").lightened(float(variant) * 0.025)
	_add_cyl(st, 1.05, 0.02, pos + Vector3(0, 0.035, 0), Color("4d6144"), Vector3.ZERO, 8)
	_add_limb(st, pos, pos + Vector3(0, height * 0.62, 0), 0.13, trunk, 5)
	_add_sphere(st, height * 0.28, pos + Vector3(0, height * 0.74, 0), leaf, 6, 4)
	_add_sphere(st, height * 0.18, pos + Vector3(height * 0.16, height * 0.88, 0.04), leaf.lightened(0.06), 5, 3)
	_add_sphere(st, height * 0.15, pos + Vector3(-height * 0.14, height * 0.68, -0.04), leaf.darkened(0.08), 5, 3)


static func append_rock(st: SurfaceTool, pos: Vector3, radius: float, variant: int) -> void:
	var color := Color("85877e") if variant % 2 == 0 else Color("777b73")
	_add_cyl(st, radius * 0.95, 0.02, pos + Vector3(0, 0.03, 0), Color("5f6158"), Vector3.ZERO, 8)
	_add_sphere(st, radius, pos + Vector3(0, radius * 0.28, 0), color, 6, 3)
	_add_sphere(st, radius * 0.55, pos + Vector3(radius * 0.6, radius * 0.15, radius * 0.2), color.darkened(0.06), 5, 3)


static func append_grass(st: SurfaceTool, pos: Vector3, variant: int) -> void:
	var color := Color("8aa86a").lightened(0.02 * float(variant % 3))
	for i in range(3):
		var off := Vector3(-0.12 + float(i) * 0.12, 0.0, 0.03 * float(i - 1))
		_add_box(st, Vector3(0.035, 0.28 + float(i % 2) * 0.08, 0.035), pos + off + Vector3(0, 0.14, 0), color, Vector3(0, float(i) * 23.0, 8 - float(i) * 8))


static func append_fence(st: SurfaceTool, from: Vector3, to: Vector3, posts := 4) -> void:
	var wood := Color("6b5138")
	var dir := to - from
	for i in range(posts + 1):
		var p := from + dir * (float(i) / float(posts))
		_add_box(st, Vector3(0.09, 0.9, 0.09), p + Vector3(0, 0.45, 0), wood)
	_add_limb(st, from + Vector3(0, 0.62, 0), to + Vector3(0, 0.62, 0), 0.035, wood, 4)
	_add_limb(st, from + Vector3(0, 0.30, 0), to + Vector3(0, 0.30, 0), 0.03, wood.darkened(0.08), 4)


static func append_pier(st: SurfaceTool, shore: Vector3, outward: Vector3, length: float) -> void:
	var wood := Color("6b563f")
	var light_wood := Color("8b7050")
	var dark := Color("44372a")
	var side := outward.cross(Vector3.UP).normalized()
	var yaw := rad_to_deg(atan2(outward.x, outward.z))
	var mid := shore + outward * (length * 0.5)
	# 连续甲板 + 横向板缝
	_add_box(st, Vector3(1.55, 0.16, length), mid + Vector3(0, 0.27, 0), wood, Vector3(0, yaw, 0))
	for i in range(10):
		var t := (float(i) + 0.5) / 10.0
		var p := shore + outward * (t * length)
		_add_box(st, Vector3(1.62, 0.05, 0.14), p + Vector3(0, 0.36, 0), light_wood, Vector3(0, yaw, 0))
	# 两侧桩与护栏
	for t in [0.12, 0.42, 0.72, 0.98]:
		var p: Vector3 = shore + outward * (float(t) * length)
		for sx in [-0.70, 0.70]:
			_add_box(st, Vector3(0.16, 1.7, 0.16), p + side * float(sx) + Vector3(0, -0.25, 0), dark)
	_add_box(st, Vector3(0.06, 0.08, length * 0.9), shore + outward * (length * 0.52) + side * 0.72 + Vector3(0, 0.75, 0), dark, Vector3(0, yaw, 0))
	_add_box(st, Vector3(0.06, 0.08, length * 0.9), shore + outward * (length * 0.52) - side * 0.72 + Vector3(0, 0.75, 0), dark, Vector3(0, yaw, 0))
	# 端头系缆桩
	for sx in [-0.65, 0.65]:
		_add_cyl(st, 0.16, 0.5, shore + outward * length + side * sx + Vector3(0, 0.55, 0), dark, Vector3.ZERO, 5)


# ---------------------------------------------------------------- helpers

static func make_quad(size: Vector2, material: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func make_label(text: String, font_size := 42, color := Color.WHITE) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UI.bold_font()
	label.font_size = font_size
	label.pixel_size = 0.0055
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color(0.03, 0.07, 0.075, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 5
	label.shaded = false
	label.double_sided = true
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return label
