extends SceneTree

# 输入级 HUD 冒烟：真实鼠标点击「攻击」按钮，再点击敌方 UnitView 选择目标，
# 从首个指令阶段一路打到战斗结束，最后校验真实结算面板出现。
# 同时保留 7 个单位点击扫描与首阶段 3 条攻击意图断言；战斗速度通过真实点击 2x 按钮设置。
# 需要窗口（物理拾取走真实视口输入）：
#   godot --path godot-battle --resolution 1920x1080 -s tools/smoke_hud_input.gd

const PHASE_TIMEOUT := 20.0
const END_TIMEOUT := 30.0
const BATTLE_TIMEOUT := 120.0
const MAX_ROUNDS := 31

var _scene: Node
var _hud: BattleHUD
var _session: BattleSession
var _sequencer: BattleSequencer
var _submitted: Array = []
var _submitted_enemy_ids: Array[StringName] = []
var _submitted_count := 0
var _phase_started := false
var _finished := false
var _outcome := BattleTypes.Outcome.NONE
var _rounds_played := 0
var _deadline_msec := 0

func _initialize() -> void:
	_deadline_msec = Time.get_ticks_msec() + int(BATTLE_TIMEOUT * 1000.0)
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
	_session.battle_finished.connect(_on_battle_finished)
	# 场景 _ready 会同步推进到首个指令阶段，信号可能早于连接。
	if _hud.is_collecting():
		_phase_started = true

	print("HUD_INPUT: window=%s physics_picking=%s skip_story=%s" % [str(root.size), str(root.physics_object_picking), str(_scene.skip_story)])
	if not await _wait_until(func() -> bool: return _phase_started and _hud.is_collecting(), PHASE_TIMEOUT):
		_fail("command phase did not start")
		return
	await _check_layout()
	await _sweep_unit_clicks()
	if not await _click_speed_button():
		_fail("2x speed button click did not set playback speed (speed=%s)" % str(_sequencer.playback_speed))
		return

	# 首阶段：三名存活我方逐一真实点击，校验 phase_submitted 的 3 条攻击意图。
	var initial_round := _session.engine.state.round
	var first_allies: Array = _session.engine.state.living(BattleTypes.Side.ALLY)
	var before := _submitted_count
	var expected := await _play_phase()
	if expected < 0:
		return
	if not await _wait_for_submission(expected, before):
		return
	if not _verify_submitted(first_allies):
		return
	print("HUD_INPUT: first phase_submitted with %d attacks OK" % expected)

	if not await _wait_until(func() -> bool: return _session.engine.state.round > initial_round or _finished, PHASE_TIMEOUT):
		_fail("round did not resolve (round=%d)" % _session.engine.state.round)
		return
	print("HUD_INPUT: round resolved %d -> %d" % [initial_round, _session.engine.state.round])
	_rounds_played = 1

	# 后续回合：持续用真实输入下达攻击，直到引擎结束。
	while not _session.engine.is_over() and not _finished:
		if _rounds_played >= MAX_ROUNDS:
			_fail("round guard exceeded (%d)" % _rounds_played)
			return
		if not await _wait_until(func() -> bool: return _finished or (_hud.is_collecting() and _hud._awaiting_intent and _hud._mode == BattleHUD.MenuMode.ROOT), PHASE_TIMEOUT):
			_fail("next command phase did not start (round=%d collecting=%s)" % [_session.engine.state.round, str(_hud.is_collecting())])
			return
		if _finished or _session.engine.is_over():
			break
		var allies: Array = _session.engine.state.living(BattleTypes.Side.ALLY)
		before = _submitted_count
		expected = await _play_phase()
		if expected < 0:
			return
		if not await _wait_for_submission(expected, before):
			return
		if not _verify_submitted(allies):
			return
		_rounds_played += 1
		if not await _wait_until(func() -> bool: return _finished or _session.engine.is_over() or not _hud.is_collecting(), PHASE_TIMEOUT):
			_fail("phase did not submit (round=%d collecting=%s)" % [_session.engine.state.round, str(_hud.is_collecting())])
			return
		print("HUD_INPUT: round %d submitted %d attacks" % [_rounds_played, expected])

	if not await _wait_until(func() -> bool: return _finished, END_TIMEOUT):
		_fail("battle_finished was not emitted (outcome=%d rounds=%d)" % [_outcome, _rounds_played])
		return
	var victory: VictoryPanel = _scene.get_node("UILayer/VictoryPanel")
	if victory == null or not victory.is_shown():
		_fail("victory panel was not shown after real battle end")
		return
	var title := _result_title(victory)
	if title.is_empty():
		_fail("victory panel has no result title")
		return
	print("HUD_INPUT: battle finished outcome=%d rounds=%d panel=%s" % [_outcome, _rounds_played, title])
	print("HUD_INPUT_OK")
	_scene.queue_free()
	await process_frame
	quit(0)

