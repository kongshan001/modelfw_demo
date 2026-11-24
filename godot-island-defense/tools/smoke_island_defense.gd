extends SceneTree
## headless 冒烟测试：兵种克制 / 高差 / 移动 / 自动攻击 / 波次 / 房屋 / 永久死亡 / 胜负 / 重开。
## 用法：godot --path godot-island-defense --headless -s tools/smoke_island_defense.gd
## 末行输出 ISLAND_DEFENSE_SMOKE_OK。

const Balance = preload("res://scripts/balance.gd")
const UI = preload("res://scripts/ui_style.gd")

var game
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	game = main
	game.auto_simulate = false
	game.demo_mode = true
	game.set_process(false)

	print("— 数据与克制表 —")
	await _test_data()
	print("— 地形 / 导航 / 登陆 —")
	await _test_terrain()
	print("— 伤害系数与管线 —")
	await _test_damage()
	print("— 移动与自动攻击 —")
	await _test_movement_and_attack()
	print("— 房屋受击 —")
	await _test_house_damage()
	print("— 暂停 / 倍速 —")
	await _test_pause_speed()
	print("— 永久死亡 —")
	await _test_permadeath()
	print("— 全屋焚毁失败 —")
	await _test_defeat_houses()
	print("— 全队阵亡失败 —")
	await _test_defeat_squads()
	print("— 波次推进 / 胜利 —")
	await _test_waves_and_victory()
	print("— 下一岛 / 重开 —")
	await _test_next_island_and_restart()

	print("checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty():
		print("ISLAND_DEFENSE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS  " + message)
	else:
		failures.append(message)
		printerr("FAIL  " + message)


func _fresh(hold := true, index := 0) -> void:
	game.debug_start_playing(index, hold)
	await process_frame
	await process_frame


func _sim(seconds: float) -> void:
	var steps := maxi(1, int(ceil(seconds / (1.0 / 30.0))))
	for _i in range(steps):
		if game.state != "playing":
			break
		game.simulate(1.0 / 30.0)


func _test_data() -> void:
	_check(Balance.PLAYER_CLASSES.size() == 3, "三个玩家兵种齐备")
	_check(Balance.SQUAD_SIZE >= 3 and Balance.SQUAD_SIZE <= 6, "每队 3–6 人（当前 %d）" % Balance.SQUAD_SIZE)
	_check(is_equal_approx(Balance.counter("shield", "archer"), 1.8), "盾克弓 ×1.8")
	_check(is_equal_approx(Balance.counter("archer", "spear"), 1.8), "弓克矛 ×1.8")
	_check(is_equal_approx(Balance.counter("spear", "shield"), 1.8), "矛克盾 ×1.8")
	_check(Balance.counter("spear", "archer") < 0.8, "矛被弓克制（<0.8）")
	_check(Balance.counter("raider", "shield") == 1.0, "海掠者无克制修正")
	_check(is_equal_approx(Balance.height_multiplier(10.0, 5.0), 1.2), "高地 +20% 伤害")
	_check(is_equal_approx(Balance.height_multiplier(2.0, 8.0), 0.85), "仰攻 -15% 伤害")
	_check(is_equal_approx(Balance.ranged_resist("shield"), 0.5), "盾卫挡箭 50%")
	_check(is_equal_approx(Balance.ranged_resist("shield", "brute"), 0.5), "重盾蛮兵挡箭 50%")
	var counts: Array = []
	for i in range(Balance.island_count()):
		counts.append(Balance.wave_count(i))
	_check(counts.size() == 2 and counts[0] >= 3 and counts[1] >= 3 and counts[1] <= 5, "两张岛，波次 3–5 波：%s" % str(counts))
	var inc1 := Balance.wave_total_enemies(0, 2) > Balance.wave_total_enemies(0, 0)
	var inc2 := Balance.wave_total_enemies(1, 3) > Balance.wave_total_enemies(1, 0)
	_check(inc1 and inc2, "波次敌人数量递增")
	var all_classes := true
	for id in ["shield", "archer", "spear"]:
		var data: Dictionary = Balance.player_class(id)
		if data.is_empty() or String(data["name"]) == "" or float(data["damage"]) <= 0.0 or float(data["range"]) <= 0.0:
			all_classes = false
	_check(all_classes, "兵种名称/伤害/射程字段有效")


func _test_terrain() -> void:
	await _fresh()
	var island = game.island
	_check(island != null and island.is_built, "岛屿构建完成")
	_check(island.nav_point_count() > 400, "AStar 导航点充足（%d）" % island.nav_point_count())
	_check(island.height_at(0, 0) > 4.0, "岛心高地（%.2f m）" % island.height_at(0, 0))
	_check(island.height_at(island.radius * 0.98, 0) < 1.0, "外缘为海岸低地")
	_check(island.houses.size() == 3, "岛上有 3 座房屋")
	_check(island.landing_count() == 3, "岛上有 3 个登陆点")
	var all_houses_high := true
	for house in island.houses:
		if house.global_position.y < 2.0:
			all_houses_high = false
	_check(all_houses_high, "房屋均建在高地上")
	var path: PackedVector3Array = island.find_path(island.landing_points[0]["pos"], island.get_nearest_house(island.landing_points[0]["pos"]).global_position)
	_check(path.size() >= 2, "登陆点可寻路到房屋（%d 个路点）" % path.size())
	var last: Vector3 = path[path.size() - 1] if path.size() > 0 else Vector3.ZERO
	var house_pos: Vector3 = island.get_nearest_house(island.landing_points[0]["pos"]).global_position
	_check(Vector2(last.x - house_pos.x, last.z - house_pos.z).length() < 4.0, "路径终点抵达房屋外围")
	var wet: Vector3 = island.clamp_to_walkable(Vector3(island.radius * 1.4, 0, 0))
	_check(island.is_terrain_walkable(wet.x, wet.z), "水面点击会被夹回可行走地面")
	var spawn_ok := true
	for pos in island.squad_spawn_points:
		if not island.is_terrain_walkable(pos.x, pos.z):
			spawn_ok = false
	_check(spawn_ok and island.squad_spawn_points.size() == 3, "三队出生点均可行走")


func _test_damage() -> void:
	await _fresh()
	var equal_pos := Vector3(0, 5, 0)
	var high_pos := Vector3(0, 8, 0)
	var low_pos := Vector3(0, 2, 0)
	var d1: Dictionary = game.compute_damage(10.0, "shield", "archer", equal_pos, equal_pos, false)
	var d2: Dictionary = game.compute_damage(10.0, "archer", "spear", equal_pos, equal_pos, false)
	var d3: Dictionary = game.compute_damage(10.0, "spear", "shield", equal_pos, equal_pos, false)
	_check(is_equal_approx(float(d1["damage"]), 18.0), "实际管线：盾→弓 10→18")
	_check(is_equal_approx(float(d2["damage"]), 18.0), "实际管线：弓→矛 10→18")
	_check(is_equal_approx(float(d3["damage"]), 18.0), "实际管线：矛→盾 10→18")
	var high: Dictionary = game.compute_damage(10.0, "raider", "raider", high_pos, low_pos, false)
	var low: Dictionary = game.compute_damage(10.0, "raider", "raider", low_pos, high_pos, false)
	_check(is_equal_approx(float(high["damage"]), 12.0), "高打低 10→12")
	_check(is_equal_approx(float(low["damage"]), 8.5), "低打高 10→8.5")
	var blocked: Dictionary = game.compute_damage(10.0, "archer", "shield", equal_pos, equal_pos, true)
	var brute_hit: Dictionary = game.compute_damage(10.0, "archer", "shield", equal_pos, equal_pos, true, "brute")
	_check(float(blocked["damage"]) < 4.0 and is_equal_approx(float(blocked["resist"]), 0.5), "弓射盾卫被挡（<4）")
	_check(is_equal_approx(float(blocked["damage"]), float(brute_hit["damage"])), "重盾蛮兵与盾卫挡箭同级")
	var enemy = game.debug_spawn_enemy("brute", game.squads[0].center + Vector3(4, 0, 0))
	await process_frame
	var before: float = enemy.hp
	game.damage_enemy(enemy, 10.0, "spear", enemy.global_position, false)
	_check(is_equal_approx(before - enemy.hp, 18.0), "damage_enemy 实际扣血 18（矛克盾）")
	var squad = game.squads[0]
	var member_before: float = float(squad.members[0]["hp"])
	game.damage_member(squad, 0, 10.0, "archer", squad.get_member_position(0), true, "")
	_check(float(squad.members[0]["hp"]) < member_before, "damage_member 实际扣血")


func _test_movement_and_attack() -> void:
	await _fresh()
	var squad = game.squads[0]
	var start: Vector3 = squad.center
	var target: Vector3 = game.island.clamp_to_walkable(start + Vector3(-8, 0, 1.5))
	game.debug_move_squad(0, target)
	_check(squad.path.size() >= 2, "移动指令生成路径")
	_sim(4.2)
	var moved := Vector2(squad.center.x - start.x, squad.center.z - start.z).length()
	var arrived := Vector2(squad.center.x - target.x, squad.center.z - target.z).length()
	_check(moved > 4.0, "队伍实际移动（%.2f m）" % moved)
	_check(arrived < 2.5, "队伍抵达目标附近（%.2f m）" % arrived)
	_check(squad.living_count() == 4, "移动途中无人阵亡")

	await _fresh()
	var melee = game.squads[2]
	var enemy = game.debug_spawn_enemy("raider", melee.center + Vector3(2.1, 0, 0.4))
	_sim(2.6)
	_check(not enemy.alive or enemy.hp < enemy.max_hp, "接近后自动近战攻击")
	_check(melee.living_count() > 0, "小队仍存活")

	await _fresh()
	var archer_squad = game.squads[1]
	var ranged_enemy = game.debug_spawn_enemy("raider", archer_squad.center + Vector3(9.5, 0, 2.0))
	var saw_projectile := false
	for _i in range(90):
		if game.state != "playing":
			break
		game.simulate(1.0 / 30.0)
		if game.projectiles.size() > 0:
			saw_projectile = true
			break
	_check(saw_projectile, "弓手进入射程生成箭矢投射物")
	_sim(3.0)
	_check(not ranged_enemy.alive or ranged_enemy.hp < ranged_enemy.max_hp, "箭矢命中并造成伤害")


func _test_house_damage() -> void:
	await _fresh()
	var refuge: Vector3 = game.island.clamp_to_walkable(Vector3(0, 0, 26))
	for i in range(game.squads.size()):
		game.squads[i].teleport(refuge + Vector3(float(i) * 1.6, 0, 0))
	await process_frame
	var house = game.houses[0]
	var hp_before: float = house.hp
	game.debug_spawn_enemy("raider", house.global_position + Vector3(2.3, 0, 0.6))
	game.debug_spawn_enemy("raider", house.global_position + Vector3(-2.1, 0, 1.0))
	_sim(4.5)
	_check(house.hp < hp_before, "海掠者接近房屋并造成伤害（%.1f → %.1f）" % [hp_before, house.hp])
	_check(house.destroyed == false, "短时间攻击未立刻摧毁房屋")
	var label_ok: bool = house._label != null and house._label.visible
	_check(label_ok, "受损房屋显示世界空间血条标签")


func _test_pause_speed() -> void:
	await _fresh()
	var t0: float = game.sim_time
	var advanced: float = game.advance(1.0)
	_check(advanced > 0.9 and game.sim_time - t0 > 0.9, "1× 推进约 1 秒")
	game.set_paused(true)
	var t1: float = game.sim_time
	game.advance(1.0)
	_check(is_equal_approx(game.sim_time, t1), "暂停时不推进模拟")
	game.set_paused(false)
	game.toggle_speed()
	_check(game.speed_mult() == 2.0, "T/按钮切到 2×")
	var t2: float = game.sim_time
	game.advance(1.0)
	_check(game.sim_time - t2 > 1.8, "2× 时模拟时间双倍推进")
	game.toggle_speed()
	_check(game.speed_mult() == 1.0, "再次切换回 1×")


func _test_permadeath() -> void:
	await _fresh()
	var squad = game.squads[1]
	for i in range(squad.members.size()):
		if bool(squad.members[i]["alive"]):
			game.damage_member(squad, i, 99999.0, "raider", squad.center, false, "")
	_sim(0.2)
	_check(not squad.alive and squad.living_count() == 0, "整队阵亡后 alive=false")
	_check(game.squads_lost == 1, "阵亡队伍计入永久损失")
	_check(not game.select_squad_index(1), "阵亡队伍无法再被选中")
	_check(game.alive_squad_count() == 2 and game.state == "playing", "仍有两队可继续作战")


func _test_defeat_houses() -> void:
	await _fresh()
	game.debug_destroy_all_houses()
	_sim(0.1)
	_check(game.state == "defeat", "全部房屋焚毁 → 失败")
	_check(game.result_reason.contains("房屋"), "失败原因写明房屋尽毁")
	_check(game.houses_alive() == 0, "房屋计数归零")


func _test_defeat_squads() -> void:
	await _fresh()
	for squad in game.squads:
		for i in range(squad.members.size()):
			if bool(squad.members[i]["alive"]):
				game.damage_member(squad, i, 99999.0, "raider", squad.center, false, "")
	_sim(0.1)
	_check(game.state == "defeat", "三队全部阵亡 → 失败")
	_check(game.result_reason.contains("小队") or game.result_reason.contains("阵亡"), "失败原因写明全队阵亡")
	_check(game.houses_alive() == 3, "失败并非因房屋（对照组）")


func _test_waves_and_victory() -> void:
	await _fresh(false)
	game.debug_set_prep(0.06)
	_sim(0.2)
	_check(game.wave_state == "active" and game.wave_number == 1, "布防倒计时结束进入第 1 波")
	_check(game.boats.size() > 0, "波次开始时生成登陆艇")
	_sim(5.6)
	_check(game.enemies.size() > 0, "登陆艇投放海掠者")
	var wave1_kills_before: int = game.kills
	game.debug_kill_enemies()
	game.debug_clear_boats()
	_sim(0.15)
	_check(game.waves_cleared == 1 and game.wave_number == 2 and game.wave_state == "prep", "清空第 1 波后进入间歇并预告第 2 波")
	_check(game.kills > wave1_kills_before, "击杀计数增加")
	game.debug_set_prep(0.06)
	_sim(0.2)
	_check(game.wave_number == 2 and game.wave_state == "active", "第 2 波开始")
	_sim(4.8)
	game.debug_kill_enemies()
	game.debug_clear_boats()
	_sim(0.15)
	_check(game.waves_cleared == 2 and game.wave_number == 3, "第 2 波清空后进入第 3 波预告")
	game.debug_set_prep(0.06)
	_sim(0.2)
	_check(game.wave_number == 3 and game.wave_state == "active", "第 3 波开始")
	_sim(5.2)
	game.debug_kill_enemies()
	game.debug_clear_boats()
	_sim(0.2)
	_check(game.state == "victory", "三波全清 → 胜利")
	_check(game.waves_cleared == 3 and game.houses_alive() == 3, "胜利结算波次与房屋数据正确")
	_check(game.result_reason != "", "胜利结算有文本原因")


func _test_next_island_and_restart() -> void:
	await _fresh()
	var archer = game.squads[1]
	for i in range(archer.members.size()):
		if bool(archer.members[i]["alive"]):
			game.damage_member(archer, i, 99999.0, "raider", archer.center, false, "")
	_sim(0.1)
	game.debug_mark_waves_done()
	_check(game.state == "victory", "残编队伍清空波次后仍可胜利")
	_check(game.has_next_island(), "第 1 岛后有下一岛")
	game.advance_island()
	await process_frame
	await process_frame
	_check(game.island_index == 1 and game.waves_total == 4, "进入第 2 岛（4 波）")
	_check(game.squads.size() == 2, "阵亡队伍不会进入下一岛")
	_check(game.alive_squad_count() == 2 and game.houses_alive() == 3, "幸存队伍补员并重置房屋")
	var classes: Array = []
	for squad in game.squads:
		classes.append(squad.class_id)
	_check(not classes.has("archer"), "兵种永久损失：弓手队不复活")
	game.restart_run()
	await process_frame
	await process_frame
	_check(game.island_index == 0 and game.state == "playing", "重开后回到第 1 岛并进入布防")
	_check(game.squads.size() == 3 and game.alive_squad_count() == 3, "重开后三队恢复")
	_check(game.houses_alive() == 3 and game.waves_cleared == 0 and game.wave_number == 1, "重开后房屋 / 波次重置")
	_check(game.speed_index == 0 and not game.paused, "重开后恢复 1× 且未暂停")
