class_name MistHud
extends Control
## 中文战术 HUD：波次、房屋防线、队伍卡、暂停/倍速、胜负结算与原创开场页。
## 所有面板与图标均为 draw_* 程序化绘制。

const UI = preload("res://scripts/ui_style.gd")
const Balance = preload("res://scripts/balance.gd")

const CARD_W := 244.0
const CARD_H := 100.0
const CARD_Y := 600.0
const CARD_GAP := 12.0

var game
var start_btn: Button
var pause_btn: Button
var speed_btn: Button
var resume_btn: Button
var pause_restart_btn: Button
var result_primary_btn: Button
var result_restart_btn: Button

var _hover_card := -1
var _built := false


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_buttons()
	_built = true


func _build_buttons() -> void:
	start_btn = UI.make_button("开始布防", Rect2(106, 520, 196, 46), UI.AMBER, 18)
	start_btn.pressed.connect(_on_start)
	add_child(start_btn)

	pause_btn = UI.make_button("暂停", Rect2(1042, 12, 84, 38), UI.PANEL_SOFT, 13, true)
	pause_btn.pressed.connect(_on_pause)
	add_child(pause_btn)

	speed_btn = UI.make_button("速度 1×", Rect2(1134, 12, 104, 38), UI.PANEL_SOFT, 13, true)
	speed_btn.pressed.connect(_on_speed)
	add_child(speed_btn)

	resume_btn = UI.make_button("继续", Rect2(486, 396, 140, 42), UI.AMBER, 16)
	resume_btn.pressed.connect(_on_resume)
	add_child(resume_btn)

	pause_restart_btn = UI.make_button("重开本岛", Rect2(654, 396, 140, 42), UI.PANEL_SOFT, 15, true)
	pause_restart_btn.pressed.connect(_on_restart)
	add_child(pause_restart_btn)

	result_primary_btn = UI.make_button("登船 · 前往下一岛", Rect2(398, 506, 250, 44), UI.AMBER, 16)
	result_primary_btn.pressed.connect(_on_result_primary)
	add_child(result_primary_btn)

	result_restart_btn = UI.make_button("重开本局", Rect2(664, 506, 168, 44), UI.PANEL_SOFT, 15, true)
	result_restart_btn.pressed.connect(_on_restart)
	add_child(result_restart_btn)


func _process(_delta: float) -> void:
	if not _built:
		return
	if game == null:
		_show_buttons(false, false, false, false)
		return
	var state: String = game.state
	var playing := state == "playing"
	var paused: bool = game.paused
	var intro := state == "intro"
	var result := state == "victory" or state == "defeat"
	start_btn.visible = intro
	pause_btn.visible = playing
	speed_btn.visible = playing
	pause_btn.text = "继续" if paused else "暂停"
	speed_btn.text = "速度 2×" if game.speed_index == 1 else "速度 1×"
	resume_btn.visible = playing and paused
	pause_restart_btn.visible = playing and paused
	result_primary_btn.visible = result
	result_restart_btn.visible = result and state == "victory"
	if result:
		if state == "victory":
			result_primary_btn.text = "登船 · 前往下一岛" if game.has_next_island() else "再来一局"
		else:
			result_primary_btn.text = "重新布防"
	_hover_card = -1
	var mouse := get_local_mouse_position()
	if playing and not paused:
		for i in range(game.squads.size()):
			if _card_rect(i).has_point(mouse):
				_hover_card = i
	queue_redraw()


func _show_buttons(a: bool, b: bool, c: bool, d: bool) -> void:
	start_btn.visible = a
	pause_btn.visible = b
	speed_btn.visible = b
	resume_btn.visible = c
	pause_restart_btn.visible = c
	result_primary_btn.visible = d
	result_restart_btn.visible = d


func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	var state: String = game.state
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return
	if state == "intro" or state == "victory" or state == "defeat" or game.paused:
		if event is InputEventMouseButton and event.pressed:
			accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for i in range(game.squads.size()):
			if _card_rect(i).has_point(event.position):
				game.select_squad_index(i, true)
				accept_event()
				return
		for panel in [Rect2(24, 90, 330, 54), Rect2(475, 14, 330, 66), Rect2(802, 590, 458, 110)]:
			if panel.has_point(event.position):
				accept_event()
				return


