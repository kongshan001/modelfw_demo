extends SceneTree

## 1920×1080 截图矩阵（离屏 SubViewport，不受显示器尺寸限制）。
## 运行：godot --path godot-steering --resolution 1280x720 -s tools/screenshot_steering.gd

var _vp: SubViewport
var _scene
var _sim
var _ui
var _camera: Camera2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir := ProjectSettings.globalize_path("res://docs/screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)

	_vp = SubViewport.new()
	_vp.size = Vector2i(1920, 1080)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await process_frame
	_sim = _scene.get_node("Sim")
	_ui = _scene.get_node("UI")
	_camera = _scene.get_node("Camera2D")
	_sim.set_physics_process(false)
	_sim.set_process(false)
	# 1920×1080 原生渲染，镜头 zoom=1.2 等价于 1280×720 下 zoom=0.8 的取景。
	_camera.zoom = Vector2(1.2, 1.2)
	_prepare_ui_scale()

	# 1) 视频同款：流场 + 群体绕 C 形障碍
	_setup("video", 150, 4.4)
	_ui.visible = false
	_sim.select_index(-1)
	await _capture("01_video_flow_1080p.png")

	# 2) 带中文控制台：选中靠近 C 形障碍、胡须命中墙面的单位
	_ui.visible = true
	var cand_ui := _pick_avoidance_candidate()
	_sim.selected = cand_ui
	_sim.agents[cand_ui].avoid_hot = true
	_sim.step_frames(1)
	await create_timer(1.2).timeout
	await _capture("02_ui_1080p.png")
	_ui.visible = false

	# 3) 追逐：移动目标
	_setup("chase", 40, 4.0)
	_select_near(Vector2(1120, 450))
	await _capture("03_chase_1080p.png")

	# 4) 走廊拥堵
	_setup("corridor", 180, 6.0)
	_select_near(Vector2(735, 450))
	await _capture("04_corridor_1080p.png")

	# 5) 羊群
	_setup("flock", 150, 5.0)
	_select_near(Vector2(700, 500))
	await _capture("05_flock_1080p.png")

	# 6) 避障近景：挑一个胡须真正命中 C 形障碍的单位
	_setup("video", 120, 4.0)
	var cand := _pick_avoidance_candidate()
	_camera.position = _sim.agents[cand].pos + Vector2(150, -70)
	_camera.zoom = Vector2(1.75, 1.75)
	_sim.selected = cand
	_sim.agents[cand].avoid_hot = true
	_sim.step_frames(1)
	await _capture("06_closeup_1080p.png")

	print("SCREENSHOTS_OK -> " + out_dir)
	quit(0)


func _prepare_ui_scale() -> void:
	# UI 按 1280×720 设计；在 1920×1080 离屏里整体放大 1.5 倍。
	for child in _ui.get_children():
		if child is Control:
			child.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			child.position = Vector2.ZERO
			child.size = Vector2(1280, 720)
			child.scale = Vector2(1.5, 1.5)


func _setup(preset: String, count: int, seconds: float) -> void:
	_sim.seed_value = 20261121
	_sim.target_count = count
	_sim.apply_preset(preset)
	_sim.set_show("vectors", true)
	_sim.set_show("rays", true)
	_sim.set_show("neighbors", true)
	_sim.set_show("flow", preset == "video" or preset == "corridor")
	_sim.set_show("highlight", true)
	_sim.step_frames(int(seconds * 60.0))


func _select_near(point: Vector2) -> void:
	var best := -1
	var best_d := INF
	for i in _sim.agents.size():
		var d: float = _sim.agents[i].pos.distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = i
	_sim.select_index(best)


func _pick_avoidance_candidate() -> int:
	var best := 0
	var best_score := -INF
	for i in _sim.agents.size():
		var a = _sim.agents[i]
		if a.pos.distance_to(Vector2(680, 450)) > 320.0:
			continue
		_sim.selected = i
		_sim._avoidance_force(a)
		var hits := 0
		for rec in a.rays:
			if rec.get("hit", false):
				hits += 1
		if hits == 0:
			continue
		var score: float = hits * 10000.0 - a.pos.distance_to(Vector2(600, 500))
		if score > best_score:
			best_score = score
			best = i
	return best


func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://docs/screenshots/" + file_name)
	var err := image.save_png(path)
	if err != OK:
		push_error("截图保存失败: " + path)
	else:
		print("saved " + file_name + "  " + str(image.get_size()))
