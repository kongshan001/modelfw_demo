class_name CoinRow
extends Control

signal plus_pressed(kind: String)

var kind := "gold"
var value := 0
var _label: Label
var _hover_plus := false
var _built := false


func setup(p_kind: String, start_value: int) -> void:
	kind = p_kind
	value = start_value
	size = Vector2(372, 28)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _built:
		set_value(start_value)
		return
	_built = true
	var bg := GradientRect.new()
	bg.position = Vector2(34, 0)
	bg.setup(Vector2(298, 28), 14.0, Color("e5f5fe"), Color("b7d5e8"),
		Color("f5feff"), 1.4, 0.5)
	add_child(bg)
	_label = Label.new()
	_label.position = Vector2(44, 0)
	_label.size = Vector2(280, 28)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = ThemeKit.body_font()
	ls.font_size = 18
	ls.font_color = ThemeKit.TEXT_INK
	ls.shadow_size = 0
	_label.label_settings = ls
	add_child(_label)
	var plus_bg := GradientRect.new()
	plus_bg.position = Vector2(338, 2)
	plus_bg.setup(Vector2(30, 24), 6.0, Color("9be0ff"), Color("3d8fd0"),
		Color("2a6c9a"), 1.4, 0.6)
	add_child(plus_bg)
	var plus := Label.new()
	plus.text = "+"
	plus.position = Vector2(338, 2)
	plus.size = Vector2(30, 24)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pls := LabelSettings.new()
	pls.font = ThemeKit.body_font()
	pls.font_size = 17
	pls.font_color = Color(0.96, 1.0, 1.0)
	plus.label_settings = pls
	add_child(plus)
	mouse_entered.connect(func() -> void: queue_redraw())
	set_value(start_value)


func set_value(v: int) -> void:
	value = v
	if _label != null:
		_label.text = str(value)


func _draw() -> void:
	var c := Vector2(16, 14)
	if kind == "gold":
		draw_circle(c + Vector2(0, 1), 16.5, Color(0.2, 0.12, 0.03, 0.22))
		draw_circle(c, 15.5, Color(0.98, 0.82, 0.35, 0.30))
		draw_circle(c, 14.2, Color("8f5c1c"))
		draw_circle(c, 12.6, Color("ffd76a"))
		draw_circle(c, 9.8, Color("d79b34"))
		draw_circle(c, 8.2, Color("f6c95f"))
		draw_rect(Rect2(c - Vector2(3.4, 3.4), Vector2(6.8, 6.8)), Color(0.36, 0.24, 0.12, 0.9))
		draw_line(c + Vector2(-6.5, -4.5), c + Vector2(-2, -8), Color(1, 1, 1, 0.75), 1.5)
	else:
		var pts := PackedVector2Array([
			c + Vector2(-12, 3), c + Vector2(-9, -2), c + Vector2(-3, -5),
			c + Vector2(3, -5), c + Vector2(9, -2), c + Vector2(12, 3),
			c + Vector2(8, 7), c + Vector2(-8, 7),
		])
		draw_colored_polygon(pts, Color("dfeaf3"))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.55, 0.67, 0.76, 0.9), 1.2)
		draw_polygon(PackedVector2Array([
			c + Vector2(-7, 0), c + Vector2(0, -3), c + Vector2(7, 0), c + Vector2(0, 3),
		]), PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8), Color(0.86, 0.93, 0.98, 0.8), Color(1, 1, 1, 0.8)]))
		draw_line(c + Vector2(-5, 5), c + Vector2(5, 5), Color(0.65, 0.76, 0.85, 0.8), 1.2)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.position.x >= 334:
			plus_pressed.emit(kind)
			accept_event()
