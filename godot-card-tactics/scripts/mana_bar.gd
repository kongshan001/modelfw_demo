class_name ManaBar
extends Control

const BattleCoreScript = preload("res://scripts/battle_core.gd")

# 9 颗菱形法力水晶：暗色=上限未到，亮蓝=本回合可用，灰蓝=已花费。

var mana := 1
var max_mana := 1

const GEM_STEP := 20.0
const GEM_R := 7.0


func set_values(current: int, maximum: int) -> void:
	mana = current
	max_mana = maximum
	queue_redraw()


func _draw() -> void:
	for i in range(BattleCoreScript.MANA_CAP):
		var center := Vector2(10.0 + i * GEM_STEP, 15.0)
		var pts := PackedVector2Array([
			center + Vector2(0, -GEM_R),
			center + Vector2(GEM_R, 0),
			center + Vector2(0, GEM_R),
			center + Vector2(-GEM_R, 0),
		])
		var fill := Color(0.16, 0.2, 0.28, 0.9)
		if i < max_mana:
			fill = Color(0.2, 0.42, 0.66, 0.95)
		if i < mana:
			fill = Color(0.47, 0.85, 1.0, 1.0)
		draw_colored_polygon(pts, fill)
		var border := Color(0.4, 0.6, 0.75, 0.55)
		if i < mana:
			border = Color(0.8, 0.97, 1.0, 0.95)
		var closed := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
		draw_polyline(closed, border, 1.2)
