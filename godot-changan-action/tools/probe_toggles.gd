extends SceneTree

var scene

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(1.4).timeout
	scene.set_mouse_capture(false)
	scene.start_game()
	scene.demo_set_lights(3)
	scene.demo_teleport(Vector3(0, 0.06, 16.5), 0.0)
	scene.set_controls_enabled(false)
	scene.set_hud_visible(false)
	await create_timer(2.0).timeout
	await _m("all")
	scene.player_fill.light_energy = 0.0
	await _m("no_fill_light")
	scene.world.env.fog_enabled = false
	await _m("no_fog")
	var sky: Sky = scene.world.env.sky
	scene.world.env.background_mode = Environment.BG_COLOR
	scene.world.env.background_color = Color(0.03, 0.045, 0.09)
	await _m("no_sky")
	scene.world.lantern_halos.visible = false
	await _m("no_halos")
	for lamp in scene.world.lamps:
		lamp["light"].light_energy = 0.0
	await _m("no_lamp_lights")
	scene.set_hud_visible(true)
	await _m("hud_on")
	print("CHANGAN_TOGGLES_DONE")
	quit(0)

func _m(label: String) -> void:
	var samples: Array[float] = []
	for i in 7:
		await create_timer(0.4).timeout
		samples.append(Engine.get_frames_per_second())
	var avg := 0.0
	var worst := 999.0
	for s in samples:
		avg += s
		worst = minf(worst, s)
	avg /= maxf(1.0, float(samples.size()))
	print("TOGGLE %-14s avg=%.1f min=%.1f draws=%d" % [label, avg, worst,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
