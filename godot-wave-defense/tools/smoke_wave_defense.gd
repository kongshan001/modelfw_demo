extends SceneTree
## 《苔关八波》headless 验收：波次推进、建塔/升级/出售、修墙、寻路/伤害、
## 升级三选一、失败/重开、分数/评级、存档、确定性 seed。
## 用法：godot --headless --path . --script tools/smoke_wave_defense.gd
## 通过时最后一行输出 WAVE_DEFENSE_SMOKE_OK，退出码 0。

const Data = preload("res://scripts/game_data.gd")
const StateScript = preload("res://scripts/game_state.gd")

const SAVE_PATH := "user://wd_smoke_save.json"

var main
var _pass := 0
var _fail := 0
var _lines: Array[String] = []


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool, detail := "") -> void:
	if ok:
		_pass += 1
		_lines.append("PASS  " + label)
	else:
		_fail += 1
		_lines.append("FAIL  " + label + ("  [" + detail + "]" if detail != "" else ""))
		push_error("SMOKE FAIL: " + label + (" " + detail if detail != "" else ""))


func _tick(seconds: float, dt := 0.05) -> void:
	var steps := int(ceil(seconds / dt))
	for i in range(steps):
		main.demo_tick(dt)


func _run() -> void:
	_remove_save()
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	main = scene
	main.demo_use_save_path(SAVE_PATH)
	main.demo_set_manual_tick(true)
	main.demo_start_run(Data.DEFAULT_SEED)
	await process_frame

	_test_initial_state()
	_test_determinism()
	_test_economy()
	_test_tower_combat()
	_test_pathing_and_damage()
	_test_wall_and_castle()
	_test_boss_summon()
	_test_upgrades()
	_test_failure_and_restart()
	_test_full_run()
	_test_persistence()

	for line in _lines:
		print(line)
	print("SMOKE SUMMARY: %d passed, %d failed" % [_pass, _fail])
	if _fail == 0:
		print("WAVE_DEFENSE_SMOKE_OK")
		quit(0)
	else:
		print("WAVE_DEFENSE_SMOKE_FAILED")
		quit(1)


func _remove_save() -> void:
	var path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(path)


func _test_initial_state() -> void:
	_check("初始金币 60", main.state.gold == Data.START_GOLD, str(main.state.gold))
	_check("主城 100 HP", main.state.castle_hp == Data.CASTLE_MAX_HP, str(main.state.castle_hp))
	_check("第 1 波准备阶段", main.waves.phase == "prep", String(main.waves.phase))
	_check("8 波数据完整", Data.WAVES.size() == 8, str(Data.WAVES.size()))
	_check("5 种敌人", Data.ENEMIES.size() == 5, str(Data.ENEMIES.size()))
	_check("2 种塔", Data.TOWERS.size() == 2, str(Data.TOWERS.size()))
	_check("3 个升级节点", Data.UPGRADE_MILESTONES.size() == 3, str(Data.UPGRADE_MILESTONES.size()))
	_check("第 8 波含 Boss", Data.wave_summary(7).contains("巨兽"), Data.wave_summary(7))


func _test_determinism() -> void:
	var a := JSON.stringify(main.waves.build_spawn_plan(3, 777))
	var b := JSON.stringify(main.waves.build_spawn_plan(3, 777))
	var c := JSON.stringify(main.waves.build_spawn_plan(3, 778))
	_check("同 seed 生成计划一致", a == b)
	_check("不同 seed 生成计划不同", a != c)
	var all_a: Array[String] = []
	var all_b: Array[String] = []
	for w in range(Data.WAVES.size()):
		all_a.append(JSON.stringify(main.waves.build_spawn_plan(w, 20261122)))
		all_b.append(JSON.stringify(main.waves.build_spawn_plan(w, 20261122)))
	_check("8 波生成计划均可复现", all_a == all_b)


