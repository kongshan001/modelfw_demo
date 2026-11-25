extends CanvasLayer

# 中文参数面板：时间/刻数、时间滑杆、播放/暂停、速度、阴影/调试/花瓣开关，
# 以及高度角、方位角、影长、光照向量、影向、FPS/draw calls。
# UI 以 1280×720 设计，窗口/离屏视口变化时由 main 统一缩放 CanvasLayer。

const DESIGN := Vector2(1280.0, 720.0)
const PANEL_W := 338.0
const TEXT := Color(0.86, 0.93, 0.83)
const DIM := Color(0.58, 0.70, 0.59)
const WARM := Color(1.00, 0.87, 0.64)
const PINK := Color(1.00, 0.68, 0.78)
const GREEN := Color(0.56, 0.88, 0.63)
const BG := Color(0.045, 0.085, 0.070, 0.93)
const BORDER := Color(0.48, 0.72, 0.48, 0.88)

var main: Node
var dial: SunDial

var _font: SystemFont
var _root: Control
var _panel: PanelContainer
var _time_label: Label
var _tick_label: Label
var _phase_label: Label
var _time_slider: HSlider
var _play_button: Button
var _shadows_check: CheckBox
var _debug_check: CheckBox
var _petals_check: CheckBox
var _stats: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _fps_label: Label
var _syncing := false
var _slider_dragging := false
var _accum := 0.0
var _fps_accum := 0.0


func _ready() -> void:
	_build_ui()
	set_process(true)


func setup(main_node: Node) -> void:
	main = main_node
	if dial != null:
		dial.main = main
		dial.font = _font
	sync_from_main()


func set_ui_visible(value: bool) -> void:
	if _root != null:
		_root.visible = value


func set_fps_visible(value: bool) -> void:
	if _fps_label != null:
		_fps_label.visible = value


func sync_from_main() -> void:
	if main == null:
		return
	_syncing = true
	_time_slider.set_value_no_signal(main.get_hour())
	_shadows_check.set_pressed_no_signal(main.are_shadows_enabled())
	_debug_check.set_pressed_no_signal(main.is_debug_enabled())
	_petals_check.set_pressed_no_signal(main.are_petals_enabled())
	_play_button.text = "暂停" if main.is_playing() else "播放"
	for s in _speed_buttons:
		var btn: Button = _speed_buttons[s]
		btn.set_pressed_no_signal(is_equal_approx(float(main.get_speed()), float(s)))
	_syncing = false
	_refresh_live()


func _process(delta: float) -> void:
	_accum += delta
	_fps_accum += delta
	if _accum >= 0.08:
		_accum = 0.0
		_refresh_live()
	if _fps_accum >= 0.4:
		_fps_accum = 0.0
		_refresh_fps()


func _refresh_live() -> void:
	if main == null:
		return
	var hour: float = main.get_hour()
	var ticks: int = SunModel.hour_to_ticks(hour)
	_time_label.text = format_hour(hour)
	_tick_label.text = "刻数 %d / %d" % [ticks, SunModel.TICKS_PER_DAY]
	_phase_label.text = main.get_phase()
	_phase_label.add_theme_color_override("font_color",
			PINK if hour < 10.0 or hour >= 16.0 else GREEN)
	if not _slider_dragging and not _syncing:
		_time_slider.set_value_no_signal(hour)

	var rep: Dictionary = main.get_hero_shadow_report()
	var h_ratio := 0.0
	var h_px := 0.0
	var capped := false
	if not rep.is_empty():
		h_ratio = float(rep["total_length"]) / maxf(float(rep["visual_height"]), 1.0)
		h_px = float(rep["total_length"])
		capped = bool(rep["capped"])
	var cap_txt := " · 封顶" if capped else ""
	_stats["elev"].text = "%.1f°" % main.get_elevation()
	_stats["azim"].text = "%.1f°" % main.get_azimuth()
	_stats["shadow"].text = "%.2f H · %.0f px%s" % [h_ratio, h_px, cap_txt]
	var sun_dir: Vector2 = main.get_sun_dir()
	var shadow_dir: Vector2 = main.get_shadow_dir()
	_stats["sunvec"].text = "(%.2f, %.2f)" % [sun_dir.x, sun_dir.y]
	_stats["shvec"].text = "(%.2f, %.2f)" % [shadow_dir.x, shadow_dir.y]
	_stats["phase"].text = main.get_phase()

	if _play_button.text != ("暂停" if main.is_playing() else "播放"):
		_play_button.text = "暂停" if main.is_playing() else "播放"


