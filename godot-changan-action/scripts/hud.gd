extends Control
class_name ChanganHUD

## 灯下客 HUD：气血/气/连击/目标/街灯数/Boss 血条/锁定/交互提示/伤害闪屏/
## 对话/抉择/结算/失败/标题。全部自绘 + 系统 CJK 字体，无外部 UI 素材。

var main: Node
var font: SystemFont
var flash_red := 0.0
var tutorial_muted := false

const PAPER := Color(0.94, 0.88, 0.74)
const GOLD := Color(1.0, 0.70, 0.28)
const RED := Color(0.86, 0.30, 0.22)
const JADE := Color(0.36, 0.72, 0.58)
const DIM := Color(0.66, 0.69, 0.78)
const PANEL := Color(0.025, 0.035, 0.06, 0.72)
const NIGHT := Color(0.055, 0.075, 0.15)


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
	queue_redraw()


func _draw() -> void:
	if main == null or main.player == null:
		return
	var vp := get_viewport_rect().size
	if vp.x < 10.0:
		vp = Vector2(1280, 720)
	_draw_vignette(vp)
	var state: String = main.game_state
	if state == "title":
		_draw_title(vp)
	else:
		_draw_player_panel(vp)
		_draw_objective(vp)
		_draw_combo(vp)
		_draw_lock_marker(vp)
		_draw_boss_panel(vp)
		_draw_interact(vp)
		_draw_toast(vp)
		_draw_tutorial(vp)
		if state == "dialogue":
			_draw_dialogue(vp)
		elif state == "choice":
			_draw_choice(vp)
		elif state == "results":
			_draw_results(vp)
		elif state == "defeat":
			_draw_defeat(vp)
		elif state == "paused":
			_draw_paused(vp)
	if flash_red > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.8, 0.05, 0.02, flash_red * 0.24), true)


func _draw_vignette(vp: Vector2) -> void:
	draw_rect(Rect2(0, 0, vp.x, 56), Color(0, 0, 0, 0.20), true)
	draw_rect(Rect2(0, vp.y - 92, vp.x, 92), Color(0, 0, 0, 0.24), true)
	draw_rect(Rect2(0, 0, 22, vp.y), Color(0, 0, 0, 0.10), true)
	draw_rect(Rect2(vp.x - 22, 0, 22, vp.y), Color(0, 0, 0, 0.10), true)


# ── title ───────────────────────────────────────────────────────────────────

func _draw_title(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.012, 0.02, 0.04, 0.30), true)
	var panel := Rect2(vp.x * 0.5 - 330, vp.y * 0.20, 660, 300)
	draw_rect(panel, Color(0.015, 0.025, 0.05, 0.74), true)
	draw_rect(panel, Color(0.85, 0.62, 0.28, 0.18), false, 1.2)
	var cx := vp.x * 0.5
	draw_string(font, Vector2(0, vp.y * 0.34), "灯 下 客", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 72, Color(0.98, 0.76, 0.36))
	draw_string(font, Vector2(0, vp.y * 0.34 + 46), "长 安 一 夜", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 30, Color(0.86, 0.82, 0.72))
	draw_line(Vector2(cx - 190, vp.y * 0.34 + 68), Vector2(cx + 190, vp.y * 0.34 + 68), Color(1.0, 0.68, 0.28, 0.8), 1.5)
	draw_string(font, Vector2(0, vp.y * 0.34 + 106), "守灯人查一桩黑灯油的旧账", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 20, Color(0.82, 0.84, 0.92))
	draw_string(font, Vector2(0, vp.y * 0.34 + 136), "10–15 分钟 · 三盏街灯 · 一场短战", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 15, Color(0.58, 0.66, 0.82))
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
	draw_string(font, Vector2(0, vp.y * 0.78), "按 任 意 键 开 始", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 24, Color(0.95, 0.78, 0.42, pulse))
	draw_string(font, Vector2(0, vp.y - 34), "原创致敬版 · 与原作者作品无关 · 角色网格 CC0 KayKit，场景/剧情/UI 原创",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 12, Color(0.55, 0.60, 0.72, 0.8))


# ── combat panels ───────────────────────────────────────────────────────────

