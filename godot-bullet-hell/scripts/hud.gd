class_name BulletHud
extends Control

const ArtRes = preload("res://scripts/art.gd")

# 中文街机 HUD：Boss 血条/阶段、当前弹幕、残机/擦弹、FPS/弹量、
# 暂停/胜负覆盖层、节拍与受击闪屏。全部用 draw_* 自绘，不依赖主题资源。

var phase_title := "第一阶 · 校准"
var phase_subtitle := "PHASE 1 // CALIBRATE"
var phase_index := 0
var phase_count := 3
var phase_color := ArtRes.MAGENTA
var boss_name := "辉庭守望者 · 环"
var hp := 1200.0
var max_hp := 1200.0
var lives := 5
var max_lives := 5
var graze := 0
var fps := 0
var bullet_count := 0
var bullet_capacity := 4096
var pattern_code := "P01"
var pattern_name := "单发·瞄准"
var pattern_summary := ""
var inspect_id := -1
var demo := true
var paused := false
var game_over := false
var victory := false
var elapsed := 0.0
var transition_text := ""
var transition_sub := ""
var transition_left := 0.0
var flash_color := Color.WHITE
var flash_alpha := 0.0
var toast_text := ""
var toast_left := 0.0
var beat_pulse := 0.0
var rec_mode := false
var _redraw_accum := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	z_index = 100
	set_process(true)

func _process(delta: float) -> void:
	elapsed += delta
	flash_alpha = maxf(0.0, flash_alpha - delta * 3.2)
	transition_left = maxf(0.0, transition_left - delta)
	toast_left = maxf(0.0, toast_left - delta)
	# HUD 以 20Hz 重录 draw 指令，减少 Intel 核显上的 CanvasItem 行数。
	_redraw_accum += delta
	if _redraw_accum >= 0.05:
		_redraw_accum = 0.0
		queue_redraw()

func flash(color: Color, strength := 0.3) -> void:
	flash_color = color
	flash_alpha = maxf(flash_alpha, strength)

func show_transition(title: String, subtitle: String, duration := 1.5) -> void:
	transition_text = title
	transition_sub = subtitle
	transition_left = duration

func toast(text: String, duration := 1.2) -> void:
	toast_text = text
	toast_left = duration

