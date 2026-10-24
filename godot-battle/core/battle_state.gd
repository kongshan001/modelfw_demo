class_name BattleState
extends RefCounted

var round: int = 0
var outcome: int = BattleTypes.Outcome.NONE
var units: Array[BattleUnitState] = []
var item_uses: Dictionary = {}
var encounter: EncounterData
var max_rounds: int = 30

func get_unit(unit_id: StringName) -> BattleUnitState:
	for unit in units:
		if unit.id == unit_id:
			return unit
	return null

func living(side: int) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for unit in units:
		if unit.side == side and unit.is_alive():
			result.append(unit)
	return result

func living_enemies_of(unit: BattleUnitState) -> Array[BattleUnitState]:
	return living(1 - unit.side)

func living_allies_of(unit: BattleUnitState) -> Array[BattleUnitState]:
	return living(unit.side)

func is_over() -> bool:
	return outcome != BattleTypes.Outcome.NONE

func item_remaining(item_id: StringName) -> int:
	return int(item_uses.get(item_id, 0))

func consume_item(item_id: StringName) -> bool:
	var remaining := item_remaining(item_id)
	if remaining <= 0:
		return false
	item_uses[item_id] = remaining - 1
	return true
