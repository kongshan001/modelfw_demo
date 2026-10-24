extends RefCounted

func _lowest_ally(allies: Array[BattleUnitState]) -> BattleUnitState:
	var sorted := allies.duplicate()
	sorted.sort_custom(func(a, b):
		var pa := float(a.hp) / float(a.data.max_hp)
		var pb := float(b.hp) / float(b.data.max_hp)
		if is_equal_approx(pa, pb):
			return String(a.id) < String(b.id)
		return pa < pb)
	return sorted[0]

func _policy(engine: BattleEngine) -> Array[BattleIntent]:
	var intents: Array[BattleIntent] = []
	var allies := engine.state.living(BattleTypes.Side.ALLY)
	var enemies := engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		return intents
	for ally in allies:
		if ally.id == &"hero_healer":
			var target := _lowest_ally(allies)
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [target.id], &"heal_single"))
		elif ally.id == &"hero_mage":
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [enemies[0].id], &"fire_spell"))
		else:
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.ATTACK, [enemies[0].id]))
	return intents

func _run(engine: BattleEngine, max_rounds: int) -> Array[Dictionary]:
	var all_events: Array[Dictionary] = []
	for i in max_rounds:
		if engine.is_over():
			break
		for event in engine.resolve_round(_policy(engine)):
			all_events.append(event.to_dict())
	return all_events

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()
	var encounter := content.get_encounter(&"enc_bamboo_01")

	var engine := BattleEngine.new(encounter, content, 777)
	_run(engine, 12)
	var path := engine.dump_replay("user://test_replay.json")
	t.ok(not path.is_empty(), "录像写入成功")
	t.ok(FileAccess.file_exists(path), "录像文件存在")

	var replay := BattleReplay.load_file(path)
	t.ok(not replay.is_empty(), "录像可加载")
	var verification := BattleReplay.verify(replay, content, true)
	t.ok(bool(verification["ok"]), "录像校验通过: " + str(verification["errors"]))
	var replay_snapshots: Array = replay.get("snapshots", [])
	var replay_events: Array = replay.get("events", [])
	t.ok(replay_snapshots.size() >= 1, "包含状态快照")
	t.ok(replay_events.size() > 0, "包含事件流")

	var engine_a := BattleEngine.new(encounter, content, 888, false)
	var engine_b := BattleEngine.new(encounter, content, 888, false)
	var events_a := _run(engine_a, 12)
	var events_b := _run(engine_b, 12)
	t.eq(JSON.stringify(events_b, "", true), JSON.stringify(events_a, "", true), "同种子同指令事件流一致")
	t.eq(engine_b.state.outcome, engine_a.state.outcome, "同种子结果一致")

	var tampered := replay.duplicate(true)
	for event in tampered["events"]:
		if event["type"] == "damage":
			event["data"]["amount"] = int(event["data"]["amount"]) + 1
			break
	var tampered_result := BattleReplay.verify(tampered, content, true)
	t.ok(not bool(tampered_result["ok"]), "篡改后的录像校验失败")
	t.ok(" ".join(tampered_result["errors"]).contains("digest"), "篡改报告指出摘要不一致: " + str(tampered_result["errors"]))

	var intent_tampered := replay.duplicate(true)
	intent_tampered["rounds"][0]["intents"][0]["kind"] = BattleTypes.IntentKind.DEFEND
	var intent_result := BattleReplay.verify(intent_tampered, content, true)
	t.ok(not bool(intent_result["ok"]), "篡改意图后的录像校验失败")
	t.eq(String(intent_result["first_divergence"].get("reason", "")), "event_mismatch", "指令篡改通过摘要链后被事件比对发现")

	var snapshot_tampered := replay.duplicate(true)
	var snapshots: Array = snapshot_tampered["snapshots"]
	t.ok(snapshots.size() >= 2, "录像包含多轮快照")
	var tamper_index := 1 if snapshots.size() > 1 else 0
	var tamper_unit: Dictionary = snapshots[tamper_index]["units"][0]
	tamper_unit["hp"] = int(tamper_unit["hp"]) + 1
	var snapshot_result := BattleReplay.verify(snapshot_tampered, content, true)
	t.ok(not bool(snapshot_result["ok"]), "篡改快照后的录像校验失败")
	t.eq(String(snapshot_result["first_divergence"].get("reason", "")), "snapshot_mismatch", "快照篡改被定位为 snapshot_mismatch")
	t.ok(" ".join(snapshot_result["errors"]).contains("snapshot"), "错误信息指出快照分歧: " + str(snapshot_result["errors"]))

	var item_tampered := replay.duplicate(true)
	for snapshot in item_tampered["snapshots"]:
		var items: Dictionary = snapshot.get("item_uses", {})
		if not items.is_empty():
			items["potion_hp"] = int(items["potion_hp"]) + 1
			break
	var item_result := BattleReplay.verify(item_tampered, content, true)
	t.ok(not bool(item_result["ok"]), "篡改道具次数后的录像校验失败")
	t.eq(String(item_result["first_divergence"].get("reason", "")), "snapshot_mismatch", "道具次数篡改被定位为 snapshot_mismatch")

	var partial_engine := BattleEngine.new(encounter, content, 555)
	partial_engine.apply_debug_op({"op": "kill", "unit_id": "mob_a"})
	var partial_path := partial_engine.dump_replay("user://test_replay_partial.json")
	var partial_replay := BattleReplay.load_file(partial_path)
	var partial_result := BattleReplay.verify(partial_replay, content, true)
	t.ok(bool(partial_result["ok"]), "未解算回合不会产生假分歧: " + str(partial_result["errors"]))
	# 未解析轮次的快照不参与比对：即使篡改也不应影响校验。
	for snapshot in partial_replay["snapshots"]:
		if int(snapshot["round"]) == 1 and not snapshot["units"].is_empty():
			snapshot["units"][0]["hp"] = 1
			break
	var partial_tampered := BattleReplay.verify(partial_replay, content, true)
	t.ok(bool(partial_tampered["ok"]), "未解析轮次不比较快照: " + str(partial_tampered["errors"]))

	var debug_engine := BattleEngine.new(encounter, content, 999)
	debug_engine.apply_debug_op({"op": "kill", "unit_id": "mob_a"})
	debug_engine.resolve_round(_policy(debug_engine))
	var debug_path := debug_engine.dump_replay("user://test_replay_debug.json")
	var debug_replay := BattleReplay.load_file(debug_path)
	var debug_result := BattleReplay.verify(debug_replay, content, true)
	t.ok(bool(debug_result["ok"]), "调试操作可随录像重放: " + str(debug_result["errors"]))

	var broken_state := BattleState.new()
	var broken_unit := BattleUnitState.new(content.get_unit(&"hero_swordsman"), BattleTypes.Side.ALLY, 0)
	broken_unit.hp = -1
	broken_state.units.append(broken_unit)
	t.ok(BattleInvariants.check(broken_state).size() > 0, "不变量能发现非法 HP")
