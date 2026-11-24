class_name RaceTrack
extends Node3D

# 程序化环野赛道：闭合 Catmull-Rom 中心线 → 路面/路肩/护栏/起跑线/拱门。
# 同时给赛车提供 point_at / nearest / tangent_at 等查询，保证玩家与 AI 用同一条中心线。

const HALF_WIDTH := 7.0
const SEGMENTS_PER_SPAN := 16
const BARRIER_INSET := 1.45

const CONTROL_POINTS := [
	Vector3(-48.0, 0.0, -18.0),
	Vector3(-30.0, 0.0, -42.0),
	Vector3(0.0, 0.0, -50.0),
	Vector3(32.0, 0.0, -42.0),
	Vector3(54.0, 0.0, -20.0),
	Vector3(56.0, 0.0, 8.0),
	Vector3(38.0, 0.0, 28.0),
	Vector3(12.0, 0.0, 26.0),
	Vector3(-4.0, 0.0, 38.0),
	Vector3(-28.0, 0.0, 40.0),
	Vector3(-52.0, 0.0, 22.0),
	Vector3(-58.0, 0.0, 0.0),
]

var samples: Array[Vector3] = []
var tangents: Array[Vector3] = []
var rights: Array[Vector3] = []
var dists: PackedFloat32Array = []
var length := 0.0
var start_gate: Node3D

var _mat_asphalt: StandardMaterial3D
var _mat_white: StandardMaterial3D
var _mat_cream: StandardMaterial3D
var _mat_coral: StandardMaterial3D
var _mat_navy: StandardMaterial3D
var _mat_light_red: StandardMaterial3D
var _mat_light_green: StandardMaterial3D
var _start_lights: Array[MeshInstance3D] = []


func build() -> void:
	name = "Track"
	_build_materials()
	_build_centerline()
	_build_road()
	_build_markings()
	_build_barriers()
	_build_start_gate()
	print("TRACK_READY samples=%d length=%.1fm" % [samples.size(), length])


# ── 中心线与查询 ───────────────────────────────────────────────────────────
func _build_centerline() -> void:
	samples.clear()
	var count := CONTROL_POINTS.size()
	for i in count:
		var p0: Vector3 = CONTROL_POINTS[(i - 1 + count) % count]
		var p1: Vector3 = CONTROL_POINTS[i]
		var p2: Vector3 = CONTROL_POINTS[(i + 1) % count]
		var p3: Vector3 = CONTROL_POINTS[(i + 2) % count]
		for j in SEGMENTS_PER_SPAN:
			samples.append(_catmull(p0, p1, p2, p3, float(j) / float(SEGMENTS_PER_SPAN)))
	var n := samples.size()
	dists.resize(n)
	var total := 0.0
	for i in n:
		dists[i] = total
		total += samples[i].distance_to(samples[(i + 1) % n])
	length = total
	tangents.resize(n)
	rights.resize(n)
	for i in n:
		var t := (samples[(i + 1) % n] - samples[(i - 1 + n) % n])
		t.y = 0.0
		t = t.normalized()
		tangents[i] = t
		rights[i] = t.cross(Vector3.UP).normalized()


func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func point_at(distance: float) -> Vector3:
	var d := wrapf(distance, 0.0, length)
	var i := _segment_index(d)
	var j := (i + 1) % samples.size()
	var d0 := dists[i]
	var d1 := length if j == 0 else dists[j]
	return samples[i].lerp(samples[j], clampf((d - d0) / maxf(0.001, d1 - d0), 0.0, 1.0))


func tangent_at(distance: float) -> Vector3:
	var d := wrapf(distance, 0.0, length)
	var i := _segment_index(d)
	var j := (i + 1) % samples.size()
	var d0 := dists[i]
	var d1 := length if j == 0 else dists[j]
	return tangents[i].lerp(tangents[j], clampf((d - d0) / maxf(0.001, d1 - d0), 0.0, 1.0)).normalized()


