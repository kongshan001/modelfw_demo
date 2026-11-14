extends SceneTree

# Headless 冒烟：demo 场景加载、重定向节点、WASD 状态机、位移与角色切换。
# 用法：godot --headless --path godot-mixamo-demo -s tools/smoke_demo.gd

func _initialize() -> void:
	var scene: Node = load("res://scenes/demo.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(1.0).timeout

	var player: Node = scene.get("player")
	if player == null:
		_fail("player missing")
		return
	if String(player.call("get_character_name")) != "Michelle":
		_fail("initial character is not Michelle")
		return
	if String(player.call("get_state")) != "Idle":
		_fail("initial state is not Idle")
		return

	player.call("toggle_dance")
	await create_timer(0.2).timeout
	if String(player.call("get_state")) != "Dance":
		_fail("dance did not start")
		return
	player.call("toggle_dance")
	await create_timer(0.1).timeout
	if String(player.call("get_state")) != "Idle":
		_fail("dance did not stop")
		return

	player.call("set_demo_input", Vector2(1.0, 0.0), false)
	await create_timer(0.5).timeout
	if String(player.call("get_state")) != "Walk":
		_fail("state did not become Walk")
		return

	var start_pos: Vector3 = player.position
	await create_timer(0.3).timeout
	if player.position.is_equal_approx(start_pos):
		_fail("player did not move")
		return

	player.call("cycle_character")
	await create_timer(0.1).timeout
	if String(player.call("get_character_name")) != "Soldier":
		_fail("switch to Soldier failed")
		return
	player.call("set_demo_input", Vector2.ZERO, false)
	await create_timer(0.1).timeout
	player.call("toggle_dance")
	await create_timer(0.2).timeout
	if String(player.call("get_state")) != "Dance":
		_fail("Soldier dance did not start")
		return
	player.call("toggle_dance")
	await create_timer(0.1).timeout
	if String(player.call("get_state")) != "Idle":
		_fail("Soldier dance did not stop")
		return

	player.call("cycle_character")
	await create_timer(0.1).timeout
	if String(player.call("get_character_name")) != "Xbot":
		_fail("switch to Xbot failed")
		return
	player.call("set_demo_input", Vector2.ZERO, false)
	await create_timer(0.1).timeout
	player.call("toggle_dance")
	await create_timer(0.2).timeout
	if String(player.call("get_state")) != "Dance":
		_fail("Xbot dance did not start")
		return
	player.call("toggle_dance")
	await create_timer(0.1).timeout
	if String(player.call("get_state")) != "Idle":
		_fail("Xbot dance did not stop")
		return

	player.call("set_demo_input", Vector2(0.0, -1.0), true)
	await create_timer(0.4).timeout
	if String(player.call("get_state")) != "Run":
		_fail("state did not become Run")
		return

	print("DEMO_SMOKE_OK")
	scene.queue_free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	printerr("DEMO_SMOKE_FAIL: " + message)
	quit(1)
