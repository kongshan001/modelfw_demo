extends SceneTree

# 1920×1080 离屏 FPS 探针（macOS 桌面会裁大窗口，所以用 SubViewport）。
# 用法：godot --path godot-sakura-sunlight -s tools/probe_sakura_sunlight_1080.gd

const SIZE := Vector2i(1920, 1080)
const DURATION := 4.0

var _scene
var _vp: SubViewport


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	_vp.snap_2d_transforms_to_pixel = true
	_vp.snap_2d_vertices_to_pixel = true
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(1.0).timeout
	_scene.set_hour(9.0)
	_scene.set_playing(true)
	_scene.set_ui_visible(true)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var hud = _scene.get_node("HUD")
	print("PROBE_1080 viewport=%s hud_scale=%s world=640x360" % [
		str(_vp.size), str(hud.scale)])
	var result := await _measure("sakura_sunlight_1080", DURATION)
	print("PROBE_1080_RESULT res=%s avg=%.1f min=%.1f draws=%d" % [
		str(SIZE), result["avg"], result["min"], draws])
	if float(result["avg"]) >= 30.0:
		print("SAKURA_SUNLIGHT_PROBE_1080_OK")
		quit(0)
	else:
		printerr("SAKURA_SUNLIGHT_PROBE_1080_FAIL avg=%.1f" % result["avg"])
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
	return {"avg": avg, "min": low if low < 9999.0 else avg}
