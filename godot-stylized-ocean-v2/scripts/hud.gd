class_name OceanHud
extends CanvasLayer

# 中文 HUD：标题、参数面板（时间/波浪/泡沫/水色/涟漪/相机/雨/调试）、操作提示、FPS/Draw Calls。
# 面板为深青玻璃底 + 奶白字 + 青绿滑条，呼应参考的清爽卡通海岛。

var world: Node
var scale_factor := 1.0
var root: Control
var panel: PanelContainer
var panel_body: VBoxContainer
var panel_toggle: Button
var collapse_box: VBoxContainer
var stats_label: Label
var caption_label: Label
var debug_label: Label
var hints: Label
var theme: Theme
var font: SystemFont
var mono_font: SystemFont

var _controls: Dictionary = {}
var _syncing := false
var _panel_open := true
var _debug_captions := [
	"", "调试 · 浪高视图", "调试 · 法线视图", "调试 · 泡沫视图",
	"调试 · 涟漪源视图", "调试 · 水深视图", "调试 · 岸线梯度视图",
]

const PANEL_W := 306.0
const MARGIN := 22.0


func setup(p_world: Node, p_scale := 1.0) -> void:
	world = p_world
	scale_factor = p_scale
	layer = 10
	_build()


func _make_fonts() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
			"Microsoft YaHei", "Heiti SC", "Arial"])
	font.font_weight = 500
	mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Menlo", "SF Mono", "Consolas", "monospace"])


func _make_theme() -> void:
	_make_fonts()
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = int(14.0 * scale_factor)
	theme.set_color("font_color", "Label", Color("#edf7f6"))
	theme.set_color("font_color", "Button", Color("#eaf6f4"))
	theme.set_color("font_hover_color", "Button", Color("#ffffff"))
	theme.set_color("font_pressed_color", "Button", Color("#0f2c33"))
	theme.set_color("font_color", "CheckButton", Color("#e8f4f2"))
	theme.set_font_size("font_size", "Label", int(14.0 * scale_factor))

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.16, 0.36, 0.4, 0.55)
	btn.corner_radius_top_left = int(7 * scale_factor)
	btn.corner_radius_top_right = int(7 * scale_factor)
	btn.corner_radius_bottom_left = int(7 * scale_factor)
	btn.corner_radius_bottom_right = int(7 * scale_factor)
	btn.content_margin_left = int(10 * scale_factor)
	btn.content_margin_right = int(10 * scale_factor)
	btn.content_margin_top = int(4 * scale_factor)
	btn.content_margin_bottom = int(4 * scale_factor)
	theme.set_stylebox("normal", "Button", btn)
	var btn_hover := btn.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.24, 0.55, 0.58, 0.7)
	theme.set_stylebox("hover", "Button", btn_hover)
	var btn_press := btn.duplicate() as StyleBoxFlat
	btn_press.bg_color = Color(0.55, 0.93, 0.88, 0.9)
	theme.set_stylebox("pressed", "Button", btn_press)

	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.06, 0.16, 0.2, 0.7)
	slider_bg.corner_radius_top_left = 3
	slider_bg.corner_radius_top_right = 3
	slider_bg.corner_radius_bottom_left = 3
	slider_bg.corner_radius_bottom_right = 3
	slider_bg.content_margin_top = int(3 * scale_factor)
	slider_bg.content_margin_bottom = int(3 * scale_factor)
	theme.set_stylebox("slider", "HSlider", slider_bg)
	var slider_grab := StyleBoxFlat.new()
	slider_grab.bg_color = Color("#6fe3d6")
	slider_grab.corner_radius_top_left = 6
	slider_grab.corner_radius_top_right = 6
	slider_grab.corner_radius_bottom_left = 6
	slider_grab.corner_radius_bottom_right = 6
	theme.set_stylebox("grabber_area", "HSlider", slider_grab)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_grab)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.11, 0.14, 0.82)
	panel_style.border_color = Color(0.35, 0.75, 0.74, 0.35)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = int(14 * scale_factor)
	panel_style.corner_radius_top_right = int(14 * scale_factor)
	panel_style.corner_radius_bottom_left = int(14 * scale_factor)
	panel_style.corner_radius_bottom_right = int(14 * scale_factor)
	panel_style.content_margin_left = int(14 * scale_factor)
	panel_style.content_margin_right = int(14 * scale_factor)
	panel_style.content_margin_top = int(12 * scale_factor)
	panel_style.content_margin_bottom = int(12 * scale_factor)
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	theme.set_stylebox("panel", "Panel", panel_style)

	var option := StyleBoxFlat.new()
	option.bg_color = Color(0.06, 0.18, 0.22, 0.95)
	option.border_color = Color(0.35, 0.75, 0.74, 0.35)
	option.set_border_width_all(1)
	option.corner_radius_top_left = 6
	option.corner_radius_top_right = 6
	option.corner_radius_bottom_left = 6
	option.corner_radius_bottom_right = 6
	option.content_margin_left = 8
	option.content_margin_right = 8
	option.content_margin_top = 4
	option.content_margin_bottom = 4
	theme.set_stylebox("normal", "OptionButton", option)
	theme.set_stylebox("hover", "OptionButton", option)
	theme.set_stylebox("pressed", "OptionButton", option)


