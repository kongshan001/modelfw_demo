class_name BattleReplay
extends RefCounted

static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

static func verify(replay: Dictionary, content: ContentDB, strict_content: bool = false) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var version: Variant = replay.get("replay_version", 0)
	if not (version is int or version is float) or float(version) != float(BattleRecorder.REPLAY_VERSION):
		errors.append("unsupported replay_version")
		return _failed(errors, warnings)
	if not (replay.get("meta") is Dictionary):
		errors.append("malformed meta")
		return _failed(errors, warnings)
	if not (replay.get("rounds") is Array):
		errors.append("malformed rounds")
		return _failed(errors, warnings)
	if not (replay.get("events") is Array):
		errors.append("malformed events")
		return _failed(errors, warnings)
	if not (replay.get("digests") is Array):
		errors.append("malformed digests")
		return _failed(errors, warnings)
	if not (replay.get("result") is Dictionary):
		errors.append("malformed result")
		return _failed(errors, warnings)
	var meta: Dictionary = replay["meta"]
	var encounter := content.get_encounter(StringName(meta.get("battle_id", "")))
	if encounter == null:
		errors.append("unknown encounter: " + String(meta.get("battle_id", "")))
		return _failed(errors, warnings)
	if String(meta.get("content_hash", "")) != content.content_hash():
		if strict_content:
			errors.append("content hash mismatch")
		else:
			warnings.append("content hash mismatch")
	errors.append_array(_verify_digest_chain(replay))
	if not errors.is_empty():
		return _failed(errors, warnings)

	var engine := BattleEngine.new(encounter, content, int(meta.get("seed", 0)), false)
	var recorded_by_round := {}
	for event_dict in replay["events"]:
		var event_round := int(event_dict.get("round", 0))
		if not recorded_by_round.has(event_round):
			recorded_by_round[event_round] = []
		recorded_by_round[event_round].append(event_dict)

	var snapshots_by_round := {}
	var recorded_snapshots: Variant = replay.get("snapshots", [])
	if recorded_snapshots is Array:
		for snapshot in recorded_snapshots:
			if snapshot is Dictionary and snapshot.has("round"):
				snapshots_by_round[int(snapshot["round"])] = snapshot

	var rounds: Array = replay["rounds"].duplicate()
	rounds.sort_custom(func(a, b): return int(a["round"]) < int(b["round"]))
	var first_divergence := {}
	for entry in rounds:
		var entry_round := int(entry["round"])
		for op in entry.get("debug_ops", []):
			engine.apply_debug_op(op)
		if entry.has("resolved") and not bool(entry["resolved"]):
			continue
		# Snapshots are recorded at the start of each resolved round, after that
		# round's debug ops. Compare them before replaying the round.
		if snapshots_by_round.has(entry_round):
			first_divergence = _compare_snapshot(engine.state, snapshots_by_round[entry_round])
			if not first_divergence.is_empty():
				break
		var intents: Array[BattleIntent] = []
		for intent_dict in entry.get("intents", []):
			intents.append(BattleIntent.from_dict(intent_dict))
		var produced := engine.resolve_round(intents)
		var expected: Array = recorded_by_round.get(entry_round, [])
		first_divergence = _compare_events(produced, expected)
		if not first_divergence.is_empty():
			break
	if not first_divergence.is_empty():
		if String(first_divergence.get("reason", "")) == "snapshot_mismatch":
			errors.append("snapshot divergence at round %d: %s" % [
				int(first_divergence.get("round", 0)),
				String(first_divergence.get("field", "state")),
			])
		else:
			errors.append("event divergence: " + String(first_divergence.get("reason", "unknown")))
	else:
		var result: Dictionary = replay["result"]
		if int(result.get("outcome", BattleTypes.Outcome.NONE)) != engine.state.outcome:
			errors.append("outcome mismatch")
		elif int(result.get("rounds", engine.state.round)) != engine.state.round:
			errors.append("round count mismatch")
		var recorded_digests: Array = replay["digests"]
		var last_digest := ""
		if not recorded_digests.is_empty():
			last_digest = String(recorded_digests[-1].get("sha256", ""))
		if String(result.get("digest", "")) != last_digest:
			errors.append("result digest mismatch")
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings, "first_divergence": first_divergence}

static func _compare_events(produced: Array[BattleEvent], expected: Array) -> Dictionary:
	# Report the first differing event before a size mismatch so intent tampering
	# (which can change event counts downstream) still surfaces as event_mismatch.
	for index in mini(produced.size(), expected.size()):
		var produced_json := BattleDigest.canonical_json(produced[index].to_dict())
		var expected_json := BattleDigest.canonical_json(expected[index])
		if produced_json != expected_json:
			return {
				"reason": "event_mismatch",
				"index": index,
				"round": produced[index].round,
				"seq": produced[index].seq,
				"expected": expected[index],
				"produced": produced[index].to_dict(),
				"context_before": expected.slice(maxi(0, index - 5), index),
				"context_after": expected.slice(index + 1, mini(expected.size(), index + 6)),
			}
	if produced.size() != expected.size():
		return {"reason": "event_count", "expected": expected.size(), "produced": produced.size()}
	return {}

