extends SceneTree

# 真实 GPU 1920×1080 截图矩阵。所有镜头由 API 摆位，确定性 tick，保证可复现。
# 用法：godot --path godot-stylized-ocean-v2 -s tools/screenshot_stylized_ocean.gd

const SIZE := Vector2i(1920, 1080)
const OUT := "res://docs/shots"
const STEP := 1.0 / 30.0

var scene
var vp: SubViewport


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	scene = load("res://scenes/main.tscn").instantiate()
	vp.add_child(scene)
	await process_frame
	await create_timer(0.6).timeout
	scene.set_paused(true)
	scene.set_ui_visible(false)
	scene.set_hour(11.5)
	scene.ocean.clear_ripples()
	scene.set_camera_orbit(90.0, 58.0, 116.0)
	_tick(60)

	# 01 广角俯视（参考主构图）
	await _shot("01_wide_topdown")

	# 02 低机位海平线
	scene.set_camera_target(0.0, 6.0, 1.0)
	scene.set_camera_orbit(90.0, 21.0, 165.0)
	scene.set_camera_fov(42.0)
	scene.set_hour(11.5)
	_tick(30)
	await _shot("02_horizon")
	scene.set_camera_fov(36.0)

	# 03 岸线泡沫特写
	scene.set_camera_target(0.0, 27.0, 0.2)
	scene.set_camera_orbit(70.0, 48.0, 46.0)
	scene.set_hour(11.5)
	scene.ocean.clear_ripples()
	_tick(40)
	await _shot("03_shore_foam")

	# 04 浪尖泡沫（提高浪高）
	scene.set_camera_target(0.0, 62.0, 0.0)
	scene.set_camera_orbit(65.0, 26.0, 52.0)
	scene.ocean.set_wave_height(1.85)
	scene.ocean.set_foam_amount(1.15)
	scene.set_hour(11.5)
	scene.ocean.clear_ripples()
	_tick(70)
	await _shot("04_crest_foam")
	scene.ocean.set_wave_height(0.72)
	scene.ocean.set_foam_amount(0.85)

	# 05 太阳高光（深海）
	scene.set_clouds_visible(false)
	scene.set_camera_target(0.0, 62.0, 0.0)
	scene.set_camera_orbit(90.0, 44.0, 55.0)
	scene.set_hour(11.5)
	scene.ocean.set_sun_glint(1.5)
	scene.ocean.clear_ripples()
	_tick(40)
	await _shot("05_sun_glint")
	scene.ocean.set_sun_glint(1.0)
	scene.set_clouds_visible(true)

	# 06/07 鼠标涟漪 前/后
	scene.set_camera_target(0.0, 29.0, 0.15)
	scene.set_camera_orbit(90.0, 55.0, 46.0)
	scene.set_hour(11.5)
	scene.ocean.clear_ripples()
	scene.set_virtual_cursor(Vector2(960, 560))
	_tick(20)
	await _shot("06_ripple_before")
	scene.debug_paint_arc(Vector2(0.0, 30.5), 4.5, 7, 1.25)
	_tick(26)
	await _shot("07_ripple_after")

	# 08 岛屿 + 小船
	scene.set_virtual_cursor(Vector2(-99999, -99999))
	scene.ocean.clear_ripples()
	scene.set_camera_target(18.0, 10.0, 1.0)
	scene.set_camera_orbit(88.0, 52.0, 78.0)
	scene.set_hour(11.5)
	_tick(45)
	await _shot("08_island_boat")

	# 09 调试：水深热力图（HUD）
	scene.set_camera_target(0.0, 18.0, 0.6)
	scene.set_camera_orbit(90.0, 55.0, 80.0)
	scene.set_debug_view(5)
	scene.set_ui_visible(true)
	scene.set_ui_scale(1.5)
	scene.hud.set_panel_open(true)
	scene.hud.set_caption("调试 · 水深（米）/ 岸线梯度")
	scene.set_paused(false)
	await create_timer(1.1).timeout
	await _shot("09_debug_depth")
	scene.set_paused(true)
	# 09b 调试：涟漪源
	scene.set_debug_view(4)
	scene.hud.set_caption("调试 · 涟漪源（12 路）")
	scene.ocean.clear_ripples()
	scene.debug_paint_arc(Vector2(0.0, 26.0), 5.5, 6, 1.2)
	_tick(18)
	scene.set_paused(false)
	await create_timer(0.9).timeout
	await _shot("09b_debug_ripples")
	scene.set_paused(true)
	scene.set_debug_view(0)
	scene.set_ui_visible(false)
	scene.hud.set_caption("")

	# 10 夜景
	scene.set_camera_target(0.0, 2.0, 1.2)
	scene.set_camera_orbit(96.0, 56.0, 104.0)
	scene.set_hour(20.4)
	scene.ocean.clear_ripples()
	_tick(40)
	await _shot("10_night")

	# 11 雨天
	scene.set_hour(14.2)
	scene.set_camera_target(0.0, 22.0, 0.6)
	scene.set_camera_orbit(90.0, 52.0, 70.0)
	scene.set_rain(true)
	for i in 40:
		scene.tick(STEP)
	await create_timer(0.9).timeout
	for i in 20:
		scene.tick(STEP)
	await _shot("11_rain")
	scene.set_rain(false)

	# 12 UI 面板（1920 下 1.5×）
	scene.set_hour(11.5)
	scene.set_camera_target(0.0, 2.0, 1.2)
	scene.set_camera_orbit(90.0, 58.0, 116.0)
	scene.set_ui_visible(true)
	scene.set_ui_scale(1.5)
	scene.hud.set_panel_open(true)
	scene._update_stats_label()
	_tick(20)
	scene.set_paused(false)
	await create_timer(1.2).timeout
	await _shot("12_ui_panel")

	print("STYLIZED_OCEAN_SHOTS_OK")
	quit(0)


func _tick(n: int) -> void:
	for i in n:
		scene.tick(STEP)


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + "/" + name + ".png")
	img.save_png(path)
	print("shot ", name, " ", img.get_width(), "x", img.get_height())
