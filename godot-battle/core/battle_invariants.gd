class_name BattleInvariants
extends RefCounted

static func check(state: BattleState) -> Array[String]:
	var issues: Array[String] = []
	if state.round < 0:
		issues.append("round is negative")
	if state.round > state.max_rounds:
		issues.append("round exceeds max_rounds")
	var seen_unit_ids := {}
	for unit in state.units:
		if seen_unit_ids.has(unit.id):
			issues.append("duplicate unit id: %s" % String(unit.id))
		seen_unit_ids[unit.id] = true
		if unit.hp < 0 or unit.hp > unit.data.max_hp:
			issues.append("%s hp out of range: %d" % [String(unit.id), unit.hp])
		if unit.mp < 0 or unit.mp > unit.data.max_mp:
			issues.append("%s mp out of range: %d" % [String(unit.id), unit.mp])
		if unit.hp <= 0 and unit.alive:
			issues.append("%s has zero hp but still alive" % String(unit.id))
		if unit.hp > 0 and not unit.alive:
			issues.append("%s is dead with positive hp" % String(unit.id))
		var seen := {}
		for status in unit.statuses:
			if seen.has(status.data.id):
				issues.append("%s duplicate status %s" % [String(unit.id), String(status.data.id)])
			seen[status.data.id] = true
			if status.remaining < 0:
				issues.append("%s status %s has negative remaining" % [String(unit.id), String(status.data.id)])
	for item_id in state.item_uses:
		if int(state.item_uses[item_id]) < 0:
			issues.append("item %s has negative uses" % String(item_id))
	return issues
