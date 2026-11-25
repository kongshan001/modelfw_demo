extends SceneTree

# 无头验收：弹反窗/判定、闪避 i-frames、精力/忆能、敌人起手/受击/破韧/死亡、
# 检查点死亡复活、窥梦遗物开门、记忆残片、Boss 血条/二阶段、胜负与重开、HUD/输入。
# Run: godot --headless --path godot-dream-parry -s tools/smoke_dream_parry.gd

var world: DreamWorld
var player: DreamPlayer
var normal: DreamEnemy
var boss: DreamEnemy
var hud: DreamHud
var checks := 0
var fails: Array[String] = []
var done := false


func _initialize() -> void:
	var watchdog := create_timer(120.0)
	watchdog.timeout.connect(func() -> void:
		if not done:
			printerr("DREAM_PARRY_SMOKE_TIMEOUT")
			quit(1))
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await create_timer(0.35).timeout
	world = scene as DreamWorld
	_check(world != null, "main scene 应为 DreamWorld")
	if world == null:
		_finish()
		return
	player = world.player
	normal = world.normal_enemy
	boss = world.boss
	hud = world.hud
	_check(player != null and normal != null and boss != null and hud != null, "核心节点齐全")
	if player == null or normal == null or boss == null or hud == null:
		_finish()
		return

	await _test_scene_and_assets()
	await _test_fallbacks()
	await _test_input_and_tokens()
	await _test_parry_and_riposte()
	await _test_dodge_iframes()
	await _test_energy_and_stamina()
	await _test_enemy_death_and_checkpoint()
	await _test_player_death_and_respawn()
	await _test_relic_gate_and_shards()
	await _test_boss_and_victory()
	await _test_restart_and_pause()
	_finish()


func _test_scene_and_assets() -> void:
	print("── SCENE / ASSETS ──")
	_check(world.level != null, "DreamLevel 已构建")
	_check(world.checkpoints.size() == 2, "应有两个残梦灯检查点")
	_check(world.shards.size() == 2, "应有两枚记忆残片")
	_check(world.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "相机应为等轴正交")
	_check(world.camera.current, "等轴相机应启用")
	_check(hud.size.x > 0.0 and hud.size.y > 0.0, "HUD 应铺满视口")
	_check(world.level.bridge_root.visible == false, "隐藏断桥初始不可见")
	_check(world.level.bridge_body.collision_layer == 0, "隐藏断桥初始无碰撞")
	_check(world.level.barrier_body.collision_layer == 1, "幻象墙初始阻挡通路")
	_check(player._uses_model, "Knight.glb CC0 角色应加载成功")
	_check(normal._uses_model, "Rogue_Hooded.glb CC0 敌人应加载成功")
	_check(boss._uses_model, "Mage.glb CC0 Boss 应加载成功")
	_check(player.find_child("Umbrella", true, false) != null, "玩家应持有程序化雨伞")
	_check(player.anim != null and player.anim.has_animation("Block"), "KayKit Block 动画存在")
	_check(normal.anim != null and normal.anim.has_animation("1H_Melee_Attack_Slice_Horizontal"), "敌人攻击动画存在")
	_check(hud.objective_text.contains("记忆") or world.get_objective_text().contains("记忆"), "HUD 目标包含记忆残片")
	_check(world.get_objective_text().contains("遗物") == false, "初始目标先引导探索而非遗物")
	_check(player.PARRY_WINDOW == 0.18, "弹反窗应明确为 0.18s")
	_check(player.DODGE_IFRAMES == 0.26, "闪避 i-frames 应明确为 0.26s")
	_check(world.has_method("request_attack_token") and world.has_method("release_attack_token"), "攻击令牌接口存在")
	_check(world.has_method("use_relic"), "遗物使用接口存在")
	_check(world.room_name == "醒梦庭", "出生房间应为醒梦庭")
	_check(normal.global_position.distance_to(DreamLevel.NORMAL_HOME) < 0.2, "巡游者应在齿轮回廊")
	_check(boss.global_position.distance_to(DreamLevel.BOSS_HOME) < 0.2, "Boss 应在无钟之间")
	print("CHECKPOINTS=%d SHARDS=%d START=%s" % [world.checkpoints.size(), world.shards.size(), world.room_name])


