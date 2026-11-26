class_name MeshKit
extends RefCounted
## Procedural low-poly geometry helpers. Everything is baked into one surface
## with vertex colors so a whole character/map prop costs a single draw call.
## Materials using this geometry must enable vertex_color_use_as_albedo.

static func new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func finish(st: SurfaceTool) -> ArrayMesh:
	return st.commit()


static func _v(st: SurfaceTool, p: Vector3, n: Vector3, color: Color) -> void:
	st.set_color(lift(color))
	st.set_normal(n.normalized())
	st.add_vertex(p)


## HTML palette colors are authored as sRGB display values; vertex colors are
## consumed far darker by the PBR pipeline. A gamma lift restores a mid-tone.
static func lift(color: Color) -> Color:
	var r := pow(color.r, 0.48)
	var g := pow(color.g, 0.48)
	var b := pow(color.b, 0.48)
	var lum := r * 0.2126 + g * 0.7152 + b * 0.0722
	var sat := 1.22
	return Color(clampf(lum + (r - lum) * sat, 0.0, 1.0),
		clampf(lum + (g - lum) * sat, 0.0, 1.0),
		clampf(lum + (b - lum) * sat, 0.0, 1.0), color.a)


static func add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n := (b - a).cross(c - a)
	_v(st, a, n, color)
	_v(st, b, n, color)
	_v(st, c, n, color)


static func add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, n: Vector3) -> void:
	_v(st, a, n, color)
	_v(st, b, n, color)
	_v(st, c, n, color)
	_v(st, a, n, color)
	_v(st, c, n, color)
	_v(st, d, n, color)


static func xf(pos: Vector3, rot_y: float = 0.0, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y).scaled(scl), pos)


static func basis_euler(rx: float, ry: float, rz: float) -> Basis:
	return Basis.from_euler(Vector3(rx, ry, rz))


static func add_box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, rot_y: float = 0.0) -> void:
	add_box_xf(st, Transform3D(Basis(Vector3.UP, rot_y), center), size, color)


