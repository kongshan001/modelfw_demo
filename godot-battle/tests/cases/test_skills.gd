extends RefCounted

func _dummy(slot: int) -> UnitData:
	var data := UnitData.new()
	data.id = StringName("dummy_%d" % slot)
	data.display_name = "木桩%d" % slot
	data.max_hp = 9999
	data.max_mp = 0
	data.atk = 1
	data.defense = 999
	data.magic = 0
	data.resistance = 999
	data.speed = 1
	data.crit_rate = 0.0
	data.ai_profile = &"melee"
	return data

func _state(entries: Array) -> BattleState:
	var state := BattleState.new()
	for entry in entries:
		state.units.append(BattleUnitState.new(entry["data"], entry["side"], entry["slot"]))
	state.max_rounds = 30
	return state

func _count_events(events: Array[BattleEvent], type: StringName, source: String) -> int:
	var count := 0
	for event in events:
		if event.type == type and String(event.source_id) == source:
			count += 1
	return count

func _event_by_type(events: Array[BattleEvent], type: StringName, source: String) -> BattleEvent:
	for event in events:
		if event.type == type and String(event.source_id) == source:
			return event
	return null

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()

	var sweep_state := _state([
		{"data": content.get_unit(&"hero_swordsman"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(0), "side": BattleTypes.Side.ENEMY, "slot": 0},
		{"data": _dummy(1), "side": BattleTypes.Side.ENEMY, "slot": 1},
		{"data": _dummy(2), "side": BattleTypes.Side.ENEMY, "slot": 2},
		{"data": _dummy(3), "side": BattleTypes.Side.ENEMY, "slot": 3},
	])
	var sweep_events := BattleResolver.new(sweep_state, BattleRng.new(101), content).resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.SKILL, [&"dummy_0"], &"sweep"),
	])
	t.eq(_count_events(sweep_events, &"damage", "hero_swordsman"), 3, "横扫千军命中 3 个目标")
	var sweep_mp := _event_by_type(sweep_events, &"mp_change", "hero_swordsman")
	t.ok(sweep_mp != null, "技能消耗 MP")
	t.eq(int(sweep_mp.data["amount"]), 30, "横扫千军消耗 30 MP")

	var fire_state := _state([
		{"data": content.get_unit(&"hero_mage"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(0), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var fire_events := BattleResolver.new(fire_state, BattleRng.new(202), content).resolve_round([
		BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.SKILL, [&"dummy_0"], &"fire_spell"),
	])
	t.eq(_count_events(fire_events, &"damage", "hero_mage"), 1, "烈火咒单体命中")

	var thunder_state := _state([
		{"data": content.get_unit(&"hero_mage"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(0), "side": BattleTypes.Side.ENEMY, "slot": 0},
		{"data": _dummy(1), "side": BattleTypes.Side.ENEMY, "slot": 1},
		{"data": _dummy(2), "side": BattleTypes.Side.ENEMY, "slot": 2},
		{"data": _dummy(3), "side": BattleTypes.Side.ENEMY, "slot": 3},
	])
	var thunder_events := BattleResolver.new(thunder_state, BattleRng.new(303), content).resolve_round([
		BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.SKILL, [&"dummy_0"], &"thunder_storm"),
	])
	t.eq(_count_events(thunder_events, &"damage", "hero_mage"), 4, "雷霆万钧命中全体")

	var heal_state := _state([
		{"data": content.get_unit(&"hero_swordsman"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": content.get_unit(&"hero_healer"), "side": BattleTypes.Side.ALLY, "slot": 1},
		{"data": _dummy(0), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	heal_state.get_unit(&"hero_swordsman").hp = 300
	var heal_events := BattleResolver.new(heal_state, BattleRng.new(404), content).resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
		BattleIntent.make(&"hero_healer", BattleTypes.IntentKind.SKILL, [&"hero_swordsman"], &"heal_single"),
	])
	var heal := _event_by_type(heal_events, &"heal", "hero_healer")
	t.ok(heal != null, "回春术产生治疗事件")
	t.ok(int(heal.data["amount"]) > 0, "治疗量为正")
	t.ok(int(heal.data["hp_after"]) > int(heal.data["hp_before"]), "目标 HP 增加")

	var mp_state := _state([
		{"data": content.get_unit(&"hero_mage"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(0), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	mp_state.get_unit(&"hero_mage").mp = 0
	var mp_events := BattleResolver.new(mp_state, BattleRng.new(505), content).resolve_round([
		BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.SKILL, [&"dummy_0"], &"fire_spell"),
	])
	var rejected := _event_by_type(mp_events, &"intent_rejected", "hero_mage")
	t.ok(rejected != null, "MP 不足被拒绝")
	t.eq(String(rejected.data["reason"]), "invalid", "拒绝原因 invalid")
