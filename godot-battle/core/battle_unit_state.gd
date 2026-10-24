class_name BattleUnitState
extends RefCounted

var id: StringName = &""
var data: UnitData
var side: int = BattleTypes.Side.ALLY
var slot: int = 0
var hp: int = 0
var mp: int = 0
var statuses: Array[StatusInstance] = []
var alive: bool = true

func _init(p_data: UnitData, p_side: int, p_slot: int) -> void:
	id = p_data.id
	data = p_data
	side = p_side
	slot = p_slot
	hp = p_data.max_hp
	mp = p_data.max_mp

func is_alive() -> bool:
	return alive and hp > 0

func find_status(status_id: StringName) -> StatusInstance:
	for status in statuses:
		if status.data.id == status_id:
			return status
	return null

func has_status(status_id: StringName) -> bool:
	return find_status(status_id) != null

func add_status(status_data: StatusData, round_number: int) -> bool:
	var existing := find_status(status_data.id)
	if existing != null:
		existing.remaining = maxi(existing.remaining, status_data.duration)
		existing.applied_round = round_number
		return false
	statuses.append(StatusInstance.new(status_data, round_number))
	return true

func remove_status(status_id: StringName) -> bool:
	for index in range(statuses.size()):
		if statuses[index].data.id == status_id:
			statuses.remove_at(index)
			return true
	return false

func atk_value() -> float:
	var multiplier := 1.0
	for status in statuses:
		multiplier *= status.data.atk_mult
	return float(data.atk) * multiplier

func defense_value() -> float:
	var multiplier := 1.0
	for status in statuses:
		multiplier *= status.data.defense_mult
	return float(data.defense) * multiplier

func magic_value() -> float:
	return float(data.magic)

func resistance_value() -> float:
	return float(data.resistance)

func damage_taken_mult() -> float:
	var multiplier := 1.0
	for status in statuses:
		multiplier *= status.data.damage_taken_mult
	return multiplier

func seal_resist_bonus() -> float:
	var bonus := 0.0
	for status in statuses:
		bonus += status.data.seal_resist_bonus
	return bonus
