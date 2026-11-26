extends SceneTree

# T-20261126-011 QA 验收脚本（独立于游戏逻辑，仅测试）。
# 1) 1280×720 / 1920×1080 主构图与岸线微距截图；2) 通过 Viewport.push_input 走真实输入路径：
# 左键拖拽尾迹、单击落石水花、右键轨道、滚轮缩放、H/Space/R/C、F4/F7/F8；3) 参数面板与重置值核对。
# 另导出 splash/trail 帧到 /tmp/qa_splash_frames 供编码 GIF。
# 用法：godot --path godot-stylized-ocean-v2 -s tools/qa_acceptance_stylized_ocean.gd

const OUT := "res://docs/qa"
const FRAME_OUT := "/tmp/qa_splash_frames"
const S720 := Vector2i(1280, 720)
const S1080 := Vector2i(1920, 1080)
const STEP := 1.0 / 30.0
const GSTEP := 1.0 / 15.0

var vp: SubViewport
var scene
var _fails: Array[String] = []
var _checks := 0
var _splash_seen := {"splashes": 0, "rings": 0, "falling": 0, "floating": 0}


func _init() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(FRAME_OUT)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp = SubViewport.new()
	vp.size = S720
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	scene = load("res://scenes/main.tscn").instantiate()
	vp.add_child(scene)
	await create_timer(0.8).timeout
	scene.set_paused(true)
	scene.set_ui_visible(false)
	scene.set_hour(11.5)
	scene.ocean.clear_ripples()
	scene.set_camera_target(0.0, 3.0, 0.4)
	scene.set_camera_orbit(90.0, 58.0, 116.0)
	_tick(60)

	# ── 1. 视觉：1280×720 主构图 / 岸线微距 / 礁石小岛 ───────────────
	await _shot("qa_01_wide_1280")
	scene.set_camera_target(0.0, 27.0, 0.2)
	scene.set_camera_orbit(70.0, 40.0, 24.0)
	_tick(30)
	await _shot("qa_02_shore_macro_1280")
	scene.set_camera_target(13.0, 30.0, 0.2)
	scene.set_camera_orbit(100.0, 42.0, 24.0)
	_tick(30)
	await _shot("qa_03_rock_isle_1280")

	# ── 2. 视觉：1920×1080 同机位 ────────────────────────────────────
	vp.size = S1080
	scene.set_camera_target(0.0, 3.0, 0.4)
	scene.set_camera_orbit(90.0, 58.0, 116.0)
	_tick(40)
	await _shot("qa_04_wide_1920")
	scene.set_camera_target(0.0, 27.0, 0.2)
	scene.set_camera_orbit(70.0, 40.0, 24.0)
	_tick(30)
	await _shot("qa_05_shore_macro_1920")
	vp.size = S720
	_tick(10)

	# ── 3. 交互：左键拖拽尾迹（真实 push_input 路径）+ 单击落石水花 ──
	scene.set_camera_target(0.0, 29.0, 0.15)
	scene.set_camera_orbit(90.0, 55.0, 46.0)
	_tick(20)
	scene.ocean.clear_ripples()
	await _shot("qa_06_ripple_before")

	var p0 := Vector2(500, 470)
	var h0: Dictionary = scene.get_camera_rig().screen_to_water(p0)
	_check(h0["valid"], "drag start point should hit water")
	scene.ocean.clear_ripples()
	_push_button(MOUSE_BUTTON_LEFT, true, p0)
	await process_frame
	_check(scene._paint_down, "left press should enter painting state")
	for i in 15:
		var px := 500.0 + float(i) * 17.0
		var py := 470.0 + sin(float(i) * 0.5) * 10.0
		_push_motion(Vector2(px, py), Vector2(17.0, 0.0))
		_advance(GSTEP)
		await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/drag_%03d.png" % [FRAME_OUT, i])
	var trail_n: int = scene.ocean.ripples.size()
	print("QA trail_ripples=", trail_n)
	_check(trail_n >= 4, "drag should spawn a trail of ripples (got %d)" % trail_n)
	_advance(0.28)
	await _shot("qa_07_ripple_drag_after")
	_push_button(MOUSE_BUTTON_LEFT, false, Vector2(738, 470))
	await process_frame
	_check(scene._falling.is_empty(), "long drag should not drop a rock")

	# 单击落石：按下/抬起间隔走同一事件路径，<240ms 且位移 <9px
	var click_pos := Vector2(700, 430)
	var hc: Dictionary = scene.get_camera_rig().screen_to_water(click_pos)
	_check(hc["valid"], "click point should hit water")
	var before_fall: int = scene._falling.size()
	_push_button(MOUSE_BUTTON_LEFT, true, click_pos)
	_push_button(MOUSE_BUTTON_LEFT, false, click_pos)
	await process_frame
	_check(scene._falling.size() == before_fall + 1, "quick click should drop one rock")
	var landed := false
	for i in 36:
		_advance(GSTEP)
		if scene._falling.is_empty() and (scene._splashes.size() > 0 or scene._rings.size() > 0):
			landed = true
		_splash_seen["splashes"] = maxi(_splash_seen["splashes"], scene._splashes.size())
		_splash_seen["rings"] = maxi(_splash_seen["rings"], scene._rings.size())
		_splash_seen["falling"] = maxi(_splash_seen["falling"], scene._falling.size())
		_splash_seen["floating"] = maxi(_splash_seen["floating"], scene._floating.size())
		await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/splash_%03d.png" % [FRAME_OUT, i])
		if i == 14:
			await _shot("qa_08_click_splash")
	print("QA splash_seen=", _splash_seen)
	_check(landed, "rock should land and produce splash/ring")
	_check(_splash_seen["floating"] >= 1, "landed rock should float briefly")
	_check(_splash_seen["splashes"] >= 1, "splash particles spawned")

	# ── 4. 交互：右键轨道 / 滚轮缩放 ─────────────────────────────────
	scene.ocean.clear_ripples()
	scene.set_camera_target(0.0, 20.0, 0.6)
	scene.set_camera_orbit(90.0, 52.0, 70.0)
	_tick(10)
	await _shot("qa_09_camera_before")
	var cam = scene.get_camera_rig()
	var yaw0: float = cam.yaw_deg
	var pitch0: float = cam.pitch_deg
	var dist0: float = cam.distance
	_push_button(MOUSE_BUTTON_RIGHT, true, Vector2(640, 360))
	_push_motion(Vector2(740, 405), Vector2(100, 45))
	_push_button(MOUSE_BUTTON_RIGHT, false, Vector2(740, 405))
	_push_button(MOUSE_BUTTON_WHEEL_UP, true, Vector2(740, 405))
	await process_frame
	_tick(10)
	print("QA camera yaw %.1f->%.1f pitch %.1f->%.1f dist %.1f->%.1f" % [
		yaw0, cam.yaw_deg, pitch0, cam.pitch_deg, dist0, cam.distance])
	_check(absf(cam.yaw_deg - yaw0) > 10.0, "right drag should orbit yaw")
	_check(absf(cam.pitch_deg - pitch0) > 3.0, "right drag should change pitch")
	_check(cam.distance < dist0, "wheel up should zoom in")
	await _shot("qa_10_camera_after")

	# ── 5. 键盘：调试视图 F4/F7/F8、H/Space/R/C ──────────────────────
	scene.set_camera_target(0.0, 27.0, 0.2)
	scene.set_camera_orbit(70.0, 40.0, 24.0)
	_tick(20)
	_push_key(KEY_F4)
	await process_frame
	_check(scene.debug_view == 3, "F4 -> debug foam (view 3)")
	_tick(5)
	await _shot("qa_11_debug_foam")
	_push_key(KEY_F7)
	await process_frame
	_check(scene.debug_view == 6, "F7 -> shore SDF (view 6)")
	_tick(5)
	await _shot("qa_12_debug_sdf")
	_push_key(KEY_F8)
	await process_frame
	_check(scene.debug_view == 7, "F8 -> shore layers (view 7)")
	_tick(5)
	await _shot("qa_13_debug_shore_layers")
	_push_key(KEY_F1)
	await process_frame
	_check(scene.debug_view == 0, "F1 -> debug off")

	var hud = scene.get_hud()
	var ui0: bool = hud.visible
	_push_key(KEY_H)
	await process_frame
	_check(hud.visible != ui0, "H should toggle UI (was %s)" % ui0)
	_push_key(KEY_H)
	await process_frame
	_check(hud.visible == ui0, "H should restore UI")
	var pause0: bool = scene.paused
	_push_key(KEY_SPACE)
	await process_frame
	_check(scene.paused != pause0, "Space should toggle pause")
	_push_key(KEY_SPACE)
	await process_frame
	_check(scene.paused == pause0, "Space should restore pause")
	var orbit0: bool = cam.auto_orbit
	_push_key(KEY_C)
	await process_frame
	_check(cam.auto_orbit != orbit0, "C should toggle auto orbit")
	_push_key(KEY_C)
	await process_frame
	_check(cam.auto_orbit == orbit0, "C should restore auto orbit")

	_push_key(KEY_R)
	await process_frame
	_check(scene.get_ui_state()["rain"], "R should enable rain")
	await create_timer(0.9).timeout
	_tick(10)
	await _shot("qa_14_rain")
	_push_key(KEY_R)
	await process_frame
	_check(not scene.get_ui_state()["rain"], "R should disable rain")

	# ── 6. 参数面板 + 重置值核对 ─────────────────────────────────────
	scene.set_paused(true)
	scene.set_hour(11.5)
	scene.set_camera_target(0.0, 3.0, 0.4)
	scene.set_camera_orbit(90.0, 58.0, 116.0)
	scene.ocean.clear_ripples()
	scene.set_ui_visible(true)
	scene.set_ui_scale(1.0)
	scene.set_panel_open(true)
	scene.set_paused(false)
	await create_timer(1.2).timeout
	scene.set_paused(true)
	scene.get_hud().refresh_from_world()
	scene._update_stats_label()
	_tick(2)
	await _shot("qa_15_ui_panel")

	# 改参后重置，逐项核对（对照 README / TECH）
	scene.set_hour(20.4)
	scene.ocean.set_wave_height(1.6)
	scene.ocean.set_wave_speed(0.4)
	scene.ocean.set_wave_direction(140.0)
	scene.ocean.set_foam_amount(1.5)
	scene.ocean.set_sun_glint(1.9)
	scene.set_water_style(2)
	scene.set_rain(true)
	scene.set_auto_orbit(false)
	scene.set_debug_view(5)
	scene.reset_params()
	await process_frame
	var st: Dictionary = scene.get_ui_state()
	print("QA reset_state=", st)
	_check(is_equal_approx(st["hour"], 11.5), "reset hour")
	_check(is_equal_approx(st["wave_height"], 0.72), "reset wave height")
	_check(is_equal_approx(st["wave_speed"], 1.0), "reset wave speed")
	_check(is_equal_approx(st["wave_dir"], 18.0), "reset wave direction")
	_check(is_equal_approx(st["foam"], 0.85), "reset foam")
	_check(is_equal_approx(st["sun_glint"], 1.0), "reset sun glint (code default)")
	_check(st["rain"] == false, "reset rain")
	_check(st["auto_orbit"] == true, "reset auto orbit")
	_check(st["debug"] == 0, "reset debug view")
	_check(st["style"] == 0, "reset water style")
	_check(is_equal_approx(st["distance"], 108.0), "reset camera distance (code default)")
	_check(scene.ocean.ripples.is_empty(), "reset ripples")

	# ── 7. 太阳高光 1280×720：统计水面亮斑像素，避免“看不见的闪点” ──
	scene.set_ui_visible(false)
	scene.set_hour(11.5)
	scene.set_clouds_visible(false)
	scene.ocean.set_sun_glint(2.0)
	scene.set_camera_target(0.0, 62.0, 0.0)
	scene.set_camera_orbit(90.0, 44.0, 55.0)
	_tick(20)
	var glint_img: Image = await _shot("qa_17_sun_glint_1280")
	# 只统计水面区域（去掉画面顶部 30% 的海岛/沙滩与鼠标光标环），避免把沙/泡沫算成闪点
	var bright := 0
	var gw := glint_img.get_width()
	var gh := glint_img.get_height()
	for y in range(int(gh * 0.30), gh, 2):
		for x in range(0, gw, 2):
			if Vector2(x, y).distance_to(Vector2(738, 400)) < 70.0:
				continue
			var c := glint_img.get_pixel(x, y)
			if 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b > 0.90:
				bright += 1
	print("QA sun_glint_water_bright_px_sampled=", bright)
	_check(bright > 100, "sun glint should show visible sparkles on water (sampled bright px=%d)" % bright)
	scene.ocean.set_sun_glint(1.0)
	scene.set_clouds_visible(true)

	# ── 8. 夜景岸线 1280×720（补充时相覆盖） ─────────────────────────
	scene.set_hour(20.4)
	scene.set_camera_target(0.0, 27.0, 0.2)
	scene.set_camera_orbit(70.0, 40.0, 26.0)
	_tick(20)
	await _shot("qa_16_night_shore_1280")
	scene.set_hour(11.5)

	print("QA checks=", _checks, " fails=", _fails.size())
	if _fails.is_empty():
		print("STYLIZED_OCEAN_QA_OK")
		quit(0)
	else:
		for f in _fails:
			printerr("QA FAIL: ", f)
		print("STYLIZED_OCEAN_QA_FAILED")
		quit(1)


func _tick(n: int) -> void:
	for i in n:
		scene.tick(STEP)


func _advance(seconds: float) -> void:
	var steps := maxi(1, int(round(seconds / STEP)))
	for i in steps:
		scene.tick(STEP)


func _shot(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + "/" + name + ".png"))
	print("QA shot ", name, " ", img.get_width(), "x", img.get_height())
	return img


func _push_button(button: MouseButton, pressed: bool, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev)


func _push_motion(pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = rel
	vp.push_input(ev)


func _push_key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = keycode
	vp.push_input(ev)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("QA PASS: ", msg)
	else:
		_fails.append(msg)
		print("QA FAIL: ", msg)
