class_name KnotHud
extends CanvasLayer

## Chinese HUD: objectives, live winding progress, contextual hints, debug
## panel and the win card. Built from code so the project has no UI textures.

const FONT_PATH := "res://assets/fonts/NotoSansSC-Knotline.otf"
const INK := Color("#3B352D")
const INK_SOFT := Color("#6F6558")
const MUTED := Color("#958A7B")
const PAPER := Color("#FBF3E4")
const PAPER_EDGE := Color("#DFC9A8")
const ACCENT := Color("#E07856")
const TEAL := Color("#3E8E8A")
const GOLD := Color("#E9AE55")
const PLUM := Color("#8E7DBE")
const DARK_PILL := Color("#2F2A24")

var root: Control
var title_label: Label
var index_label: Label
var name_label: Label
var subtitle_label: Label
var blurb_label: Label
var stats_label: Label
var mode_panel: PanelContainer
var mode_label: Label
var mode_sub_label: Label
var fps_label: Label
var perf_card: PanelContainer
var objectives_box: VBoxContainer
var objective_rows: Dictionary = {}
var hint_panel: PanelContainer
var hint_label: Label
var controls_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var debug_panel: PanelContainer
var debug_label: RichTextLabel
var win_layer: Control
var win_card: PanelContainer
var win_title: Label
var win_sub: Label
var win_stats: Label
var win_footer: Label
var _toast_tween: Tween
var _hint_cache := ""
var _font: Font
var _theme: Theme


func _ready() -> void:
	layer = 5
	_font = _load_font()
	_theme = Theme.new()
	_theme.default_font = _font
	_theme.default_font_size = 16
	_build()


func _load_font() -> Font:
	return KnotFont.ui_font()


