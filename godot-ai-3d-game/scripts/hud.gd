class_name RaceHud
extends CanvasLayer

# 原创中文竞速 HUD：圈数/计时/名次/速度表/小地图/倒计时/暂停/结算。
# 所有布局以 1280×720 设计坐标搭建，再按视口尺寸整体缩放；1920×1080 截图因此保持同样构图。

signal restart_requested
signal resume_requested

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const NAVY := Color("#0f2740")
const NAVY_SOFT := Color(0.058, 0.129, 0.216, 0.84)
const NAVY_DEEP := Color(0.035, 0.075, 0.135, 0.93)
const CREAM := Color("#fff1ce")
const CYAN := Color("#5ae8ea")
const MINT := Color("#8ff0c0")
const GOLD := Color("#ffd15d")
const CORAL := Color("#ff8a74")

var world: RaceWorld
var show_fps := true
var canvas: Control
var design: Control
var lap_value: Label
var rank_label: Label
var rank_panel: Panel
var time_value: Label
var fps_label: Label
var countdown_label: Label
var countdown_hint: Label
var boost_label: Label
var objective_label: Label
var minimap: MiniMap
var gauge: SpeedGauge
var fx: HudFX
var pause_layer: Control
var finish_layer: Control
var finish_title: Label
var finish_sub: Label
var finish_badge: Label
var finish_time_value: Label
var finish_speed_value: Label
var finish_boost_value: Label
var finish_place_label: Label
var finish_button: Button

var _font_regular: SystemFont
var _font_bold: SystemFont
var _last_viewport := Vector2(-1, -1)
var _last_state := -1
var _last_count := -1
var _count_pulse := 0.0
var _finish_seen := false


func setup(world_ref: RaceWorld) -> void:
	world = world_ref
	_font_regular = SystemFont.new()
	_font_regular.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
		"Source Han Sans SC", "Microsoft YaHei", "Arial"
	])
	_font_regular.font_weight = 500
	_font_bold = SystemFont.new()
	_font_bold.font_names = _font_regular.font_names
	_font_bold.font_weight = 800
	_build_ui()
	_fit_ui()
	visible = true


func _process(delta: float) -> void:
	if world == null:
		return
	_fit_ui()
	_update_top()
	_update_countdown(delta)
	_update_overlays()
	_update_effects(delta)
	if minimap != null:
		minimap.queue_redraw()
	if gauge != null:
		gauge.queue_redraw()


# ── 构建 ───────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	canvas = Control.new()
	canvas.name = "HudCanvas"
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)

	design = Control.new()
	design.name = "Design"
	design.size = DESIGN_SIZE
	design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(design)

	_build_lap_panel()
	_build_title_panel()
	_build_time_panel()
	_build_map_and_gauge()
	_build_controls()
	_build_countdown()
	_build_pause_overlay()
	_build_finish_overlay()

	fx = HudFX.new()
	fx.name = "SpeedAndConfettiFX"
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.z_index = 60
	design.add_child(fx)


func _build_lap_panel() -> void:
	var p := _panel(design, Vector2(24, 20), Vector2(170, 98), NAVY_SOFT, Color(CYAN, 0.72), 16)
	_label_rect(p, "LAP  ·  圈 数", 11, CYAN, Rect2(14, 7, 142, 20), HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, true)
	lap_value = _label_rect(p, "1 / 1", 28, CREAM, Rect2(12, 25, 146, 42), HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, true, 4)
	_label_rect(p, "青岚杯 · 一 圈 制", 10, Color(CREAM, 0.72), Rect2(14, 72, 142, 18), HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, false)

	rank_panel = _panel(design, Vector2(24, 126), Vector2(170, 40), NAVY_DEEP, Color(GOLD, 0.66), 12)
	rank_label = _label_rect(rank_panel, "等待发车", 14, GOLD, Rect2(0, 0, 170, 40), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true)


func _build_title_panel() -> void:
	var p := _panel(design, Vector2(476, 18), Vector2(328, 64), NAVY_SOFT, Color(CREAM, 0.36), 18)
	_label_rect(p, "风 车 原 野", 22, CREAM, Rect2(0, 4, 328, 34), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true, 4)
	_label_rect(p, "青 岚 杯  ·  W I N D M I L L   C U P", 9, CYAN, Rect2(0, 38, 328, 20), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true)
	objective_label = _label_rect(design, "目标：跑完 1 圈，抢下第一", 12, GOLD, Rect2(430, 86, 420, 24), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true, 3)


