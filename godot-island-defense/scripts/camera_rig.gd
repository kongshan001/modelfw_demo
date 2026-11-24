class_name MistCameraRig
extends Node3D
## 正交等距战术相机：平移 / 缩放 / 旋转 / 平滑聚焦。输入由 game.gd 转译。

var camera: Camera3D
var pivot := Vector3.ZERO
var target_pivot := Vector3.ZERO
var yaw_deg := -38.0
var target_yaw := -38.0
var pitch_deg := 50.0
var size := 44.0
var target_size := 44.0
var distance := 80.0
var bounds := 34.0
var _shake := 0.0
var _shake_time := 0.0
var orbit_speed := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.5
	camera.far = 260.0
	camera.current = true
	add_child(camera)
	_apply()


func configure(world_radius: float) -> void:
	bounds = maxf(22.0, world_radius * 0.62)
	_apply()


func focus_on(pos: Vector3, snap := false) -> void:
	target_pivot = Vector3(pos.x, maxf(0.0, pos.y), pos.z)
	if snap:
		pivot = target_pivot
		_apply()


func set_zoom(value: float, snap := false) -> void:
	target_size = clampf(value, 18.0, 62.0)
	if snap:
		size = target_size
		_apply()


func zoom_step(steps: float) -> void:
	target_size = clampf(target_size * pow(0.88, steps), 18.0, 62.0)


func rotate_by(deg: float) -> void:
	target_yaw += deg


func pan_input(delta: float, input_vector: Vector2) -> void:
	if input_vector.length_squared() < 0.001:
		return
	var basis := camera.global_transform.basis
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var speed := size * 0.62 * delta
	target_pivot += (right * input_vector.x + forward * input_vector.y) * speed
	_clamp_pivot()


func pan_pixels(relative: Vector2) -> void:
	var basis := camera.global_transform.basis
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var scale := size / 720.0
	target_pivot += (-right * relative.x - forward * relative.y) * scale
	_clamp_pivot()


func shake(amount := 0.18) -> void:
	_shake = maxf(_shake, amount)
	_shake_time = 0.32


func snap_view(pos: Vector3, zoom_value: float, yaw_value: float, pitch_value := 50.0) -> void:
	pivot = Vector3(pos.x, maxf(0.0, pos.y), pos.z)
	target_pivot = pivot
	size = zoom_value
	target_size = zoom_value
	yaw_deg = yaw_value
	target_yaw = yaw_value
	pitch_deg = pitch_value
	_apply()


func set_orbit(speed_deg: float) -> void:
	orbit_speed = speed_deg


func _process(delta: float) -> void:
	if orbit_speed != 0.0:
		target_yaw += orbit_speed * delta
	pivot = pivot.lerp(target_pivot, clampf(delta * 7.0, 0.0, 1.0))
	yaw_deg = lerp_angle(deg_to_rad(yaw_deg), deg_to_rad(target_yaw), clampf(delta * 6.0, 0.0, 1.0)) * 180.0 / PI
	size = lerpf(size, target_size, clampf(delta * 7.0, 0.0, 1.0))
	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		_shake = maxf(0.0, _shake - delta * 0.8)
	_apply()


func _apply() -> void:
	if camera == null:
		return
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var shake_offset := Vector3.ZERO
	if _shake > 0.0:
		shake_offset = Vector3(
			randf_range(-_shake, _shake),
			randf_range(-_shake * 0.4, _shake * 0.4),
			randf_range(-_shake, _shake)
		)
	camera.global_position = pivot + dir * distance + shake_offset
	camera.look_at(pivot + Vector3(0, 0.0, 0), Vector3.UP)
	camera.size = size


func _clamp_pivot() -> void:
	target_pivot.x = clampf(target_pivot.x, -bounds, bounds)
	target_pivot.z = clampf(target_pivot.z, -bounds, bounds)


func project_ground(screen_pos: Vector2, height_fn: Callable) -> Vector3:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var prev := origin
	var prev_delta := 999.0
	for i in range(1, 300):
		var t := float(i) * 1.2
		var p := origin + dir * t
		var h: float = height_fn.call(p.x, p.z)
		if p.y <= h:
			# 线性插值到与高度场交点
			var lo := 0.0
			var hi := 1.0
			for _j in range(8):
				var mid := (lo + hi) * 0.5
				var q := prev.lerp(p, mid)
				var hq: float = height_fn.call(q.x, q.z)
				if q.y <= hq:
					hi = mid
				else:
					lo = mid
			return prev.lerp(p, hi)
		prev = p
		prev_delta = p.y - h
	return Vector3(origin.x + dir.x * 200.0, 0.0, origin.z + dir.z * 200.0)
