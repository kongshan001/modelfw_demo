extends CanvasLayer

# 中文参数面板。像素世界固定 1280×720，HUD 用系统 CJK 字体绘制。
# 滑杆只调“全局倍率”，海/河/湖的基础差异来自数据类别与控制器预设。

const PANEL_WIDTH := 352
const SUBTLE := Color(0.72, 0.86, 0.80)
const WARM := Color(0.99, 0.84, 0.52)
const ACCENT := Color(0.55, 0.90, 0.76)
const DIM := Color(0.52, 0.66, 0.62)

var main: Node

var _root: Control
var _tab: Button
var _panel: PanelContainer
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _focus_buttons: Dictionary = {}
var _pause_button: Button
var _rain_button: Button
var _debug_option: OptionButton
var _fps_label: Label
var _body_label: Label
var _state_label: Label
var _legend: Label
var _stats_panel: PanelContainer
var _caption_root: Control
var _caption: Label
var _caption_bar: ColorRect
var _ui_visible := true
var _panel_open := false
var _syncing := false


func _ready() -> void:
	_build_ui()
	set_process(true)


func setup(main_node: Node) -> void:
	main = main_node
	sync_from_main()


func set_ui_visible(value: bool) -> void:
	_ui_visible = value
	if _root != null:
		_root.visible = value


func set_panel_open(value: bool) -> void:
	_panel_open = value
	if _panel != null:
		_panel.visible = value
	if _tab != null:
		_tab.text = "收起参数 (H)" if value else "☰ 参数 (H)"
	if value:
		_refresh_stats()


func is_panel_open() -> bool:
	return _panel_open


func toggle_ui() -> void:
	set_panel_open(not _panel_open)


func set_stats_visible(value: bool) -> void:
	if _stats_panel != null:
		_stats_panel.visible = value


func set_display_scale(s: float) -> void:
	# 仅缩放面板与字幕，避免 CanvasLayer 缩放把底部字幕推到视口外。
	if _panel != null:
		_panel.scale = Vector2(s, s)
		_panel.pivot_offset = Vector2.ZERO
	if _tab != null:
		_tab.add_theme_font_size_override("font_size", int(round(13.0 * s)))
		_tab.custom_minimum_size = Vector2(118.0 * s, 32.0 * s)
		_tab.size = Vector2(118.0 * s, 32.0 * s)
	if _caption != null:
		_caption.add_theme_font_size_override("font_size", int(round(18.0 * s)))
	if _caption_bar != null:
		_caption_bar.offset_top = -48.0 * s
		_caption_bar.custom_minimum_size = Vector2(0, 48.0 * s)


func show_caption(text: String) -> void:
	if _caption != null:
		_caption.text = text
		_caption.visible = text != ""
	if _caption_bar != null:
		_caption_bar.visible = text != ""


func sync_from_main() -> void:
	if main == null:
		return
	_syncing = true
	var p: Dictionary = main.get_params()
	for key in _sliders.keys():
		var slider: HSlider = _sliders[key]
		slider.value = float(p[key])
		_update_value_label(key, float(p[key]))
	_rain_button.text = "雨 停" if bool(p["rain"]) or float(p["rain"]) > 0.01 else "降 雨"
	_pause_button.text = "继续" if bool(p["paused"]) else "暂停"
	_debug_option.select(int(p["debug"]))
	for cat in _focus_buttons.keys():
		var b: Button = _focus_buttons[cat]
		var on := int(p["focus"]) == int(cat)
		b.add_theme_color_override("font_color", WARM if on else SUBTLE)
		b.modulate = Color(1.0, 1.0, 1.0) if on else Color(0.78, 0.84, 0.81)
	_syncing = false
	_refresh_stats()


func tick() -> void:
	# 面板收起时不做任何 UI 文本布局（性能：默认 HUD 只有参数 chip）。
	if not _panel_open:
		return
	_refresh_stats()


func _refresh_stats() -> void:
	if main == null or _fps_label == null:
		return
	_fps_label.text = "FPS %d      DRAW %d" % [main.get_fps(), main.get_draw_calls()]
	_body_label.text = main.pipeline_summary()
	var p: Dictionary = main.get_params()
	_state_label.text = "t %5.1fs   雨量 %3d%%   观察 %s   调试 %s" % [
		float(p["time"]), int(round(float(p["rain"]) * 100.0)),
		p["focus_label"], p["debug_label"]]
	var dv := int(p["debug"])
	match dv:
		1:
			_legend.text = "青=水体覆盖   蓝=桥面裁切   黄=低洼积水   网格 16px"
		2:
			_legend.text = "蓝=浅水   黄=深水   白=等深线   网格 16px"
		3:
			_legend.text = "蓝=海   绿=河   紫=湖   黄=积水   洋红=桥面裁切"
		4:
			_legend.text = "白=岸线   青=水深轮廓   洋红=桥面裁切"
		_:
			_legend.text = "空格暂停 · R 降雨 · 1/2/3 切水体 · F 调试 · B 重建"


