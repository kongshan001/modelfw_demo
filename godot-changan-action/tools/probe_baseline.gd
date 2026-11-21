extends SceneTree

var scene

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(1.0).timeout
	scene.set_mouse_capture(false)
	scene.start_game()
	await create_timer(0.6).timeout
	await _measure("idle_lights0", 4.0)
	scene.demo_set_lights(3)
	await _measure("idle_lights3", 4.0)
	scene.demo_teleport(Vector3(0, 0.06, 16.5), 0.0)
	scene.demo_start_wave(1)
	await create_timer(0.6).timeout
	scene.set_controls_enabled(false)
	await _measure("combat", 5.0)
	scene.set_hud_visible(false)
	await _measure("combat_nohud", 3.0)
	print("CHANGAN_BASELINE_DONE")
	quit(0)

func _measure(label: String, seconds: float) -> void:
	var samples: Array[float] = []
	var elapsed := 0.0
	while elapsed < seconds:
		await create_timer(0.5).timeout
		elapsed += 0.5
		samples.append(Engine.get_frames_per_second())
	var avg := 0.0
	var worst := 999.0
	for s in samples:
		avg += s
		worst = minf(worst, s)
	avg /= float(maxi(samples.size(), 1))
	print("BASELINE %s avg=%.1f min=%.1f draws=%d tris=%d objects=%d video=%.1fMB" % [
		label, avg, worst,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	])
