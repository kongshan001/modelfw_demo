class_name BattleIntent
extends RefCounted

var actor_id: StringName = &""
var kind: int = BattleTypes.IntentKind.ATTACK
var skill_id: StringName = &""
var item_id: StringName = &""
var target_ids: Array[StringName] = []

static func make(p_actor: StringName, p_kind: int, p_targets: Array = [], p_skill: StringName = &"", p_item: StringName = &"") -> BattleIntent:
	var intent := BattleIntent.new()
	intent.actor_id = p_actor
	intent.kind = p_kind
	intent.skill_id = p_skill
	intent.item_id = p_item
	for target in p_targets:
		intent.target_ids.append(StringName(target))
	return intent

func to_dict() -> Dictionary:
	var targets: Array = []
	for target in target_ids:
		targets.append(String(target))
	return {
		"actor_id": String(actor_id),
		"kind": kind,
		"skill_id": String(skill_id),
		"item_id": String(item_id),
		"target_ids": targets,
	}

static func from_dict(source: Dictionary) -> BattleIntent:
	var intent := BattleIntent.new()
	intent.actor_id = StringName(source.get("actor_id", ""))
	intent.kind = int(source.get("kind", BattleTypes.IntentKind.ATTACK))
	intent.skill_id = StringName(source.get("skill_id", ""))
	intent.item_id = StringName(source.get("item_id", ""))
	for target in source.get("target_ids", []):
		intent.target_ids.append(StringName(target))
	return intent
