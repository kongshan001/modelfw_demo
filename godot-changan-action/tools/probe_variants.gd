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
	scene.demo_start_wave(1)
	await create_timer(0.6).timeout
	scene.set_controls_enabled(false)
	for e in scene.wave_enemies:
		e.active = false
	scene.set_hud_visible(false)
	# warm
	for i in 2:
		var w = scene.wave_enemies[0]
		if is_instance_valid(w):
			w.hp = w.max_hp
			w.global_position = scene.player.global_position + Vector3(0, 0, 1.7)
			scene.player.aim_at(w.global_position)
			scene.player.begin_attack("kick")
		scene.spawn_oil_fire(scene.player.global_position + Vector3(1, 0, 0.5), 0.6)
		await create_timer(0.8).timeout
	await create_timer(1.0).timeout
	await _run("none", false, false)
	await _run("attacks", true, false)
	await _run("fire", false, true)
	await _run("both", true, true)
	print("CHANGAN_VARIANTS_DONE")
	quit(0)

func _run(label: String, attacks: bool, fire: bool) -> void:
	var beats := 0
	var samples: Array[float] = []
	for i in 8:
		await create_timer(0.5).timeout
		samples.append(Engine.get_frames_per_second())
		beats += 1
		if beats >= 3:
			beats = 0
			if attacks:
				var target = scene.wave_enemies[0]
				if is_instance_valid(target):
					target.hp = target.max_hp
					target.global_position = scene.player.global_position + Vector3(0, 0, 1.7)
					scene.player.aim_at(target.global_position)
					scene.player.combo_window = 1.0
					scene.player.combo_step = 2
					scene.player.begin_attack("kick")
			if fire:
				scene.spawn_oil_fire(scene.player.global_position + Vector3(1, 0, 0.5), 0.7)
			scene.demo_set_player_hp(100)
	var avg := 0.0
	var worst := 999.0
	for s in samples:
		avg += s
		worst = minf(worst, s)
	avg /= maxf(1.0, float(samples.size()))
	print("VARIANT %-8s avg=%.1f min=%.1f draws=%d" % [label, avg, worst,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
