extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const RulesScript = preload("res://scripts/raid_rules.gd")
const ChestScript = preload("res://scripts/loot_chest.gd")
const ItemsScript = preload("res://scripts/items.gd")

const TEST_SAVE := "user://fog_harbor_smoke_save.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	print("— 物品表 —")
	_test_items()
	print("— 背包 —")
	_test_inventory()
	print("— 补给箱 / 掉落 —")
	_test_chests()
	print("— 撤离规则 —")
	_test_rules()
	print("— 仓库 / 升级 / 存档 —")
	_test_state()
	print("— 整场景：搜箱 / 战斗 / AI / 结算 —")
	await _test_scene()
	_cleanup()
	print("checks=%d failures=%d" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("FOG_HARBOR_SMOKE_OK")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS  " + message)
	else:
		_failures.append(message)
		printerr("FAIL  " + message)


func _cleanup() -> void:
	var path := ProjectSettings.globalize_path(TEST_SAVE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _new_state() -> GameStateScript:
	var gs := GameStateScript.new(TEST_SAVE)
	gs.reset()
	return gs


func _test_items() -> void:
	_check(ItemsScript.all_ids().size() == 8, "共 8 类战利品")
	var ids_ok := true
	var fields_ok := true
	for id in ItemsScript.all_ids():
		var item := ItemsScript.get_item(id)
		if item.is_empty():
			ids_ok = false
			continue
		for key in ["name", "rarity", "value", "stack_max", "grid", "kind", "desc"]:
			if not item.has(key):
				fields_ok = false
		if int(item["rarity"]) < 0 or int(item["rarity"]) > 3:
			fields_ok = false
		if int(item["value"]) <= 0 or int(item["stack_max"]) <= 0:
			fields_ok = false
		var grid: Vector2i = item["grid"]
		if grid.x <= 0 or grid.y <= 0:
			fields_ok = false
	_check(ids_ok and fields_ok, "物品 id 唯一可查，价值/稀有度/堆叠/占格字段有效")
	_check(ItemsScript.get_item("black_box")["grid"] == Vector2i(2, 2), "黑匣子占 2×2")
	_check(ItemsScript.get_item("precision_rig")["grid"] == Vector2i(2, 1), "精密仪器占 2×1")
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 4242
	rng_b.seed = 4242
	var loot_a := ItemsScript.roll_chest(rng_a, 0)
	var loot_b := ItemsScript.roll_chest(rng_b, 0)
	_check(JSON.stringify(loot_a) == JSON.stringify(loot_b), "同 seed 的箱子掉落完全一致")
	var loot_valid := loot_a.size() >= 2 and loot_a.size() <= 4
	for entry in loot_a:
		if ItemsScript.get_item(String(entry["id"])).is_empty() or int(entry["count"]) <= 0:
			loot_valid = false
	_check(loot_valid, "普通箱 2–3 抽，条目 id/数量合法")
	var elite_ok := true
	for seed_value in range(1, 13):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var loot := ItemsScript.roll_chest(rng, 1)
		var best := -1
		for entry in loot:
			best = maxi(best, int(ItemsScript.get_item(String(entry["id"]))["rarity"]))
		if best < 2:
			elite_ok = false
	_check(elite_ok, "精英箱保底至少一件稀有物资（12 个 seed）")
	_check(String(ItemsScript.get_item("old_script")["kind"]) == "currency", "旧港币标记为货币")


func _test_inventory() -> void:
	var inv := InventoryScript.new(6, 4)
	_check(inv.capacity_cells() == 24, "背包 6×4 = 24 格")
	var got := inv.add_item("old_script", 10)
	_check(got == 10 and inv.entries.size() == 2, "堆叠上限 8：10 张旧港币拆成两堆")
	_check(int(inv.entries[0]["count"]) + int(inv.entries[1]["count"]) == 10, "堆叠总数正确")
	var inv_full := InventoryScript.new(6, 4)
	var placed := 0
	for i in range(7):
		placed += inv_full.add_item("black_box", 1)
	_check(placed == 6 and inv_full.cells_used() == 24, "6 个 2×2 黑匣子占满 24 格，第 7 个被拒")
	_check(inv_full.add_item("medkit", 1) == 0, "满背包拒绝 1×1 物品")
	var inv_grid := InventoryScript.new(6, 4)
	inv_grid.add_item("black_box", 1)
	inv_grid.add_item("precision_rig", 1)
	_check(inv_grid.entries.size() == 2 and int(inv_grid.entries[1]["x"]) == 2 and int(inv_grid.entries[1]["y"]) == 0,
		"2×1 精密仪器绕过 2×2 占位，落在 (2,0)")
	var inv_use := InventoryScript.new(6, 4)
	inv_use.add_item("medkit", 2)
	var use_result := inv_use.use_at(0)
	_check(bool(use_result.get("ok", false)) and int(use_result.get("heal", 0)) == 45, "医疗包使用回复 45")
	_check(int(inv_use.entries[0]["count"]) == 1, "使用后数量 -1")
	var inv_drop := InventoryScript.new(6, 4)
	inv_drop.add_item("fog_crystal", 2)
	var dropped := inv_drop.drop_at(0)
	_check(String(dropped.get("id", "")) == "fog_crystal" and inv_drop.entries.is_empty(), "丢弃移除整组")
	var before := inv.entries.size()
	inv.remove_at(0, 3)
	_check(inv.entries.size() == before and int(inv.entries[0]["count"]) == 5, "部分移除保留剩余堆叠")
	var inv_loot := InventoryScript.new(6, 4)
	var transfer := inv_loot.add_loot([
		{"id": "fog_crystal", "count": 1},
		{"id": "black_box", "count": 1},
		{"id": "black_box", "count": 1},
		{"id": "black_box", "count": 1},
		{"id": "black_box", "count": 1},
		{"id": "black_box", "count": 1},
		{"id": "black_box", "count": 1},
	])
	_check(transfer["added"].size() >= 2 and transfer["missed"].size() >= 1, "add_loot 区分放入与未放入")


func _test_chests() -> void:
	var chest := ChestScript.new()
	chest.configure("smoke", Vector2(100, 100), 0, 9)
	var chest_b := ChestScript.new()
	chest_b.configure("smoke", Vector2(100, 100), 0, 9)
	_check(JSON.stringify(chest.loot) == JSON.stringify(chest_b.loot), "箱子 loot 由 index/seed 确定性生成")
	_check(chest.loot_count() >= 2, "新箱子至少 2 件物资（含堆叠）")
	var inv := InventoryScript.new(6, 4)
	var result := chest.search_instant(inv)
	_check(String(result.get("state", "")) == "searched", "搜索完成返回 searched")
	_check(bool(result.get("first", false)), "首次搜索标记 first=true")
	_check(inv.entries.size() >= 1, "战利品进入背包")
	_check(chest.is_empty(), "箱内物资全部转移后为空")
	var result_again := chest.search_instant(inv)
	_check(String(result_again.get("state", "")) == "empty", "空箱再次搜索返回 empty")
	var full := InventoryScript.new(6, 4)
	for i in range(6):
		full.add_item("black_box", 1)
	var chest_full := ChestScript.new()
	chest_full.configure("full", Vector2.ZERO, 1, 12)
	var full_result := chest_full.search_instant(full)
	_check(String(full_result.get("state", "")) == "searched" and not chest_full.is_empty(),
		"背包满时搜索完成但物资留在箱内")
	_check(full_result["missed"].size() >= 1, "返回 missed 列表")
	chest.free()
	chest_b.free()
	chest_full.free()


func _test_rules() -> void:
	var rules := RulesScript.new()
	rules.reset()
	_check(not rules.active and rules.time_left() == 360.0, "初始 6:00，撤离点未激活")
	var events := rules.tick(119.9, false)
	_check(not rules.active and not events["activated"], "119.9 秒时仍未激活")
	events = rules.tick(0.2, false)
	_check(rules.active and events["activated"], "满 120 秒激活撤离点")
	events = rules.tick(1.5, true)
	_check(is_equal_approx(rules.progress, 1.5), "站入 1.5 秒进度 1.5")
	rules.tick(0.1, false)
	_check(is_equal_approx(rules.progress, 0.0), "离开撤离圈进度清零")
	events = rules.tick(3.05, true)
	_check(bool(events.get("extracted", false)) and rules.finished and rules.success, "连续站入 3 秒撤离成功")
	var rules2 := RulesScript.new()
	rules2.reset()
	_check(not rules2.register_chest_search(), "第 1 个箱子不激活")
	_check(rules2.register_chest_search(), "第 2 个箱子激活撤离点")
	rules2.tick(0.1, false)
	_check(rules2.active, "搜箱激活状态保持")
	var rules3 := RulesScript.new()
	rules3.reset()
	var timeout := rules3.tick(360.0, false)
	_check(bool(timeout.get("timeout", false)) and rules3.finished and not rules3.success, "6 分钟耗尽判定失败")
	_check(RulesScript.EXTRACT_HOLD == 3.0, "撤离需站入 3 秒")


func _test_state() -> void:
	var gs := _new_state()
	_check(gs.credits == 0 and gs.warehouse.is_empty(), "新存档为空")
	_check(gs.warehouse_capacity() == 24, "初始仓库 24 格")
	_check(gs.weapon_damage() == 18 and gs.starting_medkits() == 1, "初始伤害 18 / 医疗包 1")
	gs.add_credits(1000)
	var credits_before := gs.credits
	_check(gs.buy_upgrade("warehouse") and gs.warehouse_capacity() == 30, "仓库升级 +6 格")
	_check(gs.credits == credits_before - 120, "仓库升级扣 120 信用点")
	_check(gs.buy_upgrade("medkit") and gs.starting_medkits() == 2, "医疗包升级 → 每局 2 个")
	_check(gs.buy_upgrade("damage") and gs.weapon_damage() == 21, "武器校准 → 伤害 21")
	_check(gs.upgrade_cost("damage") == 240, "第二级伤害升级价格 240")
	_check(gs.buy_upgrade("damage") and gs.weapon_damage() == 24, "第二次武器校准 → 伤害 24")
	gs.credits = 0
	gs.save()
	_check(not gs.buy_upgrade("damage"), "信用点不足时拒绝升级")
	var inv := InventoryScript.new(6, 4)
	inv.add_item("old_script", 8)
	inv.add_item("fog_crystal", 2)
	inv.add_item("black_box", 1)
	var warehouse_before := gs.warehouse.size()
	var credits_2 := gs.credits
	var transfer := gs.transfer_loot(inv)
	_check(int(transfer["currency_credits"]) == 160, "撤离：8 张旧港币兑换 160 信用点")
	_check(gs.credits == credits_2 + 160, "信用点已入账")
	_check(gs.warehouse.size() == warehouse_before + 2, "非货币物资按堆叠入库")
	_check(inv.entries.is_empty(), "撤离后背包清空")
	var gs2 := GameStateScript.new(TEST_SAVE)
	_check(gs2.load_save(), "存档可读回")
	_check(gs2.credits == gs.credits and gs2.warehouse_capacity() == gs.warehouse_capacity(), "重开后信用点/仓库容量保留")
	_check(gs2.upgrade_level("warehouse") == 1 and gs2.upgrade_level("damage") == 2, "重开后升级等级保留")
	var before_slots := gs2.warehouse.size()
	var before_credits := gs2.credits
	var before_upgrades := gs2.upgrades.duplicate()
	var inv_lost := InventoryScript.new(6, 4)
	inv_lost.add_item("black_box", 1)
	inv_lost.add_item("old_script", 4)
	var lost := gs2.lose_run(inv_lost)
	_check(int(lost["count"]) == 5 and inv_lost.entries.is_empty(), "阵亡：当局背包清空（5 件）")
	_check(gs2.warehouse.size() == before_slots and gs2.credits == before_credits, "阵亡不改变仓库与信用点")
	_check(gs2.upgrades == before_upgrades, "阵亡不改变升级")
	_check(int(gs2.stats.get("deaths", 0)) == 1, "阵亡统计 +1")
	var overflow_state := _new_state()
	overflow_state.add_credits(500)
	var fill := overflow_state.add_to_warehouse("brass_parts", 3000)
	_check(overflow_state.warehouse.size() == 24 and int(fill["overflow"]) > 0, "仓库满后按格拒绝新堆叠")
	_check(int(fill["overflow_credits"]) > 0, "溢出物资自动折现")
	var sell_state := _new_state()
	sell_state.add_to_warehouse("fog_crystal", 2)
	var value := sell_state.warehouse_value()
	var gained := sell_state.sell_all_warehouse()
	_check(gained == value and sell_state.warehouse.is_empty(), "回收全部物资获得等价信用点")
	_cleanup()


func _test_scene() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.demo_use_save_path(TEST_SAVE)
	main.demo_reset_state()
	main.demo_start_raid()
	await process_frame
	_check(main.demo_get_mode() == "raid", "主场景进入行动")
	_check(main.demo_get_chests().size() == 9, "地图生成 9 个补给箱")
	_check(main.demo_get_enemies().size() == 8, "地图生成 8 个敌人（3 archetype）")
	var archetypes := {}
	for enemy in main.demo_get_enemies():
		archetypes[enemy.archetype] = true
	_check(archetypes.has("lurker") and archetypes.has("gunner") and archetypes.has("elite"), "敌人包含潜伏者/枪手/精英")
	var player = main.demo_get_player()
	var inv = main.demo_get_inventory()
	_check(player != null and inv != null, "玩家与背包已创建")
	_check(inv.total_count() == 1, "初始携带 1 个医疗包")
	_check(main.demo_get_rules().time_left() > 359.0, "HUD 初始倒计时接近 6:00")

	# 搜箱：主场景 API 完成两次搜索应激活撤离点
	var chest_count_before: int = main.demo_get_chests()[0].loot_count()
	var result: Dictionary = main.demo_search_chest(0, 1.0)
	_check(String(result.get("state", "")) == "searched", "主场景搜箱完成")
	_check(main.demo_get_chests()[0].loot_count() < chest_count_before or main.demo_get_chests()[0].is_empty(),
		"搜箱后箱内物资减少")
	main.demo_search_chest(1, 1.0)
	_check(main.demo_get_rules().active, "搜完 2 个箱子激活撤离点")
	_check(main.demo_get_rules().chests_searched == 2, "搜箱计数 2")

	# 玩家射击命中敌人
	var enemy0 = main.demo_get_enemies()[0]
	main.demo_teleport(Vector2(960, 720))
	enemy0.global_position = Vector2(1180, 620)
	await physics_frame
	enemy0.global_position = Vector2(1180, 620)
	await physics_frame
	var hp_before: int = enemy0.hp
	player.demo_fire_at(enemy0.global_position)
	await physics_frame
	_check(enemy0.hp < hp_before, "玩家 hitscan 命中扣血（%d → %d）" % [hp_before, enemy0.hp])
	_check(enemy0.state_name() == "STAGGER" or enemy0.state_name() == "CHASE" or enemy0.state_name() == "ATTACK",
		"敌人受击进入硬直/反应状态")

	# 近战敌人 AI：靠近 → 发现 → 追击；强制攻击造成伤害
	var lurker = main.demo_get_enemies()[7]
	lurker.global_position = Vector2(600, 870)
	main.demo_teleport(Vector2(600, 760))
	await _await_physics(10)
	_check(lurker.state_name() != "PATROL", "潜伏者发现玩家进入 ALERT/CHASE")
	await _await_physics(26)
	_check(lurker.state_name() == "CHASE" or lurker.state_name() == "ATTACK", "发现后切换追击")
	player.hp = 100.0
	player.invuln = 0.0
	lurker.global_position = player.global_position + Vector2(32, 0)
	lurker.demo_force_attack("melee")
	await _await_physics(2)
	_check(player.hp < 100.0, "近战攻击命中玩家（HP %.0f）" % player.hp)
	var hp_before_stagger: int = lurker.hp
	lurker.take_damage(10, Vector2.RIGHT)
	_check(lurker.hp == hp_before_stagger - 10 and lurker.state_name() == "STAGGER", "敌人受击硬直并掉血")
	var kills_before: int = main.kills
	lurker.take_damage(999, Vector2.RIGHT)
	await _await_physics(2)
	_check(lurker.dead and lurker.state_name() == "DEAD", "敌人死亡状态")
	_check(main.kills == kills_before + 1, "击杀计数 +1")

	# 背包打开暂停世界
	main.demo_open_backpack()
	await process_frame
	_check(paused, "打开背包暂停世界")
	main.demo_close_backpack()
	await process_frame
	_check(not paused, "关闭背包恢复世界")

	# 真实输入：E 搜箱、WASD、Shift 冲刺、鼠标射击、R 换弹
	main.demo_set_god(true)
	main.demo_teleport(Vector2(1260, 672))
	player.invuln = 0.0
	var input_count_before: int = inv.total_count()
	var searched_before: int = main.demo_get_rules().chests_searched
	_key(KEY_E, true)
	await _await_physics(72)
	_key(KEY_E, false)
	await physics_frame
	_check(main.demo_get_rules().chests_searched > searched_before, "按住 E 实际完成搜箱")
	_check(inv.total_count() > input_count_before or main.demo_get_chests()[2].is_empty(), "E 搜箱把物资放入背包")
	var move_x0: float = player.global_position.x
	_key(KEY_D, true)
	await _await_physics(12)
	_key(KEY_D, false)
	await physics_frame
	_check(player.global_position.x > move_x0 + 5.0, "WASD 移动（D 键）")
	_key(KEY_D, true)
	_key(KEY_SHIFT, true)
	await _await_physics(3)
	_key(KEY_SHIFT, false)
	await _await_physics(4)
	_key(KEY_D, false)
	_check(player.dash_cooldown > 0.0, "Shift 冲刺进入冷却")
	player.reloading = false
	player.mag = 12
	var mag_before: int = player.mag
	_mouse_click(true)
	await _await_physics(5)
	_mouse_click(false)
	await physics_frame
	_check(player.mag < mag_before, "鼠标左键射击消耗弹药")
	player.reloading = false
	player.reload_timer = 0.0
	player.mag = 2
	player.reserve = 96
	player.control_enabled = true
	_key(KEY_R, false)
	await _await_physics(1)
	var reload_started := false
	for _attempt in range(3):
		if player.reloading:
			reload_started = true
			break
		player.mag = mini(player.mag, 2)
		_key(KEY_R, true)
		await _await_physics(4)
		_key(KEY_R, false)
		if player.reloading:
			reload_started = true
			break
		await _await_physics(2)
	_check(reload_started, "R 触发换弹")
	for _i in range(120):
		await physics_frame
		if not player.reloading:
			break
	_check(player.mag == 12 and player.reserve < 96, "换弹完成并消耗备弹")
	main.demo_set_god(false)

	# 阵亡结算：当局物资丢失，仓库/升级/信用点不变
	main.demo_add_demo_loot()
	var state = main.demo_get_state()
	var wh_before: int = state.warehouse.size()
	var credits_before: int = state.credits
	var upgrades_before: Dictionary = state.upgrades.duplicate(true)
	var carried_before: int = inv.total_count()
	_check(carried_before > 1, "阵亡前背包有物资")
	main.demo_set_god(false)
	player.demo_god = false
	player.invuln = 0.0
	player.take_damage(999, Vector2.RIGHT)
	await process_frame
	_check(player.dead, "玩家 HP 归零触发死亡")
	_check(main.demo_get_mode() == "result", "阵亡进入结算")
	_check(main.demo_get_result() != null, "结算页创建")
	_check(inv.entries.is_empty(), "阵亡后当局背包清空")
	_check(state.warehouse.size() == wh_before and state.credits == credits_before, "阵亡不动仓库与信用点")
	_check(state.upgrades == upgrades_before, "阵亡不动升级")

	# 撤离结算：物资入库 + 旧港币换钱
	main.demo_start_raid()
	await process_frame
	await process_frame
	main.demo_add_loot([
		{"id": "old_script", "count": 5},
		{"id": "fog_crystal", "count": 1},
		{"id": "precision_rig", "count": 1},
	])
	var state2 = main.demo_get_state()
	var credits_before2: int = state2.credits
	var wh_before2: int = state2.warehouse.size()
	main.demo_finish(true, "撤离成功")
	await process_frame
	_check(main.demo_get_mode() == "result", "撤离成功进入结算")
	_check(state2.credits >= credits_before2 + 100, "撤离把旧港币兑换成信用点")
	_check(state2.warehouse.size() > wh_before2, "撤离把物资转入仓库")
	var reloaded := GameStateScript.new(TEST_SAVE)
	_check(reloaded.load_save(), "撤离后存档可读")
	_check(reloaded.credits == state2.credits and reloaded.warehouse.size() == state2.warehouse.size(),
		"重开后信用点与仓库一致")
	_check(reloaded.upgrades == state2.upgrades, "重开后升级一致")

	# 撤离后再次部署：升级带来的初始医疗包生效
	main.demo_start_raid()
	await process_frame
	await process_frame
	_check(main.demo_get_inventory().total_count() == main.demo_get_state().starting_medkits(),
		"再次部署按升级携带初始医疗包")
	main.show_base()
	await process_frame
	_check(main.demo_get_mode() == "base", "返回基地")
	main.free()
	await process_frame


func _await_physics(count: int) -> void:
	for _i in range(count):
		await physics_frame


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _mouse_click(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(900, 300)
	event.global_position = Vector2(900, 300)
	event.pressed = pressed
	Input.parse_input_event(event)