func _test_fallbacks() -> void:
	print("── PROCEDURAL FALLBACK ──")
	OS.set_environment("DREAM_FORCE_PROCEDURAL", "1")
	var p2 := DreamPlayer.new()
	p2.process_mode = Node.PROCESS_MODE_DISABLED
	p2.position = Vector3(60, 0, 60)
	root.add_child(p2)
	await process_frame
	_check(p2.find_child("ProceduralFallback", true, false) != null, "玩家缺图回退模型保留")
	_check(p2.find_child("Umbrella", true, false) != null, "玩家回退模型仍持有雨伞")
	p2.queue_free()
	var e2 := DreamEnemy.new()
	e2.setup(false)
	e2.process_mode = Node.PROCESS_MODE_DISABLED
	e2.position = Vector3(62, 0, 60)
	root.add_child(e2)
	await process_frame
	_check(e2.find_child("ProceduralEnemy", true, false) != null, "敌人缺图回退模型保留")
	e2.queue_free()
	OS.unset_environment("DREAM_FORCE_PROCEDURAL")
	await process_frame


func _test_input_and_tokens() -> void:
	print("── INPUT / ATTACK TOKEN ──")
	for action in ["move_forward", "move_backward", "move_left", "move_right", "attack", "parry", "dodge", "heal", "interact", "lock_on", "restart", "pause"]:
		_check(InputMap.has_action(action), "输入动作存在: " + action)
	var attack_events := InputMap.action_get_events("attack")
	var has_mouse := false
	for ev in attack_events:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			has_mouse = true
	_check(has_mouse, "左键绑定轻击/重击")
	var pause_events := InputMap.action_get_events("pause")
	var has_esc := false
	for ev in pause_events:
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_ESCAPE:
			has_esc = true
	_check(has_esc, "Esc 绑定暂停")
	_check(world.request_attack_token(normal), "普通梦魇可取得攻击令牌")
	_check(not world.request_attack_token(boss), "同一时刻只有持有者可攻击")
	world.release_attack_token(normal)
	_check(world.attack_token == null, "攻击令牌释放")
	_check(world.request_attack_token(boss), "Boss 可取得攻击令牌")
	world.release_attack_token(boss)


func _reset_actors() -> void:
	player.respawn_at(Vector3(0, 0.05, 3.4), 0.0)
	normal.reset_enemy()
	boss.reset_enemy()
	world.attack_token = null
	world.boss_engaged = false


func _test_parry_and_riposte() -> void:
	print("── PARRY / RIPOSTE ──")
	_reset_actors()
	# 站到巡游者正南 2.4m，面向北。
	player.respawn_at(Vector3(0, 0.05, -25.45), PI)
	player.energy = 40.0
	player.face_target(normal)
	await create_timer(0.08).timeout
	_check(normal.is_alive(), "巡游者存活")
	normal.force_attack("sweep")
	await create_timer(0.06).timeout
	_check(normal.state == DreamEnemy.State.WINDUP, "普通梦魇进入起手状态")
	_check(normal._telegraph_root.visible, "起手预警圈可见")
	_check(normal.windup_duration > 0.5, "起手时长可读（>0.5s）")
	await process_frame
	_check(hud.parry_hint_visible, "HUD 显示弹反提示")
	_check(hud.parry_hint_text.contains("弹反"), "提示文本为右键弹反")
	var hp_before := player.hp
	var energy_before := player.energy
	player.start_parry()
	await create_timer(0.07).timeout
	_check(player.is_parry_active(), "弹反窗口内判定有效")
	normal.debug_skip_windup()
	await create_timer(0.10).timeout
	_check(player.hp == hp_before, "完美弹反不受伤")
	_check(normal.state == DreamEnemy.State.STAGGER, "弹反使敌人硬直")
	_check(normal.can_be_riposted(), "弹反开放反击窗口")
	_check(player.energy > energy_before + 10.0, "弹反回复忆能")
	_check(player.parry_success_count >= 1, "记录成功弹反次数")
	_check(hud.last_toast_text.contains("弹反"), "HUD 弹反反馈出现")
	# 反击：硬直窗口内轻击，伤害应加倍。
	var enemy_hp_before := normal.hp
	player.press_attack()
	await create_timer(0.05).timeout
	player.release_attack()
	await create_timer(0.30).timeout
	_check(normal.hp < enemy_hp_before - 20.0, "硬直内反击造成加倍伤害")
	_check(player.energy > energy_before + 10.0, "命中继续回能")
	# 弹反窗口结束后不再判定。
	player.respawn_at(Vector3(0, 0.05, 6.0), 0.0)
	player.start_parry()
	await create_timer(DreamPlayer.PARRY_WINDOW + 0.06).timeout
	_check(not player.is_parry_active(), "0.18s 后弹反窗关闭")
	_check(player.state == DreamPlayer.State.PARRY, "窗口关闭后仍处于恢复动作")