func _build() -> void:
	_make_theme()
	_controls.clear()
	for child in get_children():
		child.queue_free()
		if child is Control:
			remove_child(child)
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)

	_build_title()
	_build_panel()
	_build_hints()
	_build_stats()
	_build_caption()
	_build_debug()


func _build_title() -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	box.offset_left = MARGIN * scale_factor
	box.offset_top = MARGIN * scale_factor
	box.add_theme_constant_override("separation", int(2 * scale_factor))
	root.add_child(box)
	var title := Label.new()
	title.text = "风格化海洋 · 第二版"
	title.add_theme_font_size_override("font_size", int(23 * scale_factor))
	title.add_theme_color_override("font_color", Color("#f3fbf8"))
	title.add_theme_color_override("font_shadow_color", Color(0.02, 0.1, 0.13, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "STYLIZED WILD OCEAN  ·  原创低模 · 实时水面"
	sub.add_theme_font_size_override("font_size", int(10.5 * scale_factor))
	sub.add_theme_color_override("font_color", Color(0.82, 0.95, 0.92, 0.9))
	box.add_child(sub)
	var accent := ColorRect.new()
	accent.color = Color("#6fe3d6")
	accent.custom_minimum_size = Vector2(38 * scale_factor, 2.5 * scale_factor)
	box.add_child(accent)


func _section(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 7 * scale_factor)
	panel_body.add_child(spacer)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	var dot := ColorRect.new()
	dot.color = Color("#6fe3d6")
	dot.custom_minimum_size = Vector2(3 * scale_factor, 13 * scale_factor)
	line.add_child(dot)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(13 * scale_factor))
	label.add_theme_color_override("font_color", Color(0.65, 0.92, 0.88, 1.0))
	line.add_child(label)
	panel_body.add_child(line)


func _slider(key: String, text: String, min_v: float, max_v: float, step: float,
		value: float, fmt: String, callback: Callable) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var name_label := Label.new()
	name_label.text = text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", int(13 * scale_factor))
	head.add_child(name_label)
	var val_label := Label.new()
	val_label.text = fmt % value
	val_label.add_theme_font_size_override("font_size", int(12 * scale_factor))
	val_label.add_theme_color_override("font_color", Color("#a9ece2"))
	head.add_child(val_label)
	panel_body.add_child(head)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 15 * scale_factor)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_child(slider)
	slider.value_changed.connect(func(v: float):
		val_label.text = fmt % v
		if not _syncing:
			callback.call(v)
	)
	_controls[key] = {"slider": slider, "label": val_label, "fmt": fmt}


