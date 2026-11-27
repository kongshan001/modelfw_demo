extends SceneTree

# 无头验收：节点/程序化贴图、六个参数、单格/3×3、七个分析视图、
# 四个构成开关、水面微光、池底/熔岩切换、焦点、相机、重置与中文 HUD。
# 末行必须为 POOL_CAUSTICS_SMOKE_OK。
# 用法：godot --headless --path godot-pool-caustics -s tools/smoke_pool_caustics.gd

var _fails: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await create_timer(0.25).timeout

	var world = scene.get_pool_world()
	var hud = scene.get_hud()
	var cam = scene.get_pool_camera()
	_check(world != null, "pool world missing")
	_check(world.floor_material != null, "floor material missing")
	_check(world.rock_materials.size() == 2, "expected two rock materials")
	_check(world.rocks.size() == 6, "expected six hero rocks")
	_check(world.water_veil != null, "water veil missing")
	_check(world.bed_texture != null, "riverbed texture missing")
	if world.bed_texture != null:
		_check(world.bed_texture.get_width() == 640, "riverbed width should be 640")
		_check(world.bed_texture.get_height() == 640, "riverbed height should be 640")
	_check(world._rock_meshes.size() == 3, "three rock mesh variants expected")

	var floor_shader: Shader = world.floor_material.shader
	var rock_shader: Shader = world.rock_materials[0].shader
	_check(floor_shader != null and floor_shader.code.contains("caustic_fields"),
			"floor shader should include caustic core")
	_check(rock_shader != null and rock_shader.code.contains("caustic_fields"),
			"rock shader should include caustic core")
	_check(floor_shader.code.contains("u_rock_shadows"), "floor shader missing rock shadows")

	# 默认参数与 HUD 接线
	var st: Dictionary = scene.get_state()
	_check(st["variant"] == 0 and st["debug"] == 0 and st["search_3x3"] == true,
			"unexpected default state")
	_check(not bool(st["paused"]), "project should start unpaused")
	_check((st["params"] as Dictionary).has("flow"), "flow direction param missing")
	_check(hud._sliders.size() == 6, "expected 6 parameter sliders, got %d" % hud._sliders.size())
	_check(hud._debug_buttons.size() == 7, "expected 7 debug views")
	_check(hud._toggle_buttons.size() == 7, "expected 7 toggle buttons")

	# 连续参数
	var values := {"scale": 1.35, "width": 0.063, "softness": 0.71,
			"brightness": 1.22, "speed": 0.82, "flow": 44.0}
	for key in values:
		scene.set_param(key, values[key])
		_check(is_equal_approx(float(scene.get_state()["params"][key]), values[key]),
				"param %s not stored" % key)
		for mat in world.all_caustic_materials():
			var uniform: String = {
				"scale": "u_scale", "width": "u_width", "softness": "u_softness",
				"brightness": "u_brightness", "speed": "u_speed", "flow": "u_flow_angle",
			}[key]
			_check(absf(float(mat.get_shader_parameter(uniform)) - values[key]) < 0.001,
					"uniform %s not updated on %s" % [uniform, mat.resource_path])
	_check(hud._sliders["scale"].value == 1.35, "HUD scale slider did not sync")

	# 单格 vs 3×3
	scene.set_search_3x3(false)
	_check(scene.get_state()["search_3x3"] == false, "search mode not stored")
	_check(is_equal_approx(float(world.get_shared_param("u_search_3x3")), 0.0),
			"u_search_3x3 should be 0")
	_check(hud._mode_label.text.contains("单格"), "HUD should label single-cell mode")
	_check(hud._warn_label.visible, "single-cell warning should be visible")
	scene.set_debug_mode(3)
	_check(hud._warn_label.text.contains("无有效 F2"), "single F2 gap warning missing")

	scene.set_debug_mode(0)
	scene.set_search_3x3(true)
	for mode in range(7):
		scene.set_debug_mode(mode)
		_check(int(world.get_shared_param("u_debug")) == mode, "debug uniform %d" % mode)
		_check(scene.get_state()["debug"] == mode, "debug state %d" % mode)
	scene.set_debug_mode(0)

	# 构成开关
	scene.set_toggle("warp", false)
	_check(not scene.get_state()["warp"], "warp toggle state")
	_check(is_equal_approx(float(world.get_shared_param("u_warp_amount")), 0.0),
			"warp uniform not zero")
	scene.set_toggle("warp", true)
	_check(float(world.get_shared_param("u_warp_amount")) > 0.1, "warp uniform not restored")

	scene.set_toggle("junction", false)
	_check(is_equal_approx(float(world.get_shared_param("u_junction")), 0.0),
			"junction uniform not zero")
	scene.set_toggle("junction", true)
	scene.set_toggle("gather", false)
	_check(is_equal_approx(float(world.get_shared_param("u_gather")), 0.0),
			"gather uniform not zero")
	scene.set_toggle("gather", true)
	scene.set_toggle("soft", false)
	_check(is_equal_approx(float(world.get_shared_param("u_soft_light")), 0.0),
			"soft-light uniform not zero")
	scene.set_toggle("soft", true)

	scene.set_toggle("surface", false)
	_check(not world.water_veil.visible, "water veil should hide")
	scene.set_toggle("surface", true)
	_check(world.water_veil.visible, "water veil should show")

	scene.set_debug_mode(3)
	_check(not world.water_veil.visible, "water veil should hide for analysis view")
	scene.set_debug_mode(0)
	_check(world.water_veil.visible, "water veil should return for final view")

	# 焦点 / 相机的屏幕到池底射线
	var vp_size: Vector2 = scene.get_viewport().get_visible_rect().size
	var hit = cam.screen_to_floor(vp_size * 0.5)
	_check(hit != null, "center ray should hit pool floor")
	if hit != null:
		_check(absf((hit as Vector3).y) < 0.01, "ray hit should be on y=0")
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = vp_size * 0.5
		scene._unhandled_input(ev)
		_check(float(scene.get_state()["focus"]) > 0.9, "click should set focus")

	# 熔岩变体与恢复
	var pool_line: Color = world.get_shared_param("u_line_color")
	scene.set_variant(1)
	_check(scene.get_state()["variant"] == 1, "lava variant state")
	_check(is_equal_approx(float(world.get_shared_param("u_style")), 1.0), "lava style uniform")
	_check(float(world.get_shared_param("u_gap_threshold")) > 0.0, "lava threshold missing")
	_check(not world.water_veil.visible, "lava should hide water veil")
	_check((world.get_shared_param("u_line_color") as Color) != pool_line, "lava line color unchanged")
	_check(scene.environment.background_color.r > 0.01, "lava background should warm")
	scene.set_variant(0)
	_check(is_equal_approx(float(world.get_shared_param("u_style")), 0.0), "pool style restore")
	_check(world.water_veil.visible, "pool water veil restore")

	# 暂停时间
	scene.toggle_pause()
	_check(bool(scene.get_state()["paused"]), "pause toggle")
	scene.toggle_pause()
	_check(not bool(scene.get_state()["paused"]), "resume toggle")
	scene.set_time_override(9.25)
	_check(is_equal_approx(float(scene.get_state()["time"]), 9.25), "time override")
	_check(absf(float(world.get_shared_param("u_time")) - 9.25) < 0.001, "time uniform")

	# 重置
	scene.set_param("scale", 1.9)
	scene.set_toggle("warp", false)
	scene.set_search_3x3(false)
	scene.set_debug_mode(4)
	scene.set_ui_visible(false)
	scene.reset_all()
	st = scene.get_state()
	_check(st["variant"] == 0 and st["debug"] == 0 and st["search_3x3"] == true,
			"reset modes")
	_check(bool(st["warp"]) and bool(st["junction"]) and bool(st["gather"]) and bool(st["soft"]),
			"reset toggles")
	_check(bool(st["ui"]), "reset UI visibility")
	_check(absf(float(st["params"]["scale"]) - 0.72) < 0.001, "reset scale")
	_check(bool(st["camera_auto"]), "reset camera auto orbit")
	_check(absf(float(st["focus"])) < 0.001, "reset focus")

	# 最后一帧避免任何遗留错误；UI 与 shader 时间都在运行。
	await process_frame
	if _fails.is_empty():
		print("POOL_CAUSTICS_SMOKE checks=%d" % _checks)
		print("POOL_CAUSTICS_SMOKE_OK")
		quit(0)
	else:
		for f in _fails:
			printerr("POOL_CAUSTICS_SMOKE_FAIL ", f)
		print("POOL_CAUSTICS_SMOKE_FAILED checks=%d failures=%d" % [_checks, _fails.size()])
		quit(1)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(message)
		printerr("FAIL: ", message)
