class_name HD2DHud
extends CanvasLayer

# 独立 CanvasLayer 的中文 HUD。层级高于移轴后处理层，不参与屏幕模糊。

const FONT_PATH := "res://assets/fonts/noto-sans-sc-subset.woff2"
const COL_TEXT := Color("#efe3c8")
const COL_MUTED := Color("#9fb09b")
const COL_GOLD := Color("#e7b96a")
const COL_GOLD_HI := Color("#ffdc9a")
const COL_DARK := Color("#141a16")
const COL_BORDER := Color("#75613e")

var main: HD2DMain
var ui_scale := 1.0
var font: Font
var _root: Control
var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _formatters: Dictionary = {}
var _tilt_button: Button
var _night_button: Button
var _pause_button: Button
var _stats_label: Label
var _building := true


func build(p_main: HD2DMain, p_ui_scale: float) -> void:
	main = p_main
	ui_scale = p_ui_scale
	_load_font()
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = _fs(18)
	_root.theme = theme
	_build_title()
	_build_panel()
	_build_hint()
	_building = false
	sync_from_main()


func _load_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	else:
		font = ThemeDB.fallback_font
	if font is FontFile:
		var ff := font as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


func _px(value: float) -> float:
	return value * ui_scale


func _fs(value: float) -> int:
	return maxi(8, int(round(value * ui_scale)))


func _build_title() -> void:
	var panel := Panel.new()
	panel.name = "TitlePanel"
	panel.position = Vector2(_px(22), _px(20))
	panel.size = Vector2(_px(548), _px(104))
	panel.add_theme_stylebox_override("panel", _panel_style(
			Color(0.05, 0.07, 0.06, 0.76), Color(0.55, 0.45, 0.28, 0.8)))
	_root.add_child(panel)

	var title := _label("晨光农田 · 微缩沙盘", _fs(30), COL_TEXT)
	title.position = Vector2(_px(18), _px(8))
	title.size = Vector2(_px(510), _px(38))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_x", _fs(2))
	title.add_theme_constant_override("shadow_offset_y", _fs(2))
	panel.add_child(title)

	var sub := _label("2D 实时光照 · 方向长影 · 17 点双环移轴散景", _fs(15), COL_MUTED)
	sub.position = Vector2(_px(19), _px(48))
	sub.size = Vector2(_px(510), _px(24))
	panel.add_child(sub)

	_stats_label = _label("FPS -- · Draw --", _fs(15), COL_GOLD)
	_stats_label.position = Vector2(_px(19), _px(74))
	_stats_label.size = Vector2(_px(510), _px(24))
	panel.add_child(_stats_label)


