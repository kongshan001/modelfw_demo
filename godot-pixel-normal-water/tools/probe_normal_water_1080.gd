extends SceneTree

# 1920×1080 性能探针。macOS 的普通窗口会被裁到桌面，因此把 borderless
# 根窗口放到屏幕外并设为 1920×1080 —— 仍然是 root viewport + 单 Camera2D，
# 不创建 SubViewport，也不额外加相机；场景内容按 canvas_items 1.5× 缩放。
# 用法：godot --path godot-pixel-normal-water -s tools/probe_normal_water_1080.gd

const DURATION := 4.0

var _scene


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_position(Vector2i(-240, -120))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await process_frame
	print("PROBE_1080 resolution=%s" % str(root.size))
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await create_timer(2.0).timeout

	_scene.set_ui_visible(false)
	await create_timer(0.5).timeout
	await _read_draw_calls("world_only_1080")
	var world: Dictionary = await _measure("offscreen_window_1920x1080_world", DURATION)
	_scene.set_ui_visible(true)
	await create_timer(0.5).timeout
	await _read_draw_calls("with_hud_1080")
	var hud: Dictionary = await _measure("offscreen_window_1920x1080_hud", DURATION)
	print("NORMAL_WATER_1080_RESULT world_avg=%.1f world_min=%.1f hud_avg=%.1f hud_min=%.1f"
			% [world["avg"], world["min"], hud["avg"], hud["min"]])
	if float(world["avg"]) >= 30.0 and float(hud["avg"]) >= 30.0:
		print("NORMAL_WATER_1080_PROBE_OK")
		quit(0)
	else:
		printerr("NORMAL_WATER_1080_PROBE_FAIL: below 30 fps")
		quit(1)


func _measure(label: String, duration: float) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var frames := 0
	var last_t := t0
	var last_frames := 0
	var per_sec: Array[float] = []
	while float(Time.get_ticks_usec() - t0) < duration * 1000000.0:
		await process_frame
		frames += 1
		var now := Time.get_ticks_usec()
		if now - last_t >= 1000000:
			per_sec.append(float(frames - last_frames) * 1000000.0 / float(now - last_t))
			last_t = now
			last_frames = frames
	var elapsed := float(Time.get_ticks_usec() - t0) / 1000000.0
	var avg := float(frames) / maxf(elapsed, 0.001)
	var low := 9999.0
	for s in per_sec:
		low = minf(low, s)
	print("%s: avg=%.1f min=%.1f frames=%d per_sec=%s" % [
		label, avg, low if low < 9999.0 else avg, frames, str(per_sec)])
	return {"avg": avg, "min": low}


func _read_draw_calls(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var total := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("DRAW_CALLS %s total=%d primitives=%d" % [label, total, prims])
