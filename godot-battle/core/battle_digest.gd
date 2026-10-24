class_name BattleDigest
extends RefCounted

const MAX_SAFE_INTEGER := 9007199254740992.0

static func sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return "sha256:" + context.finish().hex_encode()

# Godot's JSON parser returns every number as a float, while replays are recorded
# from in-memory dictionaries where integer fields are ints. Normalize integral
# finite floats back to ints so digests and comparisons stay stable across the
# JSON round-trip.
static func canonical_json(value: Variant) -> String:
	return JSON.stringify(_normalize_numbers(value), "", true)

static func _normalize_numbers(value: Variant) -> Variant:
	if value is float:
		var number := float(value)
		if is_finite(number) and number >= -MAX_SAFE_INTEGER and number <= MAX_SAFE_INTEGER and number == roundf(number):
			return int(roundf(number))
		return number
	if value is Array:
		var normalized_list: Array = []
		for item in value:
			normalized_list.append(_normalize_numbers(item))
		return normalized_list
	if value is Dictionary:
		var normalized_dict := {}
		for key in value:
			normalized_dict[key] = _normalize_numbers(value[key])
		return normalized_dict
	return value
