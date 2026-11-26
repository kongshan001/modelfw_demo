class_name OceanProps
extends RefCounted

# 原创低模道具：礁石/棕榈/草丛/灌木/木屋/瞭望塔/帆船/小筏/云/海鸥/鱼影。
# 全部由代码生成（无外部模型/贴图）。

const ROCK_GRAY := Color("#cbd2da")
const ROCK_GRAY_DARK := Color("#9fa9b4")
const ROCK_MOSS := Color("#57b83a")
const ROCK_MOSS_LIGHT := Color("#8ada5c")
const ROCK_WET := Color("#7b95a4")

const PALM_DARK := Color("#175f34")
const PALM_MID := Color("#45bf62")
const PALM_LIGHT := Color("#73cf62")
const TRUNK_DARK := Color("#9b6b42")
const TRUNK_LIGHT := Color("#c49a6c")
const WOOD := Color("#a8743f")
const ROOF := Color("#d9a05f")
const ROOF_LIGHT := Color("#ecc084")
const SAIL := Color("#f5efe1")


static func vertex_color_material(rough := 0.9, cull_back := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic = 0.0
	m.metallic_specular = 0.25
	if not cull_back:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func flat_color_material(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic_specular = 0.22
	return m


static func foliage_material(sway := 0.07, dark := Color("#1f7a43"), light := Color("#8fe07a")) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/foliage.gdshader")
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("color_dark", dark)
	m.set_shader_parameter("color_light", light)
	return m


static func _finish(verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, uv2s: PackedVector2Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func _face(out_v: PackedVector3Array, out_n: PackedVector3Array,
		out_c: PackedColorArray, out_uv2: PackedVector2Array,
		a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color,
		w2a := 0.0, w2b := 0.0, w2c := 0.0) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 0.0000001:
		return
	n = n.normalized()
	out_v.append(a)
	out_v.append(b)
	out_v.append(c)
	out_n.append(n)
	out_n.append(n)
	out_n.append(n)
	out_c.append(ca)
	out_c.append(cb)
	out_c.append(cc)
	out_uv2.append(Vector2(w2a, 0))
	out_uv2.append(Vector2(w2b, 0))
	out_uv2.append(Vector2(w2c, 0))


static func _noise3(p: Vector3, seed_v: int) -> float:
	var s := sin(p.x * 3.7 + float(seed_v) * 1.7) * sin(p.y * 4.3 + float(seed_v) * 0.9)
	s *= sin(p.z * 3.1 + float(seed_v) * 2.3)
	return s * 0.5 + 0.5


# ───────────────────────── 礁石 ─────────────────────────
static func make_rock_mesh(seed_v: int, detail := 1, wet := false) -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var base_verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	for i in base_verts.size():
		base_verts[i] = base_verts[i].normalized()
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	var verts := base_verts
	for d in detail:
		var mid_cache: Dictionary = {}
		var new_faces: Array = []
		for f in faces:
			var ia: int = f[0]
			var ib: int = f[1]
			var ic: int = f[2]
			var mids: Array = []
			for pair in [[ia, ib], [ib, ic], [ic, ia]]:
				var key := "%d_%d" % [mini(pair[0], pair[1]), maxi(pair[0], pair[1])]
				if not mid_cache.has(key):
					var mp: Vector3 = (verts[pair[0]] + verts[pair[1]]).normalized()
					verts.append(mp)
					mid_cache[key] = verts.size() - 1
				mids.append(mid_cache[key])
			new_faces.append([ia, mids[0], mids[2]])
			new_faces.append([mids[0], ib, mids[1]])
			new_faces.append([mids[2], mids[1], ic])
			new_faces.append([mids[0], mids[1], mids[2]])
		faces = new_faces

	var shaped: Array[Vector3] = []
	for v in verts:
		var lump := 1.0
		lump += 0.18 * sin(v.x * 3.1 + float(seed_v)) * sin(v.y * 2.4 + 1.3)
		lump += 0.11 * sin(v.z * 4.7 + float(seed_v) * 0.7) * sin(v.x * 2.9)
		var sv := v * lump
		sv.y *= 0.78 + 0.14 * sin(float(seed_v))
		shaped.append(sv)

	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var out_uv2 := PackedVector2Array()
	for f in faces:
		var a: Vector3 = shaped[f[0]]
		var b: Vector3 = shaped[f[1]]
		var c: Vector3 = shaped[f[2]]
		var centroid := (a + b + c) / 3.0
		var n := (b - a).cross(c - a).normalized()
		if n.dot(centroid) < 0.0:
			n = -n
			var tmp := b
			b = c
			c = tmp
		var nz := _noise3(centroid, seed_v)
		var col := ROCK_GRAY.lerp(ROCK_GRAY_DARK, clampf(nz * 0.75, 0.0, 1.0))
		if n.y < 0.05:
			col = col.lerp(ROCK_GRAY_DARK * 0.9, 0.5)
		if n.y > 0.22 and nz > 0.4:
			var moss := ROCK_MOSS.lerp(ROCK_MOSS_LIGHT, nz)
			col = col.lerp(moss, smoothstep(0.35, 0.8, n.y) * smoothstep(0.52, 0.85, nz) * 0.85)
		if wet:
			col = col.lerp(ROCK_WET, 0.35 * smoothstep(0.2, -0.4, n.y) + 0.18)
		_face(out_v, out_n, out_c, out_uv2, a, b, c, col, col, col)
	var m := _finish(out_v, out_n, out_c, out_uv2)
	m.surface_set_material(0, vertex_color_material(0.95))
	return m


# ───────────────────────── 棕榈 ─────────────────────────
static func make_palm_trunk_mesh() -> ArrayMesh:
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var out_uv2 := PackedVector2Array()
	var height := 5.6
	var bend := Vector3(1.25, 0.0, 0.45)
	var rings := 7
	var sides := 6
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	for i in rings:
		var t := float(i) / float(rings - 1)
		pts.append(Vector3(bend.x * pow(t, 1.7), height * t, bend.z * pow(t, 1.7)))
		radii.append(lerpf(0.22, 0.11, t))
	for i in rings - 1:
		for j in sides:
			var a0 := TAU * float(j) / float(sides)
			var a1 := TAU * float(j + 1) / float(sides)
			var p00 := pts[i] + Vector3(cos(a0), 0, sin(a0)) * radii[i]
			var p01 := pts[i] + Vector3(cos(a1), 0, sin(a1)) * radii[i]
			var p10 := pts[i + 1] + Vector3(cos(a0), 0, sin(a0)) * radii[i + 1]
			var p11 := pts[i + 1] + Vector3(cos(a1), 0, sin(a1)) * radii[i + 1]
			var shade := 0.82 + 0.18 * sin(float(i) * 2.2 + float(j))
			var ca := TRUNK_DARK.lerp(TRUNK_LIGHT, shade)
			var cb := ca.darkened(0.08)
			_face(out_v, out_n, out_c, out_uv2, p00, p01, p10, ca, cb, ca)
			_face(out_v, out_n, out_c, out_uv2, p01, p11, p10, cb, cb.darkened(0.06), ca)
	# 树冠底的椰子
	for i in 3:
		var ang := TAU * float(i) / 3.0 + 0.4
		var c := pts[rings - 1] + Vector3(cos(ang) * 0.26, -0.18, sin(ang) * 0.26)
		var r := 0.13
		for s in 6:
			var a0 := TAU * float(s) / 6.0
			var a1 := TAU * float(s + 1) / 6.0
			var p0 := c + Vector3(cos(a0) * r, 0, sin(a0) * r)
			var p1 := c + Vector3(cos(a1) * r, 0, sin(a1) * r)
			_face(out_v, out_n, out_c, out_uv2, p0, p1, c + Vector3(0, 0.12, 0),
					Color("#8a5f34"), Color("#6d4726"), Color("#a5764a"))
	var m := _finish(out_v, out_n, out_c, out_uv2)
	m.surface_set_material(0, vertex_color_material(0.92))
	return m


static func make_palm_crown_mesh() -> ArrayMesh:
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var out_uv2 := PackedVector2Array()
	var crown := Vector3(1.25, 5.6, 0.45)
	var fronds := 12
	var segs := 5
	for f in fronds:
		var ang := TAU * float(f) / float(fronds) + sin(float(f) * 2.3) * 0.16
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var length := 2.2 + 0.5 * sin(float(f) * 1.7 + 0.6)
		var pts: Array[Vector3] = []
		var widths: Array[float] = []
		var p := crown
		for s in segs + 1:
			var t := float(s) / float(segs)
			var elev := lerpf(0.62, -0.85, pow(t, 0.9))
			var step := length / float(segs)
			if s > 0:
				p = p + dir * (cos(elev) * step) + Vector3.UP * (sin(elev) * step)
			pts.append(p)
			widths.append(0.5 * pow(1.0 - t * 0.92, 0.72) * minf(1.0, t * 5.0 + 0.25))
		for s in segs:
			var t0 := float(s) / float(segs)
			var t1 := float(s + 1) / float(segs)
			var c0 := PALM_DARK.lerp(PALM_MID, pow(t0, 0.65)).lerp(PALM_LIGHT, pow(t0, 3.0) * 0.55)
			var c1 := PALM_DARK.lerp(PALM_MID, pow(t1, 0.65)).lerp(PALM_LIGHT, pow(t1, 3.0) * 0.55)
			var p00 := pts[s] + side * widths[s]
			var p01 := pts[s] - side * widths[s]
			var p10 := pts[s + 1] + side * widths[s + 1]
			var p11 := pts[s + 1] - side * widths[s + 1]
			# 中脊微微抬起，正面折角
			var spine0 := pts[s] + Vector3.UP * (widths[s] * 0.35)
			var spine1 := pts[s + 1] + Vector3.UP * (widths[s + 1] * 0.35)
			_face(out_v, out_n, out_c, out_uv2, p00, spine0, p10, c0, c0, c1, 0.25 + 0.75 * t0, 0.25 + 0.75 * t0, 0.25 + 0.75 * t1)
			_face(out_v, out_n, out_c, out_uv2, spine0, spine1, p10, c0, c1, c1, 0.25 + 0.75 * t0, 0.25 + 0.75 * t1, 0.25 + 0.75 * t1)
			_face(out_v, out_n, out_c, out_uv2, spine0, p01, spine1, c0, c0, c1, 0.25 + 0.75 * t0, 0.25 + 0.75 * t0, 0.25 + 0.75 * t1)
			_face(out_v, out_n, out_c, out_uv2, p01, p11, spine1, c0, c1, c1, 0.25 + 0.75 * t0, 0.25 + 0.75 * t1, 0.25 + 0.75 * t1)
	for i in out_n.size():
		if out_n[i].y < 0.0:
			out_n[i] = -out_n[i]
	var m := _finish(out_v, out_n, out_c, out_uv2)
	m.surface_set_material(0, foliage_material(0.10, Color("#1f7a43"), Color("#8fe07a")))
	return m


# ───────────────────────── 草丛 / 灌木 ─────────────────────────
static func make_grass_mesh() -> ArrayMesh:
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var out_uv2 := PackedVector2Array()
	for i in 7:
		var ang := TAU * float(i) / 7.0 + 0.3
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x) * 0.055
		var h := 0.42 + 0.2 * sin(float(i) * 2.1)
		var tip := dir * (0.18 + 0.12 * sin(float(i) * 1.3)) + Vector3.UP * h
		var tone := 0.2 + 0.65 * (0.5 + 0.5 * sin(float(i) * 1.7))
		_face(out_v, out_n, out_c, out_uv2, -side, side, tip,
				Color.WHITE, Color.WHITE, Color.WHITE, tone * 0.7, tone * 0.7, tone)
	for i in out_n.size():
		if out_n[i].y < 0.0:
			out_n[i] = -out_n[i]
	var m := _finish(out_v, out_n, out_c, out_uv2)
	m.surface_set_material(0, foliage_material(0.055, Color("#2f8f4d"), Color("#9fe07a")))
	return m


static func make_shrub_mesh(seed_v := 3) -> ArrayMesh:
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var out_uv2 := PackedVector2Array()
	var base := Color("#4cbb5e")
	var light := Color("#9fe279")
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + seed_v
	var blob_count := 4
	for b in blob_count:
		var center := Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.25, 0.6),
				rng.randf_range(-0.4, 0.4))
		var radius := rng.randf_range(0.35, 0.6)
		var ico: ArrayMesh = make_rock_mesh(seed_v * 7 + b, 0, false)
		var arr := ico.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		for i in range(0, vs.size(), 3):
			var a := center + Vector3(vs[i].x, vs[i].y * 0.75 + 0.2, vs[i].z) * radius
			var bb := center + Vector3(vs[i + 1].x, vs[i + 1].y * 0.75 + 0.2, vs[i + 1].z) * radius
			var cc := center + Vector3(vs[i + 2].x, vs[i + 2].y * 0.75 + 0.2, vs[i + 2].z) * radius
			var col := base.lerp(light, clampf(ns[i].y * 0.8, 0.0, 1.0) * 0.7 + _noise3(a, seed_v) * 0.3)
			_face(out_v, out_n, out_c, out_uv2, a, bb, cc, col, col, col, 0.2, 0.2, 0.2)
	var m := _finish(out_v, out_n, out_c, out_uv2)
	m.surface_set_material(0, foliage_material(0.018, Color("#3a9e4e"), Color("#9be07a")))
	return m


