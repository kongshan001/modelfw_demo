extends SceneTree

# Dev helper: verifies the built-in demo paths satisfy each level's goals.
#   godot --headless --path godot-knotline-puzzle -s tools/probe_paths.gd

const Paths := preload("res://tools/demo_paths.gd")


func _initialize() -> void:
	var levels := KnotLevel.load_all()
	for level in levels:
		var rope := KnotRope.new()
		var start := KnotLevel.start_point(level) + Vector3(0.0, 0.13, 0.0)
		rope.setup(start, KnotLevel.obstacles(level), {"ground_y": 0.0, "bounds_radius": 4.3})
		var pts: Array[Vector3] = Paths.for_level(level)
		for p in pts:
			rope.add_point(p)
		var metrics := rope.analyze(KnotLevel.normalize_pillars(level), 3)
		var eval := KnotLevel.evaluate(level, metrics, rope.last_point())
		print("LEVEL %s points=%d steps=%d length=%.2f crosses=%d flat=%d win=%s" % [
			level.get("id", "?"), rope.points.size(), rope.step_count(), rope.length(),
			metrics.get("resolved_crossings", 0), metrics.get("flat_crossings", 0), eval.get("win", false)
		])
		for p in KnotLevel.normalize_pillars(level):
			var w: Dictionary = metrics.get("winding", {}).get(p["id"], {})
			print("   %s turns=%.3f deg=%.1f" % [p["id"], w.get("turns", 0.0), w.get("angle_deg", 0.0)])
		for c in eval.get("checks", []):
			print("   %s ok=%s %s" % [c.get("key", ""), c.get("ok", false), c.get("detail", "")])
		for c in metrics.get("crossings", []):
			print("   X pos=(%.2f,%.2f,%.2f) delta=%.2f resolved=%s i=%d j=%d" % [
				c["pos"].x, c["pos"].y, c["pos"].z, c["delta"], c["resolved"], c["i"], c["j"]])
	quit(0)
