class_name DreamHud
extends Control

# 中文 HUD：梦血/气力/忆能、弹反窗口提示、Boss 血条、目标、交互、暂停/梦碎/胜利。
# 所有坐标按 1280×720 设计，_draw 时整体缩放到实际视口，因此 1920×1080 截图同样清晰。

const W := 1280.0
const H := 720.0

const COL_BG := Color(0.025, 0.033, 0.06, 0.78)
const COL_BORDER := Color(0.72, 0.58, 0.35, 0.72)
const COL_GOLD := Color(0.95, 0.79, 0.48)
const COL_CREAM := Color(0.91, 0.89, 0.82)
const COL_MUTED := Color(0.58, 0.63, 0.71)
const COL_ROSE := Color(0.85, 0.42, 0.49)
const COL_STAMINA := Color(0.88, 0.69, 0.38)
const COL_ENERGY := Color(0.44, 0.86, 0.78)
const COL_PURPLE := Color(0.75, 0.51, 0.96)

var world: Node = null
var player: Node = null
var font_ui: SystemFont
var font_title: SystemFont

var boss_bar_visible := false
var death_overlay_visible := false
var victory_overlay_visible := false
var pause_visible := false
var parry_hint_visible := false
var parry_hint_text := ""
var parry_hint_sub := ""
var interact_text := ""
var objective_text := ""
var last_toast_text := ""
var room_title := ""
var room_title_left := 0.0
var show_fps := true
var hud_scale := 1.0

var _toast_text := ""
var _toast_color := Color.WHITE
var _toast_left := 0.0
var _toast_duration := 1.0
var _time := 0.0
var _intro_left := 9.0
var _hint_pulse := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font_ui = _make_font(["PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Source Han Sans SC", "Microsoft YaHei", "sans-serif"], 500)
	font_title = _make_font(["Songti SC", "STSong", "Noto Serif CJK SC", "Source Han Serif SC", "serif"], 600)


func _make_font(names: Array, weight: int) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	font.font_weight = weight
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.allow_system_fallback = true
	return font


func push_toast(text: String, color: Color, duration := 1.3) -> void:
	_toast_text = text
	_toast_color = color
	_toast_duration = duration
	_toast_left = duration
	last_toast_text = text


func show_room(name: String) -> void:
	room_title = name
	room_title_left = 2.6


func _process(delta: float) -> void:
	_time += delta
	_intro_left = maxf(0.0, _intro_left - delta)
	_toast_left = maxf(0.0, _toast_left - delta)
	room_title_left = maxf(0.0, room_title_left - delta)
	_hint_pulse += delta
	if world == null:
		return
	player = world.player
	boss_bar_visible = world.has_method("is_boss_bar_visible") and world.is_boss_bar_visible()
	death_overlay_visible = world.run_state == DreamWorld.RunState.DEAD
	victory_overlay_visible = world.run_state == DreamWorld.RunState.VICTORY
	pause_visible = world.paused
	objective_text = world.get_objective_text() if world.has_method("get_objective_text") else ""
	var hint: Dictionary = world.get_threat_hint() if world.has_method("get_threat_hint") else {}
	parry_hint_visible = not hint.is_empty()
	parry_hint_text = String(hint.get("text", ""))
	parry_hint_sub = String(hint.get("sub", ""))
	interact_text = world.get_interact_text() if world.has_method("get_interact_text") else ""
	queue_redraw()


func _draw() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0:
		viewport_size = Vector2(W, H)
	hud_scale = viewport_size.x / W
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(hud_scale, hud_scale))
	_draw_backdrop_marks()
	if world == null:
		return
	if victory_overlay_visible:
		_draw_victory()
		return
	if death_overlay_visible:
		_draw_death()
		return
	_draw_vitals()
	_draw_objective()
	_draw_controls_strip()
	_draw_room_title()
	_draw_threat_hint()
	_draw_interact()
	_draw_toast()
	_draw_parry_window()
	_draw_boss_bar()
	_draw_tutorial()
	if show_fps:
		var fps := Engine.get_frames_per_second()
		_text(Vector2(1222, 700), "%d fps" % fps, 9, Color(0.55, 0.63, 0.7, 0.75), HORIZONTAL_ALIGNMENT_RIGHT, 30)
	if pause_visible:
		_draw_pause()


