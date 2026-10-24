class_name BattleDirector
extends RefCounted

var content: ContentDB
var script_state: EncounterScript
var encounter: EncounterData
# true 时跳过全部剧情 beat（首杀/结局）；开场对白由 BattleSession 按同一标志跳过。
var skip_story := false
var registry := CommandRegistry.new()

func setup(p_content: ContentDB, p_script: EncounterScript = null, p_encounter: EncounterData = null, p_skip_story := false) -> void:
	content = p_content
	script_state = p_script
	encounter = p_encounter
	skip_story = p_skip_story
	registry.content = p_content

func build(events: Array[BattleEvent]) -> Array[BattleCommand]:
	var commands: Array[BattleCommand] = []
	for event in events:
		if event.type == &"battle_end":
			# 结局对白先于结算面板。
			_append_beats(commands, _end_beats(event))
		if event.type == &"action_start":
			_append_shout(commands, event)
		commands.append(registry.create(event))
		if event.type != &"battle_end":
			_append_beats(commands, _event_beats(event))
	return commands

func _end_beats(event: BattleEvent) -> Array:
	if skip_story or script_state == null:
		return []
	return script_state.beats_for_end(int(event.data.get("outcome", BattleTypes.Outcome.NONE)))

func _event_beats(event: BattleEvent) -> Array:
	if skip_story or script_state == null:
		return []
	# 首杀对白只由敌方死亡触发；我方阵亡不能消耗 EncounterScript 的首杀机会。
	if event.type != &"death" or not _is_enemy_death(event):
		return []
	return script_state.beats_for_event(event)

func _is_enemy_death(event: BattleEvent) -> bool:
	if encounter == null:
		return false
	for target_id in event.target_ids:
		if encounter.enemy_unit_ids.has(target_id):
			return true
	return false

func _append_beats(commands: Array[BattleCommand], beats: Array) -> void:
	for beat in beats:
		if String(beat.get("kind", "")) == "dialogue":
			commands.append(DialogueCommand.new(beat.get("lines", [])))

func _append_shout(commands: Array[BattleCommand], event: BattleEvent) -> void:
	if content == null or String(event.data.get("kind", "")) != "skill":
		return
	var skill := content.get_skill(StringName(event.data.get("skill_id", "")))
	if skill == null or skill.shout_text.strip_edges().is_empty():
		return
	commands.append(BubbleCommand.new(skill.shout_text, event.source_id))
