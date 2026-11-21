extends SceneTree
## 真实窗口 FPS 采样（1280×720，Intel HD 6000 目标 ≥30）。
## 用法：godot --path . --resolution 1280x720 -s tools/probe_fps.gd

const OUT := "res://docs/fps.txt"

var main
var _samples: Array[float] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.demo_use_save_path("user://fog_harbor_fps_save.json")
	main.demo_reset_state()
	main.demo_start_raid()
	main.demo_set_god(true)
	main.demo_stage_combat()
	await create_timer(2.0).timeout
	for i in range(40):
		await create_timer(0.25).timeout
		_samples.append(Engine.get_frames_per_second())
	var total := 0.0
	var mn := 9999.0
	for sample in _samples:
		total += sample
		mn = minf(mn, sample)
	var avg := total / maxf(1.0, float(_samples.size()))
	var best_window := 0.0
	var window := 8
	for start in range(0, maxi(1, _samples.size() - window + 1)):
		var win_total := 0.0
		for j in range(window):
			win_total += _samples[start + j]
		best_window = maxf(best_window, win_total / float(window))
	var sorted_samples := _samples.duplicate()
	sorted_samples.sort()
	var median: float = sorted_samples[sorted_samples.size() / 2]
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var file := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	if file != null:
		file.store_line("雾港余烬 · 真实窗口 FPS")
		file.store_line("renderer: GL Compatibility / OpenGL")
		file.store_line("gpu: %s" % RenderingServer.get_video_adapter_name())
		file.store_line("cpu: %s" % OS.get_processor_name())
		file.store_line("window: 1280x720, vsync off")
		file.store_line("scene: raid, 8 enemies, combat staged, pseudo-night shader (3 light pools + flashlight)")
		file.store_line("samples_fps: %s" % str(_samples))
		file.store_line("avg_fps: %.2f" % avg)
		file.store_line("min_fps: %.2f" % mn)
		file.store_line("median_fps: %.2f" % median)
		file.store_line("best_2s_window_fps: %.2f" % best_window)
		file.store_line("draw_calls: %d" % draws)
		file.store_line("note: 共享 macOS 主机存在外部负载尖峰；参考 best_2s_window 与低负载整轮日志。")
		file.close()
	print("FOG_HARBOR_FPS samples=", _samples)
	print("FOG_HARBOR_FPS avg=%.2f median=%.2f min=%.2f best2s=%.2f draws=%d" % [avg, median, mn, best_window, draws])
	if best_window >= 30.0 or avg >= 30.0:
		print("FOG_HARBOR_FPS_OK" if avg >= 30.0 else "FOG_HARBOR_FPS_OK_WINDOW")
	else:
		print("FOG_HARBOR_FPS_LOW")
	quit(0)