func _build() -> void:
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme
	add_child(root)

	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/vignette.gdshader")
	vignette.material = vm
	root.add_child(vignette)

	# ---- top row -----------------------------------------------------------
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22
	top.offset_top = 18
	top.offset_right = -22
	top.offset_bottom = 18
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(408, 0)
	left_panel.add_theme_stylebox_override("panel", _panel_style(PAPER, PAPER_EDGE, 18, 18))
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(left_panel)
	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 18)
	left_margin.add_theme_constant_override("margin_right", 18)
	left_margin.add_theme_constant_override("margin_top", 14)
	left_margin.add_theme_constant_override("margin_bottom", 14)
	left_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.add_child(left_margin)
	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 5)
	left_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_margin.add_child(left_box)

	var crest := HBoxContainer.new()
	crest.add_theme_constant_override("separation", 8)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_box.add_child(crest)
	var kicker := _label("线屿 · KNOTLINE", 12, TEAL)
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crest.add_child(kicker)
	index_label = _label("第 1 / 2 结", 12, MUTED)
	crest.add_child(index_label)

	name_label = _label("青柱庭", 30, INK)
	left_box.add_child(name_label)
	subtitle_label = _label("第一结 · 绕住青柱", 15, ACCENT)
	left_box.add_child(subtitle_label)
	blurb_label = _label("", 13, INK_SOFT)
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb_label.custom_minimum_size = Vector2(368, 0)
	left_box.add_child(blurb_label)

	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", _line_style(PAPER_EDGE))
	rule.custom_minimum_size.y = 10
	left_box.add_child(rule)

	var obj_head := HBoxContainer.new()
	obj_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_box.add_child(obj_head)
	obj_head.add_child(_label("本结目标", 12, MUTED))
	var obj_spacer := Control.new()
	obj_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_head.add_child(obj_spacer)
	obj_head.add_child(_label("● 必须   ○ 可选", 11, MUTED))

	objectives_box = VBoxContainer.new()
	objectives_box.add_theme_constant_override("separation", 3)
	objectives_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_box.add_child(objectives_box)

	stats_label = _label("节点 0 · 绳长 0.0 m · 用时 00:00", 13, INK_SOFT)
	left_box.add_child(stats_label)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(right_spacer)

	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(right_box)

	mode_panel = PanelContainer.new()
	mode_panel.add_theme_stylebox_override("panel", _panel_style(DARK_PILL, Color("#4A4239"), 14, 12))
	mode_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.add_child(mode_panel)
	var mode_box := VBoxContainer.new()
	mode_box.add_theme_constant_override("separation", 1)
	mode_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_panel.add_child(mode_box)
	mode_label = _label("绘制模式", 17, Color("#FFE7BF"))
	mode_box.add_child(mode_label)
	mode_sub_label = _label("左键画线 · Tab 切换", 11, Color("#CFC2B0"))
	mode_box.add_child(mode_sub_label)

	perf_card = PanelContainer.new()
	perf_card.add_theme_stylebox_override("panel", _panel_style(Color(PAPER, 0.94), PAPER_EDGE, 12, 10))
	perf_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.add_child(perf_card)
	var right_inner := VBoxContainer.new()
	right_inner.add_theme_constant_override("separation", 2)
	right_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	perf_card.add_child(right_inner)
	fps_label = _label("FPS —  ·  绘制 —  ·  F1 调试", 11, MUTED)
	right_inner.add_child(fps_label)

	debug_panel = PanelContainer.new()
	debug_panel.add_theme_stylebox_override("panel", _panel_style(Color("#241F1BE8"), Color("#5A4C3B"), 12, 10))
	debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_panel.visible = false
	right_box.add_child(debug_panel)
	debug_label = RichTextLabel.new()
	debug_label.bbcode_enabled = true
	debug_label.fit_content = true
	debug_label.scroll_active = false
	debug_label.custom_minimum_size = Vector2(300, 0)
	debug_label.add_theme_font_size_override("normal_font_size", 12)
	debug_label.add_theme_color_override("default_color", Color("#E7DDCE"))
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_panel.add_child(debug_label)

	# ---- hints and controls ------------------------------------------------
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -142
	bottom.offset_bottom = -16
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)

	hint_panel = PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", _panel_style(Color(DARK_PILL, 0.95), Color("#51483D"), 18, 14))
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(hint_panel)
	var hint_box := VBoxContainer.new()
	hint_box.add_theme_constant_override("separation", 3)
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_child(hint_box)
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 10)
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_box.add_child(hint_row)
	var badge := _label("提示", 12, GOLD)
	badge.custom_minimum_size = Vector2(32, 0)
	hint_row.add_child(badge)
	hint_label = _label("", 15, Color("#FFF0D6"))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(660, 0)
	hint_row.add_child(hint_label)
	controls_label = _label("左键 画线 · 右键拖动 转镜头 · 右键单击/Space 收笔 · Shift 抬笔 · Z 撤销 · Esc 收回 · R 重来 · Tab 模式 · H 提示 · F1 调试", 11, Color("#CFC2B0"))
	hint_box.add_child(controls_label)

	# ---- toast -------------------------------------------------------------
	var toast_center := CenterContainer.new()
	toast_center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_center.offset_top = 24
	toast_center.offset_bottom = 110
	toast_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_center)
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", _panel_style(Color("#3B332BEF"), Color("#6A5A48"), 16, 12))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_center.add_child(toast_panel)
	toast_label = _label("", 16, Color("#FFF1D8"))
	toast_panel.add_child(toast_label)
	toast_panel.modulate.a = 0.0
	toast_panel.visible = false

	# ---- win card ----------------------------------------------------------
	win_layer = Control.new()
	win_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_layer.visible = false
	root.add_child(win_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.13, 0.10, 0.07, 0.36)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_layer.add_child(center)
	win_card = PanelContainer.new()
	win_card.custom_minimum_size = Vector2(500, 0)
	win_card.add_theme_stylebox_override("panel", _panel_style(PAPER, Color("#E7BE83"), 24, 24))
	win_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(win_card)
	var win_box := VBoxContainer.new()
	win_box.alignment = BoxContainer.ALIGNMENT_CENTER
	win_box.add_theme_constant_override("separation", 8)
	win_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_card.add_child(win_box)
	var glyph := _label("∞", 52, TEAL)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_box.add_child(glyph)
	win_title = _label("结成了！", 32, INK)
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_box.add_child(win_title)
	win_sub = _label("第一结 · 青柱庭", 15, ACCENT)
	win_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_box.add_child(win_sub)
	win_stats = _label("", 15, INK_SOFT)
	win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_box.add_child(win_stats)
	win_footer = _label("回车 · 下一关      R · 重玩本结", 14, MUTED)
	win_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_box.add_child(win_footer)


func set_level(level: Dictionary, index: int, total: int) -> void:
	name_label.text = String(level.get("name", "无名庭"))
	subtitle_label.text = String(level.get("subtitle", ""))
	blurb_label.text = String(level.get("blurb", ""))
	index_label.text = "第 %d / %d 结" % [index + 1, total]
	_clear_objective_rows()
	_hint_cache = ""