func _build_panel() -> void:
	var panel := Panel.new()
	panel.name = "ControlPanel"
	panel.position = Vector2(_px(1280 - 400 - 22), _px(20))
	panel.size = Vector2(_px(400), _px(584))
	panel.add_theme_stylebox_override("panel", _panel_style(
			Color(0.055, 0.075, 0.065, 0.9), Color(0.62, 0.5, 0.3, 0.9)))
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", _fs(16))
	margin.add_theme_constant_override("margin_right", _fs(16))
	margin.add_theme_constant_override("margin_top", _fs(12))
	margin.add_theme_constant_override("margin_bottom", _fs(12))
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _fs(3))
	margin.add_child(box)

	var head := _label("移轴控制台", _fs(24), COL_GOLD_HI)
	box.add_child(head)
	var sub := _label("焦带在屏幕纵向；半径单位为屏幕像素", _fs(13), COL_MUTED)
	box.add_child(sub)
	var line := ColorRect.new()
	line.color = Color(0.55, 0.44, 0.28, 0.55)
	line.custom_minimum_size = Vector2(0, _px(1))
	box.add_child(line)

	_add_slider(box, "focus", "焦点位置", 0.0, 100.0, 1.0,
			main.focus_y * 100.0,
			func(v): return "%d%%" % int(v),
			func(v): main.set_focus_y(v / 100.0))
	_add_slider(box, "band", "焦带宽度", 4.0, 60.0, 1.0,
			main.band_half * 200.0,
			func(v): return "%d%%" % int(v),
			func(v): main.set_band_half(v / 200.0))
	_add_slider(box, "feather", "过渡羽化", 2.0, 50.0, 1.0,
			main.feather * 100.0,
			func(v): return "%d%%" % int(v),
			func(v): main.set_feather(v / 100.0))
	_add_slider(box, "strength", "模糊强度", 0.0, 150.0, 1.0,
			main.strength * 100.0,
			func(v): return "%d%%" % int(v),
			func(v): main.set_strength(v / 100.0))
	_add_slider(box, "radius", "散景半径", 0.0, 40.0, 1.0,
			main.radius,
			func(v): return "%d px" % int(v),
			func(v): main.set_radius(v))
	_add_slider(box, "angle", "光方向", -180.0, 180.0, 1.0,
			main.light_angle,
			func(v): return "%d°" % int(v),
			func(v): main.set_light_angle(v))
	_add_slider(box, "energy", "光强度", 0.0, 250.0, 5.0,
			main.light_energy * 100.0,
			func(v): return "%.2f×" % (v / 100.0),
			func(v): main.set_light_energy(v / 100.0))
	_add_slider(box, "warmth", "暖 / 冷", -100.0, 100.0, 1.0,
			main.warmth * 100.0,
			func(v): return _signed(v),
			func(v): main.set_warmth(v / 100.0))

	var line2 := ColorRect.new()
	line2.color = Color(0.55, 0.44, 0.28, 0.55)
	line2.custom_minimum_size = Vector2(0, _px(1))
	box.add_child(line2)

	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", _fs(6))
	box.add_child(toggles)
	_tilt_button = _button("移轴 开", true)
	_tilt_button.toggled.connect(func(on): main.set_post_enabled(on))
	toggles.add_child(_tilt_button)
	_night_button = _button("白天", true)
	_night_button.toggled.connect(func(on): main.set_night(on))
	toggles.add_child(_night_button)
	_pause_button = _button("暂停", true)
	_pause_button.toggled.connect(func(on): main.set_paused(on))
	toggles.add_child(_pause_button)

	var presets_label := _label("光影预设", _fs(13), COL_MUTED)
	box.add_child(presets_label)
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", _fs(6))
	box.add_child(presets)
	var morning_btn := _button("晨光", false)
	morning_btn.pressed.connect(func(): main.apply_preset("morning"))
	presets.add_child(morning_btn)
	var dusk_btn := _button("黄昏", false)
	dusk_btn.pressed.connect(func(): main.apply_preset("dusk"))
	presets.add_child(dusk_btn)
	var night_btn := _button("夜灯", false)
	night_btn.pressed.connect(func(): main.apply_preset("night"))
	presets.add_child(night_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, _px(4))
	box.add_child(spacer)
	var note := _label("17 taps = 中心 4 + 内环 8×2 + 外环 8×1 = 28", _fs(12), COL_MUTED)
	box.add_child(note)
	var note2 := _label("焦内 Point 采样直接输出；焦外才做双环散景", _fs(12), COL_MUTED)
	box.add_child(note2)
	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer2)
	var foot := _label("B 前后对比   SPACE 暂停   N 昼夜   H 界面   1/2/3 预设", _fs(12), COL_MUTED)
	box.add_child(foot)


func _build_hint() -> void:
	var panel := Panel.new()
	panel.position = Vector2(_px(22), _px(658))
	panel.size = Vector2(_px(604), _px(40))
	panel.add_theme_stylebox_override("panel", _panel_style(
			Color(0.05, 0.07, 0.06, 0.66), Color(0.45, 0.38, 0.25, 0.65)))
	_root.add_child(panel)
	var hint := _label("拖动滑杆实时调参 · 焦外双环散景 · HUD 独立层，不参与模糊", _fs(14), COL_TEXT)
	hint.position = Vector2(_px(12), _px(8))
	hint.size = Vector2(_px(580), _px(24))
	panel.add_child(hint)