func _process(_delta: float) -> void:
	# 统计由 main 以 5Hz 调用 tick()；这里不再每帧重排字体。
	return


# ── 构建 ─────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "STHeiti",
		"Noto Sans CJK SC", "Sans-Serif"])
	font.allow_system_fallback = true

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 13
	theme.set_color("font_color", "Label", SUBTLE)
	theme.set_color("font_color", "Button", Color(0.90, 0.95, 0.88))
	theme.set_color("font_color", "CheckBox", SUBTLE)
	theme.set_font_size("font_size", "Button", 12)
	theme.set_constant("outline_size", "Label", 0)

	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = theme
	add_child(_root)

	# 默认收起：仅左上角一个 32px 高的参数 chip，避免 HUD 压景。
	_tab = Button.new()
	_tab.text = "☰ 参数 (H)"
	_tab.position = Vector2(18, 18)
	_tab.custom_minimum_size = Vector2(118, 32)
	_tab.size = Vector2(118, 32)
	_tab.add_theme_font_size_override("font_size", 13)
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Color(0.030, 0.068, 0.064, 0.90)
	tab_style.border_color = Color(0.36, 0.68, 0.58, 0.85)
	tab_style.set_border_width_all(2)
	tab_style.set_corner_radius_all(5)
	_tab.add_theme_stylebox_override("normal", tab_style)
	_tab.pressed.connect(toggle_ui)
	_root.add_child(_tab)

	_panel = PanelContainer.new()
	_panel.position = Vector2(18, 58)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.030, 0.068, 0.064, 0.92)
	style.border_color = Color(0.36, 0.68, 0.58, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)
	_panel.visible = _panel_open

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := Label.new()
	title.text = "潮汐花园"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", WARM)
	title_row.add_child(title)
	var title_tag := Label.new()
	title_tag.text = "ONE WATER SHADER"
	title_tag.add_theme_font_size_override("font_size", 9)
	title_tag.add_theme_color_override("font_color", DIM)
	title_tag.size_flags_vertical = Control.SIZE_SHRINK_END
	title_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(title_tag)

	var subtitle := Label.new()
	subtitle.text = "海 / 河 / 湖共用 1 个水面 Shader · 零额外水面网格"
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", SUBTLE)
	column.add_child(subtitle)

	_stats_panel = PanelContainer.new()
	var stat_style := StyleBoxFlat.new()
	stat_style.bg_color = Color(0.018, 0.042, 0.040, 0.74)
	stat_style.border_color = Color(0.22, 0.38, 0.34, 0.7)
	stat_style.set_border_width_all(1)
	stat_style.set_corner_radius_all(3)
	stat_style.content_margin_left = 8
	stat_style.content_margin_right = 8
	stat_style.content_margin_top = 4
	stat_style.content_margin_bottom = 4
	_stats_panel.add_theme_stylebox_override("panel", stat_style)
	column.add_child(_stats_panel)
	var stat_box := VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 1)
	_stats_panel.add_child(stat_box)
	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 10)
	_fps_label.add_theme_color_override("font_color", ACCENT)
	stat_box.add_child(_fps_label)
	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", 10)
	_body_label.add_theme_color_override("font_color", SUBTLE)
	stat_box.add_child(_body_label)
	_state_label = Label.new()
	_state_label.add_theme_font_size_override("font_size", 9)
	_state_label.add_theme_color_override("font_color", DIM)
	stat_box.add_child(_state_label)

	_add_divider(column)
	var focus_title := Label.new()
	focus_title.text = "观察水体（1 / 2 / 3）· 只高亮，不改变分类"
	focus_title.add_theme_font_size_override("font_size", 9)
	focus_title.add_theme_color_override("font_color", DIM)
	column.add_child(focus_title)
	var focus_row := HBoxContainer.new()
	focus_row.add_theme_constant_override("separation", 4)
	column.add_child(focus_row)
	_add_focus_button(focus_row, "全部", WaterController.CAT_ALL)
	_add_focus_button(focus_row, "海域", WaterController.CAT_SEA)
	_add_focus_button(focus_row, "河流", WaterController.CAT_RIVER)
	_add_focus_button(focus_row, "内陆湖", WaterController.CAT_LAKE)

	_add_divider(column)
	_add_slider(column, "tide", "潮汐（岸线位移）", 0.0, 1.0, 0.01, 0.5, true)
	_add_slider(column, "flow", "流速倍率", 0.0, 2.0, 0.05, 1.0, false)
	_add_slider(column, "wave", "浪幅倍率", 0.0, 2.0, 0.05, 1.0, false)
	_add_slider(column, "foam", "泡沫倍率", 0.0, 2.0, 0.05, 1.0, false)
	_add_slider(column, "caustic", "焦散倍率", 0.0, 2.0, 0.05, 1.0, false)
	_add_slider(column, "rain", "雨量", 0.0, 1.0, 0.01, 0.0, true)

	_add_divider(column)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	column.add_child(row1)
	_rain_button = Button.new()
	_rain_button.text = "降 雨"
	_rain_button.custom_minimum_size = Vector2(70, 32)
	_rain_button.pressed.connect(_on_rain_toggle)
	row1.add_child(_rain_button)
	_pause_button = Button.new()
	_pause_button.text = "暂停"
	_pause_button.custom_minimum_size = Vector2(58, 32)
	_pause_button.pressed.connect(_on_pause_toggle)
	row1.add_child(_pause_button)
	_debug_option = OptionButton.new()
	_debug_option.custom_minimum_size = Vector2(154, 32)
	for item in ["调试：关闭", "调试：水体掩码", "调试：水深场", "调试：类别", "调试：岸线"]:
		_debug_option.add_item(item)
	_debug_option.item_selected.connect(_on_debug_selected)
	row1.add_child(_debug_option)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	column.add_child(row2)
	var rebuild := Button.new()
	rebuild.text = "重建管线 (B)"
	rebuild.custom_minimum_size = Vector2(140, 32)
	rebuild.pressed.connect(_on_rebuild)
	row2.add_child(rebuild)
	var reset := Button.new()
	reset.text = "重置 (N)"
	reset.custom_minimum_size = Vector2(92, 32)
	reset.pressed.connect(_on_reset)
	row2.add_child(reset)
	var hide := Button.new()
	hide.text = "收起 (H)"
	hide.custom_minimum_size = Vector2(80, 32)
	hide.pressed.connect(toggle_ui)
	row2.add_child(hide)

	_legend = Label.new()
	_legend.text = "空格暂停 · R 降雨 · 1/2/3 切水体 · F 调试 · B 重建"
	_legend.add_theme_font_size_override("font_size", 9)
	_legend.add_theme_color_override("font_color", DIM)
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legend.custom_minimum_size = Vector2(PANEL_WIDTH - 22, 0)
	column.add_child(_legend)

	# 底部字幕独立于面板，隐藏 UI 时仍可用于截图 / 视频。
	_caption_root = Control.new()
	_caption_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_root.theme = theme
	add_child(_caption_root)
	# 字幕：底部 48 逻辑 px 安全条 #0B1414 α0.55，正文 18px #F5F7E0 ≥4.5:1。
	_caption_bar = ColorRect.new()
	_caption_bar.color = Color(0.043, 0.078, 0.078, 0.55)
	_caption_bar.visible = false
	_caption_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption_bar.anchor_top = 1.0
	_caption_bar.anchor_bottom = 1.0
	_caption_bar.offset_top = -48.0
	_caption_bar.offset_bottom = 0.0
	_caption_root.add_child(_caption_bar)
	_caption = Label.new()
	_caption.visible = false
	_caption.text = ""
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.add_theme_color_override("font_color", Color(0.96, 0.97, 0.88))
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption_bar.add_child(_caption)


