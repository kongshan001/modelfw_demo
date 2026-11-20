extends CanvasLayer

# Compact UI: a small title card and a bottom bar, so the pond stays visible.

var world
var slider: HSlider
var time_label: Label
var status: Label
var _mode := 0

const GOLD := Color(1.0, 0.85, 0.58)
const TEAL := Color(0.55, 0.92, 0.88)
const DIM := Color(0.78, 0.84, 0.88)


func setup(w) -> void:
	world = w
	_build()
	slider.value_changed.connect(_on_time)
	_on_time(slider.value)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# title card
	var title_panel := PanelContainer.new()
	title_panel.position = Vector2(24.0, 18.0)
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_theme_stylebox_override("panel", _style(
		Color(0.035, 0.06, 0.075, 0.72), Color(0.55, 0.92, 0.88, 0.22)))
	root.add_child(title_panel)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	title_panel.add_child(tv)
	tv.add_child(_label("星海浅湾", 24, GOLD))
	tv.add_child(_label("STARWATER · 通透像素水体 / 2D water Shader", 11, TEAL))

	# bottom bar
	var bar := PanelContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 24.0
	bar.offset_right = -24.0
	bar.offset_top = -84.0
	bar.offset_bottom = -18.0
	bar.add_theme_stylebox_override("panel", _style(
		Color(0.035, 0.06, 0.075, 0.82), Color(0.55, 0.92, 0.88, 0.20)))
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bar)

	var vv := VBoxContainer.new()
	vv.add_theme_constant_override("separation", 4)
	bar.add_child(vv)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label("时间", 13, DIM))
	slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 24.0
	slider.step = 0.5
	slider.value = 12.0
	slider.custom_minimum_size = Vector2(260.0, 18.0)
	row.add_child(slider)
	time_label = _label("12:00", 14, GOLD)
	time_label.custom_minimum_size = Vector2(56.0, 0.0)
	row.add_child(time_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	status = _label("VIEW 正常 · CAUSTICS ON · REFRACT ON · FOAM ON", 12, TEAL)
	row.add_child(status)
	vv.add_child(row)

	vv.add_child(_label(
		"WASD / 方向键 移动   ·   点击水面 涟漪 / 落点汇流   ·   F1 mask   F2 深度   F3 焦散   F4 折射   F5 泡沫",
		12, DIM))


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _on_time(v: float) -> void:
	if world == null:
		return
	world.set_time(v)
	var h := int(floor(v))
	var m := int(round((v - h) * 60.0)) % 60
	time_label.text = "%02d:%02d" % [h, m]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F1:
			_mode = 0 if _mode == 1 else 1
			world.set_debug(_mode)
		KEY_F2:
			_mode = 0 if _mode == 2 else 2
			world.set_debug(_mode)
		KEY_F3:
			world.toggle_caustic()
		KEY_F4:
			world.toggle_refract()
		KEY_F5:
			world.toggle_foam()
		_:
			return
	_update_status()


func _update_status() -> void:
	var view := "正常"
	if _mode == 1:
		view = "MASK"
	elif _mode == 2:
		view = "DEPTH"
	status.text = "VIEW %s · CAUSTICS %s · REFRACT %s · FOAM %s" % [
		view,
		"ON" if world._caustic_on else "OFF",
		"ON" if world._refract_on else "OFF",
		"ON" if world._foam_on else "OFF",
	]
