extends CanvasLayer

# 中文参数面板：变体、调试视图、单格/3×3、四个构成开关、五个连续参数。
# UI 按 1280×720 设计；1920×1080 截图时整体 ×1.5，文字与点击区域一起放大。

const UI_W := 1280.0
const UI_H := 720.0
const PANEL_W := 302.0
const FONT_UI := ["PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
		"Microsoft YaHei", "Sans-Serif"]
const FONT_DISPLAY := ["Songti SC", "STSong", "Noto Serif CJK SC", "Serif"]
const FONT_MONO := ["Menlo", "SF Mono", "Monaco", "Consolas", "Monospace"]

const C_TEXT := Color(0.85, 0.96, 0.93)
const C_MUTED := Color(0.55, 0.72, 0.70)
const C_ACCENT := Color(0.46, 1.0, 0.88)
const C_WARM := Color(1.0, 0.80, 0.52)
const C_PANEL := Color(0.012, 0.040, 0.045, 0.92)
const C_LINE := Color(0.28, 0.72, 0.67, 0.34)

var main

var _ui: Control
var _panel: PanelContainer
var _title: Label
var _mode_label: Label
var _warn_label: Label
var _stats_label: Label
var _hint_label: Label
var _footer_hint: Label
var _caption_root: PanelContainer
var _caption_label: Label
var _toast_label: Label
var _toast_root: PanelContainer
var _debug_grid: GridContainer
var _search_box: HBoxContainer
var _variant_box: HBoxContainer
var _toggle_grid: GridContainer
var _color_button: ColorPickerButton

var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _slider_rows: Dictionary = {}
var _toggle_buttons: Dictionary = {}
var _debug_buttons: Array[Button] = []
var _variant_buttons: Array[Button] = []
var _search_buttons: Array[Button] = []
var _syncing := false
var _caption_time := 0.0
var _toast_time := 0.0
var _stats_time := 0.0
var _panel_open := true
var _minimal := false
var _ui_visible := true

var _font_ui: SystemFont
var _font_display: SystemFont
var _font_mono: SystemFont

const DEBUG_NAMES := ["最终成片", "F1 最近距离", "F2 次近距离", "F2−F1 距离差",
		"亮纹 mask", "格网 + 特征点", "坐标扭曲场"]
const DEBUG_SHORT := ["成片", "F1", "F2", "F2−F1", "亮纹", "格网", "扭曲"]


func _ready() -> void:
	layer = 10
	_build_fonts()
	_build_ui()
	set_process(true)


func setup(main_node: Node) -> void:
	main = main_node
	sync_from_main()


func sync_from_main() -> void:
	if main == null or _ui == null:
		return
	_syncing = true
	var st: Dictionary = main.get_state()
	var p: Dictionary = st["params"]
	for key in _sliders:
		var slider: HSlider = _sliders[key]
		slider.set_value_no_signal(float(p.get(key, slider.value)))
		_update_value_label(key, float(p.get(key, slider.value)))
	_set_button_active(_variant_buttons, int(st["variant"]))
	_set_button_active(_search_buttons, 1 if bool(st["search_3x3"]) else 0)
	_set_button_active(_debug_buttons, int(st["debug"]))
	_set_toggle_state("warp", bool(st["warp"]))
	_set_toggle_state("junction", bool(st["junction"]))
	_set_toggle_state("gather", bool(st["gather"]))
	_set_toggle_state("soft", bool(st["soft"]))
	_set_toggle_state("surface", bool(st["surface"]))
	_set_toggle_state("auto", bool(st["camera_auto"]))
	_set_toggle_state("paused", bool(st["paused"]))

	var search_txt := "3×3 邻域" if bool(st["search_3x3"]) else "单格测距"
	var mode_name := String(DEBUG_NAMES[int(st["debug"])])
	if int(st["debug"]) == 0:
		if bool(st["search_3x3"]):
			_mode_label.text = "实时 · %s · F2−F1 光纹" % search_txt
		else:
			_mode_label.text = "对照 · 单格 · F1 等距环 / 格缝断裂"
	else:
		_mode_label.text = "分析 · %s · %s" % [search_txt, mode_name]
	var warn := ""
	if not bool(st["search_3x3"]):
		warn = "单格：每个像素只看本格，距离场在格缝处断裂"
		if int(st["debug"]) == 2 or int(st["debug"]) == 3:
			warn += " · 无有效 F2"
	_warn_label.text = warn
	_warn_label.visible = warn != ""
	var line_color: Color = main.world.get_shared_param("u_line_color")
	if _color_button != null and not _color_button.get_popup().visible:
		_color_button.color = line_color
	_warn_label.modulate = Color(1.0, 0.84, 0.58, 1.0)
	_syncing = false