func right_at(distance: float) -> Vector3:
	var d := wrapf(distance, 0.0, length)
	var i := _segment_index(d)
	var j := (i + 1) % samples.size()
	var d0 := dists[i]
	var d1 := length if j == 0 else dists[j]
	return rights[i].lerp(rights[j], clampf((d - d0) / maxf(0.001, d1 - d0), 0.0, 1.0)).normalized()


func nearest(world_pos: Vector3) -> Dictionary:
	var best := 0
	var best_dist := INF
	for i in samples.size():
		var dx := samples[i].x - world_pos.x
		var dz := samples[i].z - world_pos.z
		var d2 := dx * dx + dz * dz
		if d2 < best_dist:
			best_dist = d2
			best = i
	var center := samples[best]
	var right := rights[best]
	var tangent := tangents[best]
	var offset := world_pos - center
	offset.y = 0.0
	return {
		"index": best,
		"progress": fposmod(dists[best] + offset.dot(tangent), length),
		"lateral": offset.dot(right),
		"center": center,
		"right": right,
		"tangent": tangent,
	}


func distance_to_center(world_pos: Vector3) -> float:
	var got := nearest(world_pos)
	return absf(float(got["lateral"]))


func curvature_at(distance: float) -> float:
	var a := tangent_at(distance - 7.0)
	var b := tangent_at(distance + 7.0)
	return clampf(a.angle_to(b) / 0.72, 0.0, 1.0)


func grid_transform(progress: float, lane: float) -> Transform3D:
	var pos := point_at(progress) + right_at(progress) * lane
	var tangent := tangent_at(progress)
	var yaw := atan2(-tangent.x, -tangent.z)
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func _segment_index(distance: float) -> int:
	var lo := 0
	var hi := dists.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if dists[mid] <= distance:
			lo = mid
		else:
			hi = mid - 1
	return clampi(lo, 0, dists.size() - 1)


# ── 材质与几何工具 ─────────────────────────────────────────────────────────
func _build_materials() -> void:
	_mat_asphalt = _solid(Color("#65718a"), 0.96)
	_mat_white = _solid(Color("#fbf4df"), 0.9)
	_mat_cream = _solid(Color("#fff0cf"), 0.9)
	_mat_coral = _solid(Color("#f05f58"), 0.88)
	_mat_navy = _solid(Color("#173f5b"), 0.82)
	_mat_light_red = _emissive(Color("#ff5b57"), 1.2)
	_mat_light_green = _emissive(Color("#67f29b"), 1.4)


func _solid(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _emissive(color: Color, energy := 1.0) -> StandardMaterial3D:
	var mat := _solid(color, 0.35)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


func _geo() -> Dictionary:
	return {"v": [], "n": [], "idx": []}


func _add_quad(geo: Dictionary, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3) -> void:
	var verts: Array = geo["v"]
	var normals: Array = geo["n"]
	var indices: Array = geo["idx"]
	var base := verts.size()
	verts.append(p0)
	verts.append(p1)
	verts.append(p2)
	verts.append(p3)
	for i in 4:
		normals.append(normal)
	# Godot 的前面为顺时针；这里反向绕序，保证路面/路肩法线朝上并被阳光照亮。
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 1)
	indices.append(base)
	indices.append(base + 3)
	indices.append(base + 2)


func _mesh_from_geo(geo: Dictionary, material: Material, mesh_name: String) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(geo["v"])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(geo["n"])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(geo["idx"])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _append_ribbon(geo: Dictionary, offset_a: float, offset_b: float, height: float) -> void:
	var n := samples.size()
	for i in n:
		var j := (i + 1) % n
		var a := samples[i] + rights[i] * offset_a + Vector3.UP * height
		var b := samples[i] + rights[i] * offset_b + Vector3.UP * height
		var c := samples[j] + rights[j] * offset_b + Vector3.UP * height
		var d := samples[j] + rights[j] * offset_a + Vector3.UP * height
		_add_quad(geo, a, b, c, d, Vector3.UP)


