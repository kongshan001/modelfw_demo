class_name EncounterScript
extends Resource

@export var intro_lines: Array[String] = []
@export var first_kill_lines: Array[String] = []
@export var victory_lines: Array[String] = []
@export var defeat_lines: Array[String] = []

var _first_kill_done: bool = false

func reset() -> void:
	_first_kill_done = false

func beats_for_start() -> Array[Dictionary]:
	if intro_lines.is_empty():
		return []
	return [{"kind": "dialogue", "lines": intro_lines}]

func beats_for_event(event: BattleEvent) -> Array[Dictionary]:
	if event.type == &"death" and not _first_kill_done:
		_first_kill_done = true
		if not first_kill_lines.is_empty():
			return [{"kind": "dialogue", "lines": first_kill_lines}]
	return []

func beats_for_end(outcome: int) -> Array[Dictionary]:
	if outcome == BattleTypes.Outcome.VICTORY and not victory_lines.is_empty():
		return [{"kind": "dialogue", "lines": victory_lines}]
	if outcome == BattleTypes.Outcome.DEFEAT and not defeat_lines.is_empty():
		return [{"kind": "dialogue", "lines": defeat_lines}]
	return []
