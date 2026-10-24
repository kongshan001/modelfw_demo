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
	if int(replay.get("replay_version", 0)) != 1:
		errors.append("unsupported replay_version")
		return {"ok": false, "errors": errors, "warnings": warnings, "first_divergence": {}}
	var meta: Dictionary = replay.get("meta", {})
	var encounter := content.get_encounter(StringName(meta.get("battle_id", "")))
	if encounter == null:
		errors.append("unknown encounter: " + String(meta.get("battle_id", "")))
		return {"ok": false, "errors": errors, "warnings": warnings, "first_divergence": {}}
	if String(meta.get("content_hash", "")) != content.content_hash():
		if strict_content:
			errors.append("content hash mismatch")
		else:
			warnings.append("content hash mismatch")
	errors.append_array(_verify_digest_chain(replay))
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "warnings": warnings, "first_divergence": {}}

	var engine := BattleEngine.new(encounter, content, int(meta.get("seed", 0)), false)
	var recorded_by_round := {}
	for event_dict in replay.get("events", []):
		var event_round := int(event_dict.get("round", 0))
		if not recorded_by_round.has(event_round):
			recorded_by_round[event_round] = []
		recorded_by_round[event_round].append(event_dict)

	var rounds: Array = replay.get("rounds", [])
	rounds.sort_custom(func(a, b): return int(a["round"]) < int(b["round"]))
	var first_divergence := {}
	for entry in rounds:
		var entry_round := int(entry["round"])
		for op in entry.get("debug_ops", []):
			engine.apply_debug_op(op)
		var intents: Array[BattleIntent] = []
		for intent_dict in entry.get("intents", []):
			intents.append(BattleIntent.from_dict(intent_dict))
		var produced := engine.resolve_round(intents)
		var expected: Array = recorded_by_round.get(entry_round, [])
		first_divergence = _compare_events(produced, expected)
		if not first_divergence.is_empty():
			break
	if not first_divergence.is_empty():
		errors.append("event divergence: " + String(first_divergence.get("reason", "unknown")))
	else:
		var result: Dictionary = replay.get("result", {})
		if int(result.get("outcome", BattleTypes.Outcome.NONE)) != engine.state.outcome:
			errors.append("outcome mismatch")
		elif int(result.get("rounds", engine.state.round)) != engine.state.round:
			errors.append("round count mismatch")
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings, "first_divergence": first_divergence}

static func _compare_events(produced: Array[BattleEvent], expected: Array) -> Dictionary:
	if produced.size() != expected.size():
		return {"reason": "event_count", "expected": expected.size(), "produced": produced.size()}
	for index in produced.size():
		var produced_json := _canonical_event_json(produced[index].to_dict())
		var expected_json := _canonical_event_json(expected[index])
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
	return {}

static func _verify_digest_chain(replay: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var events_by_round := {}
	for event_dict in replay.get("events", []):
		var event_round := int(event_dict.get("round", 0))
		if not events_by_round.has(event_round):
			events_by_round[event_round] = []
		events_by_round[event_round].append(event_dict)
	var previous := ""
	for digest_entry in replay.get("digests", []):
		var digest_round := int(digest_entry.get("round", 0))
		var parts: Array[String] = []
		for event_dict in events_by_round.get(digest_round, []):
			parts.append(_canonical_event_json(event_dict))
		var expected := BattleDigest.sha256(previous + "\n" + "\n".join(parts))
		if expected != String(digest_entry.get("sha256", "")):
			errors.append("digest mismatch at round %d" % digest_round)
		previous = expected
	return errors

# Godot's JSON parser returns every number as a float, while replays are recorded
# from in-memory event dictionaries where integer fields are ints. Normalize
# integral floats back to ints so digest and event comparisons stay stable
# across the JSON round-trip.
static func _canonical_event_json(event_dict: Dictionary) -> String:
	return JSON.stringify(_normalize_numbers(event_dict), "", true)

static func _normalize_numbers(value: Variant) -> Variant:
	if value is float:
		var number := float(value)
		if number >= -9007199254740992.0 and number <= 9007199254740992.0 and number == roundf(number):
			return int(roundf(number))
		return number
	if value is Array:
		var source_list: Array = value
		var normalized_list: Array = []
		for item in source_list:
			normalized_list.append(_normalize_numbers(item))
		return normalized_list
	if value is Dictionary:
		var source_dict: Dictionary = value
		var normalized_dict := {}
		for key in source_dict:
			normalized_dict[key] = _normalize_numbers(source_dict[key])
		return normalized_dict
	return value
