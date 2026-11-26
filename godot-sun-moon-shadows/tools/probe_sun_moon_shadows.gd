extends SceneTree

# 真实 GPU 像素/性能探针（不 headless）：
#   * 08:00 两棵树的影子重叠点 vs 单影点：用「开影 / 关影」两次渲染反解
#     阴影 alpha，验证重叠只覆盖一层；
#   * 21:00 冷蓝月影 + 暖黄路灯池同时存在，灯池内仍能看到月影；
#   * 1280×720 与 1920×1080 的 FPS。
# 运行：godot --path godot-sun-moon-shadows --resolution 1280x720 -s tools/probe_sun_moon_shadows.gd

const SHOT_DIR := "res://docs/shots/probe"
const VW := 1280
const VH := 720
var _fails: Array[String] = []
var _checks := 0
var _vp: SubViewport
var _scene


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp = _make_viewport(VW, VH)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(0.9).timeout
	_scene.set_playing(false)
	_scene.set_ui_visible(false)
	_scene.set_hour(8.0)
	await _settle()
	await _test_overlap_pixels()
	await _test_night_pixels()
	await _test_fps()
	await _cleanup()
	if _fails.is_empty():
		print("PROBE checks=%d fails=0" % _checks)
		print("SUN_MOON_SHADOW_PROBE_OK")
		quit(0)
	else:
		for f in _fails:
			printerr("PROBE_FAIL: ", f)
		print("SUN_MOON_SHADOW_PROBE_FAIL fails=%d checks=%d" % [_fails.size(), _checks])
		quit(1)


func _make_viewport(w: int, h: int) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_2d = Viewport.MSAA_DISABLED
	vp.snap_2d_transforms_to_pixel = true
	vp.snap_2d_vertices_to_pixel = true
	root.add_child(vp)
	return vp


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


func _settle() -> void:
	await create_timer(0.15).timeout
	await process_frame


func _capture() -> Image:
	await create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	return _vp.get_texture().get_image()


func _px(img: Image, p: Vector2) -> Color:
	var scale := float(_vp.size.x) / 640.0
	var x := clampi(int(p.x * scale), 1, img.get_width() - 2)
	var y := clampi(int(p.y * scale), 1, img.get_height() - 2)
	var c := Color(0, 0, 0, 0)
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			c += img.get_pixel(x + dx, y + dy)
			n += 1
	return c / float(n)