func _test_dodge_iframes() -> void:
	print("── DODGE / UNPARRYABLE AOE ──")
	_reset_actors()
	boss.reset_enemy()
	boss.aggro = true
	world.boss_engaged = true
	player.respawn_at(boss.global_position + Vector3(-2.8, 0.05, 0), -PI * 0.5)
	player.face_target(boss)
	player.energy = 55.0
	await create_timer(0.08).timeout
	boss.force_attack("toll")
	await create_timer(0.08).timeout
	_check(boss.state == DreamEnemy.State.WINDUP, "Boss 丧钟起手")
	_check(boss.current_attack_parryable() == false, "丧钟领域不可弹反")
	await process_frame
	_check(hud.parry_hint_text.contains("闪避"), "不可弹反攻击提示闪避")
	var hp_before := player.hp
	var stamina_before := player.stamina
	var dodge_before := player.dodge_success_count
	player.start_dodge()
	await process_frame
	_check(player.is_invulnerable(), "闪避启动即有 i-frames")
	_check(player.stamina < stamina_before - 15.0, "闪避消耗气力")
	boss.debug_skip_windup()
	await create_timer(0.10).timeout
	_check(player.hp == hp_before, "i-frames 内不受丧钟伤害")
	_check(player.dodge_success_count > dodge_before, "记录成功闪避")
	world.boss_engaged = false
	boss.aggro = false
	boss.reset_enemy()


func _test_energy_and_stamina() -> void:
	print("── ENERGY / STAMINA / SHARED RESOURCE ──")
	_reset_actors()
	player.respawn_at(Vector3(0, 0.05, 3.4), 0.0)
	player.hp = 50.0
	player.energy = 80.0
	player.state = DreamPlayer.State.FREE
	player.try_heal()
	_check(player.energy <= 47.0, "回梦消耗 35 忆能")
	await create_timer(0.50).timeout
	_check(player.hp >= 85.0, "回梦恢复 35 梦血")
	_check(DreamPlayer.HEAL_COST == 35.0 and DreamWorld.RELIC_COST == 25.0, "回梦与遗物共享忆能且成本明确")
	var stamina_start := player.stamina
	player.state = DreamPlayer.State.FREE
	player.start_dodge()
	await create_timer(0.1).timeout
	_check(player.stamina < stamina_start - 15.0, "闪避消耗气力")
	await create_timer(0.9).timeout
	_check(player.stamina > stamina_start - 30.0, "气力会自然回复")
	_check(player.state != DreamPlayer.State.DEAD, "资源测试后玩家存活")
	# 重击：按住左键 ≥0.32s，消耗更多气力。
	_reset_actors()
	player.state = DreamPlayer.State.FREE
	player.state_time = 0.0
	player.stamina = 100.0
	player.energy = 80.0
	player.press_attack()
	await create_timer(0.36).timeout
	_check(player.attack_held, "按住左键进入蓄力")
	player.release_attack()
	await create_timer(0.06).timeout
	_check(player.state == DreamPlayer.State.ATTACK and player.attack_heavy, "按住后释放为重击")
	_check(player.stamina < 82.0, "重击消耗更多气力")
	await create_timer(0.9).timeout
	# 锁定：靠近巡游者，Tab/中键可在最近敌人间锁定。
	player.respawn_at(Vector3(0, 0.05, -20.5), 0.0)
	await create_timer(0.08).timeout
	world.toggle_lock_on()
	_check(player.lock_target == normal, "锁定最近的梦魇")
	world.toggle_lock_on()
	_check(player.lock_target == null, "再次按下解除锁定")


func _test_enemy_death_and_checkpoint() -> void:
	print("── ENEMY DEATH / CHECKPOINT RESET ──")
	_reset_actors()
	normal.take_damage(9999.0, false, player.global_position)
	await process_frame
	_check(not normal.is_alive(), "普通梦魇可被击杀")
	_check(normal.collision_layer == 0, "死亡后关闭敌人碰撞")
	world.respawn_at_checkpoint()
	await create_timer(0.15).timeout
	_check(normal.is_alive(), "检查点重置普通梦魇")
	_check(normal.hp == normal.max_hp, "重置后敌人满血")
	_check(world.run_state == DreamWorld.RunState.PLAYING, "重置后回到游玩状态")


