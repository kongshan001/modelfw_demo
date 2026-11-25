extends SceneTree

# 真实 GPU 探针（不使用 editor-only 的 global_shader_parameter_get）：
#   1) 校验 main 记录下来的全局光参数（写入 RenderingServer 的同一条路径）；
#   2) 连续抓 08:00 / 12:00 / 16:36 / 阴影开/关 的帧，比较像素差异，
#      证明全局光参数确实改变了世界渲染，而不是逐物传参；
#   3) 关闭 VSync，测 4s 平均/最低 FPS 与 draw calls。
# 用法：godot --path godot-sakura-sunlight --resolution 1280x720 -s tools/probe_sakura_sunlight.gd

const DURATION := 4.0

var _scene


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await create_timer(1.0).timeout
	_scene.set_playing(false)

	# 全局光镜像值（main 在写 RenderingServer 的同一函数里同步）。
	_scene.set_hour(8.0)
	var g8: Vector2 = _scene.get_global_uniform("u_sun_dir")
	var e8: float = _scene.get_global_uniform("u_sun_elevation")
	var c8: Color = _scene.get_global_uniform("u_sun_color")
	_scene.set_hour(17.0)
	var g17: Vector2 = _scene.get_global_uniform("u_sun_dir")
	var e17: float = _scene.get_global_uniform("u_sun_elevation")
	var c17: Color = _scene.get_global_uniform("u_sun_color")
	_scene.set_shadows_enabled(false)
	var sh_off: float = _scene.get_global_uniform("u_shadow_strength")
	_scene.set_shadows_enabled(true)
	var sh_on: float = _scene.get_global_uniform("u_shadow_strength")
	var mirror_ok := (g8 - SunModel.sun_plane_dir(8.0)).length() < 0.001 \
			and absf(e8 - 35.0) < 0.05 \
			and c8 != c17 and c8.r > c8.b and c17.r > c17.b \
			and absf(sh_off) < 0.001 and absf(sh_on - 1.0) < 0.001
	print("PROBE_GLOBAL mirror=%s g8=%s e8=%.2f g17=%s e17=%.2f" % [
		"OK" if mirror_ok else "FAIL", str(g8), e8, str(g17), e17])

	# 真实 GPU 像素对比：全局光/阴影开关必须改变世界渲染。
	_scene.set_ui_visible(false)
	_scene.set_petals_enabled(false)
	var img8 := await _capture(8.0)
	var img12 := await _capture(12.0)
	var img17 := await _capture(16.6)
	_scene.set_hour(14.0)
	_scene.set_shadows_enabled(true)
	var sh_on_img := await _capture(14.0)
	_scene.set_shadows_enabled(false)
	var sh_off_img := await _capture(14.0)
	var d_mn := _mean_diff(img8, img12)
	var d_ne := _mean_diff(img12, img17)
	var d_sh := _mean_diff(sh_on_img, sh_off_img)
	var visual_ok := d_mn > 0.10 and d_ne > 0.10 and d_sh > 0.01
	print("PROBE_VISUAL morning_noon=%.3f noon_evening=%.3f shadow_on_off=%.3f %s" % [
		d_mn, d_ne, d_sh, "OK" if visual_ok else "FAIL"])

	# FPS / draw calls：回到 09:00，持续播放，UI 打开。
	_scene.set_shadows_enabled(true)
	_scene.set_petals_enabled(true)
	_scene.set_ui_visible(true)
	_scene.set_hour(9.0)
	_scene.set_speed(1.0)
	_scene.set_playing(true)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var vp_size := root.size
	var result := await _measure("sakura_sunlight", DURATION)
	print("PROBE_RESULT res=%s avg=%.1f min=%.1f draws=%d" % [
		str(vp_size), result["avg"], result["min"], draws])
	if float(result["avg"]) >= 30.0 and mirror_ok and visual_ok:
		print("SAKURA_SUNLIGHT_PROBE_OK")
		quit(0)
	else:
		printerr("SAKURA_SUNLIGHT_PROBE_FAIL avg=%.1f mirror=%s visual=%s" % [
			result["avg"], str(mirror_ok), str(visual_ok)])
		quit(1)


func _capture(hour: float) -> Image:
	_scene.set_hour(hour)
	await process_frame
	await create_timer(0.06).timeout
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _mean_diff(a: Image, b: Image) -> float:
	if a == null or b == null:
		return 0.0
	# 在世界中部取一块（避开 HUD 左上/右下），随窗口分辨率缩放。
	var w := mini(a.get_width(), b.get_width())
	var h := mini(a.get_height(), b.get_height())
	var rect := Rect2i(int(w * 0.36), int(h * 0.30),
			int(w * 0.36), int(h * 0.42))
	var total := 0.0
	var count := 0
	for y in range(rect.position.y, rect.position.y + rect.size.y, 4):
		for x in range(rect.position.x, rect.position.x + rect.size.x, 4):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			count += 1
	return total / float(maxi(count, 1))


func _measure(label: String, duration: float) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var frames := 0
	var last_t := t0
	var last_frames := 0
	var per_sec: Array[float] = []
	while float(Time.get_ticks_usec() - t0) < duration * 1000000.0:
		await process_frame
		frames += 1
		var now := Time.get_ticks_usec()
		if now - last_t >= 1000000:
			per_sec.append(float(frames - last_frames) * 1000000.0 / float(now - last_t))
			last_t = now
			last_frames = frames
	var elapsed := float(Time.get_ticks_usec() - t0) / 1000000.0
	var avg := float(frames) / maxf(elapsed, 0.001)
	var low := 9999.0
	for s in per_sec:
		low = minf(low, s)
	print("%s: avg=%.1f min=%.1f frames=%d per_sec=%s" % [
		label, avg, low if low < 9999.0 else avg, frames, str(per_sec)])
	return {"avg": avg, "min": low if low < 9999.0 else avg}
