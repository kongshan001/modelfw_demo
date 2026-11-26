extends SceneTree

# Headless acceptance suite for Knotline.
#   godot --headless --path godot-knotline-puzzle -s tools/smoke_knotline.gd
# Covers level schema, tube mesh, one-stroke continuity, pillar clearance,
# winding, over/under self-crossings, objective evaluation, undo/reset,
# demo-path solvability and live scene wiring.
# Prints KNOTLINE_SMOKE_OK checks=<n> on success; exits 1 on failure.

const Paths := preload("res://tools/demo_paths.gd")
const MAIN_SCENE := "res://scenes/main.tscn"

var fails: Array[String] = []
var checks := 0
var levels: Array[Dictionary] = []


func _initialize() -> void:
	levels = KnotLevel.load_all()
	_test_levels()
	_test_tube()
	_test_continuity()
	_test_obstacle_push()
	_test_winding()
	_test_crossings()
	_test_evaluate()
	_test_undo_reset()
	_test_demo_paths()
	_test_dense_paths()
	await _test_scene()
	if fails.is_empty():
		print("KNOTLINE_SMOKE_OK checks=%d levels=%d" % [checks, levels.size()])
		quit(0)
	else:
		for f in fails:
			printerr("KNOTLINE FAIL: ", f)
		printerr("KNOTLINE_SMOKE_FAILED checks=%d fails=%d" % [checks, fails.size()])
		quit(1)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails.append(msg)