func _build_time_panel() -> void:
	var p := _panel(design, Vector2(1086, 20), Vector2(170, 98), NAVY_SOFT, Color(CYAN, 0.72), 16)
	_label_rect(p, "TIME  ·  计 时", 11, CYAN, Rect2(14, 7, 142, 20), HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, true)
	time_value = _label_rect(p, "00:00.00", 21, CREAM, Rect2(12, 27, 150, 38), HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, true, 4)
	fps_label = _label_rect(p, "FPS --", 10, MINT, Rect2(14, 70, 142, 18), HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, false)


func _build_map_and_gauge() -> void:
	minimap = MiniMap.new()
	minimap.name = "MiniMap"
	minimap.position = Vector2(24, 518)
	minimap.size = Vector2(232, 178)
	minimap.world = world
	minimap.font = _font_bold
	design.add_child(minimap)

	gauge = SpeedGauge.new()
	gauge.name = "SpeedGauge"
	gauge.position = Vector2(1058, 506)
	gauge.size = Vector2(198, 198)
	gauge.world = world
	gauge.font = _font_bold
	gauge.font_regular = _font_regular
	design.add_child(gauge)


func _build_controls() -> void:
	var p := _panel(design, Vector2(358, 646), Vector2(566, 54), NAVY_DEEP, Color(CREAM, 0.26), 16)
	_label_rect(p, "W / ↑  油门    S / ↓  刹车    A D / ← →  转向    ESC / P  暂停    R  重开", 12, Color(CREAM, 0.94), Rect2(0, 5, 566, 20), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true)
	_label_rect(p, "驶过发光箭头加速 · 冲线第一即夺冠", 10, CYAN, Rect2(0, 26, 566, 18), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)


func _build_countdown() -> void:
	countdown_label = _label_rect(design, "", 134, CREAM, Rect2(340, 198, 600, 190), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true, 28)
	countdown_label.pivot_offset = Vector2(300, 95)
	countdown_label.visible = false
	countdown_hint = _label_rect(design, "W / ↑ 起步 · A D 转向 · 过弯前松一点油门", 14, Color(CREAM, 0.94), Rect2(340, 392, 600, 30), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true, 4)
	countdown_hint.visible = false
	boost_label = _label_rect(design, "↯  加 速 !", 44, CYAN, Rect2(340, 142, 600, 70), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true, 9)
	boost_label.pivot_offset = Vector2(300, 35)
	boost_label.visible = false


func _build_pause_overlay() -> void:
	pause_layer = Control.new()
	pause_layer.name = "PauseOverlay"
	pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_layer.z_index = 30
	pause_layer.visible = false
	design.add_child(pause_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.055, 0.095, 0.64)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_layer.add_child(dim)

	var p := _panel(pause_layer, Vector2(370, 178), Vector2(540, 368), NAVY_DEEP, Color(CYAN, 0.8), 24)
	var accent := ColorRect.new()
	accent.color = CYAN
	accent.position = Vector2(90, 0)
	accent.size = Vector2(360, 4)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(accent)
	_label_rect(p, "比 赛 暂 停", 38, CREAM, Rect2(0, 32, 540, 56), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true, 6)
	_label_rect(p, "风车还在转，你的圈速停在原处。", 14, Color(CREAM, 0.74), Rect2(0, 90, 540, 24), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)
	var resume := _button(p, "继续比赛     ESC", Vector2(120, 146), Vector2(300, 56), CYAN)
	resume.pressed.connect(func() -> void: resume_requested.emit())
	var restart := _button(p, "重新开始     R", Vector2(120, 216), Vector2(300, 52), GOLD)
	restart.pressed.connect(func() -> void: restart_requested.emit())
	_label_rect(p, "暂停时不会继续计时，也不会被对手拉开。", 11, Color(CREAM, 0.48), Rect2(0, 302, 540, 20), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)


