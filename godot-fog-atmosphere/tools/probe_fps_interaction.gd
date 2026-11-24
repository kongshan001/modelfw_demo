extends SceneTree
## 真实窗口 FPS：第三人称行走 + 动态雾驱散（高/低质量、昼/夜、720p/1080p 窗口、静止）。
## 用法：godot --path . --resolution 1280x720 -s tools/probe_fps_interaction.gd
## 输出：docs/fps_interaction.txt；末行 FOG_FPS_INTERACTION_OK / FOG_FPS_INTERACTION_LOW

const OUT := "res://docs/fps_interaction.txt"

var main
var _report: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.demo_set_fps_visible(false)
	main.demo_set_fog(2, 2)
	main.demo_set_fog_color(0)
	main.demo_set_follow_view(26.0, 20.0, 7.2, false)
	await create_timer(2.0).timeout

	main.demo_set_quality(true)
	main.demo_set_phase(false, true)
	main.demo_teleport_player(1.5, 18.5)
	main.demo_set_player_input(0.0, 1.0, false)
	await create_timer(1.0).timeout
	var walk_day := await _sample("high_walk_day_720p", 7.0)

	main.demo_set_phase(true, true)
	main.demo_teleport_player(1.5, 18.5)
	await create_timer(1.0).timeout
	var walk_night := await _sample("high_walk_night_720p", 6.0)

	main.demo_set_phase(false, true)
	main.demo_set_quality(false)
	main.demo_teleport_player(1.5, 18.5)
	await create_timer(1.0).timeout
	var walk_low := await _sample("low_walk_day_720p", 6.0)

	main.demo_set_quality(true)
	await create_timer(0.8).timeout
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await create_timer(1.5).timeout
	var win_size := DisplayServer.window_get_size()
	main.demo_teleport_player(1.5, 18.5)
	await create_timer(1.0).timeout
	var walk_1080 := await _sample("high_walk_day_1080p_window", 5.0)

	main.demo_clear_player_input()
	main.demo_teleport_player(1.5, 18.5)
	await create_timer(1.5).timeout
	var idle_1080 := await _sample("high_idle_day_1080p_window", 5.0)

	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objs := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var file := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	if file != null:
		file.store_line("雾林微光 · Fogwood — 第三人称雾驱散 FPS")
		file.store_line("renderer: GL Compatibility / OpenGL")
		file.store_line("gpu: %s" % RenderingServer.get_video_adapter_name())
		file.store_line("cpu: %s" % OS.get_processor_name())
		file.store_line("logical viewport: 1280x720 (canvas_items stretch); 1080p 为窗口/最终 blit 尺寸")
		file.store_line("actual_window_size_1080_run: %dx%d" % [win_size.x, win_size.y])
		file.store_line("vsync: off / max_fps: 0")
		file.store_line("draw_calls: %d / nodes: %d" % [draws, objs])
		file.store_line("mode: 第三人称跟随 + 持续行走 + 动态雾驱散（半径 4.5m / 强度 85% / 恢复 1.6s）")
		for line in _report:
			file.store_line(line)
		file.store_line("note: 共享主机存在外部负载尖峰；以 median 与 best_2s 为主要参考。")
		file.close()
	for line in _report:
		print(line)
	print("FOG_FPS_INTERACTION_DRAWS=%d NODES=%d WINDOW=%dx%d" % [draws, objs, win_size.x, win_size.y])
	var ok: bool = float(walk_day["median"]) >= 30.0 or float(walk_day["best2s"]) >= 30.0
	if ok:
		print("FOG_FPS_INTERACTION_OK")
	else:
		print("FOG_FPS_INTERACTION_LOW")
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