func _add_focus_button(row: HBoxContainer, text: String, cat: int) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(76, 32)
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(func() -> void:
		if main != null:
			main.set_focus(cat))
	row.add_child(b)
	_focus_buttons[cat] = b


func _add_slider(parent: VBoxContainer, key: String, label_text: String,
		min_v: float, max_v: float, step: float, default_v: float, percent: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(118, 20)
	label.add_theme_font_size_override("font_size", 10)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = default_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(140, 20)
	slider.value_changed.connect(func(value: float) -> void: _on_slider_changed(key, value))
	row.add_child(slider)
	_sliders[key] = slider
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(42, 20)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 9)
	value_label.add_theme_color_override("font_color", ACCENT)
	row.add_child(value_label)
	_value_labels[key] = value_label
	value_label.set_meta("percent", percent)
	_update_value_label(key, default_v)


func _add_divider(parent: VBoxContainer) -> void:
	var line := ColorRect.new()
	line.color = Color(0.26, 0.42, 0.38, 0.55)
	line.custom_minimum_size = Vector2(0, 1)
	parent.add_child(line)


func _update_value_label(key: String, value: float) -> void:
	if not _value_labels.has(key):
		return
	var label: Label = _value_labels[key]
	var percent: bool = label.get_meta("percent", false)
	if key == "flow" or key == "wave" or key == "foam" or key == "caustic":
		label.text = "×%.2f" % value
	elif percent:
		label.text = "%d%%" % int(round(value * 100.0))
	else:
		label.text = "%.2f" % value


# ── 回调 ─────────────────────────────────────────────────────────────────
func _on_slider_changed(key: String, value: float) -> void:
	_update_value_label(key, value)
	if _syncing or main == null:
		return
	if key == "rain":
		main.set_rain(value)
	else:
		main.set_param(key, value)


func _on_rain_toggle() -> void:
	if main != null:
		main.toggle_rain()


func _on_pause_toggle() -> void:
	if main != null:
		main.toggle_pause()


func _on_debug_selected(index: int) -> void:
	if main != null:
		main.set_debug_view(index)


func _on_rebuild() -> void:
	if main != null:
		main.rebuild_pipeline()


func _on_reset() -> void:
	if main != null:
		main.reset()


func get_panel_size() -> Vector2:
	return _panel.size if _panel != null else Vector2.ZERO


func get_tab_button() -> Button:
	return _tab
