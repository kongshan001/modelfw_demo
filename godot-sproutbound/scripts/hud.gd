extends Control
class_name SproutHUD

## 苔野远行 HUD：气血 / 目标 / 击杀 / 草籽 / FPS / 连斩 / 敌人血条 /
## 传送门指引 / 调试面板 / 暂停 / 胜利 / 失败 / 标题。全部自绘 + 系统 CJK 字体。

const MAX_W := 1280.0
const MAX_H := 720.0

const PAPER := SproutStyle.PAPER
const MINT := SproutStyle.MINT
const AMBER := SproutStyle.AMBER
const CORAL := SproutStyle.CORAL
const TEAL := SproutStyle.TEAL
const DIM := Color(0.68, 0.75, 0.66)
const PANEL := SproutStyle.PANEL
const DEEP := Color(0.035, 0.08, 0.055, 0.86)

const STATE_CN := {
	"idle": "待机", "patrol": "巡逻", "alert": "警觉", "chase": "追击",
	"windup": "前摇", "strike": "出招", "recover": "硬直", "hurt": "受击",
	"dead": "消散", "return": "回巢",
}

var main: Node
var font: SystemFont
var toast_text := ""
var toast_timer := 0.0
var hurt_flash := 0.0
var combo_pulse := 0.0
var dodge_pulse := 0.0

var _t := 0.0
var _panel_style: StyleBoxFlat
var _panel_soft: StyleBoxFlat
var _panel_dark: StyleBoxFlat
var _bar_bg: StyleBoxFlat


func _ready() -> void:
	name = "HUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = SproutStyle.cjk()
	size = Vector2(MAX_W, MAX_H)
	position = Vector2.ZERO
	_panel_style = _make_style(PANEL, 10, Color(0.58, 0.82, 0.60, 0.22), 1)
	_panel_soft = _make_style(SproutStyle.PANEL_SOFT, 8, Color(0.58, 0.82, 0.60, 0.14), 1)
	_panel_dark = _make_style(DEEP, 16, Color(0.66, 0.92, 0.68, 0.32), 2)
	_bar_bg = _make_style(Color(0.03, 0.06, 0.04, 0.85), 4, Color(0.5, 0.7, 0.5, 0.2), 1)
	_update_scale()


func _make_style(bg: Color, radius: int, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0.0, 3.0)
	s.content_margin_left = 0.0
	s.content_margin_top = 0.0
	s.content_margin_right = 0.0
	s.content_margin_bottom = 0.0
	return s


func _process(delta: float) -> void:
	_t += delta
	toast_timer = maxf(0.0, toast_timer - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta * 2.4)
	combo_pulse = maxf(0.0, combo_pulse - delta * 3.0)
	dodge_pulse = maxf(0.0, dodge_pulse - delta * 1.8)
	_update_scale()
	queue_redraw()


func _update_scale() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var s := minf(vp.x / MAX_W, vp.y / MAX_H)
	if absf(scale.x - s) > 0.001:
		scale = Vector2(s, s)


# ------------------------------------------------------------------ public

func show_toast(text: String, seconds: float = 2.2) -> void:
	toast_text = text
	toast_timer = seconds


func flash_hurt() -> void:
	hurt_flash = 1.0


func pulse_combo() -> void:
	combo_pulse = 1.0


func show_dodge_pulse() -> void:
	dodge_pulse = 1.0


func clear_overlays() -> void:
	hurt_flash = 0.0
	combo_pulse = 0.0
	dodge_pulse = 0.0
	toast_text = ""
	toast_timer = 0.0


# -------------------------------------------------------------------- draw

func _draw() -> void:
	if main == null or main.player == null:
		return
	if main.game_state == "title":
		_draw_title()
		return

	if main.game_state in ["victory", "defeat"]:
		if main.game_state == "victory":
			_draw_victory()
		else:
			_draw_defeat()
		if main.debug_view:
			_draw_debug()
		return

	_draw_hurt_flash()
	_draw_player_panel()
	_draw_objective()
	_draw_stats()
	_draw_combo()
	_draw_enemy_bars()
	_draw_portal_marker()
	_draw_controls()
	_draw_toast()
	_draw_dodge_pulse()

	if main.game_state == "paused":
		_draw_pause()

	if main.debug_view:
		_draw_debug()


