class_name KnotLevel
extends RefCounted

## JSON level schema, normalization and win evaluation.
## Levels are data-only; the world and rope receive copies of these values.

const LEVEL_DIR := "res://levels"


static func load_all(dir_path: String = LEVEL_DIR) -> Array[Dictionary]:
	var levels: Array[Dictionary] = []
	var names := DirAccess.get_files_at(dir_path)
	names.sort()
	for n in names:
		if not n.ends_with(".json"):
			continue
		var path := dir_path + "/" + n
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			push_error("KnotLevel: cannot open " + path)
			continue
		var data = JSON.parse_string(f.get_as_text())
		if typeof(data) != TYPE_DICTIONARY:
			push_error("KnotLevel: JSON parse failed " + path)
			continue
		var err := validate(data)
		if err != "":
			push_error("KnotLevel: " + n + " — " + err)
			continue
		data["_file"] = n
		data["_path"] = path
		levels.append(data)
	return levels


static func validate(data: Dictionary) -> String:
	for key in ["id", "name", "start", "goal", "pillars"]:
		if not data.has(key):
			return "missing field " + key
	var start = data["start"]
	if not (start is Array) or start.size() < 2 or start.size() > 3:
		return "start must be [x,y,z]"
	var goal = data["goal"]
	if not (goal is Array) or goal.size() < 2 or goal.size() > 3:
		return "goal must be [x,y,z]"
	if not (data["pillars"] is Array) or data["pillars"].is_empty():
		return "pillars must be a non-empty array"
	for p in data["pillars"]:
		if not (p is Dictionary):
			return "pillar must be an object"
		for key in ["id", "name", "pos", "radius", "height"]:
			if not p.has(key):
				return "pillar missing " + key
		if not (p["pos"] is Array) or p["pos"].size() != 2:
			return "pillar.pos must be [x,z]"
		if float(p["radius"]) <= 0.02 or float(p["height"]) <= 0.1:
			return "pillar " + str(p["id"]) + " has bad size"
	if float(data.get("goal_radius", 0.6)) <= 0.05:
		return "goal_radius too small"
	if int(data.get("crossings_required", 0)) < 0:
		return "crossings_required must be >= 0"
	return ""


static func start_point(level: Dictionary) -> Vector3:
	var s = level["start"]
	if s.size() == 2:
		return Vector3(float(s[0]), 0.12, float(s[1]))
	return Vector3(float(s[0]), float(s[1]), float(s[2]))


static func goal_point(level: Dictionary) -> Vector3:
	var g = level["goal"]
	if g.size() == 2:
		return Vector3(float(g[0]), 0.06, float(g[1]))
	return Vector3(float(g[0]), float(g[1]), float(g[2]))