func _refresh_fps() -> void:
	if main == null:
		return
	_fps_label.text = "FPS %d   DRAW %d" % [main.get_fps(), main.get_draw_calls()]


# ── 构建 ─────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "STHeiti",
		"Noto Sans CJK SC", "Sans-Serif"])
	_font.allow_system_fallback = true

	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 12
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", WARM)
	theme.set_color("font_pressed_color", "Button", PINK)
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_pressed_color", "CheckBox", WARM)
	_build_slider_theme(theme)

	_root = Control.new()
	_root.name = "HUDRoot"
	_root.position = Vector2.ZERO
	_root.size = DESIGN
	_root.custom_minimum_size = DESIGN
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = theme
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.name = "ControlPanel"
	_panel.position = Vector2(18.0, 16.0)
	_panel.custom_minimum_size = Vector2(PANEL_W, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style(BG, BORDER, 2, 7))
	_root.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	col.add_child(title_row)
	var title := _label("樱庭日照", 26, WARM)
	title_row.add_child(title)
	var title_tag := _label("SAKURA\nSUNLIGHT", 8, DIM)
	title_tag.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(title_tag)

	var subtitle := _label("纯三角函数 · 2D 像素日照 · 固定机位", 11, TEXT)
	col.add_child(subtitle)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(0.0, 2.0)
	accent.color = Color(1.0, 0.64, 0.75, 0.55)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(accent)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 10)
	col.add_child(time_row)
	_time_label = _label("08:00", 32, WARM)
	_time_label.custom_minimum_size = Vector2(104.0, 0.0)
	time_row.add_child(_time_label)
	var time_meta := VBoxContainer.new()
	time_meta.add_theme_constant_override("separation", 0)
	time_meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_row.add_child(time_meta)
	_tick_label = _label("刻数 2000 / 6000", 10, DIM)
	time_meta.add_child(_tick_label)
	_phase_label = _label("晨光", 13, PINK)
	time_meta.add_child(_phase_label)

	_time_slider = HSlider.new()
	_time_slider.name = "TimeSlider"
	_time_slider.min_value = SunModel.DAY_START_HOUR
	_time_slider.max_value = SunModel.DAY_END_HOUR
	_time_slider.step = 0.01
	_time_slider.value = SunModel.DAY_START_HOUR
	_time_slider.custom_minimum_size = Vector2(0.0, 22.0)
	_time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_slider.focus_mode = Control.FOCUS_NONE
	_time_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_time_slider.value_changed.connect(_on_time_slider_changed)
	_time_slider.drag_started.connect(_on_slider_drag_started)
	_time_slider.drag_ended.connect(_on_slider_drag_ended)
	col.add_child(_time_slider)

	var range_row := HBoxContainer.new()
	col.add_child(range_row)
	var r0 := _label("08:00", 9, DIM)
	r0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r0.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	range_row.add_child(r0)
	var r1 := _label("12:30", 9, DIM)
	r1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	range_row.add_child(r1)
	var r2 := _label("17:00", 9, DIM)
	r2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	range_row.add_child(r2)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	col.add_child(buttons)
	_play_button = _button("暂停", 50.0)
	_play_button.pressed.connect(_on_play_pressed)
	buttons.add_child(_play_button)
	var reset_btn := _button("重置", 50.0)
	reset_btn.pressed.connect(_on_reset_pressed)
	buttons.add_child(reset_btn)
	var speed_label := _label("速度", 9, DIM)
	buttons.add_child(speed_label)
	var speed_group := ButtonGroup.new()
	for s in [0.5, 1.0, 2.0, 4.0]:
		var speed_text := ("%.1f×" % s) if s < 1.0 else ("%d×" % int(s))
		var b := _button(speed_text, 38.0)
		b.toggle_mode = true
		b.button_group = speed_group
		b.pressed.connect(_on_speed_pressed.bind(s))
		buttons.add_child(b)
		_speed_buttons[s] = b

	var sep1 := ColorRect.new()
	sep1.custom_minimum_size = Vector2(0.0, 1.0)
	sep1.color = Color(0.48, 0.66, 0.46, 0.35)
	sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sep1)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 10)
	stats.add_theme_constant_override("v_separation", 1)
	col.add_child(stats)
	_add_stat(stats, "elev", "高度角", "35.0°")
	_add_stat(stats, "azim", "方位角", "50.0°")
	_add_stat(stats, "shadow", "影长", "1.43 H · 190 px")
	_add_stat(stats, "sunvec", "光照向量", "(0.64, -0.77)")
	_add_stat(stats, "shvec", "影向", "(-0.64, 0.77)")
	_add_stat(stats, "phase", "时段", "晨光")

	var sep2 := ColorRect.new()
	sep2.custom_minimum_size = Vector2(0.0, 1.0)
	sep2.color = Color(0.48, 0.66, 0.46, 0.35)
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sep2)

	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 2)
	col.add_child(toggles)
	_shadows_check = _check("阴影 S", true)
	_shadows_check.toggled.connect(_on_shadows_toggled)
	toggles.add_child(_shadows_check)
	_debug_check = _check("调试 F3", false)
	_debug_check.toggled.connect(_on_debug_toggled)
	toggles.add_child(_debug_check)
	_petals_check = _check("花瓣 P", true)
	_petals_check.toggled.connect(_on_petals_toggled)
	toggles.add_child(_petals_check)

	var hint := _label("空格 暂停 · R 重置 · 1/2/3 跳 08:00/12:00/16:00 · H 收起", 9, DIM)
	col.add_child(hint)
	_fps_label = _label("FPS --   DRAW --", 10, GREEN)
	col.add_child(_fps_label)

	# 右下角太阳罗盘。
	var dial_panel := PanelContainer.new()
	dial_panel.name = "SunDialPanel"
	dial_panel.position = Vector2(DESIGN.x - 18.0 - 258.0, DESIGN.y - 16.0 - 176.0)
	dial_panel.custom_minimum_size = Vector2(258.0, 176.0)
	dial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dial_panel.add_theme_stylebox_override("panel", _panel_style(BG, BORDER, 1, 7))
	_root.add_child(dial_panel)
	dial = SunDial.new()
	dial.name = "SunDial"
	dial.custom_minimum_size = Vector2(236.0, 156.0)
	dial_panel.add_child(dial)
	dial.font = _font

	var footer := _label("FIXED CAMERA · 640×360 WORLD · 2× / 3× INTEGER SCALE", 9,
			Color(0.72, 0.82, 0.68, 0.55))
	footer.position = Vector2(20.0, DESIGN.y - 27.0)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(footer)


