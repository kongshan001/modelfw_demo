class_name FoldCamera
extends Camera3D

## Fixed isometric orthographic camera. Orbit is deliberately impossible:
## only a small zoom is exposed so the screen-space alignment stays readable.

const DISTANCE := 12.0
const BASE_ZOOM := 1.0

var focus := Vector3.ZERO
var base_size := 8.0
var zoom := 1.0


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	near = 0.05
	far = 120.0
	current = true
	_apply()


func configure(level: Dictionary) -> void:
	var cam: Dictionary = level.get("camera", {})
	focus = FoldMath.vec3(cam.get("focus", [0, 0, 0]))
	base_size = float(cam.get("size", 8.0))
	zoom = 1.0
	_apply()


func set_zoom(multiplier: float, level: Dictionary) -> void:
	zoom = FoldMath.clamp_zoom(multiplier, level)
	_apply()


func effective_size() -> float:
	return base_size * zoom


func _apply() -> void:
	size = effective_size()
	var b := FoldMath.basis()
	transform = Transform3D(b, focus + FoldMath.BACK * DISTANCE)


func screen_of(point: Vector3) -> Vector2:
	return FoldMath.project(point, focus, effective_size())


func depth_of(point: Vector3) -> float:
	return FoldMath.project_depth(point, focus)


func screen_ray(screen: Vector2) -> Array:
	return FoldMath.screen_ray(screen, focus, effective_size())


func project_box(center: Vector3, size_axes: Vector3, yaw_deg: float) -> Array:
	var out := []
	for ix in 2:
		for iy in 2:
			for iz in 2:
				var local := Vector3(
					(-0.5 + float(ix)) * size_axes.x,
					(-0.5 + float(iy)) * size_axes.y,
					(-0.5 + float(iz)) * size_axes.z
				)
				out.append(screen_of(center + FoldMath.rotate_y(local, yaw_deg)))
	return out