static func _compare_snapshot(state: BattleState, recorded: Dictionary) -> Dictionary:
	var round_number := int(recorded.get("round", state.round + 1))
	var recorded_units: Variant = recorded.get("units", [])
	if not (recorded_units is Array):
		return _snapshot_divergence(round_number, "", "units", recorded_units, "array")

	var produced_by_id := {}
	for unit in state.units:
		produced_by_id[String(unit.id)] = _unit_snapshot(unit)
	var expected_by_id := {}
	for expected in recorded_units:
		if expected is Dictionary:
			expected_by_id[String(expected.get("id", ""))] = expected
	if expected_by_id.size() != produced_by_id.size():
		return _snapshot_divergence(round_number, "", "unit_set", expected_by_id.keys(), produced_by_id.keys())

	for unit_id in expected_by_id:
		if not produced_by_id.has(unit_id):
			return _snapshot_divergence(round_number, unit_id, "unit_presence", true, false)
		var expected: Dictionary = expected_by_id[unit_id]
		var produced: Dictionary = produced_by_id[unit_id]
		for field in ["hp", "mp"]:
			if int(expected.get(field, 0)) != int(produced[field]):
				return _snapshot_divergence(round_number, unit_id, field, expected.get(field), produced[field])
		if bool(expected.get("alive", false)) != bool(produced["alive"]):
			return _snapshot_divergence(round_number, unit_id, "alive", expected.get("alive"), produced["alive"])
		var expected_statuses := BattleDigest.canonical_json(_normalized_statuses(expected.get("statuses", [])))
		var produced_statuses := BattleDigest.canonical_json(_normalized_statuses(produced["statuses"]))
		if expected_statuses != produced_statuses:
			return _snapshot_divergence(round_number, unit_id, "statuses", expected_statuses, produced_statuses)

	var produced_items := {}
	for item_id in state.item_uses:
		produced_items[String(item_id)] = int(state.item_uses[item_id])
	var recorded_items: Variant = recorded.get("item_uses", {})
	if not (recorded_items is Dictionary):
		return _snapshot_divergence(round_number, "", "item_uses", recorded_items, produced_items)
	var expected_items := {}
	for item_id in recorded_items:
		expected_items[String(item_id)] = int(recorded_items[item_id])
	if BattleDigest.canonical_json(expected_items) != BattleDigest.canonical_json(produced_items):
		return _snapshot_divergence(round_number, "", "item_uses", expected_items, produced_items)
	return {}

static func _unit_snapshot(unit: BattleUnitState) -> Dictionary:
	var status_list: Array = []
	for status in unit.statuses:
		status_list.append({"id": String(status.data.id), "remaining": status.remaining})
	return {
		"hp": unit.hp,
		"mp": unit.mp,
		"alive": unit.is_alive(),
		"statuses": status_list,
	}

static func _normalized_statuses(source: Variant) -> Array:
	var statuses: Array = []
	if source is Array:
		for status in source:
			if status is Dictionary:
				statuses.append({
					"id": String(status.get("id", "")),
					"remaining": int(status.get("remaining", 0)),
				})
	statuses.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	return statuses

static func _snapshot_divergence(round_number: int, unit_id: String, field: String, expected: Variant, produced: Variant) -> Dictionary:
	return {
		"reason": "snapshot_mismatch",
		"round": round_number,
		"unit_id": unit_id,
		"field": field,
		"expected": expected,
		"produced": produced,
	}

static func _verify_digest_chain(replay: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var events_by_round := {}
	for event_dict in replay["events"]:
		var event_round := int(event_dict.get("round", 0))
		if not events_by_round.has(event_round):
			events_by_round[event_round] = []
		events_by_round[event_round].append(event_dict)
	var previous := ""
	for digest_entry in replay["digests"]:
		var digest_round := int(digest_entry.get("round", 0))
		var parts: Array[String] = []
		for event_dict in events_by_round.get(digest_round, []):
			parts.append(BattleDigest.canonical_json(event_dict))
		var expected := BattleDigest.sha256(previous + "\n" + "\n".join(parts))
		if expected != String(digest_entry.get("sha256", "")):
			errors.append("digest mismatch at round %d" % digest_round)
		previous = expected
	return errors

static func _failed(errors: Array[String], warnings: Array[String]) -> Dictionary:
	return {"ok": false, "errors": errors, "warnings": warnings, "first_divergence": {}}
