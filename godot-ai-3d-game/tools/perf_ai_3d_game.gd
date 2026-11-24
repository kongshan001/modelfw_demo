extends SceneTree

# 真 GPU 压测：1920×1080 默认，3 车 + HUD + 全场景；玩家自动驾驶并持续打方向。
# 运行：
#   godot --path godot-ai-3d-game --resolution 1280x720 -s tools/perf_ai_3d_game.gd
#   godot --path godot-ai-3d-game --resolution 1280x720 -s tools/perf_ai_3d_game.gd -- --vp=1280x720

var vp: SubViewport
var world: RaceWorld
var vp_size := Vector2i(1920, 1080)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vp="):
			var parts := arg.substr(5).split("x")
			if parts.size() == 2:
				vp_size = Vector2i(int(parts[0]), int(parts[1]))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp = SubViewport.new()
	vp.size = vp_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	vp.add_child(scene)
	world = scene as RaceWorld
	await process_frame
	await process_frame
	world.debug_start_now()
	print("PERF_VIEWPORT ", vp_size, " vsync=", DisplayServer.window_get_vsync_mode())

	Input.action_press("accelerate")
	# 预热 2.5s，让 shader 编译和场景上传稳定。
	var warm_end := Time.get_ticks_usec() + 2_500_000
	while Time.get_ticks_usec() < warm_end:
		_autopilot()
		await process_frame

	var sample_start := Time.get_ticks_usec()
	var last_us := sample_start
	var frames := 0
	var worst_us := 0
	var samples: Array[float] = []
	while Time.get_ticks_usec() - sample_start < 6_000_000:
		_autopilot()
		await process_frame
		var now := Time.get_ticks_usec()
		var frame_us := now - last_us
		last_us = now
		frames += 1
		worst_us = maxi(worst_us, frame_us)
		samples.append(1_000_000.0 / maxf(1.0, float(frame_us)))
	var elapsed := float(Time.get_ticks_usec() - sample_start) / 1_000_000.0
	samples.sort()
	var median := samples[int(samples.size() * 0.5)]
	var p95 := samples[int(samples.size() * 0.95)]
	var avg := float(frames) / maxf(0.001, elapsed)
	var min_fps := 1_000_000.0 / maxf(1.0, float(worst_us))
	Input.action_release("accelerate")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	print("PERF_RESULT viewport=%dx%d frames=%d elapsed=%.2fs avg_fps=%.2f median_fps=%.2f p95_fps=%.2f worst_frame_ms=%.2f min_fps=%.2f speed=%.1f kmh" % [
		vp_size.x, vp_size.y, frames, elapsed, avg, median, p95, float(worst_us) / 1000.0, min_fps,
		world.player.speed_kmh(),
	])
	if avg >= 30.0:
		print("AI_3D_GAME_PERF_OK avg_fps=%.1f" % avg)
	else:
		print("AI_3D_GAME_PERF_FAIL avg_fps=%.1f" % avg)
	quit(0 if avg >= 30.0 else 1)


func _autopilot() -> void:
	if world == null or world.state != RaceWorld.RaceState.RACING:
		return
	var near := world.track.nearest(world.player.global_position)
	var ahead := world.track.point_at(float(near["progress"]) + 13.0)
	var to := ahead - world.player.global_position
	var desired := atan2(-to.x, -to.z)
	var diff := wrapf(desired - world.player.yaw, -PI, PI)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_press("accelerate")
	if diff > 0.025:
		Input.action_press("steer_left")
	elif diff < -0.025:
		Input.action_press("steer_right")
