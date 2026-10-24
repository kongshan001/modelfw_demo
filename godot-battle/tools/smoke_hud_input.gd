extends SceneTree

# 输入级 HUD 冒烟：真实鼠标点击「攻击」按钮，再用真实鼠标点击敌方 UnitView 选择目标，
# 覆盖 3 名存活我方的完整指令阶段，校验 phase_submitted 的 3 条意图与回合结算。
# 需要窗口（物理拾取走真实视口输入）：
#   godot --path godot-battle --resolution 1920x1080 -s tools/smoke_hud_input.gd

const PHASE_TIMEOUT := 15.0

var _scene: Node
var _hud: BattleHUD
var _session: BattleSession
var _sequencer: BattleSequencer
var _submitted: Array = []
var _submitted_count := 0
var _phase_started := false

func _initialize() -> void:
	_scene = load("res://scenes/battle_scene.tscn").instantiate()
	# BattleSession 在场景 _ready 中创建，手动模式必须在入树前确定。
	_scene.start_auto_mode = false
	_scene.skip_story = true
	root.add_child(_scene)
	await process_frame
	_hud = _scene.get_node("UILayer/BattleHUD")
	_session = _scene.get_node("BattleSession")
	_sequencer = _scene.get_node("BattleSequencer")
	_session.auto_mode = false
	_hud.phase_submitted.connect(_on_phase_submitted)
	_session.command_phase_started.connect(_on_command_phase_started)
	# 场景 _ready 会同步推进到首个指令阶段，信号可能早于连接。
	if _hud.is_collecting():
		_phase_started = true

	print("HUD_INPUT: window=%s physics_picking=%s skip_story=%s" % [str(root.size), str(root.physics_object_picking), str(_scene.skip_story)])
	if not await _wait_until(func() -> bool: return _phase_started and _hud.is_collecting(), PHASE_TIMEOUT):
		_fail("command phase did not start")
		return
	await _check_layout()
	await _sweep_unit_clicks()

	var initial_round := _session.engine.state.round
	# 三次攻击分别点击不同敌人，顺带验证鼠标点击 UnitView。
	var target_slots: Array[int] = [0, 1, 2]
	for index in 3:
		if not await _wait_until(func() -> bool: return _hud.is_collecting() and _hud._awaiting_intent and _hud._mode == BattleHUD.MenuMode.ROOT, PHASE_TIMEOUT):
			_fail("ally %d root menu not ready (collecting=%s mode=%d)" % [index, str(_hud.is_collecting()), _hud._mode])
			return
		var attack := _find_button("攻击")
		if attack == null:
			_fail("attack button not found by text for ally %d" % index)
			return
		var rect := attack.get_global_rect()
		print("HUD_INPUT: click 攻击 ally=%d rect=%s" % [index, str(rect)])
		_click_at(rect.get_center())
		await process_frame
		if _hud._mode != BattleHUD.MenuMode.TARGET:
			_fail("attack click did not enter target mode (ally %d mode=%d)" % [index, _hud._mode])
			return

		var enemies := _session.engine.state.living(BattleTypes.Side.ENEMY)
		if enemies.is_empty():
			_fail("no living enemies for ally %d" % index)
			return
		var target: BattleUnitState = enemies[target_slots[index] % enemies.size()]
		var view: UnitView = _session.context.unit_view(target.id)
		if view == null:
			_fail("missing UnitView for target %s" % target.id)
			return
		var point := _to_screen(view.global_position + Vector2(0, -140))
		print("HUD_INPUT: click target %s at %s" % [target.id, str(point)])
		_click_at(point)
		await physics_frame
		await process_frame
		if _hud._mode == BattleHUD.MenuMode.TARGET and _hud._awaiting_intent:
			# 物理拾取可能晚一帧。
			await physics_frame
			await process_frame
		if index < 2:
			if not await _wait_until(func() -> bool: return _hud.is_collecting() and _hud._awaiting_intent and _hud._mode == BattleHUD.MenuMode.ROOT, 3.0):
				_fail("target click did not submit ally %d (mode=%d awaiting=%s)" % [index, _hud._mode, str(_hud._awaiting_intent)])
				return

	if not await _wait_until(func() -> bool: return _submitted_count > 0, 5.0):
		_fail("phase_submitted was not emitted")
		return
	if _submitted.size() != 3:
		_fail("phase_submitted expected 3 intents, got %d" % _submitted.size())
		return
	var allies := _session.engine.state.living(BattleTypes.Side.ALLY)
	for i in _submitted.size():
		var intent: BattleIntent = _submitted[i]
		if intent.kind != BattleTypes.IntentKind.ATTACK:
			_fail("intent %d is not ATTACK: %s" % [i, str(intent.to_dict())])
			return
		if i >= allies.size() or intent.actor_id != allies[i].id:
			_fail("intent %d actor mismatch: %s" % [i, str(intent.to_dict())])
			return
		var living_enemies := _session.engine.state.living(BattleTypes.Side.ENEMY)
		if intent.target_ids.size() != 1 or not _contains_unit(living_enemies, intent.target_ids[0]):
			_fail("intent %d target is not a living enemy: %s" % [i, str(intent.to_dict())])
			return
	print("HUD_INPUT: phase_submitted with 3 attacks OK")

	if not await _wait_until(func() -> bool: return _session.engine.state.round > initial_round, 10.0):
		_fail("round did not resolve (round=%d)" % _session.engine.state.round)
		return
	print("HUD_INPUT: round resolved %d -> %d" % [initial_round, _session.engine.state.round])
	print("HUD_INPUT_OK")
	_scene.queue_free()
	await process_frame
	quit(0)

