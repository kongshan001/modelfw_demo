extends SceneTree

## Legionfall headless smoke test.
## Run: godot --headless --path godot-legion-td -s tools/smoke_legion_td.gd
## Last line: LEGION_TD_SMOKE_OK

const D := preload("res://scripts/legion_data.gd")
const Game := preload("res://scripts/legion_game.gd")

var game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS  ", label, (("  [" + detail + "]") if detail != "" else ""))
	else:
		failures += 1
		printerr("FAIL  ", label, (("  [" + detail + "]") if detail != "" else ""))


func _run() -> void:
	game = Game.new()
	root.add_child(game)
	for i in 3:
		await process_frame

	_test_boot()
	_test_selection()
	_test_move()
	_test_recruit()
	_test_tower()
	_test_combat()
	_test_waves()
	_test_core_and_restart()
	_test_hero()
	_test_roguelike_effects()
	_test_box_select_and_time()
	await _test_ui_click()

	print("SMOKE_CHECKS=", checks, " FAILURES=", failures)
	if failures == 0:
		print("LEGION_TD_SMOKE_OK")
		quit(0)
	else:
		printerr("LEGION_TD_SMOKE_FAILED checks=%d failures=%d" % [checks, failures])
		quit(1)


func _fresh(seed_value: int = 20261127) -> void:
	game.start_run(seed_value)
	game.simulate(0.02)


func _test_boot() -> void:
	check(game.world != null and game.ui != null, "世界与 HUD 已创建")
	check(game.units.size() == 4, "初始 4 个单位", "units=%d" % game.units.size())
	check(game.hero != null and game.hero.is_hero, "初始 1 位英雄")
	check(game.ui_state == "prep", "开局为准备阶段")
	check(game.core_hp == 100.0 and game.gold == 300, "核心 100 / 金币 300")
	check(game.selected_units.size() == 4, "开局全选初始小队")
	check(D.WAVES.size() == 6, "6 波配置")
	check(D.TOWERS.size() == 3 and D.UNITS.size() == 4, "3 塔 + 4 角色（含英雄）")


func _test_selection() -> void:
	_fresh()
	game.select_single_index(0)
	check(game.selected_units.size() == 1, "单选 1 个单位")
	game.select_all_units()
	check(game.selected_units.size() == 4, "全选 4 个单位")
	game.clear_selection()
	check(game.selected_units.is_empty(), "清空选择")
	game.select_pad(0)
	check(game.selected_pad_index == 0, "选中建造点")
	game.select_barracks()
	check(game.barracks_selected, "选中兵营")


func _test_move() -> void:
	_fresh()
	var u = game.units[0]
	game.select_single_index(0)
	var target: Vector3 = game.clamp_to_land(u.global_position + Vector3(4, 0, -3))
	game.command_move(target)
	game.simulate(0.6)
	check(u.global_position.distance_to(target) < 3.4, "右键移动响应",
		"d=%.2f" % u.global_position.distance_to(target))
	game.stop_selected()
	check(u.state == 0, "停止指令清空移动")


func _test_recruit() -> void:
	_fresh()
	var gold: int = game.gold
	var n: int = game.units.size()
	check(game.recruit("guard"), "招募灰烬卫士")
	check(game.units.size() == n + 1, "招募后单位 +1")
	check(game.gold == gold - int(D.UNITS.guard.cost), "招募扣除金币")
	check(float(game.cooldowns.guard) > 0.0, "招募进入冷却")
	check(not game.recruit("hero"), "英雄不可重复招募")
	game.cooldowns.guard = 0.0
	game.pop_cap = game.pop_used
	check(not game.recruit("guard"), "人口满时拒绝招募")
	game.pop_cap = D.START_POP_CAP
	game.gold = 0
	game.cooldowns.guard = 0.0
	check(not game.recruit("guard"), "金币不足时拒绝招募")


func _test_tower() -> void:
	_fresh()
	game.debug_add_resources(800, 80)
	game.select_pad(0)
	var gold: int = game.gold
	check(game.build_tower_at_selected("prism"), "建造棱镜塔")
	check(game.towers.size() == 1, "塔列表 +1")
	check(game.gold == gold - int(D.TOWERS.prism.cost), "建塔扣除金币")
	var tower = game.towers[0]
	check(tower.level == 1, "塔初始 Lv1")
	check(game.upgrade_selected_tower(), "升级塔")
	check(tower.level == 2 and tower.effective_damage() > float(D.TOWERS.prism.damage),
		"塔升级后伤害提高")
	var sv: Array = tower.sell_value()
	var gold_before: int = game.gold
	check(game.sell_selected_tower(), "出售塔")
	check(game.towers.is_empty() and game.gold == gold_before + int(sv[0]), "出售返还金币")
	check(game.world.pads[0].tower == null, "建造点恢复可用")
	# 建造点不可重复建造
	game.select_pad(1)
	game.build_tower_at_selected("frost")
	game.select_pad(1)
	check(not game.build_tower_at_selected("prism"), "已有塔的建造点拒绝重复建造")
	game.select_pad(2)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_2
	game._handle_key(ev)
	check(game.towers.size() == 2 and game.towers[-1].kind == "mortar", "建造面板 1/2/3 快捷键建塔")


