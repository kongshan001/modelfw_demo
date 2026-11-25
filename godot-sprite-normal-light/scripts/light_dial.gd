extends Control

# HUD 内的光照向量小表盘：方位角 + 高度 + 光色。
# 纯矢量绘制，不参与世界光照。

const INK := Color(0.035, 0.060, 0.075, 0.92)
const RING := Color(0.30, 0.42, 0.44, 0.9)
const TICK := Color(0.42, 0.56, 0.56, 0.8)
const DIM := Color(0.44, 0.58, 0.58, 0.9)

var angle_deg := 28.0
var height := 72.0
var light_color := Color(1.0, 0.73, 0.45)


func _ready() -> void:
	custom_minimum_size = Vector2(104, 88)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(angle: float, h: float, color: Color) -> void:
	angle_deg = angle
	height = h
	light_color = color
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.28, 0.30, 0.9), false, 1.0)
	var center := Vector2(46, 48)
	draw_arc(center, 27.0, 0.0, TAU, 40, RING, 1.0, false)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var dir := Vector2(sin(a), -cos(a))
		draw_line(center + dir * 24.0, center + dir * 28.0, TICK, 1.0)
	var elev := clampf(height / 160.0, 0.0, 1.0)
	var a := deg_to_rad(angle_deg)
	var reach := 26.0 * (1.0 - 0.42 * elev)
	var dir := Vector2(sin(a), -cos(a))
	var dot := center + dir * reach
	draw_line(center, dot, Color(light_color.r, light_color.g, light_color.b, 0.8), 1.0)
	draw_circle(dot, 3.0, light_color)
	draw_circle(dot, 1.0, Color(1.0, 0.96, 0.86, 0.95))

	var bar_x := size.x - 11.0
	draw_line(Vector2(bar_x, center.y + 28.0), Vector2(bar_x, center.y - 24.0), DIM, 1.0)
	var top := center.y + 28.0 - 52.0 * elev
	draw_line(Vector2(bar_x, center.y + 28.0), Vector2(bar_x, top), light_color, 2.0)
	draw_string(font, Vector2(3, 11), "L", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
	draw_string(font, Vector2(bar_x - 7, size.y - 4), "h", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
	draw_string(font, Vector2(3, size.y - 4), "az", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
