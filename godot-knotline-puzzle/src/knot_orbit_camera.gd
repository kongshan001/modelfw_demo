class_name KnotOrbitCamera
extends Node3D

## Smoothed orbit camera for a tabletop diorama.
## Rigs the Camera3D at a distance and orbits around the focus point; WASD pans.

var camera: Camera3D
var target_focus := Vector3(0.0, 0.65, 0.0)
var target_yaw := -32.0
var target_pitch := 38.0
var target_distance := 9.5
var current_focus := Vector3(0.0, 0.65, 0.0)
var current_yaw := -32.0
var current_pitch := 38.0
var current_distance := 9.5

const FOCUS_LIMIT := 3.5
const PITCH_MIN := 12.0
const PITCH_MAX := 74.0
const DIST_MIN := 4.2
const DIST_MAX := 14.0
const SMOOTH := 10.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 46.0
	camera.near = 0.08
	camera.far = 70.0
	camera.position = Vector3(0.0, 0.0, current_distance)
	add_child(camera)
	_apply(true)


func setup(yaw: float, pitch: float, distance: float, focus: Vector3, snap: bool = true) -> void:
	target_yaw = yaw
	target_pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
	target_distance = clampf(distance, DIST_MIN, DIST_MAX)
	target_focus = _clamp_focus(focus)
	if snap:
		current_yaw = target_yaw
		current_pitch = target_pitch
		current_distance = target_distance
		current_focus = target_focus
	_apply(true)


func _process(delta: float) -> void:
	var t := 1.0 - exp(-SMOOTH * delta)
	current_yaw = lerpf(current_yaw, target_yaw, t)
	current_pitch = lerpf(current_pitch, target_pitch, t)
	current_distance = lerpf(current_distance, target_distance, t)
	current_focus = current_focus.lerp(target_focus, t)
	_apply(false)


func _apply(force: bool) -> void:
	if camera == null:
		return
	rotation_degrees = Vector3(-current_pitch, current_yaw, 0.0)
	position = current_focus
	camera.position = Vector3(0.0, 0.0, current_distance)
	camera.rotation = Vector3.ZERO
	if force:
		force_update_transform()


func orbit(delta_yaw: float, delta_pitch: float) -> void:
	target_yaw += delta_yaw
	target_pitch = clampf(target_pitch + delta_pitch, PITCH_MIN, PITCH_MAX)


func zoom(factor: float) -> void:
	target_distance = clampf(target_distance * factor, DIST_MIN, DIST_MAX)


func pan(meters_x: float, meters_z: float) -> void:
	var yaw_rad := deg_to_rad(target_yaw)
	var right := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad))
	var forward := Vector3(-sin(yaw_rad), 0.0, -cos(yaw_rad))
	target_focus = _clamp_focus(target_focus + right * meters_x + forward * meters_z)


func _clamp_focus(f: Vector3) -> Vector3:
	var flat := Vector2(f.x, f.z)
	if flat.length() > FOCUS_LIMIT:
		flat = flat.normalized() * FOCUS_LIMIT
	return Vector3(flat.x, clampf(f.y, 0.25, 1.8), flat.y)


func screen_position(world: Vector3) -> Vector2:
	return camera.unproject_position(world)


func is_behind(world: Vector3) -> bool:
	return camera.is_position_behind(world)


func camera_forward() -> Vector3:
	return -camera.global_transform.basis.z


func ray_origin(screen: Vector2) -> Vector3:
	return camera.project_ray_origin(screen)


func ray_normal(screen: Vector2) -> Vector3:
	return camera.project_ray_normal(screen)


func meters_per_pixel() -> float:
	var vp := camera.get_viewport().get_visible_rect().size.y
	if vp <= 1.0:
		return 0.02
	return 2.0 * current_distance * tan(deg_to_rad(camera.fov) * 0.5) / vp
