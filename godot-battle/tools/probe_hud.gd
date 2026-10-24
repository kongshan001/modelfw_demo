extends SceneTree

# HUD 指令流程探针（headless）：程序化完成一回合、触发 25s 超时路径、再验证逃跑。
# 用法：godot --headless --path godot-battle -s tools/probe_hud.gd

func _initialize() -> void:
	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var hud: BattleHUD = scene.get_node("UILayer/BattleHUD")
	var session: BattleSession = scene.get_node("BattleSession")
	var sequencer: BattleSequencer = scene.get_node("BattleSequencer")

	# ---- 第一回合：攻击 / 返回撤销 / 法术 / 防御 ----
	if not await _wait_until(func() -> bool: return hud.is_collecting(), 10.0):
		_fail("phase 1 did not start")
		return
	var enemies := session.engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		_fail("no living enemies")
		return
	var primary := enemies[0].id
	hud.select_attack()
	hud.choose_target(primary)
	# 第二名角色先攻击，再返回上一位，验证撤销后重选。
	hud.select_attack()
	hud.choose_target(primary)
	hud.go_back()
	hud.select_skill(&"fire_spell")
	hud.choose_target(primary)
	hud.select_defend()
	if not await _wait_until(func() -> bool: return not hud.is_collecting(), 3.0):
		_fail("phase 1 did not finish")
		return

	var first := hud.last_intents
	if first.size() != 3:
		_fail("expected 3 intents, got %d" % first.size())
		return
	if first[0].kind != BattleTypes.IntentKind.ATTACK or first[0].actor_id != &"hero_swordsman" or not _targets(first[0], primary):
		_fail("intent 0 mismatch: %s" % str(first[0].to_dict()))
		return
	if first[1].kind != BattleTypes.IntentKind.SKILL or first[1].actor_id != &"hero_mage" or first[1].skill_id != &"fire_spell" or not _targets(first[1], primary):
		_fail("intent 1 mismatch (back-out did not restore?): %s" % str(first[1].to_dict()))
		return
	if first[2].kind != BattleTypes.IntentKind.DEFEND or first[2].actor_id != &"hero_healer":
		_fail("intent 2 mismatch: %s" % str(first[2].to_dict()))
		return
	print("HUD_PROBE: manual flow OK")
	hud.toggle_speed()
	if sequencer.playback_speed < 1.5:
		_fail("speed toggle did not switch to 2x")
		return

	await _skip_playback(sequencer)

	# ---- 第二回合：倒计时超时自动普攻 ----
	if not await _wait_until(func() -> bool: return hud.is_collecting(), 10.0):
		_fail("phase 2 did not start")
		return
	hud._time_left = 0.05
	if not await _wait_until(func() -> bool: return not hud.is_collecting(), 3.0):
		_fail("timeout phase did not finish")
		return
	var auto_intents := hud.last_intents
	var living_allies := session.engine.state.living(BattleTypes.Side.ALLY)
	var living_enemies := session.engine.state.living(BattleTypes.Side.ENEMY)
	if auto_intents.size() != living_allies.size():
		_fail("timeout expected %d intents, got %d" % [living_allies.size(), auto_intents.size()])
		return
	for intent in auto_intents:
		if intent.kind != BattleTypes.IntentKind.ATTACK:
			_fail("timeout intent is not ATTACK: %s" % str(intent.to_dict()))
			return
		if intent.target_ids.size() != 1 or not _contains_unit(living_enemies, intent.target_ids[0]):
			_fail("timeout target is not a living enemy: %s" % str(intent.to_dict()))
			return
	print("HUD_PROBE: timeout auto-attack OK")

	await _skip_playback(sequencer)

	# ---- 第三回合：道具指向友方 ----
	if not await _wait_until(func() -> bool: return hud.is_collecting(), 10.0):
		_fail("phase 3 did not start")
		return
	var phase_allies := session.engine.state.living(BattleTypes.Side.ALLY)
	var phase_enemies := session.engine.state.living(BattleTypes.Side.ENEMY)
	if phase_allies.size() < 3 or phase_enemies.is_empty():
		_fail("unexpected phase 3 lineup")
		return
	var heal_target := phase_allies[2].id
	if not hud.select_item(&"potion_hp"):
		_fail("select_item(potion_hp) failed")
		return
	if not hud.choose_target(heal_target):
		_fail("item target selection failed")
		return
	hud.select_attack()
	hud.choose_target(phase_enemies[0].id)
	hud.select_defend()
	if not await _wait_until(func() -> bool: return not hud.is_collecting(), 3.0):
		_fail("item phase did not finish")
		return
	var item_intents := hud.last_intents
	if item_intents.size() != 3:
		_fail("item phase expected 3 intents, got %d" % item_intents.size())
		return
	if item_intents[0].kind != BattleTypes.IntentKind.ITEM or item_intents[0].item_id != &"potion_hp" or not _targets(item_intents[0], heal_target):
		_fail("item intent mismatch: %s" % str(item_intents[0].to_dict()))
		return
	print("HUD_PROBE: item ally-target OK")

	await _skip_playback(sequencer)

	# ---- 第四回合：逃跑为全队指令，丢弃已下指令 ----
	if not await _wait_until(func() -> bool: return hud.is_collecting(), 10.0):
		_fail("phase 4 did not start")
		return
	var flee_enemies := session.engine.state.living(BattleTypes.Side.ENEMY)
	if flee_enemies.is_empty():
		_fail("no enemies before flee check")
		return
	hud.select_attack()
	hud.choose_target(flee_enemies[0].id)
	hud.select_flee()
	if not await _wait_until(func() -> bool: return not hud.is_collecting(), 3.0):
		_fail("flee phase did not finish")
		return
	var flee_intents := hud.last_intents
	if flee_intents.size() != 1:
		_fail("flee expected 1 intent, got %d" % flee_intents.size())
		return
	if flee_intents[0].kind != BattleTypes.IntentKind.FLEE or flee_intents[0].actor_id != &"party":
		_fail("flee intent mismatch: %s" % str(flee_intents[0].to_dict()))
		return
	print("HUD_PROBE: flee party intent OK")
	print("HUD_PROBE_OK")
	scene.queue_free()
	await process_frame
	quit(0)

func _skip_playback(sequencer: BattleSequencer) -> void:
	await create_timer(0.25).timeout
	await sequencer.skip_all()
	await create_timer(0.15).timeout

func _targets(intent: BattleIntent, unit_id: StringName) -> bool:
	return intent.target_ids.size() == 1 and intent.target_ids[0] == unit_id

func _contains_unit(units: Array, unit_id: StringName) -> bool:
	for unit in units:
		if unit.id == unit_id:
			return true
	return false

func _wait_until(predicate: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return true
		await create_timer(0.1).timeout
		elapsed += 0.1
	return false

func _fail(message: String) -> void:
	printerr("HUD_PROBE_FAIL: " + message)
	quit(1)
