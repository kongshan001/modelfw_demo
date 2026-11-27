extends SceneTree

# 真实 GPU 性能探测：1280×720 窗口，预热并轮询全部 shader 分支后测 240 帧。
# 用法：godot --path godot-pool-caustics --resolution 1280x720 -s tools/probe_pool_caustics.gd
# 输出 POOL_CAUSTICS_PROBE_OK fps=... ms=... dc=...。

const WARM_FRAMES := 25
const MEASURE_FRAMES := 240

var _scene


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await create_timer(1.2).timeout

	# 先让每个调试分支、两个变体都编译/跑过，避免首帧编译污染。
	for mode in range(7):
		_scene.set_debug_mode(mode)
		await _wait_frames(3)
	_scene.set_debug_mode(0)
	_scene.set_variant(1)
	await _wait_frames(6)
	_scene.set_variant(0)
	_scene.set_search_3x3(false)
	await _wait_frames(3)
	_scene.set_search_3x3(true)
	_scene.set_ui_visible(true)
	_scene.get_hud().set_minimal(false)
	_scene.get_hud().set_stats_visible(true)
	_scene.set_time_override(5.2)
	await _wait_frames(WARM_FRAMES)

	var t0 := Time.get_ticks_usec()
	for i in MEASURE_FRAMES:
		await process_frame
	var elapsed := float(Time.get_ticks_usec() - t0) / 1_000_000.0
	var fps := float(MEASURE_FRAMES) / maxf(elapsed, 0.0001)
	var ms := elapsed * 1000.0 / float(MEASURE_FRAMES)
	var dc := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var engine_fps := Engine.get_frames_per_second()
	var res := DisplayServer.window_get_size()
	print("POOL_CAUSTICS_PROBE resolution=%dx%d fps=%.1f ms=%.2f engine_fps=%d dc=%d samples=%d" % [
			res.x, res.y, fps, ms, engine_fps, dc, MEASURE_FRAMES])
	if fps < 30.0:
		printerr("POOL_CAUSTICS_PROBE_FAIL fps below 30")
		quit(1)
		return
	print("POOL_CAUSTICS_PROBE_OK")
	quit(0)


func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame
