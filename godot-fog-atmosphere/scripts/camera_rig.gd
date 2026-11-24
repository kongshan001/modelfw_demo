extends Node3D
## 环绕相机：左键拖拽环绕、滚轮缩放、WASD 平移焦点、空格自动环绕。
## 默认是接近参考视频的高角度缓慢环绕；所有 demo_* 调用走 set_view()，不依赖真实输入。

const DEFAULT_YAW := 26.0
const DEFAULT_PITCH := 36.0
const DEFAULT_DISTANCE := 15.5
const DEFAULT_FOCUS := Vector3(0.0, 1.4, 0.0)
const MIN_PITCH := 8.0
const MAX_PITCH := 74.0
const MIN_DISTANCE := 6.5
const MAX_DISTANCE := 32.0
const FOLLOW_PITCH := 20.0
const FOLLOW_DISTANCE := 7.2
const FOLLOW_MIN_DISTANCE := 3.5
const FOLLOW_MAX_DISTANCE := 12.0
const FOLLOW_HEIGHT := 1.15
const PAN_RADIUS := 18.0
const AUTO_ORBIT_SPEED := 1.6

var camera: Camera3D
var yaw_deg := DEFAULT_YAW
var pitch_deg := DEFAULT_PITCH
var distance := DEFAULT_DISTANCE
var focus := DEFAULT_FOCUS
var auto_orbit := true
var follow_enabled := false
var follow_target: Node3D
var world_ref: Node3D

