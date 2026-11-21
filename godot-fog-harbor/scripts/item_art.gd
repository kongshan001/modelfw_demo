class_name FogItemArt
extends RefCounted
## 8 类战利品的原创矢量小图标。必须在 CanvasItem._draw() 内调用。

static func draw_icon(canvas: CanvasItem, rect: Rect2, id: String) -> void:
	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y)
	match id:
		"old_script":
			_draw_script(canvas, c, s)
		"medkit":
			_draw_medkit(canvas, c, s)
		"brass_parts":
			_draw_gear(canvas, c, s)
		"shipping_chip":
			_draw_chip(canvas, c, s)
		"military_cell":
			_draw_battery(canvas, c, s)
		"precision_rig":
			_draw_rig(canvas, c, s)
		"fog_crystal":
			_draw_crystal(canvas, c, s)
		"black_box":
			_draw_blackbox(canvas, c, s)
		_:
			canvas.draw_rect(Rect2(c - Vector2(s, s) * 0.22, Vector2(s, s) * 0.44), Color("6f8489"), true)


static func _draw_script(canvas: CanvasItem, c: Vector2, s: float) -> void:
	var w := s * 0.78
	var h := s * 0.46
	var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	canvas.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35), true)
	canvas.draw_rect(r, Color("b39b6a"), true)
	canvas.draw_rect(r, Color("6f5c39"), false, 1.5)
	canvas.draw_circle(c - Vector2(w * 0.24, 0), h * 0.24, Color("7a6640"), true)
	canvas.draw_line(c - Vector2(w * 0.04, h * 0.22), c + Vector2(w * 0.36, h * 0.22), Color("7a6640"), 1.5)
	canvas.draw_line(c - Vector2(w * 0.04, 0), c + Vector2(w * 0.36, 0), Color("7a6640"), 1.5)
	canvas.draw_line(c - Vector2(w * 0.04, -h * 0.22), c + Vector2(w * 0.36, -h * 0.22), Color("7a6640"), 1.5)


static func _draw_medkit(canvas: CanvasItem, c: Vector2, s: float) -> void:
	var w := s * 0.66
	var h := s * 0.52
	var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	canvas.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35), true)
	canvas.draw_rect(r, Color("d9e3dc"), true)
	canvas.draw_rect(r, Color("49615e"), false, 1.5)
	var t := r.size.x * 0.16
	canvas.draw_rect(Rect2(c - Vector2(t, h * 0.32), Vector2(t * 2, h * 0.64)), Color("4fae9c"), true)
	canvas.draw_rect(Rect2(c - Vector2(w * 0.3, t), Vector2(w * 0.6, t * 2)), Color("4fae9c"), true)


static func _draw_gear(canvas: CanvasItem, c: Vector2, s: float) -> void:
	var r := s * 0.24
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var p := c + Vector2(cos(a), sin(a)) * (r + s * 0.055)
		canvas.draw_rect(Rect2(p - Vector2(s * 0.055, s * 0.045), Vector2(s * 0.11, s * 0.09)), Color("b58a45"), true)
	canvas.draw_circle(c, r + s * 0.02, Color("d3a85e"), true)
	canvas.draw_circle(c, r * 0.5, Color("3a2d1b"), true)
	canvas.draw_circle(c, r * 0.18, Color("16120c"), true)


static func _draw_chip(canvas: CanvasItem, c: Vector2, s: float) -> void:
	var body := s * 0.46
	var r := Rect2(c - Vector2(body, body) * 0.5, Vector2(body, body))
	for i in range(4):
		var off := -body * 0.3 + i * body * 0.2
		canvas.draw_line(c + Vector2(off, -body * 0.5), c + Vector2(off, -body * 0.5 - s * 0.08), Color("d2b36a"), 2.0)
		canvas.draw_line(c + Vector2(off, body * 0.5), c + Vector2(off, body * 0.5 + s * 0.08), Color("d2b36a"), 2.0)
		canvas.draw_line(c + Vector2(-body * 0.5, off), c + Vector2(-body * 0.5 - s * 0.08, off), Color("d2b36a"), 2.0)
		canvas.draw_line(c + Vector2(body * 0.5, off), c + Vector2(body * 0.5 + s * 0.08, off), Color("d2b36a"), 2.0)
	canvas.draw_rect(r, Color("2d4a44"), true)
	canvas.draw_rect(r.grow(-3), Color("3f6a60"), false, 1.5)
	canvas.draw_rect(Rect2(c - Vector2(body * 0.24, body * 0.24), Vector2(body * 0.48, body * 0.48)), Color("7fd6bd"), true)
	canvas.draw_circle(c, body * 0.09, Color("d8f7eb"), true)


