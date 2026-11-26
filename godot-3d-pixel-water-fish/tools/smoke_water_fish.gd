extends SceneTree

# Headless 自测：分辨率/缩放、两段式 viewport、水面参数、鱼群群游、
# 视角切换、调试视图、时段/天气、HUD 按钮接线。
# 末行输出 WATER_FISH_SMOKE_OK。

const MAIN_SCENE := "res://scenes/main.tscn"
var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed: PackedScene = load(MAIN_SCENE)
	if packed == null:
		_fail("main scene missing")
		_finish()
		return
	var main = packed.instantiate()
	root.add_child(main)
	await _frames(8)

	# 1. 低分辨率 RT / 整数倍缩放
	_check(main.internal_size == Vector2i(640, 360), "default internal 640x360")
	_check(main.viewport.size == Vector2i(640, 360), "world viewport size")
	_check(main.composite_viewport.size == Vector2i(640, 360), "composite viewport size")
	_check(main.compute_display_scale(Vector2(1280, 720), Vector2i(640, 360)) == 2, "1280 -> 2x")
	_check(main.compute_display_scale(Vector2(1920, 1080), Vector2i(640, 360)) == 3, "1920 -> 3x")
	_check(main.screen_rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "nearest display filter")
	main.set_param("internal_index", 0)
	await _frames(2)
	_check(main.internal_size == Vector2i(320, 180), "switch internal 320x180")
	_check(main.viewport.size == Vector2i(320, 180), "world viewport follows")
	_check(main.composite_viewport.size == Vector2i(320, 180), "composite viewport follows")
	main.set_param("internal_index", 1)
	await _frames(2)
	_check(main.internal_size == Vector2i(480, 270), "switch internal 480x270")
	main.set_param("internal_index", 2)
	await _frames(2)
	_check(main.internal_size == Vector2i(640, 360), "restore internal 640x360")
	_check(main.post_material != null and main.post_material.get_shader_parameter("world_tex") != null, "post world texture bound")

	# 2. 水面参数
	main.set_param("clarity", 0.2)
	main.set_param("refraction", 1.1)
	main.set_param("foam", 1.5)
	main.set_param("caustics", 1.6)
	var p: Dictionary = main.get_params()
	_check(is_equal_approx(float(p["clarity"]), 0.2), "clarity applied")
	_check(is_equal_approx(float(p["refraction"]), 1.1), "refraction applied")
	_check(is_equal_approx(float(p["foam"]), 1.5), "foam applied")
	_check(is_equal_approx(float(p["caustics"]), 1.6), "caustics applied")
	_check(is_equal_approx(float(main.world.water_material.get_shader_parameter("refraction")), 1.1), "water material refraction")
	main.set_param("clarity", 0.45)
	main.set_param("refraction", 0.4)
	main.set_param("foam", 0.45)
	main.set_param("caustics", 1.0)

	# 3. 鱼群生成与群游
	main.set_param("fish_count", 21)
	await _frames(2)
	_check(main.fish_manager.get_fish_count() == 21, "fish count 21")
	var species: Array = main.fish_manager.get_species_counts()
	_check(species[0] > 0 and species[1] > 0 and species[2] > 0, "three species present")
	var before: Array[Vector3] = main.fish_manager.get_positions()
	main.prewarm_simulation(2.0)
	var after: Array[Vector3] = main.fish_manager.get_positions()
	var moved := 0
	for i in mini(before.size(), after.size()):
		if before[i].distance_to(after[i]) > 0.02:
			moved += 1
	_check(moved >= mini(10, after.size()), "fish positions update")
	_check(main.fish_manager.all_inside_water(), "fish stay inside water")

	# 4. 暂停冻结
	main.set_param("paused", true)
	var frozen: Array[Vector3] = main.fish_manager.get_positions()
	main.prewarm_simulation(1.0)
	var frozen2: Array[Vector3] = main.fish_manager.get_positions()
	var drift := 0.0
	for i in mini(frozen.size(), frozen2.size()):
		drift = maxf(drift, frozen[i].distance_to(frozen2[i]))
	_check(drift < 0.0001, "pause freezes fish")
	main.set_param("paused", false)

	# 5. 视角切换
	main.apply_camera_view(0.0, -4.0, 4.5, Vector3(-0.8, -0.35, -1.0), true)
	await _frames(2)
	_check(main.mode_underwater, "underwater mode flag")
	_check(main.camera.global_position.y < -0.02, "underwater camera below surface")
	_check(main.get_underwater_amount() > 0.5, "underwater shader blend")
	main.apply_camera_view(26.0, 60.0, 16.0, Vector3(0.0, 0.1, 0.0), false)
	await _frames(2)
	_check(not main.mode_underwater, "above mode flag")
	_check(main.camera.global_position.y > 0.5, "above camera above water")

	# 6. 调试视图
	for mode in [1, 2, 3, 4, 5]:
		main.set_param("debug", mode)
		await _frames(1)
		_check(main.debug_mode == mode, "debug mode %d" % mode)
		_check(is_equal_approx(float(main.post_material.get_shader_parameter("debug_mode")), float(mode)), "post debug %d" % mode)
		if mode == 2 or mode == 3:
			_check(main._debug_overrides_active, "material override for debug %d" % mode)
		if mode == 5:
			_check(is_equal_approx(float(main.world.water_material.get_shader_parameter("debug_mask")), 1.0), "water mask debug")
	main.set_param("debug", 0)
	await _frames(1)
	_check(not main._debug_overrides_active, "debug overrides restored")
	_check(main.world.water.visible, "water restored after debug")

	# 7. 时段/天气/雨量
	main.set_param("preset", 2)
	await _frames(1)
	_check(absf(main.time_of_day - 0.8) < 0.02, "golden preset time")
	_check(not main.weather_rain, "golden preset clear")
	main.set_param("preset", 3)
	main.prewarm_simulation(2.0)
	await _frames(1)
	_check(main.weather_rain, "night preset rain")
	_check(main.rain_amount > 0.5, "rain amount ramps")
	main.set_param("preset", 1)
	main.prewarm_simulation(1.0)

	# 8. HUD 内部按钮接线
	if main.hud != null and main.hud._res_buttons.size() == 3:
		main.hud._res_buttons[0].pressed.emit()
		await _frames(1)
		_check(main.internal_index == 0, "HUD 320 button")
		main.hud._res_buttons[2].pressed.emit()
		await _frames(1)
		_check(main.internal_index == 2, "HUD 640 button")
	else:
		_fail("HUD resolution buttons missing")

	# 9. 相机输入/自动环绕开关
	main.set_param("auto_orbit", false)
	_check(not main.auto_orbit, "auto orbit off")
	main.set_param("auto_orbit", true)

	_finish(main)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("[PASS] ", label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failed = true
	push_error("[SMOKE FAIL] " + label)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish(main = null) -> void:
	if main != null:
		root.remove_child(main)
		main.free()
	await _frames(2)
	if _failed:
		print("WATER_FISH_SMOKE_FAILED")
		quit(1)
	else:
		print("WATER_FISH_SMOKE_OK")
		quit(0)
