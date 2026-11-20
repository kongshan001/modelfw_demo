extends SceneTree

# 真实输入接线测试：需要窗口/键盘焦点。
# 覆盖 空格蓄力/释放、左键抛钩、B 菜单、按钮点击、甲板放置。
# Run: godot --path . --resolution 1280x720 -s tools/input_raft.gd

var _fails: Array[String] = []
var _checks := 0
var _scene: Node
var _world: RaftWorld
var _hud: RaftHud


func _initialize() -> void:
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	await process_frame
	await create_timer(0.4).timeout
	_world = _scene.get_node("ViewportContainer/WorldViewport/World")
	_hud = _scene.get_node("HUD")
	_world.spawn_enabled = false
	_world.clear_loot()
	_world.debug_spawn_loot("barrel", Vector3(5.0, 0.0, 0.0))
	Input.warp_mouse(Vector2(640, 420))
	await process_frame

	# 空格：按住蓄力，松开抛钩
	_key(KEY_SPACE, true)
	await process_frame
	await create_timer(0.16).timeout
	_check(_world.hook_state == "charging", "Space hold should charge the hook")
	_key(KEY_SPACE, false)
	await process_frame
	_check(_world.hook_state == "flying", "Space release should cast the hook")

	# 等待回到 idle，补一个新目标，再用左键重复一次
	await _wait_idle()
	_world.clear_loot()
	_world.debug_spawn_loot("barrel", Vector3(-5.0, 0.0, 0.0))
	Input.warp_mouse(Vector2(640, 420))
	await process_frame
	_mouse_down(Vector2(640, 420))
	await process_frame
	_check(_world.hook_state == "charging", "left click should charge the hook")
	_mouse_release(Vector2(640, 420))
	await process_frame
	_check(_world.hook_state == "flying", "left release should cast the hook")
	await _wait_idle()

	# B 打开建造菜单；点击扩建按钮
	_key(KEY_B, true)
	await process_frame
	await create_timer(0.1).timeout
	_check(_hud.is_build_open(), "B should open the build menu")
	var btn: Button = _hud.build_menu.get_node("Build_expand")
	var center := btn.get_global_rect().get_center()
	Input.warp_mouse(center)
	await process_frame
	_mouse_down(center)
	await process_frame
	_mouse_release(center)
	await process_frame
	await create_timer(0.15).timeout
	_check(not _hud.is_build_open(), "build button click should close the menu")
	_check(_world.placement_mode and _world.placement_type == "expand",
		"build button should enter expand placement")

	# 点甲板放置
	var target := Vector2i(2, 0)
	var screen := _world.world_to_viewport(_world.cell_center(target)) * 2.0
	Input.warp_mouse(screen)
	await process_frame
	_mouse_down(screen)
	await process_frame
	_mouse_release(screen)
	await process_frame
	await create_timer(0.2).timeout
	_check(_world.raft.has(target), "world click should place the previewed raft tile")
	_check(_world.raft.size() == 5, "placement should grow raft to 5 tiles")

	if _fails.is_empty():
		print("RAFT_INPUT_OK checks=%d" % _checks)
	else:
		for f in _fails:
			printerr("RAFT_INPUT_FAIL: ", f)
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	quit(0 if _fails.is_empty() else 1)


func _wait_idle() -> void:
	for i in 240:
		if _world.hook_state == "idle" and _world.cooldown <= 0.0:
			return
		await process_frame


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _mouse_down(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)


func _mouse_release(pos: Vector2) -> void:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)