func _test_economy() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_gold(500)
	_check("建造弩塔成功", main.demo_build_tower(0, "crossbow"))
	var tower = main.get_tower(0)
	_check("弩塔已占位", tower != null)
	_check("扣除弩塔造价 50", main.state.gold == 450, str(main.state.gold))
	_check("弩塔升 Lv.2", main.demo_upgrade_tower(0))
	_check("扣除升级费 60", main.state.gold == 390, str(main.state.gold))
	_check("弩塔等级 2", tower.level == 2, str(tower.level))
	var bolt_stats: Dictionary = tower.stats()
	_check("弩塔 Lv.2 伤害 12.5", is_equal_approx(float(bolt_stats["damage"]), 12.5), str(bolt_stats["damage"]))
	_check("建造炮塔成功", main.demo_build_tower(1, "cannon"))
	var cannon = main.get_tower(1)
	_check("扣除炮塔造价 70", main.state.gold == 320, str(main.state.gold))
	_check("炮塔有爆炸半径", float(cannon.stats()["splash"]) > 0.0, str(cannon.stats()["splash"]))
	_check("出售炮塔返还 35", main.demo_sell_tower(1))
	_check("出售后金币 355", main.state.gold == 355, str(main.state.gold))
	_check("出售后建造位空出", main.get_tower(1) == null)
	main.demo_set_gold(10)
	_check("金币不足时建造失败", not main.demo_build_tower(2, "cannon"))

	# 战斗期禁止建造。
	main.demo_set_gold(500)
	main.demo_skip_prep()
	_check("战斗期禁止建造", not main.demo_build_tower(2, "crossbow"))
	main.demo_clear_enemies()
	_tick(2.0)


func _path_distance_near(point: Vector2) -> float:
	var best := 0.0
	var best_d := INF
	var total := Data.path_length()
	var d := 0.0
	while d <= total:
		var dist := point.distance_to(Data.path_point_at(d))
		if dist < best_d:
			best_d = dist
			best = d
		d += 5.0
	return best


func _test_tower_combat() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_gold(500)
	main.demo_set_player_pos(Vector2(1150, 620))
	_check("弩塔建造（战斗测试）", main.demo_build_tower(0, "crossbow"))
	var d0 := _path_distance_near(Vector2(Data.BUILD_PADS[0]["pos"]))
	var e = main.demo_spawn_enemy("militia", d0, 0.0)
	_tick(1.5)
	_check("弩塔自动开火命中", e != null and e.hp < e.max_hp, str(e.hp) if e != null else "null")
	main.demo_clear_enemies()
	var far = main.demo_spawn_enemy("militia", 0.0, 0.0)
	_tick(0.4)
	_check("射程外敌人不受伤", far != null and is_equal_approx(far.hp, far.max_hp), str(far.hp) if far != null else "null")
	main.demo_clear_enemies()

	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_gold(500)
	main.demo_set_player_pos(Vector2(1150, 620))
	_check("炮塔建造（战斗测试）", main.demo_build_tower(1, "cannon"))
	var d1 := _path_distance_near(Vector2(Data.BUILD_PADS[1]["pos"]))
	var group: Array = []
	for i in range(3):
		group.append(main.demo_spawn_enemy("militia", d1 - 16.0 + float(i) * 16.0, float(i - 1) * 6.0))
	_tick(2.2)
	var damaged := 0
	for enemy in group:
		if enemy != null and enemy.hp < enemy.max_hp:
			damaged += 1
	_check("炮塔溅射命中 ≥2 个目标", damaged >= 2, str(damaged))
	main.demo_clear_enemies()


