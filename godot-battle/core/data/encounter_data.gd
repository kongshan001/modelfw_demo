class_name EncounterData
extends Resource

@export var id: StringName = &""
@export var ally_unit_ids: Array[StringName] = []
@export var enemy_unit_ids: Array[StringName] = []
@export var item_counts: Dictionary = {}
@export var reward_exp: int = 0
@export var reward_gold: int = 0
@export var max_rounds: int = 30
@export var background_path: String = ""
@export var bgm_path: String = ""
@export var script_data: EncounterScript