func _test_player_death_and_respawn() -> void:
	print("── PLAYER DEATH / RESPAWN ──")
	_reset_actors()
	world.last_checkpoint = world.checkpoints[0]
	var deaths_before := world.death_count
	player.hit_invuln = 0.0
	player.hp = 5.0
	player.take_damage(999.0, player.global_position + Vector3(0, 0, 2))
	await process_frame
	_check(player.state == DreamPlayer.State.DEAD, "致命伤进入死亡状态")
	_check(world.run_state == DreamWorld.RunState.DEAD, "世界进入梦碎状态")
	_check(world.death_count == deaths_before + 1, "梦碎计数增加")
	await process_frame
	_check(hud.death_overlay_visible, "HUD 显示梦碎叠层")
	await create_timer(2.65).timeout
	_check(world.run_state == DreamWorld.RunState.PLAYING, "等待后自动复活")
	_check(player.hp == DreamPlayer.MAX_HP, "复活满梦血")
	_check(player.global_position.distance_to(world.checkpoints[0]["spawn"]) < 0.6, "复活在最后检查点")
	_check(normal.is_alive(), "复活后梦魇重置")


func _test_relic_gate_and_shards() -> void:
	print("── RELIC / HIDDEN BRIDGE / SHARDS ──")
	_reset_actors()
	# 清掉巡游者，避免拾取流程被 AI 打断。
	normal.take_damage(9999.0, false, player.global_position)
	await process_frame
	player.respawn_at(Vector3(4.5, 0.05, -25.2), 0.0)
	player.energy = 80.0
	await create_timer(0.06).timeout
	_check(world.get_interact_text().contains("窥梦棱镜"), "祭坛交互提示")
	world.interact()
	await process_frame
	_check(world.has_relic, "取得窥梦棱镜")
	_check(world.level.relic_prism.visible == false, "取得后祭坛棱镜隐藏")
	_check(world.get_objective_text().contains("E") or world.get_objective_text().contains("遗物"), "HUD 目标转向遗物")
	# 第一枚记忆残片
	player.respawn_at(Vector3(0, 0.05, -25.2), 0.0)
	await create_timer(0.06).timeout
	_check(world.get_interact_text().contains("记忆残片"), "残片交互提示")
	world.interact()
	await process_frame
	_check(world.shards_collected == 1, "拾取第一枚记忆残片")
	# 遗物开门
	player.respawn_at(Vector3(-7.2, 0.05, -22.0), -PI * 0.5)
	player.energy = 80.0
	await create_timer(0.06).timeout
	_check(world.level.bridge_root.visible == false, "开门前断桥不可见")
	_check(world.level.bridge_body.collision_layer == 0, "开门前断桥不可走")
	_check(world.get_interact_text().contains("窥梦"), "断桥边遗物交互提示")
	# 先验证幻象墙真的挡人：相机等轴下 W+A = 世界西向。
	player.state = DreamPlayer.State.FREE
	Input.action_press("move_forward")
	Input.action_press("move_left")
	await create_timer(0.55).timeout
	Input.action_release("move_forward")
	Input.action_release("move_left")
	_check(player.global_position.x > -8.05, "遗物使用前幻象墙挡住断桥")
	world.interact()
	await process_frame
	_check(world.bridge_revealed, "遗物看破幻象")
	_check(world.player.energy < 60.0, "遗物消耗忆能")
	_check(world.level.bridge_root.visible, "断桥显形")
	_check(world.level.bridge_body.collision_layer == 1, "断桥获得碰撞")
	_check(world.level.barrier_body.collision_layer == 0, "幻象墙碰撞解除")
	_check(world.get_objective_text().contains("断桥") or world.get_objective_text().contains("残片"), "HUD 目标更新到断桥之后")
	# 真正用移动跨过显形断桥，验证碰撞层已切换。
	player.state = DreamPlayer.State.FREE
	Input.action_press("move_forward")
	Input.action_press("move_left")
	await create_timer(1.45).timeout
	Input.action_release("move_forward")
	Input.action_release("move_left")
	await create_timer(0.1).timeout
	_check(player.global_position.x < -9.2, "显形后可实际走过断桥")
	_check(player.global_position.y > -0.5, "过桥途中没有跌落")
	# 第二枚记忆残片（隐藏岛）
	player.respawn_at(Vector3(-17.0, 0.05, -22.0), 0.0)
	await create_timer(0.06).timeout
	world.interact()
	await process_frame
	_check(world.shards_collected == 2, "拾取隐藏岛上的第二枚残片")
	_check(world.get_objective_text().contains("守梦人"), "碎片齐后目标指向 Boss")


