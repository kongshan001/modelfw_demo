extends SceneTree

# 输入级 HUD 冒烟：真实鼠标点击「攻击」按钮 + 真实数字键 1–4 选择目标，
# 从首个指令阶段一路打到战斗结束，最后校验真实结算面板出现。
#
# 紧凑菱形阵型（参考 FWJ）：每侧一个前排尖端，后排围绕中央石环展开，
# 命中区允许屏幕空间重叠。因此不再断言单位点击矩形互不相交，也不再做全单位边界点击扫描；
# 改为验证：
#   - 1–4 键可选每个存活敌方槽位，Q/W/E 键可选每个存活我方槽位；
#   - 单一目标箭头默认落在尖端，鼠标点击敌方/我方尖端均能提交；
#   - 全部命中区/信息带避开 HUD 面板，尖端点击点不被其他命中区抢走；
#   - 完整 12 回合真实输入战斗到结算面板。
# 需要窗口（物理拾取走真实视口输入）：
#   godot --path godot-battle --resolution 1920x1080 -s tools/smoke_hud_input.gd

const PHASE_TIMEOUT := 20.0
const END_TIMEOUT := 30.0
const BATTLE_TIMEOUT := 120.0
const MAX_ROUNDS := 31
const TIP_CLICK_OFFSET := Vector2(0, -120)

var _scene: Node
var _hud: BattleHUD
var _session: BattleSession
var _sequencer: BattleSequencer
var _submitted: Array = []
var _submitted_enemy_ids: Array[StringName] = []
var _expected_targets: Array[StringName] = []
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
	if not _check_layout():
		return
	if not await _probe_target_keys():
		return
	if not await _probe_tip_clicks():
		return
	if not await _click_speed_button():
		_fail("2x speed button click did not set playback speed (speed=%s)" % str(_sequencer.playback_speed))
		return

	# 首阶段：三名存活我方逐一真实点击「攻击」+ 真实数字键，校验 3 条攻击意图。
	var initial_round := _session.engine.state.round
	var first_allies := _living_sorted(BattleTypes.Side.ALLY)
	var before := _submitted_count
	var expected := await _play_phase()
	if expected < 0:
		return
	if not await _wait_for_submission(expected, before):
		return
	if not _verify_submitted(first_allies):
		return
	print("HUD_INPUT: first phase_submitted with %d key-selected attacks OK" % expected)

	if not await _wait_until(func() -> bool: return _session.engine.state.round > initial_round or _finished, PHASE_TIMEOUT):
		_fail("round did not resolve (round=%d)" % _session.engine.state.round)
		return
	print("HUD_INPUT: round resolved %d -> %d" % [initial_round, _session.engine.state.round])
	_rounds_played = 1

	# 后续回合：持续用真实鼠标 + 数字键下达攻击，直到引擎结束。
	while not _session.engine.is_over() and not _finished:
		if _rounds_played >= MAX_ROUNDS:
			_fail("round guard exceeded (%d)" % _rounds_played)
			return
		if not await _wait_until(func() -> bool: return _finished or _root_ready(), PHASE_TIMEOUT):
			_fail("next command phase did not start (round=%d collecting=%s)" % [_session.engine.state.round, str(_hud.is_collecting())])
			return
		if _finished or _session.engine.is_over():
			break
		var allies := _living_sorted(BattleTypes.Side.ALLY)
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

# ---------------------------------------------------------------- 目标键探针