func _luma(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


func _test_overlap_pixels() -> void:
	_scene.set_hour(8.0)
	_scene.set_shadows_enabled(true)
	await _settle()
	var world = _scene.get_world()
	var probe: Dictionary = world.refresh_overlap_probe()
	_check(bool(probe.get("found", false)), "08:00 tree shadow overlap must exist")
	if not bool(probe.get("found", false)):
		return
	var pair: Array = probe["pair"]
	_check(pair.has("oak") and pair.has("pine"), "overlap pair must be oak+pine")
	var p_single: Vector2 = probe["single_point"]
	var p_overlap: Vector2 = probe["overlap_point"]
	_check(int(probe["overlap_coverage"]) == 1, "overlap point union coverage = 1")
	_check(int(probe["single_coverage"]) == 1, "single point union coverage = 1")
	var img_on: Image = await _capture()
	img_on.save_png(SHOT_DIR + "/probe_overlap_on.png")
	var crop := img_on.get_region(Rect2i(
			clampi(int(p_single.x * 2) - 70, 0, img_on.get_width() - 240),
			clampi(int(p_single.y * 2) - 60, 0, img_on.get_height() - 160),
			240, 160))
	crop.save_png(SHOT_DIR + "/probe_overlap_crop.png")
	_scene.set_shadows_enabled(false)
	await _settle()
	var img_off: Image = await _capture()
	img_off.save_png(SHOT_DIR + "/probe_overlap_off.png")
	_scene.set_shadows_enabled(true)
	await _settle()
	var sc: Color = _scene.get_global_uniform("u_ambient_sub")
	var a_single := _solve_alpha(_px(img_off, p_single), _px(img_on, p_single), sc)
	var a_overlap := _solve_alpha(_px(img_off, p_overlap), _px(img_on, p_overlap), sc)
	print("PROBE_OVERLAP single=%s overlap=%s alpha_single=%.3f alpha_overlap=%.3f config=%.3f" % [
		str(p_single), str(p_overlap), a_single, a_overlap, sc.a])
	_check(a_single > 0.1, "single shadow pixel must actually darken")
	_check(absf(a_overlap - a_single) < 0.025,
			"overlap darkness must match single (%.3f vs %.3f)" % [a_overlap, a_single])
	_check(absf(a_overlap - sc.a) < 0.04,
			"overlap alpha must be one layer, not two (%.3f vs %.3f)" % [a_overlap, sc.a])
	var dark_single := _luma(_px(img_off, p_single)) - _luma(_px(img_on, p_single))
	var dark_overlap := _luma(_px(img_off, p_overlap)) - _luma(_px(img_on, p_overlap))
	print("PROBE_OVERLAP_DARK single_luma=%.3f overlap_luma=%.3f" % [
		dark_single, dark_overlap])
	_check(dark_single > 0.015 and dark_overlap > 0.015,
			"both probe points must show shadow darkening")


func _solve_alpha(bg: Color, shadowed: Color, shadow_color: Color) -> float:
	var vals: Array[float] = []
	var bgs: Array[float] = [bg.r, bg.g, bg.b]
	var shs: Array[float] = [shadowed.r, shadowed.g, shadowed.b]
	var scs: Array[float] = [shadow_color.r, shadow_color.g, shadow_color.b]
	for ch in 3:
		var b := bgs[ch]
		var s := shs[ch]
		var c := scs[ch]
		if absf(b - c) > 0.03:
			vals.append((b - s) / (b - c))
	if vals.is_empty():
		return 0.0
	var sum := 0.0
	for v in vals:
		sum += clampf(v, 0.0, 1.0)
	return sum / float(vals.size())


func _test_night_pixels() -> void:
	_scene.set_hour(21.0)
	_scene.set_shadows_enabled(true)
	_scene.set_lamps_enabled(true)
	await _settle()
	var world = _scene.get_world()
	_check(world.get_moon_sprite().visible, "moon visible at 21:00")
	_check(world.are_lamps_on(), "lamps on at 21:00")
	var img_on: Image = await _capture()
	img_on.save_png(SHOT_DIR + "/probe_night_on.png")
	# 找一个地面月影点：避开两盏灯池，高度 0，开/关影亮度差明显。
	_scene.set_shadows_enabled(false)
	await _settle()
	var img_off: Image = await _capture()
	_scene.set_shadows_enabled(true)
	await _settle()
	var lamp_points: Array[Vector2] = [Vector2(150, 310), Vector2(548, 300)]
	var shadow_pt := Vector2(-1, -1)
	var best_delta := 0.0
	for y in range(250, 335, 2):
		for x in range(190, 610, 2):
			var p := Vector2(x, y)
			if world.sample_height_px(p) > 3.0:
				continue
			var far := 999.0
			for lp in lamp_points:
				far = minf(far, p.distance_to(lp))
			if far < 72.0:
				continue
			var d := _luma(_px(img_off, p)) - _luma(_px(img_on, p))
			if d > best_delta:
				best_delta = d
				shadow_pt = p
	_check(shadow_pt.x >= 0.0, "must find an open-ground moon shadow pixel")
	if shadow_pt.x >= 0.0:
		var cs := _px(img_on, shadow_pt)
		var cb := _px(img_off, shadow_pt)
		print("PROBE_NIGHT_SHADOW p=%s on=%s off=%s delta=%.3f" % [
			str(shadow_pt), cs.to_html(false), cb.to_html(false), best_delta])
		_check(best_delta > 0.012, "moon shadow must darken the ground")
		_check(cs.b >= cs.r, "moon shadow pixel must be cool (B>=R)")
	# 灯池内的月影仍可见 + 找一个真正暖色的灯池点。
	var pool_shadow := Vector2(-1, -1)
	var pool_delta := 0.0
	var lamp_pt := Vector2(548, 298)
	var warm_score := -999.0
	for y in range(280, 335, 1):
		for x in range(500, 610, 1):
			var p := Vector2(x, y)
			if world.sample_height_px(p) > 3.0:
				continue
			if p.distance_to(Vector2(548, 300)) > 46.0:
				continue
			var c := _px(img_on, p)
			var score := (c.r - c.b) + _luma(c) * 0.3
			if score > warm_score:
				warm_score = score
				lamp_pt = p
			var d := _luma(_px(img_off, p)) - _luma(_px(img_on, p))
			if d > pool_delta:
				pool_delta = d
				pool_shadow = p
	_check(pool_shadow.x >= 0.0 and pool_delta > 0.006,
			"moon shadow must remain visible inside a warm lamp pool")
	if pool_shadow.x >= 0.0:
		print("PROBE_NIGHT_POOL_SHADOW p=%s delta=%.3f on=%s off=%s" % [
			str(pool_shadow), pool_delta, _px(img_on, pool_shadow).to_html(false),
			_px(img_off, pool_shadow).to_html(false)])
	var cl := _px(img_on, lamp_pt)
	_check(cl.r > cl.b, "lamp pool pixel must be warm (R>B)")
	print("PROBE_NIGHT_LAMP p=%s lit=%s" % [
		str(lamp_pt), cl.to_html(false)])
	# 路灯开关：关掉后灯池点明显变暗。
	_scene.set_lamps_enabled(false)
	await _settle()
	var img_lamps_off: Image = await _capture()
	_scene.set_lamps_enabled(true)
	await _settle()
	var c_off := _px(img_lamps_off, lamp_pt)
	_check(_luma(cl) > _luma(c_off) + 0.02, "lamps off must remove warm pool light")
	img_lamps_off.save_png(SHOT_DIR + "/probe_night_lamp_off.png")


func _test_fps() -> void:
	_scene.set_hour(9.0)
	_scene.set_playing(true)
	_scene.set_ui_visible(true)
	await _settle()
	var fps1280 := await _measure(_vp, 3.0)
	print("PROBE_FPS viewport=1280x720 avg=%.1f" % fps1280)
	_check(fps1280 >= 30.0, "1280x720 FPS >= 30 (got %.1f)" % fps1280)
	# 1920×1080 离屏。
	var big := _make_viewport(1920, 1080)
	var big_scene = load("res://scenes/main.tscn").instantiate()
	big.add_child(big_scene)
	await process_frame
	await create_timer(0.8).timeout
	big_scene.set_playing(true)
	big_scene.set_hour(9.0)
	await create_timer(0.3).timeout
	var fps1920 := await _measure(big, 3.0)
	print("PROBE_FPS viewport=1920x1080 avg=%.1f" % fps1920)
	_check(fps1920 >= 30.0, "1920x1080 FPS >= 30 (got %.1f)" % fps1920)
	print("PROBE_SCALE hud_scale_1920=%s world_scale=%s" % [
		str(big_scene.get_node("HUD").scale), str(big_scene.get_pixel_scale())])
	big_scene.queue_free()
	big.queue_free()
	await process_frame


func _measure(vp: SubViewport, seconds: float) -> float:
	var t0 := Time.get_ticks_usec()
	var frames := 0
	while float(Time.get_ticks_usec() - t0) < seconds * 1000000.0:
		await process_frame
		frames += 1
	var elapsed := float(Time.get_ticks_usec() - t0) / 1000000.0
	return float(frames) / maxf(elapsed, 0.001)


func _cleanup() -> void:
	if _scene != null:
		_scene.queue_free()
	if _vp != null:
		_vp.queue_free()
	await process_frame
