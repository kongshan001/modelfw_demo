extends SceneTree
## 真实窗口输入探针：按钮、卡片、右键移动、框选、暂停/倍速、滚轮、重开。
## 用法：godot --path godot-island-defense --resolution 1280x720 -s tools/probe_input_island_defense.gd

var game
var checks := 0
var failures: Array[String] = []
var ui_xform := Transform2D.IDENTITY


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for _i in range(8):
		await process_frame
	game = main
	ui_xform = root.get_final_transform()
	game.demo_mode = false
	game.auto_simulate = true
	await process_frame
	_check(game.state == "intro", "启动进入开场页")
	await _click(_native(Vector2(204, 543)))
	_check(game.state == "playing", "点击「开始布防」进入战斗")
	game.hold_waves = true
	game.prep_timer = 999.0
	await _frames(3)

	await _click(_native(Vector2(140, 650)))
	_check(game.selected_squads.size() == 1 and game.selected_squads[0] == game.squads[0], "点击队伍卡选中盾卫队")
	var moving_before: Vector3 = game.squads[0].center
	await _click(_native(Vector2(640, 360)), MOUSE_BUTTON_RIGHT)
	await _frames(12)
	var path_ok: bool = game.squads[0].path.size() >= 2 or game.squads[0].moving
	_check(path_ok, "右键下达移动指令")
	await _key(KEY_2)
	_check(game.selected_squads.size() == 1 and game.selected_squads[0] == game.squads[1], "数字 2 选中弓手队")
	await _key(KEY_SPACE)
	_check(game.paused, "Space 暂停")
	var t0: float = game.sim_time
	await _frames(10)
	_check(is_equal_approx(game.sim_time, t0), "暂停时模拟冻结")
	await _key(KEY_SPACE)
	_check(not game.paused, "Space 继续")
	await _key(KEY_T)
	_check(game.speed_mult() == 2.0, "T 切 2×")
	await _key(KEY_T)
	_check(game.speed_mult() == 1.0, "T 切回 1×")
	await _click(_native(Vector2(1089, 31)))
	_check(game.paused, "点击顶部「暂停」")
	await _click(_native(Vector2(556, 417)))
	_check(not game.paused, "点击暂停面板「继续」")
	await _click(_native(Vector2(104, 31)), MOUSE_BUTTON_WHEEL_UP)
	_check(game.camera_rig.target_size < 44.0, "滚轮缩放相机")
	await _frames(3)

	# 框选：拉远镜头后从空白处圈住中部三队
	game.debug_focus_camera(Vector3(0, 0, 0), 52.0, -38.0, 50.0)
	await _frames(3)
	await _click(_native(Vector2(490, 380)))
	await _frames(2)
	await _drag(_native(Vector2(520, 240)), _native(Vector2(900, 500)))
	await _frames(4)
	_check(game.selected_squads.size() == 3, "框选三支小队（%d）" % game.selected_squads.size())
	await _key(KEY_R)
	await _frames(5)
	_check(game.state == "playing" and game.houses_alive() == 3 and game.squads.size() == 3, "R 重开并恢复三队 / 三屋")

	print("checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty():
		print("ISLAND_DEFENSE_INPUT_OK")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL " + failure)
		quit(1)


func _native(pos: Vector2) -> Vector2:
	return ui_xform * pos


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS  " + message)
	else:
		failures.append(message)
		printerr("FAIL  " + message)


func _mouse_motion(pos: Vector2, mask := 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	motion.button_mask = mask
	Input.parse_input_event(motion)
	Input.flush_buffered_events()


func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	_mouse_motion(pos)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await _frames(3)


func _drag(from: Vector2, to: Vector2) -> void:
	_mouse_motion(from)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = from
	down.global_position = from
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	for i in range(1, 6):
		_mouse_motion(from.lerp(to, float(i) / 5.0), MOUSE_BUTTON_MASK_LEFT)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	up.global_position = to
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await _frames(20)


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await _frames(3)