# 1–4 / QWE 逐一选择每个存活槽位：进入目标模式 → 按真实键 → 校验意图目标 → 返回。
func _probe_target_keys() -> bool:
	var enemies := _living_sorted(BattleTypes.Side.ENEMY)
	for enemy in enemies:
		if not await _open_root_button("攻击"):
			return false
		if _hud._mode != BattleHUD.MenuMode.TARGET:
			_fail("attack click did not enter enemy target mode (mode=%d)" % _hud._mode)
			return false
		if not _check_single_arrow(&"boss_brute", "enemy target mode"):
			return false
		if not _check_target_prompt():
			return false
		var key := KEY_1 + enemy.slot
		print("HUD_INPUT: press %s for enemy slot %d (%s)" % [OS.get_keycode_string(key), enemy.slot, enemy.id])
		if not await _press_key_and_check(key, enemy.id, "enemy key %s" % OS.get_keycode_string(key)):
			return false
		if not await _return_to_root():
			return false

	for ally in _living_sorted(BattleTypes.Side.ALLY):
		if not await _open_ally_target_mode():
			return false
		if not _check_single_arrow(&"hero_swordsman", "ally target mode"):
			return false
		var key := KEY_Q
		match ally.slot:
			0:
				key = KEY_Q
			1:
				key = KEY_W
			2:
				key = KEY_E
			_:
				_fail("unexpected ally slot %d" % ally.slot)
				return false
		print("HUD_INPUT: press %s for ally slot %d (%s)" % [OS.get_keycode_string(key), ally.slot, ally.id])
		if not await _press_key_and_check(key, ally.id, "ally key %s" % OS.get_keycode_string(key)):
			return false
		if not await _return_to_root():
			return false

	if _hud._ally_index != 0 or not _hud._intents.is_empty():
		_fail("target key probes left HUD state dirty (index=%d intents=%d)" % [_hud._ally_index, _hud._intents.size()])
		return false
	print("HUD_INPUT: 1–4 keys selected all %d enemy slots; QWE keys selected all %d ally slots" % [enemies.size(), _living_sorted(BattleTypes.Side.ALLY).size()])
	return true

# 真实鼠标点击敌方尖端（妖将）与我方尖端（剑客），校验提交目标。
func _probe_tip_clicks() -> bool:
	var brute: UnitView = _view_of(&"boss_brute")
	var swordsman: UnitView = _view_of(&"hero_swordsman")
	if brute == null or swordsman == null:
		_fail("missing tip unit views")
		return false

	if not await _open_root_button("攻击"):
		return false
	if _hud._mode != BattleHUD.MenuMode.TARGET:
		_fail("attack click did not enter enemy target mode (mode=%d)" % _hud._mode)
		return false
	if not _check_single_arrow(&"boss_brute", "enemy tip click"):
		return false
	# 悬停后箭头移动到当前悬停目标，且仍然只有一个箭头。
	var fox: UnitView = _view_of(&"boss_fox")
	if fox == null:
		_fail("missing boss_fox for hover probe")
		return false
	_move_mouse(_to_screen(fox.global_position + TIP_CLICK_OFFSET))
	await physics_frame
	await process_frame
	if not _check_single_arrow(&"boss_fox", "hover"):
		return false
	print("HUD_INPUT: hover moved the single target arrow to boss_fox")
	var enemy_tip_point := _to_screen(brute.global_position + TIP_CLICK_OFFSET)
	print("HUD_INPUT: click enemy tip %s at %s" % [brute.unit_id, str(enemy_tip_point)])
	_click_at(enemy_tip_point)
	await physics_frame
	await process_frame
	if not await _wait_until(func() -> bool: return _root_ready(), 3.0):
		_fail("enemy tip click did not submit (mode=%d awaiting=%s)" % [_hud._mode, str(_hud._awaiting_intent)])
		return false
	if not _last_intent_targets(brute.unit_id):
		return false
	if not await _return_to_root():
		return false

	if not await _open_ally_target_mode():
		return false
	if not _check_single_arrow(&"hero_swordsman", "ally tip click"):
		return false
	var ally_tip_point := _to_screen(swordsman.global_position + TIP_CLICK_OFFSET)
	print("HUD_INPUT: click ally tip %s at %s" % [swordsman.unit_id, str(ally_tip_point)])
	_click_at(ally_tip_point)
	await physics_frame
	await process_frame
	if not await _wait_until(func() -> bool: return _root_ready(), 3.0):
		_fail("ally tip click did not submit (mode=%d awaiting=%s)" % [_hud._mode, str(_hud._awaiting_intent)])
		return false
	if not _last_intent_targets(swordsman.unit_id):
		return false
	if not await _return_to_root():
		return false
	print("HUD_INPUT: tip clicks submitted boss_brute and hero_swordsman")
	return true

