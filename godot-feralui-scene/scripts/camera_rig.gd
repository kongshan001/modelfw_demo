extends Node3D
## 缓慢环绕相机：默认 3/4 俯视，自动环绕；左键拖拽/右摇杆环绕，滚轮缩放，空格暂停环绕。
## 相机只读场景，不与交互物发生物理碰撞（浮岛为静态展示）。

const DEFAULT_YAW := 22.0
const DEFAULT_PITCH := 35.5
const DEFAULT_DISTANCE := 21.5
const DEFAULT_FOCUS := Vector3(0.0, 2.15, 0.30)
const MIN_PITCH := 10.0
const MAX_PITCH := 67.0
const MIN_DISTANCE := 14.0
const MAX_DISTANCE := 39.0
const AUTO_ORBIT_SPEED := 0.85
const DRAG_YAW := 0.17
const DRAG_PITCH := 0.12

var camera: Camera3D
var yaw_deg := DEFAULT_YAW
var pitch_deg := DEFAULT_PITCH
var distance := DEFAULT_DISTANCE
var focus := DEFAULT_FOCUS
var auto_orbit := true
var dragging := false

var _target_yaw := DEFAULT_YAW
var _target_pitch := DEFAULT_PITCH
var _target_distance := DEFAULT_DISTANCE
var _target_focus := DEFAULT_FOCUS
var _last_mouse := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "OrbitCamera"
	camera.fov = 43.0
	camera.near = 0.08
	camera.far = 230.0
	camera.current = true
	add_child(camera)
	_apply_camera(true)


func _process(delta: float) -> void:
	_time += delta
	if auto_orbit and not dragging:
		_target_yaw += AUTO_ORBIT_SPEED * delta

	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if absf(stick.x) > 0.18:
		_target_yaw -= stick.x * 95.0 * delta
		auto_orbit = false
	if absf(stick.y) > 0.18:
		_target_pitch = clampf(_target_pitch + stick.y * 58.0 * delta, MIN_PITCH, MAX_PITCH)
		auto_orbit = false

	# 呼吸式构图：焦点高度以极小幅度起伏，避免完全机械的静止。
	var breathe := Vector3(0.0, sin(_time * 0.31) * 0.045, 0.0)
	var blend := 1.0 - exp(-delta * 4.8)
	yaw_deg = lerpf(yaw_deg, _target_yaw, blend)
	pitch_deg = lerpf(pitch_deg, _target_pitch, blend)
	distance = lerpf(distance, _target_distance, blend)
	focus = focus.lerp(_target_focus + breathe, blend)
	_apply_camera(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			dragging = mb.pressed
			_last_mouse = mb.position
			if mb.pressed:
				auto_orbit = false
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = clampf(_target_distance * 0.90, MIN_DISTANCE, MAX_DISTANCE)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = clampf(_target_distance * 1.10, MIN_DISTANCE, MAX_DISTANCE)
	elif event is InputEventMouseMotion and dragging:
		var mm := event as InputEventMouseMotion
		_target_yaw -= mm.relative.x * DRAG_YAW
		_target_pitch = clampf(_target_pitch + mm.relative.y * DRAG_PITCH, MIN_PITCH, MAX_PITCH)


func _apply_camera(snap: bool) -> void:
	if snap:
		yaw_deg = _target_yaw
		pitch_deg = _target_pitch
		distance = _target_distance
		focus = _target_focus
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)) * distance
	camera.global_position = focus + offset
	camera.look_at(focus, Vector3.UP)


func set_view(p_yaw: float, p_pitch: float, p_distance: float,
		p_focus: Vector3 = DEFAULT_FOCUS, p_auto := false) -> void:
	_target_yaw = p_yaw
	_target_pitch = clampf(p_pitch, MIN_PITCH, MAX_PITCH)
	_target_distance = clampf(p_distance, MIN_DISTANCE, MAX_DISTANCE)
	_target_focus = p_focus
	auto_orbit = p_auto
	yaw_deg = _target_yaw
	pitch_deg = _target_pitch
	distance = _target_distance
	focus = _target_focus
	_apply_camera(true)


func set_auto_orbit(value: bool) -> void:
	auto_orbit = value


func toggle_auto_orbit() -> void:
	auto_orbit = not auto_orbit


func zoom(delta: float) -> void:
	_target_distance = clampf(_target_distance * (1.0 + delta), MIN_DISTANCE, MAX_DISTANCE)


func reset() -> void:
	dragging = false
	auto_orbit = true
	_target_yaw = DEFAULT_YAW
	_target_pitch = DEFAULT_PITCH
	_target_distance = DEFAULT_DISTANCE
	_target_focus = DEFAULT_FOCUS
	yaw_deg = DEFAULT_YAW
	pitch_deg = DEFAULT_PITCH
	distance = DEFAULT_DISTANCE
	focus = DEFAULT_FOCUS
	_apply_camera(true)
