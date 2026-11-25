extends SceneTree

# 真实 GPU 1920×1080 截图矩阵：
#   08:00 / 正午 / 16:00 / 17:00 封顶 / 调试视图 / 阴影开/关对比 / 带 UI 面板。
# 用 1920×1080 的 SubViewport 离屏渲染；世界 640×360 → 3× 最近邻，HUD 1.5×。
# 用法：godot --path godot-sakura-sunlight -s tools/screenshot_sakura_sunlight.gd
# 输出到 res://docs/shots/

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)

var _scene
var _hud
var _vp: SubViewport


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	_vp.snap_2d_transforms_to_pixel = true
	_vp.snap_2d_vertices_to_pixel = true
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(0.9).timeout
	_hud = _scene.get_node("HUD")
	_hud.set_fps_visible(false)
	print("SHOT_UI_SCALE %s viewport=%s" % [str(_hud.scale), str(_vp.size)])

	await _pose({"hour": 8.0, "ui": false, "debug": false, "shadows": true,
			"petals": true})
	await _shot("01_0800")

	await _pose({"hour": 12.0, "ui": false, "debug": false, "shadows": true,
			"petals": true})
	await _shot("02_noon")

	await _pose({"hour": 16.0, "ui": false, "debug": false, "shadows": true,
			"petals": true})
	await _shot("03_1600")

	await _pose({"hour": 17.0, "ui": false, "debug": false, "shadows": true,
			"petals": true})
	await _shot("04_1700_cap")

	await _pose({"hour": 9.25, "ui": true, "debug": true, "shadows": true,
			"petals": true})
	await _shot("05_debug")

	await _pose({"hour": 14.0, "ui": false, "debug": false, "shadows": true,
			"petals": true})
	await _shot("06_shadow_on")

	await _pose({"hour": 14.0, "ui": false, "debug": false, "shadows": false,
			"petals": true})
	await _shot("07_shadow_off")

	await _pose({"hour": 8.0, "ui": true, "debug": false, "shadows": true,
			"petals": true})
	await _shot("08_panel_0800")

	await _pose({"hour": 12.0, "ui": true, "debug": false, "shadows": true,
			"petals": true})
	await _shot("09_panel_noon")

	await _pose({"hour": 16.6, "ui": true, "debug": false, "shadows": true,
			"petals": true})
	await _shot("10_panel_evening")

	print("SAKURA_SUNLIGHT_SHOTS_OK")
	quit(0)


func _pose(p: Dictionary) -> void:
	_scene.set_playing(false)
	_scene.set_hour(float(p["hour"]))
	_scene.set_debug_enabled(bool(p["debug"]))
	_scene.set_shadows_enabled(bool(p["shadows"]))
	_scene.set_petals_enabled(bool(p["petals"]))
	_scene.set_ui_visible(bool(p["ui"]))
	_scene.simulate_petals(0.16)
	_hud.sync_from_main()
	await create_timer(0.18).timeout
	await process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path, " ", image.get_width(), "x", image.get_height())
