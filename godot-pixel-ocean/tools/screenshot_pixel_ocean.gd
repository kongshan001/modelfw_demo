extends SceneTree

# GPU 实拍：晚霞 / 低机位倒影 / 正午 / 夜 / 浪尖白沫 / 五点浮力 / 参数面板。
# 每张定格在一个确定的波相位，便于对比。
# 用法：godot --path godot-pixel-ocean --resolution 1280x720 -s tools/screenshot_pixel_ocean.gd

const OUT := "res://docs/shots"
const SIZE := Vector2i(1280, 720)

var _vp: SubViewport
var _scene


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(0.6).timeout
	_scene.set_auto_orbit(false)
	_scene.set_ui_visible(false)

	# 01 晚霞全景
	_scene.set_preset(1)
	_scene.set_camera_orbit(32.0, 12.0, 8.8)
	_scene.set_wave_height(1.20)
	await _pose(18.4, 2.4)
	await _shot("01_sunset_wide")

	# 02 低机位倒影
	_scene.set_preset(1)
	_scene.set_camera_orbit(20.0, 4.2, 7.2)
	_scene.set_wave_height(1.30)
	_scene.set_foam_amount(1.0)
	_scene.set_reflection_strength(1.0)
	await _pose(18.4, 5.1)
	await _shot("02_sunset_reflection")

	# 03 正午
	_scene.set_preset(0)
	_scene.set_camera_orbit(28.0, 17.0, 9.5)
	_scene.set_wave_height(1.05)
	await _pose(12.5, 1.7)
	await _shot("03_noon_clear")

	# 04 夜
	_scene.set_preset(2)
	_scene.set_camera_orbit(36.0, 10.0, 8.2)
	_scene.set_sparkle_amount(1.0)
	await _pose(22.5, 3.4)
	await _shot("04_night_sparkle")

	# 05 浪尖白沫（俯视，浪高拉大）
	_scene.set_preset(1)
	_scene.set_camera_orbit(25.0, 24.0, 6.8)
	_scene.set_wave_height(1.75)
	_scene.set_foam_amount(1.45)
	await _pose(18.4, 7.6)
	await _shot("05_foam_crest")

	# 06 五点浮力采样
	_scene.set_preset(1)
	_scene.set_camera_orbit(38.0, 33.0, 9.2)
	_scene.set_wave_height(1.45)
	_scene.set_foam_amount(1.1)
	_scene.set_debug_points(true)
	await _pose(18.4, 4.4)
	await _shot("06_five_points")
	_scene.set_debug_points(false)

	# 07 参数面板
	_scene.set_preset(1)
	_scene.set_camera_orbit(32.0, 12.0, 8.8)
	await _pose(18.4, 2.4)
	_scene.set_ui_visible(true)
	_scene.set_paused(false)
	_scene.get_node("HUD").sync_from_main()
	await create_timer(0.2).timeout
	await _shot("07_panel")
	_scene.set_ui_visible(false)

	# 08 干净的镜面：低机位、弱泡沫，确认帆影是上下翻转而不是左右翻转
	_scene.set_preset(1)
	_scene.set_time_of_day(18.2)
	_scene.set_camera_orbit(18.0, 3.6, 6.2)
	_scene.set_wave_height(0.9)
	_scene.set_foam_amount(0.12)
	_scene.set_sparkle_amount(0.35)
	_scene.set_reflection_strength(1.0)
	_scene.set_transparency(0.10)
	await _pose(18.2, 1.2)
	await _shot("08_mirror")

	# 09 透明海水：俯视看海床焦散
	_scene.set_preset(0)
	_scene.set_camera_orbit(30.0, 34.0, 7.4)
	_scene.set_wave_height(0.8)
	_scene.set_foam_amount(0.25)
	_scene.set_reflection_strength(0.35)
	_scene.set_sparkle_amount(0.4)
	_scene.set_transparency(0.80)
	await _pose(12.5, 3.0)
	await _shot("09_transparency")

	print("PIXEL_OCEAN_SHOTS_OK")
	quit(0)


func _pose(hour: float, wave_clock: float) -> void:
	_scene.set_time_of_day(hour)
	_scene.set_paused(true)
	_scene.set_wave_clock(wave_clock)
	for i in 10:
		_scene.get_raft().update_buoyancy(0.5)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path)
