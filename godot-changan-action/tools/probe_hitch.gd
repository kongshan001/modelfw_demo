extends SceneTree

var scene
var last_action := "none"
var last_hitstop := 0.0
var last_draws := 0

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
	# warm
	for i in 3:
		_do_attack()
		scene.spawn_oil_fire(scene.player.global_position + Vector3(1, 0, 0.5), 0.6)
		await create_timer(0.8).timeout
	await create_timer(1.0).timeout
	var elapsed := 0.0
	var beat := 0.0
	var last_us := Time.get_ticks_usec()
	var frames := 0
	var sum_dt := 0.0
	var worst := 0.0
	var worst_at := 0.0
	var next_fire := 0.0
	while elapsed < 10.0:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last_us) / 1000000.0
		last_us = now
		elapsed += dt
		frames += 1
		sum_dt += dt
		if dt > worst:
			worst = dt
			worst_at = elapsed
		if dt > 0.10:
			print("HITCH dt=%.1fms at=%.2fs action=%s hitstop=%.2f draws=%d fps=%.1f" % [
				dt * 1000.0, elapsed, last_action, scene.hitstop_timer,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Engine.get_frames_per_second()])
		beat += dt
		if beat >= 1.5:
			beat = 0.0
			if elapsed >= next_fire:
				next_fire = elapsed + 2.0
				scene.spawn_oil_fire(scene.player.global_position + Vector3(1, 0, 0.5), 0.7)
				last_action = "fire"
			_do_attack()
			last_action = "attack"
		scene.demo_set_player_hp(100)
	var avg := float(frames) / maxf(sum_dt, 0.001)
	print("HITCH_SUMMARY frames=%d avg=%.1f worst=%.1fms at=%.2fs" % [frames, avg, worst * 1000.0, worst_at])
	quit(0)

func _do_attack() -> void:
	var target = scene.wave_enemies[0]
	if is_instance_valid(target):
		target.hp = target.max_hp
		target.global_position = scene.player.global_position + Vector3(0, 0, 1.7)
		scene.player.aim_at(target.global_position)
		scene.player.combo_window = 1.0
		scene.player.combo_step = 2
		scene.player.begin_attack("kick")