# ───────────────────────── 木屋 ─────────────────────────
static func make_hut() -> Node3D:
	var root := Node3D.new()
	root.name = "Hut"
	var wood := flat_color_material(WOOD, 0.9)
	var wood_dark := flat_color_material(Color("#87592f"), 0.9)
	var roof_mat := flat_color_material(ROOF, 0.92)
	var roof_light := flat_color_material(ROOF_LIGHT, 0.9)
	var floor_mat := flat_color_material(Color("#c8a670"), 0.95)
	var rug_mat := flat_color_material(Color("#b96b4e"), 0.98)

	for i in 4:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.26, 2.2, 0.26)
		post.mesh = pm
		post.material_override = wood_dark
		post.position = Vector3(-2.6 if i % 2 == 0 else 2.6, 1.1, -2.0 if i < 2 else 2.0)
		root.add_child(post)

	var floor_mi := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(6.2, 0.22, 4.8)
	floor_mi.mesh = fm
	floor_mi.material_override = floor_mat
	floor_mi.position = Vector3(0, 2.2, 0)
	root.add_child(floor_mi)

	# 低矮侧墙 / 内部暗色，让屋顶从俯视读成“屋子”而不是桌子
	for side in [-1, 1]:
		var side_wall := MeshInstance3D.new()
		var sw := BoxMesh.new()
		sw.size = Vector3(0.16, 1.5, 4.6)
		side_wall.mesh = sw
		side_wall.material_override = wood
		side_wall.position = Vector3(2.95 * side, 2.95, 0)
		root.add_child(side_wall)
	var inner := MeshInstance3D.new()
	var inn := BoxMesh.new()
	inn.size = Vector3(4.6, 0.08, 4.0)
	inner.mesh = inn
	inner.material_override = flat_color_material(Color("#6e4a2b"), 1.0)
	inner.position = Vector3(0, 2.34, 0)
	root.add_child(inner)

	var ladder := Node3D.new()
	ladder.position = Vector3(-1.8, 1.05, 2.6)
	for s in 2:
		var rail := MeshInstance3D.new()
		var rm3 := BoxMesh.new()
		rm3.size = Vector3(0.12, 2.3, 0.12)
		rail.mesh = rm3
		rail.material_override = wood_dark
		rail.position.x = 0.35 * (1.0 if s == 0 else -1.0)
		ladder.add_child(rail)
	for s in 4:
		var rung := MeshInstance3D.new()
		var rm4 := BoxMesh.new()
		rm4.size = Vector3(0.85, 0.08, 0.1)
		rung.mesh = rm4
		rung.material_override = wood
		rung.position.y = -0.85 + s * 0.55
		ladder.add_child(rung)
	root.add_child(ladder)

	var rug := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(2.6, 0.03, 1.9)
	rug.mesh = rm
	rug.material_override = rug_mat
	rug.position = Vector3(-0.4, 2.33, 0.1)
	root.add_child(rug)

	# 低矮后墙
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(6.0, 1.15, 0.16)
	wall.mesh = wm
	wall.material_override = wood
	wall.position = Vector3(0, 2.85, -2.3)
	root.add_child(wall)

	# 双坡屋顶
	for s in 2:
		var roof := MeshInstance3D.new()
		var rm2 := BoxMesh.new()
		rm2.size = Vector3(7.0, 0.18, 3.05)
		roof.mesh = rm2
		roof.material_override = roof_mat if s == 0 else roof_light
		roof.position = Vector3(0, 4.18, -1.24 if s == 0 else 1.24)
		roof.rotation_degrees = Vector3(32.0 if s == 0 else -32.0, 0, 0)
		root.add_child(roof)
	var ridge := MeshInstance3D.new()
	var rgm := BoxMesh.new()
	rgm.size = Vector3(7.1, 0.14, 0.22)
	ridge.mesh = rgm
	ridge.material_override = roof_light
	ridge.position = Vector3(0, 4.92, 0)
	root.add_child(ridge)
	return root


