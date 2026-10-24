class_name BattleSession
extends Node

signal battle_finished(outcome: int)
signal command_phase_started

var content: ContentDB
var encounter: EncounterData
var engine: BattleEngine
var context: BattleContext
var director := BattleDirector.new()
var sequencer: BattleSequencer
var auto_mode := false
var skip_story := false
var seed_value := 20261024
var replay_mode := false
var replay_path := ""
var replay_data: Dictionary = {}
var _script_state: EncounterScript
var _result_shown := false
var _replay_label: Control

func start(p_seed: int = 20261024) -> void:
	content = ContentDB.load_all()
	var pending := _consume_pending_replay()
	if not pending.is_empty():
		if _setup_replay(pending):
			await _run_replay()
			return
		push_error("REPLAY_FAIL: cannot load replay " + pending)
	replay_mode = false
	encounter = content.get_encounter(&"enc_bamboo_01")
	_prepare(p_seed, true)
	if auto_mode:
		auto_play()
	else:
		await _run_battle()

func _consume_pending_replay() -> String:
	if not OS.is_debug_build():
		return ""
	var debug := get_node_or_null("/root/BattleDebug")
	if debug == null or not debug.has_method("consume_pending_replay"):
		return ""
	return String(debug.consume_pending_replay())

func _setup_replay(pending: String) -> bool:
	var loaded := BattleReplay.load_file(pending)
	var meta: Variant = loaded.get("meta", {})
	var replay_encounter: EncounterData = null
	if meta is Dictionary:
		replay_encounter = content.get_encounter(StringName(meta.get("battle_id", "")))
	if loaded.is_empty() or replay_encounter == null:
		return false
	replay_mode = true
	replay_path = pending
	replay_data = loaded
	encounter = replay_encounter
	skip_story = true
	_prepare(int(meta.get("seed", 0)), false)
	if context.hud != null:
		context.hud.visible = false
		if context.hud.has_method("set_command_visible"):
			context.hud.set_command_visible(false)
	_show_replay_label()
	return true

func _prepare(p_seed: int, record: bool) -> void:
	seed_value = p_seed
	_script_state = encounter.script_data
	if _script_state != null:
		_script_state.reset()
	director.setup(content, _script_state, encounter, skip_story)
	engine = BattleEngine.new(encounter, content, seed_value, record)
	_result_shown = false
	sequencer.ctx = context
	context.session = self
	context.sequencer = sequencer
	if context.audio != null:
		context.audio.play_bgm(encounter.bgm_path)
	_build_units()
	_register_debug()

func _register_debug() -> void:
	var debug := get_node_or_null("/root/BattleDebug")
	if debug != null and debug.has_method("register_session"):
		debug.register_session(self)

func _run_replay() -> void:
	var rounds: Array = replay_data.get("rounds", []).duplicate()
	rounds.sort_custom(func(a, b): return int(a.get("round", 0)) < int(b.get("round", 0)))
	for entry in rounds:
		if engine.is_over():
			break
		for op in entry.get("debug_ops", []):
			engine.apply_debug_op(op)
		if entry.has("resolved") and not bool(entry["resolved"]):
			continue
		var intents: Array[BattleIntent] = []
		for intent_dict in entry.get("intents", []):
			intents.append(BattleIntent.from_dict(intent_dict))
		var events := engine.resolve_round(intents)
		for command in director.build(events):
			sequencer.enqueue(command)
		await sequencer.play_all()
		context.apply_snapshot(engine.state)
	print("REPLAY_OK %s rounds=%d outcome=%d" % [replay_path, engine.state.round, engine.state.outcome])
	show_result(engine.state.outcome)
	battle_finished.emit(engine.state.outcome)

func _show_replay_label() -> void:
	if context == null or context.ui_layer == null:
		return
	var panel := PanelContainer.new()
	panel.name = "ReplayLabel"
	panel.position = Vector2(1416, 18)
	panel.custom_minimum_size = Vector2(470, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.06, 0.86)
	style.border_color = Color(0.9, 0.68, 0.3, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "回放模式 · F1 控制台 · F6/F7 单步 · ESC 退出"
	label.add_theme_font_override("font", FontUtil.cjk_font())
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.6))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	context.ui_layer.add_child(panel)
	_replay_label = panel