func _build_finish_overlay() -> void:
	finish_layer = Control.new()
	finish_layer.name = "FinishOverlay"
	finish_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	finish_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	finish_layer.z_index = 32
	finish_layer.visible = false
	design.add_child(finish_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.09, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	finish_layer.add_child(dim)

	var p := _panel(finish_layer, Vector2(310, 142), Vector2(660, 444), NAVY_DEEP, Color(GOLD, 0.82), 24)
	finish_button = _button(p, "再 跑 一 局     R", Vector2(180, 354), Vector2(300, 56), GOLD)
	finish_button.pressed.connect(func() -> void: restart_requested.emit())
	finish_badge = _label_rect(p, "★", 42, GOLD, Rect2(0, 20, 660, 46), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true, 8)
	finish_title = _label_rect(p, "青岚杯冠军", 42, CREAM, Rect2(0, 62, 660, 62), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true, 8)
	finish_sub = _label_rect(p, "", 14, Color(CREAM, 0.76), Rect2(40, 122, 580, 26), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)
	finish_place_label = _label_rect(p, "", 13, CYAN, Rect2(30, 150, 600, 22), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true)
	# 三项数据
	var boxes := [
		{"pos": Vector2(34, 188), "caption": "完赛用时", "key": "time"},
		{"pos": Vector2(240, 188), "caption": "最高时速", "key": "speed"},
		{"pos": Vector2(446, 188), "caption": "冲刺次数", "key": "boost"},
	]
	for box in boxes:
		var sub := _panel(p, box["pos"], Vector2(180, 130), Color(0.06, 0.14, 0.22, 0.92), Color(CYAN, 0.28), 14)
		_label_rect(sub, box["caption"], 12, Color(CREAM, 0.68), Rect2(0, 12, 180, 24), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)
		match box["key"]:
			"time":
				finish_time_value = _label_rect(sub, "00:00.00", 24, CREAM, Rect2(0, 42, 180, 48), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true, 4)
			"speed":
				finish_speed_value = _label_rect(sub, "0 km/h", 26, GOLD, Rect2(0, 42, 180, 48), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true, 4)
			"boost":
				finish_boost_value = _label_rect(sub, "0 次", 26, CYAN, Rect2(0, 42, 180, 48), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true, 4)
	_label_rect(p, "按 R 立即重开 · 冲线照片会留在风车原野", 11, Color(CREAM, 0.44), Rect2(0, 414, 660, 20), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)


# ── 每帧数据 ───────────────────────────────────────────────────────────────
func _update_top() -> void:
	if lap_value == null:
		return
	lap_value.text = "1 / 1"
	var state := world.state
	if state == RaceWorld.RaceState.COUNTDOWN:
		rank_label.text = "等待发车"
		rank_label.add_theme_color_override("font_color", GOLD)
	elif state == RaceWorld.RaceState.FINISHED:
		rank_label.text = "最终 · 第 %d 名" % world.finish_place
		rank_label.add_theme_color_override("font_color", GOLD if world.finish_won else CORAL)
	else:
		var place := world.current_places()
		rank_label.text = "名次  %d / 3" % place
		rank_label.add_theme_color_override("font_color", GOLD if place == 1 else (CREAM if place == 2 else CORAL))
	time_value.text = world.finish_time_text() if state == RaceWorld.RaceState.FINISHED else world.time_text()
	objective_label.visible = state == RaceWorld.RaceState.RACING
	fps_label.visible = show_fps
	if show_fps:
		var fps := Engine.get_frames_per_second()
		fps_label.text = "FPS %d" % fps
		fps_label.add_theme_color_override("font_color", MINT if fps >= 50 else (GOLD if fps >= 30 else CORAL))
	if gauge != null:
		gauge.speed_kmh = world.player.speed_kmh() if world.player != null else 0.0
		gauge.boost = world.player.boost_timer > 0.0 if world.player != null else false


func _update_countdown(_delta: float) -> void:
	if world.state == RaceWorld.RaceState.COUNTDOWN:
		var number := world.countdown_number()
		if number != _last_count:
			_last_count = number
			_count_pulse = 1.0
			countdown_label.text = str(maxi(number, 1))
			countdown_label.add_theme_color_override("font_color", CREAM)
		countdown_label.visible = true
		countdown_label.scale = Vector2.ONE * lerpf(1.0, 1.28, _count_pulse)
		countdown_hint.visible = true
		boost_label.visible = false
		if _count_pulse > 0.0:
			_count_pulse = maxf(0.0, _count_pulse - 0.055)
	elif world.go_flash > 0.0:
		countdown_label.text = "出发！"
		countdown_label.add_theme_color_override("font_color", CYAN)
		countdown_label.visible = true
		countdown_label.scale = Vector2.ONE * lerpf(1.0, 1.14, clampf(world.go_flash / 0.85, 0.0, 1.0))
		countdown_hint.visible = false
		_last_count = -1
	else:
		countdown_label.visible = false
		countdown_hint.visible = false
	if world.state == RaceWorld.RaceState.RACING and world.player != null and (world.player.boost_timer > 0.0 or world.boost_flash > 0.0):
		boost_label.visible = true
		boost_label.modulate.a = clampf(0.5 + world.player.boost_timer * 0.7 + world.boost_flash * 0.5, 0.0, 1.0)
		boost_label.scale = Vector2.ONE * (1.0 + sin(world._anim_time * 13.0) * 0.035)
	else:
		boost_label.visible = false


func _update_overlays() -> void:
	var state := world.state
	if state != _last_state:
		if state == RaceWorld.RaceState.FINISHED and not _finish_seen:
			_show_finish()
		_last_state = state
	pause_layer.visible = state == RaceWorld.RaceState.PAUSED
	finish_layer.visible = state == RaceWorld.RaceState.FINISHED
	if state != RaceWorld.RaceState.FINISHED and _finish_seen:
		_finish_seen = false
		fx.set_finish(false)


func _show_finish() -> void:
	_finish_seen = true
	var place := world.finish_place
	var won := world.finish_won
	finish_badge.text = "★" if won else ("●" if place == 2 else "◆")
	finish_badge.add_theme_color_override("font_color", GOLD if won else CYAN)
	finish_title.add_theme_color_override("font_color", GOLD if won else CREAM)
	finish_title.text = "青岚杯冠军" if won else ("第 %d 名 · 差一点" % place)
	finish_sub.text = "你把两名对手甩在风车后面。风车原野记住了这一圈。" if won else "内线还在，下一圈再来把它抢回来。"
	finish_place_label.text = "FINAL  ·  第 %d 名 / 3" % place
	finish_time_value.text = world.finish_time_text()
	finish_speed_value.text = "%d km/h" % int(round(world.finish_best_kmh))
	finish_boost_value.text = "%d 次" % world.finish_boost_count
	finish_button.text = "再 跑 一 局     R"
	fx.set_finish(won)
	finish_layer.visible = true


func _update_effects(_delta: float) -> void:
	if fx != null:
		fx.boost = world.boost_flash
		fx.bump = world.bump_flash
		fx.racing = world.state == RaceWorld.RaceState.RACING
		fx.queue_redraw()


# ── 缩放 ───────────────────────────────────────────────────────────────────
func _fit_ui() -> void:
	if canvas == null or design == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp == _last_viewport:
		return
	_last_viewport = vp
	var scale := minf(vp.x / DESIGN_SIZE.x, vp.y / DESIGN_SIZE.y)
	design.scale = Vector2(scale, scale)
	design.position = (vp - DESIGN_SIZE * scale) * 0.5


# ── 小工具 ─────────────────────────────────────────────────────────────────
func _style(bg: Color, border: Color, border_width: int, radius: int, shadow := true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	if shadow:
		style.shadow_color = Color(0.01, 0.04, 0.08, 0.28)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 4)
	return style


func _panel(parent: Control, pos: Vector2, size: Vector2, bg: Color, border: Color, radius: int) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(bg, border, 2, radius))
	parent.add_child(p)
	return p