func _draw() -> void:
	if flash_alpha > 0.001:
		draw_rect(Rect2(0, 0, 1280, 720), Color(flash_color, flash_alpha), true)
	# 顶部品牌
	draw_colored_polygon(PackedVector2Array([
		Vector2(38, 27), Vector2(47, 36), Vector2(38, 45), Vector2(29, 36),
	]), Color(ArtRes.MAGENTA, 0.9))
	draw_arc(Vector2(38, 36), 10.0, 0.0, TAU, 24, Color(ArtRes.CYAN, 0.55), 1.0, true)
	ArtRes.draw_title(self, Vector2(56, 42), "绯星弹幕", 21, ArtRes.INK)
	ArtRes.draw_text(self, Vector2(56, 58), "SCARLET ORBIT // 10 PATTERNS", 9, ArtRes.DIM)

	# Boss 血条与阶段
	var hp_rect := Rect2(390.0, 34.0, 500.0, 9.0)
	ArtRes.draw_text(self, Vector2(390, 24), boss_name, 13, ArtRes.INK, true)
	var ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	draw_rect(hp_rect.grow(2.0), Color(ArtRes.LINE, 0.30), true)
	draw_rect(hp_rect, Color(0.035, 0.025, 0.065, 0.9), true)
	draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * ratio, hp_rect.size.y)), Color(phase_color, 0.88), true)
	draw_rect(Rect2(hp_rect.position + Vector2(0, 1), Vector2(hp_rect.size.x * ratio, 2.0)), Color(1, 1, 1, 0.62), true)
	for k in 4:
		var x := hp_rect.position.x + hp_rect.size.x * float(k + 1) / 4.0
		draw_line(Vector2(x, 31), Vector2(x, 46), Color(ArtRes.INK, 0.22), 1.0)
	draw_rect(hp_rect.grow(2.0), Color(phase_color, 0.5), false, 1.0)
	ArtRes.draw_text(self, Vector2(390, 61), phase_title, 11, Color(phase_color, 0.95), true)
	ArtRes.draw_text(self, Vector2(610, 61), "阶段 %d / %d  ·  HP %d" % [phase_index + 1, phase_count, int(ceil(hp))], 10, ArtRes.DIM)
	# 阶段刻度
	for k in phase_count:
		var c := phase_color if k <= phase_index else Color(ArtRes.LINE, 0.45)
		draw_rect(Rect2(892.0 + k * 11.0, 38.0, 7.0, 3.0), c, true)

	# 右上性能/技术信息
	if rec_mode:
		ArtRes.draw_text(self, Vector2(40, 84), "REC 60FPS   ·   弹 %d / %d" % [bullet_count, bullet_capacity], 10, Color(ArtRes.DIM, 0.93), false, HORIZONTAL_ALIGNMENT_RIGHT, 1206)
	else:
		ArtRes.draw_text(self, Vector2(40, 84), "FPS %d   ·   弹 %d / %d" % [fps, bullet_count, bullet_capacity], 10, Color(ArtRes.DIM, 0.93), false, HORIZONTAL_ALIGNMENT_RIGHT, 1206)
	ArtRes.draw_text(self, Vector2(40, 98), "SEED B17B17  ·  BPM 120", 9, Color(ArtRes.LINE, 0.95), false, HORIZONTAL_ALIGNMENT_RIGHT, 1206)

	# 当前弹幕卡
	var card := Rect2(26.0, 136.0, 336.0, 84.0)
	draw_rect(card, Color(0.025, 0.018, 0.055, 0.42), true)
	draw_rect(card, Color(phase_color if inspect_id >= 0 else ArtRes.LINE, 0.55 if inspect_id >= 0 else 0.30), false, 1.0)
	draw_rect(Rect2(card.position, Vector2(3.0, card.size.y)), Color(phase_color if inspect_id >= 0 else ArtRes.CYAN, 0.85), true)
	var label := "观察模式 · OBSERVE" if inspect_id >= 0 else "当前弹幕 · CURRENT"
	ArtRes.draw_text(self, card.position + Vector2(14, 18), label, 9, ArtRes.DIM)
	ArtRes.draw_title(self, card.position + Vector2(14, 48), "%s  %s" % [pattern_code, pattern_name], 19, ArtRes.INK if inspect_id < 0 else ArtRes.CYAN)
	ArtRes.draw_text(self, card.position + Vector2(14, 69), pattern_summary, 10, ArtRes.DIM)
	if inspect_id >= 0:
		ArtRes.draw_text(self, card.position + Vector2(238, 18), "Q 返回时间轴", 9, Color(ArtRes.GOLD, 0.9))

	# 左下：残机 + 擦弹
	ArtRes.draw_text(self, Vector2(34, 620), "残机", 10, ArtRes.DIM)
	for k in max_lives:
		var c := ArtRes.CYAN if k < lives else Color(ArtRes.LINE, 0.35)
		var cx := 84.0 + k * 18.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, 608), Vector2(cx + 6, 615), Vector2(cx, 622), Vector2(cx - 6, 615),
		]), c)
	ArtRes.draw_text(self, Vector2(34, 644), "擦弹", 10, ArtRes.DIM)
	ArtRes.draw_title(self, Vector2(84, 647), "%03d" % graze, 18, ArtRes.CYAN)
	ArtRes.draw_text(self, Vector2(160, 644), "AUTO FIRE", 9, Color(ArtRes.GOLD, 0.85))
	draw_circle(Vector2(226, 640), 3.0, Color(ArtRes.GOLD, 0.9))

	# 底部模式/操作
	var mode_text := "演示自动操作中 · TAB 接管" if (demo and not game_over and not victory) else "手动操控 · TAB 切回演示"
	var mode_color := ArtRes.CYAN if demo else ArtRes.DIM
	ArtRes.draw_text(self, Vector2(40, 663), "● " + mode_text, 10, Color(mode_color, 0.9), false, HORIZONTAL_ALIGNMENT_CENTER, 1200)
	ArtRes.draw_text(self, Vector2(34, 684), "WASD / 方向键 移动    SHIFT 聚焦    P 暂停    R 重开", 10, ArtRes.DIM)
	ArtRes.draw_text(self, Vector2(34, 698), "1–0 观察弹幕    Q 返回时间轴    TAB 演示/接管", 9, Color(ArtRes.LINE, 1.0))
	ArtRes.draw_text(self, Vector2(40, 684), "教程语言复刻 · 角色/素材原创", 9, Color(ArtRes.LINE, 0.8), false, HORIZONTAL_ALIGNMENT_RIGHT, 1200)

	# 顶部与 Boss 同步的节拍短线
	if beat_pulse > 0.01:
		var beat_w := 34.0 * beat_pulse
		draw_rect(Rect2(640.0 - beat_w * 0.5, 80.0, beat_w, 1.0), Color(phase_color, 0.25 + 0.4 * beat_pulse), true)

	# 提示 toast
	if toast_left > 0.0 and transition_left <= 0.0:
		var a: float = minf(1.0, toast_left * 2.0)
		draw_rect(Rect2(486.0, 100.0, 308.0, 26.0), Color(0.02, 0.01, 0.05, 0.65 * a), true)
		ArtRes.draw_text(self, Vector2(486, 117), toast_text, 11, Color(ArtRes.INK, a), false, HORIZONTAL_ALIGNMENT_CENTER, 308)

	# 阶段切换横幅
	if transition_left > 0.0:
		var a: float = clampf(minf((1.5 - transition_left) * 4.0, transition_left * 2.2), 0.0, 1.0)
		draw_rect(Rect2(250.0, 306.0, 780.0, 116.0), Color(0.012, 0.008, 0.03, 0.72 * a), true)
		draw_line(Vector2(250, 306), Vector2(1030, 306), Color(phase_color, 0.65 * a), 1.0)
		draw_line(Vector2(250, 422), Vector2(1030, 422), Color(phase_color, 0.65 * a), 1.0)
		ArtRes.draw_title(self, Vector2(250, 352), transition_text, 32, Color(ArtRes.INK, a), HORIZONTAL_ALIGNMENT_CENTER, 780)
		ArtRes.draw_text(self, Vector2(250, 381), transition_sub, 11, Color(phase_color, 0.9 * a), false, HORIZONTAL_ALIGNMENT_CENTER, 780)
		ArtRes.draw_text(self, Vector2(250, 406), "120 BPM · PATTERN TIMELINE", 9, Color(ArtRes.DIM, a), false, HORIZONTAL_ALIGNMENT_CENTER, 780)

	# 暂停 / 胜负覆盖层
	if paused or game_over or victory:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.008, 0.005, 0.02, 0.68), true)
	if paused:
		_draw_panel("暂停 / PAUSED", "P 继续    R 重开", ArtRes.CYAN, "WASD 移动 · SHIFT 聚焦 · 1–0 观察弹幕")
	elif game_over:
		_draw_panel("信号丢失 / SIGNAL LOST", "R 重新连线", ArtRes.RED, "擦弹 %03d  ·  阶段 %d / %d" % [graze, phase_index + 1, phase_count])
	elif victory:
		_draw_panel("辉庭已静默 / STAGE CLEAR", "R 再来一次", ArtRes.GOLD, "残机 %d  ·  擦弹 %03d  ·  10/10 弹幕已归档" % [lives, graze])

func _draw_panel(title: String, hint: String, color: Color, sub: String) -> void:
	var box := Rect2(376.0, 276.0, 528.0, 168.0)
	draw_rect(box, Color(0.02, 0.012, 0.045, 0.92), true)
	draw_rect(box, Color(color, 0.7), false, 1.5)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 2.0)), Color(color, 0.9), true)
	ArtRes.draw_title(self, Vector2(box.position.x, box.position.y + 52.0), title, 27, color, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	ArtRes.draw_text(self, Vector2(box.position.x, box.position.y + 86.0), sub, 11, ArtRes.DIM, false, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	ArtRes.draw_text(self, Vector2(box.position.x, box.position.y + 126.0), hint, 16, ArtRes.INK, true, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
