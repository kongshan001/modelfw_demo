extends SceneTree

# 真实窗口性能采样（不是 1920 离屏截图管线）：
#   godot --path godot-dream-parry --resolution 1280x720 -s tools/perf_dream_parry.gd
#   godot --path godot-dream-parry --resolution 1920x1080 -s tools/perf_dream_parry.gd
# 采样：醒梦庭待机 + 无钟之间 Boss 实战（玩家无敌，避免死亡中断）。
# 打印实际窗口/视口尺寸。若系统显示器小于请求尺寸，窗口会被桌面夹取，日志如实记录。

var world: DreamWorld


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	world = scene as DreamWorld
	world.capture_mode = true
	world.hud._intro_left = 0.0
	world.hud.show_fps = false
	await create_timer(3.0).timeout
	var requested := Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width")), int(ProjectSettings.get_setting("display/window/size/viewport_height")))
	print("PERF_WINDOW logical_request=%s actual_window=%s root_viewport=%s hud_size=%s" % [
		str(requested),
		str(DisplayServer.window_get_size()),
		str(root.size),
		str(world.hud.size),
	])
	var idle := await _sample(4.0)
	print("PERF_IDLE avg_fps=%.1f p95_frame_ms=%.2f p95_fps=%.1f" % [idle["fps"], idle["p95"], idle["min"]])
	world.capture_mode = false
	world.debug_teleport_player(Vector3(25.0, 0.05, -22.0), -PI * 0.5)
	world.player.hit_invuln = 9999.0
	world.boss.global_position = DreamLevel.BOSS_HOME
	world.boss.aggro = true
	world.boss_engaged = true
	world.boss.attack_cooldown = 0.2
	world.hud._toast_left = 0.0
	await create_timer(0.8).timeout
	var arena := await _sample(5.0)
	print("PERF_ARENA avg_fps=%.1f p95_frame_ms=%.2f p95_fps=%.1f boss_state=%s hp=%.0f" % [
		arena["fps"], arena["p95"], arena["min"], str(world.boss.state), world.player.hp])
	print("DREAM_PARRY_PERF_OK avg_arena_fps=%.1f" % arena["fps"])
	world.queue_free()
	await process_frame
	quit(0)


func _sample(seconds: float) -> Dictionary:
	var frames := 0
	var samples: Array[float] = []
	var start := Time.get_ticks_usec()
	var last := start
	while float(Time.get_ticks_usec() - start) / 1_000_000.0 < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - last) / 1000.0)
		last = now
		frames += 1
	var elapsed := float(Time.get_ticks_usec() - start) / 1_000_000.0
	samples.sort()
	var p95 := samples[clampi(int(float(samples.size()) * 0.95), 0, samples.size() - 1)] if not samples.is_empty() else 0.0
	return {
		"fps": float(frames) / maxf(elapsed, 0.001),
		"p95": p95,
		"min": 1000.0 / p95 if p95 > 0.0 else 0.0,
	}