func _add_stat(grid: GridContainer, key: String, name_text: String, value_text: String) -> void:
	var name := _label(name_text, 11, DIM)
	name.custom_minimum_size = Vector2(72.0, 0.0)
	grid.add_child(name)
	var value := _label(value_text, 11, TEXT)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(value)
	_stats[key] = value


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.focus_mode = Control.FOCUS_NONE
	return l


func _button(text: String, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 26.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_stylebox_override("normal", _button_style(Color(0.075, 0.14, 0.105, 0.95),
			Color(0.32, 0.50, 0.32, 0.9)))
	b.add_theme_stylebox_override("hover", _button_style(Color(0.11, 0.20, 0.14, 0.98),
			Color(0.55, 0.78, 0.50, 0.95)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.28, 0.16, 0.19, 0.98),
			Color(1.0, 0.64, 0.75, 0.95)))
	return b


func _check(text: String, pressed: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = pressed
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 10)
	return c


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 5.0
	s.content_margin_right = 5.0
	s.content_margin_top = 3.0
	s.content_margin_bottom = 3.0
	return s


func _panel_style(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 12.0
	s.content_margin_bottom = 12.0
	return s


func _build_slider_theme(theme: Theme) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.035, 0.07, 0.055, 0.95)
	track.set_corner_radius_all(2)
	track.content_margin_top = 2.0
	track.content_margin_bottom = 2.0
	theme.set_stylebox("slider", "HSlider", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.63, 0.73, 0.92)
	fill.set_corner_radius_all(2)
	fill.content_margin_top = 2.0
	fill.content_margin_bottom = 2.0
	theme.set_stylebox("grabber_area", "HSlider", fill)
	var fill_hi: StyleBoxFlat = fill.duplicate()
	fill_hi.bg_color = Color(1.0, 0.76, 0.82, 0.98)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)

	theme.set_icon("grabber", "HSlider", _make_grabber())
	theme.set_icon("grabber_highlight", "HSlider", _make_grabber())


