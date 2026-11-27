extends Camera3D

# 受限环视相机：默认在池面上方缓慢横移，右键拖拽环视、滚轮缩放。
# 左键由 main 用于把焦散亮区聚焦到池底点击处。

var target := Vector3(0.55, -0.25, 0.0)
var distance := 17.2
var yaw_deg := 4.0
var pitch_deg := 48.0
var auto_orbit := true
var auto_strength := 1.0

var _auto_time := 0.0
var _manual_yaw := 4.0
var _manual_pitch := 48.0
var _manual_distance := 17.2
var _dragging := false

const MIN_DISTANCE := 12.8
const MAX_DISTANCE := 17.2
const MIN_PITCH := 48.0
const MAX_PITCH := 60.0
const YAW_LIMIT := 12.0


func _ready() -> void:
	fov = 44.0
	near = 0.1
	far = 80.0
	current = true
	_apply()


func _process(delta: float) -> void:
	if auto_orbit:
		_auto_time += delta
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_manual_distance = clampf(_manual_distance - 0.8, MIN_DISTANCE, MAX_DISTANCE)
			distance = _manual_distance
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_manual_distance = clampf(_manual_distance + 0.8, MIN_DISTANCE, MAX_DISTANCE)
			distance = _manual_distance
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_manual_yaw = clampf(_manual_yaw - mm.relative.x * 0.16,
				-YAW_LIMIT, YAW_LIMIT)
		_manual_pitch = clampf(_manual_pitch + mm.relative.y * 0.12,
				MIN_PITCH, MAX_PITCH)
		yaw_deg = _manual_yaw
		pitch_deg = _manual_pitch


func _apply() -> void:
	var yaw := deg_to_rad(_manual_yaw)
	if auto_orbit:
		yaw += sin(_auto_time * 0.075) * deg_to_rad(3.2) * auto_strength
	# 自动环视叠加后也留在已验证的安全取景角内，避免露出河床边界。
	yaw = clampf(yaw, deg_to_rad(-YAW_LIMIT), deg_to_rad(YAW_LIMIT))
	var pitch := deg_to_rad(_manual_pitch)
	var horizontal := distance * cos(pitch)
	var pos := target + Vector3(sin(yaw) * horizontal,
			sin(pitch) * distance, cos(yaw) * horizontal)
	position = pos
	look_at(target, Vector3.UP)


func set_pose(new_target: Vector3, new_yaw: float, new_pitch: float,
		new_distance: float) -> void:
	target = new_target
	_manual_yaw = new_yaw
	_manual_pitch = clampf(new_pitch, MIN_PITCH, MAX_PITCH)
	_manual_distance = clampf(new_distance, MIN_DISTANCE, MAX_DISTANCE)
	yaw_deg = _manual_yaw
	pitch_deg = _manual_pitch
	distance = _manual_distance
	auto_orbit = false
	_apply()


func reset_pose() -> void:
	target = Vector3(0.55, -0.25, 0.0)
	_manual_yaw = 4.0
	_manual_pitch = 48.0
	_manual_distance = 17.2
	yaw_deg = _manual_yaw
	pitch_deg = _manual_pitch
	distance = _manual_distance
	auto_orbit = true
	_auto_time = 0.0
	_apply()


func screen_to_floor(screen_pos: Vector2) -> Variant:
	var from := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	return from + dir * t
