extends SceneTree

# 真实 GPU 1920×1080 离屏（SubViewport）性能探针。macOS 窗口会被屏幕尺寸裁切，
# 因此 1080p 用离屏渲染；这不是“窗口实际分辨率”的测量，但反映渲染成本。
# 用法：godot --path godot-hd2d -s tools/probe_hd2d_1080.gd

const SIZE := Vector2i(1920, 1080)
const SECONDS := 2.5
var _scene: Node
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
	print("PROBE1080 viewport=", _vp.size, " pixel_scale=", _scene.pixel_scale)
	await _measure("post_on", true)
	await _measure("post_off", false)
	print("PROBE_HD2D_1080_OK")
	quit(0)


func _measure(label: String, post: bool) -> void:
	_scene.set_post_enabled(post)
	_scene.set_paused(false)
	await create_timer(0.4).timeout
	var frames := 0
	var elapsed := 0.0
	var min_fps := 100000.0
	var max_draws := 0
	var start := Time.get_ticks_usec()
	var last := start
	while elapsed < SECONDS:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000000.0
		last = now
		elapsed = float(now - start) / 1000000.0
		frames += 1
		if dt > 0.0:
			min_fps = minf(min_fps, 1.0 / dt)
		max_draws = maxi(max_draws, int(Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	print("%s avg_fps=%.1f min_fps=%.1f max_draws=%d frames=%d"
			% [label, float(frames) / elapsed, min_fps, max_draws, frames])
