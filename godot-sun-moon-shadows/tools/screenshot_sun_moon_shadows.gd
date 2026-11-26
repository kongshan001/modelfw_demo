extends SceneTree

# 真实 GPU 1920×1080 截图矩阵：
#   晨光 / 正午 / 黄昏 / 19:00 交接 / 21:00 路灯+月影 / 午夜月亮 / 重叠影标记与裁切 /
#   高度图 / 遮挡热力 / 网格线框 / 软膝曲线（软/硬） / 白天 UI / 夜间 UI。
# 用 1920×1080 离屏 SubViewport 渲染，世界 640×360 整数 3×，HUD 3×。
# 运行：godot --path godot-sun-moon-shadows -s tools/screenshot_sun_moon_shadows.gd

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
	_scene.set_playing(false)
	print("SHOTS scale=%d hud_scale=%s viewport=%s" % [
		_scene.get_pixel_scale(), str(_hud.scale), str(_vp.size)])

	await _pose(8.0, false, false, false, false, true, true)
	await _shot("01_0800_clean")
	await _pose(12.0, false, false, false, false, true, true)
	await _shot("02_noon_clean")
	await _pose(18.3333, false, false, false, false, true, true)
	await _shot("03_dusk_clean")
	await _pose(19.0, false, false, false, false, true, true)
	await _shot("03b_handoff_1900")
	await _pose(21.0, false, false, false, false, true, true)
	await _shot("04_night_2100_clean")
	await _pose(0.5, false, false, false, false, true, true)
	await _shot("05_midnight_moon_clean")

	# 重叠树影标记（08:00）+ 局部裁切。
	await _pose(8.0, false, false, false, true, true, true)
	await _shot("06_overlap_markers")
	var img = await _grab()
	var probe: Dictionary = _scene.get_world().get_overlap_probe()
	if bool(probe.get("found", false)):
		var p: Vector2 = probe["single_point"]
		var cx := clampi(int(p.x * 3.0) - 250, 0, 1920 - 640)
		var cy := clampi(int(p.y * 3.0) - 190, 0, 1080 - 340)
		var crop: Image = img.get_region(Rect2i(cx, cy, 640, 340))
		crop.save_png(OUT + "/06b_overlap_crop.png")
		print("OVERLAP_CROP ", probe["pair"], " ", probe["single_point"], " ", probe["overlap_point"])
	await _clear_debug()

	# 高度图 / 遮挡 / 网格（无 UI，避免面板遮住对照）。
	await _pose(8.0, false, false, true, false, true, true)
	await _shot("07_heightmap")
	await _clear_debug()
	await _pose(8.0, false, true, false, false, true, true)
	await _shot("08_occlusion_heat")
	await _clear_debug()
	await _pose(8.0, false, false, false, false, true, true)
	_scene.set_debug_flag("mesh", true)
	await _shot("09_mesh_wireframe")
	await _clear_debug()

	# 调试曲线面板（18:20，软膝 / 硬截）。
	await _pose(18.3333, true, false, false, false, true, true)
	_scene.set_debug_enabled(true)
	await create_timer(0.2).timeout
	await _shot("10_debug_panel_curve_soft")
	_scene.set_soft_knee(false)
	await create_timer(0.2).timeout
	await _shot("11_debug_panel_curve_hard")
	_scene.set_soft_knee(true)

	# UI 展示。
	await _pose(12.0, true, false, false, false, true, true)
	await _shot("12_noon_ui")
	await _pose(21.0, true, false, false, false, true, true)
	await _shot("13_night_ui")

	print("SUN_MOON_SHADOW_SHOTS_OK")
	quit(0)


func _pose(hour: float, ui: bool, occlusion: bool, heightmap: bool,
		overlap: bool, soft_knee: bool, shadows: bool) -> void:
	_scene.set_playing(false)
	_scene.set_hour(hour)
	_scene.set_ui_visible(ui)
	_scene.set_soft_knee(soft_knee)
	_scene.set_shadows_enabled(shadows)
	_scene.set_debug_enabled(false)
	_scene.get_world().set_debug_flag("heightmap", heightmap)
	_scene.get_world().set_debug_flag("occlusion", occlusion)
	_scene.get_world().set_debug_flag("overlap", overlap)
	_hud.sync_from_main()
	await create_timer(0.2).timeout
	await process_frame


func _clear_debug() -> void:
	_scene.set_debug_enabled(false)
	_hud.sync_from_main()
	await create_timer(0.08).timeout


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return _vp.get_texture().get_image()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	var err := img.save_png(OUT + "/" + name + ".png")
	if err != OK:
		printerr("failed to save ", name, ": ", err)
	else:
		print("SHOT ", name)