func set_ui_visible(value: bool) -> void:
	_ui_visible = value
	if _ui != null:
		_ui.visible = value


func set_ui_scale(scale: float) -> void:
	if _ui != null:
		_ui.scale = Vector2(scale, scale)


func set_minimal(value: bool) -> void:
	_minimal = value
	if _panel != null:
		_panel.visible = (not value) and _panel_open
	if _hint_label != null:
		_hint_label.visible = not value
	if _footer_hint != null:
		_footer_hint.visible = not value


func set_stats_visible(value: bool) -> void:
	if _stats_label != null:
		_stats_label.visible = value


func toggle_panel() -> void:
	_panel_open = not _panel_open
	if _panel != null:
		_panel.visible = _panel_open and not _minimal


func show_caption(text: String, seconds: float = 0.0) -> void:
	_caption_label.text = text
	_caption_root.visible = text != ""
	_caption_time = seconds


func show_toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_root.visible = true
	_toast_time = 2.4


func tick(delta: float) -> void:
	if _caption_time > 0.0:
		_caption_time -= delta
		if _caption_time <= 0.0:
			_caption_root.visible = false
	if _toast_time > 0.0:
		_toast_time -= delta
		var a := clampf(_toast_time / 0.4, 0.0, 1.0) if _toast_time < 0.4 else 1.0
		_toast_root.modulate.a = a
		if _toast_time <= 0.0:
			_toast_root.visible = false
	_stats_time += delta
	if _stats_time >= 0.22 and _stats_label != null and _ui.visible:
		_stats_time = 0.0
		var fps := Engine.get_frames_per_second()
		var dc := RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var pause := "  ‖ PAUSED" if main != null and bool(main.get_state()["paused"]) else ""
		_stats_label.text = "FPS %02d   DC %02d%s" % [fps, dc, pause]


# ── UI 构建 ─────────────────────────────────────────────────────────────

func _build_fonts() -> void:
	_font_ui = SystemFont.new()
	_font_ui.font_names = PackedStringArray(FONT_UI)
	_font_ui.allow_system_fallback = true
	_font_display = SystemFont.new()
	_font_display.font_names = PackedStringArray(FONT_DISPLAY)
	_font_display.allow_system_fallback = true
	_font_mono = SystemFont.new()
	_font_mono.font_names = PackedStringArray(FONT_MONO)
	_font_mono.allow_system_fallback = true


func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font = _font_ui
	theme.default_font_size = 13
	theme.set_color("font_color", "Label", C_TEXT)

	_ui = Control.new()
	_ui.name = "UI"
	_ui.size = Vector2(UI_W, UI_H)
	_ui.position = Vector2.ZERO
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = theme
	add_child(_ui)

	_build_edge_gradients()
	_build_title()
	_build_stats()
	_build_panel()
	_build_bottom_hints()
	_build_caption()
	_build_toast()


func _build_edge_gradients() -> void:
	var top := _gradient_rect(Vector2(UI_W, 220.0), Vector2.ZERO, false)
	top.name = "TopShade"
	var bottom := _gradient_rect(Vector2(UI_W, 122.0), Vector2(0.0, UI_H - 122.0), true)
	bottom.name = "BottomShade"