func _label_rect(parent: Control, text: String, font_size: int, color: Color, rect: Rect2, align: HorizontalAlignment, valign: VerticalAlignment, bold: bool, outline := 3) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.vertical_alignment = valign
	label.add_theme_font_override("font", _font_bold if bold else _font_regular)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.015, 0.045, 0.075, 0.9))
	label.add_theme_constant_override("outline_size", outline)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, pos: Vector2, size: Vector2, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", _font_bold)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", NAVY)
	b.add_theme_color_override("font_hover_color", NAVY)
	b.add_theme_color_override("font_pressed_color", NAVY)
	b.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.18))
	b.add_theme_constant_override("outline_size", 0)
	var normal := _style(accent, Color(1, 1, 1, 0.35), 2, 14, false)
	var hover := _style(accent.lightened(0.12), Color(1, 1, 1, 0.80), 2, 14, false)
	var pressed := _style(accent.darkened(0.12), Color(1, 1, 1, 0.55), 2, 14, false)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	parent.add_child(b)
	return b


# ── 自定义控件：小地图 / 速度表 / 特效 ─────────────────────────────────────
class MiniMap extends Control:

	var world: RaceWorld
	var font: Font
	var _style: StyleBoxFlat

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style = StyleBoxFlat.new()
		_style.bg_color = Color(0.035, 0.085, 0.135, 0.82)
		_style.border_color = Color(0.36, 0.90, 0.90, 0.45)
		_style.set_border_width_all(2)
		_style.corner_radius_top_left = 16
		_style.corner_radius_top_right = 16
		_style.corner_radius_bottom_left = 16
		_style.corner_radius_bottom_right = 16
		_style.shadow_color = Color(0.0, 0.03, 0.06, 0.24)
		_style.shadow_size = 6
		_style.shadow_offset = Vector2(0, 3)

	func _draw() -> void:
		if world == null or world.track == null:
			return
		draw_style_box(_style, Rect2(Vector2.ZERO, size))
		if font != null:
			draw_string(font, Vector2(16, 24), "赛 道", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8ff0c0"))
			draw_string(font, Vector2(94, 24), "MINIMAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.94, 0.79, 0.48))
		var rect := Rect2(16, 34, size.x - 32, size.y - 46)
		var min_x := INF
		var max_x := -INF
		var min_z := INF
		var max_z := -INF
		for point in world.track.samples:
			min_x = minf(min_x, point.x)
			max_x = maxf(max_x, point.x)
			min_z = minf(min_z, point.z)
			max_z = maxf(max_z, point.z)
		var span := maxf(max_x - min_x, max_z - min_z)
		if span <= 0.01:
			return
		var scale := minf(rect.size.x / span, rect.size.y / span) * 0.88
		var center := Vector2((min_x + max_x) * 0.5, (min_z + max_z) * 0.5)
		var map_center := rect.get_center()
		var points := PackedVector2Array()
		for point in world.track.samples:
			points.append(map_center + Vector2(point.x - center.x, point.z - center.y) * scale)
		if points.size() > 2:
			points.append(points[0])
			draw_polyline(points, Color(0.015, 0.05, 0.08, 0.85), 9.0, true)
			draw_polyline(points, Color(0.70, 0.87, 0.83, 0.78), 5.0, true)
		# 起跑线
		var start := world.track.point_at(0.0)
		var start_p := map_center + Vector2(start.x - center.x, start.z - center.y) * scale
		var tangent := world.track.tangent_at(0.0)
		var normal := Vector2(-tangent.z, tangent.x) * 8.0
		draw_line(start_p - normal, start_p + normal, Color(1.0, 0.94, 0.74, 0.9), 2.0)
		# 对手与玩家
		for kart in world.rivals:
			var kp: Vector3 = kart.global_position
			var mp := map_center + Vector2(kp.x - center.x, kp.z - center.y) * scale
			draw_circle(mp, 5.0, Color(0.02, 0.06, 0.10, 0.9))
			draw_circle(mp, 3.6, kart.visual.body_color if kart.visual != null else Color("#ff8a74"))
		if world.player != null:
			var pp3: Vector3 = world.player.global_position
			var pp := map_center + Vector2(pp3.x - center.x, pp3.z - center.y) * scale
			var dir := Vector2(-sin(world.player.yaw), -cos(world.player.yaw))
			var side := Vector2(-dir.y, dir.x)
			var tri := PackedVector2Array([
				pp + dir * 8.5,
				pp - dir * 5.0 + side * 5.2,
				pp - dir * 5.0 - side * 5.2,
			])
			draw_colored_polygon(tri, Color("#5af3ef"))
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.02, 0.10, 0.16, 0.9), 1.5, true)


