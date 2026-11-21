class_name UIButton
extends Control

signal pressed

enum Kind { GOLD, SLATE, DANGER, ICE, GHOST }

var kind: int = Kind.GOLD
var disabled: bool = false
var _hovered: bool = false
var _down: bool = false
var _bg: GradientRect
var _glow: TextureRect
var _label: Label
var _font_size: int = 20


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _label != null:
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)
		resized.connect(_sync_size)
		_sync_size()


func setup(text: String, p_kind: int, size_px: Vector2, font_size: int = 20) -> UIButton:
	kind = p_kind
	_font_size = font_size
	custom_minimum_size = size_px
	size = size_px
	pivot_offset = size_px * 0.5
	if _label == null:
		_glow = ThemeKit.glow_texture_rect("glow", Color(1.0, 0.86, 0.5, 0.0))
		_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add_child(_glow)
		_bg = GradientRect.new()
		add_child(_bg)
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
		var ls := LabelSettings.new()
		ls.font = ThemeKit.body_font()
		ls.font_size = font_size
		ls.font_color = ThemeKit.BUTTON_TEXT
		ls.outline_size = 0
		_label.label_settings = ls
	_label.text = text
	_apply_style()
	_sync_size()
	if is_inside_tree():
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not disabled else Control.CURSOR_ARROW
		mouse_filter = Control.MOUSE_FILTER_STOP
		if not mouse_entered.is_connected(_on_enter):
			mouse_entered.connect(_on_enter)
			mouse_exited.connect(_on_exit)
			resized.connect(_sync_size)
	return self


func set_text(text: String) -> void:
	if _label != null:
		_label.text = text


func set_disabled(value: bool) -> void:
	disabled = value
	if _label != null:
		_apply_style()
		mouse_default_cursor_shape = Control.CURSOR_ARROW if value else Control.CURSOR_POINTING_HAND


func _sync_size() -> void:
	if _bg == null:
		return
	pivot_offset = size * 0.5
	_bg.position = Vector2.ZERO
	_bg.setup(size, 9.0, Color.WHITE, Color.WHITE)
	_bg.visible = true
	_label.position = Vector2.ZERO
	_label.size = size
	_glow.position = -Vector2(14, 14)
	_glow.size = size + Vector2(28, 28)
	_apply_style()


func _apply_style() -> void:
	if _bg == null:
		return
	var top := ThemeKit.GOLD_BRIGHT
	var bottom := Color("ffc531")
	var border := Color("a86f19")
	var text_col := ThemeKit.BUTTON_TEXT
	var gloss := 0.75
	match kind:
		Kind.GOLD:
			top = Color("ffefae")
			bottom = Color("ffc531")
			border = Color("a86f19")
			text_col = ThemeKit.BUTTON_TEXT
		Kind.SLATE:
			top = Color("e2f0fa")
			bottom = Color("a9c8de")
			border = Color("678ca5")
			text_col = Color("17384c")
			gloss = 0.55
		Kind.DANGER:
			top = Color("ffb8ae")
			bottom = Color("d94a40")
			border = Color("84231f")
			text_col = Color("4c120f")
			gloss = 0.6
		Kind.ICE:
			top = Color("c7f6ee")
			bottom = Color("63d4c3")
			border = Color("2f8b7d")
			text_col = Color("104f48")
			gloss = 0.65
		Kind.GHOST:
			top = Color(0.12, 0.28, 0.38, 0.35)
			bottom = Color(0.05, 0.16, 0.24, 0.55)
			border = Color(0.91, 0.78, 0.47, 0.7)
			text_col = ThemeKit.GOLD_BRIGHT
			gloss = 0.2
	if disabled:
		top = ThemeKit.DISABLED_TOP
		bottom = ThemeKit.DISABLED_BOTTOM
		border = Color("768b98")
		text_col = Color("e7eef3")
	elif _hovered:
		top = top.lightened(0.12)
		bottom = bottom.lightened(0.16)
	_bg.setup(size, 9.0, top, bottom, border, 2.0, gloss)
	_label.label_settings.font_color = text_col
	_label.label_settings.font_size = _font_size
	_label.label_settings.font = ThemeKit.body_font()
	if _glow != null:
		var glow_col := Color(1.0, 0.88, 0.55, 0.0)
		if _hovered and not disabled:
			glow_col.a = 0.30 if kind == Kind.GOLD or kind == Kind.ICE else 0.18
		_glow.modulate = glow_col
	_glow.visible = kind != Kind.GHOST


func _on_enter() -> void:
	if disabled:
		return
	_hovered = true
	_apply_style()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.035, 1.035), 0.12)


func _on_exit() -> void:
	_hovered = false
	_down = false
	_apply_style()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "scale", Vector2(0.97, 0.97), 0.06)
			accept_event()
		else:
			if _down and Rect2(Vector2.ZERO, size).has_point(event.position):
				_down = false
				pressed.emit()
				var tw := create_tween()
				tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(self, "scale", Vector2(1.035, 1.035), 0.10)
			else:
				_down = false
			accept_event()


func click_for_test() -> void:
	if not disabled:
		pressed.emit()
