extends SceneTree

## 真实 GPU 性能测量：100 / 1000 / 3000 单位，1280×720 与 1920×1080。
## 运行：godot --path godot-swarm-autobattler -s tools/perf_swarm.gd
## 测量在 SubViewport 中进行（窗口可被 macOS 限制，SubViewport 渲染分辨率为准）。
## 输出：docs/perf_measurements.json + 末行 SWARM_PERF_OK

const OUT_JSON := "res://docs/perf_measurements.json"
const SHOT := "res://docs/shots/05_perf_debug.png"

var sv: SubViewport
var holder: Control
var game
var results: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	sv = SubViewport.new()
	sv.size = Vector2i(1280, 720)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(sv)
	holder = Control.new()
	holder.size = Vector2(1280, 720)
	holder.scale = Vector2.ONE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(holder)
	game = load("res://scenes/main.tscn").instantiate()
	holder.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	print("PERF adapter=", RenderingServer.get_video_adapter_name(), " renderer=", RenderingServer.get_video_adapter_api_version())

	for res in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		_set_resolution(res)
		for units in [100, 1000, 3000]:
			await _measure(res, units)

	var f := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"adapter": RenderingServer.get_video_adapter_name(),
			"renderer": RenderingServer.get_video_adapter_api_version(),
			"engine": Engine.get_version_info(),
			"timestamp": Time.get_datetime_string_from_system(),
			"results": results,
		}, "  "))
		f.close()
	print("PERF_JSON=", ProjectSettings.globalize_path(OUT_JSON))
	print("SWARM_PERF_OK")
	game.queue_free()
	await process_frame
	sv.queue_free()
	quit(0)


func _set_resolution(res: Vector2i) -> void:
	sv.size = res
	holder.scale = Vector2(float(res.x) / 1280.0, float(res.y) / 720.0)
	await process_frame
	await process_frame


func _measure(res: Vector2i, units: int) -> void:
	game.debug_perf_overlay(false)
	game.debug_hide_toast()
	game.debug_mount_battle(units, 0.0, false, false, false)
	game.debug_get_view().set_speed(1.0)
	# 预热：至少 20 帧，避开首帧纹理/节点初始化。
	for i in 6:
		await process_frame
	var view = game.debug_get_view()
	var t0 := Time.get_ticks_usec()
	var last := t0
	var deltas: Array[float] = []
	var draws_max := 0
	var frames := 0
	while Time.get_ticks_usec() - t0 < 1800000 and frames < 900:
		await process_frame
		var now := Time.get_ticks_usec()
		deltas.append(float(now - last) / 1000.0)
		last = now
		frames += 1
		draws_max = maxi(draws_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	var elapsed := float(Time.get_ticks_usec() - t0) / 1000000.0
	var sum := 0.0
	var max_dt := 0.001
	for d in deltas:
		sum += d
		max_dt = maxf(max_dt, d)
	var avg_dt := sum / maxf(1.0, float(deltas.size()))
	var avg_fps := 1000.0 / maxf(0.001, avg_dt)
	var min_fps := 1000.0 / max_dt
	var total_units: int = view.total_units()
	var entry := {
		"resolution": "%dx%d" % [res.x, res.y],
		"units": total_units,
		"units_target": units,
		"frames": deltas.size(),
		"wall_s": snappedf(elapsed, 0.01),
		"fps_avg": snappedf(avg_fps, 0.1),
		"fps_min": snappedf(min_fps, 0.1),
		"engine_fps": snappedf(float(Performance.get_monitor(Performance.TIME_FPS)), 0.1),
		"draw_calls_max": draws_max,
		"sim_ms_avg": snappedf(view.avg_sim_ms(), 0.01),
		"render_ms_avg": snappedf(view.avg_render_ms(), 0.01),
		"fx_active": view._fx_active,
		"seed": int(view.battle.seed_value) if view.battle != null else 0,
	}
	results.append(entry)
	print("PERF %s units=%d avg_fps=%.1f min_fps=%.1f draw=%d sim=%.2fms render=%.2fms frames=%d" % [
		entry["resolution"], total_units, avg_fps, min_fps, draws_max,
		entry["sim_ms_avg"], entry["render_ms_avg"], deltas.size()])
	# 3000 单位 / 1080p 时保留一张带 perf 叠层的实拍。
	if res == Vector2i(1920, 1080) and units == 3000:
		game.debug_perf_overlay(true)
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = sv.get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png(ProjectSettings.globalize_path(SHOT))
			print("PERF_SHOT=", ProjectSettings.globalize_path(SHOT), " ", img.get_size())
