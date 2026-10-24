extends RefCounted

func run(t: TestContext) -> void:
	var event := BattleEvent.make(3, 2, &"damage", &"hero_mage", [&"mob_a", &"mob_b"], {"amount": 12, "crit": true})
	var restored := BattleEvent.from_dict(event.to_dict())
	t.eq(restored.canonical_json(), event.canonical_json(), "事件序列化往返一致")
	t.eq(restored.target_ids.size(), 2, "目标数量保留")
	t.eq(String(restored.target_ids[1]), "mob_b", "目标顺序保留")

	var intent := BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.SKILL, [&"boss_fox"], &"sweep")
	var intent2 := BattleIntent.from_dict(intent.to_dict())
	t.eq(String(intent2.actor_id), "hero_swordsman", "意图 actor 往返")
	t.eq(intent2.kind, BattleTypes.IntentKind.SKILL, "意图 kind 往返")
	t.eq(String(intent2.skill_id), "sweep", "意图技能往返")
	t.eq(intent2.target_ids.size(), 1, "意图目标往返")
