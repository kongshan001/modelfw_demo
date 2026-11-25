extends SceneTree

# 真实 GPU 帧率探针：关闭垂直同步，编辑器 + 运行预览各采样一段时间。
# 运行：godot --path godot-level-editor --resolution 1280x720 -s tools/probe_level_editor.gd

const EditorScene := preload("res://scenes/editor.tscn")


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var editor: Control = EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	await create_timer(2.0).timeout
	editor.canvas.fit_view()
	editor.update_zoom_label()

	var fps_edit := await _sample(4.0)
	editor.open_preview()
	await create_timer(1.0).timeout
	var fps_preview := await _sample(3.0)
	var min_fps: float = minf(fps_edit["min"], fps_preview["min"])
	var avg_fps: float = (float(fps_edit["avg"]) + float(fps_preview["avg"])) / 2.0
	var passed: bool = float(fps_edit["avg"]) >= 30.0 and float(fps_preview["avg"]) >= 30.0

	print("PROBE window=", DisplayServer.window_get_size(), " driver=", RenderingServer.get_video_adapter_name())
	print("PROBE editor avg=%.1f p5=%.1f min=%.1f frames=%d" % [fps_edit["avg"], fps_edit["p5"], fps_edit["min"], fps_edit["frames"]])
	print("PROBE preview avg=%.1f p5=%.1f min=%.1f frames=%d" % [fps_preview["avg"], fps_preview["p5"], fps_preview["min"], fps_preview["frames"]])
	print("LEVEL_EDITOR_FPS avg=%.1f min=%.1f target_avg=30 %s" % [avg_fps, min_fps, "OK" if passed else "LOW"])
	quit(0)


func _sample(seconds: float) -> Dictionary:
	var started := Time.get_ticks_msec()
	var last := started
	var intervals: Array[float] = []
	var frames := 0
	while Time.get_ticks_msec() - started < int(seconds * 1000.0):
		await process_frame
		frames += 1
		var now := Time.get_ticks_msec()
		var delta := float(now - last)
		if delta > 0.0:
			intervals.append(1000.0 / delta)
		last = now
	if intervals.is_empty():
		return {"avg": 0.0, "min": 0.0, "frames": frames}
	intervals.sort()
	var total := 0.0
	for fps in intervals:
		total += fps
	var p5_index := clampi(int(float(intervals.size()) * 0.05), 0, intervals.size() - 1)
	return {
		"avg": total / float(intervals.size()),
		"p5": intervals[p5_index],
		"min": intervals[0],
		"frames": frames,
	}
