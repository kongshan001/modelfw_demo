extends SceneTree

# 真实 GPU 截图：1920×1080 合成（640×360 世界 ×3 最近邻 + 全分辨率 HUD）。
# 屏幕物理分辨率不足 1920 时，用 SubViewport 合成，仍是真实 GPU 渲染。

const MAIN_SCENE := "res://scenes/main.tscn"
const HUD_SCRIPT := preload("res://scripts/hud.gd")
const OUT_DIR := "res://docs/shots"

var main
var cap: SubViewport
var cap_world: TextureRect
var cap_hud


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var abs_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(30, 30))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	var packed: PackedScene = load(MAIN_SCENE)
	main = packed.instantiate()
	root.add_child(main)
	await _frames(90)
	main.set_param("auto", false)
	main.set_param("internal_index", 2)
	main.set_ui_visible(false)
	# 1080p 合成时，HUD 的 ×N 标示按 1920/640 = 3 显示。
	main.hud_scale_override = 3
	await _frames(8)
	_setup_capture_viewport()
	await _frames(8)

	# 01 黄昏第三人称（默认跟随相机，角色行走）
	main.set_time_of_day(0.20)
	main.world.keeper.teleport(Vector3(0.75, 0.15, 7.0), 0.0)
	main.world.keeper.set_walk_preview(true, 1.2)
	main.reset_camera()
	main.cam_yaw = -12.0
	main.cam_pitch = 20.0
	main.cam_dist = 7.6
	main.clear_camera_override()
	main.prewarm(1.5)
	await _shot("01_dusk_thirdperson.png", false)

	# 02 落日 / 光柱
	main.set_time_of_day(0.30)
	main.world.keeper.teleport(Vector3(0.5, 0.15, -3.0), 0.0)
	main.world.keeper.set_walk_preview(true, 1.1)
	main.set_camera_override(Vector3(0.6, 1.8, -6.2), 8.0, 19.0, 12.0)
	main.prewarm(1.2)
	await _shot("02_sunset_beams.png", false)

	# 03 深夜第三人称（路灯全亮 + 萤火 + 星空）
	main.set_time_of_day(0.94)
	main.world.keeper.teleport(Vector3(0.75, 0.15, 7.0), 0.0)
	main.world.keeper.set_walk_preview(false)
	main.reset_camera()
	main.cam_yaw = -8.0
	main.cam_pitch = 20.0
	main.cam_dist = 8.2
	main.clear_camera_override()
	main.prewarm(2.0)
	await _shot("03_night_thirdperson.png", false)

	# 04 路灯特写（暖光、地面光池、角色提灯）
	main.set_time_of_day(0.94)
	main.world.keeper.teleport(Vector3(2.2, 0.15, 4.2), 0.5)
	main.world.keeper.set_walk_preview(false)
	main.set_camera_override(Vector3(3.2, 2.1, 3.3), 32.0, 5.0, 3.6)
	main.prewarm(1.0)
	await _shot("04_lamp_closeup.png", false)

	# 05 萤火虫特写（大树下）
	main.set_time_of_day(0.93)
	main.world.keeper.teleport(Vector3(3.8, 0.15, -1.2), 0.4)
	main.world.keeper.set_walk_preview(true, 2.4)
	main.set_camera_override(Vector3(5.8, 1.4, -2.9), 40.0, 8.0, 5.4)
	main.prewarm(2.4)
	await _shot("05_fireflies.png", false)

	# 06 水池与月影
	main.set_time_of_day(0.90)
	main.world.keeper.teleport(Vector3(-3.0, 0.15, -5.2), PI)
	main.world.keeper.set_walk_preview(false)
	main.set_camera_override(Vector3(-3.0, 0.30, -0.4), 24.0, 9.0, 6.6)
	main.prewarm(1.8)
	await _shot("06_pool_reflection.png", false)

	# 07 拱门与光束（黄昏）
	main.set_time_of_day(0.20)
	main.world.keeper.teleport(Vector3(0.45, 0.15, -5.6), 0.0)
	main.world.keeper.set_walk_preview(true, 0.6)
	main.set_camera_override(Vector3(0.3, 1.9, -8.9), 0.0, 11.0, 10.0)
	main.prewarm(1.0)
	await _shot("07_arch_beams.png", false)

	# 08 角色行走（正面 3/4，拱门/池在背景）
	main.set_time_of_day(0.55)
	main.world.keeper.teleport(Vector3(0.9, 0.15, 2.2), PI)
	main.world.keeper.set_walk_preview(true, 1.25)
	main.set_camera_override(Vector3(0.9, 1.0, 2.2), 18.0, 7.0, 3.6)
	main.prewarm(1.0)
	await _shot("08_character_walk.png", false)

	# 09 HUD 全分辨率面板
	main.set_time_of_day(0.55)
	main.world.keeper.teleport(Vector3(0.75, 0.15, 4.5), 0.0)
	main.world.keeper.set_walk_preview(false)
	main.reset_camera()
	main.cam_yaw = -12.0
	main.cam_pitch = 20.0
	main.cam_dist = 8.5
	main.clear_camera_override()
	cap_hud.set_ui_visible(true)
	cap_hud.sync_from_main()
	cap_hud.refresh_stats()
	await _frames(12)
	await _shot("09_hud_panel.png", true)
	cap_hud.set_ui_visible(false)

	# 10 更粗像素（480×270 ×4）对照
	main.set_param("internal_index", 1)
	main.set_time_of_day(0.78)
	main.set_camera_override(Vector3(-0.2, 1.15, 0.0), -4.0, 33.0, 16.0)
	main.world.keeper.teleport(Vector3(0.75, 0.15, 6.4), 0.0)
	main.world.keeper.set_walk_preview(false)
	main.prewarm(1.0)
	_set_capture_world_texture()
	await _frames(12)
	await _shot("10_lowres_480.png", false)
	main.set_param("internal_index", 2)
	_set_capture_world_texture()

	# 11 角色夜景近景（提灯/脸部可读性）
	main.set_time_of_day(0.95)
	main.world.keeper.teleport(Vector3(0.4, 0.15, 3.2), PI)
	main.world.keeper.set_walk_preview(true, 2.0)
	main.set_camera_override(Vector3(0.4, 1.0, 3.2), -8.0, 5.0, 2.7)
	main.prewarm(1.0)
	await _shot("11_character_night.png", false)

	# 12 黎明？不做；这里是深夜路灯近景侧向
	main.set_time_of_day(0.94)
	main.world.keeper.teleport(Vector3(-1.5, 0.15, -4.8), 0.2)
	main.world.keeper.set_walk_preview(false)
	main.set_camera_override(Vector3(-1.9, 2.1, -7.7), 20.0, 5.0, 4.2)
	main.prewarm(1.0)
	await _shot("12_arch_lamp_night.png", false)

	print("CAPTURE_DONE out=", abs_dir)
	_cleanup()
	quit(0)