func _draw_player_panel(vp: Vector2) -> void:
	var p = main.player
	var r := Rect2(24, 22, 330, 96)
	_panel(r, 0.78)
	draw_line(r.position, r.position + Vector2(130, 0), GOLD, 1.6)
	draw_string(font, Vector2(r.position.x + 16, r.position.y + 24), "沈灯 · 守灯人", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPER)
	var hp_ratio: float = float(p.hp) / 100.0
	draw_string(font, Vector2(r.position.x + 16, r.position.y + 50), "气血", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)
	_bar(Rect2(r.position.x + 54, r.position.y + 38, 210, 13), hp_ratio,
		Color(0.88, 0.26, 0.18), Color(0.25, 0.05, 0.04, 0.7))
	draw_string(font, Vector2(r.end.x - 58, r.position.y + 50), "%d" % p.hp, HORIZONTAL_ALIGNMENT_RIGHT, 42, 13, PAPER)
	draw_string(font, Vector2(r.position.x + 16, r.position.y + 75), "气", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)
	var qi_full: bool = p.qi >= 100.0
	_bar(Rect2(r.position.x + 54, r.position.y + 64, 210, 9), p.qi / 100.0,
		GOLD if qi_full else Color(0.78, 0.58, 0.24), Color(0.16, 0.13, 0.06, 0.7))
	draw_string(font, Vector2(r.end.x - 58, r.position.y + 74), "%d" % int(p.qi), HORIZONTAL_ALIGNMENT_RIGHT, 42, 12, GOLD if qi_full else DIM)
	if qi_full:
		var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
		draw_string(font, Vector2(r.position.x + 280, r.position.y + 90), "Q 灯破", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.82, 0.40, pulse))
	else:
		draw_string(font, Vector2(r.position.x + 276, r.position.y + 90), "Q 灯破 · 气满", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.52, 0.55, 0.65))


func _draw_objective(vp: Vector2) -> void:
	var w := 480.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, 18, w, 38)
	_panel(r, 0.76)
	draw_line(Vector2(r.position.x + 24, r.position.y), Vector2(r.end.x - 24, r.position.y), GOLD, 1.6)
	var text := "目标 · " + String(main.quest_text)
	draw_string(font, Vector2(r.position.x, r.position.y + 25), text, HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color(0.96, 0.88, 0.72))
	draw_string(font, Vector2(r.position.x, r.end.y + 16), "街灯 %d / 3" % main.street_lights_lit,
		HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.96, 0.72, 0.36))


func _draw_combo(vp: Vector2) -> void:
	if main.combo <= 1:
		return
	var t := clampf(main.combo_timer / 2.4, 0.0, 1.0)
	var x := vp.x - 128.0
	var y := 176.0
	draw_arc(Vector2(x, y), 42, -PI * 0.5, -PI * 0.5 + TAU * t, 36, GOLD, 2.4, true)
	draw_circle(Vector2(x, y), 36, Color(0.02, 0.04, 0.07, 0.52))
	draw_string(font, Vector2(x - 46, y + 12), "×%d" % main.combo, HORIZONTAL_ALIGNMENT_CENTER, 92, 34 + mini(main.combo, 6) * 2, GOLD)
	draw_string(font, Vector2(x - 46, y + 34), "连击", HORIZONTAL_ALIGNMENT_CENTER, 92, 12, Color(0.88, 0.82, 0.68))


func _draw_lock_marker(vp: Vector2) -> void:
	var target = main.lock_target
	if target == null or not is_instance_valid(target) or target.is_dead:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var head: Vector3 = target.global_position + Vector3(0, 2.05, 0)
	if cam.is_position_behind(head):
		return
	var screen := cam.unproject_position(head)
	var s := 9.0
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
	var diamond := PackedVector2Array([
		screen + Vector2(0, -s * pulse), screen + Vector2(s * pulse, 0),
		screen + Vector2(0, s * pulse), screen + Vector2(-s * pulse, 0),
	])
	draw_colored_polygon(diamond, Color(1.0, 0.72, 0.26, 0.85))
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]),
		Color(1.0, 0.90, 0.62, 0.95), 1.4)
	draw_string(font, screen + Vector2(-70, -16), String(target.display_name),
		HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color(1.0, 0.86, 0.60, 0.9))


func _draw_boss_panel(vp: Vector2) -> void:
	var boss = main.boss_ref
	if boss == null or not is_instance_valid(boss) or boss.is_dead:
		return
	if main.game_state not in ["playing", "dialogue", "choice"]:
		return
	var w := 620.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y - 78, w, 50)
	_panel(r, 0.80)
	draw_string(font, Vector2(r.position.x + 12, r.position.y + 22), "霍三更 · 灯市行首",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.98, 0.78, 0.46))
	var phase_text := "一阶段" if boss.phase == 1 else "二阶段 · 熄灯"
	draw_string(font, Vector2(r.end.x - 160, r.position.y + 22), phase_text,
		HORIZONTAL_ALIGNMENT_RIGHT, 150, 12, Color(1.0, 0.52, 0.26) if boss.phase == 2 else DIM)
	_bar(Rect2(r.position.x + 12, r.position.y + 30, w - 24, 10), boss.display_hp_ratio(),
		Color(0.90, 0.34, 0.14), Color(0.20, 0.06, 0.04, 0.75))
	# 阶段刻度
	draw_line(Vector2(r.position.x + 12 + (w - 24) * 0.5, r.position.y + 28),
		Vector2(r.position.x + 12 + (w - 24) * 0.5, r.position.y + 42), Color(1.0, 0.8, 0.5, 0.7), 1.2)


