class_name BattleFactory
extends RefCounted

static func create(encounter: EncounterData, content: ContentDB) -> BattleState:
	var state := BattleState.new()
	state.encounter = encounter
	state.max_rounds = encounter.max_rounds
	var slot := 0
	for unit_id in encounter.ally_unit_ids:
		var data := content.get_unit(unit_id)
		if data == null:
			push_error("Missing ally unit: " + String(unit_id))
			continue
		state.units.append(BattleUnitState.new(data, BattleTypes.Side.ALLY, slot))
		slot += 1
	slot = 0
	for unit_id in encounter.enemy_unit_ids:
		var data := content.get_unit(unit_id)
		if data == null:
			push_error("Missing enemy unit: " + String(unit_id))
			continue
		state.units.append(BattleUnitState.new(data, BattleTypes.Side.ENEMY, slot))
		slot += 1
	for item_id in encounter.item_counts:
		state.item_uses[StringName(item_id)] = int(encounter.item_counts[item_id])
	return state