# ───────────────────────── 瞭望塔 ─────────────────────────
static func make_tower() -> Node3D:
	var root := Node3D.new()
	root.name = "Tower"
	var stone := flat_color_material(Color("#a6b0bd"), 0.9)
	var stone_dark := flat_color_material(Color("#8d98a7"), 0.9)
	var red := flat_color_material(Color("#e2603f"), 0.7)
	var cream := flat_color_material(Color("#efe6d3"), 0.85)

	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.25
	cm.bottom_radius = 1.6
	cm.height = 6.2
	cm.radial_segments = 10
	cm.rings = 1
	base.mesh = cm
	base.material_override = stone
	base.position = Vector3(0, 3.1, 0)
	root.add_child(base)

	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 1.55
	bm.bottom_radius = 1.45
	bm.height = 0.45
	bm.radial_segments = 10
	band.mesh = bm
	band.material_override = stone_dark
	band.position = Vector3(0, 4.9, 0)
	root.add_child(band)

	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 1.75
	tm.bottom_radius = 1.55
	tm.height = 0.55
	tm.radial_segments = 10
	top.mesh = tm
	top.material_override = cream
	top.position = Vector3(0, 6.45, 0)
	root.add_child(top)

	for i in 8:
		var ang := TAU * float(i) / 8.0
		var cren := MeshInstance3D.new()
		var km := BoxMesh.new()
		km.size = Vector3(0.42, 0.42, 0.42)
		cren.mesh = km
		cren.material_override = cream
		cren.position = Vector3(cos(ang) * 1.55, 6.85, sin(ang) * 1.55)
		cren.rotation.y = -ang
		root.add_child(cren)

	var cone := MeshInstance3D.new()
	var conem := CylinderMesh.new()
	conem.top_radius = 0.05
	conem.bottom_radius = 1.9
	conem.height = 1.15
	conem.radial_segments = 10
	conem.rings = 1
	cone.mesh = conem
	cone.material_override = red
	cone.position = Vector3(0, 7.35, 0)
	cone.scale = Vector3(0.85, 0.9, 0.85)
	root.add_child(cone)

	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.055
	pm.bottom_radius = 0.07
	pm.height = 1.8
	pm.radial_segments = 6
	pole.mesh = pm
	pole.material_override = stone_dark
	pole.position = Vector3(0, 7.75, 0)
	root.add_child(pole)

	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.15, 0.5, 0.06)
	flag.mesh = fm
	flag.material_override = red
	flag.position = Vector3(0.55, 8.1, 0)
	root.add_child(flag)

	var beacon := MeshInstance3D.new()
	var bm2 := SphereMesh.new()
	bm2.radius = 0.3
	bm2.height = 0.6
	bm2.radial_segments = 8
	bm2.rings = 4
	beacon.mesh = bm2
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("#ff8a5c")
	glow.emission_enabled = true
	glow.emission = Color("#ff7a4a")
	glow.emission_energy_multiplier = 2.2
	beacon.material_override = glow
	beacon.position = Vector3(0, 8.65, 0)
	root.add_child(beacon)
	return root


