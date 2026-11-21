extends SceneTree

# T-20261121-007 性能探针：试衣镜 Studio 单次重绘 CPU 成本（2.1×，非 mini）。
# 24Hz 重绘预算：≤16ms/次（与缩略图烘焙同预算）；目标中位 ≤9ms。
# 用法：godot --path . --resolution 1280x720 -s tools/material_probe.gd


func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(1.2).timeout
	var studio = scene.get_studio()
	if studio == null:
		printerr("MATERIAL_PROBE_NO_STUDIO")
		quit(1)
		return
	var samples: Array[int] = []
	for i in 24:
		studio.set_clock(0.4 + float(i) * 0.07)
		studio.queue_redraw()
		await RenderingServer.frame_post_draw
		samples.append(int(studio.last_draw_usec))
	samples.sort()
	var med := samples[samples.size() / 2]
	var p90 := samples[int(float(samples.size()) * 0.9)]
	var total := 0
	for s in samples:
		total += s
	print("MATERIAL_PROBE studio_draw_median_ms=%.2f p90_ms=%.2f max_ms=%.2f avg_ms=%.2f samples=%d"
			% [float(med) / 1000.0, float(p90) / 1000.0, float(samples[-1]) / 1000.0,
			float(total) / float(samples.size()) / 1000.0, samples.size()])
	if med <= 16000:
		print("MATERIAL_PROBE_OK")
		quit(0)
	else:
		printerr("MATERIAL_PROBE_SLOW")
		quit(1)
