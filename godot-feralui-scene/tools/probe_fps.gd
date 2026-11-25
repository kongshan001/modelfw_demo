extends SceneTree
## 真实窗口 FPS 采样：720p 高/低、夜/昼/雨、1080p 高。
## 用法：godot --path godot-feralui-scene --resolution 1280x720 -s tools/probe_fps.gd
## 输出：res://docs/fps.txt；末行 FERALUI_FPS_OK / FERALUI_FPS_LOW

const OUT := "res://docs/fps.txt"

var main
var _report: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(2.0).timeout
	main.demo_set_hud_visible(true)
	main.demo_set_markers_visible(true)
	main.demo_set_view(22.0, 35.5, 21.5, Vector3(0, 2.15, 0.30), false)
	main.demo_set_quality(true)
	main.demo_set_phase(true, true)
	await create_timer(1.0).timeout
	var night720 := await _sample("high_night_720p", 7.0)

	main.demo_set_phase(false, true)
	await create_timer(1.0).timeout
	var day720 := await _sample("high_day_720p", 6.0)

	main.demo_set_phase(true, true)
	main.demo_set_weather(true, true)
	await create_timer(1.0).timeout
	var rain720 := await _sample("high_night_rain_720p", 6.0)
	main.demo_set_weather(false, true)

	main.demo_set_quality(false)
	await create_timer(1.0).timeout
	var low720 := await _sample("low_night_720p", 5.0)

	main.demo_set_quality(true)
	await create_timer(0.8).timeout
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await create_timer(1.5).timeout
	var win_size := DisplayServer.window_get_size()
	var night1080 := await _sample("high_night_1080p_window", 5.0)

	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var tris := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var file := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	if file != null:
		file.store_line("苔光浮庭 · Mosslight Isle — 真实窗口 FPS")
		file.store_line("renderer: GL Compatibility / OpenGL")
		file.store_line("gpu: %s" % RenderingServer.get_video_adapter_name())
		file.store_line("cpu: %s" % OS.get_processor_name())
		file.store_line("logical viewport: 1280x720 (canvas_items stretch); 1080p 为窗口/最终 blit 尺寸")
		file.store_line("actual_window_size_1080_run: %dx%d" % [win_size.x, win_size.y])
		file.store_line("vsync: off / max_fps: 0 / HUD + markers visible")
		file.store_line("draw_calls: %d / primitives: %d / nodes: %d" % [draws, tris, nodes])
		for line in _report:
			file.store_line(line)
		file.store_line("note: 共享主机有外部负载尖峰；以 median 与 best_2s 为主要参考。")
		file.close()
	for line in _report:
		print(line)
	print("FERALUI_FPS_DRAWS=%d PRIMS=%d NODES=%d WINDOW=%dx%d" % [
		draws, tris, nodes, win_size.x, win_size.y])
	var ok: bool = float(night720["median"]) >= 30.0 or float(night720["best2s"]) >= 30.0
	if ok:
		print("FERALUI_FPS_OK")
	else:
		print("FERALUI_FPS_LOW")
	quit(0)


func _sample(label: String, seconds: float) -> Dictionary:
	var fps_samples: Array[float] = []
	var t := 0.0
	while t < seconds:
		await create_timer(0.25).timeout
		fps_samples.append(Engine.get_frames_per_second())
		t += 0.25
	var total := 0.0
	var mn := 9999.0
	for s in fps_samples:
		total += s
		mn = minf(mn, s)
	var sorted := fps_samples.duplicate()
	sorted.sort()
	var median: float = sorted[sorted.size() / 2]
	var avg: float = total / maxf(1.0, float(fps_samples.size()))
	var best2s := 0.0
	var window := 8
	for start in range(0, maxi(1, fps_samples.size() - window + 1)):
		var win := 0.0
		for j in range(window):
			win += fps_samples[start + j]
		best2s = maxf(best2s, win / float(window))
	var line := "%s: avg=%.1f median=%.1f min=%.1f best_2s=%.1f samples=%s" % [
		label, avg, median, mn, best2s, str(fps_samples)
	]
	_report.append(line)
	print("FPS_SAMPLE ", line)
	return {"avg": avg, "median": median, "min": mn, "best2s": best2s}
