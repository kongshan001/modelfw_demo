extends SceneTree

## Headless 冒烟：移动 / 跳跃 / 3 连斩命中 / 闪避 i-frames / 敌人 AI 巡逻·索敌·追击 /
## 前摇出招 / 远程孢弹 / 受击死亡 / 拾取 / 目标计数 / 传送门胜负 / 重开 / 暂停 / 调试。
##   godot --headless --path . -s tools/smoke_sproutbound.gd
## 末行 SPROUTBOUND_SMOKE_OK。

var scene
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func wait_until(pred: Callable, timeout: float, step: float = 0.05) -> bool:
	var t := 0.0
	while t < timeout:
		if pred.call():
			return true
		await create_timer(step).timeout
		t += step
	return bool(pred.call())


func _run() -> void:
	print("SPROUTBOUND_SMOKE start")
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# 1. 启动 / 标题
	check(scene.world != null, "world built")
	check(scene.player != null and scene.player.model != null, "player model built")
	check(scene.camera != null and scene.camera.current, "camera active")
	check(scene.hud != null and scene.hud.font != null, "HUD + CJK font")
	check(scene.game_state == "title", "boots into title")
	check(scene.enemies.is_empty(), "title has no enemies")
	check(not scene.portal_active, "portal asleep at title")

	# 2. 开始
	scene.start_game()
	await wait(0.25)
	check(scene.game_state == "playing", "title -> playing")
	check(scene.player.active and scene.player.controls_enabled, "player active")
	check(scene.enemies.size() == 10, "10 enemies spawned (%d)" % scene.enemies.size())
	check(scene.total_enemies == 10, "total enemies 10")
	check(scene.pickups.size() == 11, "11 pickups (8 seeds + 3 hearts)")
	check(scene.player.hp == SproutPlayer.MAX_HP, "player full HP")
	check(scene.player.is_on_floor(), "player grounded")
	await wait(0.3)
	check(scene.player.state in ["idle", "move"], "idle on ground (%s)" % scene.player.state)

	# 冻结所有敌人，避免干扰运动测试
	scene.set_controls_enabled(false)
	for e in scene.enemies:
		e.active = false
		e.velocity = Vector3.ZERO
	scene.demo_teleport(Vector3(0.0, scene.world.ground_y(0.0, 3.0) + 0.06, 3.0), PI)
	await wait(0.2)

	# 3. 移动
	var p0: Vector3 = scene.player.global_position
	scene.demo_move(Vector3(0.0, 0.0, 1.0))
	await wait(0.55)
	scene.demo_stop()
	var moved := Vector2(scene.player.global_position.x - p0.x,
		scene.player.global_position.z - p0.z).length()
	check(moved > 0.6, "Move: demo input moves player (%.2fm)" % moved)
	check(scene.player.state in ["move", "sprint", "idle"], "Move: locomotion state=%s" % scene.player.state)
	await wait(0.6)
	check(scene.player.state in ["idle", "air"], "Idle: stops back (%s)" % scene.player.state)

	# 4. 跳跃
	scene.set_controls_enabled(true)
	var y_before: float = scene.player.global_position.y
	var jumped: bool = scene.player.try_jump()
	await wait(0.25)
	check(jumped, "Jump: accepted")
	check(scene.player.global_position.y > y_before + 0.3,
		"Jump: airborne (dy=%.2f)" % (scene.player.global_position.y - y_before))
	await wait(1.0)
	check(scene.player.is_on_floor(), "Jump: lands back on ground")

	# 5. 闪避 i-frames
	await wait(0.2)
	scene.set_controls_enabled(true)
	scene.player.dodge_cd = 0.0
	var dodged: bool = scene.player.try_dodge()
	check(dodged and scene.player.state == "dodge", "Dodge: accepted")
	check(scene.player.is_invulnerable(), "Dodge: i-frames active")
	await wait(0.55)
	check(scene.player.state != "dodge", "Dodge: ends")
	check(not scene.player.is_invulnerable(), "Dodge: i-frames expired")

	# 6. 攻击命中 / 连段 / 敌人受击
	var target = scene.enemies[0]
	target.visible = true
	target.global_position = scene.player.global_position + Vector3(0.0, 0.0, 1.5)
	target.hp = target.max_hp
	target.active = false
	scene.player._facing_yaw = PI
	scene.player.rotation.y = PI
	await process_frame
	var hp_before: int = target.hp
	scene.demo_attack(0)
	check(scene.player.state == "attack", "Attack: state entered")
	await wait(0.22)
	check(target.hp < hp_before, "Attack: registers damage (%d -> %d)" % [hp_before, target.hp])
	check(scene.combo >= 1, "Combo: hit increments (%d)" % scene.combo)
	check(target.state in ["hurt", "chase", "windup", "strike"], "Enemy: hurt/aggro state=%s" % target.state)
	var step1: int = scene.player.combo_step
	scene.demo_attack(1)
	await wait(0.25)
	check(scene.player.combo_step >= 1 and scene.player.attack_count >= 2,
		"Attack: chain step 2 (step=%d count=%d)" % [scene.player.combo_step, scene.player.attack_count])
	await wait(0.6)

	# 7. 敌人 AI：巡逻/索敌/追击/前摇/出招
	var ai = scene.enemies[1]
	ai.visible = true
	ai.active = true
	ai.hp = ai.max_hp
	ai.global_position = Vector3(6.0, scene.world.ground_y(6.0, 14.0) + 0.05, 14.0)
	scene.demo_teleport(Vector3(6.0, scene.world.ground_y(6.0, 22.0) + 0.06, 22.0), PI)
	scene.player.invuln_t = 0.0
	scene.player.hp = SproutPlayer.MAX_HP
	await wait(0.5)
	var far_state: String = ai.state
	check(far_state in ["idle", "patrol"], "AI: far player idle/patrol (%s)" % far_state)
	scene.demo_teleport(Vector3(6.0, scene.world.ground_y(6.0, 16.6) + 0.06, 16.6), PI)
	await wait(0.15)
	var detected: bool = await wait_until(func(): return ai.state in ["alert", "chase", "windup"], 2.0)
	check(detected, "AI: detects nearby player (%s)" % ai.state)
	# 直接推进到前摇，把玩家放到攻击范围内，验证出招会扣血
	scene.demo_teleport(ai.global_position + Vector3(0.0, 0.06, 1.15), 0.0)
	ai.aim_at(scene.player.global_position)
	ai.demo_set_state("windup")
	ai.active = true
	scene.player.invuln_t = 0.0
	var php: int = scene.player.hp
	var struck: bool = await wait_until(func(): return scene.player.hp < php, 2.5)
	check(struck, "AI: windup -> strike damages player (hp=%d, state=%s)" % [scene.player.hp, ai.state])
	ai.active = false
	await wait(0.2)

	# 8. 远程孢弹
	var spitter = scene.enemies[4]
	spitter.visible = true
	spitter.active = true
	spitter.hp = spitter.max_hp
	spitter.global_position = Vector3(0.0, scene.world.ground_y(0.0, 9.0) + 0.05, 9.0)
	scene.demo_teleport(Vector3(0.0, scene.world.ground_y(0.0, 15.0) + 0.06, 15.0), PI)
	spitter.aim_at(scene.player.global_position)
	spitter.cooldown = 0.0
	spitter.demo_set_state("windup")
	var saw_bolt := false
	var bolt_wait := 0.0
	while bolt_wait < 2.2:
		await create_timer(0.05).timeout
		bolt_wait += 0.05
		if scene.bolts.size() > 0:
			saw_bolt = true
			break
	check(saw_bolt, "Ranged: spitter spawns spore bolt")
	for b in scene.bolts.duplicate():
		if is_instance_valid(b):
			b.queue_free()
	scene.bolts.clear()
	spitter.active = false
	await wait(0.2)

	# 9. 敌人受击闪白 / 玩家受伤 / 死亡 / 失败
	scene.player.invuln_t = 0.0
	var hp0: int = scene.player.hp
	scene.demo_damage_player(10)
	check(scene.player.hp == hp0 - 10, "Player: damage applied (%d -> %d)" % [hp0, scene.player.hp])
	scene.player.invuln_t = 0.0
	scene.demo_kill_player()
	await wait(1.45)
	check(scene.player.dead and scene.game_state == "defeat", "Defeat: state=%s" % scene.game_state)

	# 10. 重开
	scene.restart_game()
	await wait(0.35)
	check(scene.game_state == "playing", "Restart: playing")
	check(scene.player.hp == SproutPlayer.MAX_HP and not scene.player.dead, "Restart: full HP")
	check(scene.kills == 0 and scene.seeds_collected == 0, "Restart: counters reset")
	check(not scene.portal_active and scene.enemies.size() == 10, "Restart: enemies + portal reset")
	await wait(0.2)

	# 11. 拾取
	var seed_p = scene.pickups[0]
	var seed_node: Node3D = seed_p.node
	var before_seeds: int = scene.seeds_collected
	scene.demo_teleport(seed_node.global_position + Vector3(0.0, 0.06, 0.0), PI)
	await wait(0.2)
	check(scene.seeds_collected > before_seeds, "Pickup: seed collected (%d)" % scene.seeds_collected)
	var heart_p = null
	for p in scene.pickups:
		if String(p.kind) == "heart":
			heart_p = p
			break
	check(heart_p != null, "Pickup: heart exists")
	if heart_p != null:
		scene.player.hp = 50
		scene.demo_teleport(heart_p.node.global_position + Vector3(0.0, 0.06, 0.0), PI)
		await wait(0.2)
		check(scene.player.hp == 75, "Pickup: heart heals +25 (%d)" % scene.player.hp)

	# 12. 击杀计数 / 传送门 / 胜利
	scene.demo_kill_enemy(scene.enemies[0])
	await wait(0.25)
	check(scene.kills == 1, "Goal: kill counted (%d)" % scene.kills)
	scene.demo_kill_all()
	await wait(0.35)
	check(scene.kills == 10, "Goal: all enemies counted (%d)" % scene.kills)
	check(scene.portal_active and scene.world.portal_active, "Goal: portal opens")
	scene.demo_enter_portal()
	var won: bool = await wait_until(func(): return scene.game_state == "victory", 2.5)
	check(won, "Victory: entering portal ends run")
	var stats: Dictionary = scene.get_play_stats()
	check(int(stats.total) == 10 and int(stats.kills) == 10, "Victory: stats consistent")

	# 13. 胜利后重开 / 暂停 / 调试
	scene.restart_game()
	await wait(0.35)
	check(scene.game_state == "playing" and scene.kills == 0, "Restart: after victory")
	scene._pause_game()
	check(scene.game_state == "paused" and not scene.player.active, "Pause: frozen")
	scene._resume_game()
	check(scene.game_state == "playing" and scene.player.active, "Pause: resumed")
	var dbg_before: bool = scene.debug_view
	scene.toggle_debug()
	check(scene.debug_view != dbg_before, "Debug: toggled")
	check(scene.enemies[0].debug_label.visible == scene.debug_view, "Debug: enemy labels follow toggle")
	scene.toggle_debug()
	check(scene.debug_view == dbg_before, "Debug: toggled back")

	# 14. 清理
	for e in scene.enemies:
		if is_instance_valid(e):
			e.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	print("SPROUTBOUND_SMOKE checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty():
		print("SPROUTBOUND_SMOKE_OK")
		quit(0)
	else:
		for f in failures:
			print("FAILED: ", f)
		quit(1)