func _row_buttons(items: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", int(12 * scale_factor))
		var cb: Callable = item[1]
		b.pressed.connect(cb)
		row.add_child(b)
	panel_body.add_child(row)


func _check(key: String, text: String, value: bool, callback: Callable) -> void:
	var cb := CheckButton.new()
	cb.text = text
	cb.button_pressed = value
	cb.add_theme_font_size_override("font_size", int(13 * scale_factor))
	panel_body.add_child(cb)
	cb.toggled.connect(func(v: bool):
		if not _syncing:
			callback.call(v)
	)
	_controls[key] = {"check": cb}


func _option(key: String, text: String, items: PackedStringArray, selected: int, callback: Callable) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var name_label := Label.new()
	name_label.text = text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", int(13 * scale_factor))
	head.add_child(name_label)
	var opt := OptionButton.new()
	opt.add_theme_font_size_override("font_size", int(12 * scale_factor))
	for it in items:
		opt.add_item(it)
	opt.selected = selected
	head.add_child(opt)
	panel_body.add_child(head)
	opt.item_selected.connect(func(idx: int):
		if not _syncing:
			callback.call(idx)
	)
	_controls[key] = {"option": opt}


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -(PANEL_W + MARGIN) * scale_factor
	panel.offset_right = -MARGIN * scale_factor
	panel.offset_top = MARGIN * scale_factor
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.custom_minimum_size = Vector2(PANEL_W * scale_factor, 0)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(5 * scale_factor))
	panel.add_child(vbox)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "参数面板"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", int(16 * scale_factor))
	title.add_theme_color_override("font_color", Color("#f6fdfb"))
	head.add_child(title)
	panel_toggle = Button.new()
	panel_toggle.text = "收起"
	panel_toggle.add_theme_font_size_override("font_size", int(11 * scale_factor))
	panel_toggle.pressed.connect(toggle_panel)
	head.add_child(panel_toggle)
	vbox.add_child(head)

	var divider := ColorRect.new()
	divider.color = Color(0.45, 0.83, 0.8, 0.28)
	divider.custom_minimum_size = Vector2(0, 1 * scale_factor)
	vbox.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0, 545 * scale_factor)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	panel_body = VBoxContainer.new()
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation", int(2 * scale_factor))
	scroll.add_child(panel_body)

	var footer := Label.new()
	footer.text = "H 隐藏界面 · Space 暂停 · R 下雨 · 实时生效"
	footer.add_theme_font_size_override("font_size", int(9.5 * scale_factor))
	footer.add_theme_color_override("font_color", Color(0.62, 0.82, 0.8, 0.85))
	vbox.add_child(footer)
	collapse_box = VBoxContainer.new()
	collapse_box.add_theme_constant_override("separation", int(2 * scale_factor))
	# 便于整体收起：把滚动区与页脚移入同一容器
	vbox.remove_child(scroll)
	vbox.remove_child(footer)
	collapse_box.add_child(scroll)
	collapse_box.add_child(footer)
	vbox.add_child(collapse_box)

	_section("时间与光照")
	_slider("hour", "时间 / 太阳高度", 5.0, 21.5, 0.1, 11.5, "%.1f h", func(v): world.set_hour(v))
	_row_buttons([
		["正午", func(): world.set_time_preset("noon")],
		["黄昏", func(): world.set_time_preset("dusk")],
		["夜晚", func(): world.set_time_preset("night")],
	])
	_slider("glint", "太阳高光", 0.0, 2.0, 0.01, 1.0, "%.2f", func(v): world.set_sun_glint(v))

	_section("海面")
	_slider("wave_height", "浪高", 0.0, 2.5, 0.01, 0.72, "%.2f", func(v): world.set_wave_height(v))
	_slider("wave_speed", "浪速", 0.0, 2.5, 0.01, 1.0, "%.2f", func(v): world.set_wave_speed(v))
	_slider("wave_dir", "浪向", 0.0, 360.0, 1.0, 18.0, "%.0f°", func(v): world.set_wave_dir(v))
	_slider("foam", "岸边泡沫", 0.0, 1.6, 0.01, 0.85, "%.2f", func(v): world.set_foam(v))
	_option("water_style", "水色", PackedStringArray(["参考深海蓝", "热带青绿", "暮色深蓝"]), 0,
			func(idx): world.set_water_style(idx))

	_section("涟漪互动")
	_slider("ripple_amp", "涟漪强度", 0.0, 2.0, 0.01, 1.0, "%.2f", func(v): world.set_ripple_strength(v))
	_slider("ripple_decay", "涟漪持续", 0.0, 1.0, 0.01, 0.35, "%.2f", func(v): world.set_ripple_decay(v))
	_check("ripples_on", "鼠标涟漪 / 落石", true, func(v): world.set_ripples_enabled(v))
	_check("shoreline", "岸线编辑可视化", false, func(v): world.set_shoreline_visible(v))

	_section("天气与镜头")
	_check("rain", "下雨", false, func(v): world.set_rain(v))
	_check("auto_orbit", "自动环绕", true, func(v): world.set_auto_orbit(v))
	_slider("pitch", "俯瞰仰角", 12.0, 86.0, 1.0, 58.0, "%.0f°", func(v): world.set_camera_pitch(v))
	_slider("distance", "相机距离", 40.0, 200.0, 1.0, 108.0, "%.0f m", func(v): world.set_camera_distance(v))

	_section("调试")
	_option("debug", "视图", PackedStringArray(["关闭", "浪高", "法线", "泡沫", "涟漪源", "水深", "岸线梯度"]), 0,
			func(idx): world.set_debug_view(idx))
	_row_buttons([
		["重置参数", func(): world.reset_params()],
		["隐藏 UI", func(): set_ui_visible(false)],
	])