# ───────────────────────── 帆船 ─────────────────────────
static func make_boat() -> Node3D:
	var root := Node3D.new()
	root.name = "SailBoat"
	var hull_dark := flat_color_material(Color("#7d4f2e"), 0.9)
	var hull_light := flat_color_material(Color("#a8703f"), 0.85)
	var deck_mat := flat_color_material(Color("#c9a06c"), 0.92)
	var sail_mat := flat_color_material(SAIL, 0.95)
	sail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sail_mat.emission_enabled = true
	sail_mat.emission = Color("#3a3320")
	sail_mat.emission_energy_multiplier = 0.15
	var mast_mat := flat_color_material(Color("#6e482a"), 0.9)
	var red := flat_color_material(Color("#cf5a3b"), 0.8)

	var hull := MeshInstance3D.new()
	hull.mesh = _make_hull_mesh()
	root.add_child(hull)

	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(4.6, 0.1, 1.5)
	deck.mesh = dm
	deck.material_override = deck_mat
	deck.position = Vector3(0, 0.52, 0)
	root.add_child(deck)

	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.055
	mm.bottom_radius = 0.09
	mm.height = 3.6
	mm.radial_segments = 6
	mast.mesh = mm
	mast.material_override = mast_mat
	mast.position = Vector3(0.25, 2.3, 0)
	root.add_child(mast)

	var sail := MeshInstance3D.new()
	sail.mesh = _make_sail_mesh(Vector2(0.25, 4.0), 2.3, 2.6, 0.0)
	sail.material_override = sail_mat
	root.add_child(sail)
	var sail2 := MeshInstance3D.new()
	sail2.mesh = _make_sail_mesh(Vector2(-0.55, 3.1), -1.7, 1.7, 0.12)
	sail2.material_override = sail_mat
	root.add_child(sail2)

	var flag := MeshInstance3D.new()
	var flagm := BoxMesh.new()
	flagm.size = Vector3(0.55, 0.3, 0.04)
	flag.mesh = flagm
	flag.material_override = red
	flag.position = Vector3(0.55, 4.12, 0)
	root.add_child(flag)

	var rail := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(4.7, 0.09, 0.09)
	rail.mesh = rm
	rail.material_override = hull_dark
	rail.position = Vector3(0, 0.66, 0.78)
	root.add_child(rail)
	var rail2 := rail.duplicate() as MeshInstance3D
	rail2.position.z = -0.78
	root.add_child(rail2)
	return root


