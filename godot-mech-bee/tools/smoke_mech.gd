extends SceneTree

# Headless acceptance: solver, part count, explode/reassemble, isolate, HUD.
# Run: godot --headless --path godot-mech-bee -s tools/smoke_mech.gd

func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.5).timeout

	var fails: Array[String] = []
	var s = scene.solver

	# ── solver + wing motion ──
	if s.beat_hz() <= 0.0:
		fails.append("HOVER beat_hz should be > 0")
	scene.auto_tour = false
	scene.paused = false
	scene.set_state("HOVER", false)
	var a: float = s.wing_angle(0)
	await create_timer(0.25).timeout
	var b: float = s.wing_angle(0)
	if absf(a - b) < 0.01:
		fails.append("wing did not move")
	if scene.model.parts.size() != 17:
		fails.append("part count %d != 17" % scene.model.parts.size())
	if scene.hud == null:
		fails.append("HUD missing")
	if scene.labels == null:
		fails.append("labels overlay missing")
	if scene.visible_label_parts().is_empty():
		fails.append("no label parts")

	# ── telemetry is driven by the same solver ──
	scene.hud.update_view()
	if scene.hud.wing_value.text.is_empty():
		fails.append("HUD wing value empty")
	if scene.hud.runtime_value.text.is_empty():
		fails.append("HUD runtime empty")

	# ── teardown ──
	scene.set_state("TEARDOWN", false)
	await create_timer(1.7).timeout
	if scene.explode_t < 0.8:
		fails.append("teardown explode_t %.2f < 0.8" % scene.explode_t)
	var moved := 0
	for part in scene.model.parts:
		if part.node.position.distance_to(part.home) > 0.2:
			moved += 1
	if moved < 12:
		fails.append("exploded parts %d < 12" % moved)
	if s.beat_hz() != 0.0:
		fails.append("teardown wings should stop")

	# ── reassembly ──
	scene.set_state("REASSEMBLY", false)
	await create_timer(2.4).timeout
	if scene.explode_t > 0.05:
		fails.append("reassembly explode_t %.2f > 0.05" % scene.explode_t)

	# ── isolate ──
	scene.set_state("HOVER", false)
	await create_timer(0.3).timeout
	scene.select_part("optics")
	scene.toggle_isolate()
	if scene.model.part_visible("thorax"):
		fails.append("isolate did not hide thorax")
	if not scene.model.part_visible("optics"):
		fails.append("isolate hid the selected part")
	scene.toggle_isolate()
	if not scene.model.part_visible("thorax"):
		fails.append("isolate release did not restore parts")

	# ── wing-off state ──
	scene.set_state("WING OFF", false)
	await create_timer(1.2).timeout
	if s.beat_hz() != 0.0:
		fails.append("wing-off beat_hz should be 0")
	var wing_moved: bool = scene.model.get_part("wing_lf").node.position.distance_to(
		scene.model.get_part("wing_lf").home) > 0.1
	if not wing_moved:
		fails.append("wing-off did not move the wing")

	# ── pause ──
	var t0: float = s.t
	scene.paused = true
	await create_timer(0.3).timeout
	if absf(s.t - t0) > 0.001:
		fails.append("pause advanced solver time")
	scene.paused = false

	if fails.is_empty():
		print("MECH_SMOKE_OK parts=17 moved=%d" % moved)
		quit(0)
	else:
		for f in fails:
			printerr("MECH FAIL: ", f)
		quit(1)
