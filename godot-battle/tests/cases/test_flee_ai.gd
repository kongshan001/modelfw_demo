extends RefCounted

func _find(events: Array[BattleEvent], type: StringName, source: String) -> BattleEvent:
	for event in events:
		if event.type == type and String(event.source_id) == source:
			return event
	return null

func _has_skill_event(events: Array[BattleEvent], source: String, skill_id: String) -> bool:
	for event in events:
		if String(event.source_id) != source:
			continue
		if event.type == &"action_start" and String(event.data.get("skill_id", "")) == skill_id:
			return true
	return false

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
			for event in events:
				if event.type == &"action_start" and engine.state.get_unit(event.source_id) != null and engine.state.get_unit(event.source_id).side == BattleTypes.Side.ALLY:
					ally_actions += 1
			t.eq(ally_actions, 0, "逃跑失败我方不行动")
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

	var fox_seal_seen := false
	var fox_fire_seen := false
	for seed_value in range(1, 31):
		var fox_engine := BattleEngine.new(encounter, content, seed_value)
		var fox_events := fox_engine.resolve_round([
			BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
			BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.DEFEND),
			BattleIntent.make(&"hero_healer", BattleTypes.IntentKind.DEFEND),
		])
		if _find(fox_events, &"status_apply", "boss_fox") != null or _find(fox_events, &"status_resist", "boss_fox") != null:
			fox_seal_seen = true
		if _has_skill_event(fox_events, "boss_fox", "fox_fire"):
			fox_fire_seen = true
	t.ok(fox_seal_seen or fox_fire_seen, "狐妖至少使用一种技能")

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
