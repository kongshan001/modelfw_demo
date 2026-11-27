extends SceneTree

# 真实 GPU 性能探针：1280×720 窗口 + 640×360 内部 RT；
# 再以 1920×1080 SubViewport 合成（模拟 1080p 输出 + HUD）测量。
# 关闭垂直同步，测试期间关闭截图回读。

const MAIN_SCENE := "res://scenes/main.tscn"
var main
var cap: SubViewport
var cap_hud


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(40, 40))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	var packed: PackedScene = load(MAIN_SCENE)
	main = packed.instantiate()
	root.add_child(main)
	main.set_param("auto", false)
	main.set_time_of_day(0.92)
	main.world.keeper.set_walk_preview(true, 1.0)
	await create_timer(2.0).timeout
	var a := await _measure(5.0)
	await create_timer(0.3).timeout
	print("PERF_1280 avg=%.1f min=%.1f max=%.1f frames=%d draw=%d rt=%dx%d fps_engine=%d" % [
		a["avg"], a["min"], a["max"], a["frames"], main.get_draw_calls(),
		main.internal_size.x, main.internal_size.y, main.get_fps()])

	# 1920×1080 合成：640×360 ×3 + 全分辨率 HUD（真实 GPU）
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
	cap.add_child(bg)
	var world_rect := TextureRect.new()
	world_rect.texture = main.post_viewport.get_texture()
	world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_rect.stretch_mode = TextureRect.STRETCH_SCALE
	world_rect.size = Vector2(1920, 1080)
	cap.add_child(world_rect)
	cap_hud = load("res://scripts/hud.gd").new()
	cap_hud.layer = 11
	cap.add_child(cap_hud)
	cap_hud.setup(main)
	await create_timer(1.5).timeout
	var b := await _measure(5.0)
	await create_timer(0.3).timeout
	print("PERF_1920_SUBPORT avg=%.1f min=%.1f max=%.1f frames=%d draw=%d" % [
		b["avg"], b["min"], b["max"], b["frames"], main.get_draw_calls()])
	print("PERF_NOTE 1920x1080 is a real-GPU SubViewport composition (physical screen may be smaller)")
	print("PERF_DONE")
	_cleanup()
	quit(0)


func _measure(seconds: float) -> Dictionary:
	var start := Time.get_ticks_usec()
	var last := start
	var frames := 0
	var min_fps := 1.0e9
	var max_fps := 0.0
	var min_dt := 1.0e9
	var max_dt := 0.0
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000000.0
		last = now
		if dt > 0.0000001:
			var fps := 1.0 / dt
			min_fps = minf(min_fps, fps)
			max_fps = maxf(max_fps, fps)
			min_dt = minf(min_dt, dt)
			max_dt = maxf(max_dt, dt)
		frames += 1
		if float(now - start) / 1000000.0 >= seconds:
			break
	var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
	var avg := float(frames) / maxf(elapsed, 0.0001)
	return {"avg": avg, "min": min_fps, "max": max_fps, "frames": frames}


func _cleanup() -> void:
	if cap != null:
		root.remove_child(cap)
		cap.queue_free()
	if main != null:
		root.remove_child(main)
		main.queue_free()
	await process_frame
