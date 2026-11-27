extends SceneTree

# 真实 GPU 截图：1920×1080，HUD ×1.5。
# 覆盖池底光网 / 圆石特写 / 单格切缝 / F1 / F2 / F2−F1 / 亮纹 / 格网 / 熔岩 / 面板。
# 用法：godot --path godot-pool-caustics -s tools/screenshot_pool_caustics.gd

const OUT := "res://docs/screenshots"
const SIZE := Vector2i(1920, 1080)
const DEFAULT_POSE := Vector3(0.55, -0.25, 0.0)

var _vp: SubViewport
var _scene
var _hud


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	_vp.positional_shadow_atlas_size = 0
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(1.2).timeout
	_hud = _scene.get_hud()
	_hud.set_ui_scale(1.5)
	_hud.set_minimal(false)
	_hud.set_stats_visible(true)
	_scene.set_ui_visible(true)
	_scene.set_time_override(5.0)
	await create_timer(0.8).timeout

	# 1 · 池底总览
	_scene.set_variant(0)
	_scene.set_debug_mode(0)
	_scene.set_search_3x3(true)
	_scene.set_ui_visible(false)
	_camera(DEFAULT_POSE, 4.0, 48.0, 17.2)
	_scene.set_time_override(6.2)
	await _snapshot("01_pool_caustics")

	# 2 · 圆石与光网包裹
	_camera(Vector3(-1.20, 0.8, 0.10), -8.0, 50.0, 12.8)
	_scene.set_time_override(7.6)
	await _snapshot("02_boulder_detail")

	# 3 · 单格测距：可见正方格缝与断裂圆环
	_scene.set_ui_visible(true)
	_hud.set_minimal(true)
	_hud.set_stats_visible(false)
	_camera(DEFAULT_POSE, 4.0, 48.0, 17.2)
	_hud.show_caption("", 0.0)
	_scene.set_debug_mode(0)
	_scene.set_search_3x3(false)
	_scene.set_time_override(7.0)
	await _snapshot("03_single_cell")

	# 4 · F1：恢复 3×3 后再采集分析视图。
	_scene.set_search_3x3(true)
	_scene.set_debug_mode(1)
	await _snapshot("04_f1_distance")

	# 5 · F2
	_scene.set_debug_mode(2)
	await _snapshot("05_f2_distance")

	# 6 · F2−F1
	_scene.set_debug_mode(3)
	await _snapshot("06_f2_minus_f1")

	# 7 · 亮纹 mask
	_scene.set_debug_mode(4)
	await _snapshot("07_beam_mask")

	# 8 · 格网 + 特征点
	_scene.set_debug_mode(5)
	await _snapshot("08_grid_3x3")

	# 9 · 坐标扭曲场
	_scene.set_debug_mode(6)
	await _snapshot("09_warp_field")

	# 10 · 熔岩变体（同一 F2−F1 核心）
	_scene.set_debug_mode(0)
	_scene.set_search_3x3(true)
	_scene.set_variant(1)
	_scene.set_ui_visible(false)
	_scene.set_time_override(6.8)
	await _snapshot("10_lava_cracks")

	# 11 · 中文参数面板：让引擎 FPS 从连续截图写入的低谷恢复后再采集。
	_scene.set_variant(0)
	_scene.set_debug_mode(0)
	_scene.set_search_3x3(true)
	_scene.set_ui_visible(true)
	_hud.set_minimal(false)
	_hud.set_stats_visible(true)
	_scene.get_pool_camera().reset_pose()
	_scene.set_time_override(8.4)
	_scene.sync_ui()
	await create_timer(3.0).timeout
	await _snapshot("11_control_panel")

	print("POOL_CAUSTICS_SHOTS_OK")
	quit(0)


func _camera(target: Vector3, yaw: float, pitch: float, distance: float) -> void:
	_scene.get_pool_camera().set_pose(target, yaw, pitch, distance)


func _snapshot(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := _vp.get_texture().get_image()
	var path := "%s/%s.png" % [OUT, file_name]
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path, " ", image.get_width(), "x", image.get_height())
