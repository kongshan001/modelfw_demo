extends RefCounted
## 原创程序化几何工具：低模石块/树冠叶片/踏石/发光贴图。
## 所有几何在本工程内生成，不依赖外部模型或贴图。

const PHI := 1.6180339887

const ICO_VERTS := [
	Vector3(-1, PHI, 0), Vector3(1, PHI, 0), Vector3(-1, -PHI, 0), Vector3(1, -PHI, 0),
	Vector3(0, -1, PHI), Vector3(0, 1, PHI), Vector3(0, -1, -PHI), Vector3(0, 1, -PHI),
	Vector3(PHI, 0, -1), Vector3(PHI, 0, 1), Vector3(-PHI, 0, -1), Vector3(-PHI, 0, 1),
]

const ICO_FACES := [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
	[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
	[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
	[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
]


static func surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func finish(st: SurfaceTool) -> ArrayMesh:
	return st.commit()


static func add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		color: Color, normal := Vector3.ZERO) -> void:
	var n := normal
	if n == Vector3.ZERO:
		n = (b - a).cross(c - a)
		if n.length_squared() > 0.000001:
			n = n.normalized()
		else:
			n = Vector3.UP
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_color(color)
		st.add_vertex(v)


static func add_tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, color: Color,
		normal := Vector3.ZERO) -> void:
	var n := normal
	if n == Vector3.ZERO:
		n = (b - a).cross(c - a)
		if n.length_squared() > 0.000001:
			n = n.normalized()
		else:
			n = Vector3.UP
	var pairs := [[a, ua], [b, ub], [c, uc]]
	for pair in pairs:
		st.set_normal(n)
		st.set_uv(pair[1])
		st.set_color(color)
		st.add_vertex(pair[0])


static func add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		color: Color, normal := Vector3.ZERO) -> void:
	add_tri(st, a, b, c, color, normal)
	add_tri(st, a, c, d, color, normal)


static func add_box(st: SurfaceTool, center: Vector3, size: Vector3, basis: Basis,
		color: Color) -> void:
	var h := size * 0.5
	var pts: Array[Vector3] = []
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				pts.append(center + basis * Vector3(h.x * x, h.y * y, h.z * z))
	# 索引与 Geo 内部面顺序：(-x,-y,-z)=0, (+x,-y,-z)=1, (+x,+y,-z)=2, (-x,+y,-z)=3,
	# (-x,-y,+z)=4, (+x,-y,+z)=5, (+x,+y,+z)=6, (-x,+y,+z)=7
	var order := [
		[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3],
		[1, 2, 6, 5], [0, 1, 5, 4], [3, 7, 6, 2],
	]
	for face in order:
		add_quad(st, pts[face[0]], pts[face[1]], pts[face[2]], pts[face[3]], color)


static func add_cylinder(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float,
		sides: int, color: Color, cap := false) -> void:
	var axis := b - a
	if axis.length_squared() < 0.000001:
		return
	axis = axis.normalized()
	var guide := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
	var u := axis.cross(guide).normalized()
	var v := axis.cross(u).normalized()
	var base_ring: Array[Vector3] = []
	var top_ring: Array[Vector3] = []
	for i in range(sides):
		var ang := TAU * float(i) / float(sides)
		var dir := u * cos(ang) + v * sin(ang)
		base_ring.append(a + dir * r0)
		top_ring.append(b + dir * r1)
	for i in range(sides):
		var j := (i + 1) % sides
		var shade := color.lightened(0.05 * sin(float(i) * 2.1))
		add_quad(st, base_ring[i], base_ring[j], top_ring[j], top_ring[i], shade)
	if cap:
		var center_a := a
		var center_b := b
		for i in range(sides):
			var j := (i + 1) % sides
			add_tri(st, center_a, base_ring[j], base_ring[i], color.darkened(0.10))
			add_tri(st, center_b, top_ring[i], top_ring[j], color.lightened(0.06))


static func add_cone(st: SurfaceTool, base: Vector3, radius: float, height: float,
		sides: int, color: Color, tip_color := Color(0, 0, 0, 0)) -> void:
	var tip_color_use := color.lightened(0.12) if tip_color.a <= 0.0 else tip_color
	var apex := base + Vector3(0, height, 0)
	var ring: Array[Vector3] = []
	for i in range(sides):
		var ang := TAU * float(i) / float(sides)
		ring.append(base + Vector3(cos(ang), 0, sin(ang)) * radius)
	for i in range(sides):
		var j := (i + 1) % sides
		add_tri(st, ring[i], ring[j], apex, color.lerp(tip_color_use, 0.55))
	for i in range(1, sides - 1):
		add_tri(st, base, ring[i], ring[i + 1], color.darkened(0.12), Vector3.DOWN)


