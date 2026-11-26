class_name HueArt
extends RefCounted

# Procedural art kit: rounded meshes, sigil medallions, soft sprites and paint palette.
# Everything here is generated at runtime; the project contains no textures, fonts or models.

const PAINTS := {
	"blank": Color("f3e7d6"),
	"red": Color("e45a52"),
	"yellow": Color("f0c24b"),
	"blue": Color("4c87db"),
	"orange": Color("ee8a3c"),
	"green": Color("59ba7b"),
	"purple": Color("9669d5"),
	"mud": Color("87756a"),
}
const INK := Color("3b3147")
const INK_SOFT := Color("6d6179")
const CREAM := Color("fff8ec")
const CREAM_DIM := Color("f4e8d7")
const BLUSH := Color("f6c9c0")
const GOLD := Color("e8b44a")

const COLOR_NAMES := {
	"blank": "空白",
	"red": "红",
	"yellow": "黄",
	"blue": "蓝",
	"orange": "橙",
	"green": "绿",
	"purple": "紫",
	"mud": "浊",
}

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func paint_color(id: String) -> Color:
	return PAINTS.get(id, PAINTS["blank"])


static func color_name(id: String) -> String:
	return str(COLOR_NAMES.get(id, id))


static func hex(value: String, alpha := 1.0) -> Color:
	var c := Color.html("#" + value.replace("#", ""))
	c.a = alpha
	return c


static func theme_color(theme: Dictionary, key: String, fallback: Color) -> Color:
	if not theme.has(key):
		return fallback
	var s := str(theme[key])
	if s.is_empty():
		return fallback
	return hex(s)


# ---------------------------------------------------------------- meshes

static func rounded_box_mesh(bevel := 0.13, n := 20) -> ArrayMesh:
	var cache_key := "rounded_box_%.3f_%d" % [bevel, n]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var inner := 0.5 - bevel
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var faces := [
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
	]
	for face_index in faces.size():
		var f: Array = faces[face_index]
		var face_n: Vector3 = f[0]
		var face_u: Vector3 = f[1]
		var face_v: Vector3 = f[2]
		var base := verts.size()
		for i in n + 1:
			var tu := -1.0 + 2.0 * float(i) / float(n)
			for j in n + 1:
				var tv := -1.0 + 2.0 * float(j) / float(n)
				var p0 := face_n * 0.5 + face_u * (0.5 * tu) + face_v * (0.5 * tv)
				var clamped := Vector3(
					clampf(p0.x, -inner, inner),
					clampf(p0.y, -inner, inner),
					clampf(p0.z, -inner, inner)
				)
				var w := p0 - clamped
				var p := p0
				var nrm := face_n
				if w.length_squared() > 0.0000001:
					nrm = w.normalized()
					p = clamped + nrm * bevel
				verts.append(p)
				norms.append(nrm)
				uvs.append(Vector2((tu + 1.0) * 0.5, (tv + 1.0) * 0.5))
		for i in n:
			for j in n:
				var a := base + i * (n + 1) + j
				var b := a + 1
				var c := a + (n + 1) + 1
				var d := a + (n + 1)
				idx.append(a)
				idx.append(d)
				idx.append(c)
				idx.append(a)
				idx.append(c)
				idx.append(b)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[cache_key] = mesh
	return mesh


static func ring_mesh(inner := 0.72, outer := 1.0, segments := 64) -> ArrayMesh:
	var key := "ring_%.2f_%.2f_%d" % [inner, outer, segments]
	if _cache.has(key):
		return _cache[key]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in segments + 1:
		var a := TAU * float(i) / float(segments)
		var ca := cos(a)
		var sa := sin(a)
		verts.append(Vector3(ca * inner, 0.0, sa * inner))
		verts.append(Vector3(ca * outer, 0.0, sa * outer))
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
		uvs.append(Vector2(float(i) / segments, 0.0))
		uvs.append(Vector2(float(i) / segments, 1.0))
	for i in segments:
		var a := i * 2
		var b := a + 1
		var c := a + 2
		var d := a + 3
		idx.append(a)
		idx.append(b)
		idx.append(d)
		idx.append(a)
		idx.append(d)
		idx.append(c)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = mesh
	return mesh


static func soft_dot_texture(size := 64) -> ImageTexture:
	var key := "dot_%d" % size
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	for y in size:
		for x in size:
			var r := Vector2(float(x) - c, float(y) - c).length() / c
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = pow(a, 1.6)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func sigil_texture(id: String) -> ImageTexture:
	var key := "sigil_" + id
	if _cache.has(key):
		return _cache[key]
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	if id != "blank":
		for y in size:
			for x in size:
				var border_hits := 0
				var icon_hits := 0
				for sy in 2:
					for sx in 2:
						var px := ((float(x) + (float(sx) + 0.5) * 0.5) / float(size)) * 2.0 - 1.0
						var py := 1.0 - ((float(y) + (float(sy) + 0.5) * 0.5) / float(size)) * 2.0
						if _medallion_border(px, py):
							border_hits += 1
						if _sigil_inside(id, px, py):
							icon_hits += 1
				var a_border := float(border_hits) / 4.0 * 0.92
				var a_icon := float(icon_hits) / 4.0
				var a := maxf(a_border, a_icon)
				if a > 0.002:
					img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _medallion_border(x: float, y: float) -> bool:
	# Inner stroke of a rounded square "stamp" plate.
	var half := 0.78
	var rad := 0.20
	var qx := absf(x) - (half - rad)
	var qy := absf(y) - (half - rad)
	var outside := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - rad
	return outside <= 0.0 and outside > -0.055