func set_objectives(checks: Array) -> void:
	var keys := []
	for c in checks:
		keys.append(String(c.get("key", "")))
	if keys.size() != objective_rows.size():
		_clear_objective_rows()
	for c in checks:
		var key := String(c.get("key", ""))
		var row: Dictionary
		if objective_rows.has(key):
			row = objective_rows[key]
		else:
			row = _make_objective_row(key)
			objective_rows[key] = row
		var ok := bool(c.get("ok", false))
		var optional := bool(c.get("optional", false))
		var icon: Label = row["icon"]
		var name: Label = row["name"]
		var detail: Label = row["detail"]
		icon.text = "✓" if ok else ("·" if optional else "○")
		icon.add_theme_color_override("font_color", TEAL if ok else (PLUM if optional else MUTED))
		var suffix := "  (可选)" if optional else ""
		name.text = String(c.get("text", "")) + suffix
		name.add_theme_color_override("font_color", INK if not optional or ok else INK_SOFT)
		detail.text = String(c.get("detail", ""))
		detail.add_theme_color_override("font_color", TEAL if ok else MUTED)


func _make_objective_row(key: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objectives_box.add_child(row)
	var icon := _label("○", 16, MUTED)
	icon.custom_minimum_size = Vector2(20, 0)
	row.add_child(icon)
	var name := _label("", 15, INK)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var detail := _label("", 13, MUTED)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(detail)
	return {"icon": icon, "name": name, "detail": detail, "row": row}


func _clear_objective_rows() -> void:
	for row in objective_rows.values():
		var node: Node = row["row"]
		if is_instance_valid(node):
			objectives_box.remove_child(node)
			node.queue_free()
	objective_rows.clear()


func refresh(state: Dictionary) -> void:
	var mode := String(state.get("mode", "draw"))
	if mode == "draw":
		mode_label.text = "绘制模式"
		mode_label.add_theme_color_override("font_color", Color("#FFE7BF"))
		mode_sub_label.text = "左键画线 · 右键拖动仍可转镜头"
	else:
		mode_label.text = "镜头模式"
		mode_label.add_theme_color_override("font_color", Color("#BFE6DD"))
		mode_sub_label.text = "左键旋转 · WASD 平移 · 滚轮缩放"
	var steps := int(state.get("steps", 0))
	var length := float(state.get("length", 0.0))
	var time_str := String(state.get("time_str", "00:00"))
	var drawing := bool(state.get("drawing", false))
	stats_label.text = "节点 %d · 绳长 %.1f m · 用时 %s%s" % [steps, length, time_str, "  ·  画线中" if drawing else ""]
	var fps := int(state.get("fps", 0))
	var draws := int(state.get("draw_calls", 0))
	var segs := int(state.get("segments", 0))
	var capture := bool(state.get("capture", false))
	if perf_card != null:
		perf_card.visible = not capture
	fps_label.text = "FPS %d  ·  绘制 %d  ·  段 %d  ·  F1 调试" % [fps, draws, segs]
	var checks: Array = state.get("checks", [])
	if not checks.is_empty():
		set_objectives(checks)
	var hint := String(state.get("hint", ""))
	if hint != _hint_cache:
		_hint_cache = hint
		hint_label.text = hint
	var debug_on := bool(state.get("debug", false))
	debug_panel.visible = debug_on
	if debug_on:
		debug_label.text = String(state.get("debug_text", ""))


func toast(text: String, seconds: float = 2.6) -> void:
	if toast_label == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.text = text
	toast_panel.visible = true
	toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.16)
	_toast_tween.tween_interval(maxf(0.4, seconds))
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func(): toast_panel.visible = false)


func show_win(stats: Dictionary) -> void:
	if win_layer == null:
		return
	win_layer.visible = true
	win_sub.text = String(stats.get("level_line", ""))
	win_stats.text = String(stats.get("stats_line", ""))
	win_footer.text = String(stats.get("footer", "回车 · 下一关      R · 重玩本结"))
	win_title.text = "全部结成！" if bool(stats.get("last", false)) else "结成了！"
	win_layer.modulate.a = 0.0
	win_card.scale = Vector2(0.92, 0.92)
	win_card.pivot_offset = Vector2(250, 150)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(win_layer, "modulate:a", 1.0, 0.25)
	tw.tween_property(win_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_win() -> void:
	if win_layer != null:
		win_layer.visible = false


func set_hint(text: String) -> void:
	if hint_label != null and hint_label.text != text:
		hint_label.text = text


func set_debug_visible(on: bool) -> void:
	if debug_panel != null:
		debug_panel.visible = on


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel_style(bg: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = maxi(6, padding - 4)
	s.content_margin_bottom = maxi(6, padding - 4)
	return s


func _line_style(color: Color) -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = color
	s.thickness = 1
	return s
