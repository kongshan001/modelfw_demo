class_name KnotTube
extends RefCounted

## Catmull-Rom polyline sampling + a hand-built tube mesh.
## The rope is rebuilt from control points whenever the stroke changes; the
## sampled polyline is shared by the visual mesh, winding and crossing tests.

const MAX_RINGS := 1100


static func sample_catmull(points: PackedVector3Array, subdivisions: int = 3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var src := _dedupe(points)
	if src.is_empty():
		return out
	if src.size() == 1:
		out.append(src[0])
		return out
	if src.size() == 2:
		out.append(src[0])
		out.append(src[1])
		return out
	var sub := maxi(1, subdivisions)
	var per_seg := maxi(1, int(ceil(float(MAX_RINGS - 1) / float(src.size() - 1))))
	if sub > per_seg:
		sub = per_seg
	for i in range(src.size() - 1):
		var p1 := src[i]
		var p2 := src[i + 1]
		var p0 := src[i - 1] if i > 0 else p1 + (p1 - p2)
		var p3 := src[i + 2] if i + 2 < src.size() else p2 + (p2 - p1)
		for s in sub:
			var t := float(s) / float(sub)
			out.append(_catmull(p0, p1, p2, p3, t))
	out.append(src[src.size() - 1])
	return out


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	# Uniform Catmull-Rom, tension 0.5. Dense input points keep overshoot small.
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


static func _dedupe(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in points:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(p) > 1e-8:
			out.append(p)
	return out


static func build_tube(samples: PackedVector3Array, radius: float, radial: int = 8) -> ArrayMesh:
	var pts := _dedupe(samples)
	var mesh := ArrayMesh.new()
	if pts.size() < 2:
		return mesh
	var rings := pts.size()
	var seg := maxi(3, radial)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	verts.resize(rings * seg)
	norms.resize(rings * seg)
	uvs.resize(rings * seg)

	var prev_tangent := Vector3.ZERO
	var normal := Vector3.ZERO
	for i in rings:
		var tangent: Vector3
		if i == 0:
			tangent = pts[1] - pts[0]
		elif i == rings - 1:
			tangent = pts[i] - pts[i - 1]
		else:
			tangent = pts[i + 1] - pts[i - 1]
		if tangent.length_squared() < 1e-10:
			tangent = Vector3.FORWARD
		tangent = tangent.normalized()
		if i == 0:
			var hint := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
			normal = tangent.cross(hint).normalized()
		else:
			var q := Quaternion(prev_tangent, tangent)
			normal = (q * normal).normalized()
		normal = (normal - tangent * normal.dot(tangent))
		if normal.length_squared() < 1e-8:
			var hint := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
			normal = tangent.cross(hint).normalized()
		normal = normal.normalized()
		prev_tangent = tangent
		var binormal := tangent.cross(normal).normalized()
		var u := float(i) / float(rings - 1)
		for j in seg:
			var a := TAU * float(j) / float(seg)
			var dir := normal * cos(a) + binormal * sin(a)
			var idx := i * seg + j
			verts[idx] = pts[i] + dir * radius
			norms[idx] = dir
			uvs[idx] = Vector2(u, float(j) / float(seg))
	for i in range(rings - 1):
		for j in seg:
			var j2 := (j + 1) % seg
			var a := i * seg + j
			var b := i * seg + j2
			var c := (i + 1) * seg + j
			var d := (i + 1) * seg + j2
			indices.append(a)
			indices.append(b)
			indices.append(c)
			indices.append(b)
			indices.append(d)
			indices.append(c)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func build_from_controls(points: PackedVector3Array, radius: float, radial: int = 8, subdivisions: int = 3) -> ArrayMesh:
	return build_tube(sample_catmull(points, subdivisions), radius, radial)


static func polyline_length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total
