extends SceneTree

# GPU 实拍：原生 1920×1080（窗口 borderless 放大到 1920 后挪到屏幕外，
# 直接抓 root Viewport，不创建 SubViewport、不加第二台相机）。
# 场景仍然是 320×180 世界 + 单个 Camera2D，1920 时 canvas_items 内容缩放 1.5×。
# 用法：godot --path godot-pixel-normal-water -s tools/screenshot_normal_water.gd
# 输出：docs/shots/*.png（8 张 1920×1080 与 1 张 HUD 视图）

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)

var _scene
var _hud


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# macOS 会把普通窗口裁到桌面；borderless + 负坐标可得到真实 1920×1080 根视口。
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(SIZE)
	DisplayServer.window_set_position(Vector2i(-240, -120))
	await process_frame
	print("SCREENSHOT_ROOT_SIZE=", root.size)

	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await create_timer(0.7).timeout
	_hud = _scene.get_node("HUD")
	_scene.set_ui_visible(true)
	_scene.set_paused(false)
	_scene.set_light_preset(0)
	_scene.reset_camera()
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	# 08 HUD 先拍：此时尚未被逐帧 PNG 保存拖慢，FPS 读数才真实。
	await _shot("08_hud_panel")
	_scene.set_ui_visible(false)
	_scene.set_paused(true)
	_scene.set_time_value(1.35)
	_scene.set_light_angle(35.0)
	_scene.set_wave_speed(1.0)
	_scene.set_wave_amplitude(2.0)
	_scene.set_wave_step(1.0)
	_scene.reset_camera()
	await _settle()

	# 01 夜景全景
	await _shot("01_night_wide")

	# 02 建筑法线受光特写（月光从右上）
	_scene.focus_camera(Vector2(67, 80), 8.0)
	_scene.set_light_angle(312.0)
	_scene.set_time_value(2.1)
	await _settle()
	await _shot("02_tavern_normal_light")

	# 03 同一机位，光从左上：展示屋顶/树冠/梁柱法线的方向响应
	_scene.set_light_angle(78.0)
	await _settle()
	await _shot("03_tavern_light_flip")

	# 04 倒影特写：保留水线/建筑底部/暖灯，让倒影有上下文
	_scene.reset_camera()
	_scene.focus_camera(Vector2(150, 126), 6.2)
	_scene.set_light_angle(35.0)
	_scene.set_time_value(2.55)
	await _settle()
	await _shot("04_reflection_closeup")

	# 05 放大水波量化格：4px 波幅、2px 格，整行跳变仍能看见岸线和灯影
	_scene.focus_camera(Vector2(150, 128), 6.8)
	_scene.set_wave_amplitude(4.0)
	_scene.set_wave_step(2.0)
	_scene.set_time_value(1.1)
	await _settle()
	await _shot("05_quantized_wave_steps")

	# 06 调试视图：法线 RGB + 光向量 + 倒影四边形 + mask 岸线 + 整格刻度
	_scene.reset_camera()
	_scene.set_wave_amplitude(2.0)
	_scene.set_wave_step(1.0)
	_scene.set_light_angle(35.0)
	_scene.set_time_value(2.75)
	_scene.set_debug_enabled(true)
	_scene.set_normal_view(true)
	await _settle()
	await _shot("06_debug_normals_mesh")
	_scene.set_normal_view(false)

	# 07 倒影 Mesh 线框特写
	_scene.focus_camera(Vector2(178, 136), 8.0)
	_scene.set_time_value(2.0)
	await _settle()
	await _shot("07_reflection_mesh_wire")
	_scene.set_debug_enabled(false)
	_scene.reset_camera()

	print("NORMAL_WATER_SHOTS_OK count=8 size=%s" % str(root.size))
	quit(0)


func _settle() -> void:
	await process_frame
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img.get_width() != SIZE.x or img.get_height() != SIZE.y:
		# 若桌面环境裁切，退化为最近邻补到 1920，保持 6× 像素格。
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_NEAREST)
	var path := OUT + "/" + shot_name + ".png"
	var err := img.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path, " ", img.get_size())
