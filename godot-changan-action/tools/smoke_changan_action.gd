extends SceneTree

## Headless 冒烟：状态机 / 连击 / 翻滚 i-frames / 受击·击倒·起身 / 敌人 AI 令牌 /
## 战斗触发 / 街道灯 / Boss 两阶段 / 剧情 beat / 胜负 / 重开。
##   godot --headless --path . -s tools/smoke_changan_action.gd
## 末行 CHANGAN_ACTION_SMOKE_OK。

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


func _run() -> void:
	print("CHANGAN_ACTION_SMOKE start")
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# 1. 载入
	check(scene.world != null, "world built")
	check(scene.player != null and scene.player.anim != null, "player model + AnimationPlayer")
	check(scene.player.anim.get_animation_list().size() >= 60, "player has KayKit clip set")
	check(scene.world.lantern_count >= 30, ">=30 hanging lanterns")
	check(scene.world.lamps.size() == 3, "3 street lamps")
	check(scene.game_state == "title", "boots into title")
	check(not scene.player.visible, "title hides player model")
	check(scene.quest_text.contains("阿禾"), "initial objective points to Ahe")

	# 2. 标题 → 开始
	scene.start_game()
	await wait(0.15)
	check(scene.game_state == "playing", "title -> playing")
	check(scene.player.visible, "start shows player model")
	check(scene.player.controls_enabled, "controls enabled after start")

	# 3. 移动状态
	scene.demo_teleport(Vector3(0, 0.06, 3.0), 0.0)
	var p0: Vector3 = scene.player.global_position
	scene.demo_move(Vector3(0, 0, 1))
	await wait(0.55)
	scene.demo_stop()
	var moved: float = Vector2(scene.player.global_position.x - p0.x,
		scene.player.global_position.z - p0.z).length()
	check(moved > 0.35, "Move: demo input moves player (%.2fm)" % moved)
	check(scene.player.state in ["move", "sprint", "idle"], "Move: locomotion state=%s" % scene.player.state)
	await wait(0.25)
	check(scene.player.state == "idle", "Idle: stops back to idle")

	# 4. 攻击 / 3 连 / 击倒
	scene.demo_start_wave(1)
	await process_frame
	scene.set_controls_enabled(false)
	scene.demo_teleport(Vector3(0, 0.06, 18.0), 0.0)
	await wait(0.1)
	for e in scene.wave_enemies:
		e.active = false
	var target = scene.wave_enemies[0]
	target.global_position = scene.player.global_position + Vector3(0, 0, 1.7)
	target.hp = target.max_hp
	await wait(0.05)
	var hp_before: int = target.hp
	check(scene.player.begin_attack("jab"), "Attack: jab accepted")
	await wait(0.22)
	check(target.hp < hp_before, "Attack: jab registers damage")
	check(scene.combo >= 1, "Combo: hit increments combo")
	check(scene.player.attack_count >= 1, "Attack: state entered")

	# J-J-K
	scene.player.combo_window = 1.0
	scene.player.combo_step = 1
	target.hp = target.max_hp
	target.global_position = scene.player.global_position + Vector3(0, 0, 1.7)
	target.state = "idle"
	check(scene.player.begin_attack("jab"), "Combo: second jab accepted")
	await wait(0.22)
	check(scene.player.attack_kind == "jab2", "Combo: second hit is jab2")
	scene.player.combo_window = 1.0
	scene.player.combo_step = 2
	check(scene.player.begin_attack("kick"), "Combo: third hit accepted")
	await wait(0.40)
	check(scene.player.attack_kind == "finisher", "Combo: third hit resolves to finisher")
	check(target.hp <= 0 or target.state in ["knockdown", "dead"], "Combo: finisher knocks down/kills")

	# 5. 翻滚 i-frames
	scene.demo_clear_wave()
	await wait(0.1)
	scene.set_controls_enabled(true)
	scene.player.reset_state(Vector3(0, 0.06, 12), 0.0)
	await wait(0.05)
	var hp0: int = scene.player.hp
	check(scene.player.start_roll(Vector3(0, 0, 1)), "Roll: accepted")
	await wait(0.16)
	check(scene.player.i_frame_window_active(), "Roll: inside i-frame window 0.08–0.30s")
	scene.player.take_damage(10, scene.player.global_position - Vector3(0, 0, 1))
	check(scene.player.hp == hp0, "Roll: damage ignored during i-frames")
	await wait(0.36)
	check(not scene.player.i_frame_window_active(), "Roll: i-frames ended")
	scene.player.take_damage(10, scene.player.global_position - Vector3(0, 0, 1))
	check(scene.player.hp == hp0 - 10, "Roll: damage lands after i-frames")

	# 5b. 火油地面持续伤害
	scene.player.reset_state(Vector3(0, 0.06, 12), 0.0)
	await process_frame
	var fire_hp: int = scene.player.hp
	scene.spawn_oil_fire(scene.player.global_position, 0.9)
	await wait(0.75)
	check(scene.player.hp < fire_hp, "Oil fire: standing in fire deals damage")

	# 6. 受击 / 击倒 / 起身 / 胜利
	scene.player.reset_state(Vector3(0, 0.06, 12), 0.0)
	await process_frame
	scene.player.take_damage(5, scene.player.global_position + Vector3(0, 0, -1), false)
	check(scene.player.state == "hit", "Hit: state=hit")
	await wait(0.5)
	scene.player.reset_state(Vector3(0, 0.06, 12), 0.0)
	scene.player.take_damage(5, scene.player.global_position + Vector3(0, 0, -1), true)
	check(scene.player.state == "knockdown", "Knockdown: state=knockdown")
	await wait(1.15)
	check(scene.player.state in ["getup", "knockdown"], "GetUp: enters getup after lie")
	# 宿主负载高时物理帧可能抖动；轮询到起身完成（最多 3s）
	var waited := 0.0
	while scene.player.state in ["knockdown", "getup"] and waited < 3.0:
		await wait(0.1)
		waited += 0.1
	check(scene.player.state in ["idle", "move"], "GetUp: returns to locomotion")
	scene.player.play_victory()
	check(scene.player.state == "victory", "Victory: player victory state")
	scene.player.reset_state(Vector3(0, 0.06, 12), 0.0)

	# 7. 敌人 AI 回合 + 攻击令牌
	scene.demo_start_wave(1)
	var telegraphs := [0]
	var max_simultaneous := 0
	for e in scene.wave_enemies:
		e.active = true
		e.attack_telegraphed.connect(func() -> void: telegraphs[0] += 1)
	scene.demo_teleport(Vector3(0, 0.06, 18.5), 0.0)
	var t := 0.0
	while t < 2.4:
		await wait(0.05)
		t += 0.05
		var attacking := 0
		for e in scene.wave_enemies:
			if is_instance_valid(e) and not e.is_dead and e.is_attacking():
				attacking += 1
		max_simultaneous = maxi(max_simultaneous, attacking)
	check(telegraphs[0] > 0, "EnemyAI: at least one attack telegraphed (%d)" % telegraphs[0])
	check(max_simultaneous <= 1, "EnemyAI: attack token keeps 1v1 (max=%d)" % max_simultaneous)
	scene.demo_clear_wave()
	await wait(0.1)

	# 8. 剧情 beat / 战斗触发 / 街道灯
	scene.demo_restart()
	await wait(0.1)
	scene.demo_teleport(Vector3(0, 0.06, 14.0), 0.0)
	scene.demo_talk("ahe")
	check(scene.game_state == "dialogue", "Story: Ahe dialogue opens")
	check(scene.dialogue_lines.size() >= 2 and scene.dialogue_lines.size() <= 4, "Story: 2–4 dialogue lines")
	scene.demo_skip_dialogue()
	await wait(0.1)
	check(scene.game_state == "playing", "Story: dialogue closes back to play")
	check(scene.current_wave == 1 and scene.encounter_active, "Encounter 1: spawns after Ahe")
	check(scene.wave_enemies.size() == 2 and scene.wave_enemies[0].archetype == "thug", "Encounter 1: two thug archetype")
	check(scene.story_beats.has("B1"), "Story beat B1 reached")
	check(scene.quest_text.contains("泼皮"), "Objective: defeat thugs")
	scene.demo_clear_wave()
	await wait(0.1)
	check(scene.wave1_cleared, "Encounter 1: cleared")
	check(scene.story_stage == "light_street", "Story: stage light_street")
	check(scene.quest_text.contains("街灯"), "Objective: light street lamps")
	scene.demo_light_lamp(0)
	scene.demo_light_lamp(1)
	scene.demo_light_lamp(2)
	check(scene.street_lights_lit == 3, "Street lamps: 3/3 lit")
	scene.demo_teleport(Vector3(0, 0.06, 44.0), 0.0)
	await wait(0.2)
	check(scene.current_wave == 2 and scene.encounter_active, "Encounter 2: triggered at Z=44")
	check(scene.story_beats.has("B2"), "Story beat B2 reached")
	check(scene.wave_enemies.size() == 2, "Encounter 2: oil vendor + brute")
	check(scene.wave_enemies[0].archetype == "oil", "Encounter 2: ranged oil archetype")
	check(scene.wave_enemies[1].archetype == "brute", "Encounter 2: elite brute archetype")
	scene.demo_clear_wave()
	await wait(0.1)
	check(scene.wave2_cleared, "Encounter 2: cleared")
	check(scene.story_stage == "find_wenjiu", "Story: stage find_wenjiu")
	scene.demo_talk("wenjiu")
	check(scene.game_state == "dialogue", "Story: Wen Jiu dialogue opens")
	scene.demo_skip_dialogue()
	await wait(0.1)
	check(scene.story_stage == "boss_ready", "Story: boss_ready after Wen Jiu")
	check(scene.quest_text.contains("鼓楼"), "Objective: go to drum tower")

	# 9. Boss / 熄灯 / 胜负 / 结算 / 重开
	check(scene.extinguish_duration() == 5.0, "Boss: 3 lit lamps -> 5s darkness")
	scene.demo_set_lights(0)
	check(scene.extinguish_duration() == 20.0, "Boss: 0 lit lamps -> 20s darkness")
	scene.demo_set_lights(3)
	check(scene.world.plaza_light != null, "Boss arena: plaza lantern light exists")
	scene.demo_teleport(Vector3(0, 0.06, 73.0), 0.0)
	await wait(0.2)
	check(scene.boss_spawned, "Boss: spawns at plaza trigger")
	check(scene.story_beats.has("B3"), "Story beat B3 reached")
	scene.demo_start_boss()
	await wait(0.1)
	if scene.boss_intro_t > 0.0:
		scene.skip_boss_intro()
	await wait(0.1)
	check(scene.boss_ref != null and not scene.boss_ref.is_dead, "Boss: alive and active")
	check(scene.boss_ref.archetype == "boss" and scene.boss_ref.display_name == "霍三更", "Boss: archetype/name")
	check(scene.boss_ref.phase == 1, "Boss: phase 1")
	scene.demo_boss_phase2()
	await wait(0.2)
	check(scene.boss_ref.phase == 2, "Boss: phase 2 at 50%")
	check(scene.boss_phase2_done, "Boss: extinguish fired")
	check(scene.world.dark_active, "Boss: world darkened by extinguish")
	check(scene.extinguish_duration() == 5.0, "Boss: darkness duration = 20 - 5*3")
	scene.demo_kill_enemy(scene.boss_ref)
	await wait(0.15)
	check(scene.game_state == "choice", "Victory: choice state after boss")
	check(scene.player.state == "victory", "Victory: player victory animation")
	scene.demo_choose("mercy")
	check(scene.game_state == "results", "Ending: results screen")
	check(scene.choice == "mercy", "Ending: mercy choice recorded")
	check(scene.ending_text != "", "Ending: ending text present")
	check(scene.story_beats.size() == 3, "Story: 3 beats reached")
	check(scene.get_stats()["lights"] == 3, "Results: stats include 3 lamps")
	scene.demo_restart()
	await wait(0.15)
	check(scene.game_state == "playing", "Restart: back to play")
	check(scene.story_stage == "meet_ahe", "Restart: story reset")
	check(scene.street_lights_lit == 0, "Restart: lamps reset")
	check(scene.player.hp == 100, "Restart: player full HP")

	# 10. 失败 / 重试
	scene.demo_start_wave(1)
	await wait(0.1)
	scene.demo_teleport(Vector3(0, 0.06, 16.0), 0.0)
	scene.demo_kill_player()
	await wait(0.15)
	check(scene.game_state == "defeat", "Defeat: overlay state")
	scene.demo_retry()
	await wait(0.15)
	check(scene.game_state == "playing", "Retry: back to play")
	check(scene.player.hp == 100 and scene.current_wave == 1, "Retry: full HP, current fight")

	# 11. 清理
	scene.queue_free()
	await process_frame
	await process_frame
	print("CHANGAN_ACTION_SMOKE checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty():
		print("CHANGAN_ACTION_SMOKE_OK")
		quit(0)
	else:
		for f in failures:
			print("FAILED: ", f)
		quit(1)
