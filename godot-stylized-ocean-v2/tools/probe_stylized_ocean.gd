extends SceneTree

# 性能探针：真实 GPU（Intel HD 6000），vsync 关，固定机位。
# 测 1280×720 默认 / 雨 / UI，以及 1920×1080 默认；输出平均 FPS 与 draw calls。
# 用法：godot --path godot-stylized-ocean-v2 -s tools/probe_stylized_ocean.gd

const OUT := "/tmp/ocean_v2_probe"

var vp: SubViewport
var scene


func _init() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/main.tscn").instantiate()
	vp.add_child(scene)
	await create_timer(1.2).timeout
	scene.set_ui_visible(false)
	scene.set_paused(false)
	scene.set_camera_orbit(90.0, 58.0, 116.0)
	scene.set_hour(11.5)
	await create_timer(1.5).timeout

	await _measure("1280x720_default", 110)
	scene.set_rain(true)
	await create_timer(0.6).timeout
	await _measure("1280x720_rain", 90)
	scene.set_rain(false)
	await create_timer(0.4).timeout
	scene.set_ui_visible(true)
	scene.set_ui_scale(1.0)
	await create_timer(0.5).timeout
	await _measure("1280x720_ui", 80)
	scene.set_ui_visible(false)
	vp.size = Vector2i(1920, 1080)
	await create_timer(0.8).timeout
	await _measure("1920x1080_default", 60)
	print("STYLIZED_OCEAN_PROBE_OK")
	quit(0)


func _measure(label: String, frames: int) -> void:
	await RenderingServer.frame_post_draw
	var t0 := Time.get_ticks_usec()
	for i in frames:
		await RenderingServer.frame_post_draw
	var dt := (Time.get_ticks_usec() - t0) / 1_000_000.0
	var fps := float(frames) / maxf(dt, 0.0001)
	var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var v := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	print("PERF %s frames=%d time=%.2fs avg_fps=%.1f draw_calls=%d objects=%d viewport=%dx%d" % [
		label, frames, dt, fps, dc, v, vp.size.x, vp.size.y])
