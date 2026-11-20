extends Control
class_name UltimateHUD

## Silver-gold HUD drawn with vector primitives. No external UI assets.

var main: Node
var player: WukongPlayer
var dummy: StoneSentinel
var font: SystemFont
var show_tutorial := true
var tutorial_muted := false
var flash_red := 0.0

const SILVER := Color(0.86, 0.91, 1.0)
const DIM := Color(0.60, 0.68, 0.84)
const GOLD := Color(0.95, 0.78, 0.42)
const BLUE := Color(0.45, 0.78, 1.0)
const RED := Color(1.0, 0.38, 0.30)
const AMBER := Color(1.0, 0.66, 0.32)
const PANEL := Color(0.012, 0.020, 0.038, 0.70)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
		"Microsoft YaHei", "Arial Unicode MS", "sans-serif",
	])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	flash_red = maxf(0.0, flash_red - delta * 2.2)
	if main != null:
		show_tutorial = main.elapsed < 9.0 and not main.victory and not main.defeat and not tutorial_muted
	queue_redraw()


func _draw() -> void:
	if main == null or player == null or dummy == null:
		return
	var vp := get_viewport_rect().size
	if vp.x < 10.0:
		vp = Vector2(1280, 720)
	_draw_vignette(vp)
	_draw_player_panel()
	_draw_dummy_panel(vp)
	_draw_combo(vp)
	_draw_hints(vp)
	if main.warning_timer > 0.0:
		_draw_warning(vp)
	if show_tutorial:
		_draw_tutorial(vp)
	if main.victory:
		_draw_victory(vp)
	elif main.defeat:
		_draw_defeat(vp)
	if flash_red > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.9, 0.06, 0.03, flash_red * 0.22), true)
	draw_string(font, Vector2(vp.x - 218, vp.y - 16), "ORIGINAL · PROCEDURAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.65, 0.85, 0.55))


func _draw_vignette(vp: Vector2) -> void:
	var edge := Color(0.0, 0.0, 0.0, 0.22)
	draw_rect(Rect2(0, 0, vp.x, 40), edge, true)
	draw_rect(Rect2(0, vp.y - 90, vp.x, 90), Color(0, 0, 0, 0.25), true)
	draw_rect(Rect2(0, 0, 24, vp.y), Color(0, 0, 0, 0.10), true)
	draw_rect(Rect2(vp.x - 24, 0, 24, vp.y), Color(0, 0, 0, 0.10), true)


func _draw_player_panel() -> void:
	var r := Rect2(26, 24, 366, 142)
	_panel(r, 0.72)
	draw_line(Vector2(r.position.x, r.position.y), Vector2(r.position.x + 150, r.position.y), GOLD, 2.0)
	draw_line(Vector2(r.end.x - 60, r.end.y), Vector2(r.end.x, r.end.y), BLUE, 2.0)
	draw_string(font, Vector2(r.position.x + 18, r.position.y + 30), "齐天大圣 · 极意", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, SILVER)
	draw_string(font, Vector2(r.position.x + 19, r.position.y + 47), "ULTIMATE  ·  SILVER MANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.70, 0.92, 0.9))
	var label_w := 42.0
	var bar_x := r.position.x + 62
	var bar_w := r.size.x - 130
	var hp_y := r.position.y + 66
	var en_y := r.position.y + 96
	var ch_y := r.position.y + 121
	draw_string(font, Vector2(r.position.x + 18, hp_y + 11), "气血", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	_bar(Rect2(bar_x, hp_y, bar_w, 13), float(player.hp) / 100.0,
		Color(0.92, 0.24, 0.18), Color(0.35, 0.06, 0.05, 0.65))
	draw_string(font, Vector2(r.end.x - 56, hp_y + 11), "%d" % player.hp, HORIZONTAL_ALIGNMENT_RIGHT, 40, 13, SILVER)
	draw_string(font, Vector2(r.position.x + 18, en_y + 10), "气", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	_bar(Rect2(bar_x, en_y, bar_w, 10), player.energy / 100.0,
		Color(0.30, 0.72, 1.0), Color(0.05, 0.12, 0.25, 0.7))
	draw_string(font, Vector2(r.end.x - 62, en_y + 10), "%d" % int(player.energy), HORIZONTAL_ALIGNMENT_RIGHT, 46, 12, BLUE)
	draw_string(font, Vector2(r.position.x + 18, ch_y + 8), "蓄力", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
	var charge_ratio := player.charge if player.charging else 0.0
	_bar(Rect2(bar_x, ch_y, bar_w, 6), charge_ratio,
		Color(1.0, 0.86, 0.48), Color(0.16, 0.13, 0.06, 0.6), 1.0)
	if player.charging:
		draw_string(font, Vector2(r.end.x - 58, ch_y + 8), "%d%%" % int(player.charge * 100.0),
			HORIZONTAL_ALIGNMENT_RIGHT, 42, 11, GOLD)


func _draw_dummy_panel(vp: Vector2) -> void:
	var w := 430.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, 20, w, 72)
	_panel(r, 0.64)
	draw_line(Vector2(r.position.x + 40, r.position.y), Vector2(r.end.x - 40, r.position.y), AMBER, 2.0)
	draw_string(font, Vector2(r.position.x, r.position.y + 26), "石傀 · 训练体", HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(0.98, 0.88, 0.70))
	_bar(Rect2(r.position.x + 28, r.position.y + 38, w - 56, 13),
		float(dummy.hp) / float(dummy.max_hp), Color(0.96, 0.48, 0.16),
		Color(0.30, 0.10, 0.03, 0.7))
	draw_string(font, Vector2(r.position.x, r.position.y + 66), "%d / %d" % [dummy.hp, dummy.max_hp],
		HORIZONTAL_ALIGNMENT_CENTER, w, 11, Color(0.9, 0.75, 0.55))
	# target brackets
	var cx := vp.x * 0.5
	draw_line(Vector2(cx - w * 0.5 - 12, r.position.y + 42), Vector2(cx - w * 0.5 - 12, r.position.y + 28), AMBER, 1.5)
	draw_line(Vector2(cx - w * 0.5 - 12, r.position.y + 28), Vector2(cx - w * 0.5 + 2, r.position.y + 28), AMBER, 1.5)
	draw_line(Vector2(cx + w * 0.5 + 12, r.position.y + 42), Vector2(cx + w * 0.5 + 12, r.position.y + 28), AMBER, 1.5)
	draw_line(Vector2(cx + w * 0.5 + 12, r.position.y + 28), Vector2(cx + w * 0.5 - 2, r.position.y + 28), AMBER, 1.5)


func _draw_combo(vp: Vector2) -> void:
	if main.combo <= 0:
		return
	var t := clampf(main.combo_timer / 2.4, 0.0, 1.0)
	var center := Vector2(vp.x - 142, 164)
	var scale_pulse := 1.0 + 0.05 * sin(Time.get_ticks_msec() * 0.012)
	draw_circle(center, 44.0 * scale_pulse, Color(0.02, 0.06, 0.12, 0.65))
	draw_arc(center, 44.0, -PI * 0.5, -PI * 0.5 + TAU * t, 40, GOLD, 2.5, true)
	draw_arc(center, 38.0, -PI * 0.5, -PI * 0.5 + TAU * t, 40, Color(0.45, 0.78, 1.0, 0.55), 1.2, true)
	var num_size := 36 + mini(main.combo, 8) * 2
	var text := "×%d" % main.combo
	draw_string(font, center + Vector2(-40, 10), text, HORIZONTAL_ALIGNMENT_CENTER, 80, num_size, GOLD)
	draw_string(font, center + Vector2(-40, 34), "连击", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(0.85, 0.80, 0.65))


func _draw_hints(vp: Vector2) -> void:
	var w := 770.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y - 56, w, 34)
	_panel(r, 0.48)
	var text := "WASD  移动    ·    长按空格  蓄力 / 松开  气功波    ·    鼠标拖拽  环绕    ·    滚轮  缩放    ·    R  重置"
	draw_string(font, Vector2(r.position.x, r.position.y + 22), text, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(0.80, 0.86, 0.98, 0.85))


func _draw_warning(vp: Vector2) -> void:
	var a := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.022)
	var w := 400.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, 104, w, 32)
	draw_rect(r, Color(0.36, 0.06, 0.02, 0.65 * a), true)
	draw_rect(r, Color(1.0, 0.40, 0.16, 0.8), false, 1.5)
	draw_string(font, Vector2(r.position.x, r.position.y + 22), "石傀蓄力 · 离开红圈", HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(1.0, 0.80, 0.55))


func _draw_tutorial(vp: Vector2) -> void:
	var a := clampf((9.0 - main.elapsed) / 1.4, 0.0, 1.0)
	var w := 520.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y - 132, w, 52)
	draw_rect(r, Color(0.02, 0.04, 0.08, 0.62 * a), true)
	draw_line(Vector2(r.position.x + 20, r.position.y), Vector2(r.end.x - 20, r.position.y), Color(0.55, 0.78, 1.0, a), 1.5)
	draw_string(font, Vector2(r.position.x, r.position.y + 25), "长按 空格 蓄力 · 松开放出气功波", HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(0.92, 0.95, 1.0, a))
	draw_string(font, Vector2(r.position.x, r.position.y + 43), "蓄力越久，伤害与击退越强", HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.68, 0.78, 0.92, a * 0.85))


