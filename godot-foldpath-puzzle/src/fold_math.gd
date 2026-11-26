class_name FoldMath
extends RefCounted

## Fixed orthographic isometric projection and pick maths.
## The camera looks from +X +Y +Z toward the focus, so a displacement along
## (1,1,1) leaves the screen position untouched: that is the whole fold trick.

const YAW := 45.0
const PITCH := -35.2643896827546
const VIEW := Vector2(1280.0, 720.0)
const BACK := Vector3(0.5773502691896258, 0.5773502691896258, 0.5773502691896258)


static func basis() -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(PITCH), deg_to_rad(YAW), 0.0), EULER_ORDER_YXZ)


static func project(point: Vector3, focus: Vector3, ortho_size: float, view: Vector2 = VIEW) -> Vector2:
	var b := basis()
	var rel := point - focus
	var ppw := view.y / ortho_size
	return Vector2(
		view.x * 0.5 + rel.dot(b.x) * ppw,
		view.y * 0.5 - rel.dot(b.y) * ppw
	)


static func project_depth(point: Vector3, focus: Vector3) -> float:
	return (point - focus).dot(BACK)


static func pixels_per_world(ortho_size: float, view: Vector2 = VIEW) -> float:
	return view.y / ortho_size


static func screen_ray(screen: Vector2, focus: Vector3, ortho_size: float, view: Vector2 = VIEW) -> Array:
	var b := basis()
	var ppw := view.y / ortho_size
	var x := (screen.x - view.x * 0.5) / ppw
	var y := (view.y * 0.5 - screen.y) / ppw
	var plane_point := focus + b.x * x + b.y * y
	var origin := plane_point + BACK * 24.0
	return [origin, -BACK]


static func rotate_y(v: Vector3, deg: float) -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(deg)) * v


static func snap_angle(deg: float, step: float) -> float:
	if step <= 0.0:
		return deg
	return snappedf(deg, step)


## Ray vs. oriented box whose yaw-only transform is pivot / yaw_deg.
## Returns the nearest hit distance, or -1.0 when there is no hit.
static func ray_yaw_box(origin: Vector3, dir: Vector3, pivot: Vector3, yaw_deg: float, box_center: Vector3, box_size: Vector3) -> float:
	var inv := Basis(Vector3.UP, deg_to_rad(-yaw_deg))
	var o := inv * (origin - pivot) - box_center
	var d := inv * dir
	var half := box_size * 0.5
	var tmin := -INF
	var tmax := INF
	for axis in 3:
		var oa := o[axis]
		var da := d[axis]
		var ha := half[axis]
		if absf(da) < 1e-7:
			if oa < -ha or oa > ha:
				return -1.0
			continue
		var t1 := (-ha - oa) / da
		var t2 := (ha - oa) / da
		if t1 > t2:
			var tmp := t1
			t1 = t2
			t2 = tmp
		tmin = maxf(tmin, t1)
		tmax = minf(tmax, t2)
		if tmin > tmax:
			return -1.0
	if tmax < 0.0:
		return -1.0
	return tmin if tmin >= 0.0 else tmax


static func vec3(data, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if data is Array and data.size() >= 3:
		return Vector3(float(data[0]), float(data[1]), float(data[2]))
	return fallback


static func clamp_zoom(value: float, level: Dictionary) -> float:
	var cam: Dictionary = level.get("camera", {})
	var lo := float(cam.get("zoom_min", 0.82))
	var hi := float(cam.get("zoom_max", 1.22))
	return clampf(value, lo, hi)
