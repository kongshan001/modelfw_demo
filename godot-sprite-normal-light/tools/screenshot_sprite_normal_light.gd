extends SceneTree

# 真实 GPU 1920×1080 截图矩阵：
#   UI 英雄图 / 法线 ON / 法线 OFF / 法线图调试 / 光照向量调试 /
#   原生 CanvasTexture+Light2D / 高光特写 / 翻转+2×缩放。
# macOS 普通窗口会被桌面裁切；borderless + 负坐标得到真实 1920 根视口。
# 用法：godot --path godot-sprite-normal-light -s tools/screenshot_sprite_normal_light.gd
# 输出：res://docs/shots/*.png

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)

var _scene
var _hud
var _cam: Camera2D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(SIZE)
	DisplayServer.window_set_position(Vector2i(-240, -120))
	await process_frame
	print("SCREENSHOT_ROOT_SIZE=", root.size)

	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await create_timer(0.8).timeout
	_hud = _scene.get_node("HUD")
	_cam = _scene.get_node("World/Camera2D")
	_scene.set_playing(false)
	_scene.set_auto_orbit(false)
	_scene.set_ui_visible(true)
	_scene.set_native_mode(false)
	_scene.set_debug_mode(0)
	_scene.set_normals_on(true)
	_scene.reset()
	_scene.set_playing(false)
	_scene.set_auto_orbit(false)
	_scene.set_light_angle(330.0)
	_hud.sync_from_main()
	await create_timer(2.0).timeout

	# 01 hero with HUD; captured first while the FPS readout is fresh
	await _shot("01_ui_shader")

	_scene.set_ui_visible(false)
	_scene.set_light_angle(0.0)
	_scene.set_light_height(64.0)
	await _shot("02_normal_on")

	_scene.set_normals_on(false)
	await _shot("03_normal_off")

	_scene.set_normals_on(true)
	_scene.set_debug_mode(1)
	await _shot("04_debug_normal")

	_scene.set_debug_mode(2)
	await _shot("05_debug_light")

	_scene.set_debug_mode(4)
	await _shot("09_debug_vectors")

	_scene.set_debug_mode(0)
	_scene.set_ui_visible(true)
	_scene.set_light_angle(330.0)
	_scene.set_native_mode(true)
	_hud.sync_from_main()
	await _shot("06_ui_native_light2d")

	_scene.set_native_mode(false)
	_scene.set_ui_visible(false)
	_scene.reset()
	_scene.set_playing(false)
	_scene.set_auto_orbit(false)
	_scene.set_light_angle(20.0)
	_scene.set_light_height(30.0)
	_scene.set_roughness(0.22)
	_scene.set_spec_strength(1.1)
	_scene.set_light_energy(1.6)
	_scene.get_node("LightRig/EmberGlow").visible = false
	_cam.position = Vector2(190, 112)
	_cam.zoom = Vector2(6, 6)
	await _shot("07_highlight_closeup")

	_cam.position = Vector2(160, 90)
	_cam.zoom = Vector2(4, 4)
	_scene.get_node("LightRig/EmberGlow").visible = true
	_scene.reset()
	_scene.set_playing(false)
	_scene.set_auto_orbit(false)
	_scene.set_light_angle(330.0)
	_scene.toggle_flip_test()
	_scene.toggle_scale_test()
	await _shot("08_flip_scale")

	print("SPRITE_NORMAL_LIGHT_SHOTS_OK count=9 size=%s" % str(root.size))
	quit(0)


func _shot(shot_name: String) -> void:
	_hud.sync_from_main()
	await process_frame
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != SIZE:
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_NEAREST)
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path, " ", image.get_width(), "x", image.get_height())