static func _make_hull_mesh() -> ArrayMesh:
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var out_uv2 := PackedVector2Array()
	var top := Color("#b07a46")
	var side := Color("#8e5c34")
	var bottom := Color("#6d4528")
	# 船体：6 个横截面，上宽下窄，两端收尖
	var sections := [
		[-2.55, 0.18], [-1.7, 0.62], [0.0, 0.78], [1.6, 0.66], [2.55, 0.2],
	]
	var top_y := 0.55
	var bot_y := -0.35
	for i in sections.size() - 1:
		var x0: float = sections[i][0]
		var w0: float = sections[i][1]
		var x1: float = sections[i + 1][0]
		var w1: float = sections[i + 1][1]
		# 顶部甲板边沿
		_face(out_v, out_n, out_c, out_uv2,
				Vector3(x0, top_y, -w0), Vector3(x1, top_y, -w1), Vector3(x1, top_y, w1),
				top, top, top)
		_face(out_v, out_n, out_c, out_uv2,
				Vector3(x0, top_y, -w0), Vector3(x1, top_y, w1), Vector3(x0, top_y, w0),
				top, top, top)
		# 左/右舷
		_face(out_v, out_n, out_c, out_uv2,
				Vector3(x0, top_y, -w0), Vector3(x1, bot_y, -w1 * 0.45), Vector3(x1, top_y, -w1),
				side, bottom, side)
		_face(out_v, out_n, out_c, out_uv2,
				Vector3(x0, top_y, -w0), Vector3(x0, bot_y, -w0 * 0.45), Vector3(x1, bot_y, -w1 * 0.45),
				side, bottom, bottom)
		_face(out_v, out_n, out_c, out_uv2,
				Vector3(x0, top_y, w0), Vector3(x1, top_y, w1), Vector3(x1, bot_y, w1 * 0.45),
				side, side, bottom)
		_face(out_v, out_n, out_c, out_uv2,
				Vector3(x0, top_y, w0), Vector3(x1, bot_y, w1 * 0.45), Vector3(x0, bot_y, w0 * 0.45),
				side, bottom, bottom)
		# 船底
		_face(out_v, out_n, out_c, out_uv2,
				Vector3(x0, bot_y, -w0 * 0.45), Vector3(x0, bot_y, w0 * 0.45), Vector3(x1, bot_y, w1 * 0.45),
				bottom, bottom, bottom)
		_face(out_v, out_n, out_c, out_uv2,
				Vector3(x0, bot_y, -w0 * 0.45), Vector3(x1, bot_y, w1 * 0.45), Vector3(x1, bot_y, -w1 * 0.45),
				bottom, bottom, bottom)
	var m := _finish(out_v, out_n, out_c, out_uv2)
	m.surface_set_material(0, vertex_color_material(0.88))
	return m