func _test_combat() -> void:
	_fresh()
	game.debug_add_resources(800, 80)
	game.select_pad(3)
	game.build_tower_at_selected("prism")
	game.clear_selection()
	var enemy = game.debug_spawn_enemy("crawler", 0, Vector3(18, 0, 9), 1.0, 1.0, 1.0)
	var hp0: float = enemy.hp
	game.simulate(2.0)
	check(enemy.hp < hp0 or enemy.dead, "塔自动索敌造成伤害", "hp %.0f -> %.0f" % [hp0, enemy.hp])
	# 玩家自动索敌
	_fresh()
	var dummy = game.debug_spawn_enemy("crawler", 0, game.hero.global_position + Vector3(2.5, 0, 0),
		4.0, 0.2, 0.0)
	var hp1: float = dummy.hp
	game.select_single_index(3)
	game.simulate(1.5)
	check(dummy.hp < hp1, "待命单位自动交战", "hp %.0f -> %.0f" % [hp1, dummy.hp])
	# 攻击移动
	_fresh()
	var ranged = game.debug_spawn_unit("bolt", Vector3(-2, 0, 18))
	var target = game.debug_spawn_enemy("crawler", 0, Vector3(5, 0, 18), 3.0, 0.2, 0.0)
	game.clear_selection()
	game.selected_units.append(ranged)
	ranged.set_selected(true)
	game.command_attack_move(Vector3(7, 0, 18))
	var hp2: float = target.hp
	game.simulate(2.0)
	check(target.hp < hp2, "攻击移动沿途交火", "hp %.0f -> %.0f" % [hp2, target.hp])
	# 敌人攻核心（清场隔离，避免被玩家单位先手）
	_fresh()
	for u in game.units.duplicate():
		u.queue_free()
	game.units.clear()
	game.hero = null
	game.selected_units.clear()
	var core_hp: float = game.core_hp
	game.debug_spawn_enemy("colossus", 0, Vector3(0, 0, 30), 1.0, 1.0, 1.0)
	game.simulate(2.0)
	check(game.core_hp < core_hp, "敌人抵达后伤害核心", "core %.0f -> %.0f" % [core_hp, game.core_hp])


func _test_waves() -> void:
	_fresh()
	game.debug_start_wave(1)
	check(game.ui_state == "wave" and game.wave_index == 1, "第 1 波开始")
	game.simulate(1.0)
	check(game.enemies.size() > 0, "敌人已生成", "enemies=%d" % game.enemies.size())
	game.debug_kill_all()
	game.simulate(1.4)
	check(game.ui_state == "upgrade", "清波后进入三选一")
	check(game.upgrade_choices.size() == 3, "提供 3 个强化")
	if game.upgrade_choices.is_empty():
		return
	check(game.reroll_upgrades(), "重掷强化")
	check(game.rerolls_left == 0, "重掷次数扣除")
	check(game.upgrade_choices.size() == 3, "重掷仍为 3 选 1")
	var picked: String = game.upgrade_choices[0]
	check(game.pick_upgrade(0), "选择强化")
	check(int(game.upgrade_levels.get(picked, 0)) == 1, "强化等级 +1", picked)
	check(game.ui_state == "prep", "选择后回到准备阶段")
	check(game.wave_index == 1, "波次计数保留")
	# 多入口 / 修饰
	_fresh()
	game.debug_start_wave(4)
	check(game.modifier.size() > 0, "第 4 波有修饰", String(game.modifier.get("name", "")))
	var lanes := {}
	for s in game.spawn_queue:
		lanes[int(s.lane)] = true
	check(lanes.size() >= 2, "多入口波次", "lanes=%s" % str(lanes.keys()))
	# 最终波清空直接胜利
	_fresh()
	game.debug_start_wave(6)
	game.debug_kill_all()
	game.simulate(1.4)
	check(game.ui_state == "win", "最终波清空即胜利")


func _test_core_and_restart() -> void:
	_fresh(424242)
	check(game.seed_value == 424242, "run seed 生效")
	game.damage_core(101.0)
	check(game.ui_state == "lose" and game.core_hp == 0.0, "核心归零判负")
	game.restart_run(777)
	check(game.seed_value == 777 and game.core_hp == 100.0, "重开恢复核心与种子")
	check(game.units.size() == 4 and game.towers.is_empty(), "重开重置单位与塔")
	check(game.ui_state == "prep" and game.wave_index == 0, "重开回到第 1 波准备")
	game.debug_win()
	check(game.ui_state == "win", "调试胜利")
	game.restart_run()
	check(game.ui_state == "prep" and game.core_hp == 100.0, "胜利后可重开")


