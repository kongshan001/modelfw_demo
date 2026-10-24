class_name BattleDirector
extends RefCounted

var content: ContentDB
var script_state: EncounterScript
var registry := CommandRegistry.new()

func setup(p_content: ContentDB, p_script: EncounterScript = null) -> void:
	content = p_content
	script_state = p_script
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
	if script_state == null:
		return []
	return script_state.beats_for_end(int(event.data.get("outcome", BattleTypes.Outcome.NONE)))

func _event_beats(event: BattleEvent) -> Array:
	if script_state == null:
		return []
	return script_state.beats_for_event(event)

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
