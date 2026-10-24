extends RefCounted

func _dummy() -> UnitData:
	var data := UnitData.new()
	data.id = &"dummy"
	data.display_name = "木桩"
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

func _state(entries: Array, items: Dictionary = {}) -> BattleState:
	var state := BattleState.new()
	for entry in entries:
		state.units.append(BattleUnitState.new(entry["data"], entry["side"], entry["slot"]))
	state.item_uses = items
	state.max_rounds = 30
	return state

func _count(events: Array[BattleEvent], type: StringName, source: String) -> int:
	var total := 0
	for event in events:
		if event.type == type and String(event.source_id) == source:
			total += 1
	return total

func _first(events: Array[BattleEvent], type: StringName, source: String) -> BattleEvent:
	for event in events:
		if event.type == type and String(event.source_id) == source:
			return event
	return null

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()

	# 中毒：回合开始 tick，施加回合不递减，结束后 remaining 3 -> 2
	var poison_state := _state([
		{"data": content.get_unit(&"hero_swordsman"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var poisoned := poison_state.get_unit(&"hero_swordsman")
	poisoned.add_status(content.get_status(&"poison"), 0)
	var poison_events := BattleResolver.new(poison_state, BattleRng.new(11), content).resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
	])
	var tick := _first(poison_events, &"status_tick", "hero_swordsman")
	t.ok(tick != null, "中毒在回合开始结算")
	t.eq(int(tick.data["amount"]), roundi(float(poisoned.data.max_hp) * 0.08), "中毒伤害为最大 HP 的 8%")
	t.eq(poisoned.find_status(&"poison").remaining, 2, "中毒剩余回合减少")

	# 封印：只结算一次（命中或抵抗）
	var seal_state := _state([
		{"data": content.get_unit(&"hero_mage"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var seal_events := BattleResolver.new(seal_state, BattleRng.new(22), content).resolve_round([
		BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.SKILL, [&"dummy"], &"seal_talisman"),
	])
	var seal_count := _count(seal_events, &"status_apply", "hero_mage") + _count(seal_events, &"status_resist", "hero_mage")
	t.eq(seal_count, 1, "封印要么命中要么抵抗，且只结算一次")

	# 防御对封印命中的修正
	var def_target := BattleUnitState.new(content.get_unit(&"boss_fox"), BattleTypes.Side.ENEMY, 0)
	def_target.add_status(content.get_status(&"defending"), 0)
	t.near(BattleResolver.new(BattleState.new(), BattleRng.new(1), content).compute_status_chance(def_target, 0.65), 0.455, 0.0001, "防御使封印命中率 ×0.7")

	# 道具：金疮药回复 220，共享池 3 -> 2
	var item_state := _state([
		{"data": content.get_unit(&"hero_swordsman"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(), "side": BattleTypes.Side.ENEMY, "slot": 0},
	], {&"potion_hp": 3})
	item_state.get_unit(&"hero_swordsman").hp = 100
	var item_events := BattleResolver.new(item_state, BattleRng.new(33), content).resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.ITEM, [&"hero_swordsman"], &"", &"potion_hp"),
	])
	var item_use := _first(item_events, &"item_used", "hero_swordsman")
	t.ok(item_use != null, "使用金疮药")
	t.eq(int(item_use.data["remaining"]), 2, "金疮药剩余 2 次")
	var item_heal := _first(item_events, &"heal", "hero_swordsman")
	t.eq(int(item_heal.data["hp_after"]), 320, "金疮药回复 220 HP")

	# 清心咒：解除一个负面状态
	var cleanse_state := _state([
		{"data": content.get_unit(&"hero_swordsman"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": content.get_unit(&"hero_healer"), "side": BattleTypes.Side.ALLY, "slot": 1},
		{"data": _dummy(), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var cleanse_target := cleanse_state.get_unit(&"hero_swordsman")
	cleanse_target.add_status(content.get_status(&"poison"), 0)
	cleanse_target.add_status(content.get_status(&"armor_down"), 0)
	var cleanse_events := BattleResolver.new(cleanse_state, BattleRng.new(44), content).resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.ATTACK, [&"dummy"]),
		BattleIntent.make(&"hero_healer", BattleTypes.IntentKind.SKILL, [&"hero_swordsman"], &"cleanse"),
	])
	var cleanse_expire := _first(cleanse_events, &"status_expire", "hero_healer")
	t.ok(cleanse_expire != null, "清心咒解除一个负面状态")
	t.eq(String(cleanse_expire.data["reason"]), "cleanse", "解除原因正确")
	t.eq(cleanse_target.statuses.size(), 1, "只解除一个负面状态")

	# 防御：状态保留到自身下次行动
	var defend_state := _state([
		{"data": content.get_unit(&"hero_swordsman"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var defend_events := BattleResolver.new(defend_state, BattleRng.new(55), content).resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
	])
	t.ok(_first(defend_events, &"defend", "hero_swordsman") != null, "防御指令产生事件")
	t.ok(defend_state.get_unit(&"hero_swordsman").has_status(&"defending"), "防御状态保留到自身下次行动")