func _test_hero() -> void:
	_fresh()
	var enemy = game.debug_spawn_enemy("crawler", 0, game.hero.global_position + Vector3(2.0, 0, 0),
		2.0, 0.1, 0.0)
	var hp: float = enemy.hp
	check(game.hero_skill(), "英雄技能可用")
	check(game.hero.skill_cd > 0.0, "技能进入冷却")
	check(enemy.hp < hp, "技能造成范围伤害", "hp %.0f -> %.0f" % [hp, enemy.hp])
	check(not game.hero_skill(), "冷却中不可再次施放")
	game.hero.skill_cd = 0.0
	game.hero.hp = 0.0
	game.hero.die(true)
	check(game.hero == null and game.hero_respawn_t > 0.0, "英雄阵亡进入复活计时")
	game.simulate(D.HERO_RESPAWN + 0.2)
	check(game.hero != null and game.hero.is_alive(), "英雄按时复活")


func _test_roguelike_effects() -> void:
	# 生命强化：已存在单位立刻补血，新招募单位也继承新上限。
	_fresh()
	game.upgrade_choices.clear()
	game.upgrade_choices.append("vigor")
	game.upgrade_choices.append("train")
	game.upgrade_choices.append("range")
	game.ui_state = "upgrade"
	check(game.pick_upgrade(0), "选择坚韧战团")
	var guard = game.units[0]
	check(is_equal_approx(guard.max_hp, float(D.UNITS.guard.hp) * 1.18),
		"坚韧战团立即提高单位上限", "hp=%.1f" % guard.max_hp)
	game.debug_add_resources(100, 0)
	game.cooldowns.guard = 0.0
	game.pop_cap = 99
	game.recruit("guard")
	var fresh_unit = game.units[-1]
	check(is_equal_approx(fresh_unit.max_hp, float(D.UNITS.guard.hp) * 1.18),
		"强化后新招募单位继承生命上限", "hp=%.1f" % fresh_unit.max_hp)
	# 暮霜附魔：棱镜塔命中也会施加减速。
	_fresh()
	game.upgrade_levels["frost"] = 1
	game._recompute_stats()
	game.debug_add_resources(300, 40)
	game.select_pad(4)
	game.build_tower_at_selected("prism")
	game.clear_selection()
	var enemy = game.debug_spawn_enemy("crawler", 0, Vector3(-9, 0, 4), 6.0, 0.1, 0.0)
	game.simulate(2.0)
	check(enemy.slow_t > 0.0 and enemy.slow_pct > 0.0, "暮霜附魔对棱镜塔生效",
		"slow=%.2f t=%.2f" % [enemy.slow_pct, enemy.slow_t])
	# 扩编令增加人口上限。
	_fresh()
	game.upgrade_levels["pop"] = 1
	game._recompute_stats()
	check(game.pop_cap == D.START_POP_CAP + 4, "扩编令提高人口上限")
	# 重开清空强化。
	game.restart_run(555)
	check(game.upgrade_levels.is_empty() and game.stats.unit_hp == 1.0, "重开清空强化")


func _test_box_select_and_time() -> void:
	_fresh()
	game.clear_selection()
	var rect := Rect2()
	var first := true
	for u in game.units:
		var sp: Vector2 = game.world.world_to_screen(u.global_position + Vector3(0, 0.8, 0))
		if first:
			rect = Rect2(sp - Vector2(30, 40), Vector2(60, 80))
			first = false
		else:
			rect = rect.expand(sp + Vector2(30, 40))
			rect = rect.expand(sp - Vector2(30, 40))
	game._box_select(rect)
	check(game.selected_units.size() == 4, "矩形框选命中初始小队",
		"n=%d" % game.selected_units.size())
	game.toggle_speed()
	check(is_equal_approx(game.speed, 2.0), "Tab 切换到 2×")
	game.toggle_speed()
	check(is_equal_approx(game.speed, 1.0), "再次切换回 1×")
	game.toggle_pause()
	check(game.paused, "Space 暂停")
	game.toggle_pause()
	check(not game.paused, "Space 继续")


func _test_ui_click() -> void:
	_fresh()
	game.ui.queue_redraw()
	await process_frame
	await process_frame
	check(game.ui._buttons.size() > 0, "HUD 生成可点击按钮", "n=%d" % game.ui._buttons.size())
	var target: Dictionary = {}
	for b in game.ui._buttons:
		if b.id == "recruit:guard":
			target = b
			break
	check(not target.is_empty(), "找到招募按钮")
	if not target.is_empty():
		var n: int = game.units.size()
		game.ui.handle_click(target.rect.get_center())
		check(game.units.size() == n + 1, "点击招募卡立即出兵")
	# 暂停 / 速度按钮走同一条 HUD 点击路径。
	for b in game.ui._buttons:
		if b.id == "pause":
			game.ui.handle_click(b.rect.get_center())
			break
	check(game.paused, "HUD 暂停按钮生效")
	for b in game.ui._buttons:
		if b.id == "pause":
			game.ui.handle_click(b.rect.get_center())
			break
	check(not game.paused, "HUD 继续按钮生效")