static func _draw_battery(canvas: CanvasItem, c: Vector2, s: float) -> void:
	var w := s * 0.36
	var h := s * 0.66
	var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	canvas.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35), true)
	canvas.draw_rect(r, Color("52634c"), true)
	canvas.draw_rect(r, Color("889c78"), false, 1.5)
	canvas.draw_rect(Rect2(c + Vector2(-w * 0.22, -h * 0.56), Vector2(w * 0.44, h * 0.1)), Color("d2b36a"), true)
	canvas.draw_rect(Rect2(r.position + Vector2(2, h * 0.62), Vector2(w - 4, h * 0.11)), Color("d2b36a"), true)
	var bolt := PackedVector2Array([
		c + Vector2(4, -h * 0.28), c + Vector2(-9, h * 0.02),
		c + Vector2(-1, h * 0.02), c + Vector2(-5, h * 0.3),
		c + Vector2(11, -h * 0.04), c + Vector2(2, -h * 0.04),
	])
	canvas.draw_colored_polygon(bolt, Color("f2d27a"))


static func _draw_rig(canvas: CanvasItem, c: Vector2, s: float) -> void:
	var w := s * 0.88
	var h := s * 0.5
	var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	canvas.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35), true)
	canvas.draw_rect(r, Color("384e57"), true)
	canvas.draw_rect(r, Color("73909a"), false, 1.5)
	canvas.draw_rect(Rect2(r.position + Vector2(w * 0.08, h * 0.16), Vector2(w * 0.46, h * 0.5)), Color("204a4a"), true)
	canvas.draw_line(r.position + Vector2(w * 0.12, h * 0.3), r.position + Vector2(w * 0.44, h * 0.3), Color("73d6b4"), 1.5)
	canvas.draw_line(r.position + Vector2(w * 0.12, h * 0.46), r.position + Vector2(w * 0.34, h * 0.46), Color("4fae9c"), 1.5)
	canvas.draw_circle(r.position + Vector2(w * 0.72, h * 0.42), h * 0.17, Color("b58a45"), true)
	canvas.draw_circle(r.position + Vector2(w * 0.72, h * 0.42), h * 0.07, Color("2b2114"), true)
	canvas.draw_line(r.position + Vector2(w * 0.9, h * 0.12), r.position + Vector2(w * 0.9, -h * 0.2), Color("9ab0b4"), 2.0)


static func _draw_crystal(canvas: CanvasItem, c: Vector2, s: float) -> void:
	canvas.draw_circle(c, s * 0.42, Color(0.32, 0.86, 0.82, 0.13), true)
	var outer := PackedVector2Array([
		c + Vector2(0, -s * 0.4), c + Vector2(s * 0.24, -s * 0.04),
		c + Vector2(s * 0.12, s * 0.38), c + Vector2(-s * 0.12, s * 0.38),
		c + Vector2(-s * 0.24, -s * 0.04),
	])
	canvas.draw_colored_polygon(outer, Color("4fb9b6"))
	var inner := PackedVector2Array([
		c + Vector2(0, -s * 0.32), c + Vector2(s * 0.12, -s * 0.02),
		c + Vector2(0, s * 0.24), c + Vector2(-s * 0.12, -s * 0.02),
	])
	canvas.draw_colored_polygon(inner, Color("b8f2e6"))
	canvas.draw_line(c + Vector2(0, -s * 0.32), c + Vector2(0, s * 0.24), Color("e2fff8"), 1.2)
	canvas.draw_line(c + Vector2(-s * 0.22, -s * 0.02), c + Vector2(s * 0.22, -s * 0.02), Color(0.2, 0.6, 0.58, 0.7), 1.0)


static func _draw_blackbox(canvas: CanvasItem, c: Vector2, s: float) -> void:
	var w := s * 0.68
	var h := s * 0.5
	var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	canvas.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.45), true)
	canvas.draw_rect(r, Color("20272a"), true)
	canvas.draw_rect(r, Color("566166"), false, 1.5)
	canvas.draw_rect(Rect2(r.position + Vector2(0, h * 0.62), Vector2(w, h * 0.16)), Color("d07a3c"), true)
	canvas.draw_rect(Rect2(r.position + Vector2(w * 0.1, h * 0.18), Vector2(w * 0.34, h * 0.34)), Color("12302c"), true)
	canvas.draw_line(r.position + Vector2(w * 0.14, h * 0.36), r.position + Vector2(w * 0.38, h * 0.36), Color("74d8ae"), 1.5)
	for i in range(3):
		canvas.draw_rect(Rect2(r.position + Vector2(w * (0.62 + i * 0.1), h * 0.2), Vector2(w * 0.05, h * 0.1)), Color("6b7478"), true)
	canvas.draw_line(r.position + Vector2(w * 0.55, 0), r.position + Vector2(w * 0.55, -h * 0.18), Color("9aa4a6"), 2.0)
