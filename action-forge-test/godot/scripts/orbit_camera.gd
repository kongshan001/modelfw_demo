extends Camera3D
class_name OrbitCamera

## Simple orbit camera for the Action Forge preview.
## Mouse drag orbits, wheel zooms; presets 1-4, C toggles auto-orbit.

var target := Vector3(0.0, 0.95, 0.0)
var yaw := 18.0
var pitch := -6.0
var distance := 3.8
var auto_orbit := true
var auto_speed := 7.0  # degrees per second
var dragging := false

func _ready() -> void:
	current = true
	_apply()

func _process(delta: float) -> void:
	if auto_orbit and not dragging:
		yaw += auto_speed * delta
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(1.2, distance * 0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(12.0, distance * 1.1)
	elif event is InputEventMouseMotion and dragging:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.25
		pitch = clampf(pitch - mm.relative.y * 0.2, -75.0, 25.0)

func preset(n: int) -> void:
	match n:
		1:
			target = Vector3(0.0, 0.95, 0.0); yaw = 0.0; pitch = -4.0; distance = 3.6
		2:
			target = Vector3(0.0, 0.95, 0.0); yaw = 28.0; pitch = -8.0; distance = 4.0
		3:
			target = Vector3(0.0, 0.95, 0.0); yaw = 90.0; pitch = -6.0; distance = 3.8
		4:
			target = Vector3(-1.15, 1.0, 0.0); yaw = -12.0; pitch = -4.0; distance = 2.0
		5:
			target = Vector3(1.15, 1.0, 0.0); yaw = 12.0; pitch = -4.0; distance = 2.0
		6:
			target = Vector3(0.0, 0.55, 0.0); yaw = 12.0; pitch = -12.0; distance = 2.2
	_apply()

func _apply() -> void:
	var yr := deg_to_rad(yaw)
	var pr := deg_to_rad(pitch)
	var offset := Vector3(sin(yr) * cos(pr), sin(pr), cos(yr) * cos(pr)) * distance
	look_at_from_position(target + offset, target, Vector3.UP)