static func _make_sail_mesh(base: Vector2, width: float, height: float, bulge: float) -> ArrayMesh:
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var out_uv2 := PackedVector2Array()
	var c := Color("#f7f2e4")
	var c_shadow := Color("#e0d8c6")
	var p0 := Vector3(base.x, base.y, 0)
	var p1 := Vector3(base.x, base.y - height, 0)
	var p2 := Vector3(base.x + width, base.y - height * 0.45, bulge)
	var p3 := Vector3(base.x + width * 0.12, base.y - height * 0.9, 0)
	_face(out_v, out_n, out_c, out_uv2, p0, p1, p2, c, c_shadow, c)
	_face(out_v, out_n, out_c, out_uv2, p0, p2, p3, c, c, c_shadow)
	_face(out_v, out_n, out_c, out_uv2, p1, p2, p3, c_shadow, c_shadow, c)
	var m := _finish(out_v, out_n, out_c, out_uv2)
	m.surface_set_material(0, vertex_color_material(0.95))
	return m


static func make_raft() -> Node3D:
	var root := Node3D.new()
	root.name = "Raft"
	var orange := flat_color_material(Color("#d9773f"), 0.9)
	var wood := flat_color_material(Color("#a9774a"), 0.95)
	var sail := flat_color_material(SAIL, 0.95)
	sail.cull_mode = BaseMaterial3D.CULL_DISABLED
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(2.4, 0.18, 1.5)
	deck.mesh = dm
	deck.material_override = orange
	root.add_child(deck)
	for i in 3:
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(2.3, 0.06, 0.18)
		plank.mesh = pm
		plank.material_override = wood
		plank.position = Vector3(0, 0.12, -0.5 + i * 0.5)
		root.add_child(plank)
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.03
	mm.bottom_radius = 0.05
	mm.height = 1.9
	mm.radial_segments = 5
	mast.mesh = mm
	mast.material_override = wood
	mast.position = Vector3(0.2, 1.0, 0)
	root.add_child(mast)
	var sail_mi := MeshInstance3D.new()
	sail_mi.mesh = _make_sail_mesh(Vector2(0.2, 1.85), 1.15, 1.5, 0.06)
	sail_mi.material_override = sail
	root.add_child(sail_mi)
	return root