func _card_rect(index: int) -> Rect2:
	return Rect2(Vector2(20.0 + float(index) * (CARD_W + CARD_GAP), CARD_Y), Vector2(CARD_W, CARD_H))


func is_blocking_point(pos: Vector2) -> bool:
	if game == null:
		return true
	if game.state != "playing" or game.paused:
		return true
	for i in range(game.squads.size()):
		if _card_rect(i).has_point(pos):
			return true
	for panel in [Rect2(24, 90, 330, 54), Rect2(475, 14, 330, 66), Rect2(802, 590, 458, 110)]:
		if panel.has_point(pos):
			return true
	for button in [start_btn, pause_btn, speed_btn, resume_btn, pause_restart_btn, result_primary_btn, result_restart_btn]:
		if button != null and button.visible and button.get_global_rect().has_point(pos):
			return true
	return false


func _draw() -> void:
	if game == null:
		return
	if game.state == "intro":
		_draw_intro()
		return
	_draw_top()
	_draw_banner()
	_draw_squad_cards()
	_draw_help()
	if game.state == "playing" and game.paused:
		_draw_pause()
	if game.state == "victory" or game.state == "defeat":
		_draw_result()
	if game.selecting:
		var rect: Rect2 = game.selection_rect
		draw_rect(rect, Color(0.91, 0.70, 0.37, 0.10), true)
		draw_rect(rect, Color(0.91, 0.70, 0.37, 0.85), false, 1.0)


func _draw_top() -> void:
	# 品牌 + 岛名
	UI.draw_text(self, Vector2(24, 34), "雾屿守望", 22, UI.TEXT, true)
	UI.draw_text(self, Vector2(24, 50), "MISTBOUND WATCH", 8, UI.AMBER)
	var island_name := ""
	var island_sub := ""
	if game.island != null:
		island_name = str(game.island.data["name"])
		island_sub = str(game.island.data["subtitle"])
	UI.draw_text(self, Vector2(24, 74), "%s · %s" % [island_name, island_sub], 13, UI.DIM)

	# 房屋防线
	var hx := 24.0
	var hy := 90.0
	UI.draw_bracket_panel(self, Rect2(hx, hy, 330, 54), Color(0.04, 0.09, 0.10, 0.75), UI.BORDER_SOFT)
	var alive_houses: int = game.houses_alive()
	var total_houses: int = game.houses_total()
	UI.draw_text(self, Vector2(hx + 12, hy + 20), "防线", 11, UI.AMBER, true)
	UI.draw_text(self, Vector2(hx + 46, hy + 20), "房屋 %d / %d" % [alive_houses, total_houses], 13, UI.TEXT, true)
	for i in range(game.houses.size()):
		var house = game.houses[i]
		var x := hx + 150.0 + float(i) * 58.0
		var ratio := 0.0 if house.destroyed else clampf(house.hp / house.max_hp, 0.0, 1.0)
		_draw_house_icon(Vector2(x, hy + 18), 18.0, ratio, house.destroyed)
		UI.draw_bar(self, Rect2(x - 16, hy + 38, 46, 5), ratio, UI.GREEN.lerp(UI.RED, 1.0 - ratio))

	# 波次面板
	var rect := Rect2(475, 14, 330, 66)
	UI.draw_bracket_panel(self, rect, Color(0.04, 0.09, 0.10, 0.84), UI.BORDER_SOFT)
	UI.draw_center(self, Rect2(rect.position.x, rect.position.y + 7, rect.size.x, 24), "第 %d / %d 波" % [game.wave_number, game.waves_total], 19, UI.TEXT, true)
	var status := ""
	if game.state == "playing":
		if game.wave_state == "prep":
			status = "布防倒计时 %02d 秒" % int(ceil(game.prep_timer))
		elif game.wave_state == "active":
			status = "登陆中 · 敌 %d" % game.enemies_remaining()
		else:
			status = "海面暂平"
	UI.draw_center(self, Rect2(rect.position.x, rect.position.y + 34, rect.size.x, 18), status, 12, UI.AMBER if game.wave_state == "prep" else UI.DIM)
	var progress := clampf(float(game.waves_cleared) / float(maxi(1, game.waves_total)), 0.0, 1.0)
	UI.draw_bar(self, Rect2(rect.position.x + 18, rect.position.y + 54, rect.size.x - 36, 4), progress, UI.SEA)



