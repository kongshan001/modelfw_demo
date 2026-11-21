class_name ItemCell
extends Control

signal hovered(cell, item, screen_pos)
signal unhovered(cell)
signal clicked(cell, item, index)
signal double_clicked(cell, item, index)

var item: Dictionary = {}
var index: int = -1
var selected: bool = false
var hovered_state: bool = false

var _built := false
var _content: Control
var _glow: TextureRect
var _sel_glow: TextureRect
var _bg: GradientRect
var _icon: TextureRect
var _count: Label
var _decor: Control
var _time := 0.0
var _cell_size := Vector2(102, 85)


func allocate(size_px: Vector2) -> void:
	_cell_size = size_px
	custom_minimum_size = size_px
	size = size_px
	pivot_offset = size_px * 0.5
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process(false)

	_sel_glow = ThemeKit.glow_texture_rect("glow", Color(1.0, 0.82, 1.0, 0.0))
	_sel_glow.position = Vector2(-18, -18)
	_sel_glow.size = size_px + Vector2(36, 36)
	_sel_glow.visible = false
	add_child(_sel_glow)

	_glow = ThemeKit.glow_texture_rect("glow", Color(1.0, 0.92, 0.68, 0.0))
	_glow.position = Vector2(-12, -12)
	_glow.size = size_px + Vector2(24, 24)
	_glow.visible = false
	add_child(_glow)

	_content = Control.new()
	_content.position = Vector2.ZERO
	_content.size = size_px
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_bg = GradientRect.new()
	_content.add_child(_bg)
	_bg.setup(size_px, 6.0, ThemeKit.CELL_TOP, ThemeKit.CELL_BOTTOM,
		ThemeKit.quality_color(0), 2.4, 0.4)

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(12, 3)
	_icon.size = Vector2(78, 78)
	_icon.pivot_offset = _icon.size * 0.5
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_icon)

	_count = Label.new()
	_count.position = Vector2(54, 57)
	_count.size = Vector2(42, 24)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = ThemeKit.body_font()
	ls.font_size = 19
	ls.font_color = ThemeKit.TEXT_LIGHT
	ls.outline_size = 4
	ls.outline_color = Color(0.06, 0.16, 0.24, 0.92)
	_count.label_settings = ls
	_content.add_child(_count)

	_decor = Decor.new()
	_decor.size = size_px
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_decor)

	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)


func set_item(new_item: Dictionary, new_index: int) -> void:
	if not _built:
		allocate(_cell_size)
	item = new_item
	index = new_index
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon.visible = true
	_icon.texture = ThemeKit.icon(str(item.get("icon", "pouch")))
	var stack := int(item.get("stack", 1))
	_count.text = str(stack)
	_count.visible = stack > 1
	_decor.setup(int(item.get("quality", 0)), not bool(item.get("bindable", true)),
		str(item.get("category", "")) == "装备")
	_apply_frame()


func set_empty(new_index: int) -> void:
	if not _built:
		allocate(_cell_size)
	item = {}
	index = new_index
	hovered_state = false
	set_selected(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _icon != null:
		_icon.texture = null
		_icon.visible = false
	if _count != null:
		_count.visible = false
	if _decor != null:
		_decor.setup(0, false, false)
	if _content != null:
		_content.position = Vector2.ZERO
	if _glow != null:
		_glow.visible = false
	_apply_frame()


func set_selected(value: bool) -> void:
	selected = value
	_apply_frame()
	set_process(value or hovered_state)
	if _sel_glow != null:
		_sel_glow.visible = value
		if not value:
			_sel_glow.modulate.a = 0.0


func _apply_frame() -> void:
	if _bg == null:
		return
	var q := int(item.get("quality", 0))
	var top := ThemeKit.CELL_TOP_HOT if hovered_state else ThemeKit.CELL_TOP
	var bottom := ThemeKit.CELL_BOTTOM_HOT if hovered_state else ThemeKit.CELL_BOTTOM
	# Reference grid borders are mostly pale ice-blue; quality hues stay
	# subtle here and are strongest on the equipment slots.
	var border := ThemeKit.quality_color(q).lerp(Color("cfe6f8"), 0.42)
	var bw := 2.4
	if q >= 2:
		bw = 2.8
	if selected:
		border = Color("ffefc8")
		bw = 3.2
	elif hovered_state:
		border = ThemeKit.quality_color(q).lightened(0.2)
	_bg.setup(_cell_size, 6.0, top, bottom, border, bw, 0.46)
	_decor.queue_redraw()


func _on_mouse_enter() -> void:
	if not is_visible_in_tree():
		return
	hovered_state = true
	_apply_frame()
	set_process(true)
	if _glow != null:
		_glow.visible = true
		_glow.modulate = Color(1.0, 0.92, 0.68, 0.45)
	if _content != null:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_content, "position", Vector2(0, -3), 0.12)
	hovered.emit(self, item, get_global_rect().position + Vector2(size.x - 4, 6))


func _on_mouse_exit() -> void:
	hovered_state = false
	_apply_frame()
	if _glow != null:
		var tw := create_tween()
		tw.tween_property(_glow, "modulate:a", 0.0, 0.12)
		tw.tween_callback(func() -> void:
			if not hovered_state:
				_glow.visible = false)
	if _content != null:
		var tw2 := create_tween()
		tw2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw2.tween_property(_content, "position", Vector2.ZERO, 0.12)
	set_process(selected)
	unhovered.emit(self)


func _process(delta: float) -> void:
	_time += delta
	if selected and _sel_glow != null:
		_sel_glow.modulate.a = 0.24 + 0.16 * (0.5 + 0.5 * sin(_time * 4.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			double_clicked.emit(self, item, index)
		else:
			clicked.emit(self, item, index)
		accept_event()


func play_use_flash() -> void:
	if _icon == null:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_icon, "scale", Vector2(1.18, 1.18), 0.10)
	tw.tween_property(_icon, "scale", Vector2.ONE, 0.16)
	if _glow != null:
		_glow.visible = true
		_glow.modulate = Color(1.0, 0.95, 0.7, 0.95)
		var tw2 := create_tween()
		tw2.tween_property(_glow, "modulate:a", 0.0, 0.38)
		tw2.tween_callback(func() -> void:
			if not hovered_state:
				_glow.visible = false)


func simulate_hover(on: bool) -> void:
	if on:
		_on_mouse_enter()
	else:
		_on_mouse_exit()


func press_for_test(as_double: bool = false) -> void:
	if as_double:
		double_clicked.emit(self, item, index)
	else:
		clicked.emit(self, item, index)


func get_center_global() -> Vector2:
	return get_global_rect().position + size * 0.5


class Decor extends Control:
	var quality := 0
	var bound := false
	var equipped := false

	func setup(q: int, is_bound: bool, is_equipment: bool) -> void:
		quality = q
		bound = is_bound
		equipped = is_equipment
		queue_redraw()

	func _draw() -> void:
		# No quality diamond: the reference conveys quality through the cell
		# border only. Bound items keep the small silver lock in the top-right.
		if bound:
			var lc := Color(0.90, 0.95, 1.0, 0.92)
			var lc2 := Color(0.42, 0.55, 0.66, 0.95)
			draw_rect(Rect2(size.x - 20, 8, 11, 9), lc, true)
			draw_rect(Rect2(size.x - 20, 8, 11, 9), lc2, false, 1.0)
			draw_arc(Vector2(size.x - 14.5, 8), 3.6, PI, TAU, 12, lc, 1.6)
			draw_rect(Rect2(size.x - 17, 12.5, 5, 2), lc2)
