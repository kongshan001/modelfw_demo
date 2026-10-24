class_name BattleEffect
extends Resource

enum Kind { DAMAGE, HEAL, APPLY_STATUS, CLEANSE, RESTORE_MP }

@export var kind: Kind = Kind.DAMAGE
@export var damage_type: int = BattleTypes.DamageType.PHYSICAL
@export var power: float = 1.0
@export var status_id: StringName = &""
@export var status_chance: float = 1.0
@export var cleanse_count: int = 1
@export var flat_amount: int = 0

static func damage(p_type: int, p_power: float) -> BattleEffect:
	var effect := BattleEffect.new()
	effect.kind = Kind.DAMAGE
	effect.damage_type = p_type
	effect.power = p_power
	return effect

static func heal(p_power: float, p_flat: int = 0) -> BattleEffect:
	var effect := BattleEffect.new()
	effect.kind = Kind.HEAL
	effect.damage_type = BattleTypes.DamageType.HEAL
	effect.power = p_power
	effect.flat_amount = p_flat
	return effect

static func apply_status(p_status_id: StringName, p_chance: float = 1.0) -> BattleEffect:
	var effect := BattleEffect.new()
	effect.kind = Kind.APPLY_STATUS
	effect.status_id = p_status_id
	effect.status_chance = p_chance
	return effect

static func cleanse(p_count: int = 1) -> BattleEffect:
	var effect := BattleEffect.new()
	effect.kind = Kind.CLEANSE
	effect.cleanse_count = p_count
	return effect

static func restore_mp(p_amount: int) -> BattleEffect:
	var effect := BattleEffect.new()
	effect.kind = Kind.RESTORE_MP
	effect.flat_amount = p_amount
	return effect
