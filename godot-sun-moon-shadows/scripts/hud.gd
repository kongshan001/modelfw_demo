class_name SunMoonHUD
extends CanvasLayer

# 640×360 像素中文 HUD：顶部两块「天空条」只遮住天空，底部控制条遮住前景草，
# 中间的画面（房屋 / 树 / 角色 / 影子）保持完整可见。
# 字体 Fusion Pixel 12px（OFL），关闭抗锯齿，由 main 按整数倍放大。

const DESIGN := Vector2(640.0, 360.0)
const TEXT := Color(0.90, 0.93, 0.84)
const DIM := Color(0.58, 0.70, 0.65)
const WARM := Color(1.00, 0.86, 0.55)
const COOL := Color(0.64, 0.80, 1.00)
const GREEN := Color(0.60, 0.94, 0.73)
const RED := Color(0.96, 0.55, 0.42)
const BG := Color(0.035, 0.060, 0.080, 0.92)
const BG2 := Color(0.045, 0.075, 0.085, 0.94)
const BORDER := Color(0.32, 0.52, 0.52, 0.90)
const BORDER_WARM := Color(0.76, 0.62, 0.34, 0.95)

var main: Node
var font: FontFile
var font_small: FontFile
var _root: Control
var _panel_left: PanelContainer
var _panel_right: PanelContainer
var _bottom: PanelContainer
var _panel_debug: PanelContainer
var _time_label: Label
var _phase_label: Label
var _time_slider: HSlider
var _play_button: Button
var _shadows_button: Button
var _knee_button: Button
var _lamps_button: Button
var _debug_button: Button
var _debug_buttons: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _labels: Dictionary = {}
var _swatches: Dictionary = {}
var _hint: Label
var _curve: KneeCurvePlot
var _ui_visible := true
var _debug_visible := false
var _syncing := false
var _slider_dragging := false
var _was_playing := true
var _accum := 0.0
var _fps_accum := 0.0


func _ready() -> void:
	font = load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf.woff2")
	font_small = load("res://assets/fonts/fusion-pixel-10px-proportional-zh_hans.ttf.woff2")
	for f in [font, font_small]:
		if f != null:
			f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			f.hinting = TextServer.HINTING_NONE
			f.allow_system_fallback = true
	_build_ui()
	set_process(true)


func setup(main_node: Node) -> void:
	main = main_node
	if _curve != null:
		_curve.main = main
		_curve.font = font_small
	sync_from_main()


func set_ui_visible(value: bool) -> void:
	_ui_visible = value
	if _root != null:
		_root.visible = value
	if value:
		_sync_debug_panel()


func set_debug_visible(value: bool) -> void:
	_debug_visible = value
	_sync_debug_panel()


func set_fps_visible(value: bool) -> void:
	if _labels.has("stats"):
		_labels["stats"].visible = value


func is_ui_visible() -> bool:
	return _ui_visible


func is_debug_visible() -> bool:
	return _debug_visible


func get_time_slider() -> HSlider:
	return _time_slider


func get_time_label() -> Label:
	return _time_label


func get_curve_plot() -> KneeCurvePlot:
	return _curve


func get_root_control() -> Control:
	return _root


func get_debug_button(flag: String) -> Button:
	return _debug_buttons.get(flag, null)


func format_hour(hour: float) -> String:
	return LightModel.format_hour(hour)


func sync_from_main() -> void:
	if main == null:
		return
	_syncing = true
	_time_slider.set_value_no_signal(main.get_hour())
	_play_button.text = "暂停" if main.is_playing() else "播放"
	_shadows_button.set_pressed_no_signal(main.are_shadows_enabled())
	_knee_button.set_pressed_no_signal(main.is_soft_knee())
	_lamps_button.set_pressed_no_signal(main.are_lamps_enabled())
	_debug_button.set_pressed_no_signal(main.is_debug_enabled())
	for s in _speed_buttons:
		var b: Button = _speed_buttons[s]
		b.set_pressed_no_signal(is_equal_approx(float(main.get_speed()), float(s)))
	var world = main.get_world()
	if world != null:
		for flag in _debug_buttons:
			var b: Button = _debug_buttons[flag]
			b.set_pressed_no_signal(world.is_debug_flag(flag))
	_syncing = false
	_refresh_live()
	_refresh_fps()
	_sync_debug_panel()


