extends SceneTree

# 无头验收：
#   16px 抠图 / 2-Pass 8 邻域深度（含斜向 1.414）/ 零分配 BFS 海河湖分类 /
#   桥面裁切与桥下水体连通 / 单水面 shader 且无额外水面网格 /
#   三水体预设 / 潮汐等参数 / 雨积水复用同一 shader / 暂停 / 重建可复现 / 中文 HUD。
# 用法：godot --headless --path godot-water-shader -s tools/smoke_water_shader.gd

var _fails: Array[String] = []
var _checks := 0


func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.20).timeout

	var pipeline: WaterPipeline = scene.get_pipeline()
	var ctrl: WaterController = scene.get_controller()
	var mat: ShaderMaterial = scene.get_water_material()
	var stats: Dictionary = scene.get_stats()
	var shader_code: String = mat.shader.code if mat.shader != null else ""

	# ── 16px 栅格 / 掩码 ───────────────────────────────────────────────
	_check(pipeline.cell == 16, "cell size != 16")
	_check(pipeline.cols == 80 and pipeline.rows == 45,
			"grid != 80x45: %dx%d" % [pipeline.cols, pipeline.rows])
	_check(pipeline.src_size == Vector2i(1280, 720), "source != 1280x720")
	var mask_img: Image = pipeline.images["mask"]
	_check(mask_img.get_width() == 80 and mask_img.get_height() == 45, "mask texture size wrong")
	var depth_img: Image = pipeline.images["depth"]
	var cat_img: Image = pipeline.images["category"]
	_check(cat_img.get_width() == 80, "category texture size wrong")
	_check(pipeline.bridge_cells > 20, "bridge cutout cells too few: %d" % pipeline.bridge_cells)

	# 实际水体：覆盖格均为硬水，陆地不是。
	var sea_edge := Vector2i(5, 22)
	_check(pipeline.get_hard(sea_edge), "sea edge cell should be water")
	_check(pipeline.get_depth_cells(sea_edge) > 3.0, "open sea should be deep")
	_check(not pipeline.get_hard(Vector2i(40, 20)), "inland cell should be land")
	var min_d := 999.0
	var max_d := 0.0
	for y in pipeline.rows:
		for x in pipeline.cols:
			if pipeline.get_hard(Vector2i(x, y)):
				var dc := pipeline.get_depth_cells(Vector2i(x, y))
				min_d = minf(min_d, dc)
				max_d = maxf(max_d, dc)
	_check(min_d >= 0.99 and min_d < 1.6, "shallowest water distance odd: %.2f" % min_d)
	_check(max_d > 10.0, "deepest water distance too small: %.2f" % max_d)

	# 2-Pass 8 邻域：合成 4×4 水格，挖掉左上角，检查 (2,2) 的斜向距离 = 1.414。
	var synth := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	synth.fill(Color(0, 0, 0, 1))
	for y in 64:
		for x in 64:
			synth.set_pixel(x, y, Color(1, 0, 0, 1))
	for y in range(16, 32):
		for x in range(16, 32):
			synth.set_pixel(x, y, Color(0, 0, 0, 0))
	var sp := WaterPipeline.new()
	sp.build(synth, 16)
	_check(sp.cols == 4 and sp.rows == 4, "synthetic grid wrong")
	var diag := sp.get_depth_cells(Vector2i(2, 2))
	_check(absf(diag - 1.41421356) < 0.02,
			"8-neighbour diagonal distance should be 1.414, got %.3f" % diag)
	_check(sp.get_depth_cells(Vector2i(3, 3)) > diag,
			"depth should increase away from the single land pocket")

	# ── BFS：三个水体 / 内陆湖关浪与焦散 / 流动方向 ────────────────────
	var bodies: Array = scene.get_bodies()
	_check(bodies.size() == 3, "expected 3 water bodies (bridge must not split river), got %d" % bodies.size())
	var types := {}
	for b in bodies:
		types[b["type"]] = b
	_check(types.has("sea") and types.has("river") and types.has("lake"),
			"missing sea/river/lake classification: %s" % str(types.keys()))
	var sea: Dictionary = types.get("sea", {})
	var river: Dictionary = types.get("river", {})
	var lake: Dictionary = types.get("lake", {})
	_check(bool(sea.get("enclosed", true)) == false, "sea should touch map border")
	_check(float(sea.get("avg_width", 0.0)) > float(river.get("avg_width", 0.0)),
			"sea should be wider than river")
	_check(bool(lake.get("enclosed", false)), "inland lake should be enclosed")
	_check(not bool(lake.get("waves", true)), "inland lake should disable waves")
	_check(not bool(lake.get("caustics", true)), "inland lake should disable caustics")
	_check(bool(stats.get("lake_caustic_off", false)), "lake caustic flag missing")
	_check(int(stats.get("body_count", 0)) == 3, "stats body_count != 3")
	_check(int(stats.get("lake_count", 0)) == 1, "stats lake_count != 1")

	var lake_center := pipeline.cell_at(lake["center"])
	var river_center := pipeline.cell_at(river["center"])
	_check(pipeline.get_category(lake_center) == WaterPipeline.CAT_LAKE, "lake center category wrong")
	_check(pipeline.get_category(river_center) == WaterPipeline.CAT_RIVER, "river center category wrong")
	_check(pipeline.get_flow(lake_center).length() < 0.01, "lake flow should be zero")
	_check(pipeline.get_flow(river_center).length() > 0.5, "river flow direction missing")
	_check(absf(float(cat_img.get_pixel(lake_center.x, lake_center.y).r) - 0.75) < 0.01,
			"lake category texture should store 3")

	# ── 桥面裁切 / 桥下水体连通 / 前景遮挡 ────────────────────────────
	var bridge_rect: Rect2 = scene.get_pipeline().bridge_rect
	var bridge_cell := pipeline.cell_at(bridge_rect.get_center())
	_check(pipeline.is_bridge_cell(bridge_cell), "bridge center not marked as cutout")
	_check(pipeline.is_under_bridge_water(bridge_cell),
			"bridge center should retain underlying water for connectivity")
	_check(pipeline.get_category(bridge_cell) == WaterPipeline.CAT_RIVER,
			"bridge center should still be classified as river")
	var mpx := mask_img.get_pixel(bridge_cell.x, bridge_cell.y)
	_check(mpx.r < 0.01 and mpx.b > 0.99, "bridge mask channels should be R=0 / B=1")
	var fg: Sprite2D = scene.get_foreground_sprite()
	var wl: ColorRect = scene.get_water_layer()
	_check(fg != null and fg.texture != null, "bridge foreground layer missing")
	_check(fg.z_index > wl.z_index, "bridge foreground must draw above water")
	var bridge_px := 0
	var bridge_img: Image = scene.get_foreground_sprite().texture.get_image()
	var bridge_data := bridge_img.get_data()
	for i in range(3, bridge_data.size(), 64):
		if bridge_data[i] > 0:
			bridge_px += 1
	_check(bridge_px > 100, "foreground bridge art looks empty")
	scene.set_debug_view(0)
	_check(fg.visible, "foreground hidden in normal view")
	scene.set_debug_view(1)
	_check(not fg.visible, "foreground should hide in debug view")
	scene.set_debug_view(0)

	# ── 单水面 shader / 没有额外水面网格 ──────────────────────────────
	_check(scene.count_water_surfaces() == 1, "expected exactly 1 water surface overlay")
	_check(scene.find_children("*", "MeshInstance2D", true, false).is_empty(),
			"MeshInstance2D found (no water meshes allowed)")
	_check(scene.find_children("*", "Polygon2D", true, false).is_empty(),
			"Polygon2D found (no water meshes allowed)")
	var shader_nodes := 0
	for n in scene.find_children("*", "CanvasItem", true, false):
		if n.material is ShaderMaterial:
			var sm: ShaderMaterial = n.material
			if sm == mat:
				shader_nodes += 1
	_check(shader_nodes == 1, "water ShaderMaterial should be used by exactly 1 node")
	_check(shader_code.count("shader_type canvas_item;") == 1, "shader_type must appear once")
	_check(shader_code.contains("u_mask") and shader_code.contains("u_depth"), "mask/depth uniforms missing")
	_check(shader_code.contains("u_category") and shader_code.contains("u_flow"), "category/flow uniforms missing")
	_check(shader_code.contains("voronoi_edge"), "Voronoi caustic missing")
	_check(shader_code.contains("rain_rings"), "rain ripple logic missing")
	_check(shader_code.contains("u_puddle_mask") and shader_code.contains("u_puddle_depth"),
			"puddle uniforms missing from the shared shader")

	# ── 三套预设 / 全局倍率 / uniform 接线 ────────────────────────────
	var p_sea: Dictionary = ctrl.effective(WaterController.CAT_SEA)
	var p_river: Dictionary = ctrl.effective(WaterController.CAT_RIVER)
	var p_lake: Dictionary = ctrl.effective(WaterController.CAT_LAKE)
	_check(float(p_lake["wave"]) < float(p_sea["wave"]) * 0.15, "lake wave not suppressed")
	_check(float(p_lake["caustic"]) == 0.0, "lake caustic must be 0")
	_check(float(p_river["flow"]) > float(p_sea["flow"]), "river should flow faster than sea")
	_check(float(p_sea["foam"]) > float(p_river["foam"]), "sea foam should exceed river foam")
	_check(float(p_river["foam"]) > float(p_lake["foam"]), "lake foam should be the weakest")
	var u_wave: Vector3 = mat.get_shader_parameter("u_wave")
	var u_caustic: Vector3 = mat.get_shader_parameter("u_caustic")
	var u_flow: Vector3 = mat.get_shader_parameter("u_flow_speed")
	_check(u_wave.x > u_wave.y and u_wave.y > u_wave.z, "wave preset vector wrong: %s" % str(u_wave))
	_check(absf(u_caustic.z) < 0.0001, "lake caustic uniform should be zero")
	_check(u_flow.y > u_flow.x, "river flow uniform should exceed sea")
	_check(mat.get_shader_parameter("u_mask") != null, "u_mask not bound")
	_check(mat.get_shader_parameter("u_depth") != null, "u_depth not bound")
	_check(mat.get_shader_parameter("u_category") != null, "u_category not bound")
	_check(mat.get_shader_parameter("u_flow") != null, "u_flow not bound")
	_check(mat.get_shader_parameter("u_puddle_mask") != null, "u_puddle_mask not bound")
	_check(mat.get_shader_parameter("u_puddle_depth") != null, "u_puddle_depth not bound")
	_check(mat.get_shader_parameter("u_ground") != null, "u_ground not bound")

	scene.set_param("tide", 1.0)
	_check(absf(float(mat.get_shader_parameter("u_tide")) - 1.0) < 0.001, "tide uniform not wired")
	scene.set_param("wave", 1.7)
	var wave_now: Vector3 = mat.get_shader_parameter("u_wave")
	_check(absf(wave_now.x - 1.7 * 1.15) < 0.02,
			"wave slider not wired to preset vector")
	scene.set_param("tide", 0.5)
	scene.set_param("wave", 1.0)
	scene.set_focus(WaterController.CAT_SEA)
	_check(absf(float(mat.get_shader_parameter("u_focus")) - 1.0) < 0.001, "focus uniform not wired")
	scene.set_focus(WaterController.CAT_ALL)
	_check(absf(float(mat.get_shader_parameter("u_focus"))) < 0.001, "focus reset failed")

	# ── 雨积水：同一 shader / 低洼数据 / 雨量 uniform ──────────────────
	_check(scene.get_rain() <= 0.01, "rain should be off initially")
	_check(int(stats["puddle_cells"]) > 20, "lowland puddle cells missing")
	var puddle_cell := Vector2i(-1, -1)
	for y in pipeline.rows:
		for x in pipeline.cols:
			if pipeline.get_lowland(Vector2i(x, y)):
				puddle_cell = Vector2i(x, y)
				break
		if puddle_cell.x >= 0:
			break
	_check(puddle_cell.x >= 0, "no lowland cell found")
	_check(pipeline.get_category(puddle_cell) == WaterPipeline.CAT_PUDDLE,
			"lowland cell should be category 4")
	_check(pipeline.get_puddle_depth(puddle_cell) > 0.0, "puddle depth missing")
	_check(absf(float(cat_img.get_pixel(puddle_cell.x, puddle_cell.y).r) - 1.0) < 0.01,
			"puddle category texture should store 4")
	_check(scene.count_water_surfaces() == 1, "puddles must reuse the single water surface")
	scene.set_rain(0.9)
	_check(absf(float(mat.get_shader_parameter("u_rain")) - 0.9) < 0.001, "rain uniform not wired")
	_check(scene.is_raining(), "rain state not set")
	_check(not shader_code.contains("u_puddle_shader"), "puddles must not use a second shader")
	scene.set_rain(0.0)
	_check(not scene.is_raining(), "rain not turned off")

	# ── 调试视图 / 岸线视图 / 暂停 ───────────────────────────────────
	for v in [1, 2, 3, 4]:
		scene.set_debug_view(v)
		_check(int(mat.get_shader_parameter("u_debug")) == v, "debug uniform %d not applied" % v)
		_check(not fg.visible, "foreground should hide in debug %d" % v)
		var legend_label: Label = scene.get_hud()._legend
		_check(legend_label.text.length() > 4, "debug legend empty")
	scene.set_debug_view(4)
	_check(String(scene.get_hud()._legend.text).contains("岸线"), "shoreline legend missing")
	scene.set_debug_view(0)
	_check(fg.visible, "foreground did not return after debug off")

	scene.set_paused(false)
	scene.set_time_seconds(3.0)
	scene.set_paused(true)
	await create_timer(0.22).timeout
	_check(absf(scene.get_time() - 3.0) < 0.001, "paused time advanced")
	scene.set_paused(false)
	await create_timer(0.22).timeout
	_check(scene.get_time() > 3.05, "time does not advance after unpause")

	# ── 重置 ─────────────────────────────────────────────────────────
	scene.set_param("tide", 0.9)
	scene.set_param("flow", 1.8)
	scene.set_rain(0.8)
	scene.set_focus(WaterController.CAT_LAKE)
	scene.set_debug_view(3)
	scene.set_paused(true)
	scene.reset()
	await process_frame
	var rp: Dictionary = scene.get_params()
	_check(absf(float(rp["tide"]) - 0.5) < 0.001, "reset tide wrong")
	_check(absf(float(rp["flow"]) - 1.0) < 0.001, "reset flow wrong")
	_check(absf(float(rp["rain"])) < 0.001, "reset rain wrong")
	_check(int(rp["focus"]) == 0 and int(rp["debug"]) == 0, "reset focus/debug wrong")
	_check(not bool(rp["paused"]), "reset should unpause")
	_check(absf(scene.get_time()) < 0.05, "reset time wrong")
	_check(fg.visible, "reset should show foreground")
	_check(absf(float(mat.get_shader_parameter("u_tide")) - 0.5) < 0.001, "reset uniform not applied")

	# ── 重建 / 保存可复现 ────────────────────────────────────────────
	_check(scene.rebuild_pipeline(), "pipeline rebuild is not reproducible")
	var rebuilt_bodies: Array = scene.get_bodies()
	_check(rebuilt_bodies.size() == 3, "rebuilt pipeline should still have 3 bodies")
	_check(scene.count_water_surfaces() == 1, "rebuild created an extra water surface")
	_check(scene.get_water_material().get_shader_parameter("u_mask") != null,
			"rebuilt mask texture not rebound")
	var files_ok := true
	for f in ["mask", "depth", "category", "flow", "puddle_mask", "puddle_depth", "meta"]:
		if not FileAccess.file_exists("res://docs/pipeline/%s.png" % f) \
				and not FileAccess.file_exists("res://docs/pipeline/%s.json" % f):
			files_ok = false
	_check(files_ok, "pipeline output files missing under docs/pipeline")
	_check(FileAccess.file_exists("res://docs/pipeline/source_mask_1280.png"), "source mask not saved")
	var meta := {}
	var mf := FileAccess.open("res://docs/pipeline/meta.json", FileAccess.READ)
	if mf != null:
		meta = JSON.parse_string(mf.get_as_text())
	_check(meta is Dictionary and int(meta.get("body_count", 0)) == 3, "meta.json body_count wrong")
	_check(int(meta.get("cell", 0)) == 16, "meta.json cell wrong")

	# ── HUD / 中文 / FPS / draw calls ─────────────────────────────────
	var labels: Array = scene.find_children("*", "Label", true, false)
	var chinese := 0
	for l in labels:
		if l.text.contains("水") or l.text.contains("海") or l.text.contains("雨") or l.text.contains("深度"):
			chinese += 1
	_check(chinese >= 4, "Chinese HUD labels missing (%d)" % chinese)
	_check(scene.get_hud()._sliders.size() >= 6, "expected 6 parameter sliders")
	_check(scene.get_hud()._focus_buttons.size() == 4, "expected 4 water focus buttons")
	_check(String(scene.get_hud()._legend.text).length() > 0, "HUD legend missing")
	_check(String(scene.pipeline_summary()).contains("海") and String(scene.pipeline_summary()).contains("湖"),
			"pipeline summary missing Chinese body names")
	_check(scene.get_fps() >= 0, "fps query failed")
	_check(scene.get_draw_calls() >= 0, "draw calls query failed")
	_check(scene.get_hud()._debug_option.item_count == 5, "debug option should have 5 entries")

	# 滑杆与按钮接线（改 HUD 值应写回主控）。
	var rain_slider: HSlider = scene.get_hud()._sliders["rain"]
	rain_slider.value = 0.40
	_check(absf(scene.get_rain() - 0.40) < 0.001, "HUD rain slider not wired")
	scene.set_rain(0.0)

	if _fails.is_empty():
		print("WATER_SHADER_SMOKE_OK checks=%d" % _checks)
		quit(0)
	else:
		for f in _fails:
			printerr("WATER SHADER SMOKE FAIL: ", f)
		quit(1)


func _check(ok: bool, msg: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(msg)