func _on_phase_submitted(intents: Array) -> void:
	_submitted = intents.duplicate()
	_submitted_count += 1

func _on_command_phase_started() -> void:
	_phase_started = true

func _check_layout() -> void:
	var views: Array = _session.context.unit_views.values()
	if views.size() != 7:
		_fail("expected 7 unit views, got %d" % views.size())
		return
	var blockers: Array[Control] = []
	for node_name in ["CommandPanel", "BattleLog", "TurnOrderBar", "PlaybackControls", "PartyFleeButton"]:
		var panel := _hud.get_node_or_null(node_name) as Control
		if panel != null and panel.visible:
			blockers.append(panel)
	for value in views:
		var view: UnitView = value
		var point := _to_screen(view.global_position + Vector2(0, -140))
		for panel in blockers:
			if panel.get_global_rect().has_point(point):
				_fail("unit %s click point %s blocked by %s" % [view.unit_id, str(point), panel.name])
				return
	print("HUD_INPUT: 7 unit click points clear of HUD panels")

func _sweep_unit_clicks() -> void:
	var hits := {}
	var views: Array = _session.context.unit_views.values()
	for value in views:
		var view: UnitView = value
		view.clicked.connect(func(clicked_view: UnitView) -> void:
			hits[clicked_view.unit_id] = true
		)
		_click_at(_to_screen(view.global_position + Vector2(0, -140)))
		await physics_frame
		await process_frame
	for value in views:
		var view: UnitView = value
		if not hits.has(view.unit_id):
			_fail("unit %s did not receive a real mouse click" % view.unit_id)
			return
	print("HUD_INPUT: all 7 units received real mouse clicks")

func _to_screen(world_point: Vector2) -> Vector2:
	return root.get_canvas_transform() * world_point

func _find_button(text: String) -> Button:
	var stack: Array[Node] = [_hud]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and node.is_visible_in_tree() and not node.disabled and String(node.text) == text:
			return node
		for child in node.get_children():
			stack.append(child)
	return null

func _click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = point
	press.global_position = point
	root.push_input(press, true)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	release.global_position = point
	root.push_input(release, true)

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
	printerr("HUD_INPUT_FAIL: " + message)
	quit(1)