func _sync_debug_panel() -> void:
	if _panel_debug != null:
		_panel_debug.visible = _ui_visible and _debug_visible


func _process(delta: float) -> void:
	_accum += delta
	_fps_accum += delta
	if _accum >= 0.08:
		_accum = 0.0
		_refresh_live()
	if _fps_accum >= 0.5:
		_fps_accum = 0.0
		_refresh_fps()


func _refresh_live() -> void:
	if main == null:
		return
	var hour: float = main.get_hour()
	_time_label.text = format_hour(hour)
	_phase_label.text = main.get_phase()
	if not _slider_dragging and not _syncing:
		_time_slider.set_value_no_signal(hour)

	var solar: Dictionary = main.get_solar()
	var main_light := String(solar.get("main_light", "sun"))
	var main_is_sun := main_light == "sun"
	_labels["main"].text = "主光 %s ×%.2f" % [
		"太阳" if main_is_sun else "月亮", float(solar.get("intensity", 0.0))]
	_labels["main"].add_theme_color_override("font_color", WARM if main_is_sun else COOL)
	_swatches["main"].color = WARM if main_is_sun else COOL
	_labels["sun"].text = "日 %5.1f° / %3.0f°" % [
		float(solar.get("sun_elevation", 0.0)),
		float(solar.get("sun_azimuth", 0.0))]
	_labels["moon"].text = "月 %5.1f° / %3.0f°" % [
		float(solar.get("moon_elevation", 0.0)),
		float(solar.get("moon_azimuth", 0.0))]

	var world = main.get_world()
	var stats: Dictionary = world.get_shadow_stats() if world != null else {}
	var elev := float(solar.get("elevation", 0.0))
	var len_h := LightModel.shadow_length(1.0, maxf(elev, 0.35), main.is_soft_knee())
	var knee := "软膝" if main.is_soft_knee() else "硬截"
	_labels["stats"].text = "影 %.2fH %s 顶%d 块%d FPS%d DRAW%d" % [
		len_h, knee, int(stats.get("vertices", 0)),
		int(stats.get("union_polygons", 0)), main.get_fps(), main.get_draw_calls()]

	var g_dir: Vector4 = main.get_global_uniform("u_light_dir")
	var g_col: Color = main.get_global_uniform("u_light_color")
	var g_amb: Color = main.get_global_uniform("u_ambient_sub")
	_labels["vec_dir"].text = "方向 (%.2f,%.2f) 高%.2f 夜%.2f" % [
		g_dir.x, g_dir.y, g_dir.z, g_dir.w]
	_labels["vec_col"].text = "光色 #%s ×%.2f" % [g_col.to_html(false), g_col.a]
	_labels["vec_amb"].text = "扣除 #%s ×%.2f" % [g_amb.to_html(false), g_amb.a]
	_swatches["col"].color = g_col
	_swatches["amb"].color = g_amb

	if _debug_visible and world != null:
		var occl: Dictionary = world.get_occlusion_debug()
		_labels["occl"].text = "桶影%d vs 屋顶%d→%s\n树影%d vs 地面%d→%s" % [
			int(occl["barrel_caster"]), int(occl["roof_height"]),
			"截断" if not bool(occl["barrel_vs_roof"]) else "落影",
			int(occl["tree_caster"]), int(occl["ground_height"]),
			"落影" if bool(occl["tree_vs_ground"]) else "截断"]
		var hi: Dictionary = world.get_height_info()
		_labels["height"].text = "高度图 %s 640×360 · %dpx" % [
			hi["format"], int(hi["normalization_px"])]
		if world.is_debug_flag("overlap"):
			var probe: Dictionary = world.get_overlap_probe()
			if bool(probe.get("found", false)):
				_labels["overlap"].text = "重影%s 覆盖%d层 · 单影%s 覆盖%d层" % [
					_fmt_point(probe["overlap_point"]), int(probe["overlap_coverage"]),
					_fmt_point(probe["single_point"]), int(probe["single_coverage"])]
			else:
				_labels["overlap"].text = "重叠采样：当前两树影未相交"
		else:
			_labels["overlap"].text = "重叠采样：按 V 开启（08:00 两树影）"
	if _curve != null and _debug_visible:
		_curve.queue_redraw()


