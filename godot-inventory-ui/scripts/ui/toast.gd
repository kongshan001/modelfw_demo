class_name Toast
extends Control

var _pill: Control
var _bg: GradientRect
var _label: Label
var _tween: Tween
var _font_size := 15


func setup() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill = Control.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pill)
	_bg = GradientRect.new()
	_pill.add_child(_bg)
	_label = Label.new()
	_label.position = Vector2(24, 0)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = ThemeKit.body_font()
	ls.font_size = _font_size
	ls.font_color = Color("f4fbff")
	ls.outline_size = 2
	ls.outline_color = Color(0.02, 0.06, 0.1, 0.8)
	_label.label_settings = ls
	_pill.add_child(_label)
	modulate.a = 0.0


func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0


func show_message(text: String, accent: Color = Color("ffe6a9")) -> void:
	if _label == null:
		return
	_label.text = text
	var w: float = maxf(190.0, minf(900.0, ThemeKit.body_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x + 56.0))
	var h := 40.0
	_pill.size = Vector2(w, h)
	_pill.position = Vector2((1280.0 - w) * 0.5, 618.0)
	_bg.setup(Vector2(w, h), 12.0, Color(0.05, 0.14, 0.20, 0.94), Color(0.02, 0.07, 0.11, 0.96),
		Color(accent.r, accent.g, accent.b, 0.85), 1.5, 0.0)
	_label.position = Vector2(20, 0)
	_label.size = Vector2(w - 40, h)
	_label.label_settings.font_color = Color("f6fcff")
	_pill.position.y = 628.0
	modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.12)
	_tween.parallel().tween_property(_pill, "position:y", 618.0, 0.16)
	_tween.tween_interval(1.35)
	_tween.tween_property(self, "modulate:a", 0.0, 0.20)