func _draw_house_icon(center: Vector2, s: float, ratio: float, destroyed: bool) -> void:
	var body_color := Color("5b4a3b") if destroyed else Color("d8c9a4")
	var roof_color := Color("7d3f34") if destroyed else Color("b85c43")
	draw_rect(Rect2(center + Vector2(-s * 0.55, -s * 0.15), Vector2(s * 1.1, s * 0.7)), body_color, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-s * 0.78, -s * 0.15),
		center + Vector2(0, -s * 0.85),
		center + Vector2(s * 0.78, -s * 0.15),
	]), roof_color)
	if destroyed:
		draw_line(center + Vector2(-s * 0.5, -s * 0.5), center + Vector2(s * 0.45, s * 0.35), Color("d96a55"), 1.5)
		draw_line(center + Vector2(s * 0.5, -s * 0.5), center + Vector2(-s * 0.45, s * 0.35), Color("d96a55"), 1.5)
	else:
		draw_rect(Rect2(center + Vector2(-s * 0.12, s * 0.1), Vector2(s * 0.24, s * 0.42)), Color("5b4332"), true)
		draw_rect(Rect2(center + Vector2(-s * 0.4, 0), Vector2(s * 0.2, s * 0.18)), Color("f6c66e"), true)


func _draw_banner() -> void:
	if game.banner_timer <= 0.0 or game.banner_text == "":
		return
	var alpha := clampf(game.banner_timer / 0.35, 0.0, 1.0)
	var rect := Rect2(372, 112, 536, 62)
	draw_rect(rect, Color(0.03, 0.08, 0.09, 0.82 * alpha), true)
	draw_rect(Rect2(rect.position.x, rect.position.y, 4, rect.size.y), Color(0.91, 0.70, 0.37, alpha), true)
	UI.draw_center(self, Rect2(rect.position.x, rect.position.y + 8, rect.size.x, 26), game.banner_text, 21, Color(UI.TEXT.r, UI.TEXT.g, UI.TEXT.b, alpha), true)
	if game.banner_sub != "":
		UI.draw_center(self, Rect2(rect.position.x, rect.position.y + 34, rect.size.x, 18), game.banner_sub, 12, Color(UI.DIM.r, UI.DIM.g, UI.DIM.b, alpha))


func _draw_squad_cards() -> void:
	for i in range(game.squads.size()):
		var squad = game.squads[i]
		var rect := _card_rect(i)
		var selected: bool = game.selected_squads.has(squad)
		var hovered := i == _hover_card
		var fill := Color(0.04, 0.10, 0.105, 0.90) if squad.alive else Color(0.05, 0.07, 0.075, 0.86)
		draw_rect(rect, fill, true)
		var border := UI.AMBER if selected else (UI.BORDER_SOFT if not hovered else UI.SEA)
		draw_rect(rect, border, false, 1.5 if selected else 1.0)
		if selected:
			draw_rect(Rect2(rect.position.x, rect.position.y, 4, rect.size.y), UI.AMBER, true)

		var color: Color = UI.class_color(squad.class_id)
		UI.draw_class_icon(self, rect.position + Vector2(36, 46), 22.0, squad.class_id, color if squad.alive else UI.DIM.darkened(0.3))
		UI.draw_text(self, rect.position + Vector2(64, 26), str(squad.data["name"]), 18, UI.TEXT if squad.alive else UI.DIM, true)
		UI.draw_text(self, rect.position + Vector2(64, 42), str(squad.data["title"]), 11, UI.DIM)
		var hotkey := str(i + 1)
		draw_rect(Rect2(rect.position + Vector2(rect.size.x - 26, 8), Vector2(18, 18)), Color(0.08, 0.16, 0.17, 0.95), true)
		draw_rect(Rect2(rect.position + Vector2(rect.size.x - 26, 8), Vector2(18, 18)), UI.BORDER, false, 1.0)
		UI.draw_center(self, Rect2(rect.position + Vector2(rect.size.x - 26, 8), Vector2(18, 18)), hotkey, 11, UI.AMBER, true)

		var status := ""
		if not squad.alive:
			status = "全灭 · 永久损失"
		elif game.is_squad_engaged(squad):
			status = "交战中"
		elif squad.moving:
			status = "移动中"
		else:
			status = "待命"
		UI.draw_text(self, rect.position + Vector2(176, 42), status, 11, UI.RED if not squad.alive else (UI.AMBER if status == "交战中" else UI.DIM))

		for m_i in range(squad.members.size()):
			var alive_member: bool = squad.members[m_i]["alive"]
			var dot := rect.position + Vector2(65 + float(m_i) * 14, 54)
			draw_circle(dot, 4.0, color if alive_member else Color(0.2, 0.24, 0.23, 0.8))
			if not alive_member:
				draw_line(dot + Vector2(-3, -3), dot + Vector2(3, 3), UI.DIM.darkened(0.2), 1.0)

		var hp_ratio: float = squad.hp_ratio()
		var bar_color := UI.GREEN if hp_ratio > 0.55 else (UI.AMBER if hp_ratio > 0.25 else UI.RED)
		UI.draw_bar(self, Rect2(rect.position + Vector2(64, 66), Vector2(124, 8)), hp_ratio, bar_color if squad.alive else UI.DIM.darkened(0.25))
		UI.draw_text(self, rect.position + Vector2(64, 88), "兵力 " + squad.hp_value(), 10, UI.DIM)
		UI.draw_right(self, Rect2(rect.position + Vector2(112, 62), Vector2(120, 14)), "%d / %d 人" % [squad.living_count(), squad.members.size()], 10, UI.DIM)