func _mesh_instance(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, box_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _sphere(parent: Node3D, sphere_name: String, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var instance := MeshInstance3D.new()
	instance.name = sphere_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance


# ── 路面与线 ───────────────────────────────────────────────────────────────
func _build_road() -> void:
	var geo := _geo()
	_append_ribbon(geo, -HALF_WIDTH, HALF_WIDTH, 0.02)
	var road := _mesh_from_geo(geo, _mat_asphalt, "Asphalt")
	add_child(road)


func _build_markings() -> void:
	# 两条白色边线
	var edges := _geo()
	_append_ribbon(edges, -HALF_WIDTH + 0.38, -HALF_WIDTH + 0.62, 0.045)
	_append_ribbon(edges, HALF_WIDTH - 0.62, HALF_WIDTH - 0.38, 0.045)
	add_child(_mesh_from_geo(edges, _mat_white, "EdgeLines"))

	# 红白路肩：按 3 段交替，两色各 1 个 mesh，左右共 4 条带
	for color_index in 2:
		var geo := _geo()
		for side in [-1.0, 1.0]:
			for i in samples.size():
				if int(i / 3) % 2 != color_index:
					continue
				var j := (i + 1) % samples.size()
				var inner_a: float = side * HALF_WIDTH
				var outer_a: float = side * (HALF_WIDTH + 1.15)
				var a := samples[i] + rights[i] * inner_a + Vector3.UP * 0.055
				var b := samples[i] + rights[i] * outer_a + Vector3.UP * 0.055
				var c := samples[j] + rights[j] * outer_a + Vector3.UP * 0.055
				var d := samples[j] + rights[j] * inner_a + Vector3.UP * 0.055
				_add_quad(geo, a, b, c, d, Vector3.UP)
		var mat := _mat_coral if color_index == 0 else _mat_cream
		add_child(_mesh_from_geo(geo, mat, "Curb_%d" % color_index))

	# 中央白虚线：一条 MultiMesh，避开起跑线前后
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.22, 0.025, 2.35)
	var dash_mat := _mat_white
	var dash_count := int(length / 8.0)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = dash_mesh
	multimesh.instance_count = dash_count
	for i in dash_count:
		var progress := 7.0 + float(i) * 8.0
		var tangent := tangent_at(progress)
		var yaw := atan2(-tangent.x, -tangent.z)
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), point_at(progress) + Vector3.UP * 0.055))
	var dash := MultiMeshInstance3D.new()
	dash.name = "CenterDashes"
	dash.multimesh = multimesh
	dash.material_override = dash_mat
	dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dash)


