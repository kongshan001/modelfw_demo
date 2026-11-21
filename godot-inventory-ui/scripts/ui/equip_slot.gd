class_name EquipSlot
extends Control

signal hovered(slot, data, screen_pos)
signal unhovered(slot)
signal clicked(slot, data)

const SLOT_SIZE := 96.0

var data: Dictionary = {}
var _built := false
var _glow: TextureRect
var _bg: GradientRect
var _icon: TextureRect
var _level: Label
var _enchant_chip: GradientRect
var _enchant: Label
var _plus: Label
var _hover := false
var _time := 0.0


func setup(slot_data: Dictionary) -> void:
	data = slot_data
	size = Vector2(SLOT_SIZE, SLOT_SIZE)
	custom_minimum_size = size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	if _built:
		_refresh()
		return
	_built = true
	_glow = ThemeKit.glow_texture_rect("glow", Color(1.0, 0.93, 0.7, 0.0))
	_glow.position = Vector2(-18, -18)
	_glow.size = Vector2(SLOT_SIZE + 36, SLOT_SIZE + 36)
	_glow.visible = false
	add_child(_glow)

	_bg = GradientRect.new()
	_bg.position = Vector2.ZERO
	add_child(_bg)

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(10, 8)
	_icon.size = Vector2(76, 76)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	var pill := GradientRect.new()
	pill.position = Vector2(4, 73)
	pill.setup(Vector2(42, 18), 9.0, Color(0.09, 0.22, 0.32, 0.92), Color(0.04, 0.13, 0.20, 0.95),
		Color(0.91, 0.76, 0.44, 0.8), 1.0, 0.0)
	add_child(pill)
	_level = Label.new()
	_level.position = Vector2(4, 73)
	_level.size = Vector2(42, 18)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = ThemeKit.body_font()
	ls.font_size = 10
	ls.font_color = ThemeKit.GOLD_BRIGHT
	_level.label_settings = ls
	add_child(_level)

	_enchant_chip = GradientRect.new()
	_enchant_chip.position = Vector2(-7, 98)
	_enchant_chip.setup(Vector2(110, 17), 8.0, Color(0.08, 0.2, 0.29, 0.55), Color(0.04, 0.12, 0.19, 0.65),
		Color(0.72, 0.88, 0.96, 0.35), 1.0, 0.0)
	add_child(_enchant_chip)
	_enchant = Label.new()
	_enchant.position = Vector2(-6, 98)
	_enchant.size = Vector2(100, 17)
	_enchant.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enchant.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enchant.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var es := LabelSettings.new()
	es.font = ThemeKit.body_font()
	es.font_size = 10
	es.font_color = Color(0.87, 0.96, 1.0)
	es.outline_size = 2
	es.outline_color = Color(0.06, 0.16, 0.23, 0.9)
	_enchant.label_settings = es
	add_child(_enchant)

	_plus = Label.new()
	_plus.text = "+"
	_plus.position = Vector2(84, 98)
	_plus.size = Vector2(16, 17)
	_plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := LabelSettings.new()
	ps.font = ThemeKit.body_font()
	ps.font_size = 12
	ps.font_color = ThemeKit.GOLD_BRIGHT
	ps.outline_size = 2
	ps.outline_color = Color(0.08, 0.2, 0.28, 0.9)
	_plus.label_settings = ps
	add_child(_plus)

	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	set_process(false)
	_refresh()


func _refresh() -> void:
	if _bg == null:
		return
	var q := int(data.get("quality", 0))
	_bg.setup(Vector2(SLOT_SIZE, SLOT_SIZE), 11.0,
		ThemeKit.CELL_TOP_HOT if _hover else ThemeKit.CELL_TOP,
		ThemeKit.CELL_BOTTOM_HOT if _hover else ThemeKit.CELL_BOTTOM,
		ThemeKit.quality_color(q).lightened(0.12) if _hover else ThemeKit.quality_color(q),
		3.0, 0.5)
	_icon.texture = ThemeKit.icon(str(data.get("icon", "pouch")))
	_level.text = "%d级" % int(data.get("level", 1))
	var enchant := str(data.get("enchant", ""))
	var show_enchant := enchant == "未附魔"
	_enchant.text = enchant
	_enchant.visible = show_enchant
	_enchant_chip.visible = show_enchant
	_plus.visible = show_enchant
	_glow.visible = _hover or q >= 3
	set_process(q >= 3)


func _process(delta: float) -> void:
	_time += delta
	if _glow != null and not _hover:
		_glow.visible = true
		var a := 0.10 + 0.06 * (0.5 + 0.5 * sin(_time * 2.2))
		_glow.modulate = Color(1.0, 0.88, 0.55, a)


func _on_enter() -> void:
	_hover = true
	_refresh()
	if _glow != null:
		_glow.visible = true
		_glow.modulate = Color(1.0, 0.93, 0.7, 0.45)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.055, 1.055), 0.12)
	hovered.emit(self, data, get_global_rect().position + Vector2(size.x + 8, 0))


func _on_exit() -> void:
	_hover = false
	_refresh()
	if _glow != null:
		var gq := int(data.get("quality", 0))
		if gq >= 3:
			pass
		else:
			_glow.visible = false
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)
	unhovered.emit(self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self, data)
		accept_event()


func simulate_hover(on: bool) -> void:
	if on:
		_on_enter()
	else:
		_on_exit()


func press_for_test() -> void:
	clicked.emit(self, data)