static func add_ico(st: SurfaceTool, center: Vector3, radii: Vector3, color: Color,
		basis := Basis.IDENTITY, seed := 1, jitter := 0.12) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var verts: Array[Vector3] = []
	for base in ICO_VERTS:
		var unit: Vector3 = base.normalized()
		var j := 1.0 + rng.randf_range(-jitter, jitter)
		var p := Vector3(unit.x * radii.x, unit.y * radii.y, unit.z * radii.z) * j
		verts.append(center + basis * p)
	for face in ICO_FACES:
		var a: Vector3 = verts[face[0]]
		var b: Vector3 = verts[face[1]]
		var c: Vector3 = verts[face[2]]
		var n := (b - a).cross(c - a)
		if n.dot((a + b + c) / 3.0 - center) < 0.0:
			var tmp := b
			b = c
			c = tmp
			n = -n
		var fc := color
		fc = fc.lightened(rng.randf_range(-0.045, 0.055))
		add_tri(st, a, b, c, fc)


static func add_leaf_card(st: SurfaceTool, center: Vector3, width: float, length: float,
		color: Color, rng: RandomNumberGenerator, droop := 0.0) -> void:
	var ang := rng.randf_range(0.0, TAU)
	var tilt := rng.randf_range(-0.65, 0.65)
	var b := Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, tilt)
	var right := b * Vector3(width * 0.5, 0.0, 0.0)
	var up := b * Vector3(0.0, 0.0, -length * 0.5)
	var tip_drop := b * Vector3(0.0, -droop, 0.0)
	var a := center - right
	var bb := center + up + tip_drop
	var c := center + right
	var d := center - up
	add_quad(st, a, bb, c, d, color)


static func add_stone(st: SurfaceTool, center: Vector3, rx: float, rz: float,
		height: float, sides: int, seed: int, top_color: Color, side_color: Color,
		rotation := 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts: Array[Vector3] = []
	for i in range(sides):
		var ang := rotation + TAU * float(i) / float(sides)
		var r := rng.randf_range(0.82, 1.12)
		pts.append(center + Vector3(cos(ang) * rx * r, 0.0, sin(ang) * rz * r))
	var top := center + Vector3.UP * height
	for i in range(sides):
		var j := (i + 1) % sides
		var outward := (pts[i] + pts[j]) * 0.5 - center
		outward.y = 0.0
		outward = outward.normalized() + Vector3.UP * 0.16
		outward = outward.normalized()
		add_tri(st, top, pts[j], pts[i], top_color.lightened(rng.randf_range(-0.035, 0.045)), Vector3.UP)
		add_tri(st, pts[i], pts[j], pts[j] - Vector3.UP * height, side_color, outward)
		add_tri(st, pts[i], pts[j] - Vector3.UP * height, pts[i] - Vector3.UP * height, side_color.darkened(0.06), outward)


static func add_ribbon(st: SurfaceTool, points: Array[Vector3], widths: Array[float],
		color_a: Color, color_b: Color) -> void:
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var dir := (b - a)
		dir.y = 0.0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0.0, dir.x)
		var aw := widths[i] * 0.5
		var bw := widths[i + 1] * 0.5
		var shade := color_a.lerp(color_b, float(i) / maxf(1.0, float(points.size() - 1)))
		add_quad(st, a - side * aw, b - side * bw, b + side * bw, a + side * aw, shade, Vector3.UP)


static func make_vcol_material(rough := 0.9, extra_emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = rough
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if extra_emission > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(0.45, 0.38, 0.22)
		mat.emission_energy_multiplier = extra_emission
	return mat


static func make_std_material(color: Color, rough := 0.9, emission := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = 0.0
	if emission.a > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission.a * 3.0
	return mat


static func make_radial_texture(size := 64, power := 1.8) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2((float(x) - half) / half, (float(y) - half) / half).length()
			var alpha := pow(clampf(1.0 - d, 0.0, 1.0), power)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func make_cloud_texture(size := 128) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 1741
	noise.frequency = 0.026
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.55
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var uv := Vector2(float(x) / float(size), float(y) / float(size))
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var edge := smoothstep(0.0, 0.26, uv.x) * smoothstep(1.0, 0.74, uv.x)
			edge *= smoothstep(0.0, 0.30, uv.y) * smoothstep(1.0, 0.70, uv.y)
			var a := smoothstep(0.44, 0.72, n) * edge
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * 0.92))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func lighten_srgb(c: Color, amount: float) -> Color:
	return Color(
		clampf(c.r + amount, 0.0, 1.0),
		clampf(c.g + amount, 0.0, 1.0),
		clampf(c.b + amount, 0.0, 1.0),
		c.a)
