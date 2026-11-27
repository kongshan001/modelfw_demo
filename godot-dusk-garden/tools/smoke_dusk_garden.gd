extends SceneTree

# Headless 自测（无 GPU）：
# 像素化链路/整数缩放、时间映射、路灯错峰与开关、萤火活动度与开关、
# 角色移动/点击寻路、相机跟随/覆盖、暂停、水面灯光参数、HUD 参数。
# 末行必须输出 DUSK_GARDEN_SMOKE_OK。

const MAIN_SCENE := "res://scenes/main.tscn"
var _failed := false
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load(MAIN_SCENE)
	if packed == null:
		_fail("main.tscn missing")
		_finish()
		return
	var main = packed.instantiate()
	root.add_child(main)
	await _frames(12)

	# 1. 视口 / 最近邻 / 整数倍
	_check(main.internal_size == Vector2i(640, 360), "default internal 640x360")
	_check(main.world_viewport.size == Vector2i(640, 360), "world viewport size")
	_check(main.post_viewport.size == Vector2i(640, 360), "post viewport size")
	_check(main.compute_display_scale(Vector2(1280, 720), Vector2i(640, 360)) == 2, "1280 -> 2x")
	_check(main.compute_display_scale(Vector2(1920, 1080), Vector2i(640, 360)) == 3, "1920 -> 3x")
	_check(main.compute_display_scale(Vector2(1280, 720), Vector2i(480, 270)) == 2, "480 letterbox -> 2x")
	var r480: Rect2 = main.compute_screen_rect(Vector2(1280, 720), Vector2i(480, 270))
	_check(r480.size == Vector2(960, 540), "480 screen rect 960x540")
	_check(r480.position == Vector2(160, 90), "480 screen rect centered")
	_check(main.screen.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "display nearest")
	_check(main.post_mat != null and main.post_mat.get_shader_parameter("world_tex") != null, "post world texture bound")
	main.set_param("internal_index", 1)
	await _frames(2)
	_check(main.internal_size == Vector2i(480, 270), "switch to 480x270")
	_check(main.world_viewport.size == Vector2i(480, 270), "world viewport follows 480")
	_check(main.post_viewport.size == Vector2i(480, 270), "post viewport follows 480")
	main.set_param("internal_index", 2)
	await _frames(2)

	# 2. 时间映射 / 环境状态
	main.set_param("auto", false)
	main.set_time_of_day(0.0)
	_check(main.get_clock_text() == "18:30", "clock 18:30 at t=0")
	_check(main.get_phase_label() == "黄昏", "phase dusk at t=0")
	main.set_time_of_day(1.0)
	_check(main.get_clock_text() == "22:30", "clock 22:30 at t=1")
	_check(main.get_phase_label() == "深夜", "phase night at t=1")
	_check(main.night_amount > 0.9, "night amount at t=1")
	var dusk_state: Dictionary = main._sample_time(0.02)
	var night_state: Dictionary = main._sample_time(0.98)
	_check(float(night_state["night"]) > float(dusk_state["night"]), "night increases")
	_check((night_state["sky_top"] as Color).get_luminance() < (dusk_state["sky_top"] as Color).get_luminance(), "sky darkens")
	_check(float(night_state["moon_sky"]) > float(dusk_state["moon_sky"]), "moon strength rises")
	_check(float(night_state["star"]) > float(dusk_state["star"]), "stars rise")

	# 3. 路灯：0 盏 → 全亮；阈值递增；开关
	var thresholds: Array = main.world.get_lamp_thresholds()
	_check(thresholds.size() == 6, "six lamps")
	var increasing := true
	for i in range(1, thresholds.size()):
		if float(thresholds[i]) <= float(thresholds[i - 1]):
			increasing = false
	_check(increasing, "lamp thresholds staggered")
	main.set_time_of_day(0.0)
	await _frames(2)
	_check(main.get_lit_lamp_count() == 0, "no lamps at dusk start")
	var low_sum := _sum(main.get_lamp_levels())
	main.set_time_of_day(0.55)
	await _frames(2)
	var mid_sum := _sum(main.get_lamp_levels())
	main.set_time_of_day(0.95)
	await _frames(2)
	var high_sum := _sum(main.get_lamp_levels())
	_check(mid_sum > low_sum and high_sum > mid_sum, "lamp levels rise over time")
	_check(main.get_lit_lamp_count() == 6, "all lamps at late night")
	var levels_before: Array = main.get_lamp_levels()
	main.set_param("lamps", false)
	await _frames(2)
	_check(main.get_lit_lamp_count() == 0, "lamps toggled off")
	_check(_sum(main.get_lamp_levels()) < 0.001, "lamp energies zero when off")
	main.set_param("lamps", true)
	await _frames(2)
	_check(main.get_lit_lamp_count() == 6, "lamps toggled back on")
	var levels_after: Array = main.get_lamp_levels()
	var diff := 0.0
	for i in mini(levels_before.size(), levels_after.size()):
		diff = maxf(diff, absf(float(levels_before[i]) - float(levels_after[i])))
	_check(diff < 0.02, "lamp level restore")

	# 4. 萤火虫：活动度、数量、位置、开关
	main.set_time_of_day(0.0)
	await _frames(4)
	_check(main.world.fireflies.get_activity() < 0.01, "fireflies inactive at dusk")
	main.set_time_of_day(0.95)
	await _frames(4)
	_check(main.world.fireflies.get_activity() > 0.9, "fireflies active at night")
	_check(main.world.fireflies.count >= 60, "firefly count")
	_check(main.get_firefly_visible_count() > 20, "fireflies visible at night")
	var positions: Array = main.world.fireflies.get_positions()
	var finite := true
	var y_ok := true
	var in_bounds := true
	for p in positions:
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
			finite = false
		if p.y < 0.0:
			y_ok = false
		if absf(p.x) > 20.0 or absf(p.z) > 20.0:
			in_bounds = false
	_check(finite, "firefly positions finite")
	_check(y_ok, "fireflies above ground")
	_check(in_bounds, "fireflies in bounds")
	main.set_param("fireflies", false)
	await _frames(3)
	_check(main.world.fireflies.get_activity() < 0.001, "fireflies toggled off")
	_check(main.get_firefly_visible_count() == 0, "firefly visible zero when off")
	main.set_param("fireflies", true)
	await _frames(3)
	_check(main.world.fireflies.get_activity() > 0.9, "fireflies toggled back on")

	# 5. 角色移动 / 朝向 / 点击寻路
	var keeper = main.world.keeper
	keeper.teleport(Vector3(0.5, 0.15, 4.0), 0.0)
	await _frames(6)
	var start_pos: Vector3 = keeper.global_position
	main.set_test_move(Vector3(1, 0, 0), false)
	await _physics_frames(45)
	main.clear_test_move()
	await _frames(3)
	var moved_pos: Vector3 = keeper.global_position
	_check(moved_pos.x - start_pos.x > 0.4, "WASD-driven movement moves character")
	_check(_is_finite_vec(moved_pos), "character position finite")
	var start2: Vector3 = keeper.global_position
	keeper.walk_to(start2 + Vector3(-1.8, 0, 0))
	await _physics_frames(60)
	var walked: Vector3 = keeper.global_position
	_check(walked.x < start2.x - 0.3, "click-to-move target follows")
	keeper.clear_move_target()
	_check(keeper.get_speed() < 4.2, "walk speed within bounds")

	# 6. 相机跟随 / 旋转 / 覆盖
	main.reset_camera()
	await _frames(5)
	var cam_after_reset: Vector3 = main.get_camera_position()
	var char_pos: Vector3 = keeper.global_position
	_check(cam_after_reset.distance_to(char_pos) > 6.0, "camera follows at orbit distance")
	_check(cam_after_reset.y > char_pos.y + 2.0, "camera above character")
	main.set_camera_override(Vector3(0, 1.2, 0), 180.0, 15.0, 9.0)
	await _frames(5)
	var ov: Vector3 = main.get_camera_position()
	_check(absf(ov.z + 7.8) < 1.5, "camera override rotates south")
	_check(ov.y > 1.5, "camera override above")
	main.clear_camera_override()
	main.reset_camera()
	await _frames(3)

	# 7. 暂停冻结时间；自动播放推进
	main.set_param("paused", false)
	main.set_param("auto", true)
	main.set_time_of_day(0.10)
	var t0: float = main.time_of_day
	await _frames(30)
	var t1: float = main.time_of_day
	_check(t1 > t0, "auto time advances")
	main.set_param("paused", true)
	var tp0: float = main.time_of_day
	await _frames(20)
	var tp1: float = main.time_of_day
	_check(absf(tp1 - tp0) < 0.0001, "pause freezes time")
	main.set_param("paused", false)
	main.set_param("auto", false)

	# 8. 水面灯光 uniform / 天空参数
	var lamp_pos = main.world.water_mat.get_shader_parameter("lamp_pos")
	var lamp_energy = main.world.water_mat.get_shader_parameter("lamp_energy")
	_check(lamp_pos != null and lamp_pos.size() == 3, "water lamp positions 3")
	_check(lamp_energy != null and lamp_energy.size() == 3, "water lamp energy 3")
	_check(int(main.world.water_mat.get_shader_parameter("lamp_count")) == 3, "water lamp count 3")
	var sun_dir = main.world.sky_mat.get_shader_parameter("sun_dir")
	var moon_dir = main.world.sky_mat.get_shader_parameter("moon_dir")
	_check(sun_dir is Vector3 and moon_dir is Vector3, "sky sun/moon directions")
	_check(main.world.shaft_mats.size() == 3, "three light shafts")
	var kp = main.world.keeper
	_check(kp != null and kp.get_lantern_position().y > 0.5, "keeper lantern present")

	# 9. HUD 参数
	var p: Dictionary = main.get_params()
	_check(p.has("clock") and p.has("lit") and p.has("firefly_visible"), "params keys")
	_check(p.has("internal_label") and p.has("draw_calls"), "params stats keys")
	_check(p["lamp_count"] == 6, "params lamp count")
	_check(main.hud != null and main.hud.is_ui_visible(), "HUD visible")
	main.set_ui_visible(false)
	_check(not main.hud.is_ui_visible(), "HUD hide")
	main.set_ui_visible(true)
	_check(main.hud.is_ui_visible(), "HUD show")

	# 10. 时间预设
	main.apply_preset(2)
	await _frames(2)
	_check(main.time_of_day > 0.85, "night preset")
	_check(not main.auto_time, "preset pauses auto time")
	main.apply_preset(0)
	await _frames(2)
	_check(main.time_of_day < 0.3, "dusk preset")

	# 11. 无 NaN / 非法关键状态
	_check(_is_finite_vec(main.get_camera_position()), "camera finite")
	_check(_is_finite_vec(main.get_character_position()), "character finite")
	_check(not main.world.lamps.is_empty(), "lamps built")
	_check(main.world.fireflies.count == 160, "firefly default count 160")

	_finish()


func _sum(arr) -> float:
	var s := 0.0
	for v in arr:
		s += float(v)
	return s


func _is_finite_vec(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics_frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("PASS ", label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failed = true
	print("FAIL ", label)


func _finish() -> void:
	print("CHECKS ", _checks)
	if _failed:
		print("DUSK_GARDEN_SMOKE_FAIL")
		quit(1)
	else:
		print("DUSK_GARDEN_SMOKE_OK")
		quit(0)