func _test_boss_and_victory() -> void:
	print("── BOSS / PHASE / VICTORY ──")
	_reset_actors()
	# 碎片和遗物状态不能因检查点重置而丢失。
	world.has_relic = true
	world.bridge_revealed = true
	world.level.set_relic_taken(true)
	world.level.set_bridge_open(true)
	for shard in world.shards:
		shard["collected"] = true
		var node: Node3D = shard["node"]
		node.visible = false
	world.shards_collected = 2
	player.respawn_at(Vector3(24.0, 0.05, -22.0), -PI * 0.5)
	player.face_target(boss)
	await create_timer(0.10).timeout
	boss.aggro = true
	world.boss_engaged = true
	await process_frame
	_check(hud.boss_bar_visible, "交战时 HUD 显示 Boss 血条")
	_check(world.is_boss_bar_visible(), "Boss 血条状态接口")
	_check(boss.hp == boss.max_hp, "Boss 满血")
	boss.hp = boss.max_hp * 0.55
	boss.take_damage(20.0, false, player.global_position)
	await process_frame
	_check(boss.phase_two, "Boss 半血进入第二声钟")
	_check(boss.phase_two, "二阶段状态可读")
	var parried_before := player.parry_success_count
	boss.on_parried()
	await process_frame
	_check(boss.is_staggered(), "Boss 也可被弹反硬直")
	_check(boss.can_be_riposted(), "Boss 硬直提供反击窗口")
	_check(player.parry_success_count == parried_before, "Boss 硬直不由玩家自动弹反计数")
	# 击败 Boss，检查胜利。
	boss.take_damage(99999.0, false, player.global_position)
	await create_timer(0.25).timeout
	_check(not boss.is_alive(), "Boss 被击败")
	_check(world.run_state == DreamWorld.RunState.VICTORY, "集齐残片并击败 Boss 后胜利")
	await process_frame
	_check(hud.victory_overlay_visible, "HUD 显示胜利叠层")
	_check(hud.boss_bar_visible == false, "胜利后隐藏 Boss 血条")


func _test_restart_and_pause() -> void:
	print("── RESTART / PAUSE ──")
	world.restart_run()
	await create_timer(0.15).timeout
	_check(world.run_state == DreamWorld.RunState.PLAYING, "重开后回到游玩")
	_check(world.shards_collected == 0 and not world.has_relic and not world.bridge_revealed, "重开清空残片/遗物/断桥")
	_check(world.level.bridge_root.visible == false and world.level.bridge_body.collision_layer == 0, "重开后断桥恢复隐藏")
	_check(world.level.barrier_body.collision_layer == 1, "重开后幻象墙恢复")
	_check(boss.is_alive() and boss.hp == boss.max_hp, "重开后 Boss 满血复活")
	_check(normal.is_alive() and normal.hp == normal.max_hp, "重开后巡游者复活")
	_check(player.hp == DreamPlayer.MAX_HP, "重开后玩家满血")
	_check(world.death_count == 0, "重开清空梦碎计数")
	_check(player.global_position.distance_to(DreamWorld.START_POS) < 0.6, "重开回到起始残梦灯")
	await process_frame
	_check(hud.victory_overlay_visible == false, "重开后胜利叠层消失")
	# 暂停
	world.toggle_pause()
	await process_frame
	_check(world.paused and paused, "暂停状态与场景树暂停同时生效")
	_check(hud.pause_visible, "HUD 显示暂停叠层")
	world.toggle_pause()
	await process_frame
	_check(not world.paused and not paused, "取消暂停恢复运行")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", message)
	else:
		fails.append(message)
		printerr("FAIL  ", message)


func _finish() -> void:
	done = true
	if fails.is_empty():
		print("DREAM_PARRY_SMOKE_OK checks=%d" % checks)
		quit(0)
	else:
		printerr("DREAM_PARRY_SMOKE_FAILED checks=%d fails=%d" % [checks, fails.size()])
		for failure in fails:
			printerr("  - ", failure)
		quit(1)
