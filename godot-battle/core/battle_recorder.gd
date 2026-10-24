class_name BattleRecorder
extends RefCounted

const REPLAY_VERSION := 1

var meta: Dictionary = {}
var rounds: Array[Dictionary] = []
var events: Array[Dictionary] = []
var digests: Array[Dictionary] = []
var snapshots: Array[Dictionary] = []
var result: Dictionary = {}
var _previous_digest: String = ""

func begin(encounter: EncounterData, seed_value: int, content_hash: String, state: BattleState) -> void:
	rounds.clear()
	events.clear()
	digests.clear()
	snapshots.clear()
	result.clear()
	_previous_digest = ""
	meta = {
		"battle_id": String(encounter.id),
		"content_hash": content_hash,
		"engine": String(Engine.get_version_info().get("string", "unknown")),
		"seed": seed_value,
		"created_at": Time.get_datetime_string_from_system(true),
		"build": "debug" if OS.is_debug_build() else "release",
	}
	snapshots.append(_snapshot(1, state))

func _ensure_round(round_number: int) -> Dictionary:
	for entry in rounds:
		if int(entry["round"]) == round_number:
			return entry
	var entry := {"round": round_number, "intents": [], "debug_ops": [], "resolved": false}
	rounds.append(entry)
	return entry

func record_intents(round_number: int, intents: Array[BattleIntent]) -> void:
	var entry := _ensure_round(round_number)
	var list: Array = entry["intents"]
	for intent in intents:
		list.append(intent.to_dict())
	entry["intents"] = list
	entry["resolved"] = true

func record_debug_op(round_number: int, op: Dictionary) -> void:
	var entry := _ensure_round(round_number)
	var ops: Array = entry["debug_ops"]
	ops.append(op.duplicate(true))
	entry["debug_ops"] = ops

func record_snapshot(round_number: int, state: BattleState) -> void:
	for index in range(snapshots.size()):
		if int(snapshots[index]["round"]) == round_number:
			snapshots[index] = _snapshot(round_number, state)
			return
	snapshots.append(_snapshot(round_number, state))

func record_round_events(round_events: Array[BattleEvent]) -> void:
	if round_events.is_empty():
		return
	var round_number := round_events[0].round
	var parts: Array[String] = []
	for event in round_events:
		events.append(event.to_dict())
		parts.append(event.canonical_json())
	var digest := BattleDigest.sha256(_previous_digest + "\n" + "\n".join(parts))
	_previous_digest = digest
	digests.append({"round": round_number, "sha256": digest})

func finish(state: BattleState) -> void:
	result = {"outcome": state.outcome, "rounds": state.round, "digest": _previous_digest}

func _snapshot(round_number: int, state: BattleState) -> Dictionary:
	var unit_list: Array = []
	for unit in state.units:
		var status_list: Array = []
		for status in unit.statuses:
			status_list.append({"id": String(status.data.id), "remaining": status.remaining})
		unit_list.append({
			"id": String(unit.id),
			"hp": unit.hp,
			"mp": unit.mp,
			"alive": unit.is_alive(),
			"statuses": status_list,
		})
	var items := {}
	for item_id in state.item_uses:
		items[String(item_id)] = int(state.item_uses[item_id])
	return {"round": round_number, "units": unit_list, "item_uses": items}

func to_dict() -> Dictionary:
	return {
		"replay_version": REPLAY_VERSION,
		"meta": meta,
		"rounds": rounds,
		"events": events,
		"digests": digests,
		"snapshots": snapshots,
		"result": result,
	}

func save(path: String = "") -> String:
	if path.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://replays"))
		var battle_id := String(meta.get("battle_id", "battle"))
		var stamp := int(Time.get_unix_time_from_system() * 1000.0)
		path = "user://replays/%s_%d.json" % [battle_id, stamp]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write replay: " + path)
		return ""
	file.store_string(JSON.stringify(to_dict(), "  ", true))
	file.close()
	print("REPLAY_SAVED: " + ProjectSettings.globalize_path(path))
	return path
