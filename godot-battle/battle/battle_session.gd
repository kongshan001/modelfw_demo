class_name BattleSession
extends Node

signal battle_finished(outcome: int)

var content: ContentDB
var encounter: EncounterData
var engine: BattleEngine
var context: BattleContext
var director := BattleDirector.new()
var sequencer: BattleSequencer
var auto_mode := false
var seed_value := 20261024
var _script_state: EncounterScript

func start(p_seed: int = 20261024) -> void:
	seed_value = p_seed
	content = ContentDB.load_all()
	encounter = content.get_encounter(&"enc_bamboo_01")
	engine = BattleEngine.new(encounter, content, seed_value)
	_script_state = encounter.script_data
	if _script_state != null:
		_script_state.reset()
	sequencer.ctx = context
	context.session = self
	context.sequencer = sequencer
	_build_units()
	if auto_mode:
		auto_play()
	else:
		await _run_battle()

func _build_units() -> void:
	var enemy_positions := [Vector2(330, 700), Vector2(500, 740), Vector2(670, 780), Vector2(840, 820)]
	var ally_positions := [Vector2(1500, 790), Vector2(1330, 760), Vector2(1160, 730)]
	for index in engine.state.units.size():
		var unit := engine.state.units[index]
		var view := UnitView.new()
		context.scene.add_child(view)
		var is_ally := unit.side == BattleTypes.Side.ALLY
		var pos: Vector2 = ally_positions[unit.slot] if is_ally else enemy_positions[unit.slot]
		view.setup(unit, pos, is_ally)
		context.unit_views[unit.id] = view

func _run_battle() -> void:
	if _script_state != null and context.hud != null:
		for beat in _script_state.beats_for_start():
			await context.hud.play_beat(beat)
	while not engine.is_over():
		var intents: Array[BattleIntent]
		if auto_mode or context.hud == null:
			intents = _auto_intents()
		else:
			intents = await context.hud.collect_intents(engine, content)
		var events := engine.resolve_round(intents)
		for command in director.build(events):
			sequencer.enqueue(command)
		await sequencer.play_all()
		if context.hud != null:
			context.hud.refresh_all(engine.state)
	battle_finished.emit(engine.state.outcome)

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
	var label := Label.new()
	label.text = "胜利！" if outcome == BattleTypes.Outcome.VICTORY else ("逃跑成功" if outcome == BattleTypes.Outcome.ESCAPED else "战败…")
	label.add_theme_font_override("font", FontUtil.cjk_font())
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(660, 380)
	label.size = Vector2(600, 100)
	context.ui_layer.add_child(label)
