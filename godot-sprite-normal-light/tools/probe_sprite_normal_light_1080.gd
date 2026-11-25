extends SceneTree

# 1920×1080 真实 GPU 性能探针：borderless 根窗口放大到 1920 后挪到屏幕外。
# 用法：godot --path godot-sprite-normal-light -s tools/probe_sprite_normal_light_1080.gd

const SIZE := Vector2i(1920, 1080)

var _scene


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(SIZE)
	DisplayServer.window_set_position(Vector2i(-240, -120))
	await process_frame
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await create_timer(1.2).timeout
	_scene.set_playing(false)
	_scene.set_auto_orbit(false)
	_scene.set_light_angle(330.0)
	await create_timer(0.5).timeout
	print("PROBE1080 root=%s driver=%s" % [
		str(root.size), RenderingServer.get_video_adapter_name()])
	await _read_draw_calls("with_hud")
	var hud: Dictionary = await _measure("shader_with_hud", 4.0)
	_scene.set_ui_visible(false)
	await create_timer(0.4).timeout
	var world: Dictionary = await _measure("shader_world_only", 3.0)
	_scene.set_native_mode(true)
	await create_timer(0.4).timeout
	var native: Dictionary = await _measure("native_world_only", 2.5)
	_scene.set_native_mode(false)
	var lowest: float = minf(minf(hud["avg"], world["avg"]), native["avg"])
	print("SPRITE_NORMAL_LIGHT_PROBE_1080_RESULT hud_avg=%.1f hud_min=%.1f world_avg=%.1f world_min=%.1f native_avg=%.1f native_min=%.1f lowest_avg=%.1f" % [
		hud["avg"], hud["min"], world["avg"], world["min"],
		native["avg"], native["min"], lowest])
	if lowest >= 30.0:
		print("SPRITE_NORMAL_LIGHT_PROBE_1080_OK")
		quit(0)
	else:
		printerr("SPRITE_NORMAL_LIGHT_PROBE_1080_FAIL: below 30 fps")
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
	print("DRAW_CALLS %s total=%d" % [label,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