func _close(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps


func _finite_v3(v: Vector3) -> bool:
	return not (is_nan(v.x) or is_nan(v.y) or is_nan(v.z) or is_inf(v.x) or is_inf(v.y) or is_inf(v.z))


func _test_levels() -> void:
	_check(levels.size() == 2, "expected 2 levels, got %d" % levels.size())
	for lvl in levels:
		_check(KnotLevel.validate(lvl) == "", "level schema should validate: " + str(lvl.get("id", "?")))
		_check(lvl.has("name") and String(lvl["name"]) != "", "level needs a name")
		var start := KnotLevel.start_point(lvl)
		var goal := KnotLevel.goal_point(lvl)
		_check(start.distance_to(goal) > 1.0, "start and goal too close")
		_check(start.distance_to(Vector3.ZERO) < 5.0 and goal.distance_to(Vector3.ZERO) < 5.0, "pad outside island")
		var pillars := KnotLevel.normalize_pillars(lvl)
		_check(pillars.size() >= 2, "level should offer multiple wrap targets")
		var required := 0
		for p in pillars:
			_check(float(p["radius"]) > 0.0 and float(p["height"]) > 0.0, "pillar has positive size")
			if bool(p["required"]):
				required += 1
		_check(required >= 1, "level needs at least one required pillar")
		var pal := KnotLevel.palette(lvl)
		_check(pal.size() >= 8, "palette incomplete")
		var cam := KnotLevel.camera_defaults(lvl)
		_check(float(cam["distance"]) > 3.0, "camera distance")


func _test_tube() -> void:
	var ctrl := PackedVector3Array([
		Vector3(0.0, 0.1, 0.0), Vector3(0.8, 0.3, 0.2),
		Vector3(1.6, 0.1, 0.7), Vector3(2.5, 0.35, 0.3),
	])
	var samples := KnotTube.sample_catmull(ctrl, 3)
	_check(samples.size() >= ctrl.size() * 2, "Catmull sampling too sparse")
	_check(samples[0].is_equal_approx(ctrl[0]), "sample must start at first control point")
	_check(samples[samples.size() - 1].is_equal_approx(ctrl[ctrl.size() - 1]), "sample must end at last control point")
	var finite := true
	for p in samples:
		if not _finite_v3(p):
			finite = false
	_check(finite, "sampled points must be finite")
	var mesh := KnotTube.build_tube(samples, 0.05, 8)
	_check(mesh.get_surface_count() == 1, "tube should have one surface")
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_check(verts.size() == samples.size() * 8, "unexpected tube vertex count")
	_check(idx.size() == (samples.size() - 1) * 8 * 6, "unexpected tube index count")
	_check(uvs.size() == verts.size(), "UV count must match vertices")
	var bad_norm := false
	var bad_idx := false
	for n in norms:
		if absf(n.length() - 1.0) > 0.02:
			bad_norm = true
	for i in idx:
		if i < 0 or i >= verts.size():
			bad_idx = true
	_check(not bad_norm, "tube normals must be unit length")
	_check(not bad_idx, "tube indices out of range")
	var len := KnotTube.polyline_length(samples)
	_check(len > 2.0, "sampled tube length too short")


func _test_continuity() -> void:
	var rope := KnotRope.new()
	rope.setup(Vector3(-2.0, 0.12, 0.0), [], {"ground_y": 0.0, "bounds_radius": 5.0})
	_check(rope.points.size() == 1 and rope.points[0].is_equal_approx(rope.anchor), "rope must start at anchor")
	_check(rope.step_count() == 0 and rope.is_empty(), "new rope should be empty")
	var added := 0
	for i in 5:
		added += rope.add_point(Vector3(-1.6 + i * 0.3, 0.12, 0.1 * i))
	_check(added == 5, "each distinct point should append")
	_check(rope.step_count() == 5, "step count should count user points after anchor")
	_check(rope.points.size() == 6, "one raw point per user input without obstacles")
	var at_end := rope.points[rope.points.size() - 1]
	_check(rope.add_point(at_end) == 0, "duplicate point should be ignored")
	_check(rope.step_count() == 5, "ignored point must not change steps")
	var first := rope.points[0]
	var connected := true
	for i in range(1, rope.points.size()):
		if not _finite_v3(rope.points[i]) or rope.points[i].distance_to(rope.points[i - 1]) > rope.max_jump + 0.01:
			connected = false
	_check(connected, "polyline must remain continuous and finite")
	_check(first.distance_to(rope.anchor) < 0.001, "anchor must never move")
	var far := rope.add_point(Vector3(40.0, 9.0, -40.0))
	_check(far > 0, "far point should clamp, not fail")
	var last := rope.last_point()
	_check(absf(last.x) <= rope.bounds_radius + 0.01 and absf(last.z) <= rope.bounds_radius + 0.01, "point should clamp to bounds")
	_check(last.y <= 3.81, "point should clamp in height")
	_check(rope.length() > 0.0, "length should be positive")


func _test_obstacle_push() -> void:
	var obs := {
		"id": "p", "center": Vector2.ZERO, "radius": 0.3,
		"height": 1.5, "y0": 0.0, "y1": 1.5,
	}
	var rope := KnotRope.new()
	rope.setup(Vector3(-0.8, 0.5, 0.0), [obs], {"ground_y": 0.0, "bounds_radius": 5.0})
	rope.add_point(Vector3(0.8, 0.5, 0.0))
	var safe := 0.3 + rope.rope_radius + rope.clearance - 0.01
	var all_outside := true
	var has_arc := false
	for p in rope.points:
		if p.distance_to(rope.anchor) < 0.001:
			continue
		var d := Vector2(p.x, p.z).length()
		if d < safe:
			all_outside = false
		if d > safe + 0.05:
			has_arc = true
	_check(all_outside, "rope must not cut through the pillar")
	_check(has_arc, "crossing a pillar should insert arc points")
	_check(rope.points.size() > 2, "arc insertion should add raw points")
	_check(rope.step_count() == 1, "arc points must not count as user steps")
	var samples := rope.sample(3)
	var w := rope.compute_winding(samples, [obs])
	var turns := float(w["p"]["turns"])
	_check(absf(turns) >= 0.45, "going around a pillar half-way should register winding, got %.2f" % turns)


func _test_winding() -> void:
	var rope := KnotRope.new()
	var pillar := {"id": "p", "center": Vector2.ZERO, "radius": 0.3, "height": 1.5}
	var circle := PackedVector3Array()
	for i in 73:
		var a := TAU * float(i) / 72.0
		circle.append(Vector3(cos(a) * 0.45, 0.55, sin(a) * 0.45))
	var w := rope.compute_winding(circle, [pillar])
	var turns := float(w["p"]["turns"])
	_check(_close(turns, 1.0, 0.02), "full circle should be one turn, got %.3f" % turns)
	var half := PackedVector3Array()
	for i in 37:
		var a2 := PI * float(i) / 36.0
		half.append(Vector3(cos(a2) * 0.45, 0.55, sin(a2) * 0.45))
	var w2 := rope.compute_winding(half, [pillar])
	_check(_close(float(w2["p"]["turns"]), 0.5, 0.02), "half circle should be half a turn")
	var rev := PackedVector3Array()
	for i in 73:
		var a3 := -TAU * float(i) / 72.0
		rev.append(Vector3(cos(a3) * 0.45, 0.55, sin(a3) * 0.45))
	var w3 := rope.compute_winding(rev, [pillar])
	_check(_close(float(w3["p"]["turns"]), -1.0, 0.02), "reversed circle should be negative one turn")
	var high := PackedVector3Array()
	for p in circle:
		high.append(Vector3(p.x, 2.2, p.z))
	var w4 := rope.compute_winding(high, [pillar])
	_check(absf(float(w4["p"]["turns"])) < 0.01, "a loop above the pillar must not count")
	var wide := PackedVector3Array()
	for p in circle:
		wide.append(Vector3(p.x * 2.6, p.y, p.z * 2.6))
	var w5 := rope.compute_winding(wide, [pillar])
	_check(absf(float(w5["p"]["turns"])) < 0.01, "a loop far from the pillar must not count")


func _test_crossings() -> void:
	var rope := KnotRope.new()
	var samples := _crossing_samples(0.2, 0.5)
	var xs := KnotRope.find_crossings(samples, 0.12, 0.45)
	var resolved := 0
	var max_delta := 0.0
	for c in xs:
		if bool(c["resolved"]):
			resolved += 1
			max_delta = maxf(max_delta, float(c["delta"]))
	_check(resolved >= 1, "figure-eight should have a resolved crossing")
	_check(max_delta >= 0.25, "crossing should carry a clear over/under height difference")
	var flat := KnotRope.find_crossings(_crossing_samples(0.3, 0.31), 0.12, 0.45)
	var flat_resolved := 0
	var flat_total := 0
	for c in flat:
		flat_total += 1
		if bool(c["resolved"]):
			flat_resolved += 1
	_check(flat_total >= 1, "flat crossing should still be found")
	_check(flat_resolved == 0, "flat crossing must not count as over/under")


func _crossing_samples(y_a: float, y_b: float) -> PackedVector3Array:
	var samples := PackedVector3Array()
	# Low strand, left to right. An odd number of segments keeps the crossing
	# inside a segment rather than exactly on a shared vertex.
	for i in 26:
		var t := float(i) / 25.0
		samples.append(Vector3(lerpf(-1.0, 1.0, t), y_a, lerpf(0.0, 1.0, t)))
	# A distant loop keeps the two strands far apart along the stroke.
	var connectors: Array[Vector3] = [Vector3(2.4, 0.2, 2.0), Vector3(2.4, 0.2, -2.0), Vector3(-2.4, 0.2, -2.0), Vector3(-1.2, 0.2, -1.0)]
	for p in connectors:
		samples.append(p)
	# High strand, crossing the low one.
	for i in 26:
		var t2 := float(i) / 25.0
		samples.append(Vector3(lerpf(-1.0, 1.0, t2), y_b, lerpf(1.0, 0.0, t2)))
	return samples


func _test_evaluate() -> void:
	var lvl: Dictionary = levels[0]
	var pillars := KnotLevel.normalize_pillars(lvl)
	var metrics := {
		"winding": {},
		"resolved_crossings": 0,
		"flat_crossings": 0,
	}
	for p in pillars:
		metrics["winding"][p["id"]] = {"turns": 1.01 if p["required"] else 0.0, "angle_deg": 363.0}
	var goal := KnotLevel.goal_point(lvl)
	var far := goal + Vector3(3.0, 0.0, 0.0)
	var eval_ok := KnotLevel.evaluate(lvl, metrics, goal)
	_check(bool(eval_ok["win"]), "all requirements + goal should win")
	var eval_far := KnotLevel.evaluate(lvl, metrics, far)
	_check(not bool(eval_far["win"]), "must not win away from the goal pad")
	var zero := metrics.duplicate(true)
	zero["winding"][pillars[0]["id"]] = {"turns": 0.2, "angle_deg": 72.0}
	var eval_zero := KnotLevel.evaluate(lvl, zero, goal)
	_check(not bool(eval_zero["win"]), "must not win without wrapping the required pillar")
	var clockwise := metrics.duplicate(true)
	for p in pillars:
		if bool(p["required"]):
			clockwise["winding"][p["id"]] = {"turns": -1.01, "angle_deg": 363.0}
	_check(bool(KnotLevel.evaluate(lvl, clockwise, goal)["win"]), "clockwise winding should also win")
	# Optional pillars must not block the win.
	var optional_only := metrics.duplicate(true)
	for p in pillars:
		if not bool(p["required"]):
			optional_only["winding"][p["id"]] = {"turns": 0.0, "angle_deg": 0.0}
	_check(bool(KnotLevel.evaluate(lvl, optional_only, goal)["win"]), "optional target must not block")
	# Level 2 needs a resolved self-crossing.
	var lvl2: Dictionary = levels[1]
	var m2 := metrics.duplicate(true)
	m2["winding"] = {}
	for p in KnotLevel.normalize_pillars(lvl2):
		m2["winding"][p["id"]] = {"turns": 1.01, "angle_deg": 363.0}
	var g2 := KnotLevel.goal_point(lvl2)
	m2["resolved_crossings"] = 0
	_check(not bool(KnotLevel.evaluate(lvl2, m2, g2)["win"]), "level 2 must require a self-crossing")
	m2["resolved_crossings"] = 1
	_check(bool(KnotLevel.evaluate(lvl2, m2, g2)["win"]), "level 2 should win with a crossing")


func _test_undo_reset() -> void:
	var rope := KnotRope.new()
	rope.setup(Vector3(-1.0, 0.1, 0.0), [], {"ground_y": 0.0})
	for i in 5:
		rope.add_point(Vector3(-0.8 + i * 0.2, 0.1, 0.1))
	_check(rope.step_count() == 5, "setup undo test steps")
	var before := rope.length()
	var info := rope.undo_info()
	_check(not info.is_empty(), "undo_info should be available")
	_check(rope.undo_last_control(), "undo should remove a point")
	_check(rope.step_count() == 4, "undo should decrease steps")
	_check(rope.length() < before, "undo should shorten the rope")
	var guard := 0
	while rope.undo_last_control() and guard < 10:
		guard += 1
	_check(rope.step_count() == 0, "all user points should undo back to anchor")
	_check(rope.points.size() == 1 and rope.last_point().is_equal_approx(rope.anchor), "rope should end at anchor")
	for i in 3:
		rope.add_point(Vector3(0.0, 0.1, 0.3 * (i + 1)))
	rope.reset()
	_check(rope.points.size() == 1, "reset should keep the anchor")
	_check(rope.step_count() == 0, "reset should clear steps")
	_check(_close(rope.length(), 0.0), "reset should clear length")


func _test_demo_paths() -> void:
	for lvl in levels:
		var rope := KnotRope.new()
		rope.setup(KnotLevel.start_point(lvl) + Vector3(0.0, 0.13, 0.0), KnotLevel.obstacles(lvl), {
			"ground_y": 0.0, "bounds_radius": 4.3,
		})
		var path: Array[Vector3] = Paths.for_level(lvl)
		_check(not path.is_empty(), "demo path missing for " + str(lvl.get("id", "?")))
		for p in path:
			rope.add_point(p)
		_check(rope.points.size() <= rope.max_points, "demo path must stay under the point cap")
		var metrics := rope.analyze(KnotLevel.normalize_pillars(lvl), 3)
		var ev := KnotLevel.evaluate(lvl, metrics, rope.last_point())
		_check(bool(ev["win"]), "demo path must solve " + str(lvl.get("id", "?")))
		for p in KnotLevel.normalize_pillars(lvl):
			if bool(p["required"]):
				var turns := float(metrics["winding"][p["id"]]["turns"])
				_check(turns >= float(p["turns"]) - 0.05, "demo path should wrap " + str(p["id"]))
		if int(lvl.get("crossings_required", 0)) > 0:
			_check(int(metrics["resolved_crossings"]) >= int(lvl["crossings_required"]), "demo path should self-cross")


func _test_dense_paths() -> void:
	# The video/capture tools feed mouse-density samples; make sure that
	# densification cannot round a loop below the required turn count.
	for lvl in levels:
		var path: Array[Vector3] = Paths.for_level(lvl)
		var dense := _densify(path, 0.09)
		_check(dense.size() > path.size(), "dense path should have more points")
		var rope := KnotRope.new()
		rope.setup(KnotLevel.start_point(lvl) + Vector3(0.0, 0.13, 0.0), KnotLevel.obstacles(lvl), {
			"ground_y": 0.0, "bounds_radius": 4.3,
		})
		for p in dense:
			rope.add_point(p)
		var metrics := rope.analyze(KnotLevel.normalize_pillars(lvl), 3)
		var ev := KnotLevel.evaluate(lvl, metrics, rope.last_point())
		_check(bool(ev["win"]), "dense demo path must solve " + str(lvl.get("id", "?")))
		_check(rope.points.size() <= rope.max_points, "dense path exceeds point cap")
		if int(lvl.get("crossings_required", 0)) > 0:
			_check(int(metrics["resolved_crossings"]) >= 1, "dense path should keep its over/under crossing")


func _densify(path: Array[Vector3], step: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if path.is_empty():
		return out
	for i in range(path.size() - 1):
		var a := path[i]
		var b := path[i + 1]
		var n := maxi(1, int(ceil(a.distance_to(b) / step)))
		for k in n:
			out.append(a.lerp(b, float(k) / float(n)))
	out.append(path[path.size() - 1])
	return out


func _test_scene() -> void:
	var game := (load(MAIN_SCENE) as PackedScene).instantiate() as KnotGame
	root.add_child(game)
	await process_frame
	await process_frame
	_check(game.levels.size() == 2, "scene should load both levels")
	_check(game.world != null and game.rope != null and game.hud != null, "scene wiring incomplete")
	game.debug_load_level(1)
	await process_frame
	var path: Array[Vector3] = Paths.for_level(game.levels[1])
	game.debug_set_path(path, false)
	var st: Dictionary = game.debug_state()
	_check(bool(st["win"]), "scene-level path should satisfy level 2")
	game.debug_set_path(path, true)
	await process_frame
	_check(bool(game.debug_state()["won"]), "finishing a solved line should show the win state")
	game.queue_free()
	await process_frame
