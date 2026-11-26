extends RefCounted

## Clean-room demo solutions used by the smoke test and capture tools.
## They are ordinary rope control points — the same API the mouse uses.

const LOOP_STEP := 20.0


static func for_level(level: Dictionary) -> Array[Vector3]:
	match String(level.get("id", "")):
		"first_knot":
			return level_one(level)
		"double_loop":
			return level_two(level)
	return []


static func level_one(level: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var pillars := KnotLevel.normalize_pillars(level)
	var qing: Dictionary = _find(pillars, "qing")
	var start := KnotLevel.start_point(level)
	var goal := KnotLevel.goal_point(level)
	out.append(Vector3(start.x, 0.12, start.z))
	_loop(out, qing["center"], float(qing["radius"]) + 0.14, 0.55, 140.0)
	out.append(_around(qing["center"], float(qing["radius"]) + 0.95, deg_to_rad(140.0 + 400.0), 0.55))
	out.append(_around(qing["center"], float(qing["radius"]) + 1.05, deg_to_rad(78.0), 0.50))
	out.append(_around(qing["center"], float(qing["radius"]) + 1.05, deg_to_rad(6.0), 0.34))
	out.append(Vector3(goal.x, 0.09, goal.z))
	return out


static func level_two(level: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var pillars := KnotLevel.normalize_pillars(level)
	var qing: Dictionary = _find(pillars, "qing")
	var coral: Dictionary = _find(pillars, "coral")
	var start := KnotLevel.start_point(level)
	var goal := KnotLevel.goal_point(level)
	out.append(Vector3(start.x, 0.12, start.z))
	# Left loop.
	_loop(out, qing["center"], float(qing["radius"]) + 0.14, 0.55, 130.0)
	out.append(_around(qing["center"], float(qing["radius"]) + 0.95, deg_to_rad(130.0 + 400.0), 0.55))
	# Cross under the later high strand.
	out.append(Vector3(0.6, 0.55, 1.0))
	out.append(Vector3(-0.6, 0.55, 0.2))
	# Right loop.
	_loop(out, coral["center"], float(coral["radius"]) + 0.14, 0.55, 130.0)
	out.append(_around(coral["center"], float(coral["radius"]) + 0.95, deg_to_rad(130.0 + 400.0), 0.55))
	# High crossing strand: passes above the low strand at (0, 0.6).
	out.append(Vector3(-0.6, 0.90, 1.0))
	out.append(Vector3(0.6, 0.90, 0.2))
	out.append(Vector3(goal.x, 0.09, goal.z))
	return out


static func _find(pillars: Array[Dictionary], id: String) -> Dictionary:
	for p in pillars:
		if p["id"] == id:
			return p
	return pillars[0]


static func _loop(out: Array[Vector3], center: Vector2, radius: float, y: float, start_deg: float) -> void:
	# Slightly more than one turn so dense mouse-style sampling still clears
	# the 360° requirement after smoothing.
	_append_arc(out, center, radius, y, start_deg, 400.0)


static func _append_arc(out: Array[Vector3], center: Vector2, radius: float, y: float, start_deg: float, sweep_deg: float) -> void:
	var steps := int(ceil(sweep_deg / LOOP_STEP))
	for i in range(0, steps + 1):
		var a := deg_to_rad(start_deg + LOOP_STEP * i)
		out.append(_around(center, radius, a, y))


static func _around(center: Vector2, radius: float, angle_rad: float, y: float) -> Vector3:
	return Vector3(center.x + cos(angle_rad) * radius, y, center.y + sin(angle_rad) * radius)
