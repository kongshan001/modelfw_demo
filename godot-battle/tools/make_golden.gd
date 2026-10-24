extends SceneTree

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/golden"))
	var content := ContentDB.load_all()
	var encounter := content.get_encounter(&"enc_bamboo_01")
	var configs := [
		{"name": "golden_attack", "seed": 1001, "policy": "attack"},
		{"name": "golden_aoe", "seed": 1002, "policy": "aoe"},
		{"name": "golden_control", "seed": 1003, "policy": "control"},
	]
	for config in configs:
		var engine := BattleEngine.new(encounter, content, int(config["seed"]), true)
		for i in 12:
			if engine.is_over():
				break
			engine.resolve_round(_build_intents(engine, String(config["policy"]), content))
		var path := engine.dump_replay("res://tests/golden/%s.json" % String(config["name"]))
		print("GOLDEN: " + path)
	quit(0)

func _build_intents(engine: BattleEngine, policy: String, content: ContentDB) -> Array[BattleIntent]:
	var intents: Array[BattleIntent] = []
	var allies := engine.state.living(BattleTypes.Side.ALLY)
	var enemies := engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		return intents
	var lowest := _lowest_ally(allies)
	for ally in allies:
		match policy:
			"attack":
				intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.ATTACK, [enemies[0].id]))
			"aoe":
				if ally.id == &"hero_swordsman":
					intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [enemies[0].id], &"sweep"))
				elif ally.id == &"hero_mage":
					intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [enemies[0].id], &"thunder_storm"))
				else:
					intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [lowest.id], &"heal_all"))
			"control":
				if ally.id == &"hero_swordsman":
					intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [enemies[0].id], &"armor_break"))
				elif ally.id == &"hero_mage":
					var seal_target := enemies[0]
					for enemy in enemies:
						if enemy.id == &"boss_fox":
							seal_target = enemy
					intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [seal_target.id], &"seal_talisman"))
				else:
					var has_debuff := false
					for ally2 in allies:
						for status in ally2.statuses:
							if status.data.kind == StatusData.Kind.DEBUFF:
								has_debuff = true
					if has_debuff:
						intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [lowest.id], &"cleanse"))
					else:
						intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [lowest.id], &"heal_single"))
	return intents

func _lowest_ally(allies: Array[BattleUnitState]) -> BattleUnitState:
	var sorted := allies.duplicate()
	sorted.sort_custom(func(a, b):
		var pa := float(a.hp) / float(a.data.max_hp)
		var pb := float(b.hp) / float(b.data.max_hp)
		if is_equal_approx(pa, pb):
			return String(a.id) < String(b.id)
		return pa < pb)
	return sorted[0]
