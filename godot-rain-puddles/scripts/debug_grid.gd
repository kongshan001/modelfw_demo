extends Node2D

# 调试叠加：显示大占位格（红）与灯柱 1×1 放行格（绿）。
# 只在调试开关打开时可见，不影响正常画面。

var field: PuddleField


func setup(p_field: PuddleField) -> void:
	field = p_field
	queue_redraw()


func _draw() -> void:
	if field == null:
		return
	for cell in field.blocked_cells:
		var r := RainLayout.cell_rect(cell)
		draw_rect(r, Color(1.0, 0.28, 0.20, 0.14), true)
		draw_rect(r, Color(1.0, 0.42, 0.30, 0.62), false, 1.0)
	for lamp in RainLayout.LAMPS:
		var cell: Vector2i = RainLayout.lamp_cell(lamp)
		var r := RainLayout.cell_rect(cell)
		draw_rect(r, Color(0.30, 1.0, 0.55, 0.16), true)
		draw_rect(r, Color(0.45, 1.0, 0.65, 0.95), false, 1.0)
		var c := r.get_center()
		draw_line(c + Vector2(-5, 0), c + Vector2(5, 0),
				Color(0.75, 1.0, 0.80, 0.9), 1.0)
		draw_line(c + Vector2(0, -5), c + Vector2(0, 5),
				Color(0.75, 1.0, 0.80, 0.9), 1.0)