func _draw_victory(vp: Vector2) -> void:
	var reveal := clampf(1.0 - main.victory_reveal / 0.85, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.008, 0.015, 0.03, 0.62 * reveal), true)
	var w := 620.0
	var h := 370.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y * 0.5 - h * 0.5, w, h)
	_panel(r, 0.88 * reveal)
	draw_line(Vector2(r.position.x, r.position.y + 2), Vector2(r.end.x, r.position.y + 2), Color(GOLD.r, GOLD.g, GOLD.b, reveal), 2.5)
	draw_line(Vector2(r.position.x, r.end.y - 2), Vector2(r.end.x, r.end.y - 2), Color(BLUE.r, BLUE.g, BLUE.b, reveal), 2.0)
	var cx := vp.x * 0.5
	draw_string(font, Vector2(cx - w * 0.5, r.position.y + 96), "极意 · 完成", HORIZONTAL_ALIGNMENT_CENTER, w, 54, Color(1.0, 0.86, 0.55, reveal))
	draw_string(font, Vector2(cx - w * 0.5, r.position.y + 126), "ULTIMATE TRIAL CLEARED", HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.6, 0.76, 0.96, reveal))
	draw_string(font, Vector2(cx - w * 0.5, r.position.y + 184), "用时  %0.1f s" % main.elapsed, HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(0.85, 0.90, 1.0, reveal))
	draw_string(font, Vector2(cx - w * 0.5, r.position.y + 216), "最高连击  ×%d      命中  %d" % [main.max_combo, main.hits], HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(0.86, 0.82, 0.68, reveal))
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
	draw_string(font, Vector2(cx - w * 0.5, r.position.y + 300), "按  R  重新挑战", HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(0.55, 0.80, 1.0, reveal * pulse))