func _draw_interact(vp: Vector2) -> void:
	var prompt: String = main.interact_prompt
	if prompt == "":
		return
	var w := 280.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y - 170, w, 32)
	_panel(r, 0.72)
	draw_string(font, Vector2(r.position.x, r.position.y + 21), prompt,
		HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(0.96, 0.88, 0.70))


func _draw_toast(vp: Vector2) -> void:
	var toast: String = main.toast_text
	if toast == "" or main.toast_timer <= 0.0:
		return
	var a := clampf(main.toast_timer / 0.5, 0.0, 1.0)
	var w := 480.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, 86, w, 30)
	draw_rect(r, Color(0.04, 0.06, 0.10, 0.74 * a), true)
	draw_string(font, Vector2(r.position.x, r.position.y + 20), toast,
		HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(1.0, 0.80, 0.42, a))


func _draw_tutorial(vp: Vector2) -> void:
	if tutorial_muted or main.game_state != "playing" or main.elapsed > 28.0:
		return
	if main.boss_ref != null and not main.boss_ref.is_dead:
		return
	var w := 760.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y - 54, w, 30)
	_panel(r, 0.56)
	var text := "WASD 移动 · 左键 刺拳 / 右键 踢 · 空格 翻滚 · Shift 冲刺 · Tab 锁定 · E 交互 · Q 灯破"
	draw_string(font, Vector2(r.position.x, r.position.y + 20), text,
		HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.80, 0.85, 0.94, 0.92))


# ── dialogue / choice / results ─────────────────────────────────────────────

func _draw_dialogue(vp: Vector2) -> void:
	var w := 860.0
	var h := 138.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y - h - 34, w, h)
	_panel(r, 0.90)
	draw_line(Vector2(r.position.x + 26, r.position.y), Vector2(r.position.x + 260, r.position.y), GOLD, 1.8)
	draw_string(font, Vector2(r.position.x + 24, r.position.y + 30),
		String(main.dialogue_speaker), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, GOLD)
	var line := ""
	if main.dialogue_index >= 0 and main.dialogue_index < main.dialogue_lines.size():
		line = String(main.dialogue_lines[main.dialogue_index])
	draw_string(font, Vector2(r.position.x + 24, r.position.y + 66),
		line, HORIZONTAL_ALIGNMENT_LEFT, w - 48, 19, PAPER)
	draw_string(font, Vector2(r.position.x + 24, r.end.y - 16),
		"空格 / E 继续    ·    Esc 跳过", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
	draw_string(font, Vector2(r.end.x - 84, r.end.y - 16),
		"%d / %d" % [main.dialogue_index + 1, main.dialogue_lines.size()],
		HORIZONTAL_ALIGNMENT_RIGHT, 60, 11, Color(0.72, 0.66, 0.54))


func _draw_choice(vp: Vector2) -> void:
	var w := 620.0
	var h := 250.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y * 0.5 - h * 0.5, w, h)
	_panel(r, 0.92)
	draw_line(Vector2(r.position.x, r.position.y + 2), Vector2(r.end.x, r.position.y + 2), GOLD, 2.0)
	draw_string(font, Vector2(r.position.x, r.position.y + 52), "灯 还 亮 着",
		HORIZONTAL_ALIGNMENT_CENTER, w, 38, Color(1.0, 0.82, 0.48))
	draw_string(font, Vector2(r.position.x, r.position.y + 86), "霍三更跪在鼓楼前，铁尺落在石板上。",
		HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(0.82, 0.84, 0.92))
	draw_string(font, Vector2(r.position.x, r.position.y + 112), "灯市街的最后一盏灯，握在你手里。",
		HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(0.82, 0.84, 0.92))
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
	draw_string(font, Vector2(r.position.x + 40, r.position.y + 168), "1   留 手", HORIZONTAL_ALIGNMENT_LEFT, 240, 24, Color(0.94, 0.88, 0.72, pulse))
	draw_string(font, Vector2(r.position.x + 340, r.position.y + 168), "2   了 结", HORIZONTAL_ALIGNMENT_LEFT, 240, 24, Color(1.0, 0.52, 0.34, pulse))
	draw_string(font, Vector2(r.position.x, r.position.y + 210), "留手：交官/闻九，街灯继续亮着    了结：吹灭他的灯，街口多一盏无人认领的灯",
		HORIZONTAL_ALIGNMENT_CENTER, w, 12, DIM)