func _build_barriers() -> void:
	# 低矮护栏主体（奶油白） + 珊瑚色压顶，红白路肩之外再收一条安全视觉边。
	var wall_geo := _geo()
	var cap_geo := _geo()
	var n := samples.size()
	for side in [-1.0, 1.0]:
		for i in n:
			var j := (i + 1) % n
			var inner: float = side * (HALF_WIDTH + BARRIER_INSET)
			var outer: float = side * (HALF_WIDTH + BARRIER_INSET + 0.38)
			var a := samples[i] + rights[i] * inner
			var b := samples[j] + rights[j] * inner
			var a_top := a + Vector3.UP * 0.72
			var b_top := b + Vector3.UP * 0.72
			var a_out := samples[i] + rights[i] * outer
			var b_out := samples[j] + rights[j] * outer
			# 内侧立面
			_add_quad(wall_geo, a, a_top, b_top, b, -rights[i] * side)
			# 外侧立面（低多边形，双面材质下可见）
			_add_quad(wall_geo, a_out, b_out, b_out + Vector3.UP * 0.72, a_out + Vector3.UP * 0.72, rights[i] * side)
			# 珊瑚色压顶
			_add_quad(cap_geo, a_top, a_out + Vector3.UP * 0.72, b_out + Vector3.UP * 0.72, b_top, Vector3.UP)
	add_child(_mesh_from_geo(wall_geo, _mat_cream, "BarrierWall"))
	add_child(_mesh_from_geo(cap_geo, _mat_coral, "BarrierCap"))

	# 立柱：每 8m 一对，一条 MultiMesh。
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.16, 1.08, 0.16)
	var post_count := int(length / 8.0) * 2
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	posts.mesh = post_mesh
	posts.instance_count = post_count
	var idx := 0
	for i in int(length / 8.0):
		var progress := float(i) * 8.0
		for side in [-1.0, 1.0]:
			var pos: Vector3 = point_at(progress) + right_at(progress) * float(side) * (HALF_WIDTH + BARRIER_INSET + 0.19)
			posts.set_instance_transform(idx, Transform3D(Basis.IDENTITY, pos + Vector3.UP * 0.56))
			idx += 1
	var post_inst := MultiMeshInstance3D.new()
	post_inst.name = "BarrierPosts"
	post_inst.multimesh = posts
	post_inst.material_override = _mat_cream
	post_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(post_inst)

	# 起跑线：14×3 方格，覆盖整条路宽。
	var dark := _geo()
	var light := _geo()
	var center := point_at(0.0)
	var tangent := tangent_at(0.0)
	var right := right_at(0.0)
	var cols := 14
	var rows := 3
	var col_w := (HALF_WIDTH * 2.0) / float(cols)
	var row_d := 2.4 / float(rows)
	for col in cols:
		for row in rows:
			var x0 := -HALF_WIDTH + float(col) * col_w
			var z0 := -1.2 + float(row) * row_d
			var p0 := center + right * x0 + tangent * z0 + Vector3.UP * 0.07
			var p1 := center + right * (x0 + col_w) + tangent * z0 + Vector3.UP * 0.07
			var p2 := center + right * (x0 + col_w) + tangent * (z0 + row_d) + Vector3.UP * 0.07
			var p3 := center + right * x0 + tangent * (z0 + row_d) + Vector3.UP * 0.07
			var target := dark if (col + row) % 2 == 0 else light
			_add_quad(target, p0, p1, p2, p3, Vector3.UP)
	add_child(_mesh_from_geo(dark, _mat_navy, "StartLineDark"))
	add_child(_mesh_from_geo(light, _mat_cream, "StartLineLight"))


