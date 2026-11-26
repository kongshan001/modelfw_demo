class_name FoldPlayer
extends Node3D

## "小折狐" — an original folded-paper fox made of low-poly primitives.
## It walks the path, folds flat across screen-aligned seams and celebrates.

const BODY_COLOR := "cream"
const ACCENT := "coral"
const DARK := "pine"

var visual: Node3D
var body_root: Node3D
var legs: Array[Node3D] = []
var tail: Node3D
var scarf_tail: Node3D
var ear_l: Node3D
var ear_r: Node3D
var shadow_blob: MeshInstance3D

var _time := 0.0
var _walk_phase := 0.0
var _yaw := 0.0
var _target_yaw := 0.0
var _mode := "idle"
var _fold_t := 0.0
var _fold_base_yaw := 0.0


func _ready() -> void:
	_build()


func _mesh(parent: Node3D, mesh: Mesh, color_key: String, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = FoldPalette.mat(color_key)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, color_key: String, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, color_key, pos, rot)


func _cone(radius: float, height: float, sides := 4) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = 0.006
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


func _build() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	body_root = Node3D.new()
	body_root.name = "BodyRoot"
	visual.add_child(body_root)

	# Torso: a folded card with a narrower chest.
	_box(body_root, Vector3(0.28, 0.30, 0.34), Vector3(0, 0.34, 0.02), BODY_COLOR)
	_box(body_root, Vector3(0.235, 0.12, 0.30), Vector3(0, 0.51, 0.0), "stone_2")
	_box(body_root, Vector3(0.30, 0.035, 0.32), Vector3(0, 0.425, 0.01), "brass")

	# Head with a folded snout.
	_box(body_root, Vector3(0.29, 0.24, 0.26), Vector3(0, 0.63, -0.02), BODY_COLOR)
	_box(body_root, Vector3(0.145, 0.105, 0.14), Vector3(0, 0.585, -0.17), "stone_2")
	_box(body_root, Vector3(0.07, 0.035, 0.035), Vector3(0, 0.61, -0.245), DARK)
	_box(body_root, Vector3(0.30, 0.05, 0.09), Vector3(0, 0.725, 0.015), "stone_2")

	# Ears: four-sided paper cones with coral inner folds.
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.095 * side, 0.755, -0.005)
		pivot.rotation = Vector3(0.08, 0.0, 0.22 * -side)
		body_root.add_child(pivot)
		_mesh(pivot, _cone(0.075, 0.21), BODY_COLOR, Vector3(0, 0.08, 0))
		_mesh(pivot, _cone(0.042, 0.13), ACCENT, Vector3(0, 0.055, -0.012))
		if side < 0.0:
			ear_l = pivot
		else:
			ear_r = pivot

	# Eyes: two dark stitches with a paper glint.
	var eye := SphereMesh.new()
	eye.radius = 0.021
	eye.height = 0.042
	eye.radial_segments = 6
	eye.rings = 3
	var shine := SphereMesh.new()
	shine.radius = 0.009
	shine.height = 0.018
	shine.radial_segments = 4
	shine.rings = 2
	for sx in [-1.0, 1.0]:
		_mesh(body_root, eye, DARK, Vector3(0.073 * sx, 0.665, -0.157), Vector3.ZERO, Vector3.ONE, false)
		_mesh(body_root, shine, "white", Vector3(0.078 * sx, 0.672, -0.174), Vector3.ZERO, Vector3.ONE, false)

	# Scarf and its trailing paper tail.
	_box(body_root, Vector3(0.31, 0.055, 0.30), Vector3(0, 0.525, -0.005), ACCENT)
	scarf_tail = Node3D.new()
	scarf_tail.position = Vector3(0.12, 0.51, 0.14)
	scarf_tail.rotation = Vector3(0.2, 0.3, 0.0)
	body_root.add_child(scarf_tail)
	_box(scarf_tail, Vector3(0.10, 0.025, 0.22), Vector3(0, 0, 0.09), ACCENT, Vector3.ZERO)
	_box(scarf_tail, Vector3(0.075, 0.022, 0.16), Vector3(0.03, -0.005, 0.25), "mustard", Vector3(0, 0.2, 0.0))

	# Four folded legs on hip pivots.
	var leg_mesh := BoxMesh.new()
	leg_mesh.size = Vector3(0.06, 0.17, 0.075)
	for z in [-0.115, 0.115]:
		for x in [-0.088, 0.088]:
			var hip := Node3D.new()
			hip.position = Vector3(x, 0.19, z)
			body_root.add_child(hip)
			_mesh(hip, leg_mesh, DARK, Vector3(0, -0.075, 0))
			legs.append(hip)
	# A little brass tag.
	_box(body_root, Vector3(0.06, 0.06, 0.015), Vector3(0, 0.36, -0.185), "brass", Vector3(0, 0, 0.785))

	# Soft blob shadow so the fox reads as grounded without a shadow map.
	shadow_blob = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.50, 0.34)
	shadow_blob.mesh = plane
	shadow_blob.material_override = FoldPalette.soft_shadow(0.40)
	shadow_blob.position = Vector3(-0.08, 0.008, -0.05)
	shadow_blob.rotation.y = 0.5
	shadow_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow_blob)

	# Tail: two folded paper segments, coral tip.
	tail = Node3D.new()
	tail.position = Vector3(0, 0.36, 0.17)
	tail.rotation = Vector3(-0.45, 0.0, 0.0)
	body_root.add_child(tail)
	_box(tail, Vector3(0.09, 0.075, 0.20), Vector3(0, 0.01, 0.09), BODY_COLOR)
	_box(tail, Vector3(0.075, 0.075, 0.16), Vector3(0.015, 0.08, 0.23), ACCENT, Vector3(-0.55, 0, 0.0))
	_box(tail, Vector3(0.04, 0.06, 0.07), Vector3(0.02, 0.16, 0.30), "mustard", Vector3(-0.55, 0, 0.0))


