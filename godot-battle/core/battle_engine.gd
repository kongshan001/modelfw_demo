class_name BattleEngine
extends RefCounted

var content: ContentDB
var encounter: EncounterData
var state: BattleState
var rng: BattleRng
var resolver: BattleResolver
var recorder: BattleRecorder
var seed_value: int
var check_invariants: bool = true

func _init(p_encounter: EncounterData, p_content: ContentDB, p_seed: int, p_record: bool = true) -> void:
	encounter = p_encounter
	content = p_content
	seed_value = p_seed
	rng = BattleRng.new(p_seed)
	state = BattleFactory.create(p_encounter, p_content)
	resolver = BattleResolver.new(state, rng, p_content)
	recorder = BattleRecorder.new() if p_record else null
	if recorder != null:
		recorder.begin(p_encounter, p_seed, p_content.content_hash(), state)

func resolve_round(intents: Array[BattleIntent]) -> Array[BattleEvent]:
	if state.is_over():
		return []
	if recorder != null:
		recorder.record_snapshot(state.round + 1, state)
		recorder.record_intents(state.round + 1, intents)
	var events := resolver.resolve_round(intents)
	if recorder != null:
		recorder.record_round_events(events)
	if check_invariants:
		var issues := BattleInvariants.check(state)
		for issue in issues:
			push_error("INVARIANT: " + issue)
		if not issues.is_empty() and recorder != null:
			dump_replay()
	if state.is_over() and recorder != null:
		recorder.finish(state)
	return events

func apply_debug_op(op: Dictionary) -> void:
	if recorder != null:
		recorder.record_debug_op(state.round + 1, op)
	match String(op.get("op", "")):
		"kill":
			var kill_unit := state.get_unit(StringName(op.get("unit_id", "")))
			if kill_unit != null and kill_unit.is_alive():
				kill_unit.hp = 0
				kill_unit.alive = false
				kill_unit.statuses.clear()
		"set_hp":
			var hp_unit := state.get_unit(StringName(op.get("unit_id", "")))
			if hp_unit != null:
				hp_unit.hp = clampi(int(op.get("hp", hp_unit.hp)), 0, hp_unit.data.max_hp)
				hp_unit.alive = hp_unit.hp > 0
		"add_status":
			var status_unit := state.get_unit(StringName(op.get("unit_id", "")))
			var status_data := content.get_status(StringName(op.get("status_id", "")))
			if status_unit != null and status_data != null:
				status_unit.add_status(status_data, state.round)
		_:
			push_warning("Unknown debug op: " + String(op.get("op", "")))

func is_over() -> bool:
	return state.is_over()

func outcome() -> int:
	return state.outcome

func dump_replay(path: String = "") -> String:
	if recorder == null:
		return ""
	recorder.finish(state)
	return recorder.save(path)