func _draw_backdrop_marks() -> void:
	# 极细的上下装饰线 + 四角刻痕，让空画面仍像“梦的边框”。
	draw_line(Vector2(0, 0), Vector2(W, 0), Color(0.72, 0.58, 0.35, 0.18), 1.0)
	draw_line(Vector2(0, H - 1), Vector2(W, H - 1), Color(0.72, 0.58, 0.35, 0.18), 1.0)
	for corner in [Vector2(18, 18), Vector2(W - 18, 18), Vector2(18, H - 18), Vector2(W - 18, H - 18)]:
		var dir := Vector2(1, 1) if corner.x < W * 0.5 else Vector2(-1, 1)
		if corner.y > H * 0.5:
			dir.y = -1
		draw_line(corner, corner + Vector2(dir.x * 14, 0), Color(0.8, 0.65, 0.4, 0.3), 1.0)
		draw_line(corner, corner + Vector2(0, dir.y * 14), Color(0.8, 0.65, 0.4, 0.3), 1.0)


func _draw_vitals() -> void:
	var rect := Rect2(26, 22, 390, 137)
	_panel(rect)
	_draw_umbrella_icon(Vector2(50, 52), 0.82)
	_text(Vector2(74, 48), "缄梦者", 18, COL_CREAM)
	_text(Vector2(74, 64), "持伞的梦中人", 9, COL_MUTED)
	_text(Vector2(74, 62), "", 9, COL_MUTED)
	var hp_ratio := 0.0
	var stamina_ratio := 0.0
	var energy_ratio := 0.0
	if player != null:
		hp_ratio = clampf(float(player.hp) / float(DreamPlayer.MAX_HP), 0.0, 1.0)
		stamina_ratio = clampf(float(player.stamina) / float(DreamPlayer.MAX_STAMINA), 0.0, 1.0)
		energy_ratio = clampf(float(player.energy) / float(DreamPlayer.MAX_ENERGY), 0.0, 1.0)
	_bar(Rect2(74, 70, 320, 13), hp_ratio, COL_ROSE, "梦血", "%d / %d" % [int(player.hp), int(DreamPlayer.MAX_HP)] if player != null else "", 10)
	_text(Vector2(74, 99), "气力", 9, COL_MUTED)
	_bar(Rect2(100, 93, 126, 7), stamina_ratio, COL_STAMINA, "", "", 0)
	_text(Vector2(238, 99), "忆能", 9, COL_MUTED)
	_bar(Rect2(264, 93, 130, 7), energy_ratio, COL_ENERGY, "", "%d" % int(player.energy) if player != null else "", 9)
	var shards := int(world.shards_collected) if world != null else 0
	_text(Vector2(74, 118), "Q 回梦 -35忆能   E 交互/遗物 -25忆能", 9, Color(0.72, 0.76, 0.83, 0.9))
	_text(Vector2(74, 135), "记忆残片  %d / 2" % shards, 10, COL_GOLD if shards > 0 else COL_MUTED)
	var relic_state := "遗物 未取得"
	if world != null and world.has_relic:
		relic_state = "窥梦棱镜 已取得" if not world.bridge_revealed else "窥梦棱镜 · 断桥已显形"
	_text(Vector2(238, 135), relic_state, 9, COL_ENERGY if world != null and world.has_relic else COL_MUTED)


func _draw_umbrella_icon(center: Vector2, scale_value: float) -> void:
	var c := center
	draw_arc(c + Vector2(0, -2) * scale_value, 16.0 * scale_value, PI, TAU, 22, Color(0.93, 0.84, 0.66, 0.95), 2.2 * scale_value, true)
	draw_line(c + Vector2(-16, -2) * scale_value, c + Vector2(16, -2) * scale_value, Color(0.93, 0.84, 0.66, 0.95), 1.6 * scale_value, true)
	draw_line(c + Vector2(0, -2) * scale_value, c + Vector2(0, 22) * scale_value, Color(0.8, 0.63, 0.38, 0.95), 2.0 * scale_value, true)
	draw_arc(c + Vector2(4, 22) * scale_value, 4.0 * scale_value, PI * 0.12, PI * 1.35, 12, Color(0.8, 0.63, 0.38, 0.95), 1.8 * scale_value, true)
	for i in 3:
		draw_line(c + Vector2(-10 + i * 10, -2) * scale_value, c + Vector2(0, 13) * scale_value, Color(0.62, 0.5, 0.32, 0.6), 0.8 * scale_value, true)
	draw_circle(c + Vector2(0, -2) * scale_value, 2.0 * scale_value, COL_ENERGY)


