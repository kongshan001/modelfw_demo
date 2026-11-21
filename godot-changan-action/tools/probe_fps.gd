extends SceneTree

## 真实窗口性能探针（Intel HD 6000 目标：1280×720 avg ≥30 / min ≥20）
##   godot --path . --resolution 1280x720 -s tools/probe_fps.gd

var scene


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(1.6).timeout
	scene.set_mouse_capture(false)
	scene.start_game()
	scene.demo_set_lights(3)
	scene.demo_teleport(Vector3(0, 0.06, 16.5), 0.0)
	scene.demo_start_wave(1)
	await create_timer(0.8).timeout
	scene.set_controls_enabled(false)
	for e in scene.wave_enemies:
		e.active = false

	# 预热：编译角色/命中/火焰 shader，避免把首次编译算进平均帧率
	for i in 3:
		var warm = scene.wave_enemies[0]
		if is_instance_valid(warm):
			warm.hp = warm.max_hp
			warm.global_position = scene.player.global_position + Vector3(0, 0, 1.7)
			scene.player.aim_at(warm.global_position)
			scene.player.combo_window = 1.0
			scene.player.combo_step = 2
			scene.player.begin_attack("kick")
			scene.spawn_impact(warm.global_position + Vector3(0, 1.2, 0), Color(1.0, 0.7, 0.3), 1.5)
		scene.spawn_oil_fire(scene.player.global_position + Vector3(1.0, 0, 0.5), 0.6)
		await create_timer(0.7).timeout
	scene.demo_set_player_hp(100)
	await create_timer(1.2).timeout

	var samples: Array[float] = []
	var elapsed := 0.0
	var beat := 0.0
	while elapsed < 12.0:
		await create_timer(0.5).timeout
		elapsed += 0.5
		samples.append(Engine.get_frames_per_second())
		beat += 0.5
		if beat >= 1.5:
			beat = 0.0
			# 代表性战斗：持续 3 连命中；火油每 3 秒一次（油贩实际冷却）
			var target = scene.wave_enemies[0]
			if is_instance_valid(target) and not target.is_dead:
				target.hp = target.max_hp
				target.global_position = scene.player.global_position + Vector3(0, 0, 1.7)
				scene.player.aim_at(target.global_position)
				scene.player.combo_window = 1.0
				scene.player.combo_step = 2
				scene.player.begin_attack("kick")
			if int(elapsed * 2.0) % 6 == 0:
				scene.spawn_oil_fire(scene.player.global_position + Vector3(1.0, 0, 0.5), 0.7)
			scene.demo_set_player_hp(100)
	var avg := 0.0
	var worst := 999.0
	for s in samples:
		avg += s
		worst = minf(worst, s)
	avg /= float(maxi(samples.size(), 1))
	print("CHANGAN_FPS avg=%.1f min=%.1f samples=%d lights=%d draws=%d tris=%d" % [
		avg, worst, samples.size(), scene.street_lights_lit,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	var ok := avg >= 30.0 and worst >= 20.0
	print("CHANGAN_FPS_OK" if ok else "CHANGAN_FPS_FAIL")
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if ok else 1)