func _draw_defeat(vp: Vector2) -> void:
	var reveal := clampf(1.0 - main.defeat_reveal / 0.8, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.006, 0.006, 0.62 * reveal), true)
	var w := 560.0
	var h := 280.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y * 0.5 - h * 0.5, w, h)
	_panel(r, 0.88 * reveal)
	draw_line(Vector2(r.position.x, r.position.y + 2), Vector2(r.end.x, r.position.y + 2), Color(RED.r, RED.g, RED.b, reveal), 2.5)
	var cx := vp.x * 0.5
	draw_string(font, Vector2(cx - w * 0.5, r.position.y + 96), "力竭", HORIZONTAL_ALIGNMENT_CENTER, w, 54, Color(1.0, 0.55, 0.45, reveal))
	draw_string(font, Vector2(cx - w * 0.5, r.position.y + 128), "TRIAL FAILED", HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.8, 0.55, 0.55, reveal))
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
	draw_string(font, Vector2(cx - w * 0.5, r.position.y + 218), "按  R  重新挑战", HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(0.9, 0.75, 0.80, reveal * pulse))


func _panel(r: Rect2, alpha: float) -> void:
	draw_rect(r, Color(PANEL.r, PANEL.g, PANEL.b, PANEL.a * alpha), true)
	draw_rect(r, Color(0.55, 0.66, 0.85, 0.28 * alpha), false, 1.0)
	var c := Color(0.95, 0.78, 0.42, 0.7 * alpha)
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if corner.x > r.get_center().x else -1.0
		var sy := 1.0 if corner.y > r.get_center().y else -1.0
		draw_line(corner, corner + Vector2(14 * sx, 0), c, 1.4)
		draw_line(corner, corner + Vector2(0, 14 * sy), c, 1.4)


func _bar(r: Rect2, ratio: float, color: Color, bg: Color, height := -1.0) -> void:
	var h := r.size.y if height < 0.0 else height
	var skew := 4.0
	var bg_poly := PackedVector2Array([
		Vector2(r.position.x + skew, r.position.y),
		Vector2(r.end.x + skew, r.position.y),
		Vector2(r.end.x, r.position.y + h),
		Vector2(r.position.x, r.position.y + h),
	])
	draw_colored_polygon(bg_poly, bg)
	var clamped := clampf(ratio, 0.0, 1.0)
	var w := r.size.x * clamped
	if w > 1.0:
		var fill_poly := PackedVector2Array([
			Vector2(r.position.x + skew, r.position.y),
			Vector2(r.position.x + w + skew, r.position.y),
			Vector2(r.position.x + w, r.position.y + h),
			Vector2(r.position.x, r.position.y + h),
		])
		draw_colored_polygon(fill_poly, color)
		draw_line(Vector2(r.position.x + skew, r.position.y + 1),
			Vector2(r.position.x + w + skew, r.position.y + 1),
			Color(1, 1, 1, 0.55), 1.0)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x + skew, h),
		Color(0.65, 0.72, 0.88, 0.25), false, 1.0)
