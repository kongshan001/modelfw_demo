extends Node3D

# Bootstrap for the Mellis HB-7 field simulator.
# Everything is procedural: meshes, materials, wing texture and HUD.

const SURFACE_SHADER := preload("res://shaders/mech_surface.gdshader")
const GRID_SHADER := preload("res://shaders/grid_ground.gdshader")
const BEE := preload("res://src/mech_model.gd")
const SOLVER := preload("res://src/mech_solver.gd")
const HUD := preload("res://src/mech_hud.gd")
const LABELS := preload("res://src/labels_overlay.gd")

const CAM_TARGET := Vector3(0.0, 1.45, 0.0)

var solver: RefCounted
var model: Node3D
var hud: CanvasLayer
var labels: Control
var camera: Camera3D

var state := "HOVER"
var auto_tour := true
var turntable := true
var labels_on := true
var motion_blur := true
var selected_id := ""
var isolated := false
var paused := false

var explode_t := 0.0
var explode_target := 0.0

var yaw := deg_to_rad(32.0)
var pitch := deg_to_rad(8.0)
var distance := 6.8
var cam_target := CAM_TARGET
var cam_distance := 6.8
var _dragging := false
var _drag_pixels := 0.0
var _idle := 0.0
var _tour_clock := 0.0
var _tour_index := 0
var _tour_part_clock := 0.0
var _tour_part_index := 0
var _last_state := ""

const TOUR := [
	"HOVER", "BANKING", "WING OFF", "ABDOMEN OPEN",
	"THORAX OPEN", "TEARDOWN", "REASSEMBLY", "DEPARTING",
]
const TOUR_PARTS := [
	"optics", "thorax", "wing_lf", "leg_l3",
	"abdomen_a", "tail", "clear",
]


func _ready() -> void:
	solver = SOLVER.new()
	_build_set()
	model = BEE.new()
	add_child(model)
	model.build(self)
	hud = HUD.new()
	hud.app = self
	add_child(hud)
	labels = LABELS.new()
	labels.app = self
	add_child(labels)
	set_state("HOVER", true)
	_refresh_camera()
	hud.update_view()


func _build_set() -> void:
	camera = Camera3D.new()
	camera.fov = 36.0
	camera.near = 0.1
	camera.far = 60.0
	add_child(camera)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(18.0, 18.0)
	ground.mesh = plane
	var gm := ShaderMaterial.new()
	gm.shader = GRID_SHADER
	ground.material_override = gm
	ground.position = Vector3(0, 0, 0)
	add_child(ground)

	# soft contact shadow under the bee
	var shadow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(4.6, 3.4)
	shadow.mesh = quad
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1, 1, 1, 1)
	sm.albedo_texture = _soft_shadow_texture()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	shadow.material_override = sm
	shadow.rotation = Vector3(-PI * 0.5, 0, 0)
	shadow.position = Vector3(0, 0.012, 0)
	add_child(shadow)


func _soft_shadow_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in size:
		for x in size:
			var d := Vector2(float(x) - 63.5, float(y) - 63.5).length() / 63.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * 0.32
			img.set_pixel(x, y, Color(0.06, 0.05, 0.04, a))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	solver.state = state
	solver.paused = paused
	solver.step(delta)

	if turntable:
		yaw += delta * 0.075
	if auto_tour:
		_tour_clock += delta
		if _tour_clock > 5.5:
			_tour_clock = 0.0
			_tour_index = (_tour_index + 1) % TOUR.size()
			set_state(TOUR[_tour_index], false)
		_tour_part_clock += delta
		if _tour_part_clock > 2.2:
			_tour_part_clock = 0.0
			_tour_part_index = (_tour_part_index + 1) % TOUR_PARTS.size()
			selected_id = TOUR_PARTS[_tour_part_index]
			isolated = false
			model.clear_isolate()
			model.set_highlight(selected_id)
	else:
		_idle += delta
		if _idle > 15.0:
			auto_tour = true
			_idle = 0.0

	var target := _explode_target_for(state)
	explode_target = target
	explode_t = move_toward(explode_t, explode_target, delta * 0.85)

	model.animate(solver, explode_t)
	if isolated and not selected_id.is_empty():
		var part = model.get_part(selected_id)
		if part != null:
			cam_target = cam_target.lerp(part.label_point(), minf(delta * 4.0, 1.0))
	else:
		cam_target = cam_target.lerp(CAM_TARGET, minf(delta * 2.2, 1.0))
	var want_dist := distance + explode_t * 2.6
	if isolated and not selected_id.is_empty():
		want_dist = 3.9
	cam_distance = lerpf(cam_distance, want_dist, minf(delta * 3.5, 1.0))
	_refresh_camera()
	if hud:
		hud.update_view()
	if labels:
		labels.queue_redraw()