func _draw_help() -> void:
	var rect := Rect2(802, 590, 458, 110)
	UI.draw_bracket_panel(self, rect, Color(0.04, 0.09, 0.10, 0.82), UI.BORDER_SOFT)
	UI.draw_text(self, rect.position + Vector2(14, 21), "左键 / 拖框 选择   ·   右键 移动   ·   1–3 选队", 11, UI.TEXT)
	UI.draw_text(self, rect.position + Vector2(14, 41), "Space 暂停   ·   T 倍速   ·   Q/E 旋转   ·   滚轮 缩放", 11, UI.DIM)
	UI.draw_text(self, rect.position + Vector2(14, 61), "WASD / 中键拖动 平移   ·   R 重开", 11, UI.DIM)
	UI.draw_text(self, rect.position + Vector2(14, 81), "高地 +20% 伤害  ·  盾克弓 · 弓克矛 · 矛克盾", 11, Color(0.85, 0.82, 0.70, 0.95))
	UI.draw_text(self, rect.position + Vector2(14, 101), "队员阵亡不复活 · 全队阵亡本岛永久失去", 10, UI.RED)


func _draw_pause() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.05, 0.06, 0.52), true)
	var rect := Rect2(440, 220, 400, 280)
	UI.draw_bracket_panel(self, rect, Color(0.04, 0.10, 0.11, 0.96), UI.BORDER)
	UI.draw_center(self, Rect2(rect.position.x, 254, rect.size.x, 40), "已暂停", 30, UI.TEXT, true)
	UI.draw_center(self, Rect2(rect.position.x, 300, rect.size.x, 22), "空格继续 · 可旋转 / 缩放观察战场", 12, UI.DIM)
	UI.draw_center(self, Rect2(rect.position.x, 330, rect.size.x, 20), "调整站位后再迎接下一波", 12, UI.AMBER)
	UI.draw_text(self, Vector2(486, 466), "提示：盾卫挡箭、长矛拒盾、弓手远距消耗。", 12, UI.DIM)


