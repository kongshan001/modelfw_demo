extends RefCounted

func _find(events: Array[BattleEvent], type: StringName, source: String) -> BattleEvent:
	for event in events:
		if event.type == type and String(event.source_id) == source:
			return event
	return null

func _has_skill_event(events: Array[BattleEvent], source: String, skill_id: String) -> bool:
	return _find_skill_action(events, source, skill_id) != null

func _find_skill_action(events: Array[BattleEvent], source: String, skill_id: String) -> BattleEvent:
	for event in events:
		if String(event.source_id) != source:
			continue
		if event.type == &"action_start" and String(event.data.get("skill_id", "")) == skill_id:
			return event
	return null

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()
	var encounter := content.get_encounter(&"enc_bamboo_01")

	var slow_state := BattleState.new()
	var fast_data := UnitData.new()
	fast_data.id = &"fast"; fast_data.max_hp = 100; fast_data.max_mp = 0; fast_data.speed = 200
	var slow_data := UnitData.new()
	slow_data.id = &"slow"; slow_data.max_hp = 100; slow_data.max_mp = 0; slow_data.speed = 100
	slow_state.units.append(BattleUnitState.new(fast_data, BattleTypes.Side.ALLY, 0))
	slow_state.units.append(BattleUnitState.new(slow_data, BattleTypes.Side.ENEMY, 0))
	var chance_resolver := BattleResolver.new(slow_state, BattleRng.new(1), content)
	chance_resolver._roll_speeds()
	t.in_range(chance_resolver.compute_flee_chance(), 0.5, 0.9, "逃跑概率被限制在 50%~90%")
	chance_resolver._speed_rolls = {&"fast": 125.0, &"slow": 100.0}
	t.near(chance_resolver.compute_flee_chance(), 0.7, 0.0001, "逃跑概率按速度差精确计算")
	chance_resolver._speed_rolls = {&"fast": 50.0, &"slow": 100.0}
	t.near(chance_resolver.compute_flee_chance(), 0.5, 0.0001, "逃跑概率下限精确钳制")

	var success_found := false
	var failure_found := false
	for seed_value in range(1, 201):
		var engine := BattleEngine.new(encounter, content, seed_value)
		var events := engine.resolve_round([BattleIntent.make(&"party", BattleTypes.IntentKind.FLEE)])
		var flee_result := _find(events, &"flee_result", "party")
		if flee_result == null:
			continue
		if bool(flee_result.data["success"]):
			success_found = true
			t.eq(engine.outcome(), BattleTypes.Outcome.ESCAPED, "逃跑成功结束战斗")
			t.eq(String(events[events.size() - 1].type), "battle_end", "逃跑成功以 battle_end 收尾")
		else:
			failure_found = true
			var ally_actions := 0
			var enemy_actions := 0
			for event in events:
				if event.type != &"action_start":
					continue
				var action_source := engine.state.get_unit(event.source_id)
				if action_source == null:
					continue
				if action_source.side == BattleTypes.Side.ALLY:
					ally_actions += 1
				elif action_source.side == BattleTypes.Side.ENEMY:
					enemy_actions += 1
			t.eq(ally_actions, 0, "逃跑失败我方不行动")
			t.ok(enemy_actions >= 1, "逃跑失败敌方至少行动一次")
		if success_found and failure_found:
			break
	t.ok(success_found, "在 200 个种子内找到逃跑成功")
	t.ok(failure_found, "在 200 个种子内找到逃跑失败")

	var brute_engine := BattleEngine.new(encounter, content, 9)
	var brute_events := brute_engine.resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
		BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.DEFEND),
		BattleIntent.make(&"hero_healer", BattleTypes.IntentKind.DEFEND),
	])
	t.ok(_has_skill_event(brute_events, "boss_brute", "war_cry"), "妖将首回合使用战吼")
	t.ok(bool(_find(brute_events, &"status_apply", "boss_brute") != null), "战吼状态施加")

	var ground_split_seen := false
	for seed_value in range(1, 31):
		var split_engine := BattleEngine.new(encounter, content, seed_value)
		split_engine.state.get_unit(&"boss_brute").add_status(content.get_status(&"war_cry"), 0)
		var split_events := split_engine.resolve_round([
			BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
			BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.DEFEND),
			BattleIntent.make(&"hero_healer", BattleTypes.IntentKind.DEFEND),
		])
		if _find_skill_action(split_events, "boss_brute", "ground_split") != null:
			ground_split_seen = true
	t.ok(ground_split_seen, "30 个种子内妖将使用裂地斩")

	var poison_seen := false
	for seed_value in range(1, 31):
		var poison_engine := BattleEngine.new(encounter, content, seed_value)
		var poison_events := poison_engine.resolve_round([
			BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
			BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.DEFEND),
			BattleIntent.make(&"hero_healer", BattleTypes.IntentKind.DEFEND),
		])
		if _find_skill_action(poison_events, "mob_b", "poison_strike") != null:
			poison_seen = true
	t.ok(poison_seen, "30 个种子内妖兵·乙使用淬毒击")

	var fox_seal_seen := false
	var fox_fire_seen := false
	for seed_value in range(1, 31):
		var fox_engine := BattleEngine.new(encounter, content, seed_value)
		var fox_events := fox_engine.resolve_round([
			BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
			BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.DEFEND),
			BattleIntent.make(&"hero_healer", BattleTypes.IntentKind.DEFEND),
		])
		var charm_event := _find_skill_action(fox_events, "boss_fox", "charm_seal")
		if charm_event != null:
			fox_seal_seen = true
			var hit_priority := charm_event.target_ids.has(&"hero_healer") or charm_event.target_ids.has(&"hero_mage")
			t.ok(hit_priority, "魅惑封印优先选中治疗或法师")
		if _find_skill_action(fox_events, "boss_fox", "fox_fire") != null:
			fox_fire_seen = true
	t.ok(fox_seal_seen, "30 个种子内狐妖使用魅惑封印")
	t.ok(fox_fire_seen, "30 个种子内狐妖使用妖火")

	var limit_state := BattleState.new()
	limit_state.max_rounds = 1
	var hero_data := UnitData.new()
	hero_data.id = &"hero"; hero_data.max_hp = 1000; hero_data.max_mp = 0; hero_data.atk = 1; hero_data.speed = 10
	var enemy_data := UnitData.new()
	enemy_data.id = &"enemy"; enemy_data.max_hp = 1000; enemy_data.max_mp = 0; enemy_data.atk = 1; enemy_data.speed = 10
	limit_state.units.append(BattleUnitState.new(hero_data, BattleTypes.Side.ALLY, 0))
	limit_state.units.append(BattleUnitState.new(enemy_data, BattleTypes.Side.ENEMY, 0))
	var limit_events := BattleResolver.new(limit_state, BattleRng.new(5), content).resolve_round([
		BattleIntent.make(&"hero", BattleTypes.IntentKind.DEFEND),
	])
	t.eq(limit_state.outcome, BattleTypes.Outcome.DEFEAT, "达到回合上限判负")
	var limit_end := _find(limit_events, &"battle_end", "")
	t.eq(String(limit_end.data["reason"]), "round_limit", "回合上限原因正确")