func _process(delta: float) -> void:
	_time += delta
	if _mode == "fold":
		_apply_fold()
		return
	_walk_phase += delta * (10.5 if _mode == "walk" else 2.0)
	_yaw = lerp_angle(_yaw, _target_yaw, 1.0 - exp(-14.0 * delta))
	visual.rotation.y = _yaw
	visual.scale = visual.scale.lerp(Vector3.ONE, 0.35)
	var bob := 0.0
	var lean := 0.0
	var swing := 0.0
	match _mode:
		"walk":
			bob = absf(sin(_walk_phase)) * 0.035
			lean = sin(_walk_phase) * 0.055
			swing = sin(_walk_phase) * 0.55
		"celebrate":
			bob = absf(sin(_time * 7.0)) * 0.12
		_:
			bob = sin(_time * 2.1) * 0.012
	if shadow_blob != null:
		shadow_blob.visible = true
	body_root.position.y = bob
	body_root.rotation.z = lean
	body_root.rotation.x = -lean * 0.35
	_simple_legs(swing)
	if tail != null:
		tail.rotation.y = sin(_time * 1.6) * 0.28
		tail.rotation.x = -0.45 + sin(_time * 2.3) * 0.09
	if scarf_tail != null:
		scarf_tail.rotation.x = 0.2 + sin(_time * 2.7) * 0.12
		scarf_tail.rotation.z = sin(_time * 2.0) * 0.1
	if ear_l != null:
		ear_l.rotation.z = 0.22 + sin(_time * 1.7 + 1.0) * 0.03
	if ear_r != null:
		ear_r.rotation.z = -0.22 + sin(_time * 1.7) * 0.03


func _apply_fold() -> void:
	if shadow_blob != null:
		shadow_blob.visible = false
	var k := sin(clampf(_fold_t, 0.0, 1.0) * PI)
	visual.scale = Vector3(1.0 + 0.28 * k, 1.0 - 0.72 * k, 1.0 - 0.55 * k)
	visual.rotation.y = _fold_base_yaw + TAU * clampf(_fold_t, 0.0, 1.0)
	body_root.position.y = k * 0.22
	body_root.rotation = Vector3.ZERO
	_simple_legs(0.0)


func _simple_legs(swing: float) -> void:
	for i in legs.size():
		var phase := 1.0 if (i % 2 == 0) else -1.0
		if i == 1 or i == 2:
			phase = -phase
		legs[i].rotation.x = swing * phase


func idle(pos: Vector3, face: float) -> void:
	_mode = "idle"
	position = pos
	_target_yaw = face
	visual.scale = Vector3.ONE


func walk(pos: Vector3, dir: Vector3) -> void:
	_mode = "walk"
	position = pos
	if dir.length_squared() > 0.0001:
		_target_yaw = atan2(-dir.x, -dir.z)


func fold(pos: Vector3, base_yaw: float, t: float) -> void:
	_mode = "fold"
	position = pos
	_fold_t = t
	_fold_base_yaw = base_yaw
	_apply_fold()


func celebrate() -> void:
	_mode = "celebrate"
	visual.scale = Vector3.ONE
	body_root.position = Vector3.ZERO
	body_root.rotation = Vector3.ZERO
	_simple_legs(0.0)


func teleport(pos: Vector3, face: float) -> void:
	position = pos
	_yaw = face
	_target_yaw = face
	visual.rotation.y = face
	visual.scale = Vector3.ONE
	_mode = "idle"
	body_root.position = Vector3.ZERO
	body_root.rotation = Vector3.ZERO
	_simple_legs(0.0)


func face_yaw() -> float:
	return _target_yaw
