class_name CoinRow
extends Control

signal plus_pressed(kind: String)

# Reference (529x356): icon 276..291, pill 292..393, row h 16 -> 1280x720:
# icon ~32 px, pill 246x32, row 300x36.
var kind := "gold"
var value := 0
var _label: Label
var _hover_plus := false
var _built := false


func setup(p_kind: String, start_value: int) -> void:
	kind = p_kind
	value = start_value
	size = Vector2(300, 36)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _built:
		set_value(start_value)
		return
	_built = true
	var pill_h := 30.0 if kind == "silver" else 32.0
	var pill_y := 3.0 if kind == "silver" else 2.0
	var bg := GradientRect.new()
	bg.position = Vector2(50, pill_y)
	bg.setup(Vector2(246, pill_h), 16.0, Color("a6cdf0"), Color("79aee2"),
		Color("dff2ff"), 1.4, 0.55)
	add_child(bg)
	_label = Label.new()
	_label.position = Vector2(56, pill_y)
	_label.size = Vector2(190, pill_h)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = ThemeKit.body_font()
	ls.font_size = 24
	ls.font_color = Color("f6fdff")
	ls.outline_size = 3
	ls.outline_color = ThemeKit.BAR_INK
	_label.label_settings = ls
	add_child(_label)
	var plus_bg := GradientRect.new()
	plus_bg.position = Vector2(250, 3)
	plus_bg.setup(Vector2(44, 30), 7.0, Color("9bd8ff"), Color("4f9cd8"),
		Color("2a6c9a"), 1.4, 0.6)
	add_child(plus_bg)
	var plus := Label.new()
	plus.text = "+"
	plus.position = Vector2(250, 3)
	plus.size = Vector2(44, 30)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pls := LabelSettings.new()
	pls.font = ThemeKit.body_font()
	pls.font_size = 22
	pls.font_color = Color(0.97, 1.0, 1.0)
	pls.outline_size = 2
	pls.outline_color = ThemeKit.BAR_INK
	plus.label_settings = pls
	add_child(plus)
	set_value(start_value)


func set_value(v: int) -> void:
	value = v
	if _label != null:
		_label.text = str(value)


func pill_rect() -> Rect2:
	var pill_h := 30.0 if kind == "silver" else 32.0
	var pill_y := 3.0 if kind == "silver" else 2.0
	return Rect2(position + Vector2(50, pill_y), Vector2(246, pill_h))


func _draw() -> void:
	var c := Vector2(26, 18)
	if kind == "gold":
		draw_circle(c + Vector2(0, 1), 17.0, Color(0.2, 0.12, 0.03, 0.25))
		draw_circle(c, 16.0, Color(0.98, 0.82, 0.35, 0.30))
		draw_circle(c, 14.6, Color("8f5c1c"))
		draw_circle(c, 13.0, Color("ffd76a"))
		draw_circle(c, 10.0, Color("d79b34"))
		draw_circle(c, 8.4, Color("f6c95f"))
		draw_rect(Rect2(c - Vector2(3.6, 3.6), Vector2(7.2, 7.2)), Color(0.36, 0.24, 0.12, 0.9))
		draw_line(c + Vector2(-6.5, -4.5), c + Vector2(-2, -8), Color(1, 1, 1, 0.75), 1.6)
	else:
		var pts := PackedVector2Array([
			c + Vector2(-13, 3), c + Vector2(-10, -2), c + Vector2(-3, -6),
			c + Vector2(3, -6), c + Vector2(10, -2), c + Vector2(13, 3),
			c + Vector2(9, 8), c + Vector2(-9, 8),
		])
		draw_colored_polygon(pts, Color("dfeaf3"))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.55, 0.67, 0.76, 0.9), 1.4)
		draw_polygon(PackedVector2Array([
			c + Vector2(-8, 0), c + Vector2(0, -3.4), c + Vector2(8, 0), c + Vector2(0, 3.4),
		]), PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8), Color(0.86, 0.93, 0.98, 0.8), Color(1, 1, 1, 0.8)]))
		draw_line(c + Vector2(-5, 5.4), c + Vector2(5, 5.4), Color(0.65, 0.76, 0.85, 0.8), 1.2)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.position.x >= 250:
			plus_pressed.emit(kind)
			accept_event()