func _draw_intro() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.05, 0.055, 0.30), true)
	var rect := Rect2(70, 92, 620, 540)
	draw_rect(rect, Color(0.035, 0.085, 0.095, 0.93), true)
	draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), UI.AMBER, true)
	UI.draw_bracket_panel(self, rect, Color(0, 0, 0, 0), UI.BORDER)
	UI.draw_text(self, Vector2(106, 178), "雾屿守望", 58, UI.TEXT, true)
	UI.draw_text(self, Vector2(108, 204), "MISTBOUND WATCH", 12, UI.AMBER, true)
	draw_line(Vector2(108, 226), Vector2(654, 226), UI.BORDER_SOFT, 1.0)
	UI.draw_text(self, Vector2(108, 262), "原创极简实时岛屿防守 · 三队守军 · 三波登陆", 15, UI.AMBER)
	UI.draw_text(self, Vector2(108, 302), "· 右键移动小队，进入射程后自动交战", 13, UI.TEXT)
	UI.draw_text(self, Vector2(108, 334), "· 盾克弓、弓克矛、矛克盾；高地提升伤害", 13, UI.TEXT)
	UI.draw_text(self, Vector2(108, 366), "· 房屋是底线；队员阵亡不复活，全队阵亡即失去", 13, UI.TEXT)
	UI.draw_text(self, Vector2(108, 416), "左键/拖框 选择   ·   右键 移动   ·   1–3 选队", 12, UI.DIM)
	UI.draw_text(self, Vector2(108, 438), "Space 暂停   ·   T 倍速   ·   Q/E 旋转   ·   滚轮 缩放", 12, UI.DIM)
	UI.draw_text(self, Vector2(108, 486), "守住苔盾、风弦、潮枪三队，熬过三波海掠者。", 13, UI.DIM)
	UI.draw_text(self, Vector2(108, 590), "程序化低模 · 无外部模型/贴图 · Godot 4.6", 10, Color(0.62, 0.68, 0.62, 0.9))
	UI.draw_text(self, Vector2(108, 610), "玩法类型灵感来自极简实时战术，不含原游戏素材或商标。", 10, Color(0.62, 0.68, 0.62, 0.9))


func _draw_result() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.05, 0.055, 0.62), true)
	var victory: bool = game.state == "victory"
	var rect := Rect2(350, 118, 580, 468)
	UI.draw_bracket_panel(self, rect, Color(0.036, 0.086, 0.095, 0.97), UI.BORDER)
	draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), UI.AMBER if victory else UI.RED, true)
	UI.draw_text(self, Vector2(392, 186), "岛屿守住了" if victory else "防线失守", 40, UI.TEXT, true)
	UI.draw_text(self, Vector2(394, 214), "ISLAND HELD" if victory else "THE LINE BROKE", 11, UI.AMBER if victory else UI.RED, true)
	UI.draw_text(self, Vector2(394, 246), game.result_reason, 14, UI.DIM)
	draw_line(Vector2(392, 264), Vector2(888, 264), UI.BORDER_SOFT, 1.0)
	var stats: Dictionary = game.get_result_stats()
	var rows := [
		["岛屿", "%s" % stats.get("island", "")],
		["波次", "%d / %d" % [int(stats.get("waves", 0)), int(stats.get("waves_total", 0))]],
		["击杀", "%d" % int(stats.get("kills", 0))],
		["房屋", "%d / %d 完好" % [int(stats.get("houses_alive", 0)), int(stats.get("houses_total", 0))]],
		["幸存队伍", "%d / %d" % [int(stats.get("squads_alive", 0)), int(stats.get("squads_total", 0))]],
		["用时", UI.format_time(float(stats.get("time", 0.0)))],
	]
	for i in range(rows.size()):
		var row_y := 296.0 + float(i) * 31.0
		UI.draw_text(self, Vector2(394, row_y), str(rows[i][0]), 13, UI.DIM)
		UI.draw_text(self, Vector2(520, row_y), str(rows[i][1]), 15, UI.TEXT, true)
	if victory:
		UI.draw_text(self, Vector2(392, 480), "幸存队伍将补员后前往下一岛；阵亡队伍不会归来。", 11, UI.DIM)
	else:
		UI.draw_text(self, Vector2(392, 480), "重整防线，再试一次。", 11, UI.DIM)


func _on_start() -> void:
	if game != null:
		game.start_battle()


func _on_pause() -> void:
	if game != null:
		game.toggle_pause()


func _on_speed() -> void:
	if game != null:
		game.toggle_speed()


func _on_resume() -> void:
	if game != null:
		game.set_paused(false)


func _on_restart() -> void:
	if game != null:
		game.restart_run()


func _on_result_primary() -> void:
	if game != null:
		game.result_primary_action()
