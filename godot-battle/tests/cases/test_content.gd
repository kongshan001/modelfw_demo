extends RefCounted

func run(t: TestContext) -> void:
	var db := ContentDB.load_all()
	t.eq(db.units.size(), 7, "7 个单位")
	t.eq(db.skills.size(), 13, "13 个技能")
	t.eq(db.statuses.size(), 5, "5 个状态")
	t.eq(db.items.size(), 2, "2 个道具")
	t.eq(db.encounters.size(), 1, "1 个遭遇战")

	var encounter: EncounterData = db.get_encounter(&"enc_bamboo_01")
	t.ok(encounter != null, "遭遇战存在")
	t.eq(encounter.ally_unit_ids.size(), 3, "我方 3 人")
	t.eq(encounter.enemy_unit_ids.size(), 4, "敌方 4 人")
	for unit_id in encounter.ally_unit_ids + encounter.enemy_unit_ids:
		t.ok(db.get_unit(unit_id) != null, "单位资源存在: " + String(unit_id))

	for skill_id in [&"sweep", &"seal_talisman", &"heal_all", &"poison_strike", &"charm_seal"]:
		var skill: SkillData = db.get_skill(skill_id)
		t.ok(skill != null, "技能存在: " + String(skill_id))
		for effect in skill.effects:
			if effect.kind == BattleEffect.Kind.APPLY_STATUS:
				t.ok(db.get_status(effect.status_id) != null, "状态引用有效: " + String(effect.status_id))

	var hash_a := db.content_hash()
	var hash_b := ContentDB.load_all().content_hash()
	t.eq(hash_b, hash_a, "内容 hash 稳定")
	t.has(hash_a, "sha256:", "内容 hash 格式")
