extends SceneTree

# 真实 GPU 截图（1920×1080）。macOS 会把大窗口裁到桌面，因此用 1920×1080
# 的 SubViewport 渲染；世界仍是 1280×720 逻辑，HUD 单独 1.5×。
# 用法：godot --path godot-water-shader -s tools/screenshot_water_shader.gd

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
	await process_frame
	_scene.get_hud().set_display_scale(1.5)
	await create_timer(0.6).timeout

	await _pose(WaterController.CAT_ALL, "full", {
		"time": 8.0, "ui": false, "rain": 0.0, "debug": 0, "settle": 0.4,
		"caption": "海 / 河 / 湖 · 共用 1 个水面 Shader · 零额外水面网格",
	})
	await _shot("01_wide")

	await _pose(WaterController.CAT_ALL, "full", {
		"time": 3.0, "ui": true, "rain": 0.0, "debug": 0, "settle": 1.6,
		"caption": "",
	})
	await _shot("02_panel")

	await _pose(WaterController.CAT_SEA, "sea", {
		"time": 5.7, "ui": false, "rain": 0.0, "debug": 0, "settle": 0.4,
		"caption": "海域 · 浅滩透沙 + 3×3 Voronoi 焦散 + 双波前拍岸白沫",
	})
	await _shot("03_sea_caustics")

	await _pose(WaterController.CAT_RIVER, "river", {
		"time": 11.3, "ui": false, "rain": 0.0, "debug": 0, "settle": 0.4,
		"caption": "河流 · 单向流动 · 木桥裁切与遮挡",
	})
	await _shot("04_river_bridge")

	await _pose(WaterController.CAT_LAKE, "lake", {
		"time": 5.0, "ui": false, "rain": 0.0, "debug": 0, "settle": 0.4,
		"caption": "内陆湖 · BFS 不贴边 → 自动关海浪 / 关焦散",
	})
	await _shot("05_lake_calm")

	await _pose(WaterController.CAT_SEA, "shallow", {
		"time": 5.5, "ui": false, "rain": 0.0, "debug": 0, "settle": 0.4,
		"caption": "浅滩 · 水下鹅卵石 / 海草 / 两道波前错相拍岸",
	})
	await _shot("06_shallow_foam")

	await _pose(WaterController.CAT_ALL, "full", {
		"time": 12.3, "ui": false, "rain": 0.95, "debug": 0, "settle": 0.5,
		"caption": "降雨 · 同一 Shader 在低洼处积水并生成涟漪",
	})
	await _shot("07_rain_puddles")

	await _pose(WaterController.CAT_ALL, "plaza", {
		"time": 14.1, "ui": false, "rain": 0.95, "debug": 0, "settle": 0.5,
		"caption": "雨积水 · 低洼水膜 + 雨点涟漪 · 复用同一套水面逻辑",
	})
	await _shot("08_rain_closeup")

	await _pose(WaterController.CAT_ALL, "full", {
		"time": 4.0, "ui": false, "rain": 0.0, "debug": 1, "settle": 0.4,
		"caption": "调试 · 水体掩码：青=覆盖 / 蓝=桥面裁切 / 黄=低洼积水",
	})
	await _shot("09_debug_mask")

	await _pose(WaterController.CAT_ALL, "full", {
		"time": 4.0, "ui": false, "rain": 0.0, "debug": 2, "settle": 0.4,
		"caption": "调试 · 2-Pass 8 邻域水深场（直向 1 / 斜向 1.414）",
	})
	await _shot("10_debug_depth")

	await _pose(WaterController.CAT_ALL, "full", {
		"time": 4.0, "ui": false, "rain": 0.0, "debug": 3, "settle": 0.4,
		"caption": "调试 · 零分配 BFS 分类：海 / 河 / 湖 / 积水",
	})
	await _shot("11_debug_category")

	await _pose(WaterController.CAT_ALL, "full", {
		"time": 4.0, "ui": false, "rain": 0.0, "debug": 4, "settle": 0.4,
		"caption": "调试 · 岸线与水深轮廓",
	})
	await _shot("12_debug_shoreline")

	await _pose(WaterController.CAT_RIVER, "river", {
		"time": 4.0, "ui": false, "rain": 0.0, "debug": 1, "settle": 0.4,
		"caption": "桥面裁切特写：桥下水体保留 BFS 连通，绘制时挖空",
	})
	await _shot("13_debug_bridge_cutout")

	await _pose(WaterController.CAT_SEA, "islet", {
		"time": 5.5, "ui": false, "rain": 0.0, "debug": 0, "settle": 0.4,
		"caption": "双波前 · 礁石周围两道白沫环（相位差 0.5）",
	})
	await _shot("14_wavefront_islet")

	print("WATER_SHADER_SHOTS_OK")
	quit(0)


func _pose(focus: int, cam: String, p: Dictionary) -> void:
	_scene.set_paused(false)
	_scene.set_rain(0.0)
	_scene.set_debug_view(0)
	_scene.set_focus(focus)
	var lm: Dictionary = _scene.get_landmarks()
	if lm.has(cam) and cam != "full":
		_scene.set_camera_view(lm[cam]["pos"], lm[cam]["zoom"], true)
	else:
		_scene.snap_camera()
	_scene.set_rain(float(p["rain"]))
	_scene.set_debug_view(int(p["debug"]))
	_scene.set_time_seconds(float(p["time"]))
	_scene.set_ui_visible(bool(p["ui"]))
	_scene.get_hud().sync_from_main()
	_scene.show_caption(String(p["caption"]))
	_scene.set_paused(true)
	await create_timer(float(p.get("settle", 0.35))).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path, " ", image.get_width(), "x", image.get_height())
