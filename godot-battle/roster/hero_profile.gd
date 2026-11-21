class_name HeroProfile
extends Resource

# 主角选择界面的角色档案。放在 res://roster/ 而不是 res://data/，
# 避免进入 ContentDB 的内容哈希，影响黄金回放。

@export var id: StringName = &""
@export var display_name: String = ""
@export var title: String = ""
@export var hero_class: String = ""
@export var gender: String = ""
@export var race: String = ""
@export var accent: Color = Color(0.45, 0.8, 1.0)
@export var quote: String = ""
@export_multiline var description: String = ""
@export var hp_bar: int = 50
@export var atk_bar: int = 50
@export var mag_bar: int = 50
@export var spd_bar: int = 50
@export var skills: Array[String] = []
@export var portrait_path: String = ""
@export var sort_order: int = 0