# ── 起跑拱门 ───────────────────────────────────────────────────────────────
func _build_start_gate() -> void:
	start_gate = Node3D.new()
	start_gate.name = "StartGate"
	var tangent := tangent_at(0.0)
	start_gate.position = point_at(0.0)
	start_gate.rotation.y = atan2(-tangent.x, -tangent.z)
	add_child(start_gate)

	for side in [-1.0, 1.0]:
		var x: float = side * 9.3
		_box(start_gate, "GateBase", Vector3(1.25, 0.8, 1.25), Vector3(x, 0.4, 0.0), _mat_coral).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_box(start_gate, "GateColumn", Vector3(0.78, 4.8, 0.78), Vector3(x, 3.0, 0.0), _mat_cream).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_box(start_gate, "GateCapital", Vector3(1.1, 0.28, 1.1), Vector3(x, 5.35, 0.0), _mat_coral).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_box(start_gate, "GateFoot", Vector3(1.4, 0.16, 1.4), Vector3(x, 0.08, 0.0), _mat_navy)
		# 小旗面
		_box(start_gate, "FlagPole", Vector3(0.07, 1.9, 0.07), Vector3(x, 6.5, 0.0), _mat_white)
		var flag := _box(start_gate, "Flag", Vector3(0.06, 0.68, 1.0), Vector3(x + side * -0.10, 7.05, -0.48), _mat_coral if side < 0.0 else _mat_navy)
		flag.rotation.x = 0.08

	# 横梁与标牌
	_box(start_gate, "GateBeam", Vector3(19.4, 0.78, 0.82), Vector3(0.0, 5.36, 0.0), _mat_cream).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_box(start_gate, "GateSign", Vector3(9.4, 1.45, 0.16), Vector3(0.0, 6.02, 0.44), _mat_navy).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_box(start_gate, "SignTrim", Vector3(9.8, 1.65, 0.08), Vector3(0.0, 6.02, 0.34), _mat_cream)

	# 方格装饰带（横梁正面）
	_build_gate_checker()

	# 起跑灯：深色背板圆盘 + 前凸的发光圆盘（两个实心球会互相吞没，不能用球做“环”）。
	_start_lights.clear()
	for i in 3:
		var x := (float(i) - 1.0) * 1.35
		var backing_mesh := CylinderMesh.new()
		backing_mesh.top_radius = 0.30
		backing_mesh.bottom_radius = 0.30
		backing_mesh.height = 0.12
		backing_mesh.radial_segments = 16
		var backing: MeshInstance3D = _mesh_instance(start_gate, backing_mesh, Vector3(x, 5.36, 0.40), _mat_navy, "LightBacking%d" % i)
		backing.rotation.x = PI * 0.5
		var lamp_mesh := CylinderMesh.new()
		lamp_mesh.top_radius = 0.22
		lamp_mesh.bottom_radius = 0.22
		lamp_mesh.height = 0.10
		lamp_mesh.radial_segments = 16
		var light: MeshInstance3D = _mesh_instance(start_gate, lamp_mesh, Vector3(x, 5.36, 0.48), _mat_light_red, "StartLight%d" % i)
		light.rotation.x = PI * 0.5
		_start_lights.append(light)

	# 中文字牌
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Microsoft YaHei", "Arial"])
	font.font_weight = 700
	var title := Label3D.new()
	title.name = "CupTitle"
	title.text = "青岚杯"
	title.font = font
	title.font_size = 92
	title.pixel_size = 0.0084
	title.outline_size = 18
	title.outline_modulate = Color("#0c263c")
	title.modulate = Color("#fff3cf")
	title.position = Vector3(0.0, 5.94, 0.56)
	title.no_depth_test = false
	start_gate.add_child(title)

	var sub := Label3D.new()
	sub.name = "CupSub"
	sub.text = "W I N D M I L L   C U P"
	sub.font = font
	sub.font_size = 28
	sub.pixel_size = 0.007
	sub.modulate = Color("#8ce7e8")
	sub.position = Vector3(0.0, 6.48, 0.52)
	start_gate.add_child(sub)

	# 气球串
	var balloon_colors := [Color("#ff6b64"), Color("#ffd059"), Color("#56d9df"), Color("#fff1cb"), Color("#9ee27b")]
	for i in 7:
		var mat := _solid(balloon_colors[i % balloon_colors.size()], 0.55)
		var x := -8.6 + float(i) * 2.85
		var y := 7.55 + sin(float(i) * 1.7) * 0.28
		var b := _sphere(start_gate, "Balloon%d" % i, 0.42, Vector3(x, y, 0.0), mat)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var string := _box(start_gate, "BalloonString%d" % i, Vector3(0.025, 1.15 + float(i % 3) * 0.22, 0.025), Vector3(x, y - 0.78, 0.0), _mat_white)
		string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_gate_checker() -> void:
	var dark := _geo()
	var light := _geo()
	var cols := 18
	var rows := 2
	var total_w := 18.6
	var total_h := 0.72
	var cell_w := total_w / float(cols)
	var cell_h := total_h / float(rows)
	for col in cols:
		for row in rows:
			var x0 := -total_w * 0.5 + float(col) * cell_w
			var y0 := 4.98 + float(row) * cell_h
			var z := 0.43
			var p0 := Vector3(x0, y0, z)
			var p1 := Vector3(x0 + cell_w, y0, z)
			var p2 := Vector3(x0 + cell_w, y0 + cell_h, z)
			var p3 := Vector3(x0, y0 + cell_h, z)
			var target := dark if (col + row) % 2 == 0 else light
			_add_quad(target, p0, p1, p2, p3, Vector3.BACK)
	start_gate.add_child(_mesh_from_geo(dark, _mat_navy, "GateCheckerDark"))
	start_gate.add_child(_mesh_from_geo(light, _mat_white, "GateCheckerLight"))


func set_start_lights(go: bool) -> void:
	var color := Color("#6df29c") if go else Color("#ff5b57")
	var mat := _mat_light_green if go else _mat_light_red
	for light in _start_lights:
		light.material_override = mat
