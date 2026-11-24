extends SceneTree

# 真 GPU 压测：1200 弹 + HUD + 背景，固定 1/60 逻辑步长。
# 默认在 1280×720 SubViewport 测；传 -- --vp=1920x1080 测 1080p（逻辑舞台 ×1.5）。
# 运行：
#   godot --path godot-bullet-hell --resolution 1280x720 -s tools/perf_bullet_hell.gd -- --vp=1920x1080
# 输出最后一行 BULLET_HELL_PERF_OK 或 BULLET_HELL_PERF_FAIL（阈值 30 FPS）。

var vp: SubViewport
var stage: Node2D
var game
var vp_size := Vector2i(1280, 720)
var bullet_target := 1200

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vp="):
			var parts := arg.substr(5).split("x")
			if parts.size() == 2:
				vp_size = Vector2i(int(parts[0]), int(parts[1]))
		elif arg.begins_with("--bullets="):
			bullet_target = int(arg.substr(10))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp = SubViewport.new()
	vp.size = vp_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	stage = Node2D.new()
	stage.scale = Vector2(float(vp_size.x) / 1280.0, float(vp_size.y) / 720.0)
	vp.add_child(stage)
	game = load("res://scenes/main.tscn").instantiate()
	stage.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.reset_run()
	game.debug_set_immunity(true)
	game.set_inspect(0)
	game.debug_set_stress(bullet_target > 0, bullet_target)
	game.debug_step(0.25)
	print("PERF viewport=", vp_size, " bullets=", game.field.pool.count, " vsync=", DisplayServer.window_get_vsync_mode())

	# 预热 2.5s，让 shader / pipeline / 分配稳定。
	var warm_end := Time.get_ticks_usec() + 2_500_000
	while Time.get_ticks_usec() < warm_end:
		game.debug_step(1.0 / 60.0)
		await process_frame

	var t0 := Time.get_ticks_usec()
	var frames := 0
	var max_frame_us := 0
	var last := t0
	while Time.get_ticks_usec() - t0 < 4_000_000:
		game.debug_step(1.0 / 60.0)
		await process_frame
		var now := Time.get_ticks_usec()
		var dt_us := now - last
		last = now
		if dt_us > max_frame_us:
			max_frame_us = dt_us
		frames += 1
	var elapsed := float(Time.get_ticks_usec() - t0) / 1_000_000.0
	var avg := float(frames) / maxf(0.001, elapsed)
	var min_fps := 1_000_000.0 / maxf(1.0, float(max_frame_us))
	var bullets: int = game.field.pool.count
	print("PERF_RESULT viewport=%dx%d bullets=%d frames=%d elapsed=%.2fs avg_fps=%.2f worst_frame_ms=%.2f min_fps=%.2f" % [
		vp_size.x, vp_size.y, bullets, frames, elapsed, avg, float(max_frame_us) / 1000.0, min_fps,
	])
	print("PERF_HUD_FPS %d" % Engine.get_frames_per_second())
	if avg >= 30.0 and bullets >= bullet_target:
		print("BULLET_HELL_PERF_OK")
	else:
		print("BULLET_HELL_PERF_FAIL")
	quit(0 if avg >= 30.0 and bullets >= bullet_target else 1)
