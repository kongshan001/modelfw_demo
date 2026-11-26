class_name OrbitRig
extends Camera3D

# 轨道相机：右键拖拽旋转、滚轮缩放、自动环绕（参考视频的缓慢绕岛运动）。
# 屏幕射线解析求交 y=0 平面，用于鼠标涟漪/落石。

signal orbit_changed

var target := Vector3(0.0, 1.6, 0.0)
var yaw_deg := 90.0
var pitch_deg := 58.0
var distance := 108.0
var min_distance := 26.0
var max_distance := 220.0
var min_pitch := 12.0
var max_pitch := 86.0
var auto_orbit := true
var auto_speed := 0.9        # 度/秒，参考视频约 30s 转 30°
var field: IslandField

var _dragging := false
var _last_mouse := Vector2.ZERO


func _ready() -> void:
	fov = 36.0
	near = 0.5
	far = 2200.0
	_update_transform()


func setup(p_field: IslandField) -> void:
	field = p_field
	_update_transform()


func set_orbit(p_yaw: float, p_pitch: float, p_distance: float) -> void:
	yaw_deg = p_yaw
	pitch_deg = clampf(p_pitch, min_pitch, max_pitch)
	distance = clampf(p_distance, min_distance, max_distance)
	_update_transform()
	orbit_changed.emit()


func set_target_height(y: float) -> void:
	target.y = y
	_update_transform()


func set_target_xz(x: float, z: float, y := 1.2) -> void:
	target = Vector3(x, y, z)
	_update_transform()
	orbit_changed.emit()


func _update_transform() -> void:
	var p := deg_to_rad(pitch_deg)
	var y := deg_to_rad(yaw_deg)
	var dir := Vector3(cos(p) * cos(y), sin(p), cos(p) * sin(y))
	global_position = target + dir * distance
	look_at(target, Vector3.UP)


func tick(delta: float) -> void:
	if auto_orbit:
		yaw_deg = fmod(yaw_deg + auto_speed * delta, 360.0)
		_update_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
			_last_mouse = mb.position
			if mb.pressed:
				auto_orbit = false
				orbit_changed.emit()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance * 0.92, min_distance, max_distance)
			_update_transform()
			orbit_changed.emit()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance * 1.08, min_distance, max_distance)
			_update_transform()
			orbit_changed.emit()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var d := mm.position - _last_mouse
		_last_mouse = mm.position
		yaw_deg = fmod(yaw_deg - d.x * 0.22, 360.0)
		pitch_deg = clampf(pitch_deg + d.y * 0.18, min_pitch, max_pitch)
		_update_transform()


func screen_to_water(screen_pos: Vector2, require_depth := true) -> Dictionary:
	var origin := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return {"valid": false, "pos": Vector2.ZERO, "point": Vector3.ZERO}
	var t := -origin.y / dir.y
	if t <= 0.0:
		return {"valid": false, "pos": Vector2.ZERO, "point": Vector3.ZERO}
	var hit := origin + dir * t
	if hit.length() > StylizedOcean.WATER_RADIUS:
		return {"valid": false, "pos": Vector2.ZERO, "point": hit}
	var xz := Vector2(hit.x, hit.z)
	var depth := 99.0
	if field != null:
		depth = field.water_depth_at(xz.x, xz.y)
	if require_depth and depth < 0.10:
		return {"valid": false, "pos": xz, "point": hit, "depth": depth}
	return {"valid": true, "pos": xz, "point": hit, "depth": depth}


func get_yaw_deg() -> float:
	return yaw_deg
