class_name HueUI
extends CanvasLayer

# Hand-built 2D interface: layered cream cards, status chips, level picker, win card
# and a debug overlay. Layout is authored at 1280x720 and scaled for 1920x1080.

const PANEL := Color("fff8ec")
const PANEL_SOFT := Color("fbf0e2")
const INK := Color("3b3147")
const INK_SOFT := Color("776b80")
const CREAM := Color("fff8ec")
const DANGER := Color("d65a53")
const GREEN := Color("4c9a6a")
const GOLD := Color("e8b44a")

var game
var font: SystemFont
var font_bold: SystemFont
var theme: Dictionary = {}
var accent := Color("e8796b")
var ui_scale := 1.0
var vw := 1280.0
var vh := 720.0
var root: Control
var hud: Control
var vignette: ColorRect
var debug_on := false
var perf_visible := true

var level_badge: Panel
var badge_label: Label
var brand_label: Label
var level_label: Label
var subtitle_label: Label
var moves_label: Label
var par_label: Label
var goal_progress_label: Label
var goal_chips
var btn_undo: Button
var btn_reset: Button
var btn_select: Button
var hint_panel: Panel
var hint_label: Label
var hint_time := 0.0
var hint_current := ""
var help_label: Label
var fps_label: Label
var toast_panel: Panel
var toast_label: Label
var toast_time := 0.0
var toast_tween: Tween
var hint_tween: Tween

var select_overlay: Control
var select_panel: Panel
var select_cards_root: Control
var select_cards: Array = []
var select_levels: Array = []
var select_progress: Dictionary = {}
var select_current := 0

var win_overlay: Control
var win_panel: Panel
var win_title: Label
var win_name: Label
var win_stats: Label
var win_stars
var win_next: Button
var win_data: Dictionary = {}

var debug_panel


func setup(g) -> void:
	game = g
	layer = 10
	_make_fonts()
	_build_ui()
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_on_viewport_resized)


func _make_fonts() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Source Han Sans SC",
		"Microsoft YaHei", "Droid Sans Fallback", "Arial", "sans-serif",
	])
	font.font_weight = 500
	font.allow_system_fallback = true
	font_bold = SystemFont.new()
	font_bold.font_names = font.font_names
	font_bold.font_weight = 700
	font_bold.allow_system_fallback = true


func _on_viewport_resized() -> void:
	_build_ui()
	if game != null:
		refresh()
		if debug_on:
			debug_panel.visible = true
		if game.overlay == "select":
			open_level_select(game.levels, game.progress, game.level_index)
		elif game.overlay == "win" and not win_data.is_empty():
			show_win(str(win_data["name"]), int(win_data["stars"]), int(win_data["moves"]), int(win_data["par"]), bool(win_data["last"]))


func _build_ui() -> void:
	var vp := get_viewport()
	var vs: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(1280, 720)
	if vs.x <= 1.0 or vs.y <= 1.0:
		vs = Vector2(1280, 720)
	vw = vs.x
	vh = vs.y
	ui_scale = clampf(minf(vw / 1280.0, vh / 720.0), 0.7, 2.6)

	if root != null:
		remove_child(root)
		root.queue_free()
	root = Control.new()
	root.name = "UIRoot"
	root.size = Vector2(vw, vh)
	root.position = Vector2.ZERO
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	vignette = ColorRect.new()
	vignette.color = Color.WHITE
	vignette.position = Vector2.ZERO
	vignette.size = Vector2(vw, vh)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vmat := ShaderMaterial.new()
	vmat.shader = load("res://shaders/vignette.gdshader")
	vignette.material = vmat
	root.add_child(vignette)

	hud = Control.new()
	hud.name = "HUD"
	hud.size = Vector2(vw, vh)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)

	_build_title()
	_build_moves()
	_build_goals()
	_build_help()
	_build_hint()
	_build_toast()
	_build_overlays()
	debug_panel = DebugPanel.new()
	debug_panel.ui = self
	debug_panel.game = game
	debug_panel.position = Vector2(px(22), px(134))
	debug_panel.size = Vector2(px(330), px(392))
	debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_panel.visible = debug_on
	root.add_child(debug_panel)
	_apply_theme()
	refresh()


func px(v: float) -> float:
	return v * ui_scale


func fs(v: float) -> int:
	return maxi(8, int(round(v * ui_scale)))


