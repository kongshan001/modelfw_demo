extends SceneTree

# 真实 GPU 截图工具：把 640×360 CompositeViewport 以 3× 最近邻合成到
# 1920×1080 的 CaptureViewport，并在其上叠加 1920 原生 HUD。
# 屏幕只有 1440×900，无法直接开 1920 窗口；这是真实 GPU 的 1920 渲染。

const MAIN_SCENE := "res://scenes/main.tscn"
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
	DisplayServer.window_set_position(Vector2i(40, 40))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	var packed: PackedScene = load(MAIN_SCENE)
	main = packed.instantiate()
	root.add_child(main)
	await _frames(100)

	_setup_capture_viewport()
	main.set_param("fish_count", 22)

	# 00 HUD 面板（先拍，避免截图回读拉低实时 FPS 读数）
	main.set_param("preset", 1)
	main.set_param("ui", true)
	main.apply_camera_view(26.0, 60.0, 16.0, Vector3(0.0, 0.1, 0.0), false)
	main.prewarm_simulation(6.0)
	await create_timer(2.0).timeout
	await _shot("11_hud_panel.png", true)
	main.set_param("ui", false)
	main.set_param("fish_count", 22)

	# 01 水面全景（正午）
	main.set_param("preset", 1)
	main.apply_camera_view(26.0, 60.0, 16.0, Vector3(0.0, 0.1, 0.0), false)
	main.prewarm_simulation(2.0)
	await _shot("01_surface_wide.png", false)

	# 02 鱼群近景（以鱼群质心为目标）
	main.set_param("fish_count", 26)
	main.prewarm_simulation(2.5)
	var c := _fish_centroid()
	main.apply_camera_view(56.0, 39.0, 8.5, Vector3(c.x, -0.2, c.z), false)
	main.prewarm_simulation(1.2)
	await _shot("02_fish_school.png", false)

	# 03 水下光柱
	main.set_param("fish_count", 20)
	main.apply_camera_view(5.0, -3.0, 7.0, Vector3(0.0, -0.2, -2.0), true)
	await _shot("03_underwater.png", false)

	# 04 焦散 / 岸线泡沫 / 岩石
	main.apply_camera_view(70.0, 44.0, 6.2, Vector3(4.4, 0.0, 2.1), false)
	main.prewarm_simulation(1.0)
	await _shot("04_caustics_foam.png", false)

	# 05 低分辨率 RT 调试
	main.set_param("preset", 1)
	main.apply_camera_view(26.0, 60.0, 16.0, Vector3(0.0, 0.1, 0.0), false)
	main.set_param("debug", 1)
	await _shot("05_debug_lowres_rt.png", false)

	# 06 深度调试
	main.set_param("debug", 2)
	await _shot("06_debug_depth.png", false)

	# 07 法线调试
	main.set_param("debug", 3)
	await _shot("07_debug_normals.png", false)

	# 08 描边调试
	main.set_param("debug", 4)
	await _shot("08_debug_outline.png", false)
	main.set_param("debug", 0)

	# 09 黄昏
	main.set_param("preset", 2)
	main.apply_camera_view(32.0, 57.0, 15.5, Vector3(0.0, 0.1, 0.0), false)
	main.prewarm_simulation(1.0)
	await _shot("09_golden_hour.png", false)

	# 10 雨夜
	main.set_param("preset", 3)
	main.prewarm_simulation(4.0)
	await _shot("10_night_rain.png", false)

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
	bg.color = Color(0.02, 0.03, 0.035)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(bg)
	cap_world = TextureRect.new()
	cap_world.texture = main.composite_viewport.get_texture()
	cap_world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cap_world.stretch_mode = TextureRect.STRETCH_SCALE
	cap_world.position = Vector2.ZERO
	cap_world.size = Vector2(1920, 1080)
	cap_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(cap_world)
	cap_hud = load("res://scripts/hud.gd").new()
	cap_hud.name = "CaptureHUD"
	cap_hud.layer = 10
	cap.add_child(cap_hud)
	cap_hud.setup(main)
	cap_hud.set_ui_visible(false)
	await _frames(4)


func _shot(filename: String, with_hud: bool) -> void:
	cap_hud.set_ui_visible(with_hud)
	if with_hud:
		cap_hud.sync_from_main()
		cap_hud.refresh_stats()
	await _frames(10)
	var img: Image = cap.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + "/" + filename)
	img.save_png(path)
	print("SHOT ", filename, " ", img.get_size(), " fps=", main.get_fps(),
		" draw=", main.get_draw_calls(), " internal=", main.get_internal_size())


func _fish_centroid() -> Vector3:
	var arr: Array[Vector3] = main.fish_manager.get_positions()
	if arr.is_empty():
		return Vector3.ZERO
	var s := Vector3.ZERO
	for p in arr:
		s += p
	return s / float(arr.size())


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
