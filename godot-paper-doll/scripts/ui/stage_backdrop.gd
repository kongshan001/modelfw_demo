class_name StageBackdrop
extends Control

# 试衣镜里的纸舞台：暖色天空、纸屑、软阴影与虚线缝边。纯绘制，不含贴图。


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var top := Color("#f8efdf")
	var bottom := Color("#ead9c1")
	for i in 20:
		var t := float(i) / 19.0
		draw_rect(Rect2(0, h * t / 20.0, w, h / 20.0 + 1.0), top.lerp(bottom, t))
	draw_circle(Vector2(w * 0.78, h * 0.20), 46.0, Color(1.0, 0.81, 0.45, 0.22))
	draw_circle(Vector2(w * 0.78, h * 0.20), 31.0, Color(1.0, 0.88, 0.60, 0.16))

	for i in 9:
		var x := fposmod(float(i) * 73.0, w)
		var y := 38.0 + fposmod(float(i) * 47.0, h * 0.45)
		var c: Color = [Color(0.91, 0.42, 0.36, 0.16), Color(0.25, 0.61, 0.54, 0.16), Color(0.95, 0.70, 0.30, 0.18)][i % 3]
		draw_set_transform(Vector2(x, y), 0.5 * i, Vector2.ONE)
		draw_rect(Rect2(-4, -2, 8, 4), c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_set_transform(Vector2(w * 0.5, h - 27.0), 0.0, Vector2(1.0, 0.26))
	draw_circle(Vector2.ZERO, 86.0, Color(0.23, 0.18, 0.26, 0.10))
	draw_circle(Vector2.ZERO, 61.0, Color(1.0, 0.97, 0.90, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var dashed := Color(0.23, 0.18, 0.26, 0.20)
	draw_dashed_line(Vector2(10, 10), Vector2(w - 10, 10), dashed, 1.2, 5.0)
	draw_dashed_line(Vector2(w - 10, 10), Vector2(w - 10, h - 10), dashed, 1.2, 5.0)
	draw_dashed_line(Vector2(w - 10, h - 10), Vector2(10, h - 10), dashed, 1.2, 5.0)
	draw_dashed_line(Vector2(10, h - 10), Vector2(10, 10), dashed, 1.2, 5.0)
