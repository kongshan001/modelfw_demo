class_name StatusData
extends Resource

enum Kind { BUFF, DEBUFF }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.BUFF
@export var duration: int = 1
@export var expires_on_owner_action: bool = false
@export var skips_action: bool = false
@export var damage_taken_mult: float = 1.0
@export var seal_resist_bonus: float = 0.0
@export var atk_mult: float = 1.0
@export var defense_mult: float = 1.0
@export var poison_max_hp_ratio: float = 0.0
@export var icon_path: String = ""
@export var display_color: Color = Color.WHITE
