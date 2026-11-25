extends SceneTree

# 1080p 离屏探针：macOS 会把大窗口裁到桌面尺寸，因此用 1920×1080 的
# SubViewport 强制 GPU 按 1080p 渲染，窗口只做承载（比真实全屏略保守）。
# 用法：godot --path godot-rain-puddles -s tools/probe_rain_puddles_1080.gd

const DURATION := 4.0
const SIZE := Vector2i(1920, 1080)

var _scene
var _vp: SubViewport


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	_scene.get_node("HUD").scale = Vector2(1.5, 1.5)
	await create_timer(1.0).timeout
	_scene.set_rain_intensity(1.0)
	_scene.set_density(360)
	_scene.set_wet_level(1.0)
	_scene.set_ui_visible(false)
	await create_timer(0.6).timeout
	await _read_draw_calls("world_only_1080")
	var world: Dictionary = await _measure("offscreen_1920x1080_world_only", DURATION)
	_scene.set_density(600)
	await create_timer(0.3).timeout
	var heavy: Dictionary = await _measure("offscreen_1920x1080_600rain", DURATION)
	_scene.set_density(360)
	_scene.set_ui_visible(true)
	await create_timer(0.3).timeout
	await _read_draw_calls("with_hud_1080")
	var hud: Dictionary = await _measure("offscreen_1920x1080_with_hud", DURATION)
	print("RAIN_PUDDLES_1080_RESULT world_avg=%.1f world_min=%.1f heavy_avg=%.1f hud_avg=%.1f" % [
		world["avg"], world["min"], heavy["avg"], hud["avg"]])
	if float(world["avg"]) >= 30.0 and float(hud["avg"]) >= 30.0:
		print("RAIN_PUDDLES_1080_PROBE_OK")
		quit(0)
	else:
		printerr("RAIN_PUDDLES_1080_PROBE_FAIL: below 30 fps")
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
