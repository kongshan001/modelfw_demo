extends RefCounted

func _random_intents(engine: BattleEngine, choice_rng: RandomNumberGenerator, content: ContentDB) -> Array[BattleIntent]:
	var intents: Array[BattleIntent] = []
	var allies := engine.state.living(BattleTypes.Side.ALLY)
	var enemies := engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		return intents
	for ally in allies:
		var options: Array[int] = [BattleTypes.IntentKind.ATTACK, BattleTypes.IntentKind.DEFEND]
		if not ally.data.skills.is_empty():
			options.append(BattleTypes.IntentKind.SKILL)
		if engine.state.item_remaining(&"potion_hp") > 0 or engine.state.item_remaining(&"potion_mp") > 0:
			options.append(BattleTypes.IntentKind.ITEM)
		var kind: int = options[choice_rng.randi_range(0, options.size() - 1)]
		match kind:
			BattleTypes.IntentKind.ATTACK:
				intents.append(BattleIntent.make(ally.id, kind, [enemies[choice_rng.randi_range(0, enemies.size() - 1)].id]))
			BattleTypes.IntentKind.DEFEND:
				intents.append(BattleIntent.make(ally.id, kind))
			BattleTypes.IntentKind.SKILL:
				var skill := content.get_skill(StringName(ally.data.skills[choice_rng.randi_range(0, ally.data.skills.size() - 1)]))
				if skill == null:
					intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.ATTACK, [enemies[0].id]))
					continue
				var target := ally.id
				if skill.target_type == SkillData.TargetType.SINGLE_ENEMY or skill.target_type == SkillData.TargetType.ALL_ENEMIES:
					target = enemies[choice_rng.randi_range(0, enemies.size() - 1)].id
				elif skill.target_type == SkillData.TargetType.SINGLE_ALLY or skill.target_type == SkillData.TargetType.ALL_ALLIES:
					target = allies[choice_rng.randi_range(0, allies.size() - 1)].id
				intents.append(BattleIntent.make(ally.id, kind, [target], skill.id))
			BattleTypes.IntentKind.ITEM:
				var item_id := &"potion_hp"
				if engine.state.item_remaining(&"potion_hp") <= 0:
					item_id = &"potion_mp"
				var target := allies[choice_rng.randi_range(0, allies.size() - 1)].id
				intents.append(BattleIntent.make(ally.id, kind, [target], &"", item_id))
	return intents

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()
	var encounter := content.get_encounter(&"enc_bamboo_01")
	for battle_index in 50:
		var engine := BattleEngine.new(encounter, content, 5000 + battle_index, false)
		var choice_rng := RandomNumberGenerator.new()
		choice_rng.seed = 9000 + battle_index
		var rounds := 0
		while not engine.is_over() and rounds < 35:
			rounds += 1
			var intents := _random_intents(engine, choice_rng, content)
			engine.resolve_round(intents)
			var issues := BattleInvariants.check(engine.state)
			t.ok(issues.is_empty(), "fuzz #%d round %d: %s" % [battle_index, rounds, str(issues)])
			if not issues.is_empty():
				break
		t.ok(engine.is_over(), "fuzz #%d 在 30 回合内结束" % battle_index)