# ───────────────────────── 云 / 海鸥 / 鱼影 ─────────────────────────
static func make_cloud_mesh(seed_v: int) -> ArrayMesh:
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var out_uv2 := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# 一排横向主蓬 + 顶部小蓬：更接近参考里的奶白棉花云
	var blobs := [
		[Vector3(-3.0, -0.2, 0.0), 2.5],
		[Vector3(-0.9, 0.3, 0.4), 3.1],
		[Vector3(1.4, 0.1, -0.3), 3.0],
		[Vector3(3.5, -0.25, 0.1), 2.3],
		[Vector3(-1.3, 1.9, -0.4), 2.1],
		[Vector3(1.5, 1.7, 0.5), 1.9],
	]
	var rings := 9
	var segs := 18
	for b in blobs:
		var center: Vector3 = b[0]
		var rad: float = b[1]
		center += Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.1, 0.1), rng.randf_range(-0.2, 0.2))
		for i in rings:
			var v0 := float(i) / float(rings)
			var v1 := float(i + 1) / float(rings)
			var th0 := PI * v0
			var th1 := PI * v1
			for j in segs:
				var p0 := TAU * float(j) / float(segs)
				var p1 := TAU * float(j + 1) / float(segs)
				var s00 := Vector3(sin(th0) * cos(p0), cos(th0), sin(th0) * sin(p0))
				var s01 := Vector3(sin(th0) * cos(p1), cos(th0), sin(th0) * sin(p1))
				var s10 := Vector3(sin(th1) * cos(p0), cos(th1), sin(th1) * sin(p0))
				var s11 := Vector3(sin(th1) * cos(p1), cos(th1), sin(th1) * sin(p1))
				var p000 := center + Vector3(s00.x, s00.y * 0.72, s00.z) * rad
				var p001 := center + Vector3(s01.x, s01.y * 0.72, s01.z) * rad
				var p010 := center + Vector3(s10.x, s10.y * 0.72, s10.z) * rad
				var p011 := center + Vector3(s11.x, s11.y * 0.72, s11.z) * rad
				var white := Color(1, 1, 1)
				out_v.append(p000)
				out_v.append(p001)
				out_v.append(p010)
				out_n.append(s00)
				out_n.append(s01)
				out_n.append(s10)
				out_c.append(white)
				out_c.append(white)
				out_c.append(white)
				out_uv2.append(Vector2.ZERO)
				out_uv2.append(Vector2.ZERO)
				out_uv2.append(Vector2.ZERO)
				out_v.append(p001)
				out_v.append(p011)
				out_v.append(p010)
				out_n.append(s01)
				out_n.append(s11)
				out_n.append(s10)
				out_c.append(white)
				out_c.append(white)
				out_c.append(white)
				out_uv2.append(Vector2.ZERO)
				out_uv2.append(Vector2.ZERO)
				out_uv2.append(Vector2.ZERO)
	var m := _finish(out_v, out_n, out_c, out_uv2)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/cloud.gdshader")
	m.surface_set_material(0, mat)
	return m


