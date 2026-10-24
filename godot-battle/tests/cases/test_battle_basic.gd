extends RefCounted

func _unit(id: String, hp: int, atk: int, defense: int, speed: int, crit: float) -> UnitData:
	var data := UnitData.new()
	data.id = StringName(id)
	data.display_name = id
	data.max_hp = hp
	data.max_mp = 0
	data.atk = atk
	data.defense = defense
	data.magic = 0
	data.resistance = 0
	data.speed = speed
	data.crit_rate = crit
	data.ai_profile = &"melee"
	return data

func _state(entries: Array) -> BattleState:
	var state := BattleState.new()
	for entry in entries:
		state.units.append(BattleUnitState.new(entry["data"], entry["side"], entry["slot"]))
	state.max_rounds = 30
	return state

func _defend_intents(state: BattleState) -> Array[BattleIntent]:
	var intents: Array[BattleIntent] = []
	for unit in state.living(BattleTypes.Side.ALLY):
		intents.append(BattleIntent.make(unit.id, BattleTypes.IntentKind.DEFEND))
	return intents

func _find_damage(events: Array[BattleEvent], source: String) -> BattleEvent:
	for event in events:
		if event.type == &"damage" and String(event.source_id) == source:
			return event
	return null

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()

	var ally := _unit("ally", 100, 100, 0, 100, 0.0)
	var enemy := _unit("enemy", 1000, 10, 0, 10, 0.0)
	var state := _state([
		{"data": ally, "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": enemy, "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var resolver := BattleResolver.new(state, BattleRng.new(42), content)
	var events := resolver.resolve_round([BattleIntent.make(&"ally", BattleTypes.IntentKind.ATTACK, [&"enemy"])])
	var damage := _find_damage(events, "ally")
	t.ok(damage != null, "产生伤害事件")
	t.in_range(float(damage.data["amount"]), 90.0, 110.0, "伤害在公式范围内")
	t.eq(int(damage.data["hp_before"]) - int(damage.data["hp_after"]), int(damage.data["amount"]), "HP 变化等于伤害")

	var s1 := _unit("s1", 100, 10, 0, 100, 0.0)
	var s2 := _unit("s2", 100, 10, 0, 60, 0.0)
	var s3 := _unit("s3", 100, 10, 0, 20, 0.0)
	var e1 := _unit("e1", 100, 5, 0, 1, 0.0)
	var order_state := _state([
		{"data": s1, "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": s2, "side": BattleTypes.Side.ALLY, "slot": 1},
		{"data": s3, "side": BattleTypes.Side.ALLY, "slot": 2},
		{"data": e1, "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var order_events := BattleResolver.new(order_state, BattleRng.new(7), content).resolve_round(_defend_intents(order_state))
	var actors: Array[String] = []
	for event in order_events:
		if event.type == &"action_start":
			actors.append(String(event.source_id))
	t.eq(actors, ["s1", "s2", "s3", "e1"], "按速度降序行动")

	var killer := _unit("killer", 100, 1000, 0, 100, 0.0)
	var victim := _unit("victim", 10, 0, 0, 1, 0.0)
	var win_state := _state([
		{"data": killer, "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": victim, "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var win_events := BattleResolver.new(win_state, BattleRng.new(1), content).resolve_round([
		BattleIntent.make(&"killer", BattleTypes.IntentKind.ATTACK, [&"victim"]),
	])
	t.eq(win_state.outcome, BattleTypes.Outcome.VICTORY, "敌方全灭判胜")
	t.eq(String(win_events[win_events.size() - 1].type), "battle_end", "battle_end 是最后一个事件")

	var defender := _unit("defender", 1000, 10, 0, 10, 0.0)
	var attacker := _unit("attacker", 100, 100, 0, 100, 0.0)
	var def_state := _state([
		{"data": attacker, "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": defender, "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var defending_status := content.get_status(&"defending")
	def_state.get_unit(&"defender").add_status(defending_status, 0)
	var def_events := BattleResolver.new(def_state, BattleRng.new(3), content).resolve_round([
		BattleIntent.make(&"attacker", BattleTypes.IntentKind.ATTACK, [&"defender"]),
	])
	var def_damage := _find_damage(def_events, "attacker")
	t.in_range(float(def_damage.data["amount"]), 45.0, 55.0, "防御后伤害减半")

	var encounter := content.get_encounter(&"enc_bamboo_01")
	var engine := BattleEngine.new(encounter, content, 123)
	t.eq(engine.state.living(BattleTypes.Side.ALLY).size(), 3, "引擎生成 3 名我方")
	t.eq(engine.state.living(BattleTypes.Side.ENEMY).size(), 4, "引擎生成 4 名敌方")