var _target_yaw := DEFAULT_YAW
var _target_pitch := DEFAULT_PITCH
var _target_distance := DEFAULT_DISTANCE
var _target_focus := DEFAULT_FOCUS
var _dragging := false
var _drag_last := Vector2.ZERO


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "OrbitCamera"
	camera.fov = 64.0
	camera.near = 0.1
	camera.far = 220.0
	add_child(camera)
	camera.current = true
	_apply_camera(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_drag_last = mb.position
			if mb.pressed:
				auto_orbit = false
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			var min_d := FOLLOW_MIN_DISTANCE if follow_enabled else MIN_DISTANCE
			var max_d := FOLLOW_MAX_DISTANCE if follow_enabled else MAX_DISTANCE
			_target_distance = clampf(_target_distance * 0.90, min_d, max_d)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var min_d := FOLLOW_MIN_DISTANCE if follow_enabled else MIN_DISTANCE
			var max_d := FOLLOW_MAX_DISTANCE if follow_enabled else MAX_DISTANCE
			_target_distance = clampf(_target_distance * 1.10, min_d, max_d)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_target_yaw -= mm.relative.x * 0.16
		_target_pitch = clampf(_target_pitch + mm.relative.y * 0.12, MIN_PITCH, MAX_PITCH)


func _process(delta: float) -> void:
	var pan := Vector3.ZERO
	if not follow_enabled:
		if Input.is_physical_key_pressed(KEY_W):
			pan.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			pan.z += 1.0
		if Input.is_physical_key_pressed(KEY_A):
			pan.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			pan.x += 1.0
	if pan != Vector3.ZERO:
		var yaw := deg_to_rad(_target_yaw)
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		_target_focus += (right * pan.x + forward * -pan.z) * delta * 7.0
		var flat := Vector2(_target_focus.x, _target_focus.z)
		if flat.length() > PAN_RADIUS:
			flat = flat.normalized() * PAN_RADIUS
			_target_focus.x = flat.x
			_target_focus.z = flat.y

	# 右摇杆环绕（鼠标拖拽在 _unhandled_input）
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if absf(stick.x) > 0.18:
		_target_yaw -= stick.x * 110.0 * delta
	if absf(stick.y) > 0.18:
		_target_pitch = clampf(_target_pitch + stick.y * 70.0 * delta, MIN_PITCH, MAX_PITCH)

	if follow_enabled and follow_target != null:
		_target_focus = follow_target.global_position + Vector3(0.0, FOLLOW_HEIGHT, 0.0)
		_target_distance = clampf(_target_distance, FOLLOW_MIN_DISTANCE, FOLLOW_MAX_DISTANCE)

	if auto_orbit and not _dragging:
		_target_yaw += AUTO_ORBIT_SPEED * delta

	var blend := 1.0 - exp(-delta * 7.0)
	yaw_deg = lerpf(yaw_deg, _target_yaw, blend)
	pitch_deg = lerpf(pitch_deg, _target_pitch, blend)
	distance = lerpf(distance, _target_distance, blend)
	focus = focus.lerp(_target_focus, blend)
	_apply_camera(false)


func _apply_camera(snap: bool) -> void:
	if camera == null:
		return
	if snap:
		yaw_deg = _target_yaw
		pitch_deg = _target_pitch
		distance = _target_distance
		focus = _target_focus
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	var cam_pos := focus + offset
	if follow_enabled and world_ref != null:
		cam_pos = _avoid_camera_obstacles(focus, cam_pos)
		# 第三人称相机不钻进地形
		var min_y: float = world_ref.terrain_height(cam_pos.x, cam_pos.z) + 0.55
		if cam_pos.y < min_y:
			cam_pos.y = min_y
	camera.global_position = cam_pos
	camera.look_at(focus, Vector3.UP)


func _avoid_camera_obstacles(focus_pos: Vector3, cam_pos: Vector3) -> Vector3:
	# 相机与树干/高石柱做 2D 圆碰撞：被挡时沿视线拉近，避免镜头穿进树干。
	if world_ref == null or world_ref.obstacle_circles.is_empty():
		return cam_pos
	var flat_focus := Vector2(focus_pos.x, focus_pos.z)
	var flat_cam := Vector2(cam_pos.x, cam_pos.z)
	var delta := flat_cam - flat_focus
	var base_distance := delta.length()
	if base_distance < 0.01:
		return cam_pos
	var dir := delta / base_distance
	var dist := base_distance
	while dist > 2.0:
		var p := flat_focus + dir * dist
		var blocked := false
		for obstacle in world_ref.obstacle_circles:
			if float(obstacle.get("height", 10.0)) + 0.3 < cam_pos.y:
				continue
			var op: Vector2 = obstacle["pos"]
			if p.distance_to(op) < float(obstacle["radius"]) + 0.45:
				blocked = true
				break
		if not blocked:
			break
		dist -= 0.35
	if dist >= base_distance - 0.001:
		return cam_pos
	return focus_pos + (cam_pos - focus_pos) * (dist / base_distance)


func set_view(p_yaw: float, p_pitch: float, p_distance: float, p_focus: Vector3 = DEFAULT_FOCUS, p_auto: bool = false) -> void:
	follow_enabled = false
	_target_yaw = p_yaw
	_target_pitch = clampf(p_pitch, MIN_PITCH, MAX_PITCH)
	_target_distance = clampf(p_distance, MIN_DISTANCE, MAX_DISTANCE)
	_target_focus = p_focus
	auto_orbit = p_auto
	yaw_deg = p_yaw
	pitch_deg = _target_pitch
	distance = _target_distance
	focus = p_focus
	_apply_camera(true)


func set_follow_target(node: Node3D) -> void:
	follow_target = node


func set_follow(enabled: bool, snap: bool = true) -> void:
	follow_enabled = enabled
	if enabled:
		_target_pitch = FOLLOW_PITCH
		_target_distance = FOLLOW_DISTANCE
		auto_orbit = false
		if follow_target != null:
			_target_focus = follow_target.global_position + Vector3(0.0, FOLLOW_HEIGHT, 0.0)
	else:
		_target_pitch = DEFAULT_PITCH
		_target_distance = DEFAULT_DISTANCE
		auto_orbit = true
	if snap:
		yaw_deg = _target_yaw
		pitch_deg = _target_pitch
		distance = _target_distance
		focus = _target_focus
		_apply_camera(true)


func set_follow_view(p_yaw: float, p_pitch: float, p_distance: float, p_auto: bool = false) -> void:
	follow_enabled = true
	_target_yaw = p_yaw
	_target_pitch = clampf(p_pitch, MIN_PITCH, MAX_PITCH)
	_target_distance = clampf(p_distance, FOLLOW_MIN_DISTANCE, FOLLOW_MAX_DISTANCE)
	if follow_target != null:
		_target_focus = follow_target.global_position + Vector3(0.0, FOLLOW_HEIGHT, 0.0)
	auto_orbit = p_auto
	yaw_deg = p_yaw
	pitch_deg = _target_pitch
	distance = _target_distance
	focus = _target_focus
	_apply_camera(true)


func pan_focus(offset: Vector3) -> void:
	_target_focus += offset
	var flat := Vector2(_target_focus.x, _target_focus.z)
	if flat.length() > PAN_RADIUS:
		flat = flat.normalized() * PAN_RADIUS
		_target_focus.x = flat.x
		_target_focus.z = flat.y


func reset() -> void:
	_dragging = false
	follow_enabled = false
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


func look_yaw() -> float:
	return yaw_deg
