extends SceneTree

## 性能探针（默认 1280×720；也可 --resolution 1920x1080）：
##   godot --path . --resolution 1280x720 -s tools/perf_sproutbound.gd
## 分别测：草甸待机 / 战斗（3 敌 + 玩家连斩）。
## 注意：必须关闭 VSync 并等待 3s 预热，读数为真实帧循环平均。

var scene


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(1.0).timeout
	scene.start_game()
	scene.set_mouse_capture(false)
	await create_timer(3.0).timeout
	await _measure("idle", 4.0)
	# 战斗场景：玩家 + 3 只菌怪，持续连斩
	scene.set_controls_enabled(false)
	for e in scene.enemies:
		e.active = false
		e.visible = false
	var es := [scene.enemies[0], scene.enemies[1], scene.enemies[4]]
	for e in es:
		e.visible = true
		e.active = false
	var gy: float = scene.world.ground_y(0.0, 8.0)
	scene.demo_teleport(Vector3(0.0, gy + 0.06, 8.0), PI)
	es[0].global_position = Vector3(-0.9, scene.world.ground_y(-0.9, 9.6) + 0.05, 9.6)
	es[1].global_position = Vector3(0.9, scene.world.ground_y(0.9, 9.6) + 0.05, 9.6)
	es[2].global_position = Vector3(2.6, scene.world.ground_y(2.6, 9.2) + 0.05, 9.2)
	for e in es:
		e.aim_at(scene.player.global_position)
		e.demo_set_state("chase")
	await create_timer(1.5).timeout
	# 异步战斗循环：每 0.5s 触发一次挥剑
	var atk := func():
		scene.player.combo_window = 1.0
		scene.player.begin_attack(randi() % 3)
	await _measure_async("combat", 4.0, atk)
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _measure(label: String, seconds: float) -> void:
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var last := t0
	var min_dt := 999.0
	var sum_dt := 0.0
	var end := t0 + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < end:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000000.0
		last = now
		frames += 1
		sum_dt += dt
		min_dt = minf(min_dt, dt)
	var total := float(Time.get_ticks_usec() - t0) / 1000000.0
	print("PERF[%s] %dx%d fps=%.1f frame_ms=%.1f min_ms=%.1f draw=%d prims=%d" % [
		label, root.get_viewport().get_visible_rect().size.x,
		root.get_viewport().get_visible_rect().size.y, frames / total,
		sum_dt / frames * 1000.0, min_dt * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


func _measure_async(label: String, seconds: float, tick: Callable) -> void:
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var last := t0
	var min_dt := 999.0
	var sum_dt := 0.0
	var next_atk := t0
	var end := t0 + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < end:
		var now0 := Time.get_ticks_usec()
		if now0 >= next_atk:
			tick.call()
			next_atk = now0 + 500000
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000000.0
		last = now
		frames += 1
		sum_dt += dt
		min_dt = minf(min_dt, dt)
	var total := float(Time.get_ticks_usec() - t0) / 1000000.0
	print("PERF[%s] %dx%d fps=%.1f frame_ms=%.1f min_ms=%.1f draw=%d prims=%d" % [
		label, root.get_viewport().get_visible_rect().size.x,
		root.get_viewport().get_visible_rect().size.y, frames / total,
		sum_dt / frames * 1000.0, min_dt * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
