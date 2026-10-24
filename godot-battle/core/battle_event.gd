class_name BattleEvent
extends RefCounted

var seq: int = 0
var round: int = 0
var type: StringName = &""
var source_id: StringName = &""
var target_ids: Array[StringName] = []
var data: Dictionary = {}

static func make(p_seq: int, p_round: int, p_type: StringName, p_source: StringName, p_targets: Array, p_data: Dictionary = {}) -> BattleEvent:
	var event := BattleEvent.new()
	event.seq = p_seq
	event.round = p_round
	event.type = p_type
	event.source_id = p_source
	for target in p_targets:
		event.target_ids.append(StringName(target))
	event.data = p_data.duplicate(true)
	return event

func to_dict() -> Dictionary:
	var targets: Array = []
	for target in target_ids:
		targets.append(String(target))
	return {
		"seq": seq,
		"round": round,
		"type": String(type),
		"source_id": String(source_id),
		"target_ids": targets,
		"data": data,
	}

static func from_dict(source: Dictionary) -> BattleEvent:
	var event := BattleEvent.new()
	event.seq = int(source.get("seq", 0))
	event.round = int(source.get("round", 0))
	event.type = StringName(source.get("type", ""))
	event.source_id = StringName(source.get("source_id", ""))
	for target in source.get("target_ids", []):
		event.target_ids.append(StringName(target))
	event.data = source.get("data", {}).duplicate(true)
	return event

func canonical_json() -> String:
	return JSON.stringify(to_dict(), "", true)
