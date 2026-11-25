extends SceneTree

# 真实 GPU 截图：积水过程 / 满水倒影 / 渗干 / 雨强对比 / 灯柱规则 / 面板。
# 用 1920×1080 的 SubViewport 渲染，避免 macOS 把大窗口裁到桌面尺寸。
# 用法：godot --path godot-rain-puddles -s tools/screenshot_rain_puddles.gd
# 输出到 res://docs/shots/（1920×1080，HUD 1.5×）。

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)

var _scene
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
	_scene.get_node("HUD").scale = Vector2(1.5, 1.5)
	await create_timer(0.8).timeout
	_scene.set_ui_visible(false)
	_scene.set_debug_grid(false)
	await _warm(0.9)

	await _pose({
		"rain": 0.90, "wet": 0.38, "density": 360, "wind": 0.18,
		"ripples": true, "reflection": true, "ui": false, "debug": false,
	})
	await _shot("01_filling_rain")

	await _pose({
		"rain": 0.50, "wet": 1.0, "density": 360, "wind": 0.12,
		"ripples": true, "reflection": true, "ui": false, "debug": false,
	})
	await _shot("02_full_reflection")

	await _pose({
		"rain": 0.0, "wet": 0.55, "density": 360, "wind": 0.12,
		"ripples": false, "reflection": true, "ui": false, "debug": false,
	})
	await _shot("03_draining")

	await _pose({
		"rain": 0.0, "wet": 0.10, "density": 360, "wind": 0.12,
		"ripples": false, "reflection": true, "ui": false, "debug": false,
	})
	await _shot("04_shallow_remnant")

	await _pose({
		"rain": 1.0, "wet": 1.0, "density": 560, "wind": 0.42,
		"ripples": true, "reflection": true, "ui": false, "debug": false,
		"speed": 1.25, "length": 1.25,
	})
	await _shot("05_heavy_rain")

	await _pose({
		"rain": 0.22, "wet": 0.55, "density": 150, "wind": 0.05,
		"ripples": true, "reflection": true, "ui": false, "debug": false,
		"speed": 1.0, "length": 1.0,
	})
	await _shot("06_light_rain")

	await _pose({
		"rain": 0.60, "wet": 1.0, "density": 360, "wind": 0.18,
		"ripples": true, "reflection": true, "ui": true, "debug": true,
	})
	await _shot("07_lamp_rule_debug")

	await _pose({
		"rain": 0.75, "wet": 0.72, "density": 360, "wind": 0.18,
		"ripples": true, "reflection": true, "ui": true, "debug": false,
	})
	await _shot("08_panel")

	# 同一机位关闭倒影，作为“统一裁切”开关的对照。
	await _pose({
		"rain": 0.50, "wet": 1.0, "density": 360, "wind": 0.12,
		"ripples": true, "reflection": false, "ui": false, "debug": false,
	})
	await _shot("09_reflection_off")

	print("RAIN_PUDDLES_SHOTS_OK")
	quit(0)


func _warm(seconds: float) -> void:
	_scene.set_paused(false)
	await create_timer(seconds).timeout


func _pose(p: Dictionary) -> void:
	_scene.set_paused(false)
	_scene.set_rain_intensity(p["rain"])
	_scene.set_density(p["density"])
	_scene.set_wind(p["wind"])
	if p.has("speed"):
		_scene.set_rain_speed(p["speed"])
	if p.has("length"):
		_scene.set_rain_length(p["length"])
	if not p["ripples"]:
		_scene.set_ripples_enabled(false)
	else:
		_scene.set_ripples_enabled(true)
	_scene.set_reflection_enabled(p["reflection"])
	_scene.set_debug_grid(p["debug"])
	_scene.set_wet_level(p["wet"])
	_scene.set_ui_visible(p["ui"])
	# 让雨丝与涟漪走一会儿，再固定水位定格。
	await create_timer(0.9).timeout
	_scene.set_wet_level(p["wet"])
	_scene.set_paused(true)
	_scene.set_ui_visible(p["ui"])
	_scene.get_node("HUD").sync_from_main()
	await process_frame
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