class SpeedGauge extends Control:

	var world: RaceWorld
	var font: Font
	var font_regular: Font
	var speed_kmh := 0.0
	var boost := false
	var _style: StyleBoxFlat

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style = StyleBoxFlat.new()
		_style.bg_color = Color(0.035, 0.085, 0.135, 0.86)
		_style.border_color = Color(0.36, 0.90, 0.90, 0.40)
		_style.set_border_width_all(2)
		_style.corner_radius_top_left = 99
		_style.corner_radius_top_right = 99
		_style.corner_radius_bottom_left = 99
		_style.corner_radius_bottom_right = 99
		_style.shadow_color = Color(0.0, 0.03, 0.06, 0.28)
		_style.shadow_size = 8
		_style.shadow_offset = Vector2(0, 4)

	func _draw() -> void:
		draw_style_box(_style, Rect2(Vector2.ZERO, size))
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 18.0
		var start_angle := deg_to_rad(135.0)
		var arc_span := deg_to_rad(270.0)
		draw_arc(center, radius, start_angle, start_angle + arc_span, 64, Color(0.24, 0.48, 0.57, 0.34), 11.0, true)
		var ratio := clampf(speed_kmh / 130.0, 0.0, 1.0)
		var speed_color := Color("#5af3ef") if not boost else Color("#d8ffff")
		if ratio > 0.015:
			draw_arc(center, radius, start_angle, start_angle + arc_span * ratio, 64, speed_color, 11.0, true)
		for i in 7:
			var angle := start_angle + arc_span * float(i) / 6.0
			var p0 := center + Vector2(cos(angle), sin(angle)) * (radius - 13.0)
			var p1 := center + Vector2(cos(angle), sin(angle)) * (radius - 6.0)
			draw_line(p0, p1, Color(1, 0.95, 0.82, 0.38), 1.5)
		var needle_angle := start_angle + arc_span * ratio
		var needle_dir := Vector2(cos(needle_angle), sin(needle_angle))
		draw_line(center, center + needle_dir * (radius - 21.0), speed_color, 4.0, true)
		draw_circle(center, 7.0, Color(0.03, 0.10, 0.16, 0.95))
		draw_circle(center, 3.4, speed_color)
		if font != null:
			var text := "%d" % int(round(speed_kmh))
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
			draw_string(font, center + Vector2(-text_size.x * 0.5, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("#fff1ce"))
			var unit_size := font_regular.get_string_size("km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
			draw_string(font_regular, center + Vector2(-unit_size.x * 0.5, 36), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.95, 0.82, 0.66))
			var label := "BOOST" if boost else "SPEED"
			var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
			draw_string(font, Vector2(center.x - label_size.x * 0.5, center.y - 54), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.56, 0.94, 0.94, 0.8))