func sb(bg: Color, border: Color, radius: float, border_width := 1, shadow := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(int(round(border_width * ui_scale)))
	s.set_corner_radius_all(int(round(radius * ui_scale)))
	if shadow > 0.0:
		s.shadow_color = Color(0.12, 0.07, 0.16, 0.16)
		s.shadow_size = int(round(shadow * ui_scale))
		s.shadow_offset = Vector2(0, px(3))
	s.anti_aliasing = true
	return s


func text_to(c: CanvasItem, x: float, y: float, text: String, size: float, color: Color, bold := false, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f: Font = font_bold if bold else font
	var sz := fs(size)
	var baseline := y + sz * 0.82
	c.draw_string(f, Vector2(x, baseline), text, align, width, sz, color)


func label(parent: Node, text: String, x: float, y: float, w: float, h: float, size: float, color: Color, bold := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(px(x), px(y))
	l.size = Vector2(px(w), px(h))
	l.add_theme_font_override("font", font_bold if bold else font)
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func button(parent: Node, text: String, x: float, y: float, w: float, h: float, cb: Callable, size := 14.0, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2(px(x), px(y))
	b.size = Vector2(px(w), px(h))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", fs(size))
	var base := accent if primary else PANEL_SOFT
	var border := accent.darkened(0.12) if primary else Color(INK, 0.12)
	var fg := CREAM if primary else INK
	b.add_theme_stylebox_override("normal", _btn_sb(base, border))
	b.add_theme_stylebox_override("hover", _btn_sb(base.lightened(0.07), accent.darkened(0.05)))
	b.add_theme_stylebox_override("pressed", _btn_sb(base.darkened(0.06), accent.darkened(0.16)))
	b.add_theme_stylebox_override("disabled", _btn_sb(PANEL_SOFT.darkened(0.03), Color(INK, 0.06)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.30))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _btn_sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(maxi(1, int(round(ui_scale))))
	s.set_corner_radius_all(int(round(px(11))))
	s.content_margin_left = px(8)
	s.content_margin_right = px(8)
	s.anti_aliasing = true
	return s


func _build_title() -> void:
	var panel := Panel.new()
	panel.position = Vector2(px(22), px(18))
	panel.size = Vector2(px(382), px(100))
	panel.add_theme_stylebox_override("panel", sb(Color(PANEL, 0.96), Color(INK, 0.08), 18, 1, 5))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(panel)

	brand_label = label(panel, "HueRoll · 滚彩方庭", 18, 8, 344, 22, 13, accent, true)
	level_badge = Panel.new()
	level_badge.position = Vector2(px(18), px(36))
	level_badge.size = Vector2(px(48), px(32))
	level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(level_badge)
	badge_label = label(level_badge, "01", 0, 0, 48, 32, 16, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	level_label = label(panel, "初蘸", 78, 32, 286, 36, 24, INK, true)
	subtitle_label = label(panel, "第一课 · 一笔红", 18, 70, 344, 22, 12.5, INK_SOFT)


func _build_moves() -> void:
	var panel := Panel.new()
	panel.position = Vector2(vw - px(360), px(18))
	panel.size = Vector2(px(338), px(100))
	panel.add_theme_stylebox_override("panel", sb(Color(PANEL, 0.96), Color(INK, 0.08), 18, 1, 5))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(panel)
	label(panel, "步数", 16, 6, 60, 20, 12, INK_SOFT)
	moves_label = label(panel, "00", 16, 20, 90, 38, 28, INK, true)
	par_label = label(panel, "参考 00", 112, 27, 110, 24, 12.5, INK_SOFT)
	btn_undo = button(panel, "撤销 U", 14, 60, 94, 30, func(): game.request_undo(), 13)
	btn_reset = button(panel, "重来 R", 114, 60, 94, 30, func(): game.request_reset(), 13)
	btn_select = button(panel, "关卡 Esc", 214, 60, 110, 30, func(): game.request_level_select(), 13)


func _build_goals() -> void:
	var panel := Panel.new()
	panel.position = Vector2(vw * 0.5 - px(172), px(18))
	panel.size = Vector2(px(344), px(82))
	panel.add_theme_stylebox_override("panel", sb(Color(PANEL, 0.96), Color(INK, 0.08), 18, 1, 5))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(panel)
	label(panel, "目标", 16, 4, 80, 22, 12, INK_SOFT)
	goal_progress_label = label(panel, "0 / 0", 16, 4, 312, 22, 12.5, INK, true, HORIZONTAL_ALIGNMENT_RIGHT)
	goal_chips = GoalChips.new()
	goal_chips.ui = self
	goal_chips.position = Vector2(px(12), px(28))
	goal_chips.size = Vector2(px(320), px(46))
	goal_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(goal_chips)


func _build_help() -> void:
	var panel := Panel.new()
	panel.position = Vector2(px(20), vh - px(52))
	panel.size = Vector2(minf(px(950), vw - px(330)), px(34))
	panel.add_theme_stylebox_override("panel", sb(Color(PANEL, 0.78), Color(INK, 0.05), 17, 1, 0))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(panel)
	help_label = label(panel, "WASD / 方向键 滚动 · 点击相邻格 · Q/E 转视角 · U 撤销 · R 重来 · Esc 关卡 · M 静音", 14, 0, 900, 34, 12, INK_SOFT)

	var dw := vw / ui_scale
	var dh := vh / ui_scale
	button(hud, "↺ Q", dw - 158, dh - 92, 66, 32, func(): game.request_rotate(-1), 13)
	button(hud, "↻ E", dw - 84, dh - 92, 66, 32, func(): game.request_rotate(1), 13)
	fps_label = label(hud, "FPS 60 · 绘制 0", dw - 310, dh - 30, 288, 20, 11.5, INK_SOFT, false, HORIZONTAL_ALIGNMENT_RIGHT)
	fps_label.visible = perf_visible


func _build_hint() -> void:
	hint_panel = Panel.new()
	hint_panel.position = Vector2(vw * 0.5 - px(410), vh - px(116))
	hint_panel.size = Vector2(px(820), px(46))
	hint_panel.add_theme_stylebox_override("panel", sb(Color(PANEL, 0.95), Color(accent, 0.35), 23, 1, 4))
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.visible = false
	hud.add_child(hint_panel)
	hint_label = label(hint_panel, "", 20, 0, 780, 46, 14, INK, false, HORIZONTAL_ALIGNMENT_CENTER)


func _build_toast() -> void:
	toast_panel = Panel.new()
	toast_panel.position = Vector2(vw * 0.5 - px(220), px(112))
	toast_panel.size = Vector2(px(440), px(40))
	toast_panel.add_theme_stylebox_override("panel", sb(Color(PANEL, 0.96), Color(accent, 0.55), 20, 2, 4))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false
	hud.add_child(toast_panel)
	toast_label = label(toast_panel, "", 12, 0, 416, 40, 14, INK, true, HORIZONTAL_ALIGNMENT_CENTER)


func _build_overlays() -> void:
	select_overlay = Control.new()
	select_overlay.size = Vector2(vw, vh)
	select_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_overlay.visible = false
	root.add_child(select_overlay)
	var dim := ColorRect.new()
	dim.color = Color(INK.r, INK.g, INK.b, 0.52)
	dim.position = Vector2.ZERO
	dim.size = Vector2(vw, vh)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	select_overlay.add_child(dim)
	select_panel = Panel.new()
	select_panel.position = Vector2(vw * 0.5 - px(520), vh * 0.5 - px(235))
	select_panel.size = Vector2(px(1040), px(470))
	select_panel.add_theme_stylebox_override("panel", sb(Color(PANEL, 0.98), Color(INK, 0.10), 24, 1, 10))
	select_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	select_overlay.add_child(select_panel)
	label(select_panel, "选择关卡", 44, 20, 400, 44, 28, INK, true)
	label(select_panel, "按 1–6 快速选择 · Esc 返回", 46, 60, 500, 22, 12.5, INK_SOFT)
	button(select_panel, "返回 Esc", 944, 24, 76, 32, func(): game.request_close_level_select(), 12.5)
	select_cards_root = Control.new()
	select_cards_root.position = Vector2(px(44), px(92))
	select_cards_root.size = Vector2(px(952), px(330))
	select_cards_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_panel.add_child(select_cards_root)
	label(select_panel, "所有关卡已解锁 · 最佳步数与星级保存在本地", 44, 428, 800, 22, 11.5, INK_SOFT)

	win_overlay = Control.new()
	win_overlay.size = Vector2(vw, vh)
	win_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_overlay.visible = false
	root.add_child(win_overlay)
	var wdim := ColorRect.new()
	wdim.color = Color(INK.r, INK.g, INK.b, 0.48)
	wdim.position = Vector2.ZERO
	wdim.size = Vector2(vw, vh)
	wdim.mouse_filter = Control.MOUSE_FILTER_STOP
	win_overlay.add_child(wdim)
	win_panel = Panel.new()
	win_panel.position = Vector2(vw * 0.5 - px(280), vh * 0.5 - px(200))
	win_panel.size = Vector2(px(560), px(400))
	win_panel.add_theme_stylebox_override("panel", sb(Color(PANEL, 0.99), Color(INK, 0.10), 26, 1, 12))
	win_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	win_overlay.add_child(win_panel)
	win_title = label(win_panel, "完成！", 0, 24, 560, 50, 34, accent, true, HORIZONTAL_ALIGNMENT_CENTER)
	win_name = label(win_panel, "", 0, 74, 560, 26, 15, INK_SOFT, false, HORIZONTAL_ALIGNMENT_CENTER)
	win_stars = StarRow.new()
	win_stars.ui = self
	win_stars.position = Vector2(px(180), px(108))
	win_stars.size = Vector2(px(200), px(58))
	win_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_panel.add_child(win_stars)
	win_stats = label(win_panel, "", 0, 174, 560, 28, 14, INK, false, HORIZONTAL_ALIGNMENT_CENTER)
	label(win_panel, "目标全部完成 · 颜料已干", 0, 206, 560, 22, 12, INK_SOFT, false, HORIZONTAL_ALIGNMENT_CENTER)
	win_next = button(win_panel, "下一关 Enter", 38, 302, 202, 44, func(): game.request_next_level(), 14, true)
	button(win_panel, "再玩一次 R", 254, 302, 160, 44, func(): game.request_replay(), 13)
	button(win_panel, "关卡", 428, 302, 94, 44, func(): game.request_level_select(), 13)


func _apply_theme() -> void:
	if brand_label == null:
		return
	brand_label.add_theme_color_override("font_color", accent.darkened(0.12))
	if level_badge != null:
		level_badge.add_theme_stylebox_override("panel", sb(accent, accent.darkened(0.16), 10, 1, 2))
	if goal_chips != null:
		goal_chips.queue_redraw()
	if hint_panel != null:
		hint_panel.add_theme_stylebox_override("panel", sb(Color(PANEL, 0.95), Color(accent, 0.35), 23, 1, 4))
	if toast_panel != null:
		toast_panel.add_theme_stylebox_override("panel", sb(Color(PANEL, 0.96), Color(accent, 0.55), 20, 2, 4))


func set_theme(t: Dictionary) -> void:
	theme = t
	accent = HueArt.theme_color(theme, "accent", Color("e8796b"))
	_apply_theme()


# ------------------------------------------------------------------ refresh


func refresh() -> void:
	if game == null or game.sim == null or level_label == null:
		return
	var s = game.sim
	badge_label.text = str(s.level_id)
	level_label.text = str(s.level_name)
	subtitle_label.text = str(s.subtitle)
	moves_label.text = "%02d" % int(s.moves) if s.moves < 100 else str(s.moves)
	par_label.text = "参考 %02d" % int(s.par)
	var p: Array = s.target_progress()
	goal_progress_label.text = "%d / %d" % [int(p[0]), int(p[1])]
	if goal_chips != null:
		goal_chips.sim = s
		goal_chips.queue_redraw()
	if btn_undo != null:
		btn_undo.disabled = s.history.is_empty()
	if debug_panel != null and debug_on:
		debug_panel.queue_redraw()


func set_perf(fps: int, draw_calls: int) -> void:
	if fps_label != null:
		fps_label.text = "FPS %d · 绘制 %d" % [fps, draw_calls]
		fps_label.visible = perf_visible


func set_perf_visible(on: bool) -> void:
	perf_visible = on
	if fps_label != null:
		fps_label.visible = on


# ------------------------------------------------------------------ hint / toast


func show_hint(text: String) -> void:
	if hint_panel == null or text.strip_edges().is_empty():
		return
	hint_current = text
	hint_label.text = "✦  " + text
	hint_panel.visible = true
	hint_panel.modulate = Color(1, 1, 1, 0)
	hint_panel.position.y = vh - px(108)
	hint_time = 8.0
	if hint_tween != null and hint_tween.is_valid():
		hint_tween.kill()
	hint_tween = create_tween()
	hint_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	hint_tween.tween_property(hint_panel, "modulate", Color(1, 1, 1, 1), 0.25)
	hint_tween.parallel().tween_property(hint_panel, "position:y", vh - px(116), 0.25)


func hide_hint() -> void:
	hint_time = 0.0
	if hint_panel == null or not hint_panel.visible:
		return
	if hint_tween != null and hint_tween.is_valid():
		hint_tween.kill()
	hint_tween = create_tween()
	hint_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	hint_tween.tween_property(hint_panel, "modulate", Color(1, 1, 1, 0), 0.2)
	hint_tween.tween_callback(func(): hint_panel.visible = false)


func toast(text: String, color := INK) -> void:
	if toast_panel == null:
		return
	toast_label.text = text
	toast_panel.add_theme_stylebox_override("panel", sb(Color(PANEL, 0.98), Color(color, 0.8), 20, 2, 4))
	toast_panel.visible = true
	toast_panel.modulate = Color(1, 1, 1, 0)
	toast_panel.position.y = px(106)
	toast_time = 1.8
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	toast_tween.tween_property(toast_panel, "modulate", Color(1, 1, 1, 1), 0.18)
	toast_tween.parallel().tween_property(toast_panel, "position:y", px(112), 0.18)


func _hide_toast() -> void:
	if toast_panel == null or not toast_panel.visible:
		return
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	toast_tween.tween_property(toast_panel, "modulate", Color(1, 1, 1, 0), 0.25)
	toast_tween.tween_callback(func(): toast_panel.visible = false)


func _process(delta: float) -> void:
	if hint_time > 0.0:
		hint_time -= delta
		if hint_time <= 0.0:
			hide_hint()
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			_hide_toast()
	if debug_on and debug_panel != null and debug_panel.visible:
		debug_panel.redraw_timer -= delta
		if debug_panel.redraw_timer <= 0.0:
			debug_panel.redraw_timer = 0.15
			debug_panel.queue_redraw()


# ------------------------------------------------------------------ overlays


func open_level_select(levels: Array, progress: Dictionary, current_index: int) -> void:
	select_levels = levels
	select_progress = progress
	select_current = current_index
	if select_overlay == null:
		return
	hide_hint()
	if win_overlay != null:
		win_overlay.visible = false
	_build_cards()
	select_overlay.visible = true
	select_panel.modulate = Color(1, 1, 1, 0)
	select_panel.scale = Vector2(0.97, 0.97)
	select_panel.pivot_offset = select_panel.size * 0.5
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(select_panel, "modulate", Color(1, 1, 1, 1), 0.18)
	tw.parallel().tween_property(select_panel, "scale", Vector2.ONE, 0.18)


func _build_cards() -> void:
	if select_cards_root == null:
		return
	for c in select_cards:
		if is_instance_valid(c):
			c.queue_free()
	select_cards.clear()
	var card_w := 300.0
	var card_h := 150.0
	var gap_x := 26.0
	var gap_y := 20.0
	for i in select_levels.size():
		var row := i / 3
		var col := i % 3
		var card := LevelCard.new()
		card.ui = self
		card.index = i
		card.data = select_levels[i]
		card.entry = select_progress.get(str(select_levels[i].get("id", "")), {})
		card.current = i == select_current
		card.position = Vector2(px(col * (card_w + gap_x)), px(row * (card_h + gap_y)))
		card.size = Vector2(px(card_w), px(card_h))
		select_cards_root.add_child(card)
		select_cards.append(card)


func close_overlays() -> void:
	if select_overlay != null:
		select_overlay.visible = false
	if win_overlay != null:
		win_overlay.visible = false
	win_data = {}


func show_win(level_name: String, stars: int, moves: int, par: int, is_last: bool) -> void:
	win_data = {"name": level_name, "stars": stars, "moves": moves, "par": par, "last": is_last}
	if win_overlay == null:
		return
	hide_hint()
	win_name.text = level_name
	win_stats.text = "步数 %02d · 参考 %02d · 本次 %s" % [moves, par, _stars_text(stars)]
	win_stars.count = stars
	win_stars.queue_redraw()
	win_next.text = "回到关卡 Enter" if is_last else "下一关 Enter"
	win_overlay.visible = true
	win_panel.modulate = Color(1, 1, 1, 0)
	win_panel.scale = Vector2(0.94, 0.94)
	win_panel.pivot_offset = win_panel.size * 0.5
	win_stars.scale = Vector2(0.4, 0.4)
	win_stars.pivot_offset = win_stars.size * 0.5
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(win_panel, "modulate", Color(1, 1, 1, 1), 0.22)
	tw.parallel().tween_property(win_panel, "scale", Vector2.ONE, 0.22)
	tw.tween_property(win_stars, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stars_text(n: int) -> String:
	return "★★★".substr(0, n) + "☆☆☆".substr(0, 3 - n)


func toggle_debug(on: bool) -> void:
	debug_on = on
	if debug_panel != null:
		debug_panel.visible = on
		debug_panel.queue_redraw()


func flash_in() -> void:
	var rect := ColorRect.new()
	rect.color = Color(1, 0.98, 0.92, 0.55)
	rect.position = Vector2.ZERO
	rect.size = Vector2(vw, vh)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 100
	root.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.35)
	tw.tween_callback(rect.queue_free)


func level_target_colors(data: Dictionary) -> Array:
	var out: Array = []
	var board: Array = data.get("board", [])
	for row in board:
		for ch in str(row):
			var c := ""
			match ch:
				"R": c = "red"
				"Y": c = "yellow"
				"B": c = "blue"
				"O": c = "orange"
				"G": c = "green"
				"P": c = "purple"
			if c != "":
				out.append(c)
	return out


# ------------------------------------------------------------------ custom widgets


class GoalChips extends Control:
	const INK := Color("3b3147")
	const INK_SOFT := Color("776b80")
	const GREEN := Color("4c9a6a")
	const DANGER := Color("d65a53")
	var ui
	var sim

	func _draw() -> void:
		if ui == null or sim == null:
			return
		var cells: Array = sim.targets_sorted()
		var n := cells.size()
		if n == 0:
			return
		var w := size.x / float(n)
		for i in n:
			var cell: Vector2i = cells[i]
			var id: String = sim.target_color(cell)
			var c: Color = HueArt.paint_color(id)
			var locked: bool = sim.is_locked(cell)
			var stamped: String = sim.stamp_color(cell)
			var cx: float = i * w + ui.px(12)
			var cy: float = size.y * 0.5
			var r: float = ui.px(10)
			draw_circle(Vector2(cx, cy), r, c)
			draw_arc(Vector2(cx, cy), r, 0.0, TAU, 24, Color(1, 1, 1, 0.55), ui.px(1.4), true)
			if locked:
				var chk := Color(1, 1, 1, 0.95)
				draw_line(Vector2(cx - r * 0.42, cy), Vector2(cx - r * 0.05, cy + r * 0.38), chk, ui.px(2.0), true)
				draw_line(Vector2(cx - r * 0.05, cy + r * 0.38), Vector2(cx + r * 0.48, cy - r * 0.4), chk, ui.px(2.0), true)
			ui.text_to(self, cx + r + ui.px(7), cy - ui.px(9), HueArt.color_name(id), 14, INK, true)
			if locked:
				ui.text_to(self, cx + r + ui.px(7), cy + ui.px(5), "已完成", 9.5, GREEN)
			elif stamped != "blank":
				ui.text_to(self, cx + r + ui.px(7), cy + ui.px(5), "需重盖", 9.5, DANGER)
			else:
				ui.text_to(self, cx + r + ui.px(7), cy + ui.px(5), "待盖章", 9.5, INK_SOFT)


class StarRow extends Control:
	const GOLD := Color("e8b44a")
	var ui
	var count := 0

	func _draw() -> void:
		if ui == null:
			return
		var n := 3
		var r := minf(size.y * 0.42, size.x / 7.4)
		var step := size.x / float(n)
		for i in n:
			var center := Vector2(step * (float(i) + 0.5), size.y * 0.5)
			var pts := HueArt.star_points(center, r, r * 0.44, 5, -PI * 0.5)
			if i < count:
				draw_colored_polygon(pts, GOLD)
			else:
				draw_colored_polygon(pts, Color(GOLD, 0.28))


class LevelCard extends Control:
	const PANEL := Color("fff8ec")
	const INK := Color("3b3147")
	const INK_SOFT := Color("776b80")
	const CREAM := Color("fff8ec")
	const GOLD := Color("e8b44a")
	var ui
	var index := 0
	var data: Dictionary = {}
	var entry: Dictionary = {}
	var current := false
	var hover := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)

	func _on_enter() -> void:
		hover = true
		queue_redraw()

	func _on_exit() -> void:
		hover = false
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if ui != null and ui.game != null:
				if ui.game.sfx:
					ui.game.sfx.play("click")
				ui.game.request_load_level(index)

	func _draw() -> void:
		if ui == null:
			return
		var accent := HueArt.theme_color(data.get("theme", {}), "accent", ui.accent)
		var bg := Color(PANEL, 1.0).lerp(accent.lightened(0.55), 0.20)
		if hover:
			bg = bg.lerp(accent.lightened(0.45), 0.35)
		var border := Color(accent, 0.65) if (hover or current) else Color(INK, 0.10)
		var st: StyleBoxFlat = ui.sb(bg, border, 18, 2 if (hover or current) else 1, 5 if hover else 3)
		draw_style_box(st, Rect2(Vector2.ZERO, size))
		var strip_st: StyleBoxFlat = ui.sb(Color(accent, 0.9), Color(accent, 0.0), 3, 0, 0)
		draw_style_box(strip_st, Rect2(ui.px(16), ui.px(12), size.x - ui.px(32), ui.px(5)))

		var badge_pos := Vector2(ui.px(18), ui.px(22))
		var badge_size := Vector2(ui.px(54), ui.px(54))
		var badge_st: StyleBoxFlat = ui.sb(accent, accent.darkened(0.15), 12, 1, 2)
		draw_style_box(badge_st, Rect2(badge_pos, badge_size))
		ui.text_to(self, badge_pos.x, badge_pos.y + ui.px(10), str(data.get("id", "%02d" % (index + 1))), 22, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER, badge_size.x)

		ui.text_to(self, ui.px(86), ui.px(22), str(data.get("name", "")), 22, INK, true)
		ui.text_to(self, ui.px(86), ui.px(52), str(data.get("subtitle", "")), 12, INK_SOFT)
		var colors: Array = ui.level_target_colors(data)
		for i in mini(colors.size(), 4):
			var c: Color = HueArt.paint_color(colors[i])
			draw_circle(Vector2(ui.px(94 + i * 22), ui.px(84)), ui.px(7), c)
			draw_arc(Vector2(ui.px(94 + i * 22), ui.px(84)), ui.px(7), 0, TAU, 20, Color(1, 1, 1, 0.5), ui.px(1.2), true)
		if colors.is_empty():
			ui.text_to(self, ui.px(94), ui.px(76), "无目标数据", 10, INK_SOFT)

		var stars := int(entry.get("stars", 0))
		var sx: float = ui.px(86)
		for i in 3:
			var pts := HueArt.star_points(Vector2(sx + i * ui.px(22), ui.px(112)), ui.px(8), ui.px(3.5), 5, -PI * 0.5)
			draw_colored_polygon(pts, GOLD if i < stars else Color(GOLD, 0.22))
		var best := int(entry.get("best", 0))
		var best_text := "未完成" if best <= 0 else "最佳 %d 步" % best
		ui.text_to(self, size.x - ui.px(18) - ui.px(150), ui.px(104), best_text, 11, INK_SOFT, false, HORIZONTAL_ALIGNMENT_RIGHT, ui.px(150))
		if current:
			ui.text_to(self, size.x - ui.px(18) - ui.px(60), ui.px(20), "当前", 11, accent.darkened(0.15), true, HORIZONTAL_ALIGNMENT_RIGHT, ui.px(60))


class DebugPanel extends Control:
	const CREAM := Color("fff8ec")
	const INK := Color("3b3147")
	var ui
	var game
	var redraw_timer := 0.0

	func _draw() -> void:
		if ui == null or game == null or game.sim == null:
			return
		var st: StyleBoxFlat = ui.sb(Color(0.12, 0.09, 0.16, 0.88), Color(1, 1, 1, 0.14), 15, 1, 5)
		draw_style_box(st, Rect2(Vector2.ZERO, size))
		ui.text_to(self, ui.px(14), ui.px(10), "调试面板 · F1", 14, CREAM, true)
		var s = game.sim
		var snap: Dictionary = game.debug_snapshot()
		ui.text_to(self, ui.px(14), ui.px(32), "位置 (%d, %d)   步数 %d / 参考 %d" % [s.pos.x, s.pos.y, s.moves, s.par], 10.5, Color(1, 1, 1, 0.86))
		ui.text_to(self, ui.px(14), ui.px(48), "视角 %d° · %s · FPS %d · 绘制 %d" % [
			int(round(rad_to_deg(game.yaw_current))), "通关" if s.won else "进行中",
			int(snap.get("fps", 0)), int(snap.get("draw_calls", 0)),
		], 10.5, Color(1, 1, 1, 0.70))

		var area := Rect2(ui.px(14), ui.px(72), size.x - ui.px(28), ui.px(168))
		draw_rect(area, Color(1, 1, 1, 0.05), true)
		var cw := minf(area.size.x / float(s.width), area.size.y / float(s.height))
		var ox: float = area.position.x + (area.size.x - cw * s.width) * 0.5
		var oy: float = area.position.y + (area.size.y - cw * s.height) * 0.5
		for z in s.height:
			for x in s.width:
				var cell := Vector2i(x, z)
				var r := Rect2(ox + x * cw + 1.0, oy + z * cw + 1.0, cw - 2.0, cw - 2.0)
				if s.props.has(cell):
					draw_rect(r, Color(0.25, 0.21, 0.29, 0.9), true)
				elif s.walkable.has(cell):
					draw_rect(r, Color(0.93, 0.88, 0.81, 0.40), true)
					if s.pools.has(cell):
						draw_circle(r.get_center(), cw * 0.24, HueArt.paint_color(str(s.pools[cell])))
					if s.target_req.has(cell):
						var req := str(s.target_req[cell])
						draw_arc(r.get_center(), cw * 0.30, 0, TAU, 20, HueArt.paint_color(req), maxf(1.0, cw * 0.07), true)
						if s.is_locked(cell):
							draw_circle(r.get_center(), cw * 0.12, HueArt.paint_color(req))
			ui.text_to(self, ox - ui.px(20), oy + z * cw + cw * 0.28, str(z), 7.5, Color(1, 1, 1, 0.35), false, HORIZONTAL_ALIGNMENT_RIGHT, ui.px(16))
		for x in s.width:
			ui.text_to(self, ox + x * cw + cw * 0.5 - ui.px(5), oy - ui.px(12), str(x), 7.5, Color(1, 1, 1, 0.35))
		# cube marker
		var cc := Vector2(ox + (s.pos.x + 0.5) * cw, oy + (s.pos.y + 0.5) * cw)
		var d := cw * 0.30
		var diamond := PackedVector2Array([cc + Vector2(0, -d), cc + Vector2(d, 0), cc + Vector2(0, d), cc + Vector2(-d, 0)])
		draw_colored_polygon(diamond, Color(1, 0.97, 0.9, 0.95))
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0.15, 0.1, 0.18, 0.85), 1.0)

		ui.text_to(self, ui.px(14), ui.px(250), "六面（世界方向）", 11, Color(1, 1, 1, 0.8), true)
		var fkeys := ["up", "down", "north", "south", "east", "west"]
		var flabels := ["上", "下", "北", "南", "东", "西"]
		var box: float = ui.px(36)
		for i in 6:
			var x0: float = ui.px(14) + i * (box + ui.px(6))
			var y0: float = ui.px(268)
			var c := HueArt.paint_color(str(s.faces.get(fkeys[i], "blank")))
			draw_rect(Rect2(x0, y0, box, box), c, true)
			draw_rect(Rect2(x0, y0, box, box), Color(1, 1, 1, 0.35), false, 1.0)
			var ink := CREAM if c.get_luminance() < 0.55 else INK
			ui.text_to(self, x0, y0 + ui.px(8), flabels[i], 11, ink, true, HORIZONTAL_ALIGNMENT_CENTER, box)
		var stamps_lines := PackedStringArray()
		for cell in s.targets_sorted():
			stamps_lines.append("(%d,%d)%s%s" % [cell.x, cell.y, HueArt.color_name(s.target_color(cell)), "✓" if s.is_locked(cell) else "·"])
		ui.text_to(self, ui.px(14), ui.px(318), "目标 " + "  ".join(stamps_lines), 9.5, Color(1, 1, 1, 0.72))
		ui.text_to(self, ui.px(14), ui.px(336), "底面色 %s · 操作 %s" % [
			HueArt.color_name(str(s.faces.get("down", "blank"))),
			"无" if game.overlay == "" else game.overlay,
		], 9.5, Color(1, 1, 1, 0.72))