func _press_key_and_check(keycode: int, expected_target: StringName, label: String) -> bool:
	_press_key(keycode)
	await process_frame
	if not await _wait_until(func() -> bool: return _root_ready(), 3.0):
		_fail("%s did not submit (mode=%d awaiting=%s)" % [label, _hud._mode, str(_hud._awaiting_intent)])
		return false
	if not _last_intent_targets(expected_target):
		return false
	return true

func _return_to_root() -> bool:
	_hud.go_back()
	await process_frame
	if not await _wait_until(func() -> bool: return _root_ready(), 3.0):
		_fail("go_back did not restore root menu (mode=%d awaiting=%s)" % [_hud._mode, str(_hud._awaiting_intent)])
		return false
	return true

func _last_intent_targets(expected: StringName) -> bool:
	if _hud._intents.is_empty():
		_fail("expected intent targeting %s but HUD intent list is empty" % expected)
		return false
	var intent: BattleIntent = _hud._intents[_hud._intents.size() - 1]
	if intent.target_ids.size() != 1 or intent.target_ids[0] != expected:
		_fail("intent target mismatch: expected %s got %s" % [expected, str(intent.to_dict())])
		return false
	return true

func _check_single_arrow(expected: StringName, label: String) -> bool:
	var highlighted: Array[StringName] = []
	for value in _session.context.unit_views.values():
		var view: UnitView = value
		if view.is_target_highlighted():
			highlighted.append(view.unit_id)
	if highlighted.size() != 1 or highlighted[0] != expected:
		_fail("%s: expected single arrow on %s, got %s" % [label, expected, str(highlighted)])
		return false
	return true

func _check_target_prompt() -> bool:
	if not _has_label_text("1–4 / QWE 选择目标"):
		_fail("target prompt does not show '1–4 / QWE 选择目标'")
		return false
	if not _has_label_text("目标键位："):
		_fail("target prompt does not show the key-to-slot mapping")
		return false
	return true

# ---------------------------------------------------------------- 回合指令

# 对当前指令阶段的所有存活我方：真实点击「攻击」→ 真实按数字键选择敌方槽位。
# 返回该阶段应提交的意图数；失败返回 -1。
func _play_phase() -> int:
	var allies := _living_sorted(BattleTypes.Side.ALLY)
	_expected_targets.clear()
	var submitted := 0
	for index in allies.size():
		if not await _wait_until(func() -> bool: return _root_ready(), PHASE_TIMEOUT):
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

		var enemies := _living_sorted(BattleTypes.Side.ENEMY)
		if enemies.is_empty():
			_fail("no living enemies for ally %d" % index)
			return -1
		var target: BattleUnitState = enemies[index % enemies.size()]
		var key := KEY_1 + target.slot
		print("HUD_INPUT: press %s -> %s (slot %d) for ally %d" % [OS.get_keycode_string(key), target.id, target.slot, index])
		_press_key(key)
		await process_frame
		if _hud._mode == BattleHUD.MenuMode.TARGET and _hud._awaiting_intent:
			# 输入分发可能晚一帧。
			await process_frame
		if _hud._mode == BattleHUD.MenuMode.TARGET and _hud._awaiting_intent:
			_fail("digit key did not submit ally %d (mode=%d)" % [index, _hud._mode])
			return -1
		if _hud._intents.size() != submitted + 1:
			_fail("intent count mismatch after key: expected %d got %d" % [submitted + 1, _hud._intents.size()])
			return -1
		var last: BattleIntent = _hud._intents[_hud._intents.size() - 1]
		if last.actor_id != allies[index].id or last.target_ids.size() != 1 or last.target_ids[0] != target.id:
			_fail("key-selected intent mismatch for ally %d: %s" % [index, str(last.to_dict())])
			return -1
		_expected_targets.append(target.id)
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
	if _expected_targets.size() != _submitted.size():
		_fail("expected target list %d != submitted %d" % [_expected_targets.size(), _submitted.size()])
		return false
	for i in _submitted.size():
		var intent: BattleIntent = _submitted[i]
		if intent.kind != BattleTypes.IntentKind.ATTACK:
			_fail("intent %d is not ATTACK: %s" % [i, str(intent.to_dict())])
			return false
		if i >= allies.size() or intent.actor_id != allies[i].id:
			_fail("intent %d actor mismatch: %s" % [i, str(intent.to_dict())])
			return false
		if intent.target_ids.size() != 1 or intent.target_ids[0] != _expected_targets[i]:
			_fail("intent %d target %s != key-selected %s" % [i, str(intent.target_ids), _expected_targets[i]])
			return false
		if not _submitted_enemy_ids.has(intent.target_ids[0]):
			_fail("intent %d target was not a living enemy at submission: %s" % [i, str(intent.to_dict())])
			return false
	print("HUD_INPUT: phase_submitted with %d key-selected attacks OK" % _submitted.size())
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