func _build_units() -> void:
	var enemy_positions := [Vector2(180, 700), Vector2(350, 740), Vector2(500, 780), Vector2(700, 820)]
	# 剑客贴指令面板左侧（命中区右缘 1355，面板 1368，留 13px）；
	# 法师/医师向左展开，避免法球与右尾落入相邻命中区。
	var ally_positions := [Vector2(1290, 760), Vector2(1120, 730), Vector2(940, 700)]
	for index in engine.state.units.size():
		var unit := engine.state.units[index]
		var view := UnitView.new()
		context.scene.add_child(view)
		var is_ally := unit.side == BattleTypes.Side.ALLY
		var pos: Vector2 = ally_positions[unit.slot] if is_ally else enemy_positions[unit.slot]
		view.setup(unit, pos, is_ally)
		context.unit_views[unit.id] = view

func _run_battle() -> void:
	if not skip_story and _script_state != null:
		for beat in _script_state.beats_for_start():
			await _play_beat(beat)
	while not engine.is_over():
		var intents: Array[BattleIntent]
		if auto_mode or context.hud == null:
			intents = _auto_intents()
		else:
			command_phase_started.emit()
			intents = await context.hud.collect_intents(engine, content)
		if context.hud != null and context.hud.has_method("set_command_visible"):
			context.hud.set_command_visible(false)
		var events := engine.resolve_round(intents)
		for command in director.build(events):
			sequencer.enqueue(command)
		await sequencer.play_all()
		context.apply_snapshot(engine.state)
	show_result(engine.state.outcome)
	battle_finished.emit(engine.state.outcome)

func _play_beat(beat: Dictionary) -> void:
	if context.hud != null and context.hud.has_method("play_beat"):
		await context.hud.play_beat(beat)
	elif context.dialogue != null and String(beat.get("kind", "")) == "dialogue":
		await context.dialogue.play_lines(beat.get("lines", []))
	else:
		await context.wait(0.2)

func auto_play() -> void:
	auto_mode = true
	await _run_battle()

func _auto_intents() -> Array[BattleIntent]:
	var intents: Array[BattleIntent] = []
	var allies := engine.state.living(BattleTypes.Side.ALLY)
	var enemies := engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		return intents
	for ally in allies:
		if ally.id == &"hero_healer" and ally.mp >= 30:
			var target := _lowest_ally(allies)
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [target.id], &"heal_single"))
		elif ally.id == &"hero_mage" and ally.mp >= 25:
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [enemies[0].id], &"fire_spell"))
		else:
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.ATTACK, [enemies[0].id]))
	return intents

func _lowest_ally(allies: Array[BattleUnitState]) -> BattleUnitState:
	var sorted := allies.duplicate()
	sorted.sort_custom(func(a, b): return float(a.hp) / a.data.max_hp < float(b.hp) / b.data.max_hp)
	return sorted[0] if not sorted.is_empty() else null


func show_result(outcome: int) -> void:
	if _result_shown:
		return
	_result_shown = true
	if _replay_label != null and is_instance_valid(_replay_label):
		_replay_label.visible = false
	if context == null:
		return
	if context.dialogue != null:
		context.dialogue.hide_now()
	if context.bubble != null:
		context.bubble.hide_now()
	var exp := encounter.reward_exp if encounter != null else 0
	var gold := encounter.reward_gold if encounter != null else 0
	if context.victory_panel != null:
		context.victory_panel.show_panel(outcome, exp, gold)
		return
	# 无面板节点时的降级：保留标题 Label，便于无 UI 层场景/旧冒烟检查。
	var label := Label.new()
	label.text = "胜利！" if outcome == BattleTypes.Outcome.VICTORY else ("逃跑成功" if outcome == BattleTypes.Outcome.ESCAPED else "战败…")
	label.add_theme_font_override("font", FontUtil.cjk_font())
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(660, 380)
	label.size = Vector2(600, 100)
	if context.ui_layer != null:
		context.ui_layer.add_child(label)