func _layout_for(pos: Vector2, align: int, width: float) -> Array:
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		var w := width if width >= 0.0 else 1000.0
		return [Vector2(pos.x - w * 0.5, pos.y), w]
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		var w2 := width if width >= 0.0 else 300.0
		return [Vector2(pos.x - w2, pos.y), w2]
	if width >= 0.0:
		return [pos, width]
	return [pos, -1.0]


func _text(pos: Vector2, text: String, size_px: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var lay := _layout_for(pos, align, width)
	draw_string(font, lay[0], text, align, lay[1], size_px, color)


func _text_shadow(pos: Vector2, text: String, size_px: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var lay := _layout_for(pos, align, width)
	var sh := Color(0.02, 0.05, 0.03, color.a * 0.8)
	draw_string(font, lay[0] + Vector2(2.0, 3.0), text, align, lay[1], size_px, sh)
	draw_string(font, lay[0], text, align, lay[1], size_px, color)


func _panel(rect: Rect2, style: StyleBoxFlat = null) -> void:
	draw_style_box(style if style != null else _panel_style, rect)


func _fmt_time(t: float) -> String:
	var total := int(t)
	return "%02d:%02d" % [total / 60, total % 60]


# ---------------------------------------------------------------- world HUD

func _draw_player_panel() -> void:
	var r := Rect2(24.0, 20.0, 322.0, 96.0)
	_panel(r)
	var p = main.player
	# 叶片图标
	var leaf_green := Color(0.56, 0.83, 0.48)
	draw_circle(Vector2(54.0, 51.0), 13.0, Color(0.10, 0.19, 0.12, 0.9))
	draw_circle(Vector2(51.0, 53.0), 7.5, leaf_green)
	var pts := PackedVector2Array([
		Vector2(51.0, 59.0), Vector2(61.0, 40.0), Vector2(65.0, 48.0),
		Vector2(58.0, 59.0),
	])
	draw_colored_polygon(pts, Color(0.70, 0.90, 0.52))
	draw_line(Vector2(51.0, 59.0), Vector2(58.0, 44.0), Color(0.17, 0.32, 0.16), 1.5)

	_text(Vector2(76.0, 49.0), "芽行者", 19, PAPER)
	_text(Vector2(148.0, 48.0), "· 苔径旅人", 12, DIM)

	var ratio: float = clampf(float(p.hp) / float(SproutPlayer.MAX_HP), 0.0, 1.0)
	var bar := Rect2(76.0, 60.0, 238.0, 16.0)
	draw_style_box(_bar_bg, bar)
	var hp_col := Color(0.48, 0.80, 0.42)
	if ratio < 0.55:
		hp_col = Color(0.92, 0.72, 0.30)
	if ratio < 0.28:
		hp_col = Color(0.92, 0.36, 0.28)
	if ratio > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), hp_col, true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 4.0)),
			Color(1.0, 1.0, 0.9, 0.28), true)
	# 50% 刻度
	draw_line(Vector2(bar.position.x + bar.size.x * 0.5, bar.position.y),
		Vector2(bar.position.x + bar.size.x * 0.5, bar.position.y + bar.size.y),
		Color(0.05, 0.08, 0.05, 0.5), 1.0)
	_text(Vector2(76.0, 93.0), "生命 %d / %d" % [p.hp, SproutPlayer.MAX_HP], 11, DIM)
	var state_cn: String = "待机"
	match String(p.state):
		"move":
			state_cn = "行走"
		"sprint":
			state_cn = "疾跑"
		"attack":
			state_cn = "挥剑"
		"dodge":
			state_cn = "闪避"
		"air":
			state_cn = "腾跃"
		"hurt":
			state_cn = "受击"
		"dead":
			state_cn = "倒下"
	_text(Vector2(314.0, 93.0), state_cn, 11, MINT if p.state != "dead" else CORAL,
		HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_objective() -> void:
	var w := 416.0
	var r := Rect2(640.0 - w * 0.5, 20.0, w, 68.0)
	_panel(r)
	draw_rect(Rect2(r.position + Vector2(0.0, 10.0), Vector2(4.0, 48.0)),
		AMBER if main.portal_active else MINT, true)
	_text(Vector2(640.0, 43.0), "目 标", 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	if main.portal_active:
		_text_shadow(Vector2(640.0, 66.0), "石拱门已开启", 21, AMBER,
			HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(640.0, 82.0), "前往北端 · 走入光门完成远行", 11, DIM,
			HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_text_shadow(Vector2(640.0, 66.0),
			"清除菌怪   %d / %d" % [main.kills, main.total_enemies], 21, PAPER,
			HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(640.0, 82.0), "菌怪散尽后，石拱门会重新亮起", 11, DIM,
			HORIZONTAL_ALIGNMENT_CENTER)


func _draw_stats() -> void:
	var r := Rect2(1008.0, 20.0, 248.0, 96.0)
	_panel(r)
	# 草籽图标
	draw_circle(Vector2(1028.0, 41.0), 7.0, Color(0.96, 0.78, 0.32))
	draw_circle(Vector2(1028.0, 38.0), 4.0, Color(0.75, 0.90, 0.45))
	_text(Vector2(1042.0, 46.0), "草籽  %d / %d" % [
		main.seeds_collected, main.total_seeds], 14, PAPER)
	_text(Vector2(1042.0, 67.0), "时间  %s" % _fmt_time(main.time_elapsed), 12, DIM)
	var fps := int(main.get_fps())
	var fps_col := MINT if fps >= 30 else CORAL
	_text(Vector2(1232.0, 46.0), "%d FPS" % fps, 13, fps_col,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(1042.0, 88.0), "击倒  %d / %d" % [main.kills, main.total_enemies],
		12, DIM)
	_text(Vector2(1232.0, 88.0), "F1 调试", 10, Color(0.5, 0.6, 0.51),
		HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_combo() -> void:
	if main.combo < 2:
		return
	var pulse := 1.0 + combo_pulse * 0.22
	var alpha := 1.0
	if main.combo_timer < 0.5:
		alpha = clampf(main.combo_timer / 0.5, 0.0, 1.0)
	var x := 44.0
	var y := 648.0
	_text_shadow(Vector2(x, y), "×%d" % main.combo, int(46 * pulse),
		Color(1.0, 0.80, 0.36, alpha))
	_text(Vector2(x + 2.0, y + 20.0), "连斩", 12, Color(0.9, 0.85, 0.7, alpha))
	if main.combo_timer > 0.0:
		var w := 96.0 * clampf(main.combo_timer / 2.6, 0.0, 1.0)
		draw_rect(Rect2(x, y + 26.0, w, 3.0), Color(1.0, 0.8, 0.4, 0.5 * alpha), true)


func _draw_enemy_bars() -> void:
	if main.camera == null:
		return
	for e in main.enemies:
		if not is_instance_valid(e) or not e.is_alive() or not e.visible:
			continue
		if e.state in ["idle", "patrol", "return"] and e.hp >= e.max_hp:
			continue
		var dist: float = e.global_position.distance_to(main.player.global_position)
		if dist > 20.0:
			continue
		var head: Vector3 = e.global_position + Vector3(0.0, 2.0 * e.body_scale, 0.0)
		if main.camera.is_position_behind(head):
			continue
		var sp: Vector2 = main.camera.unproject_position(head)
		if sp.x < -20.0 or sp.x > 1300.0 or sp.y < -20.0 or sp.y > 740.0:
			continue
		var wide := 86.0 if e.kind == "warden" else 62.0
		var ratio: float = clampf(float(e.hp) / float(e.max_hp), 0.0, 1.0)
		var col: Color = CORAL
		if e.kind == "spitter":
			col = TEAL
		elif e.kind == "warden":
			col = Color(0.76, 0.70, 0.40)
		var name_col := Color(0.95, 0.92, 0.82)
		_text(Vector2(sp.x, sp.y - 8.0),
			"%s · %s" % [e.display_name, STATE_CN.get(e.state, e.state)],
			10, name_col, HORIZONTAL_ALIGNMENT_CENTER, wide)
		draw_rect(Rect2(sp.x - wide * 0.5, sp.y, wide, 6.0),
			Color(0.03, 0.06, 0.04, 0.82), true)
		if ratio > 0.0:
			draw_rect(Rect2(sp.x - wide * 0.5, sp.y, wide * ratio, 6.0), col, true)
		# 前摇时在血条上方加警示条
		if e.state == "windup":
			draw_rect(Rect2(sp.x - wide * 0.5, sp.y - 3.0, wide, 2.0),
				Color(1.0, 0.72, 0.3, 0.8), true)


func _draw_portal_marker() -> void:
	if not main.portal_active or main.game_state != "playing":
		return
	var portal: Vector3 = main.world.get_portal_pos() + Vector3(0.0, 5.2, 0.0)
	if main.camera.is_position_behind(portal):
		return
	var sp: Vector2 = main.camera.unproject_position(portal)
	if sp.x < 30.0 or sp.x > 1250.0 or sp.y < 90.0 or sp.y > 690.0:
		return
	var pulse := 0.85 + 0.15 * sin(_t * 3.2)
	var c := Color(0.62, 1.0, 0.76, pulse)
	var pts := PackedVector2Array([
		sp + Vector2(0.0, -14.0), sp + Vector2(10.0, 0.0),
		sp + Vector2(0.0, 14.0), sp + Vector2(-10.0, 0.0),
	])
	draw_colored_polygon(pts, Color(0.62, 1.0, 0.76, 0.22 * pulse))
	var loop := PackedVector2Array(pts)
	loop.append(pts[0])
	draw_polyline(loop, c, 1.5, true)
	var dist := Vector2(main.player.global_position.x - main.world.get_portal_pos().x,
		main.player.global_position.z - main.world.get_portal_pos().z).length()
	_text(Vector2(sp.x, sp.y + 30.0), "石拱门 · %dm" % int(dist), 11, c,
		HORIZONTAL_ALIGNMENT_CENTER, 140.0)


func _draw_controls() -> void:
	var r := Rect2(938.0, 596.0, 318.0, 100.0)
	_panel(r, _panel_soft)
	var lines := [
		"WASD 移动   ·   鼠标 视角",
		"左键 连斩   ·   右键 闪避",
		"空格 跳跃   ·   Shift 疾跑",
		"滚轮 缩放   ·   Esc 暂停 / F1 调试",
	]
	for i in lines.size():
		_text(Vector2(954.0, 622.0 + i * 19.0), lines[i], 11,
			Color(0.78, 0.84, 0.74))


func _draw_toast() -> void:
	if toast_timer <= 0.0 or toast_text == "":
		return
	var alpha := clampf(toast_timer / 0.35, 0.0, 1.0)
	var w := 540.0
	var r := Rect2(640.0 - w * 0.5, 552.0, w, 38.0)
	draw_style_box(_panel_dark, r)
	_text(Vector2(640.0, 577.0), toast_text, 15,
		Color(0.94, 0.90, 0.76, alpha), HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_dodge_pulse() -> void:
	if dodge_pulse <= 0.0:
		return
	var alpha := clampf(dodge_pulse, 0.0, 1.0)
	_text(Vector2(640.0, 512.0), "闪 避", 18,
		Color(0.64, 0.96, 0.72, alpha * 0.85), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_hurt_flash() -> void:
	var low := 0.0
	var ratio: float = float(main.player.hp) / float(SproutPlayer.MAX_HP)
	if ratio < 0.3 and not main.player.dead:
		low = (0.5 + 0.5 * sin(_t * 4.0)) * (1.0 - ratio / 0.3)
	var v := maxf(hurt_flash * 0.5, low * 0.4)
	if v <= 0.001:
		return
	var edge := Color(0.72, 0.12, 0.08, 0.20 * v)
	draw_rect(Rect2(0.0, 0.0, 1280.0, 26.0), edge, true)
	draw_rect(Rect2(0.0, 694.0, 1280.0, 26.0), edge, true)
	draw_rect(Rect2(0.0, 0.0, 26.0, 720.0), edge, true)
	draw_rect(Rect2(1254.0, 0.0, 26.0, 720.0), edge, true)
	if hurt_flash > 0.4:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)),
			Color(0.55, 0.08, 0.05, 0.10 * hurt_flash), true)


# ------------------------------------------------------------------ overlays

func _draw_title() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.02, 0.06, 0.035, 0.36), true)
	var r := Rect2(300.0, 108.0, 680.0, 516.0)
	draw_style_box(_panel_dark, r)
	_text(Vector2(640.0, 156.0), "S P R O U T B O U N D", 15,
		Color(0.62, 0.90, 0.68, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	_text_shadow(Vector2(640.0, 246.0), "苔 野 远 行", 58, PAPER,
		HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(640.0, 286.0), "原创低多边形 3D 动作 · 菌怪盘踞的向阳草甸", 17,
		Color(0.82, 0.88, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	# 分隔叶线
	draw_line(Vector2(474.0, 316.0), Vector2(806.0, 316.0),
		Color(0.55, 0.78, 0.56, 0.4), 1.0)
	draw_circle(Vector2(640.0, 316.0), 3.0, Color(0.65, 0.9, 0.6, 0.8))

	var pulse := 0.7 + 0.3 * sin(_t * 2.6)
	_text_shadow(Vector2(640.0, 376.0), "按 Enter 或点击鼠标左键 开始",
		22, Color(1.0, 0.84, 0.44, pulse), HORIZONTAL_ALIGNMENT_CENTER)

	var ctrl := Rect2(356.0, 406.0, 568.0, 118.0)
	_panel(ctrl, _panel_soft)
	var left := [
		"WASD    移动", "鼠标    视角", "左键    三段连斩", "右键    闪避（无敌帧）",
	]
	var right := [
		"空格    跳跃", "Shift   疾跑", "滚轮    拉近 / 拉远", "Esc/F1  暂停 / 调试",
	]
	for i in left.size():
		_text(Vector2(382.0, 434.0 + i * 22.0), left[i], 12, Color(0.85, 0.88, 0.78))
		_text(Vector2(676.0, 434.0 + i * 22.0), right[i], 12, Color(0.85, 0.88, 0.78))
	_text(Vector2(640.0, 552.0),
		"目标：清除草甸里的 10 只菌怪，让北端石拱门重新亮起", 13,
		Color(0.95, 0.86, 0.64), HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(640.0, 578.0),
		"草籽与回春露散落在草甸各处；倒下了就按 R 再来一次", 11, DIM,
		HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(640.0, 690.0),
		"原创原型 · 与参考视频及其作者无关 · 模型 / 场景 / UI 均为程序化原创 · Godot 4.6 GL Compatibility",
		10, Color(0.62, 0.68, 0.60), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_pause() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.02, 0.05, 0.03, 0.55), true)
	var r := Rect2(420.0, 250.0, 440.0, 218.0)
	draw_style_box(_panel_dark, r)
	_text_shadow(Vector2(640.0, 312.0), "已 暂 停", 32, PAPER,
		HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(640.0, 354.0), "草甸会在这里等你", 13, DIM,
		HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(640.0, 402.0), "Esc  继续远行", 17, MINT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(640.0, 432.0), "R  重新开始", 15, Color(0.9, 0.84, 0.7),
		HORIZONTAL_ALIGNMENT_CENTER)


func _draw_defeat() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.06, 0.02, 0.02, 0.55), true)
	var r := Rect2(400.0, 230.0, 480.0, 266.0)
	draw_style_box(_panel_dark, r)
	_text_shadow(Vector2(640.0, 294.0), "苔 芽 倒 下 了", 34, CORAL,
		HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(640.0, 336.0), "菌怪的低语漫过草甸，但种子还在土里", 13, DIM,
		HORIZONTAL_ALIGNMENT_CENTER)
	var s: Dictionary = main.get_play_stats()
	_text(Vector2(640.0, 390.0), "坚持 %s   ·   击倒 %d / %d" % [
		_fmt_time(float(s.time)), int(s.kills), int(s.total)], 16, PAPER,
		HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(640.0, 424.0), "草籽 %d · 最高连斩 %d" % [
		int(s.seeds), int(s.max_combo)], 13, Color(0.8, 0.82, 0.72),
		HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(640.0, 468.0), "R  重新出发", 18,
		Color(1.0, 0.84, 0.44, 0.75 + 0.25 * sin(_t * 3.0)),
		HORIZONTAL_ALIGNMENT_CENTER)


func _draw_victory() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.02, 0.08, 0.045, 0.48), true)
	var r := Rect2(376.0, 196.0, 528.0, 344.0)
	draw_style_box(_panel_dark, r)
	_text(Vector2(640.0, 252.0), "S P R O U T B O U N D", 12,
		Color(0.62, 0.90, 0.68, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	_text_shadow(Vector2(640.0, 316.0), "草 甸 重 归 宁 静", 38, MINT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(640.0, 354.0), "石拱门在你身后轻轻合拢，光落回苔叶上", 13, DIM,
		HORIZONTAL_ALIGNMENT_CENTER)
	var s: Dictionary = main.get_play_stats()
	var rows := [
		["用时", _fmt_time(float(s.time))],
		["击倒菌怪", "%d / %d" % [int(s.kills), int(s.total)]],
		["拾得草籽", "%d / %d" % [int(s.seeds), int(s.total_seeds)]],
		["最高连斩", "×%d" % int(s.max_combo)],
		["承受伤害", str(int(s.damage_taken))],
	]
	for i in rows.size():
		var y := 400.0 + i * 24.0
		var col: Color = Color(0.82, 0.88, 0.76) if i % 2 == 0 \
			else Color(0.88, 0.88, 0.78)
		_text(Vector2(476.0, y), String(rows[i][0]), 13, DIM)
		_text(Vector2(804.0, y), String(rows[i][1]), 14, col,
			HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(640.0, 516.0), "R  再走一遍", 16,
		Color(1.0, 0.86, 0.5, 0.75 + 0.25 * sin(_t * 2.8)),
		HORIZONTAL_ALIGNMENT_CENTER)


# -------------------------------------------------------------------- debug

func _draw_debug() -> void:
	var r := Rect2(24.0, 130.0, 386.0, 214.0)
	_panel(r, _panel_soft)
	_text(Vector2(40.0, 154.0), "调试视图 · F1 关闭", 13, AMBER)
	var p = main.player
	var dodge_ready := "就绪" if p.dodge_cd <= 0.0 else "%.2fs" % p.dodge_cd
	_text(Vector2(40.0, 177.0), "玩家 %s · HP %d · 速度 %.1f" % [
		p.state, p.hp, Vector2(p.velocity.x, p.velocity.z).length()], 11, PAPER)
	_text(Vector2(40.0, 195.0), "无敌帧 %.2f · 闪避 %s · 连段 %d" % [
		p.invuln_t, dodge_ready, p.combo_step], 11, PAPER)
	var alive := 0
	var chasing := 0
	var winding := 0
	var nearest: String = "无"
	var near_d := 9999.0
	for e in main.enemies:
		if not is_instance_valid(e):
			continue
		if e.is_alive():
			alive += 1
		if e.state in ["alert", "chase", "windup", "strike", "recover", "hurt"]:
			chasing += 1
		if e.state == "windup":
			winding += 1
		var d: float = e.global_position.distance_to(p.global_position)
		if e.is_alive() and d < near_d:
			near_d = d
			nearest = "%s[%s] %.1fm" % [e.display_name, STATE_CN.get(e.state, e.state), d]
	_text(Vector2(40.0, 213.0), "敌人 存活 %d / %d · 交战 %d · 前摇 %d" % [
		alive, main.total_enemies, chasing, winding], 11, PAPER)
	_text(Vector2(40.0, 231.0), "最近：%s" % nearest, 11, PAPER)
	var draw_calls := int(Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(
		Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_text(Vector2(40.0, 249.0), "帧率 %d · draw calls %d · 三角形 %d" % [
		main.get_fps(), draw_calls, prims], 11, PAPER)
	_text(Vector2(40.0, 267.0), "相机 yaw %.2f · pitch %.2f · dist %.1f" % [
		main.cam_yaw, main.cam_pitch, main.cam_dist], 11, PAPER)
	var portal_txt := "已开启" if main.portal_active else "沉睡"
	_text(Vector2(40.0, 285.0), "石拱门 %s · 草籽 %d / %d · 连斩 %d" % [
		portal_txt, main.seeds_collected, main.total_seeds, main.combo], 11, PAPER)
	_text(Vector2(40.0, 307.0), "半透明胶囊 = 角色碰撞体（自绘）", 10, DIM)
	_text(Vector2(40.0, 325.0), "范围环 = 攻击距离 / 前摇判定（自绘）", 10, DIM)