# ---------------------------------------------------------------- 阵型布局探针

func _check_layout() -> bool:
	var views: Array = _session.context.unit_views.values()
	if views.size() != 7:
		_fail("expected 7 unit views, got %d" % views.size())
		return false
	var world := _scene.get_node_or_null("World") as Node2D
	if world == null or not world.y_sort_enabled:
		_fail("World.y_sort_enabled must be true for front-row-over-back-row draw order")
		return false

	var blockers: Array[Control] = []
	for node_name in ["CommandPanel", "BattleLog", "TurnOrderBar", "PlaybackControls", "PartyFleeButton"]:
		var panel := _hud.get_node_or_null(node_name) as Control
		if panel != null and panel.visible:
			blockers.append(panel)

	var layout := BattleFieldLayout.new()
	var ally_views: Array[UnitView] = []
	var enemy_views: Array[UnitView] = []
	var ally_tips: Array[UnitView] = []
	var enemy_tips: Array[UnitView] = []
	var ally_depth_min := INF
	var enemy_depth_max := -INF
	var ally_center_sum := Vector2.ZERO
	var enemy_center_sum := Vector2.ZERO
	var hit_overlap_pairs := 0
	var info_overlap_pairs := 0

	for value in views:
		var view: UnitView = value
		if view.get_parent() != world:
			_fail("unit %s is not a direct child of World (y-sort ineffective)" % view.unit_id)
			return false
		var slot := layout.slot(view.side, view.unit_state.slot)
		if slot.is_empty():
			_fail("missing formation slot for %s side=%d slot=%d" % [view.unit_id, view.side, view.unit_state.slot])
			return false
		var expected_pos: Vector2 = slot["pos"]
		if view.home_position.distance_to(expected_pos) > 0.5:
			_fail("unit %s home %s != formation slot %s" % [view.unit_id, str(view.home_position), str(expected_pos)])
			return false
		if absf(view._formation_depth - float(slot["depth"])) > 0.001:
			_fail("unit %s depth %.3f != slot %.3f" % [view.unit_id, view._formation_depth, float(slot["depth"])])
			return false
		if view._facing != int(slot["art_flip"]):
			_fail("unit %s facing %d != slot %d" % [view.unit_id, view._facing, int(slot["art_flip"])])
			return false
		if view.art_view() != String(slot["view"]):
			_fail("unit %s art_view %s != slot %s" % [view.unit_id, view.art_view(), String(slot["view"])])
			return false
		if view.is_ally != (view.side == BattleTypes.Side.ALLY):
			_fail("unit %s ally flag mismatch" % view.unit_id)
			return false
		if view.is_ally and view.art_view() != "back":
			_fail("ally %s must use back view (got %s)" % [view.unit_id, view.art_view()])
			return false
		if not view.is_ally and view.art_view() != "front":
			_fail("enemy %s must use front view (got %s)" % [view.unit_id, view.art_view()])
			return false
		if absf(view.visual_scale() - view._art_scale * UnitView.BASE_ART_SCALE * float(slot["depth"])) > 0.001:
			_fail("unit %s visual_scale %.3f does not include base scale + formation depth" % [view.unit_id, view.visual_scale()])
			return false
		if view.is_target_highlighted():
			_fail("target arrow visible before target mode for %s" % view.unit_id)
			return false

		var hit := view.hit_rect()
		var info := view.info_rect()
		for panel in blockers:
			var panel_rect := panel.get_global_rect()
			if hit.intersects(panel_rect):
				_fail("unit %s hit rect %s overlaps %s %s" % [view.unit_id, str(hit), panel.name, str(panel_rect)])
				return false
			if info.intersects(panel_rect):
				_fail("unit %s info rect %s overlaps %s %s" % [view.unit_id, str(info), panel.name, str(panel_rect)])
				return false
		if not hit.has_point(view.global_position + TIP_CLICK_OFFSET):
			_fail("unit %s body click point is outside its hit rect %s" % [view.unit_id, str(hit)])
			return false

		if int(slot["row"]) == 1:
			if view.is_ally:
				ally_tips.append(view)
				if view.unit_id != &"hero_swordsman":
					_fail("ally tip must be hero_swordsman, got %s" % view.unit_id)
					return false
			else:
				enemy_tips.append(view)
				if view.unit_id != &"boss_brute":
					_fail("enemy tip must be boss_brute, got %s" % view.unit_id)
					return false
		if view.is_ally:
			ally_views.append(view)
			ally_depth_min = minf(ally_depth_min, view._formation_depth)
			ally_center_sum += view.home_position
		else:
			enemy_views.append(view)
			enemy_depth_max = maxf(enemy_depth_max, view._formation_depth)
			enemy_center_sum += view.home_position
			if view.home_position.y <= BackgroundView._clearing_edge_y(view.home_position.x) + 8.0:
				_fail("enemy %s at %s is not on the clearing (edge y %.0f)" % [view.unit_id, str(view.home_position), BackgroundView._clearing_edge_y(view.home_position.x)])
				return false

	# 命中区/信息带允许重叠，仅统计并打印；不再要求 x 区间互不相交。
	for i in views.size():
		for j in range(i + 1, views.size()):
			var a: UnitView = views[i]
			var b: UnitView = views[j]
			if a.hit_rect().intersects(b.hit_rect()):
				hit_overlap_pairs += 1
			if a.info_rect().intersects(b.info_rect()):
				info_overlap_pairs += 1

	if ally_tips.size() != 1 or enemy_tips.size() != 1:
		_fail("expected exactly one tip per side, got ally=%d enemy=%d" % [ally_tips.size(), enemy_tips.size()])
		return false
	var ally_tip := ally_tips[0]
	var enemy_tip := enemy_tips[0]

	# 尖端点击点不得落入其他单位命中区（后排可以重叠，但尖端必须稳定可点）。
	for pair in [[ally_tip, views], [enemy_tip, views]]:
		var tip: UnitView = pair[0]
		var point := tip.global_position + TIP_CLICK_OFFSET
		for value in pair[1]:
			var other: UnitView = value
			if other == tip:
				continue
			if other.hit_rect().has_point(point):
				_fail("tip %s click point %s is stolen by %s hit rect %s" % [tip.unit_id, str(point), other.unit_id, str(other.hit_rect())])
				return false

	var tip_distance := ally_tip.home_position.distance_to(enemy_tip.home_position)
	var min_cross := INF
	for ally in ally_views:
		for enemy in enemy_views:
			min_cross = minf(min_cross, ally.home_position.distance_to(enemy.home_position))
	if absf(min_cross - tip_distance) > 0.01:
		_fail("tips must be the closest opposing pair: tips=%.2f min cross=%.2f" % [tip_distance, min_cross])
		return false
	var tip_mid := (ally_tip.home_position + enemy_tip.home_position) * 0.5
	if tip_mid.distance_to(BackgroundView.RING_CENTER) > 2.0:
		_fail("tip midpoint %s is not on the central ring %s" % [str(tip_mid), str(BackgroundView.RING_CENTER)])
		return false

	var ally_center := ally_center_sum / float(ally_views.size())
	var enemy_center := enemy_center_sum / float(enemy_views.size())
	var center_angle := rad_to_deg(atan2(ally_center.y - enemy_center.y, ally_center.x - enemy_center.x))
	if center_angle < 20.0 or center_angle > 45.0:
		_fail("formation center line must be diagonal 20°~45°; got %.1f° (ally=%s enemy=%s)" % [center_angle, str(ally_center), str(enemy_center)])
		return false
	if ally_depth_min <= enemy_depth_max:
		_fail("ally side must be closer (min depth %.2f > enemy max %.2f)" % [ally_depth_min, enemy_depth_max])
		return false
	if ally_center.y <= enemy_center.y:
		_fail("ally side must be lower/closer (ally y %.0f <= enemy y %.0f)" % [ally_center.y, enemy_center.y])
		return false

	print("HUD_INPUT: unit hit rects intentionally overlap in compact diamond: hit pairs=%d info pairs=%d (keys + single arrow are the stable selection)" % [hit_overlap_pairs, info_overlap_pairs])
	print("HUD_INPUT: formation OK tips %s/%s distance=%.1f midpoint=%s ring=%s; centers ally=%s enemy=%s angle=%.1f°; depth ally_min=%.2f > enemy_max=%.2f; y_sort=on; %d HUD blockers clear" % [
		ally_tip.unit_id, enemy_tip.unit_id, tip_distance, str(tip_mid), str(BackgroundView.RING_CENTER),
		str(ally_center), str(enemy_center), center_angle, ally_depth_min, enemy_depth_max, blockers.size(),
	])
	return true

