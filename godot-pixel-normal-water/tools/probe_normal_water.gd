extends SceneTree

# 1280×720 原生窗口性能探针：关垂直同步，分别测世界层与带 HUD。
# 用法：godot --path godot-pixel-normal-water --resolution 1280x720 -s tools/probe_normal_water.gd

const DURATION := 4.0
const DURATION_HUD := 3.0

var _scene


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await create_timer(1.5).timeout

	print("PROBE resolution=%s cameras=%d reflection_quads=%d"
			% [str(root.size),
			_scene.find_children("*", "Camera2D", true, false).size(),
			_scene.get_reflection_quad_count()])
	_scene.set_ui_visible(false)
	await create_timer(0.5).timeout
	await _read_draw_calls("world_only")
	var world: Dictionary = await _measure("world_only_default", DURATION)
	_scene.set_ui_visible(true)
	await create_timer(0.5).timeout
	await _read_draw_calls("with_hud")
	var hud: Dictionary = await _measure("with_hud", DURATION_HUD)
	print("NORMAL_WATER_PROBE_RESULT world_avg=%.1f world_min=%.1f hud_avg=%.1f hud_min=%.1f" % [
		world["avg"], world["min"], hud["avg"], hud["min"]])
	if float(world["avg"]) >= 30.0 and float(hud["avg"]) >= 30.0:
		print("NORMAL_WATER_PROBE_OK")
		quit(0)
	else:
		printerr("NORMAL_WATER_PROBE_FAIL: below 30 fps")
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