func _test_pathing_and_damage() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_player_pos(Vector2(1150, 620))
	var e = main.demo_spawn_enemy("militia", 0.0)
	_check("敌人生成成功", e != null)
	var start_d: float = e.path_distance
	_tick(0.5)
	_check("民兵沿路径推进", e.path_distance > start_d + 10.0, str(e.path_distance))
	_check("民兵位置跟随路径", e.position.distance_to(Data.path_point_at(e.path_distance)) < 24.0)
	main.demo_clear_enemies()

	# 盾兵护甲：弩箭 ×0.6，炮塔全额。
	var shield = main.demo_spawn_enemy("shield", 60.0)
	var hp0: float = shield.hp
	shield.take_damage(10.0, "bolt")
	_check("盾兵对弩箭减伤 40%", is_equal_approx(hp0 - shield.hp, 6.0), str(hp0 - shield.hp))
	var hp1: float = shield.hp
	shield.take_damage(10.0, "cannon")
	_check("盾兵吃炮塔全额伤害", is_equal_approx(hp1 - shield.hp, 10.0), str(hp1 - shield.hp))

	# 击杀给金币、计击杀数。
	main.state.add_gold(0)
	var gold0: int = main.state.gold
	var kills0: int = main.state.kills
	shield.take_damage(500.0, "lord")
	_check("盾兵被击杀", not bool(shield.alive))
	_check("击杀数 +1", main.state.kills == kills0 + 1, str(main.state.kills))
	_check("击杀金币 +4", main.state.gold == gold0 + 4, str(main.state.gold))
	main.demo_tick(0.05)
	_check("尸体被清理", main.enemies.is_empty(), str(main.enemies.size()))

	# 领主自动攻击与技能。
	main.demo_clear_enemies()
	var aim_pos := Data.path_point_at(420.0)
	main.demo_set_player_pos(aim_pos)
	var e2 = main.demo_spawn_enemy("militia", 420.0)
	_tick(1.2)
	_check("领主自动普攻命中", e2.hp < e2.max_hp, str(e2.hp))
	main.demo_clear_enemies()
	var e3 = main.demo_spawn_enemy("militia", 420.0)
	main.demo_set_player_pos(aim_pos)
	var skill_ok: bool = main.demo_cast_skill()
	_check("回旋斩可释放", skill_ok)
	_check("回旋斩造成伤害", not bool(e3.alive) or e3.hp < e3.max_hp, str(e3.hp))
	_check("技能进入冷却", main.player.skill_left > 0.0, str(main.player.skill_left))
	main.demo_clear_enemies()


func _test_wall_and_castle() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_player_pos(Vector2(1150, 620))
	main.demo_clear_enemies()
	var wall_hp0: float = main.wall.hp
	var e = main.demo_spawn_enemy("shield", Data.path_length() - 8.0)
	_tick(1.6)
	_check("敌人拆墙造成伤害", main.wall.hp < wall_hp0, "%s -> %s" % [wall_hp0, main.wall.hp])
	main.demo_clear_enemies()

	# 波间修墙。
	main.demo_set_gold(200)
	var gold0: int = main.state.gold
	_check("修墙成功", main.demo_repair_wall())
	_check("城墙回满", is_equal_approx(main.wall.hp, main.wall.max_hp), str(main.wall.hp))
	_check("修墙扣 25 金", main.state.gold == gold0 - Data.WALL_REPAIR_COST, str(main.state.gold))

	# 墙破后敌人攻击主城。
	main.demo_damage_wall(999.0)
	_check("城墙可被摧毁", not main.wall.alive)
	var castle_hp0: int = main.state.castle_hp
	var e2 = main.demo_spawn_enemy("shield", Data.path_length() - 8.0)
	_tick(3.0)
	_check("墙破后敌人攻击主城", main.state.castle_hp < castle_hp0, "%d -> %d" % [castle_hp0, main.state.castle_hp])
	main.demo_clear_enemies()
	_check("城墙重建（费用 40）", main.demo_repair_wall())
	_check("城墙复活", main.wall.alive)


func _test_boss_summon() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_player_pos(Vector2(1150, 620))
	main.demo_clear_enemies()
	var boss = main.demo_spawn_enemy("boss", 300.0)
	_check("Boss 生成", boss != null and boss.is_boss())
	boss.take_damage(600.0, "lord")
	main.demo_tick(0.05)
	main.demo_tick(0.05)
	var militia_count := 0
	for enemy in main.enemies:
		if is_instance_valid(enemy) and enemy.type_id == "militia":
			militia_count += 1
	_check("Boss 半血召唤 4 民兵", militia_count == 4, str(militia_count))
	main.demo_clear_enemies()