func _draw_objective() -> void:
	var rect := Rect2(884, 22, 370, 94)
	_panel(rect)
	_text(Vector2(902, 44), "目 标", 11, COL_GOLD)
	var lines := objective_text.split("\n")
	var y := 64.0
	for line in lines:
		_text(Vector2(902, y), line, 11, COL_CREAM)
		y += 16.0
	var phase := ""
	if world != null and world.boss != null and not world.boss.is_alive():
		phase = "守钟人已沉默"
	elif world != null and world.boss != null and world.boss.phase_two:
		phase = "第二声钟 · 加速"
	elif world != null and world.has_relic:
		phase = "遗物：看破隐藏之路"
	_text(Vector2(902, 106), phase, 9, COL_MUTED)


func _draw_controls_strip() -> void:
	draw_rect(Rect2(0, 676, W, 44), Color(0.01, 0.016, 0.03, 0.62))
	draw_line(Vector2(0, 676), Vector2(W, 676), Color(0.72, 0.58, 0.35, 0.26), 1.0)
	var line := "WASD 移动    Tab 锁定    左键 轻击 / 按住重击    右键 弹反    Space 闪避    Q 回梦    E 交互 / 遗物    R 重开    Esc 暂停"
	_text(Vector2(26, 702), line, 10, Color(0.76, 0.8, 0.86, 0.86))
	if world != null and not world.has_relic:
		_text(Vector2(26, 666), "提示：弹反成功会回复忆能；忆能同时用于回梦与遗物。", 9, Color(0.72, 0.76, 0.83, 0.65))


func _draw_room_title() -> void:
	if room_title_left <= 0.0 or parry_hint_visible:
		return
	var alpha := clampf(room_title_left / 0.7, 0.0, 1.0)
	alpha *= clampf((2.6 - room_title_left) / 0.4, 0.0, 1.0)
	_center_text(118, room_title, 26, Color(0.93, 0.86, 0.7, alpha), font_title)
	_center_text(140, "· 梦 境 残 响 ·", 9, Color(0.7, 0.78, 0.81, alpha * 0.8))


func _draw_threat_hint() -> void:
	if not parry_hint_visible or parry_hint_text == "":
		return
	var urgent := 0.5 + 0.5 * sin(_hint_pulse * 10.0)
	var col := COL_GOLD
	if "闪避" in parry_hint_text:
		col = COL_PURPLE
	if "反击" in parry_hint_text:
		col = COL_ROSE
	var w := 340.0
	var rect := Rect2(470, 138, w, 58)
	draw_rect(rect, Color(0.02, 0.025, 0.05, 0.55))
	draw_rect(rect, Color(col.r, col.g, col.b, 0.45 + 0.25 * urgent), false, 1.0)
	draw_line(Vector2(488, 168), Vector2(508, 168), Color(col.r, col.g, col.b, 0.6), 1.0)
	draw_line(Vector2(772, 168), Vector2(792, 168), Color(col.r, col.g, col.b, 0.6), 1.0)
	_center_text(168, parry_hint_text, 22, Color(col.r, col.g, col.b, 0.92), font_title)
	_center_text(187, parry_hint_sub, 9, Color(0.82, 0.84, 0.9, 0.75))