static func normalize_pillars(level: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in level["pillars"]:
		var cx := float(p["pos"][0])
		var cz := float(p["pos"][1])
		out.append({
			"id": String(p["id"]),
			"name": String(p.get("name", p["id"])),
			"center": Vector2(cx, cz),
			"pos": Vector2(cx, cz),
			"pos3": Vector3(cx, 0.0, cz),
			"radius": float(p["radius"]),
			"height": float(p["height"]),
			"turns": float(p.get("turns", 1.0)),
			"required": bool(p.get("required", true)),
			"color": _color(p.get("color", "#3E8E8A"), Color(0.24, 0.56, 0.54)),
			"top_color": _color(p.get("top_color", "#F2CC8F"), Color(0.95, 0.80, 0.56)),
		})
	return out


static func obstacles(level: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in normalize_pillars(level):
		out.append({
			"id": p["id"],
			"center": p["center"],
			"radius": p["radius"],
			"height": p["height"],
			"y0": 0.0,
			"y1": p["height"],
		})
	return out


## Builds the live objective checklist from rope metrics.
## The win requires every required check, including landing on the goal pad;
## optional pillars are reported but do not block.
static func evaluate(level: Dictionary, metrics: Dictionary, end_point: Vector3) -> Dictionary:
	var checks: Array[Dictionary] = []
	var win := true
	var pillars := normalize_pillars(level)
	var winding: Dictionary = metrics.get("winding", {})
	for p in pillars:
		var id: String = p["id"]
		var w: Dictionary = winding.get(id, {})
		var turns := float(w.get("turns", 0.0))
		var deg := absf(turns) * 360.0
		var need := float(p["turns"])
		var ok := absf(turns) >= need - 0.035
		var required: bool = p["required"]
		var shown: float = need * 360.0 if ok else minf(deg, need * 360.0)
		checks.append({
			"key": "wrap:" + id,
			"kind": "wrap",
			"text": "绕住「%s」%d 圈" % [p["name"], int(round(need))],
			"detail": "%d° / %d°" % [int(round(shown)), int(round(need * 360.0))],
			"ok": ok,
			"optional": not required,
			"progress": clampf(absf(turns) / maxf(0.001, need), 0.0, 1.0),
		})
		if required and not ok:
			win = false
	var need_cross := int(level.get("crossings_required", 0))
	if need_cross > 0:
		var got := int(metrics.get("resolved_crossings", 0))
		var cross_ok := got >= need_cross
		checks.append({
			"key": "crossing",
			"kind": "crossing",
			"text": "让绳子与自己交叉，分出上下",
			"detail": "%d / %d" % [mini(got, need_cross), need_cross],
			"ok": cross_ok,
			"optional": false,
			"progress": clampf(float(got) / float(need_cross), 0.0, 1.0),
		})
		if not cross_ok:
			win = false
	var gp := goal_point(level)
	var goal_radius := float(level.get("goal_radius", 0.6))
	var goal_dist := Vector2(end_point.x - gp.x, end_point.z - gp.z).length()
	var goal_ok := goal_dist <= goal_radius and end_point.y <= 1.05
	checks.append({
		"key": "goal",
		"kind": "goal",
		"text": "把绳头放到「结台」",
		"detail": "已到达" if goal_ok else "还差 %.1f m" % maxf(0.0, goal_dist - goal_radius),
		"ok": goal_ok,
		"optional": false,
		"progress": 1.0 if goal_ok else clampf(1.0 - goal_dist / maxf(0.01, goal_radius * 4.0), 0.0, 0.95),
	})
	if not goal_ok:
		win = false
	return {
		"win": win,
		"checks": checks,
		"goal_distance": goal_dist,
		"goal_ok": goal_ok,
	}


static func palette(level: Dictionary) -> Dictionary:
	var defaults := {
		"sky_top": "#A9D8D4",
		"sky_bottom": "#F8EBD8",
		"island_top": "#CFE4C0",
		"island_edge": "#E6B48C",
		"rock": "#B98063",
		"accent": "#3E8E8A",
		"petal": "#F1A7A0",
		"leaf": "#7FAE7A",
		"sun": "#FFE1B0",
	}
	var given = level.get("palette", {})
	var out := {}
	for k in defaults:
		out[k] = _color(str(given.get(k, defaults[k])), Color.html(defaults[k]))
	return out


static func camera_defaults(level: Dictionary) -> Dictionary:
	var cam = level.get("camera", {})
	var focus = cam.get("focus", [0.0, 0.65, 0.0])
	return {
		"yaw": float(cam.get("yaw", -32.0)),
		"pitch": float(cam.get("pitch", 38.0)),
		"distance": float(cam.get("distance", 9.5)),
		"focus": Vector3(float(focus[0]), float(focus[1]), float(focus[2])),
	}


static func _color(value, fallback: Color) -> Color:
	if value is Color:
		return value
	var s := str(value)
	if s.begins_with("#"):
		return Color.html(s)
	if Color.html_is_valid(s):
		return Color.html(s)
	return fallback
