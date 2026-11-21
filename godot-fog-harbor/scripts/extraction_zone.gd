class_name FogExtractionZone
extends Node2D
## 撤离点：激活后青绿色脉冲；站入 3 秒完成，离开重置进度。

var zone_rect := Rect2()
var active := false
var progress := 0.0
var time_left := 0.0
var _pulse := 0.0


func configure(rect: Rect2) -> void:
	zone_rect = rect
	position = rect.position


func _ready() -> void:
	z_index = 0
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func set_status(is_active: bool, hold_progress: float, left: float) -> void:
	active = is_active
	progress = hold_progress
	time_left = left


func contains(world_pos: Vector2) -> bool:
	return zone_rect.has_point(world_pos)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, zone_rect.size)
	var color := Color("6fe0c2") if active else Color("6a7a7d")
	var alpha := 0.18 if active else 0.08
	draw_rect(rect, Color(color.r, color.g, color.b, alpha), true)
	# 斜纹
	for x in range(-int(rect.size.y), int(rect.size.x), 26):
		draw_line(Vector2(x, rect.size.y), Vector2(x + rect.size.y, 0), Color(color.r, color.g, color.b, 0.10), 3.0)
	# 边框
	draw_rect(rect, Color(color.r, color.g, color.b, 0.75), false, 2.0)
	var corner := 22.0
	for p in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		draw_circle(p, 5.0, color, true)
		draw_circle(p, 10.0, Color(color.r, color.g, color.b, 0.18), true)
	# 四角括号
	draw_line(rect.position, rect.position + Vector2(corner, 0), color, 3.0)
	draw_line(rect.position, rect.position + Vector2(0, corner), color, 3.0)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - corner, rect.position.y), color, 3.0)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + corner), color, 3.0)
	draw_line(rect.end, rect.end - Vector2(corner, 0), color, 3.0)
	draw_line(rect.end, rect.end - Vector2(0, corner), color, 3.0)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + corner, rect.end.y), color, 3.0)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - corner), color, 3.0)
	# 中央信标
	var center := rect.size * 0.5
	var beam := 0.5 + 0.5 * sin(_pulse * 3.0)
	draw_circle(center, 26.0 + beam * 5.0, Color(color.r, color.g, color.b, 0.10), true)
	draw_circle(center, 10.0, Color(color.r, color.g, color.b, 0.75), true)
	draw_circle(center, 4.0, Color(0.92, 1.0, 0.96, 0.9), true)
	draw_line(center - Vector2(0, 24), center - Vector2(0, 64), Color(color.r, color.g, color.b, 0.35), 3.0)
	FogUITheme.draw_text_center(self, Rect2(0, rect.size.y - 62, rect.size.x, 24),
		"撤 离 点" if active else "撤离点 · 未激活", 15, color, true)
	FogUITheme.draw_text_center(self, Rect2(0, rect.size.y - 40, rect.size.x, 18),
		"站入 3 秒" if active else FogUITheme.format_time(time_left), 11,
		Color(0.8, 0.9, 0.9, 0.75))
	if active and progress > 0.0:
		var bar := Rect2(rect.size.x * 0.18, 22, rect.size.x * 0.64, 8)
		draw_rect(bar, Color(0, 0, 0, 0.7), true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), color, true)
		FogUITheme.draw_text_center(self, Rect2(bar.position.x, bar.position.y - 22, bar.size.x, 20),
			"撤离中 %.1f / 3.0" % (progress * 3.0), 13, color, true)