func _setup_capture_viewport() -> void:
	cap = SubViewport.new()
	cap.name = "CaptureViewport"
	cap.size = Vector2i(1920, 1080)
	cap.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cap.msaa_2d = Viewport.MSAA_DISABLED
	cap.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	cap.use_taa = false
	cap.transparent_bg = false
	cap.gui_disable_input = true
	cap.handle_input_locally = false
	root.add_child(cap)
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.032, 0.034)
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(bg)
	cap_world = TextureRect.new()
	cap_world.texture = main.post_viewport.get_texture()
	cap_world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cap_world.stretch_mode = TextureRect.STRETCH_SCALE
	cap_world.position = Vector2.ZERO
	cap_world.size = Vector2(1920, 1080)
	cap_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(cap_world)
	cap_hud = HUD_SCRIPT.new()
	cap_hud.name = "CaptureHUD"
	cap_hud.layer = 11
	cap.add_child(cap_hud)
	cap_hud.setup(main)
	cap_hud.set_ui_visible(false)
	await _frames(4)


func _set_capture_world_texture() -> void:
	if cap_world != null:
		cap_world.texture = main.post_viewport.get_texture()


func _shot(filename: String, with_hud: bool) -> void:
	cap_hud.set_ui_visible(with_hud)
	if with_hud:
		cap_hud.sync_from_main()
		cap_hud.refresh_stats()
	await _frames(14)
	var img: Image = cap.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + "/" + filename)
	img.save_png(path)
	print("SHOT ", filename, " ", img.get_size(), " fps=", main.get_fps(),
		" draw=", main.get_draw_calls(), " internal=", main.get_internal_size())


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _cleanup() -> void:
	if cap != null:
		root.remove_child(cap)
		cap.queue_free()
	if main != null:
		root.remove_child(main)
		main.queue_free()
	await _frames(2)