static func _sigil_inside(id: String, x: float, y: float) -> bool:
	if Vector2(x, y).length() > 0.56:
		return false
	match id:
		"red":
			# four-petal flower
			if _disk(x, y, 0.0, 0.0, 0.085):
				return true
			return (
				_disk(x, y, 0.19, 0.0, 0.135) or _disk(x, y, -0.19, 0.0, 0.135)
				or _disk(x, y, 0.0, 0.19, 0.135) or _disk(x, y, 0.0, -0.19, 0.135)
			)
		"yellow":
			if _disk(x, y, 0.0, 0.0, 0.145):
				return true
			for i in 8:
				var a := TAU * float(i) / 8.0
				var inner := Vector2(cos(a), sin(a)) * 0.25
				var outer := Vector2(cos(a), sin(a)) * 0.43
				if _capsule(x, y, inner.x, inner.y, outer.x, outer.y, 0.032):
					return true
			return false
		"blue":
			if _disk(x, y, 0.0, 0.10, 0.185):
				return true
			return _triangle(x, y, Vector2(0.0, -0.42), Vector2(-0.235, 0.10), Vector2(0.235, 0.10))
		"orange":
			if _disk(x, y, 0.0, 0.0, 0.075):
				return true
			return (
				_capsule(x, y, -0.34, -0.34, 0.34, 0.34, 0.055)
				or _capsule(x, y, -0.34, 0.34, 0.34, -0.34, 0.055)
			)
		"green":
			# leaf with a short stem
			if _capsule(x, y, 0.0, -0.44, 0.0, -0.10, 0.026):
				return true
			var leaf := PackedVector2Array([
				Vector2(0.0, -0.30), Vector2(0.22, -0.10), Vector2(0.20, 0.18),
				Vector2(0.0, 0.40), Vector2(-0.20, 0.18), Vector2(-0.22, -0.10),
			])
			return _poly_inside(Vector2(x, y), leaf)
		"purple":
			return _poly_inside(Vector2(x, y), _star_poly(Vector2.ZERO, 0.45, 0.19, 5, -PI * 0.5))
		"mud":
			return (
				_capsule(x, y, -0.30, -0.30, 0.30, 0.30, 0.06)
				or _capsule(x, y, -0.30, 0.30, 0.30, -0.30, 0.06)
			)
	return false


static func _disk(x: float, y: float, cx: float, cy: float, r: float) -> bool:
	return (Vector2(x - cx, y - cy)).length_squared() <= r * r


static func _capsule(x: float, y: float, ax: float, ay: float, bx: float, by: float, r: float) -> bool:
	var p := Vector2(x, y)
	var a := Vector2(ax, ay)
	var b := Vector2(bx, by)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return (p - (a + ab * t)).length_squared() <= r * r


static func _triangle(x: float, y: float, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var p := Vector2(x, y)
	var d1 := _sign(p, a, b)
	var d2 := _sign(p, b, c)
	var d3 := _sign(p, c, a)
	var has_neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_neg and has_pos)


static func _sign(p: Vector2, a: Vector2, b: Vector2) -> float:
	return (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)


static func _poly_inside(p: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in poly.size():
		var pi := poly[i]
		var pj := poly[j]
		if ((pi.y > p.y) != (pj.y > p.y)) \
			and (p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside


static func _star_poly(center: Vector2, outer: float, inner: float, points: int, rot: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		var a := rot + TAU * float(i) / float(points * 2)
		out.append(center + Vector2(cos(a), sin(a)) * r)
	return out


# ---------------------------------------------------------------- materials & shaders

static func backdrop_material(theme: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/backdrop.gdshader")
	m.render_priority = -100
	m.set_shader_parameter("top_color", theme_color(theme, "bg_top", Color("bfd7ef")))
	m.set_shader_parameter("bottom_color", theme_color(theme, "bg_bottom", Color("f8e7d6")))
	m.set_shader_parameter("accent_color", theme_color(theme, "accent", Color("e8796b")))
	return m


static func puddle_material(color: Color, speed := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/puddle.gdshader")
	m.set_shader_parameter("paint_color", color)
	m.set_shader_parameter("ripple_speed", speed)
	return m


static func ring_material(color: Color, alpha := 1.0, softness := 0.22) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ring.gdshader")
	m.set_shader_parameter("tint", Color(color.r, color.g, color.b, alpha))
	m.set_shader_parameter("softness", softness)
	return m


static func matte(color: Color, roughness := 0.62, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func paint_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.30
	m.metallic = 0.0
	m.emission_enabled = true
	m.emission = color * 0.10
	m.emission_energy_multiplier = 1.0
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.35
	return m


static func unshaded(color: Color, alpha := 1.0, double_sided := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.no_depth_test = false
	return m


static func soft_shadow_material(alpha := 0.30) -> StandardMaterial3D:
	var m := unshaded(Color(1, 1, 1, alpha))
	m.albedo_texture = soft_dot_texture(64)
	m.albedo_color = Color(0.12, 0.06, 0.16, alpha)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return m


static func sigil_material(id: String, tint: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = sigil_texture(id)
	m.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return m


static func star_points(center: Vector2, outer: float, inner: float, points := 5, rot := -PI * 0.5) -> PackedVector2Array:
	return _star_poly(center, outer, inner, points, rot)
