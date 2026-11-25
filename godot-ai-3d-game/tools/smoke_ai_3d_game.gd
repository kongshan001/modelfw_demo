extends SceneTree

# 无头验收：资产加载、起跑线、移动/转向/边界、AI、加速带、暂停、胜/负、重开、HUD。
# 全部走真实游戏方法；截图/渲染不参与判定。
# Run: godot --headless --path godot-ai-3d-game -s tools/smoke_ai_3d_game.gd

var _fails: Array[String] = []
var _checks := 0
var _done := false


func _initialize() -> void:
	var watchdog := create_timer(90.0)
	watchdog.timeout.connect(func() -> void:
		if not _done:
			printerr("AI_3D_GAME_SMOKE_TIMEOUT")
			quit(1))
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await create_timer(0.25).timeout

	var world := scene as RaceWorld
	var hud: RaceHud = scene.get_node("HUD")
	_check(world != null, "main scene should expose RaceWorld")
	_check(hud != null, "HUD should exist")
	if world == null or hud == null:
		_finish()
		return

	# ── 资产与场景 ──
	_check(ResourceLoader.exists(KartVisual.FOX_PATH), "CC0 Fox.glb should exist")
	var fox_pack := load(KartVisual.FOX_PATH) as PackedScene
	_check(fox_pack != null, "Fox.glb should load as PackedScene")
	var fox_driver := world.player.visual.get_node_or_null("Body/FoxDriver")
	_check(fox_driver != null, "player kart should mount FoxDriver")
	if fox_driver != null:
		_check(fox_driver.find_child("AnimationPlayer", true, false) != null, "FoxDriver should have an AnimationPlayer")
	# ── Tripo 资产：车体/风车加载、程序化回退节点、车轮与叶片保留 ──
	_check(ResourceLoader.exists(KartVisual.TRIPO_CAR_PATH), "Tripo car.glb should exist")
	var tripo_car_pack := load(KartVisual.TRIPO_CAR_PATH) as PackedScene
	_check(tripo_car_pack != null, "car.glb should load as PackedScene")
	var tripo_body := world.player.visual.get_node_or_null("Body/TripoCarBody") as Node3D
	_check(tripo_body != null, "player kart should mount TripoCarBody")
	if tripo_body != null:
		# 在 Body 空间量尺寸，排除起跑格 yaw/lean 对世界 AABB 的放大。
		var body_root := world.player.visual.get_node_or_null("Body") as Node3D
		var kart_box := _combined_aabb(tripo_body, body_root)
		_check(kart_box.size.x > 1.4 and kart_box.size.x < 2.4, "Tripo car width should be 1.4–2.4m, got %.2f" % kart_box.size.x)
		_check(kart_box.size.z > 2.8 and kart_box.size.z < 3.8, "Tripo car length should be 2.8–3.8m, got %.2f" % kart_box.size.z)
		var car_tris := 0
		var car_shader := false
		var car_stack: Array[Node] = [tripo_body]
		while not car_stack.is_empty():
			var car_node: Node = car_stack.pop_back()
			for child in car_node.get_children():
				car_stack.append(child)
			if car_node is MeshInstance3D:
				var car_mi := car_node as MeshInstance3D
				if car_mi.mesh != null:
					car_tris += int(car_mi.mesh.get_faces().size() / 3)
				if car_mi.material_override is ShaderMaterial:
					car_shader = true
				for s in car_mi.mesh.get_surface_count():
					if car_mi.get_surface_override_material(s) is ShaderMaterial:
						car_shader = true
		_check(car_tris > 10000 and car_tris < 35000, "Tripo car should be decimated to 10k–35k tris, got %d" % car_tris)
		_check(car_shader, "Tripo car should use the PBR team tint shader")
	var procedural_kart := world.player.visual.get_node_or_null("Body/ProceduralBody") as Node3D
	_check(procedural_kart != null and not procedural_kart.visible, "procedural kart body should be hidden when Tripo body is active")
	var wheel_root := world.player.visual.get_node_or_null("Wheels")
	_check(wheel_root != null and wheel_root.get_child_count() == 4, "4 procedural wheels should remain for spin/steer")
	_check(ResourceLoader.exists(RaceWorld.TRIPO_WINDMILL_PATH), "Tripo windmill.glb should exist")
	var tripo_windmill_pack := load(RaceWorld.TRIPO_WINDMILL_PATH) as PackedScene
	_check(tripo_windmill_pack != null, "windmill.glb should load as PackedScene")
	var tripo_windmill := world.get_node_or_null("Windmill/TripoWindmill") as Node3D
	_check(tripo_windmill != null, "windmill should mount TripoWindmill")
	if tripo_windmill != null:
		var mill_root := world.get_node_or_null("Windmill") as Node3D
		var mill_box := _combined_aabb(tripo_windmill, mill_root)
		_check(mill_box.size.y > 9.0 and mill_box.size.y < 12.0, "Tripo windmill height should be 9–12m, got %.2f" % mill_box.size.y)
	var procedural_mill := world.get_node_or_null("Windmill/ProceduralBody") as Node3D
	_check(procedural_mill != null and not procedural_mill.visible, "procedural windmill body should be hidden when Tripo body is active")
	_check(world.get_node_or_null("Windmill/Rotor") != null, "procedural windmill rotor should remain for animation")
	_check(world.racers.size() == 3, "there should be 1 player + 2 rivals")
	_check(world.rivals.size() == 2, "there should be 2 AI rivals")
	_check(world.boost_pads.size() == 3, "there should be 3 boost pads")
	_check(world.track.length > 250.0, "track length should be >250m, got %.1f" % world.track.length)
	_check(world.race_goal > world.track.length, "race goal should include the grid offset")
	_check(world.player.start_progress > world.track.length - 7.0, "grid should start behind the finish line")
	_check(world.state == RaceWorld.RaceState.COUNTDOWN, "race should begin in countdown")
	_check(hud.finish_layer.visible == false, "finish overlay should start hidden")
	_check(hud.pause_layer.visible == false, "pause overlay should start hidden")
	_check(hud.lap_value.text.contains("1"), "lap HUD should show 1/1")
	_check(hud.objective_label.visible == false, "objective hint should be hidden during countdown")
	print("ASSET_AND_START checks=%d track=%.1f goal=%.1f" % [_checks, world.track.length, world.race_goal])

	# ── 倒计时 → 发车 ──
	world.countdown_left = 0.04
	await create_timer(0.18).timeout
	_check(world.state == RaceWorld.RaceState.RACING, "countdown should transition to racing")
	_check(world.player.active, "player should be active after GO")
	_check(world.rivals[0].active and world.rivals[1].active, "AI should be active after GO")
	_check(world.go_flash > 0.0, "GO flash timer should start")
	await create_timer(0.15).timeout
	_check(hud.objective_label.visible == true, "objective hint should appear while racing")

	# ── 移动 / 转向 ──
	var start_pos := world.player.global_position
	var start_yaw := world.player.yaw
	Input.action_press("accelerate")
	await create_timer(0.8).timeout
	_check(world.player.speed > 4.0, "accelerate should build speed, got %.2f" % world.player.speed)
	_check(world.player.global_position.distance_to(start_pos) > 1.5, "player should move forward")
	_check(world.player.race_distance > 1.0, "race distance should increase")
	Input.action_press("steer_right")
	await create_timer(0.35).timeout
	Input.action_release("steer_right")
	_check(absf(wrapf(world.player.yaw - start_yaw, -PI, PI)) > 0.05, "steering should change yaw")
	Input.action_release("accelerate")
	await create_timer(0.1).timeout
	_check(world.player.speed_kmh() > 0.0, "speedometer should report km/h")
	var rival_moved := world.rivals[0].race_distance > 1.0 and world.rivals[1].race_distance > 1.0
	_check(rival_moved, "both AI karts should move after GO")
	print("PLAYER_MOVE checks=%d speed=%.2f distance=%.2f rivalA=%.2f rivalB=%.2f" % [
		_checks, world.player.speed, world.player.race_distance,
		world.rivals[0].race_distance, world.rivals[1].race_distance])

	# ── 赛道边界：强制放到路外，单步后应被夹回护栏内 ──
	var off_progress := world.track.length * 0.30
	var probe_pos: Vector3 = world.track.point_at(off_progress) + world.track.right_at(off_progress) * 20.0
	world.player.global_position = probe_pos
	world.player.yaw = 0.0
	world.player.speed = 12.0
	world.player.active = true
	world.player.step_player(1.0 / 60.0)
	var lateral := absf(float(world.track.nearest(world.player.global_position)["lateral"]))
	_check(lateral <= RaceKart.WALL_LIMIT + 0.05, "player should be clamped inside barriers, lateral=%.2f" % lateral)
	print("WALL_CLAMP checks=%d lateral=%.2f" % [_checks, lateral])

	# ── 加速带：真实进入触发区 ──
	var pad: Dictionary = world.boost_pads[0]
	var pad_center: Vector3 = pad["center"]
	var pad_progress: float = pad["progress"]
	world.player.global_position = pad_center
	world.player.yaw = atan2(-world.track.tangent_at(pad_progress).x, -world.track.tangent_at(pad_progress).z)
	world.player.speed = 12.0
	world.player.boost_timer = 0.0
	world.player.boost_count = 0
	pad["cooldown"] = 0.0
	await create_timer(0.12).timeout
	_check(world.player.boost_count >= 1, "boost pad should increment boost count")
	_check(world.player.boost_timer > 0.0, "boost pad should set boost timer")
	_check(float(pad["cooldown"]) > 0.0, "boost pad should enter cooldown")
	_check(hud.boost_label != null, "boost HUD label should exist")
	print("BOOST_PAD checks=%d count=%d timer=%.2f cooldown=%.2f" % [
		_checks, world.player.boost_count, world.player.boost_timer, float(pad["cooldown"])])

	# ── 暂停：计时冻结、遮罩出现、恢复后继续 ──
	world.toggle_pause()
	await process_frame
	await process_frame
	_check(world.state == RaceWorld.RaceState.PAUSED, "toggle_pause should pause")
	_check(hud.pause_layer.visible, "pause overlay should appear")
	var paused_elapsed := world.elapsed
	await create_timer(0.25).timeout
	_check(is_equal_approx(world.elapsed, paused_elapsed), "elapsed time should freeze while paused")
	world.resume_game()
	await process_frame
	await process_frame
	_check(world.state == RaceWorld.RaceState.RACING, "resume should return to racing")
	_check(not hud.pause_layer.visible, "pause overlay should hide after resume")
	print("PAUSE checks=%d" % _checks)

	# ── 胜利：冲到终点，且两名 AI 在身后 ──
	world.player.boost_timer = 0.0
	world.debug_place_player_at_distance(world.race_goal - 2.0, 24.0)
	world.debug_set_rival_distance(0, world.race_goal - 30.0)
	world.debug_set_rival_distance(1, world.race_goal - 45.0)
	var waited := 0.0
	while world.state != RaceWorld.RaceState.FINISHED and waited < 3.0:
		await create_timer(0.05).timeout
		waited += 0.05
	await process_frame
	await process_frame
	_check(world.state == RaceWorld.RaceState.FINISHED, "crossing the finish should finish the race")
	_check(world.finish_place == 1, "winning run should place 1st, got %d" % world.finish_place)
	_check(world.finish_won, "place 1 should be a win")
	_check(hud.finish_layer.visible, "finish overlay should appear")
	_check(hud.finish_title.text.contains("冠军"), "win title should mention champion")
	_check(hud.finish_time_value.text.length() >= 5, "finish time should be formatted")
	print("WIN checks=%d place=%d time=%.2f overlay=%s" % [
		_checks, world.finish_place, world.finish_time, str(hud.finish_layer.visible)])

	# ── 重开 ──
	scene.restart_race()
	await create_timer(0.8).timeout
	var scene2 := current_scene
	_check(scene2 != null and scene2 != scene, "restart should load a fresh scene")
	if scene2 == null:
		_finish()
		return
	var world2 := scene2 as RaceWorld
	var hud2: RaceHud = scene2.get_node("HUD")
	_check(world2.state == RaceWorld.RaceState.COUNTDOWN, "restart should reset to countdown")
	_check(world2.player.race_distance == 0.0, "restart should reset race distance")
	_check(not hud2.finish_layer.visible, "restart should hide finish overlay")
	print("RESTART checks=%d" % _checks)

	# ── 失败：两名 AI 先到终点，玩家再冲线只能是第 3 ──
	world2.debug_start_now()
	world2.debug_place_player_at_distance(world2.race_goal - 2.0, 22.0)
	world2.debug_set_rival_distance(0, world2.race_goal + 1.0)
	world2.debug_set_rival_distance(1, world2.race_goal + 1.0)
	waited = 0.0
	while world2.state != RaceWorld.RaceState.FINISHED and waited < 3.0:
		await create_timer(0.05).timeout
		waited += 0.05
	await process_frame
	await process_frame
	_check(world2.state == RaceWorld.RaceState.FINISHED, "losing run should finish")
	_check(world2.finish_place == 3, "two AI ahead should leave the player 3rd, got %d" % world2.finish_place)
	_check(not world2.finish_won, "place 3 should be a loss")
	_check(hud2.finish_layer.visible, "loss should still show the finish overlay")
	_check(hud2.finish_title.text.contains("第 3 名"), "loss title should mention 3rd place")
	print("LOSE checks=%d place=%d" % [_checks, world2.finish_place])

	Input.action_release("accelerate")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	_finish()


func _finish() -> void:
	_done = true
	if _fails.is_empty():
		print("AI_3D_GAME_SMOKE_OK checks=%d" % _checks)
	else:
		for failure in _fails:
			printerr("AI_3D_GAME_SMOKE_FAIL: ", failure)
		print("AI_3D_GAME_SMOKE_FAILED checks=%d" % _checks)
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	quit(0 if _fails.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fails.append(message)


func _combined_aabb(root: Node3D, space: Node3D = null) -> AABB:
	var box := AABB()
	var first := true
	var inv := Transform3D.IDENTITY
	if space != null:
		inv = space.global_transform.affine_inverse()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			var part := (inv * mi.global_transform) * mi.get_aabb()
			if first:
				box = part
				first = false
			else:
				box = box.merge(part)
	return box