func _build_hints() -> void:
	hints = Label.new()
	hints.text = "左键拖拽  水面涟漪 / 尾迹      单击  落石水花\n右键拖拽  旋转视角      滚轮  缩放\nH 隐藏界面   Space 暂停   R 下雨   F1–F7 调试视图"
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hints.offset_left = MARGIN * scale_factor
	hints.offset_bottom = -MARGIN * scale_factor
	hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hints.add_theme_font_size_override("font_size", int(11.5 * scale_factor))
	hints.add_theme_color_override("font_color", Color(0.88, 0.97, 0.95, 0.88))
	hints.add_theme_color_override("font_shadow_color", Color(0.02, 0.08, 0.1, 0.6))
	hints.add_theme_constant_override("shadow_offset_x", 1)
	hints.add_theme_constant_override("shadow_offset_y", 1)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hints)


func _build_stats() -> void:
	stats_label = Label.new()
	stats_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	stats_label.offset_right = -MARGIN * scale_factor
	stats_label.offset_bottom = -MARGIN * scale_factor
	stats_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stats_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_label.add_theme_font_override("font", mono_font)
	stats_label.add_theme_font_size_override("font_size", int(10.5 * scale_factor))
	stats_label.add_theme_color_override("font_color", Color(0.83, 0.97, 0.94, 0.9))
	stats_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.08, 0.1, 0.65))
	stats_label.add_theme_constant_override("shadow_offset_x", 1)
	stats_label.add_theme_constant_override("shadow_offset_y", 1)
	stats_label.text = "FPS --   DC --"
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stats_label)


func _build_caption() -> void:
	caption_label = Label.new()
	caption_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption_label.offset_bottom = -62 * scale_factor
	caption_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
	caption_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	caption_label.add_theme_color_override("font_outline_color", Color(0.03, 0.13, 0.17, 0.9))
	caption_label.add_theme_constant_override("outline_size", 4)
	caption_label.text = ""
	caption_label.visible = false
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(caption_label)


func _build_debug() -> void:
	debug_label = Label.new()
	debug_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	debug_label.offset_top = MARGIN * scale_factor
	debug_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_label.add_theme_font_size_override("font_size", int(12 * scale_factor))
	debug_label.add_theme_color_override("font_color", Color("#c8fff4"))
	debug_label.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.12, 0.9))
	debug_label.add_theme_constant_override("outline_size", 3)
	debug_label.text = ""
	debug_label.visible = false
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(debug_label)


func set_display_scale(s: float) -> void:
	scale_factor = s
	_build()
	refresh_from_world()


func set_ui_visible(v: bool) -> void:
	visible = v


func set_panel_open(open: bool) -> void:
	_panel_open = open
	if collapse_box != null:
		collapse_box.visible = open
	panel_toggle.text = "收起" if open else "展开"


func toggle_panel() -> void:
	set_panel_open(not _panel_open)


func set_stats(text: String) -> void:
	stats_label.text = text


func set_caption(text: String) -> void:
	caption_label.text = text
	caption_label.visible = text != ""


func set_debug_view_caption(mode: int) -> void:
	if mode <= 0 or mode >= _debug_captions.size():
		debug_label.visible = false
		debug_label.text = ""
	else:
		debug_label.text = _debug_captions[mode]
		debug_label.visible = true


func refresh_from_world() -> void:
	if world == null or not world.has_method("get_ui_state"):
		return
	var st: Dictionary = world.get_ui_state()
	_syncing = true
	_set_ctrl("hour", st.get("hour", 11.5))
	_set_ctrl("glint", st.get("sun_glint", 1.0))
	_set_ctrl("wave_height", st.get("wave_height", 0.72))
	_set_ctrl("wave_speed", st.get("wave_speed", 1.0))
	_set_ctrl("wave_dir", st.get("wave_dir", 18.0))
	_set_ctrl("foam", st.get("foam", 0.85))
	_set_ctrl("ripple_amp", st.get("ripple_amp", 1.0))
	_set_ctrl("ripple_decay", st.get("ripple_decay", 0.35))
	_set_ctrl("pitch", st.get("pitch", 58.0))
	_set_ctrl("distance", st.get("distance", 108.0))
	_syncing = false


func _set_ctrl(key: String, value: float) -> void:
	if not _controls.has(key):
		return
	var c: Dictionary = _controls[key]
	if c.has("slider"):
		var slider: HSlider = c["slider"]
		slider.set_value_no_signal(value)
		var lbl: Label = c["label"]
		lbl.text = String(c["fmt"]) % value