func _refresh_fps() -> void:
	if main == null:
		return
	var world = main.get_world()
	var stats: Dictionary = world.get_shadow_stats() if world != null else {}
	var solar: Dictionary = main.get_solar()
	var elev := float(solar.get("elevation", 0.0))
	var len_h := LightModel.shadow_length(1.0, maxf(elev, 0.35), main.is_soft_knee())
	_labels["stats"].text = "影 %.2fH %s 顶%d 块%d FPS%d DRAW%d" % [
		len_h, "软膝" if main.is_soft_knee() else "硬截",
		int(stats.get("vertices", 0)), int(stats.get("union_polygons", 0)),
		main.get_fps(), main.get_draw_calls()]


static func _fmt_point(p: Vector2) -> String:
	return "(%d,%d)" % [int(p.x), int(p.y)]


# ── 构建 ─────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 10
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", WARM)
	theme.set_color("font_pressed_color", "Button", WARM)
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_pressed_color", "CheckBox", WARM)
	_build_slider_theme(theme)
	_build_button_theme(theme)

	_root = Control.new()
	_root.name = "HUDRoot"
	_root.position = Vector2.ZERO
	_root.size = DESIGN
	_root.custom_minimum_size = DESIGN
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.theme = theme
	add_child(_root)

	_build_left_panel()
	_build_right_panel()
	_build_debug_panel()
	_build_bottom_bar()