func _on_phase_submitted(intents: Array) -> void:
	_submitted = intents.duplicate()
	# 在回合结算前快照存活敌方：信号发出后 Session 会立刻 resolve_round，
	# 等到工具轮询到信号时目标可能已经死亡。
	_submitted_enemy_ids = []
	if _session != null and _session.engine != null:
		for enemy in _session.engine.state.living(BattleTypes.Side.ENEMY):
			_submitted_enemy_ids.append(enemy.id)
	_submitted_count += 1

func _on_command_phase_started() -> void:
	_phase_started = true

func _on_battle_finished(outcome: int) -> void:
	_finished = true
	_outcome = outcome

# 对当前指令阶段的所有存活我方：真实点击「攻击」→ 真实点击存活敌方 UnitView。
# 返回该阶段应提交的意图数；失败返回 -1。
func _play_phase() -> int:
	var allies: Array = _session.engine.state.living(BattleTypes.Side.ALLY)
	var submitted := 0
	for index in allies.size():
		if not await _wait_until(func() -> bool: return _hud.is_collecting() and _hud._awaiting_intent and _hud._mode == BattleHUD.MenuMode.ROOT, PHASE_TIMEOUT):
			_fail("ally %d root menu not ready (collecting=%s mode=%d)" % [index, str(_hud.is_collecting()), _hud._mode])
			return -1
		var attack := _find_button("攻击")
		if attack == null:
			_fail("attack button not found by text for ally %d" % index)
			return -1
		var rect := attack.get_global_rect()
		print("HUD_INPUT: click 攻击 ally=%d rect=%s" % [index, str(rect)])
		_click_at(rect.get_center())
		await process_frame
		if _hud._mode != BattleHUD.MenuMode.TARGET:
			_fail("attack click did not enter target mode (ally %d mode=%d)" % [index, _hud._mode])
			return -1

		var enemies: Array = _session.engine.state.living(BattleTypes.Side.ENEMY)
		if enemies.is_empty():
			_fail("no living enemies for ally %d" % index)
			return -1
		var target: BattleUnitState = enemies[index % enemies.size()]
		var view: UnitView = _session.context.unit_view(target.id)
		if view == null:
			_fail("missing UnitView for target %s" % target.id)
			return -1
		var point := _to_screen(view.global_position + Vector2(0, -140))
		print("HUD_INPUT: click target %s at %s" % [target.id, str(point)])
		_click_at(point)
		await physics_frame
		await process_frame
		if _hud._mode == BattleHUD.MenuMode.TARGET and _hud._awaiting_intent:
			# 物理拾取可能晚一帧。
			await physics_frame
			await process_frame
		if _hud._mode == BattleHUD.MenuMode.TARGET and _hud._awaiting_intent:
			_fail("target click did not submit ally %d (mode=%d awaiting=%s)" % [index, _hud._mode, str(_hud._awaiting_intent)])
			return -1
		submitted += 1
	return submitted

func _wait_for_submission(expected: int, before: int) -> bool:
	if not await _wait_until(func() -> bool: return _submitted_count > before, 5.0):
		_fail("phase_submitted was not emitted")
		return false
	if _submitted.size() != expected:
		_fail("phase_submitted expected %d intents, got %d" % [expected, _submitted.size()])
		return false
	return true

func _verify_submitted(allies: Array) -> bool:
	for i in _submitted.size():
		var intent: BattleIntent = _submitted[i]
		if intent.kind != BattleTypes.IntentKind.ATTACK:
			_fail("intent %d is not ATTACK: %s" % [i, str(intent.to_dict())])
			return false
		if i >= allies.size() or intent.actor_id != allies[i].id:
			_fail("intent %d actor mismatch: %s" % [i, str(intent.to_dict())])
			return false
		if intent.target_ids.size() != 1 or not _submitted_enemy_ids.has(intent.target_ids[0]):
			_fail("intent %d target was not a living enemy at submission: %s" % [i, str(intent.to_dict())])
			return false
	print("HUD_INPUT: phase_submitted with %d attacks OK" % _submitted.size())
	return true

func _click_speed_button() -> bool:
	var button := _find_speed_button()
	if button == null:
		return false
	var rect := button.get_global_rect()
	print("HUD_INPUT: click 倍速 rect=%s" % str(rect))
	_click_at(rect.get_center())
	await process_frame
	print("HUD_INPUT: playback speed=%s label=%s" % [str(_sequencer.playback_speed), button.text])
	return _sequencer.playback_speed >= 1.5

func _find_speed_button() -> Button:
	var stack: Array[Node] = [_hud]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and node.is_visible_in_tree() and not node.disabled and String(node.text).begins_with("倍速"):
			return node
		for child in node.get_children():
			stack.append(child)
	return null

func _result_title(panel: VictoryPanel) -> String:
	var stack: Array[Node] = [panel]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label:
			var text := String(node.text).strip_edges()
			if text == "胜利！" or text == "战败…" or text == "逃跑成功":
				return text
		for child in node.get_children():
			stack.append(child)
	return ""

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

func _wait_until(predicate: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return true
		if Time.get_ticks_msec() > _deadline_msec:
			return false
		await create_timer(0.1).timeout
		elapsed += 0.1
	return false

func _fail(message: String) -> void:
	printerr("HUD_INPUT_FAIL: " + message)
	quit(1)
