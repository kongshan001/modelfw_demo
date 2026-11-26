extends SceneTree

# 真实 GPU 性能探针（无截图回读干扰）：
# 1280×720 窗口 + 640×360 内部 RT；再用 1920×1080 合成 SubViewport
# 模拟 1920 显示器上的最终放大 + HUD 成本。关闭垂直同步。

const MAIN_SCENE := "res://scenes/main.tscn"
var main
var cap: SubViewport
var cap_hud


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(50, 50))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	var packed: PackedScene = load(MAIN_SCENE)
	main = packed.instantiate()
	root.add_child(main)
	await create_timer(2.0).timeout
	var a := await _measure(4.0)
	await create_timer(0.4).timeout
	var draw_a: int = main.get_draw_calls()
	print("PERF_1280 avg=%.1f min=%.1f max=%.1f frames=%d draw=%d rt=%dx%d" % [
		a["avg"], a["min"], a["max"], a["frames"], draw_a, main.internal_size.x, main.internal_size.y])

	# 1920×1080 合成（3× 最近邻 + 1920 HUD）
	cap = SubViewport.new()
	cap.size = Vector2i(1920, 1080)
	cap.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cap.msaa_2d = Viewport.MSAA_DISABLED
	cap.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	cap.gui_disable_input = true
	cap.handle_input_locally = false
	root.add_child(cap)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.035)
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(bg)
	var world_rect := TextureRect.new()
	world_rect.texture = main.composite_viewport.get_texture()
	world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_rect.stretch_mode = TextureRect.STRETCH_SCALE
	world_rect.size = Vector2(1920, 1080)
	world_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(world_rect)
	cap_hud = load("res://scripts/hud.gd").new()
	cap_hud.layer = 10
	cap.add_child(cap_hud)
	cap_hud.setup(main)
	await create_timer(1.5).timeout
	var b := await _measure(4.0)
	await create_timer(0.4).timeout
	var draw_b: int = main.get_draw_calls()
	print("PERF_1920_SUBPORT avg=%.1f min=%.1f max=%.1f frames=%d draw=%d" % [
		b["avg"], b["min"], b["max"], b["frames"], draw_b])
	print("PERF_NOTE 1920 is a real-GPU 1920x1080 SubViewport composition (screen is 1440x900)")
	print("PERF_DONE")
	_cleanup()
	quit(0)


func _measure(seconds: float) -> Dictionary:
	var start := Time.get_ticks_usec()
	var last := start
	var frames := 0
	var min_fps := 1.0e9
	var max_fps := 0.0
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000000.0
		last = now
		if dt > 0.000001:
			var f := 1.0 / dt
			min_fps = minf(min_fps, f)
			max_fps = maxf(max_fps, f)
		frames += 1
		var elapsed := float(now - start) / 1000000.0
		if elapsed >= seconds:
			return {
				"avg": float(frames) / elapsed,
				"min": min_fps,
				"max": max_fps,
				"frames": frames,
			}
	return {"avg": 0.0, "min": 0.0, "max": 0.0, "frames": 0}


func _cleanup() -> void:
	if cap != null:
		root.remove_child(cap)
		cap.queue_free()
	if main != null:
		root.remove_child(main)
		main.queue_free()
	await process_frame