class HudFX extends Control:

	var boost := 0.0
	var bump := 0.0
	var racing := false
	var finish_win := false
	var time := 0.0
	var _confetti: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 72:
			_confetti.append({
				"x": randf_range(0.0, 1280.0),
				"phase": randf_range(0.0, 720.0),
				"speed": randf_range(130.0, 250.0),
				"size": randf_range(5.0, 11.0),
				"sway": randf_range(0.6, 2.2),
				"color": [Color("#ffd15d"), Color("#5af3ef"), Color("#ff8a74"), Color("#8ff0c0"), Color("#fff1ce")][i % 5],
			})

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func set_finish(won: bool) -> void:
		finish_win = won
		time = 0.0

	func _draw() -> void:
		if racing and boost > 0.0:
			for i in 16:
				var y := 80.0 + fmod(float(i) * 97.0 + time * 330.0, 520.0)
				var length := 50.0 + fmod(float(i) * 37.0, 150.0)
				var alpha := boost * (0.07 + float(i % 3) * 0.025)
				draw_line(Vector2(0, y), Vector2(length, y + 18), Color(0.44, 0.97, 0.98, alpha), 2.0, true)
				draw_line(Vector2(1280, y + 42), Vector2(1280 - length, y + 58), Color(0.44, 0.97, 0.98, alpha), 2.0, true)
		if bump > 0.0:
			var tint := Color(1.0, 0.30, 0.22, bump * 0.15)
			draw_rect(Rect2(0, 0, 1280, 10), tint)
			draw_rect(Rect2(0, 710, 1280, 10), tint)
			draw_rect(Rect2(0, 0, 10, 720), tint)
			draw_rect(Rect2(1270, 0, 10, 720), tint)
		if finish_win:
			for item in _confetti:
				var x: float = item["x"] + sin(time * item["sway"] + item["phase"]) * 24.0
				var y := fmod(item["phase"] + time * item["speed"], 880.0) - 100.0
				var s: float = item["size"]
				draw_set_transform(Vector2(x, y), time * 2.4 + item["phase"], Vector2.ONE)
				draw_rect(Rect2(-s * 0.5, -s * 0.25, s, s * 0.5), item["color"])
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
