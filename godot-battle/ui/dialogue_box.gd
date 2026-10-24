class_name DialogueBox
extends Control

# 底部对白框（规格 6.5）：电影黑边 + 打字机 + 自动推进 + 点击/空格推进。
# 手动与自动播放共用；播放期间吞掉鼠标输入，隐藏后完全不影响 HUD。

const TYPE_CPS := 30.0
const BAR_TOP_HEIGHT := 72.0
const BAR_BOTTOM_HEIGHT := 210.0

var auto_advance_seconds := 1.25
var clock_scale := 1.0

var _busy := false
var _typing := false
var _skip_typing := false
var _advance_requested := false
var _current_line := ""
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _panel: PanelContainer
var _label: Label
var _hint: Label
var _fade_tween: Tween

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func _build() -> void:
	_bar_top = ColorRect.new()
	_bar_top.color = Color(0.0, 0.0, 0.0, 0.86)
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_top.anchor_right = 1.0
	_bar_top.offset_bottom = BAR_TOP_HEIGHT
	add_child(_bar_top)

	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color(0.0, 0.0, 0.0, 0.86)
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bottom.anchor_top = 1.0
	_bar_bottom.anchor_right = 1.0
	_bar_bottom.anchor_bottom = 1.0
	_bar_bottom.offset_top = -BAR_BOTTOM_HEIGHT
	add_child(_bar_bottom)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -740.0
	_panel.offset_right = 740.0
	_panel.offset_top = -196.0
	_panel.offset_bottom = -26.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.07, 0.93)
	style.border_color = Color(0.82, 0.66, 0.36, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 16
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)

	_label = Label.new()
	_label.add_theme_font_override("font", FontUtil.cjk_font())
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.91))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 3)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_label)

	_hint = Label.new()
	_hint.text = "点击 / 空格 继续"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_override("font", FontUtil.cjk_font())
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.62, 0.6, 0.56))
	box.add_child(_hint)

# ---------------------------------------------------------------- public API

func play_lines(lines: Array) -> void:
	if lines.is_empty():
		return
	_busy = true
	visible = true
	_advance_requested = false
	_skip_typing = false
	_fade_in()
	for line in lines:
		if not _busy:
			break
		await _type_line(String(line))
		if not _busy:
			break
		await _wait_advance()
	hide_now()

func is_active() -> bool:
	return _busy

func current_line() -> String:
	return _current_line

func advance() -> void:
	if not _busy:
		return
	if _typing:
		_skip_typing = true
	else:
		_advance_requested = true

func hide_now() -> void:
	_busy = false
	_typing = false
	_skip_typing = false
	_advance_requested = false
	_current_line = ""
	if _label != null:
		_label.text = ""
		_label.visible_characters = 0
	visible = false

# ---------------------------------------------------------------- 内部

func _type_line(line: String) -> void:
	_current_line = line
	_label.text = line
	_label.visible_characters = 0
	_typing = true
	_skip_typing = false
	var total := line.length()
	var revealed := 0.0
	while revealed < float(total):
		if not _busy or _skip_typing:
			break
		await get_tree().process_frame
		revealed += TYPE_CPS * maxf(0.01, clock_scale) * get_process_delta_time()
		_label.visible_characters = mini(int(revealed), total)
	_label.visible_characters = -1
	_typing = false

func _wait_advance() -> void:
	_advance_requested = false
	var elapsed := 0.0
	while _busy and elapsed < auto_advance_seconds:
		if _advance_requested:
			_advance_requested = false
			return
		await get_tree().process_frame
		elapsed += maxf(0.0001, get_process_delta_time()) * maxf(0.01, clock_scale)

func _fade_in() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_bar_top.modulate.a = 0.0
	_bar_bottom.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bar_top, "modulate:a", 1.0, 0.18)
	_fade_tween.parallel().tween_property(_bar_bottom, "modulate:a", 1.0, 0.18)
	_fade_tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.18)

func _gui_input(event: InputEvent) -> void:
	if not _busy:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not _busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			advance()
			get_viewport().set_input_as_handled()