func _add_slider(parent: VBoxContainer, key: String, text: String,
		min_v: float, max_v: float, step: float, value: float,
		formatter: Callable, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, _px(29))
	row.add_theme_constant_override("separation", _fs(6))
	parent.add_child(row)
	var label := _label(text, _fs(16), COL_TEXT)
	label.custom_minimum_size = Vector2(_px(82), 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.set_value_no_signal(value)
	slider.custom_minimum_size = Vector2(_px(120), _px(18))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	row.add_child(slider)
	var value_label := _label(formatter.call(value), _fs(15), COL_GOLD)
	value_label.custom_minimum_size = Vector2(_px(62), 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	_sliders[key] = slider
	_values[key] = value_label
	_formatters[key] = formatter
	slider.value_changed.connect(func(v):
		value_label.text = formatter.call(v)
		setter.call(v))


func _set_slider(key: String, value: float) -> void:
	if not _sliders.has(key):
		return
	var slider: HSlider = _sliders[key]
	slider.set_value_no_signal(clampf(value, slider.min_value, slider.max_value))
	var formatter: Callable = _formatters[key]
	var value_label: Label = _values[key]
	value_label.text = formatter.call(slider.value)


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#1c231e")
	track.border_color = Color("#4f4834")
	track.set_border_width_all(maxi(1, int(_px(1))))
	track.content_margin_top = _px(3)
	track.content_margin_bottom = _px(3)
	track.content_margin_left = _px(1)
	track.content_margin_right = _px(1)
	slider.add_theme_stylebox_override("slider", track)
	var fill := track.duplicate()
	fill.bg_color = Color("#b78645")
	fill.border_color = Color("#e0b66c")
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var grabber := HD2DArt.make_grabber()
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber)
	slider.add_theme_icon_override("grabber_disabled", grabber)


func _button(text: String, toggle: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.custom_minimum_size = Vector2(0, _px(27))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", _fs(15))
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_GOLD_HI)
	b.add_theme_color_override("font_pressed_color", Color("#20170d"))
	b.add_theme_color_override("font_hover_pressed_color", Color("#20170d"))
	b.add_theme_stylebox_override("normal", _button_style(Color("#232b24"), COL_BORDER))
	b.add_theme_stylebox_override("hover", _button_style(Color("#303a2f"), COL_GOLD))
	b.add_theme_stylebox_override("pressed", _button_style(Color("#d9a85c"), Color("#ffe0a0")))
	b.add_theme_stylebox_override("hover_pressed", _button_style(Color("#e7b96a"), Color("#ffe7b0")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(maxi(1, int(_px(1))))
	sb.content_margin_left = _px(4)
	sb.content_margin_right = _px(4)
	sb.content_margin_top = _px(2)
	sb.content_margin_bottom = _px(2)
	return sb


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(maxi(1, int(_px(1))))
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = int(_px(4))
	sb.shadow_offset = Vector2(_px(2), _px(3))
	return sb


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _signed(value: float) -> String:
	var n := int(round(value))
	if n > 0:
		return "+%d" % n
	return "%d" % n


func sync_from_main() -> void:
	if main == null or _building:
		return
	_set_slider("focus", main.focus_y * 100.0)
	_set_slider("band", main.band_half * 200.0)
	_set_slider("feather", main.feather * 100.0)
	_set_slider("strength", main.strength * 100.0)
	_set_slider("radius", main.radius)
	_set_slider("angle", main.light_angle)
	_set_slider("energy", main.light_energy * 100.0)
	_set_slider("warmth", main.warmth * 100.0)
	if _tilt_button != null:
		_tilt_button.set_pressed_no_signal(main.post_enabled)
		_tilt_button.text = "移轴 开" if main.post_enabled else "移轴 关"
	if _night_button != null:
		_night_button.set_pressed_no_signal(main.night)
		_night_button.text = "夜晚" if main.night else "白天"
	if _pause_button != null:
		_pause_button.set_pressed_no_signal(main.paused)
		_pause_button.text = "继续" if main.paused else "暂停"


func set_stats_visible(value: bool) -> void:
	if _stats_label != null:
		_stats_label.visible = value


func update_stats(fps: float, draws: int, size: Vector2i) -> void:
	if _stats_label == null:
		return
	_stats_label.text = "FPS %d · Draw %d · %d×%d · 焦点 %d%% · 强度 %d%%" % [
		int(round(fps)), draws, size.x, size.y,
		int(round(main.focus_y * 100.0)), int(round(main.strength * 100.0))]