func _explode_target_for(s: String) -> float:
	match s:
		"TEARDOWN":
			return 1.0
		"REASSEMBLY", "HOVER", "BANKING", "DEPARTING":
			return 0.0
		"WING OFF", "ABDOMEN OPEN", "THORAX OPEN":
			return 0.55
		_:
			return 0.0


func set_state(next: String, manual := true) -> void:
	state = next
	if solver:
		solver.state = next
	explode_target = _explode_target_for(next)
	if manual:
		_note("MODE: " + next)
		_take_over()
	_tour_index = TOUR.find(next) if TOUR.has(next) else 0


func _take_over() -> void:
	auto_tour = false
	_idle = 0.0


func _note(text: String) -> void:
	if hud:
		hud.push_log(text)


func _refresh_camera() -> void:
	var dist := cam_distance
	var pos := cam_target + Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw)) * dist
	camera.position = pos
	camera.look_at(cam_target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_pixels = 0.0
				_take_over()
			else:
				if _dragging and _drag_pixels < 5.0:
					_pick_at(event.position)
				_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = clamp(distance - 0.35, 3.2, 10.5)
			_take_over()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = clamp(distance + 0.35, 3.2, 10.5)
			_take_over()
	elif event is InputEventMouseMotion and _dragging:
		_drag_pixels += event.relative.length()
		yaw -= event.relative.x * 0.006
		pitch = clamp(pitch + event.relative.y * 0.005, deg_to_rad(-55.0), deg_to_rad(28.0))
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_H: set_state("HOVER")
			KEY_B: set_state("BANKING")
			KEY_E: set_state("TEARDOWN")
			KEY_R: set_state("REASSEMBLY")
			KEY_I: toggle_isolate()
			KEY_L: labels_on = not labels_on
			KEY_T: turntable = not turntable
			KEY_SPACE:
				paused = not paused
				_note("PAUSED" if paused else "RUNNING")
			KEY_ESCAPE:
				selected_id = ""
				isolated = false
				model.clear_highlight()


func _pick_at(pos: Vector2) -> void:
	var best := ""
	var best_d := 70.0
	for part in model.parts:
		if not part.visible:
			continue
		var p := camera.unproject_position(part.label_point())
		if camera.is_position_behind(part.label_point()):
			continue
		var d := p.distance_to(pos)
		if d < best_d:
			best_d = d
			best = part.id
	if best.is_empty():
		selected_id = ""
		model.clear_highlight()
	else:
		select_part(best)


func select_part(id: String) -> void:
	selected_id = id
	isolated = false
	model.clear_isolate()
	model.set_highlight(id)
	_note("PART: " + model.part_label(id))
	_take_over()


func toggle_isolate() -> void:
	if selected_id.is_empty():
		return
	isolated = not isolated
	model.set_isolate(selected_id if isolated else "")
	_note("ISOLATE " + (selected_id if isolated else "OFF"))
	_take_over()


func focus_assembly(id: String) -> void:
	select_part(id)
	isolated = true
	model.set_isolate(id)


func is_part_visible(id: String) -> bool:
	return model.part_visible(id)


func visible_label_parts() -> Array:
	if not labels_on:
		return []
	var out: Array = []
	if not selected_id.is_empty():
		out.append(selected_id)
	for id in ["optics", "thorax", "abdomen_a", "tail", "wing_lf", "leg_l3", "clear"]:
		if id != selected_id and not out.has(id):
			out.append(id)
	return out
