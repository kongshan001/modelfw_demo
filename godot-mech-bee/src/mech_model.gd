extends Node3D

# Procedural Mellis HB-7. No imported meshes: every part is built from Godot
# primitives and shaded with a fixed-light unshaded shader so it looks identical
# on GL Compatibility (Intel iGPU) and Forward+.

const SURFACE := preload("res://shaders/mech_surface.gdshader")
const WING := preload("res://shaders/wing.gdshader")

const RED := Color("#D33A22")
const INK := Color("#171715")
const PAPER := Color("#EDE8DA")

var app: Node
var root: Node3D
var parts: Array = []
var antennae: Array = []

var mat_white: ShaderMaterial
var mat_white_hi: ShaderMaterial
var mat_black: ShaderMaterial
var mat_dark: ShaderMaterial
var mat_red: ShaderMaterial
var mat_brass: ShaderMaterial
var mat_glass: ShaderMaterial
var mat_wing: ShaderMaterial
var mat_ghost: ShaderMaterial
var mat_highlight: StandardMaterial3D

var wing_tex: ImageTexture
var _highlight_id := ""
var _rise := 0.0


class Part:
	var id := ""
	var label := ""
	var node: Node3D
	var meshes: Array = []
	var home := Vector3.ZERO
	var explode_dir := Vector3.ZERO
	var label_local := Vector3.ZERO
	var visible := true
	var side := 1
	var wing_index := 0
	var is_wing := false
	var is_leg := false
	var ghost_pivots: Array = []
	var leg_phase := 0.0

	func label_point() -> Vector3:
		return node.to_global(label_local)


func build(owner_app: Node) -> void:
	app = owner_app
	name = "BeeModel"
	_make_materials()
	wing_tex = _make_wing_texture()
	mat_wing.set_shader_parameter("wing_tex", wing_tex)
	mat_ghost.set_shader_parameter("wing_tex", wing_tex)
	root = Node3D.new()
	root.name = "BeeRoot"
	root.position = Vector3(0, 1.6, 0)
	add_child(root)
	_build_thorax()
	_build_head()
	_build_abdomen()
	_build_wings()
	_build_legs()


func _make_materials() -> void:
	mat_white = _surface(Color("#FFFFFF"), 0.14, 0.10, 1.0, Color("#FFF6E2"))
	mat_white_hi = _surface(Color("#FFFFFF"), 0.10, 0.16, 1.0, Color("#FFFBF0"))
	mat_black = _surface(Color("#141412"), 0.55, 0.30, 1.0, Color("#E8DCC4"))
	mat_dark = _surface(Color("#2B2A26"), 0.25, 0.15, 1.0, Color("#D8CCB4"))
	mat_red = _surface(Color("#CE3A24"), 0.50, 0.30, 1.0, Color("#FF6A4A"))
	mat_brass = _surface(Color("#B08A4F"), 0.60, 0.25, 1.0, Color("#E8C27A"))
	mat_glass = _surface(Color("#F8F5EC"), 0.60, 0.28, 0.06, Color("#FFFFFF"))

	mat_wing = ShaderMaterial.new()
	mat_wing.shader = WING
	mat_wing.set_shader_parameter("tint", Color("#F3EFE2"))
	mat_wing.set_shader_parameter("opacity", 0.95)
	mat_wing.set_shader_parameter("ghost", 0.0)

	mat_ghost = ShaderMaterial.new()
	mat_ghost.shader = WING
	mat_ghost.set_shader_parameter("tint", Color("#F3EFE2"))
	mat_ghost.set_shader_parameter("opacity", 0.46)
	mat_ghost.set_shader_parameter("ghost", 0.7)

	mat_highlight = StandardMaterial3D.new()
	mat_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_highlight.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat_highlight.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_highlight.albedo_color = Color(0.95, 0.18, 0.08, 0.34)


func _surface(color: Color, spec: float, rim: float,
		alpha := 1.0, rim_color := Color("#FF6B4A")) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("specular_amount", spec)
	m.set_shader_parameter("rim_amount", rim)
	m.set_shader_parameter("rim_color", rim_color)
	m.set_shader_parameter("alpha", alpha)
	return m


# ── primitives ──────────────────────────────────────────────────────────────

func _new_part(id: String, label: String, home: Vector3, dir: Vector3) -> Part:
	var p := Part.new()
	p.id = id
	p.label = label
	p.home = home
	p.explode_dir = dir
	p.node = Node3D.new()
	p.node.name = id
	p.node.position = home
	root.add_child(p.node)
	parts.append(p)
	return p


