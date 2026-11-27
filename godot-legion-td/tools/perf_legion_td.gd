extends SceneTree

## Real-GPU perf probe: average FPS / frame time over a staged wave.
## Run 720p window:  godot --path godot-legion-td --resolution 1280x720 -s tools/perf_legion_td.gd
## Run 1080p render: LEGION_PERF_1080=1 godot --path godot-legion-td -s tools/perf_legion_td.gd
## Optional 3D scale: LEGION_3D_SCALE=0.75 ...
## Last line: LEGION_TD_PERF_OK

const D := preload("res://scripts/legion_data.gd")
const SECONDS := 8.0

var game
var sv: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var use_1080 := OS.get_environment("LEGION_PERF_1080") == "1"
	var scale := float(OS.get_environment("LEGION_3D_SCALE")) if OS.get_environment("LEGION_3D_SCALE") != "" else 1.0
	if use_1080:
		sv = SubViewport.new()
		sv.size = Vector2i(1920, 1080)
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sv.scaling_3d_scale = scale
		root.add_child(sv)
	else:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	if use_1080:
		sv.add_child(game)
	else:
		root.add_child(game)
	for i in 5:
		await process_frame
	if use_1080:
		game.ui.scale = Vector2(1.5, 1.5)
	game.debug_lock_camera = true
	# 场景：八个塔 + 第 4 波敌人 + 初始小队。
	game.debug_add_resources(2000, 200)
	for i in 8:
		game.select_pad(i)
		game.build_tower_at_selected(D.TOWER_ORDER[i % 3])
	game.debug_start_wave(4)
	game.simulate(4.0)
	game.world.set_camera(Vector3(0, 0, 18), 42.0)
	for i in 10:
		await process_frame

	var start := Time.get_ticks_usec()
	var frames := 0
	var frame_times: Array[float] = []
	var last := start
	while (Time.get_ticks_usec() - start) < int(SECONDS * 1_000_000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append((now - last) / 1000.0)
		last = now
		frames += 1
	var elapsed := (Time.get_ticks_usec() - start) / 1_000_000.0
	var avg := frames / elapsed
	frame_times.sort()
	var p95: float = frame_times[int(frame_times.size() * 0.95)] if not frame_times.is_empty() else 0.0
	var worst: float = frame_times[-1] if not frame_times.is_empty() else 0.0
	print("PERF_RES=%s scale=%.2f frames=%d seconds=%.2f avg_fps=%.1f p95_ms=%.2f worst_ms=%.2f" % [
		"1920x1080-subviewport" if use_1080 else "1280x720-window",
		scale, frames, elapsed, avg, p95, worst])
	print("PERF_DRAW_CALLS=%d" % RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	print("LEGION_TD_PERF_OK")
	game.queue_free()
	await process_frame
	if sv != null:
		sv.queue_free()
	quit(0)
