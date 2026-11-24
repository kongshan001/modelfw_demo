extends SceneTree

# 整圈可复现验收：使用 RaceKart.auto_drive（正常的 Input 路径仍是默认），
# 在真实物理/赛道/加速带/AI 下跑完 1 圈，输出完赛时间、名次与冲刺次数。
# 运行：godot --headless --path godot-ai-3d-game -s tools/playtest_autopilot.gd

func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var world := scene as RaceWorld
	world.debug_start_now()
	world.player.auto_drive = true

	var start_us := Time.get_ticks_usec()
	var watchdog_us := start_us + 60_000_000
	while world.state != RaceWorld.RaceState.FINISHED and Time.get_ticks_usec() < watchdog_us:
		await process_frame
	var elapsed_wall := float(Time.get_ticks_usec() - start_us) / 1_000_000.0
	Input.action_release("accelerate")
	print("AUTOPILOT_RESULT state=%d place=%d race_time=%.2f wall=%.2f boosts=%d player_distance=%.1f rivalA=%.1f rivalB=%.1f" % [
		world.state,
		world.finish_place,
		world.finish_time,
		elapsed_wall,
		world.player.boost_count,
		world.player.race_distance,
		world.rivals[0].race_distance,
		world.rivals[1].race_distance,
	])
	if world.state == RaceWorld.RaceState.FINISHED and world.finish_place == 1:
		print("AUTOPILOT_PLAYTEST_OK")
		quit(0)
	else:
		printerr("AUTOPILOT_PLAYTEST_FAIL")
		quit(1)
