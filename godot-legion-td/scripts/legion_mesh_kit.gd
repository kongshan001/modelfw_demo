class_name LegionMeshKit
extends RefCounted

# Surface-merge helper for the Legionfall art pass (T-20261127-020).
# Accumulates low-poly primitives into ONE ArrayMesh with per-vertex colors, so a
# whole unit body / tower / prop cluster renders as a single draw call with one
# vertex-color toon material. Original geometry only; no external assets.

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()

var _box_cache: Dictionary = {}
var _cyl_cache: Dictionary = {}
var _sphere_cache: Dictionary = {}
var _torus_cache: Dictionary = {}
var _cone_cache: Dictionary = {}


func is_empty() -> bool:
	return _verts.is_empty()


func vert_count() -> int:
	return _verts.size()


static func _cached(cache: Dictionary, key: String, maker: Callable) -> Mesh:
	if cache.has(key):
		return cache[key]
	var m: Mesh = maker.call()
	cache[key] = m
	return m


func add_mesh(mesh: Mesh, xf: Transform3D, color: Color) -> void:
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var arrays := mesh.surface_get_arrays(0)
	var mv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var mn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var mi = arrays[Mesh.ARRAY_INDEX]
	var base := _verts.size()
	_verts.resize(base + mv.size())
	_norms.resize(base + mv.size())
	_cols.resize(base + mv.size())
	for i in mv.size():
		_verts[base + i] = xf * mv[i]
		_norms[base + i] = (xf.basis * mn[i]).normalized()
		_cols[base + i] = color
	if mi != null and mi.size() > 0:
		for j in mi.size():
			_idx.append(base + int(mi[j]))
	else:
		for j in mv.size():
			_idx.append(base + j)


func box(size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var m := _cached(_box_cache, str(size), func() -> BoxMesh:
		var b := BoxMesh.new()
		b.size = size
		return b)
	var b := Basis.from_euler(rot_deg * (PI / 180.0))
	add_mesh(m, Transform3D(b, pos), color)


func box_b(size: Vector3, pos: Vector3, color: Color, basis: Basis) -> void:
	var m := _cached(_box_cache, str(size), func() -> BoxMesh:
		var b := BoxMesh.new()
		b.size = size
		return b)
	add_mesh(m, Transform3D(basis, pos), color)


func cyl(top: float, bottom: float, height: float, pos: Vector3, color: Color,
		sides: int = 6, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var key := "%f:%f:%f:%d" % [top, bottom, height, sides]
	var m := _cached(_cyl_cache, key, func() -> CylinderMesh:
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = height
		c.radial_segments = sides
		c.rings = 1
		return c)
	var b := Basis.from_euler(rot_deg * (PI / 180.0))
	add_mesh(m, Transform3D(b, pos), color)


func cone(radius: float, height: float, pos: Vector3, color: Color,
		sides: int = 5, rot_deg: Vector3 = Vector3.ZERO) -> void:
	cyl(0.0, radius, height, pos, color, sides, rot_deg)


func sphere(radius: float, pos: Vector3, color: Color, scale: Vector3 = Vector3.ONE,
		seg: int = 8, rings: int = 4) -> void:
	var key := "%f:%d:%d" % [radius, seg, rings]
	var m := _cached(_sphere_cache, key, func() -> SphereMesh:
		var s := SphereMesh.new()
		s.radius = radius
		s.height = radius * 2.0
		s.radial_segments = seg
		s.rings = rings
		return s)
	add_mesh(m, Transform3D(Basis().scaled(scale), pos), color)


func torus(inner: float, outer: float, pos: Vector3, color: Color,
		rot_deg: Vector3 = Vector3.ZERO) -> void:
	var key := "%f:%f" % [inner, outer]
	var m := _cached(_torus_cache, key, func() -> TorusMesh:
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 20
		t.ring_segments = 3
		return t)
	var b := Basis.from_euler(rot_deg * (PI / 180.0))
	add_mesh(m, Transform3D(b, pos), color)


func disc(radius: float, pos: Vector3, color: Color, sides: int = 16) -> void:
	cyl(radius, radius, 0.012, pos, color, sides)


func commit(material: Material) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _norms
	arrays[Mesh.ARRAY_COLOR] = _cols
	arrays[Mesh.ARRAY_INDEX] = _idx
	var mesh := ArrayMesh.new()
	if _verts.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material != null:
		mesh.surface_set_material(0, material)
	return mesh
