extends SceneTree

# 真实 GPU 1920×1080 截图矩阵（离屏 SubViewport，避开 macOS 大窗口裁切）。
# 用法：godot --path godot-hd2d -s tools/screenshot_hd2d.gd
# 输出：res://docs/shots/01_before.png ... 08_ui.png

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)

var _scene: Node
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
	_scene.set_paused(true)
	_scene.world.reset_motion()
	print("SHOT viewport=%s pixel_scale=%.1f ui_scale=%.2f" % [
		str(_vp.size), _scene.pixel_scale, _scene.ui_scale])

	await _pose(false, false, 0.60, 0.14, 0.20, 1.1, 17.0,
			-38.0, 0.75, 0.35, false)
	await _shot("01_before")

	await _pose(true, false, 0.60, 0.14, 0.20, 1.1, 17.0,
			-38.0, 0.75, 0.35, false)
	await _shot("02_after")

	await _pose(true, false, 0.38, 0.10, 0.22, 1.2, 19.0,
			-38.0, 0.75, 0.35, false)
	await _shot("03_focus_high")

	await _pose(true, false, 0.76, 0.09, 0.18, 1.15, 18.0,
			-38.0, 0.75, 0.35, false)
	await _shot("04_focus_low")

	await _pose(true, false, 0.60, 0.14, 0.20, 1.1, 17.0,
			38.0, 0.9, 0.8, false)
	await _shot("05_light_angle")

	await _pose(true, true, 0.62, 0.14, 0.20, 1.1, 16.0,
			-22.0, 1.2, 0.12, false)
	await _shot("06_night")

	await _pose(true, false, 0.56, 0.13, 0.20, 1.15, 18.0,
			-8.0, 0.7, 1.0, false)
	await _shot("07_dusk")

	_scene.apply_preset("morning")
	_scene.set_paused(false)
	_scene.world.reset_motion()
	_scene.set_ui_visible(true)
	_scene.hud.set_stats_visible(false)
	await create_timer(0.35).timeout
	await process_frame
	await _shot("08_ui")

	_scene.hud.set_stats_visible(false)
	_scene.apply_preset("night")
	_scene.set_paused(true)
	_scene.world.reset_motion()
	_scene.set_ui_visible(true)
	await create_timer(0.35).timeout
	await process_frame
	await _shot("09_ui_night")

	print("HD2D_SHOTS_OK count=9 size=%dx%d" % [SIZE.x, SIZE.y])
	quit(0)


func _pose(post: bool, night: bool, focus: float, band: float, feather: float,
		strength: float, radius: float, angle: float, energy: float,
		warmth: float, ui: bool) -> void:
	_scene.set_paused(true)
	_scene.world.reset_motion()
	_scene.set_post_enabled(post)
	_scene.set_night(night)
	_scene.set_light_angle(angle)
	_scene.set_light_energy(energy)
	_scene.set_warmth(warmth)
	_scene.set_focus_y(focus)
	_scene.set_band_half(band)
	_scene.set_feather(feather)
	_scene.set_strength(strength)
	_scene.set_radius(radius)
	_scene.set_ui_visible(ui)
	await create_timer(0.30).timeout
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