static func add_box_xf(st: SurfaceTool, t: Transform3D, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var corners: Array[Vector3] = [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	for i in corners.size():
		corners[i] = t * corners[i]
	var b := t.basis
	add_quad(st, corners[1], corners[2], corners[6], corners[5], color, b * Vector3(1, 0, 0))
	add_quad(st, corners[4], corners[7], corners[3], corners[0], color, b * Vector3(-1, 0, 0))
	add_quad(st, corners[3], corners[2], corners[6], corners[7], color, b * Vector3(0, 1, 0))
	add_quad(st, corners[0], corners[4], corners[5], corners[1], color, b * Vector3(0, -1, 0))
	add_quad(st, corners[5], corners[6], corners[2], corners[1], color, b * Vector3(0, 0, 1))
	add_quad(st, corners[0], corners[3], corners[7], corners[4], color, b * Vector3(0, 0, -1))


static func add_cyl(st: SurfaceTool, base: Vector3, r_bottom: float, r_top: float, height: float,
		segments: int, color: Color, rot_y: float = 0.0, caps: bool = true) -> void:
	add_cyl_xf(st, Transform3D(Basis(Vector3.UP, rot_y), base), r_bottom, r_top, height, segments, color, caps)


static func add_cyl_xf(st: SurfaceTool, t: Transform3D, r_bottom: float, r_top: float, height: float,
		segments: int, color: Color, caps: bool = true) -> void:
	var b := t.basis
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var p0 := t * (d0 * r_bottom)
		var p1 := t * (d1 * r_bottom)
		var p2 := t * (d1 * r_top + Vector3(0, height, 0))
		var p3 := t * (d0 * r_top + Vector3(0, height, 0))
		var n0 := (b * Vector3(d0.x, 0.0, d0.z)).normalized()
		var n1 := (b * Vector3(d1.x, 0.0, d1.z)).normalized()
		_v(st, p0, n0, color)
		_v(st, p1, n1, color)
		_v(st, p2, n1, color)
		_v(st, p0, n0, color)
		_v(st, p2, n1, color)
		_v(st, p3, n0, color)
	if caps:
		var up := (b * Vector3.UP).normalized()
		var down := -up
		var center_top := t * Vector3(0, height, 0)
		var center_bottom := t * Vector3.ZERO
		for i in segments:
			var a0 := TAU * float(i) / float(segments)
			var a1 := TAU * float(i + 1) / float(segments)
			var p0 := t * (Vector3(cos(a0), 0, sin(a0)) * r_top + Vector3(0, height, 0))
			var p1 := t * (Vector3(cos(a1), 0, sin(a1)) * r_top + Vector3(0, height, 0))
			_v(st, center_top, up, color)
			_v(st, p0, up, color)
			_v(st, p1, up, color)
			var q0 := t * (Vector3(cos(a0), 0, sin(a0)) * r_bottom)
			var q1 := t * (Vector3(cos(a1), 0, sin(a1)) * r_bottom)
			_v(st, center_bottom, down, color)
			_v(st, q1, down, color)
			_v(st, q0, down, color)


static func add_sphere(st: SurfaceTool, center: Vector3, radius: float, color: Color,
		segments: int = 8, rings: int = 5, squash: Vector3 = Vector3.ONE) -> void:
	for ry in rings:
		var v0 := PI * float(ry) / float(rings) - PI * 0.5
		var v1 := PI * float(ry + 1) / float(rings) - PI * 0.5
		for sx in segments:
			var u0 := TAU * float(sx) / float(segments)
			var u1 := TAU * float(sx + 1) / float(segments)
			var p00 := Vector3(cos(v0) * cos(u0), sin(v0), cos(v0) * sin(u0))
			var p01 := Vector3(cos(v0) * cos(u1), sin(v0), cos(v0) * sin(u1))
			var p10 := Vector3(cos(v1) * cos(u0), sin(v1), cos(v1) * sin(u0))
			var p11 := Vector3(cos(v1) * cos(u1), sin(v1), cos(v1) * sin(u1))
			_v(st, center + p00 * radius * squash, p00, color)
			_v(st, center + p10 * radius * squash, p10, color)
			_v(st, center + p11 * radius * squash, p11, color)
			_v(st, center + p00 * radius * squash, p00, color)
			_v(st, center + p11 * radius * squash, p11, color)
			_v(st, center + p01 * radius * squash, p01, color)


static func add_octa(st: SurfaceTool, center: Vector3, radius: Vector3, color: Color, rot_y: float = 0.0) -> void:
	var pts: Array[Vector3] = [
		Vector3(0, radius.y, 0), Vector3(radius.x, 0, 0), Vector3(0, 0, radius.z),
		Vector3(-radius.x, 0, 0), Vector3(0, 0, -radius.z), Vector3(0, -radius.y, 0),
	]
	var b := Basis(Vector3.UP, rot_y)
	for i in pts.size():
		pts[i] = center + b * pts[i]
	add_tri(st, pts[0], pts[1], pts[2], color)
	add_tri(st, pts[0], pts[2], pts[3], color)
	add_tri(st, pts[0], pts[3], pts[4], color)
	add_tri(st, pts[0], pts[4], pts[1], color)
	add_tri(st, pts[5], pts[2], pts[1], color)
	add_tri(st, pts[5], pts[3], pts[2], color)
	add_tri(st, pts[5], pts[4], pts[3], color)
	add_tri(st, pts[5], pts[1], pts[4], color)


static func add_disc(st: SurfaceTool, center: Vector3, radius: float, segments: int, color: Color) -> void:
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := center + Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := center + Vector3(cos(a1), 0, sin(a1)) * radius
		_v(st, center, Vector3.UP, color)
		_v(st, p0, Vector3.UP, color)
		_v(st, p1, Vector3.UP, color)


static func add_ring(st: SurfaceTool, center: Vector3, inner: float, outer: float,
		segments: int, color: Color) -> void:
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		add_quad(st, center + d0 * inner, center + d1 * inner, center + d1 * outer, center + d0 * outer,
			color, Vector3.UP)


static func add_chevron(st: SurfaceTool, center: Vector3, size: float, color: Color, rot_y: float = 0.0) -> void:
	var b := Basis(Vector3.UP, rot_y)
	var pts := [
		center + b * Vector3(0, 0, size * 0.55),
		center + b * Vector3(-size * 0.5, 0, -size * 0.35),
		center + b * Vector3(0, 0, -size * 0.02),
		center + b * Vector3(size * 0.5, 0, -size * 0.35),
	]
	add_tri(st, pts[0], pts[1], pts[2], color)
	add_tri(st, pts[0], pts[2], pts[3], color)


static func make_material_instance(mesh: ArrayMesh, material: Material, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