func _make_grabber() -> ImageTexture:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 14:
		for x in 14:
			var d := Vector2(float(x) - 6.5, float(y) - 6.5).length()
			if d <= 6.2:
				var c := Color(1.0, 0.68, 0.78, 1.0)
				if d > 4.6:
					c = Color(0.22, 0.12, 0.16, 1.0)
				elif d > 3.4:
					c = Color(1.0, 0.90, 0.92, 1.0)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# ── 回调 ─────────────────────────────────────────────────────────────────
func _on_time_slider_changed(value: float) -> void:
	if _syncing or main == null:
		return
	main.set_hour(value)
	_refresh_live()


func _on_slider_drag_started() -> void:
	if main == null:
		return
	_slider_dragging = true
	main.set_playing(false)
	_play_button.text = "播放"


func _on_slider_drag_ended(_value_changed: bool) -> void:
	_slider_dragging = false
	if main != null:
		main.set_hour(_time_slider.value)
	_refresh_live()


func _on_play_pressed() -> void:
	if main == null or _syncing:
		return
	main.set_playing(not main.is_playing())
	sync_from_main()


func _on_reset_pressed() -> void:
	if main == null:
		return
	main.reset()
	sync_from_main()


func _on_speed_pressed(value: float) -> void:
	if main == null or _syncing:
		return
	main.set_speed(value)
	sync_from_main()


func _on_shadows_toggled(value: bool) -> void:
	if _syncing or main == null:
		return
	main.set_shadows_enabled(value)
	_refresh_live()


func _on_debug_toggled(value: bool) -> void:
	if _syncing or main == null:
		return
	main.set_debug_enabled(value)


func _on_petals_toggled(value: bool) -> void:
	if _syncing or main == null:
		return
	main.set_petals_enabled(value)


# ── 测试 / 外部查询 ──────────────────────────────────────────────────────
func get_time_slider() -> HSlider:
	return _time_slider


func get_time_label() -> Label:
	return _time_label


func get_tick_label() -> Label:
	return _tick_label


func get_play_button() -> Button:
	return _play_button


func get_shadows_check() -> CheckBox:
	return _shadows_check


func get_debug_check() -> CheckBox:
	return _debug_check


func get_petals_check() -> CheckBox:
	return _petals_check


func get_stat_label(key: String) -> Label:
	return _stats.get(key, null)


func get_speed_button(value: float) -> Button:
	return _speed_buttons.get(value, null)


func get_sun_dial() -> SunDial:
	return dial


static func format_hour(hour: float) -> String:
	var h := int(floor(hour))
	var m := int(floor((hour - float(h)) * 60.0 + 0.0001))
	if m >= 60:
		m = 59
	return "%02d:%02d" % [h, m]