# ---------------------------------------------------------------- 输入辅助

func _root_ready() -> bool:
	return _hud._mode == BattleHUD.MenuMode.ROOT and _hud._awaiting_intent

func _open_root_button(text: String) -> bool:
	if not await _wait_until(func() -> bool: return _root_ready(), 3.0):
		_fail("root menu not ready before %s (mode=%d awaiting=%s)" % [text, _hud._mode, str(_hud._awaiting_intent)])
		return false
	var button := _find_button(text)
	if button == null:
		_fail("button %s not found (mode=%d)" % [text, _hud._mode])
		return false
	_click_at(button.get_global_rect().get_center())
	await process_frame
	return true

func _open_ally_target_mode() -> bool:
	if not await _open_root_button("道具"):
		return false
	if _hud._mode != BattleHUD.MenuMode.ITEMS:
		_fail("item click did not enter items menu (mode=%d)" % _hud._mode)
		return false
	var item := _find_button_prefix("金疮药")
	if item == null:
		_fail("potion button not found in item menu")
		return false
	_click_at(item.get_global_rect().get_center())
	await process_frame
	if _hud._mode != BattleHUD.MenuMode.TARGET:
		_fail("item click did not enter ally target mode (mode=%d)" % _hud._mode)
		return false
	if _hud._selector.side() != BattleTypes.Side.ALLY:
		_fail("item target mode side is not ALLY")
		return false
	return true

func _move_mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)

func _press_key(keycode: int) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	root.push_input(press)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	root.push_input(release)

func _view_of(unit_id: StringName) -> UnitView:
	return _session.context.unit_view(unit_id)

func _living_sorted(side: int) -> Array[BattleUnitState]:
	var units: Array[BattleUnitState] = _session.engine.state.living(side)
	units.sort_custom(func(a: BattleUnitState, b: BattleUnitState) -> bool: return a.slot < b.slot)
	return units

func _has_label_text(needle: String) -> bool:
	var stack: Array[Node] = [_hud]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label and String(node.text).contains(needle):
			return true
		for child in node.get_children():
			stack.append(child)
	return false

func _find_button_prefix(prefix: String) -> Button:
	var stack: Array[Node] = [_hud]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and node.is_visible_in_tree() and not node.disabled and String(node.text).begins_with(prefix):
			return node
		for child in node.get_children():
			stack.append(child)
	return null

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