func _draw_results(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.008, 0.012, 0.025, 0.72), true)
	var w := 700.0
	var h := 440.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y * 0.5 - h * 0.5, w, h)
	_panel(r, 0.94)
	draw_line(Vector2(r.position.x, r.position.y + 2), Vector2(r.end.x, r.position.y + 2), GOLD, 2.4)
	draw_string(font, Vector2(r.position.x, r.position.y + 64), "长 安 一 夜 · 收 灯",
		HORIZONTAL_ALIGNMENT_CENTER, w, 36, Color(1.0, 0.82, 0.48))
	draw_multiline_string(font, Vector2(r.position.x + 40, r.position.y + 108), String(main.ending_text),
		HORIZONTAL_ALIGNMENT_LEFT, w - 80, 17, 3, PAPER)
	draw_line(Vector2(r.position.x + 50, r.position.y + 150), Vector2(r.end.x - 50, r.position.y + 150), Color(0.6, 0.55, 0.45, 0.4), 1.0)
	var stats := [
		["用时", "%.0f 秒" % main.elapsed],
		["最高连击", "×%d" % main.max_combo],
		["点亮街灯", "%d / 3" % main.street_lights_lit],
		["受击次数", "%d" % main.hits_taken],
		["选择", "留手" if main.choice == "mercy" else "了结"],
	]
	for i in stats.size():
		var y := r.position.y + 194 + i * 34
		draw_string(font, Vector2(r.position.x + 90, y), stats[i][0], HORIZONTAL_ALIGNMENT_LEFT, 180, 17, DIM)
		draw_string(font, Vector2(r.position.x + 280, y), stats[i][1], HORIZONTAL_ALIGNMENT_LEFT, 260, 17, Color(0.94, 0.86, 0.68))
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
	draw_string(font, Vector2(r.position.x, r.end.y - 34), "R  再 走 一 遍", HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(0.96, 0.78, 0.40, pulse))


func _draw_defeat(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.006, 0.006, 0.66), true)
	var w := 560.0
	var h := 260.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y * 0.5 - h * 0.5, w, h)
	_panel(r, 0.92)
	draw_line(Vector2(r.position.x, r.position.y + 2), Vector2(r.end.x, r.position.y + 2), RED, 2.4)
	draw_string(font, Vector2(r.position.x, r.position.y + 88), "灯 灭 了",
		HORIZONTAL_ALIGNMENT_CENTER, w, 46, Color(1.0, 0.58, 0.44))
	draw_string(font, Vector2(r.position.x, r.position.y + 124), "这条街还得有人守。",
		HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(0.86, 0.78, 0.76))
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
	draw_string(font, Vector2(r.position.x, r.position.y + 196), "R  重 试 本 场",
		HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color(0.94, 0.82, 0.76, pulse))
	draw_string(font, Vector2(r.position.x, r.position.y + 226), "Esc  回到标题",
		HORIZONTAL_ALIGNMENT_CENTER, w, 13, DIM)


func _draw_paused(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.01, 0.015, 0.03, 0.55), true)
	draw_string(font, Vector2(0, vp.y * 0.5), "已 暂 停 · Esc 继续", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 28, PAPER)


func _panel(r: Rect2, alpha: float) -> void:
	draw_rect(r, Color(PANEL.r, PANEL.g, PANEL.b, PANEL.a * alpha), true)
	draw_rect(r, Color(0.62, 0.58, 0.48, 0.28 * alpha), false, 1.0)
	var c := Color(GOLD.r, GOLD.g, GOLD.b, 0.65 * alpha)
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if corner.x > r.get_center().x else -1.0
		var sy := 1.0 if corner.y > r.get_center().y else -1.0
		draw_line(corner, corner + Vector2(12 * sx, 0), c, 1.3)
		draw_line(corner, corner + Vector2(0, 12 * sy), c, 1.3)


func _bar(r: Rect2, ratio: float, color: Color, bg: Color) -> void:
	var skew := 4.0
	var h := r.size.y
	var bg_poly := PackedVector2Array([
		Vector2(r.position.x + skew, r.position.y),
		Vector2(r.end.x + skew, r.position.y),
		Vector2(r.end.x, r.end.y),
		Vector2(r.position.x, r.end.y),
	])
	draw_colored_polygon(bg_poly, bg)
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped <= 0.0:
		return
	var fill_end := r.position.x + r.size.x * clamped
	var fill := PackedVector2Array([
		Vector2(r.position.x + skew, r.position.y),
		Vector2(fill_end + skew, r.position.y),
		Vector2(fill_end, r.end.y),
		Vector2(r.position.x, r.end.y),
	])
	draw_colored_polygon(fill, color)
	draw_line(Vector2(r.position.x + 2, r.position.y), Vector2(fill_end, r.position.y),
		Color(1, 1, 1, 0.20), 1.0)