func _draw_interact() -> void:
	if interact_text == "":
		return
	var font_size := 13
	var text_w := font_ui.get_string_size(interact_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var rect := Rect2(W * 0.5 - text_w * 0.5 - 40, 604, text_w + 80, 34)
	draw_rect(rect, Color(0.025, 0.04, 0.07, 0.82))
	draw_rect(rect, Color(0.55, 0.81, 0.74, 0.55), false, 1.0)
	var key_rect := Rect2(rect.position.x + 12, rect.position.y + 7, 22, 20)
	draw_rect(key_rect, Color(0.07, 0.12, 0.15, 0.9))
	draw_rect(key_rect, Color(0.6, 0.9, 0.82, 0.8), false, 1.0)
	_text(Vector2(key_rect.position.x + 7, key_rect.position.y + 15), "E", 12, COL_ENERGY)
	_text(Vector2(rect.position.x + 44, rect.position.y + 22), interact_text, font_size, COL_CREAM)


func _draw_toast() -> void:
	if _toast_left <= 0.0 or _toast_text == "":
		return
	var fade := clampf(_toast_left / minf(_toast_duration, 0.45), 0.0, 1.0)
	_center_text(214, _toast_text, 20, Color(_toast_color.r, _toast_color.g, _toast_color.b, fade), font_title)


func _draw_parry_window() -> void:
	if player == null:
		return
	if player.state != DreamPlayer.State.PARRY:
		return
	var window_left := maxf(0.0, float(DreamPlayer.PARRY_WINDOW) - float(player.parry_elapsed))
	var ratio := 1.0 - clampf(window_left / float(DreamPlayer.PARRY_WINDOW), 0.0, 1.0)
	var rect := Rect2(560, 356, 160, 4)
	draw_rect(rect, Color(0.02, 0.03, 0.05, 0.65))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), Color(1.0, 0.83, 0.46, 0.9))
	_center_text(348, "弹反判定  %.2fs" % window_left, 10, Color(0.95, 0.83, 0.55, 0.85))


func _draw_boss_bar() -> void:
	if not boss_bar_visible or world == null or world.boss == null:
		return
	var boss: Node = world.boss
	var ratio := clampf(float(boss.hp) / float(boss.max_hp), 0.0, 1.0)
	var rect := Rect2(320, 644, 640, 8)
	draw_rect(Rect2(300, 632, 680, 28), Color(0.01, 0.014, 0.025, 0.65))
	draw_rect(rect, Color(0.12, 0.08, 0.12, 0.9))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), Color(0.82, 0.32, 0.5, 1.0))
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(0.95, 0.7, 0.72, 0.18), 1.0)
	draw_line(rect.position + Vector2(0, rect.size.y), rect.position + Vector2(rect.size.x, rect.size.y), Color(0.95, 0.7, 0.72, 0.18), 1.0)
	_center_text(625, "钟摆守梦人", 14, Color(0.95, 0.83, 0.8, 0.96), font_title)
	var phase := "第二声钟" if boss.phase_two else "第一声钟"
	_text(Vector2(960, 646), phase, 9, Color(0.8, 0.6, 0.72, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 80)


func _draw_tutorial() -> void:
	if _intro_left <= 0.0 or death_overlay_visible or victory_overlay_visible:
		return
	if world != null and world.capture_mode:
		return
	var alpha := clampf(_intro_left / 2.0, 0.0, 1.0)
	var rect := Rect2(312, 470, 656, 78)
	draw_rect(rect, Color(0.02, 0.03, 0.05, 0.62 * alpha))
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(0.7, 0.58, 0.35, 0.35 * alpha), 1.0)
	_center_text(496, "右键弹反  ·  精准窗口 0.18 秒  ·  成功可打断并反击", 13, Color(0.92, 0.82, 0.62, alpha))
	_center_text(518, "回梦与遗物共用「忆能」；气力见底时先闪避拉开距离。", 10, Color(0.74, 0.82, 0.86, alpha * 0.9))
	_center_text(538, "梦境中的透明断桥，只有窥梦棱镜能令其显形。", 10, Color(0.6, 0.8, 0.78, alpha * 0.85))


func _draw_death() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.012, 0.02, 0.78))
	_center_text(300, "梦 碎 了", 54, Color(0.9, 0.72, 0.62, 0.96), font_title)
	_center_text(338, "记忆沉进雾里，残梦灯仍亮着。", 12, Color(0.7, 0.74, 0.8, 0.85))
	var seconds := 0.0
	if world != null:
		seconds = maxf(0.0, 2.4 - world.death_timer)
	_center_text(382, "正在回到残梦灯  ·  %.1fs" % seconds, 12, Color(0.8, 0.69, 0.48, 0.9))
	_center_text(414, "按 R 立即重来", 11, Color(0.64, 0.7, 0.77, 0.8))
	_center_text(468, "梦碎次数  %d" % int(world.death_count if world != null else 0), 10, Color(0.55, 0.6, 0.68, 0.75))