static func make_bird_mesh() -> ArrayMesh:
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var out_uv2 := PackedVector2Array()
	var white := Color("#f5f7f7")
	var gray := Color("#c8d2d6")
	var tip := Color("#7e8f96")
	# 身体（细长八面体）
	var nose := Vector3(0.55, 0, 0)
	var tail := Vector3(-0.6, 0.03, 0)
	var top := Vector3(0, 0.12, 0)
	var bot := Vector3(0, -0.04, 0)
	var l := Vector3(-0.05, 0, 0.12)
	var r := Vector3(-0.05, 0, -0.12)
	_face(out_v, out_n, out_c, out_uv2, nose, top, l, white, white, white)
	_face(out_v, out_n, out_c, out_uv2, nose, r, top, white, white, white)
	_face(out_v, out_n, out_c, out_uv2, nose, l, bot, white, gray, gray)
	_face(out_v, out_n, out_c, out_uv2, nose, bot, r, white, gray, gray)
	_face(out_v, out_n, out_c, out_uv2, tail, l, top, gray, white, white)
	_face(out_v, out_n, out_c, out_uv2, tail, top, r, gray, white, white)
	_face(out_v, out_n, out_c, out_uv2, tail, bot, l, gray, gray, white)
	_face(out_v, out_n, out_c, out_uv2, tail, r, bot, gray, white, gray)
	# 翅膀：3 段折线，外段深灰
	for side in [-1.0, 1.0]:
		var w0 := Vector3(0.0, 0.02, 0.15 * side)
		var w1 := Vector3(-0.05, 0.06, 1.0 * side)
		var w2 := Vector3(-0.25, -0.02, 1.5 * side)
		var w3 := Vector3(-0.55, -0.05, 1.25 * side)
		_face(out_v, out_n, out_c, out_uv2, w0, w1, w2, white, gray, tip)
		_face(out_v, out_n, out_c, out_uv2, w0, w2, w3, white, tip, gray)
	var m := _finish(out_v, out_n, out_c, out_uv2)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/bird.gdshader")
	m.surface_set_material(0, mat)
	return m


static func make_fish_mesh() -> ArrayMesh:
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var out_uv2 := PackedVector2Array()
	var col := Color("#134a5c")
	var col2 := Color("#1d6474")
	var nose := Vector3(0.5, 0, 0)
	var tail0 := Vector3(-0.35, 0, 0.16)
	var tail1 := Vector3(-0.35, 0, -0.16)
	var fin := Vector3(-0.62, 0, 0)
	_face(out_v, out_n, out_c, out_uv2, nose, tail0, Vector3(0, 0, 0), col2, col, col)
	_face(out_v, out_n, out_c, out_uv2, nose, Vector3(0, 0, 0), tail1, col2, col, col)
	_face(out_v, out_n, out_c, out_uv2, tail0, fin, tail1, col, col2, col)
	var m := _finish(out_v, out_n, out_c, out_uv2)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.52)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	return m
