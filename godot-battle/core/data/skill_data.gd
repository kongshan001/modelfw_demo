class_name SkillData
extends Resource

enum TargetType { SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES, SELF }

@export var id: StringName = &""
@export var display_name: String = ""
@export var mp_cost: int = 0
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var max_targets: int = 1
@export var effects: Array[BattleEffect] = []
@export var visual_id: StringName = &"generic"
@export var shout_text: String = ""
