class_name SunDial
extends Control

# HUD 里的太阳罗盘：弧线表示屏幕平面方位 50°→140°，
# 光点离地平线的高度随高度角变化；文字显示当前时间与两个角度。

var main: Node
var font: Font
var azimuth := 50.0
var elevation := 35.0
var hour := 8.0
var phase := "晨光"


func _ready() -> void:
	custom_minimum_size = Vector2(236.0, 156.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	if main == null:
		return
	hour = main.get_hour()
	azimuth = main.get_azimuth()
	elevation = main.get_elevation()
	phase = main.get_phase()
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var center := Vector2(w * 0.5, h - 28.0)
	var radius := minf(w * 0.39, 90.0)

	# 地平线与弧。
	draw_line(Vector2(14.0, center.y), Vector2(w - 14.0, center.y),
			Color(0.55, 0.72, 0.56, 0.40), 1.0)
	draw_arc(center, radius, deg_to_rad(-142.0), deg_to_rad(-38.0), 48,
			Color(0.68, 0.86, 0.64, 0.32), 1.0)

	# 15° 刻度。
	for i in range(0, 8):
		var a := deg_to_rad(50.0 + float(i) * 15.0)
		var dir := Vector2(cos(a), -sin(a))
		var inner := center + dir * (radius - 5.0)
		var outer := center + dir * (radius + 2.0)
		draw_line(inner, outer, Color(0.72, 0.86, 0.68, 0.36), 1.0)

	# 太阳位置：方位决定沿弧的位置，高度角决定离地平线的远近。
	var az := deg_to_rad(azimuth)
	var dir := Vector2(cos(az), -sin(az))
	var r := lerpf(radius * 0.42, radius, clampf(elevation / 70.0, 0.0, 1.0))
	var sun := center + dir * r
	draw_dashed_line(center, sun, Color(1.0, 0.84, 0.52, 0.25), 1.0, 3.0)
	draw_circle(sun, 11.0, Color(1.0, 0.76, 0.42, 0.12))
	draw_circle(sun, 7.5, Color(1.0, 0.84, 0.45, 0.30))
	draw_circle(sun, 4.5, Color(1.0, 0.93, 0.68, 0.98))
	draw_circle(sun, 2.0, Color(1.0, 1.0, 0.92, 1.0))

	# 端点与文字。
	if font != null:
		draw_string(font, Vector2(10.0, center.y + 14.0), "08:00",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.72, 0.82, 0.72, 0.8))
		draw_string(font, Vector2(w - 48.0, center.y + 14.0), "17:00",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.72, 0.82, 0.72, 0.8))
		draw_string(font, Vector2(10.0, 15.0), "太阳罗盘  %s" % phase,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.85, 0.64, 0.95))
		draw_string(font, Vector2(w - 88.0, 15.0), "h %.1f°" % elevation,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.88, 0.93, 0.80, 0.95))
		draw_string(font, sun + Vector2(9.0, -7.0), "%.0f°" % azimuth,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.90, 0.70, 0.9))