func _test_upgrades() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_open_upgrade(0, false)
	_check("三选一面板打开", main.upgrade_open)
	_check("选择射程升级", main.demo_choose_upgrade(0))
	_check("塔射程修正 ×1.2", is_equal_approx(float(main.state.mods["tower_range"]), 1.2), str(main.state.mods["tower_range"]))
	_check("构筑记录 1 项", main.state.chosen_upgrades.size() == 1)

	main.demo_open_upgrade(1, false)
	main.demo_set_castle_hp(50)
	_check("选择城防抢修", main.demo_choose_upgrade(0))
	_check("主城回复 20 HP", main.state.castle_hp == 70, str(main.state.castle_hp))

	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_open_upgrade(0, false)
	_check("选择战地征缴", main.demo_choose_upgrade(2))
	var gold0: int = main.state.gold
	var e = main.demo_spawn_enemy("militia", 200.0)
	e.take_damage(999.0, "lord")
	_check("击杀金币 +1 生效", main.state.gold == gold0 + 3, str(main.state.gold - gold0))
	main.demo_clear_enemies()


func _test_failure_and_restart() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_castle_hp(10)
	main.demo_damage_castle(25.0)
	_check("主城归零判负", main.run_over and not bool(main.state.victory))
	var expected: int = main.state.compute_score()
	_check("失败分数按公式计算", main.state.score == expected, "%d vs %d" % [main.state.score, expected])
	_check("失败有评级", main.state.grade != "", main.state.grade)
	_check("失败写存档", FileAccess.file_exists(SAVE_PATH))
	_check("失败波次为 0", main.state.wave_cleared == 0, str(main.state.wave_cleared))

	main.demo_restart()
	_check("重开后继续游戏", not main.run_over)
	_check("重开后金币重置", main.state.gold == Data.START_GOLD, str(main.state.gold))
	_check("重开后主城满血", main.state.castle_hp == Data.CASTLE_MAX_HP, str(main.state.castle_hp))
	_check("重开后回到第 1 波准备", main.waves.phase == "prep" and main.waves.wave_index == 0)
	_check("重开后敌我清空", main.enemies.is_empty() and main.get_tower(0) == null)

	# 重开保留最高分。
	main.demo_set_gold(60)
	main.demo_damage_castle(999.0)
	_check("第二次失败分数不超过最高分", main.state.best_score >= main.state.score)
	main.demo_restart()


func _test_full_run() -> void:
	main.demo_start_run(20261122)
	var cleared_waves := 0
	for w in range(Data.WAVES.size()):
		_check("第 %d 波准备" % (w + 1), main.waves.phase == "prep", String(main.waves.phase))
		main.demo_skip_prep()
		var guard := 0
		while main.waves.phase == "combat" and not main.run_over and guard < 4000:
			main.demo_tick(0.05)
			if main.waves.phase == "combat":
				main.demo_clear_enemies()
			guard += 1
		if main.upgrade_open:
			main.demo_choose_upgrade(0)
		cleared_waves += 1
		if w < Data.WAVES.size() - 1:
			_check("第 %d 波后未结束" % (w + 1), not main.run_over)
	_check("8 波全部推进", cleared_waves == 8, str(cleared_waves))
	_check("守满 8 波判胜", main.run_over and bool(main.state.victory))
	_check("胜利记录 8 波", main.state.wave_cleared == 8, str(main.state.wave_cleared))
	_check("3 次构筑均已选择", main.state.chosen_upgrades.size() == 3, str(main.state.chosen_upgrades.size()))
	var expected: int = 8 * 100 + main.state.kills * 10 + main.state.castle_hp * 50 + main.state.gold
	_check("胜利分数按公式计算", main.state.score == expected, "%d vs %d" % [main.state.score, expected])
	_check("满构筑评级 S", main.state.grade == "S", "%s / %d" % [main.state.grade, main.state.score])
	_check("最高分已更新", main.state.best_score == main.state.score, str(main.state.best_score))
	_check("最佳波次 8", main.state.best_wave == 8, str(main.state.best_wave))


func _test_persistence() -> void:
	var score_before: int = main.state.best_score
	var reloaded = StateScript.new(SAVE_PATH)
	var loaded: bool = reloaded.load_save()
	_check("存档可读取", loaded)
	_check("存档保留最高分", reloaded.best_score == score_before, "%d vs %d" % [reloaded.best_score, score_before])
	_check("存档保留最佳波次", reloaded.best_wave == 8, str(reloaded.best_wave))