func _add_mesh(p: Part, mesh: Mesh, pos: Vector3, rot := Vector3.ZERO,
		scl := Vector3.ONE, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if mat:
		mi.material_override = mat
	p.node.add_child(mi)
	p.meshes.append(mi)
	return mi


func _sphere(radius: float, segments := 24) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = max(8, segments / 2)
	return m


func _cyl(radius: float, height: float, segments := 20) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


func _torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 10
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _segment(p: Part, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var d := b - a
	var length := d.length()
	if length < 0.0001:
		return null
	var mi := _add_mesh(p, _cyl(radius, length), (a + b) * 0.5, Vector3.ZERO, Vector3.ONE, mat)
	var y := d / length
	var x := Vector3.UP.cross(y)
	if x.length_squared() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	mi.basis = Basis(x, y, z)
	return mi


# ── body ────────────────────────────────────────────────────────────────────

func _build_thorax() -> void:
	var p := _new_part("thorax", "THORAX DRIVE", Vector3.ZERO, Vector3(0, 1.05, 0))
	_add_mesh(p, _cyl(0.32, 0.94), Vector3.ZERO, Vector3(0, 0, PI * 0.5), Vector3.ONE, mat_black)
	_add_mesh(p, _sphere(0.5, 32), Vector3(-0.02, 0.02, 0), Vector3.ZERO,
		Vector3(0.95, 0.82, 0.76), mat_white)
	_add_mesh(p, _sphere(0.5, 32), Vector3(0.2, 0.0, 0), Vector3.ZERO,
		Vector3(0.32, 0.9, 0.82), mat_white_hi)
	_add_mesh(p, _torus(0.34, 0.41), Vector3(0.34, 0, 0), Vector3(0, 0, PI * 0.5), Vector3.ONE, mat_red)
	_add_mesh(p, _torus(0.34, 0.41), Vector3(-0.31, 0, 0), Vector3(0, 0, PI * 0.5), Vector3.ONE, mat_red)
	_add_mesh(p, _torus(0.36, 0.40), Vector3(0.06, 0, 0), Vector3(0, 0, PI * 0.5), Vector3.ONE, mat_dark)
	for i in 6:
		var a := TAU * float(i) / 6.0
		_add_mesh(p, _sphere(0.035, 10),
			Vector3(0.36, cos(a) * 0.44, sin(a) * 0.44), Vector3.ZERO, Vector3.ONE, mat_brass)
	p.label_local = Vector3(0, 0.55, 0)

	var clear := _new_part("clear", "CLEAR CAPSULE", Vector3.ZERO, Vector3(0.15, 1.45, 0.4))
	_add_mesh(clear, _sphere(0.54, 32), Vector3(0, 0.02, 0), Vector3.ZERO,
		Vector3(1.02, 0.84, 0.82), mat_glass)
	_add_mesh(clear, _torus(0.49, 0.51), Vector3(0.45, 0.02, 0), Vector3(0, 0, PI * 0.5),
		Vector3.ONE, mat_brass)
	clear.label_local = Vector3(0.0, 0.52, 0.32)


func _build_head() -> void:
	var p := _new_part("head", "OPTIC HEAD", Vector3.ZERO, Vector3(1.25, 0.28, 0))
	_add_mesh(p, _cyl(0.3, 0.22), Vector3(0.68, 0, 0), Vector3(0, 0, PI * 0.5), Vector3.ONE, mat_black)
	_add_mesh(p, _sphere(0.46, 32), Vector3(0.95, 0.03, 0), Vector3.ZERO,
		Vector3(1.0, 0.9, 0.9), mat_white)
	_add_mesh(p, _sphere(0.4, 32), Vector3(1.02, 0.12, 0), Vector3.ZERO,
		Vector3(0.45, 0.72, 0.72), mat_white_hi)
	_add_mesh(p, _torus(0.30, 0.36), Vector3(0.67, 0, 0), Vector3(0, 0, PI * 0.5), Vector3.ONE, mat_red)
	for side in [-1.0, 1.0]:
		var base := Vector3(0.92, 0.38, side * 0.13)
		var tip := Vector3(1.26, 0.67, side * 0.24)
		_segment(p, base, tip, 0.018, mat_black)
		_add_mesh(p, _sphere(0.043, 10), tip, Vector3.ZERO, Vector3.ONE, mat_red)
		_add_mesh(p, _sphere(0.055, 10), base, Vector3.ZERO, Vector3.ONE, mat_brass)
	antennae = [p]
	_add_mesh(p, _sphere(0.028, 8), Vector3(1.13, 0.28, 0.28), Vector3.ZERO, Vector3.ONE, mat_brass)
	_add_mesh(p, _sphere(0.028, 8), Vector3(1.13, 0.28, -0.28), Vector3.ZERO, Vector3.ONE, mat_brass)
	p.label_local = Vector3(1.02, 0.5, 0)

	var optics := _new_part("optics", "OPTIC LENS", Vector3.ZERO, Vector3(1.95, 0.65, 0))
	_add_mesh(optics, _sphere(0.27, 32), Vector3(1.25, 0.03, 0), Vector3.ZERO,
		Vector3(0.62, 1.0, 1.0), mat_black)
	_add_mesh(optics, _sphere(0.17, 24), Vector3(1.37, 0.03, 0), Vector3.ZERO,
		Vector3(0.42, 1.0, 1.0), mat_dark)
	_add_mesh(optics, _torus(0.28, 0.335), Vector3(1.14, 0.03, 0), Vector3(0, 0, PI * 0.5),
		Vector3.ONE, mat_red)
	_add_mesh(optics, _torus(0.335, 0.355), Vector3(1.14, 0.03, 0), Vector3(0, 0, PI * 0.5),
		Vector3.ONE, mat_brass)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		_add_mesh(optics, _sphere(0.03, 8),
			Vector3(1.16, cos(a) * 0.22, sin(a) * 0.22), Vector3.ZERO, Vector3.ONE, mat_brass)
	optics.label_local = Vector3(1.36, 0.35, 0)


func _build_abdomen() -> void:
	var a := _new_part("abdomen_a", "ABDOMEN CAPSULE", Vector3.ZERO, Vector3(-0.8, 0.28, 0))
	_add_mesh(a, _sphere(0.46, 32), Vector3(-0.55, 0.01, 0), Vector3.ZERO,
		Vector3(0.92, 0.82, 0.8), mat_white)
	_add_mesh(a, _torus(0.40, 0.46), Vector3(-0.44, 0, 0), Vector3(0, 0, PI * 0.5), Vector3.ONE, mat_black)
	_add_mesh(a, _sphere(0.42, 32), Vector3(-0.9, 0.0, 0), Vector3.ZERO,
		Vector3(0.92, 0.8, 0.78), mat_white_hi)
	_add_mesh(a, _torus(0.37, 0.43), Vector3(-0.74, 0, 0), Vector3(0, 0, PI * 0.5), Vector3.ONE, mat_red)
	a.label_local = Vector3(-0.7, 0.46, 0)

	var b := _new_part("abdomen_b", "SHELL SEGMENT", Vector3.ZERO, Vector3(-1.5, 0.38, 0))
	_add_mesh(b, _sphere(0.38, 32), Vector3(-1.19, 0.0, 0), Vector3.ZERO,
		Vector3(0.94, 0.8, 0.76), mat_white)
	_add_mesh(b, _torus(0.33, 0.39), Vector3(-1.09, 0, 0), Vector3(0, 0, PI * 0.5), Vector3.ONE, mat_black)
	_add_mesh(b, _sphere(0.33, 28), Vector3(-1.45, 0.0, 0), Vector3.ZERO,
		Vector3(0.92, 0.78, 0.74), mat_white_hi)
	_add_mesh(b, _torus(0.29, 0.34), Vector3(-1.34, 0, 0), Vector3(0, 0, PI * 0.5), Vector3.ONE, mat_red)
	b.label_local = Vector3(-1.3, 0.4, 0)

	var tail := _new_part("tail", "TAIL GEAR · 32T", Vector3.ZERO, Vector3(-2.2, 0.08, 0))
	_add_mesh(tail, _torus(0.17, 0.27), Vector3(-1.72, 0, 0), Vector3(0, 0, PI * 0.5), Vector3.ONE, mat_brass)
	_add_mesh(tail, _cyl(0.09, 0.1), Vector3(-1.72, 0, 0), Vector3(0, 0, PI * 0.5), Vector3.ONE, mat_red)
	for i in 12:
		var ang := TAU * float(i) / 12.0
		var mi := _add_mesh(tail, _box(Vector3(0.05, 0.075, 0.05)),
			Vector3(-1.72, cos(ang) * 0.3, sin(ang) * 0.3), Vector3(ang, 0, 0), Vector3.ONE, mat_brass)
	tail.label_local = Vector3(-1.8, 0.36, 0)


func _build_wings() -> void:
	var specs := [
		{"id": "wing_lf", "label": "WING ROOT L1", "x": 0.12, "side": 1.0, "idx": 0},
		{"id": "wing_lr", "label": "WING ROOT L2", "x": -0.26, "side": 1.0, "idx": 1},
		{"id": "wing_rf", "label": "WING ROOT R1", "x": 0.12, "side": -1.0, "idx": 2},
		{"id": "wing_rr", "label": "WING ROOT R2", "x": -0.26, "side": -1.0, "idx": 3},
	]
	for spec in specs:
		var side: float = spec["side"]
		var pivot := Vector3(spec["x"], 0.34, side * 0.38)
		var p := _new_part(spec["id"], spec["label"], pivot,
			Vector3(spec["x"] * 0.2, 0.7, side * 1.35))
		p.side = int(side)
		p.is_wing = true
		p.wing_index = int(spec["idx"])

		var hinge := _add_mesh(p, _cyl(0.05, 0.18), Vector3(0, 0, 0),
			Vector3(PI * 0.5, 0, 0), Vector3.ONE, mat_red)
		_add_mesh(p, _sphere(0.065, 12), Vector3(0, 0, 0), Vector3.ZERO, Vector3.ONE, mat_black)

		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.52, 1.55)
		var wing := _add_mesh(p, mesh, Vector3(-0.08, 0, side * 0.78),
			Vector3(side * PI * 0.5, 0, 0), Vector3.ONE, mat_wing)
		wing.name = "WingSurface"

		for j in 2:
			var gp := Node3D.new()
			gp.name = "Ghost%d" % j
			p.node.add_child(gp)
			var ghost := _add_mesh_in(gp, mesh, Vector3(-0.08, 0, side * 0.78),
				Vector3(side * PI * 0.5, 0, 0), Vector3.ONE, mat_ghost)
			p.ghost_pivots.append(gp)

		p.label_local = Vector3(0, 0.06, side * 0.9)


func _add_mesh_in(parent: Node3D, mesh: Mesh, pos: Vector3, rot := Vector3.ZERO,
		scl := Vector3.ONE, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if mat:
		mi.material_override = mat
	parent.add_child(mi)
	return mi


func _build_legs() -> void:
	var xs := [0.36, 0.0, -0.36]
	for side in [1.0, -1.0]:
		for i in 3:
			var id := "leg_%s%d" % ["l" if side > 0 else "r", i + 1]
			var pivot := Vector3(xs[i], -0.18, side * 0.4)
			var p := _new_part(id, "LEG SERVO " + ("L" if side > 0 else "R") + str(i + 1),
				pivot, Vector3(xs[i] * 0.2, -0.85, side * 1.0))
			p.is_leg = true
			p.leg_phase = float(i) * 0.75 + (0.0 if side > 0 else 1.1)
			var hip := Vector3.ZERO
			var knee := Vector3(0.03, -0.3, side * 0.36)
			var ankle := Vector3(0.2, -0.56, side * 0.6)
			var toe := Vector3(0.36, -0.74, side * 0.72)
			_segment(p, hip, knee, 0.042, mat_black)
			_segment(p, knee, ankle, 0.035, mat_black)
			_segment(p, ankle, toe, 0.028, mat_black)
			_add_mesh(p, _sphere(0.08, 12), hip, Vector3.ZERO, Vector3.ONE, mat_brass)
			_add_mesh(p, _sphere(0.068, 12), knee, Vector3.ZERO, Vector3.ONE, mat_black)
			_add_mesh(p, _sphere(0.038, 10), knee, Vector3.ZERO, Vector3.ONE, mat_red)
			_add_mesh(p, _sphere(0.056, 12), ankle, Vector3.ZERO, Vector3.ONE, mat_black)
			_add_mesh(p, _sphere(0.036, 10), toe, Vector3.ZERO, Vector3.ONE, mat_red)
			p.label_local = Vector3(0.15, -0.72, side * 0.52)


# ── wing texture ────────────────────────────────────────────────────────────

func _make_wing_texture() -> ImageTexture:
	var w := 256
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	# RGB stays cream even where alpha is 0 — mipmaps must not average toward black.
	img.fill(Color(0.97, 0.95, 0.87, 0.0))
	for y in range(8, h - 6):
		var t := float(h - 8 - y) / float(h - 16)
		var width := sin(PI * pow(t, 0.75)) * 104.0 * (1.0 - 0.18 * t) + 3.0
		var cx := 128.0 + sin(t * 3.2) * 10.0 - t * 12.0
		var x0 := int(cx - width)
		var x1 := int(cx + width)
		for x in range(x0, x1):
			if x < 1 or x >= w - 1:
				continue
			var edge := absf(float(x) - cx) / maxf(width, 1.0)
			var a := 0.62
			if edge > 0.9:
				a = 0.9
			img.set_pixel(x, y, Color(0.97, 0.95, 0.87, a))
		# center vein
		img.set_pixel(int(cx), y, Color(0.12, 0.11, 0.09, 0.9))
		if y % 20 == 0:
			var dir := 1.0 if (y / 20) % 2 == 0 else -1.0
			var reach := int(width * 0.82)
			for k in range(1, reach):
				var xx := int(cx + dir * float(k))
				if xx > 1 and xx < w - 1:
					img.set_pixel(xx, y + int(float(k) * 0.28),
						Color(0.12, 0.11, 0.09, 0.62))
	# leading edge
	for y in range(8, h - 6):
		var t := float(h - 8 - y) / float(h - 16)
		var width := sin(PI * pow(t, 0.75)) * 104.0 * (1.0 - 0.18 * t) + 3.0
		var cx := 128.0 + sin(t * 3.2) * 10.0 - t * 12.0
		var lx := int(cx - width)
		if lx > 1 and lx < w - 1:
			img.set_pixel(lx, y, Color(0.12, 0.11, 0.09, 0.86))
	return ImageTexture.create_from_image(img)


# ── animation / interaction ─────────────────────────────────────────────────

func animate(solver: RefCounted, explode_t: float) -> void:
	if root == null:
		return
	_rise = lerpf(_rise, 0.46 if solver.state == "DEPARTING" else 0.0, 0.05)
	root.position = Vector3(0, 1.6 + solver.bob() + _rise, 0)
	root.rotation = Vector3(
		deg_to_rad(solver.roll_deg()) * 0.55,
		solver.yaw_drift(),
		-deg_to_rad(solver.pitch_deg()) * 0.6)

	var active := _active_for_state(solver.state)
	var all := active.has("*")
	for i in parts.size():
		var p: Part = parts[i]
		var amount := 0.0
		if all or active.has(p.id):
			var delay := float(i % 5) * 0.035
			amount = smoothstep(delay, 1.0, explode_t)
		p.node.position = p.home + p.explode_dir * amount

		if p.is_wing:
			var rest := deg_to_rad(14.0)
			p.node.rotation.x = float(p.side) * (rest + solver.wing_angle(p.wing_index))
			for j in p.ghost_pivots.size():
				var gp: Node3D = p.ghost_pivots[j]
				var off := -0.22 if j == 0 else 0.22
				gp.rotation.x = float(p.side) * (rest + solver.wing_angle_at(p.wing_index, off))
				gp.visible = app.motion_blur and solver.beat_hz() > 0.01
		elif p.is_leg:
			p.node.rotation.z = sin(solver.t * 1.6 + p.leg_phase) * deg_to_rad(2.2)


func _active_for_state(state: String) -> Array:
	match state:
		"TEARDOWN", "REASSEMBLY":
			return ["*"]
		"WING OFF":
			return ["wing_lf", "wing_lr", "wing_rf", "wing_rr"]
		"ABDOMEN OPEN":
			return ["abdomen_a", "abdomen_b", "tail", "clear"]
		"THORAX OPEN":
			return ["thorax", "clear"]
		_:
			return []


func get_part(id: String) -> Part:
	for p in parts:
		if p.id == id:
			return p
	return null


func part_label(id: String) -> String:
	var p := get_part(id)
	return p.label if p != null else ""


func set_highlight(id: String) -> void:
	clear_highlight()
	if id.is_empty():
		return
	var p := get_part(id)
	if p == null:
		return
	_highlight_id = id
	for m in p.meshes:
		m.material_overlay = mat_highlight


func clear_highlight() -> void:
	if _highlight_id.is_empty():
		return
	var p := get_part(_highlight_id)
	if p != null:
		for m in p.meshes:
			m.material_overlay = null
	_highlight_id = ""


func set_isolate(id: String) -> void:
	for p in parts:
		p.visible = id.is_empty() or p.id == id
		p.node.visible = p.visible


func clear_isolate() -> void:
	set_isolate("")


func part_visible(id: String) -> bool:
	var p := get_part(id)
	return p != null and p.visible


func part_world_label(id: String) -> Vector3:
	var p := get_part(id)
	return p.label_point() if p != null else Vector3.ZERO