func _build_left_panel() -> void:
	_panel_left = _panel(Vector2(8, 8), 200.0, BG)
	_root.add_child(_panel_left)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_panel_left.add_child(col)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	col.add_child(title_row)
	title_row.add_child(_label("日月双影", 12, WARM))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(sp)
	title_row.add_child(_label("南天同弧", 10, DIM))

	var clock_row := HBoxContainer.new()
	clock_row.add_theme_constant_override("separation", 6)
	col.add_child(clock_row)
	_time_label = _label("08:00", 24, WARM)
	_time_label.custom_minimum_size = Vector2(68, 0)
	clock_row.add_child(_time_label)
	var meta := VBoxContainer.new()
	meta.add_theme_constant_override("separation", 0)
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock_row.add_child(meta)
	_phase_label = _label("晨光", 10, GREEN)
	meta.add_child(_phase_label)
	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 2)
	meta.add_child(main_row)
	_swatches["main"] = _swatch(6, WARM)
	main_row.add_child(_swatches["main"])
	_labels["main"] = _label("主光 太阳 ×1.00", 10, WARM)
	main_row.add_child(_labels["main"])

	var sun_row := HBoxContainer.new()
	sun_row.add_theme_constant_override("separation", 6)
	col.add_child(sun_row)
	_labels["sun"] = _label("日 68.0° / 090°", 10, WARM)
	_labels["sun"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sun_row.add_child(_labels["sun"])
	_labels["moon"] = _label("月 -52° / 262°", 10, COOL)
	_labels["moon"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sun_row.add_child(_labels["moon"])


func _build_right_panel() -> void:
	_panel_right = _panel(Vector2(406, 8), 226.0, BG2)
	_root.add_child(_panel_right)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_panel_right.add_child(col)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	col.add_child(title_row)
	title_row.add_child(_label("主光通道", 12, WARM))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(sp)
	title_row.add_child(_label("3 × vec4", 10, DIM))

	for key in ["vec_dir", "vec_col", "vec_amb"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		col.add_child(row)
		if key == "vec_col":
			_swatches["col"] = _swatch(8, Color.WHITE)
			row.add_child(_swatches["col"])
		elif key == "vec_amb":
			_swatches["amb"] = _swatch(8, Color.WHITE)
			row.add_child(_swatches["amb"])
		else:
			var tag := _label("D", 10, COOL)
			tag.custom_minimum_size = Vector2(7, 0)
			row.add_child(tag)
		var l := _label("", 10, TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		_labels[key] = l

	col.add_child(_accent_line(Color(0.32, 0.52, 0.52, 0.45)))
	_labels["stats"] = _label("影 0.40H · 顶0 块0 · FPS60 DRAW0", 10, DIM)
	col.add_child(_labels["stats"])


func _build_bottom_bar() -> void:
	_bottom = _panel(Vector2(0, 314), 640.0, BG)
	_bottom.custom_minimum_size = Vector2(640, 46)
	_root.add_child(_bottom)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_bottom.add_child(col)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	col.add_child(row1)
	row1.add_child(_label("时间", 10, DIM))
	row1.add_child(_label("0", 10, DIM))
	_time_slider = HSlider.new()
	_time_slider.name = "TimeSlider"
	_time_slider.min_value = 0.0
	_time_slider.max_value = 24.0
	_time_slider.step = 0.01
	_time_slider.custom_minimum_size = Vector2(200, 14)
	_time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_slider.focus_mode = Control.FOCUS_NONE
	_time_slider.value_changed.connect(_on_time_changed)
	_time_slider.drag_started.connect(_on_slider_drag_started)
	_time_slider.drag_ended.connect(_on_slider_drag_ended)
	row1.add_child(_time_slider)
	row1.add_child(_label("24", 10, DIM))
	_play_button = _button("暂停", 38)
	_play_button.pressed.connect(_on_play)
	row1.add_child(_play_button)
	var reset := _button("重置", 32)
	reset.pressed.connect(_on_reset)
	row1.add_child(reset)
	var group := ButtonGroup.new()
	for s in [1.0, 4.0, 16.0, 64.0]:
		var b := _button("%d×" % int(s), 25)
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_on_speed.bind(s))
		row1.add_child(b)
		_speed_buttons[s] = b

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	col.add_child(row2)
	_shadows_button = _toggle("影子", 46)
	_shadows_button.pressed.connect(_on_shadows)
	row2.add_child(_shadows_button)
	_knee_button = _toggle("软膝", 46)
	_knee_button.pressed.connect(_on_knee)
	row2.add_child(_knee_button)
	_lamps_button = _toggle("路灯", 46)
	_lamps_button.pressed.connect(_on_lamps)
	row2.add_child(_lamps_button)
	_debug_button = _toggle("调试", 46)
	_debug_button.pressed.connect(_on_debug_toggle)
	row2.add_child(_debug_button)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(sp)
	row2.add_child(_label("空格 暂停 · 1 正午 · 2 黄昏 · 3 月夜 · H 隐藏 UI", 10, DIM))


func _build_debug_panel() -> void:
	_panel_debug = _panel(Vector2(298, 96), 334.0, BG)
	_panel_debug.visible = false
	_root.add_child(_panel_debug)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_panel_debug.add_child(col)
	var title_row := HBoxContainer.new()
	col.add_child(title_row)
	title_row.add_child(_label("调试 · F3", 12, WARM))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(sp)
	title_row.add_child(_label("F3 曲线 / G 高度图 / O 遮挡 / B 网格 / V 重叠", 10, DIM))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	col.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.custom_minimum_size = Vector2(148, 0)
	body.add_child(left)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 2)
	left.add_child(grid)
	for item in [["heightmap", "高度图"], ["occlusion", "遮挡"], ["mesh", "网格"], ["overlap", "重叠"]]:
		var b := _toggle(item[1], 68)
		b.pressed.connect(_on_debug_flag.bind(item[0]))
		grid.add_child(b)
		_debug_buttons[item[0]] = b
	_labels["height"] = _label("高度图 R8 640×360", 10, DIM)
	_labels["height"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_labels["height"])
	_labels["occl"] = _label("遮挡测试…", 10, DIM)
	_labels["occl"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_labels["occl"])
	_labels["overlap"] = _label("重叠采样…", 10, DIM)
	_labels["overlap"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_labels["overlap"])

	_curve = KneeCurvePlot.new()
	_curve.name = "KneeCurve"
	_curve.main = main
	_curve.font = font_small
	_curve.custom_minimum_size = Vector2(162, 102)
	body.add_child(_curve)


func _panel(pos: Vector2, width: float, bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = Vector2(width, 0)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_font_override("font", font_small if font_size <= 10 else font)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _accent_line(color: Color) -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _swatch(w: int, color: Color) -> ColorRect:
	var s := ColorRect.new()
	s.custom_minimum_size = Vector2(w, w)
	s.color = color
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _button(text: String, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 18)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_font_override("font", font_small)
	return b


func _toggle(text: String, width: float) -> Button:
	var b := _button(text, width)
	b.toggle_mode = true
	return b


func _build_button_theme(theme: Theme) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.085, 0.100, 0.94)
	normal.border_color = Color(0.27, 0.44, 0.44, 0.9)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(0)
	normal.content_margin_top = 1
	normal.content_margin_bottom = 1
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = BORDER_WARM
	hover.bg_color = Color(0.10, 0.14, 0.13, 0.96)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_color = WARM
	pressed.bg_color = Color(0.28, 0.23, 0.12, 0.96)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_stylebox("disabled", "Button", normal)
	theme.set_stylebox("normal", "CheckBox", normal)
	theme.set_stylebox("pressed", "CheckBox", pressed)
	theme.set_stylebox("hover", "CheckBox", hover)


func _build_slider_theme(theme: Theme) -> void:
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.12, 0.18, 0.18, 0.95)
	slider_bg.set_border_width_all(1)
	slider_bg.border_color = Color(0.24, 0.40, 0.40, 0.95)
	slider_bg.content_margin_top = 3
	slider_bg.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.72, 0.56, 0.28, 0.95)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := Image.create(6, 12, false, Image.FORMAT_RGBA8)
	grab.fill(Color(0, 0, 0, 0))
	for y in 12:
		for x in 6:
			if y == 0 or y == 11:
				continue
			grab.set_pixel(x, y, Color(1.0, 0.86, 0.55, 1.0) if x > 0 and x < 5
					else Color(0.45, 0.32, 0.16, 1.0))
	var tex := ImageTexture.create_from_image(grab)
	theme.set_icon("grabber", "HSlider", tex)
	theme.set_icon("grabber_highlight", "HSlider", tex)