func _gradient_rect(size: Vector2, pos: Vector2, flip: bool) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.34, 1.0])
	if flip:
		g.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.0),
				Color(0.002, 0.012, 0.015, 0.30), Color(0.002, 0.012, 0.015, 0.66)])
	else:
		g.colors = PackedColorArray([Color(0.002, 0.012, 0.015, 0.76),
				Color(0.002, 0.012, 0.015, 0.34), Color(0.0, 0.0, 0.0, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 8
	tex.height = 128
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	var r := TextureRect.new()
	r.texture = tex
	r.position = pos
	r.size = size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(r)
	return r


func _build_title() -> void:
	var block := VBoxContainer.new()
	block.position = Vector2(28.0, 24.0)
	block.add_theme_constant_override("separation", 2)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(block)

	var over := HBoxContainer.new()
	over.add_theme_constant_override("separation", 8)
	block.add_child(over)
	var bar := ColorRect.new()
	bar.color = C_ACCENT
	bar.custom_minimum_size = Vector2(24.0, 2.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	over.add_child(bar)
	var kicker := _label("VORONOI / F1 · F2 / 07", 10, C_ACCENT)
	kicker.add_theme_font_override("font", _font_mono)
	over.add_child(kicker)

	_title = _label("池底光网", 34, Color(0.91, 1.0, 0.96))
	_title.add_theme_font_override("font", _font_display)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 2)
	block.add_child(_title)

	_mode_label = _label("实时 · 3×3 邻域 · F2−F1 光纹", 12, Color(0.70, 0.86, 0.82))
	_mode_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_mode_label.add_theme_constant_override("shadow_offset_x", 1)
	_mode_label.add_theme_constant_override("shadow_offset_y", 1)
	block.add_child(_mode_label)

	_warn_label = _label("", 11, C_WARM)
	_warn_label.add_theme_font_override("font", _font_mono)
	block.add_child(_warn_label)


func _build_stats() -> void:
	_stats_label = _label("FPS --   DC --", 11, Color(0.66, 0.86, 0.82))
	_stats_label.add_theme_font_override("font", _font_mono)
	_stats_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_stats_label.add_theme_constant_override("shadow_offset_x", 1)
	_stats_label.add_theme_constant_override("shadow_offset_y", 1)
	_stats_label.position = Vector2(UI_W - 236.0, 28.0)
	_stats_label.size = Vector2(208.0, 18.0)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(_stats_label)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ControlPanel"
	_panel.position = Vector2(UI_W - PANEL_W - 26.0, 92.0)
	_panel.custom_minimum_size = Vector2(PANEL_W, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.border_color = C_LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 12
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", style)
	_ui.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	_panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	var pt := _label("光网参数", 16, C_TEXT)
	pt.add_theme_font_override("font", _font_display)
	head.add_child(pt)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var tag := _label("LIVE", 9, C_ACCENT)
	tag.add_theme_font_override("font", _font_mono)
	head.add_child(tag)

	col.add_child(_divider())

	# 变体
	var variant_row := HBoxContainer.new()
	variant_row.add_theme_constant_override("separation", 5)
	col.add_child(variant_row)
	_variant_box = variant_row
	_variant_buttons.append(_chip("池底光网", func(): _call_main("set_variant", 0)))
	_variant_buttons.append(_chip("熔岩裂缝", func(): _call_main("set_variant", 1)))
	for b in _variant_buttons:
		b.custom_minimum_size = Vector2(132.0, 26.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		variant_row.add_child(b)

	# 调试视图 3×3 按钮阵列
	var debug_head := HBoxContainer.new()
	col.add_child(debug_head)
	debug_head.add_child(_label("分析视图", 11, C_MUTED))
	var dbg_hint := _label("D 循环", 9, Color(0.40, 0.58, 0.57))
	dbg_hint.add_theme_font_override("font", _font_mono)
	dbg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dbg_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_head.add_child(dbg_hint)

	_debug_grid = GridContainer.new()
	_debug_grid.columns = 4
	_debug_grid.add_theme_constant_override("h_separation", 4)
	_debug_grid.add_theme_constant_override("v_separation", 4)
	col.add_child(_debug_grid)
	for i in DEBUG_SHORT.size():
		var b := _chip(DEBUG_SHORT[i], _on_debug_pressed.bind(i))
		b.add_theme_font_size_override("font_size", 11)
		b.custom_minimum_size = Vector2(62.0, 23.0)
		_debug_grid.add_child(b)
		_debug_buttons.append(b)

	# 邻域搜索对照
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	col.add_child(search_row)
	var slabel := _label("邻域搜索", 11, C_MUTED)
	slabel.custom_minimum_size = Vector2(60.0, 0.0)
	search_row.add_child(slabel)
	_search_buttons.append(_chip("单格", func(): _call_main("set_search_3x3", false)))
	_search_buttons.append(_chip("3×3", func(): _call_main("set_search_3x3", true)))
	_search_buttons[0].tooltip_text = "只测本格：可看到格缝"
	_search_buttons[1].tooltip_text = "记录最近/次近：连续光网"
	for b in _search_buttons:
		b.custom_minimum_size = Vector2(76.0, 24.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		search_row.add_child(b)
	_search_box = search_row

	col.add_child(_divider())

	# 构成开关
	_toggle_grid = GridContainer.new()
	_toggle_grid.columns = 2
	_toggle_grid.add_theme_constant_override("h_separation", 5)
	_toggle_grid.add_theme_constant_override("v_separation", 3)
	col.add_child(_toggle_grid)
	_add_toggle("warp", "坐标扭曲")
	_add_toggle("junction", "交点鼓结")
	_add_toggle("gather", "明暗聚散")
	_add_toggle("soft", "宽柔光")
	_add_toggle("surface", "水面微光")
	_add_toggle("auto", "自动环视")

	col.add_child(_divider())

	# 连续参数
	_add_slider(col, "scale", "密度", 0.35, 2.50, 0.01)
	_add_slider(col, "width", "线宽", 0.008, 0.110, 0.001)
	_add_slider(col, "softness", "软度", 0.10, 1.40, 0.01)
	_add_slider(col, "brightness", "亮度", 0.30, 2.20, 0.01)
	_add_slider(col, "speed", "流速", 0.00, 1.60, 0.01)
	_add_slider(col, "flow", "流向", -180.0, 180.0, 1.0)

	# 颜色 + 暂停
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	col.add_child(bottom_row)
	var clabel := _label("光纹色", 11, C_MUTED)
	clabel.custom_minimum_size = Vector2(44.0, 0.0)
	clabel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_row.add_child(clabel)
	_color_button = ColorPickerButton.new()
	_color_button.color = Color(0.66, 1.0, 0.93)
	_color_button.custom_minimum_size = Vector2(52.0, 22.0)
	_color_button.tooltip_text = "点击选择光纹颜色"
	_color_button.add_theme_font_size_override("font_size", 10)
	_color_button.color_changed.connect(_on_color_changed)
	bottom_row.add_child(_color_button)
	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(flex)
	var pause_btn := _chip("暂停", func(): _call_main("toggle_pause"))
	pause_btn.custom_minimum_size = Vector2(58.0, 23.0)
	bottom_row.add_child(pause_btn)
	pause_btn.set_meta("label", "暂停")
	_toggle_buttons["paused"] = pause_btn

	_footer_hint = _label("左键聚光 · 右键拖拽 · 滚轮缩放\nR 重置 · H 隐藏 · Tab 收面板", 10,
			Color(0.37, 0.54, 0.53))
	_footer_hint.add_theme_font_override("font", _font_mono)
	_footer_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_footer_hint)


func _build_bottom_hints() -> void:
	_hint_label = _label(
			"左键 聚光    右键拖拽环视 / 滚轮缩放    1 池底  2 熔岩    K 单格/3×3    D 调试    W 扭曲    B 鼓结    J 聚散    L 柔光",
			10, Color(0.54, 0.72, 0.69))
	_hint_label.add_theme_font_override("font", _font_mono)
	_hint_label.position = Vector2(28.0, UI_H - 34.0)
	_hint_label.size = Vector2(900.0, 18.0)
	_ui.add_child(_hint_label)


func _build_caption() -> void:
	_caption_root = PanelContainer.new()
	_caption_root.position = Vector2(360.0, UI_H - 100.0)
	_caption_root.custom_minimum_size = Vector2(560.0, 0.0)
	_caption_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.008, 0.032, 0.035, 0.62)
	st.border_color = Color(0.30, 0.75, 0.68, 0.35)
	st.border_width_top = 1
	st.content_margin_left = 18.0
	st.content_margin_right = 18.0
	st.content_margin_top = 8.0
	st.content_margin_bottom = 8.0
	st.set_corner_radius_all(2)
	_caption_root.add_theme_stylebox_override("panel", st)
	_ui.add_child(_caption_root)
	_caption_label = _label("", 15, Color(0.86, 0.98, 0.93))
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_root.add_child(_caption_label)
	_caption_root.visible = false


func _build_toast() -> void:
	_toast_root = PanelContainer.new()
	_toast_root.position = Vector2(UI_W * 0.5 - 90.0, 26.0)
	_toast_root.custom_minimum_size = Vector2(180.0, 0.0)
	_toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.014, 0.055, 0.060, 0.82)
	st.border_color = Color(0.40, 0.88, 0.78, 0.50)
	st.set_border_width_all(1)
	st.set_corner_radius_all(10)
	st.content_margin_left = 12.0
	st.content_margin_right = 12.0
	st.content_margin_top = 4.0
	st.content_margin_bottom = 4.0
	_toast_root.add_theme_stylebox_override("panel", st)
	_ui.add_child(_toast_root)
	_toast_label = _label("", 11, C_ACCENT)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_root.add_child(_toast_label)
	_toast_root.visible = false


# ── 控件辅助 ────────────────────────────────────────────────────────────

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(0.24, 0.55, 0.52, 0.28)
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _chip(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", C_MUTED)
	b.add_theme_color_override("font_hover_color", C_TEXT)
	b.add_theme_color_override("font_pressed_color", C_TEXT)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	_apply_chip_style(b, false)
	return b


func _apply_chip_style(b: Button, active: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.32, 0.31, 0.62) if active else Color(0.03, 0.12, 0.13, 0.56)
	normal.border_color = Color(0.46, 1.0, 0.88, 0.70) if active else Color(0.20, 0.46, 0.44, 0.34)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 6.0
	normal.content_margin_right = 6.0
	normal.content_margin_top = 3.0
	normal.content_margin_bottom = 3.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.40, 0.38, 0.74)
	hover.border_color = Color(0.55, 1.0, 0.90, 0.85)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.20, 0.48, 0.44, 0.80)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", C_TEXT if active else C_MUTED)


func _set_button_active(buttons: Array, active_idx: int) -> void:
	for i in buttons.size():
		_apply_chip_style(buttons[i], i == active_idx)


func _add_toggle(key: String, text: String) -> void:
	var b := _chip("", func(): _on_toggle_pressed(key))
	b.custom_minimum_size = Vector2(128.0, 23.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 11)
	_toggle_grid.add_child(b)
	_toggle_buttons[key] = b
	_update_toggle_text(key, true, text)


func _update_toggle_text(key: String, on: bool, label_text: String = "") -> void:
	var b: Button = _toggle_buttons.get(key)
	if b == null:
		return
	if label_text == "":
		label_text = b.get_meta("label", key)
	b.set_meta("label", label_text)
	b.text = ("● " if on else "○ ") + label_text
	b.add_theme_color_override("font_color", C_ACCENT if on else C_MUTED)
	_apply_chip_style(b, on)


func _set_toggle_state(key: String, on: bool) -> void:
	var b: Button = _toggle_buttons.get(key)
	if b != null:
		_update_toggle_text(key, on)


func _add_slider(parent: VBoxContainer, key: String, title: String,
		min_value: float, max_value: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.custom_minimum_size = Vector2(0.0, 23.0)
	parent.add_child(row)

	var name_label := _label(title, 11, C_MUTED)
	name_label.custom_minimum_size = Vector2(36.0, 0.0)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(142.0, 17.0)
	slider.focus_mode = Control.FOCUS_NONE
	_style_slider(slider)
	slider.value_changed.connect(_on_slider_changed.bind(key))
	row.add_child(slider)

	var val := _label("0.00", 10, C_WARM)
	val.add_theme_font_override("font", _font_mono)
	val.custom_minimum_size = Vector2(48.0, 0.0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(val)

	_sliders[key] = slider
	_value_labels[key] = val
	_slider_rows[key] = row


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.30, 0.28, 0.72)
	track.set_corner_radius_all(2)
	track.content_margin_top = 1.0
	track.content_margin_bottom = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.86, 0.76, 0.86)
	fill.set_corner_radius_all(2)
	fill.content_margin_top = 1.0
	fill.content_margin_bottom = 1.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var grabber := _circle_texture(14, Color(0.82, 1.0, 0.95))
	var grabber_hi := _circle_texture(14, Color(1.0, 0.86, 0.56))
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber_hi)
	slider.add_theme_icon_override("grabber_disabled", grabber)


func _circle_texture(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	var radius := c - 1.0
	for y in size:
		for x in size:
			var d := Vector2(float(x) - c, float(y) - c).length()
			var a := clampf(radius + 1.0 - d, 0.0, 1.0)
			if d <= radius:
				img.set_pixel(x, y, color)
			elif d <= radius + 1.3:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, a * color.a))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _update_value_label(key: String, value: float) -> void:
	if key == "width":
		_value_labels[key].text = "%.3f" % value
	elif key == "scale":
		_value_labels[key].text = "%.2f" % value
	elif key == "flow":
		_value_labels[key].text = "%d°" % int(round(value))
	else:
		_value_labels[key].text = "%.2f" % value


func _on_slider_changed(value: float, key: String) -> void:
	if _syncing or main == null:
		return
	_update_value_label(key, value)
	main.set_param(key, value)


func _on_toggle_pressed(key: String) -> void:
	if main == null:
		return
	if key == "auto":
		var st: Dictionary = main.get_state()
		main.set_toggle("auto_orbit", not bool(st["camera_auto"]))
		_toggle_buttons["auto"].set_meta("label", "自动环视")
		_update_toggle_text("auto", not bool(st["camera_auto"]), "自动环视")
	elif key == "paused":
		main.call("toggle_pause")
	else:
		var st: Dictionary = main.get_state()
		main.set_toggle(key, not bool(st[key]))


func _on_color_changed(color: Color) -> void:
	if _syncing or main == null:
		return
	main.set_line_color(color)


func _call_main(method: String, arg: Variant = null) -> void:
	if main == null:
		return
	if arg == null:
		main.call(method)
	else:
		main.call(method, arg)


func _on_debug_pressed(index: int) -> void:
	_call_main("set_debug_mode", index)