func _draw_victory() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.018, 0.026, 0.045, 0.76))
	_center_text(258, "梦 潮 退 去", 50, Color(0.93, 0.84, 0.66, 0.98), font_title)
	_center_text(296, "记忆已归位 · 这一梦结束了", 12, Color(0.72, 0.82, 0.8, 0.9))
	var stats := ""
	if world != null:
		var minutes := int(world.run_time) / 60
		var seconds := int(world.run_time) % 60
		stats = "用时 %02d:%02d    梦碎 %d 次    完美弹反 %d 次    记忆残片 2 / 2" % [minutes, seconds, world.death_count, world.player.parry_success_count]
	_center_text(380, stats, 12, Color(0.82, 0.84, 0.86, 0.9))
	_center_text(438, "R  再来一轮", 14, Color(0.93, 0.78, 0.48, 0.95))
	_center_text(468, "原创梦境切片 · 程序化关卡 / KayKit CC0 角色", 9, Color(0.48, 0.54, 0.62, 0.7))


func _draw_pause() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.008, 0.012, 0.02, 0.68))
	_center_text(278, "暂 停", 42, Color(0.9, 0.84, 0.7, 0.96), font_title)
	_center_text(320, "Esc  继续梦行", 12, Color(0.76, 0.8, 0.84, 0.9))
	_center_text(346, "R  从残梦灯重开（保留已收集记忆）", 11, Color(0.62, 0.68, 0.74, 0.8))
	_center_text(394, "WASD 移动    Tab 锁定    左键 轻击/重击    右键 弹反    Space 闪避    Q 回梦    E 交互/遗物", 10, Color(0.55, 0.63, 0.7, 0.8))


# ------------------------------------------------------------------ 绘图助手

func _panel(rect: Rect2) -> void:
	draw_rect(rect, COL_BG)
	draw_rect(rect, COL_BORDER, false, 1.0)
	draw_line(rect.position + Vector2(8, -1), rect.position + Vector2(36, -1), Color(0.9, 0.74, 0.45, 0.75), 2.0)
	draw_line(rect.position + Vector2(rect.size.x - 36, rect.size.y), rect.position + Vector2(rect.size.x - 8, rect.size.y), Color(0.9, 0.74, 0.45, 0.45), 1.0)
	draw_line(rect.position + Vector2(1, 18), rect.position + Vector2(1, rect.size.y - 18), Color(0.75, 0.6, 0.38, 0.35), 1.0)


func _bar(rect: Rect2, ratio: float, color: Color, label := "", value_text := "", font_size := 0) -> void:
	draw_rect(rect, Color(0.02, 0.03, 0.05, 0.9))
	var inset := rect.grow(-1.0)
	var fill_w := maxf(0.0, inset.size.x * clampf(ratio, 0.0, 1.0))
	draw_rect(Rect2(inset.position, Vector2(fill_w, inset.size.y)), color)
	draw_rect(Rect2(inset.position, Vector2(fill_w, maxf(1.0, inset.size.y * 0.28))), Color(1, 1, 1, 0.18))
	draw_rect(rect, Color(0.75, 0.64, 0.45, 0.5), false, 1.0)
	for i in range(1, 10):
		var x := rect.position.x + rect.size.x * float(i) / 10.0
		draw_line(Vector2(x, rect.position.y + 2), Vector2(x, rect.position.y + rect.size.y - 2), Color(0, 0, 0, 0.2), 1.0)
	if font_size > 0:
		if label != "":
			_text(Vector2(rect.position.x + 4, rect.position.y + rect.size.y - 4), label, font_size, Color(0.98, 0.96, 0.9, 0.9))
		if value_text != "":
			_text(Vector2(rect.position.x + rect.size.x - 124, rect.position.y + rect.size.y - 4), value_text, font_size, Color(0.98, 0.96, 0.9, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 120)


func _text(pos: Vector2, text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, font: Font = null) -> void:
	var used_font: Font = font if font != null else font_ui
	draw_string(used_font, pos + Vector2(1, 1), text, align, width, font_size, Color(0.01, 0.01, 0.02, color.a * 0.75))
	draw_string(used_font, pos, text, align, width, font_size, color)


func _center_text(y: float, text: String, font_size: int, color: Color, font: Font = null) -> void:
	_text(Vector2(0, y), text, font_size, color, HORIZONTAL_ALIGNMENT_CENTER, W, font)