# ── 交互 ─────────────────────────────────────────────────────────────────
func _on_time_changed(value: float) -> void:
	if _syncing or main == null:
		return
	main.set_hour(value)


func _on_slider_drag_started() -> void:
	_slider_dragging = true
	if main != null:
		_was_playing = main.is_playing()
		main.set_playing(false)


func _on_slider_drag_ended(value_changed: bool) -> void:
	_slider_dragging = false
	if main != null and _was_playing:
		main.set_playing(true)
	sync_from_main()


func _on_play() -> void:
	main.set_playing(not main.is_playing())
	sync_from_main()


func _on_reset() -> void:
	main.reset()
	sync_from_main()


func _on_speed(speed: float) -> void:
	main.set_speed(speed)
	sync_from_main()


func _on_shadows() -> void:
	if _syncing:
		return
	main.set_shadows_enabled(_shadows_button.button_pressed)
	sync_from_main()


func _on_knee() -> void:
	if _syncing:
		return
	main.set_soft_knee(_knee_button.button_pressed)
	sync_from_main()


func _on_lamps() -> void:
	if _syncing:
		return
	main.set_lamps_enabled(_lamps_button.button_pressed)
	sync_from_main()


func _on_debug_toggle() -> void:
	if _syncing:
		return
	if _debug_button.button_pressed:
		main.set_debug_enabled(true)
	else:
		main.set_debug_enabled(false)
	sync_from_main()


func _on_debug_flag(flag: String) -> void:
	if _syncing:
		return
	var b: Button = _debug_buttons[flag]
	main.set_debug_flag(flag, b.button_pressed)
	sync_from_main()
