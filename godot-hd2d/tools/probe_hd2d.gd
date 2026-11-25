extends SceneTree

# 真实 GPU 1280×720 性能探针：移轴开/关各测 2.5s；关闭 VSync。
# 用法：godot --path godot-hd2d --resolution 1280x720 -s tools/probe_hd2d.gd

const SECONDS := 2.5
var _scene: Node


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await create_timer(1.0).timeout
	print("PROBE viewport=", root.get_visible_rect().size, " render=",
			root.get_texture().get_size())
	await _measure("post_on", true)
	await _measure("post_off", false)
	print("PROBE_HD2D_OK")
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
		var draws: int = int(Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		max_draws = maxi(max_draws, draws)
	var avg := float(frames) / elapsed
	print("%s avg_fps=%.1f min_fps=%.1f max_draws=%d frames=%d"
			% [label, avg, min_fps, max_draws, frames])
