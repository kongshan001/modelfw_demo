extends Camera3D

# 绕木筏的轨道相机。输入由 main.gd 转发（因为 3D 画面在 SubViewport 里），
# 这里只负责参数、拖拽/滚轮状态和每帧位姿。

const MIN_PITCH := 2.0
const MAX_PITCH := 64.0
const MIN_DISTANCE := 4.5
const MAX_DISTANCE := 26.0
const DEFAULT_YAW := 32.0
const DEFAULT_PITCH := 12.0
const DEFAULT_DISTANCE := 8.8

var target := Vector3(0.0, 0.95, 0.0)
var yaw_deg := DEFAULT_YAW
var pitch_deg := DEFAULT_PITCH
var distance := DEFAULT_DISTANCE
var auto_orbit := true
var auto_speed := 1.3

var _dragging := false
var _idle_time := 10.0


func _ready() -> void:
	fov = 46.0
	near = 0.05
	far = 700.0
	cull_mask = 0x7FFFFFFF
	update_camera(0.0)


func setup(target_point: Vector3, yaw: float, pitch: float, dist: float) -> void:
	target = target_point
	yaw_deg = yaw
	pitch_deg = clampf(pitch, MIN_PITCH, MAX_PITCH)
	distance = clampf(dist, MIN_DISTANCE, MAX_DISTANCE)
	update_camera(0.0)


func reset() -> void:
	yaw_deg = DEFAULT_YAW
	pitch_deg = DEFAULT_PITCH
	distance = DEFAULT_DISTANCE
	_dragging = false
	update_camera(0.0)


func set_view(yaw: float, pitch: float, dist: float) -> void:
	yaw_deg = yaw
	pitch_deg = clampf(pitch, MIN_PITCH, MAX_PITCH)
	distance = clampf(dist, MIN_DISTANCE, MAX_DISTANCE)
	update_camera(0.0)


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_idle_time = 0.0
			return true
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance * 0.90, MIN_DISTANCE, MAX_DISTANCE)
			_idle_time = 0.0
			return true
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance * 1.10, MIN_DISTANCE, MAX_DISTANCE)
			_idle_time = 0.0
			return true
	elif event is InputEventMouseMotion and _dragging:
		yaw_deg -= event.relative.x * 0.28
		pitch_deg = clampf(pitch_deg + event.relative.y * 0.22, MIN_PITCH, MAX_PITCH)
		_idle_time = 0.0
		return true
	return false


func update_camera(delta: float) -> void:
	_idle_time += delta
	if auto_orbit and not _dragging and _idle_time > 5.0:
		yaw_deg += auto_speed * delta

	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)) * distance
	global_position = target + offset
	look_at(target + Vector3(0.0, 0.12, 0.0), Vector3.UP)
