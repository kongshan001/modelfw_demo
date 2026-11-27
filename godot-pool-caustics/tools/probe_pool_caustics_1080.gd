extends SceneTree

# 1920×1080 离屏渲染性能（Proof of 1080p support；主验收仍是 1280×720 窗口）。
# 用法：godot --path godot-pool-caustics -s tools/probe_pool_caustics_1080.gd

const SIZE := Vector2i(1920, 1080)
const WARM_FRAMES := 20
const MEASURE_FRAMES := 120

var _vp: SubViewport
var _scene


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	_scene.get_hud().set_ui_scale(1.5)
	_scene.set_ui_visible(true)
	_scene.get_hud().set_minimal(false)
	_scene.set_time_override(5.0)
	await create_timer(0.8).timeout
	for mode in range(7):
		_scene.set_debug_mode(mode)
		await _wait_frames(2)
	_scene.set_debug_mode(0)
	_scene.set_variant(1)
	await _wait_frames(4)
	_scene.set_variant(0)
	await _wait_frames(WARM_FRAMES)

	var t0 := Time.get_ticks_usec()
	for i in MEASURE_FRAMES:
		await process_frame
	var elapsed := float(Time.get_ticks_usec() - t0) / 1_000_000.0
	var fps := float(MEASURE_FRAMES) / maxf(elapsed, 0.0001)
	var ms := elapsed * 1000.0 / float(MEASURE_FRAMES)
	var dc := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("POOL_CAUSTICS_PROBE_1080 resolution=%dx%d fps=%.1f ms=%.2f engine_fps=%d dc=%d samples=%d" % [
			SIZE.x, SIZE.y, fps, ms, Engine.get_frames_per_second(), dc, MEASURE_FRAMES])
	print("POOL_CAUSTICS_PROBE_1080_OK")
	quit(0)


func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame
