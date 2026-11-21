class_name FogBaseScreen
extends Control
## 基地/仓库/升级界面。仓库按堆叠格计数；升级消耗信用点。
## 视觉：原创雾港夜景 + 深青面板 + 琥珀强调。

signal deploy_requested
signal upgrade_requested(id: String)
signal sell_requested

const WAREHOUSE_PANEL := Rect2(828, 150, 408, 508)
const WAREHOUSE_GRID := Rect2(850, 232, 337, 352)
const SLOT := Vector2(52, 46)
const SLOT_GAP := 5.0

var state: FogGameState = null
var _deploy_button: Button
var _sell_button: Button
var _buy_buttons: Dictionary = {}
var _message := ""
var _message_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func configure(game_state: FogGameState) -> void:
	state = game_state
	for child in get_children():
		if child is Button:
			child.queue_free()
	_deploy_button = FogUITheme.make_button("部署 · 进入雾港", Rect2(376, 564, 430, 62), FogUITheme.AMBER, 22)
	_deploy_button.pressed.connect(func(): deploy_requested.emit())
	add_child(_deploy_button)
	_sell_button = FogUITheme.make_ghost_button("回收全部物资", Rect2(850, 596, 337, 34), 14)
	_sell_button.pressed.connect(func(): sell_requested.emit())
	add_child(_sell_button)
	_buy_buttons.clear()
	for i in range(FogGameState.UPGRADE_ORDER.size()):
		var id: String = FogGameState.UPGRADE_ORDER[i]
		var button := FogUITheme.make_button("升级", Rect2(672, 150 + i * 128 + 64, 118, 34), FogUITheme.TEAL, 14)
		button.pressed.connect(func(): upgrade_requested.emit(id))
		add_child(button)
		_buy_buttons[id] = button
	refresh()


func refresh() -> void:
	if state == null:
		return
	if _deploy_button != null:
		_deploy_button.text = "部署 · 进入雾港"
	for id in _buy_buttons.keys():
		var button: Button = _buy_buttons[id]
		if state.is_upgrade_max(id):
			button.text = "已满级"
			button.disabled = true
		else:
			var cost := state.upgrade_cost(id)
			button.text = "升级 · %d" % cost
			button.disabled = not state.can_buy_upgrade(id)
	if _sell_button != null:
		_sell_button.disabled = state.warehouse.is_empty()
		_sell_button.text = "回收全部物资 · +%d" % state.warehouse_value() if not state.warehouse.is_empty() else "仓库为空"
	queue_redraw()


func show_message(text: String) -> void:
	_message = text
	_message_time = 3.2
	queue_redraw()


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message = ""
			queue_redraw()


func _draw() -> void:
	_draw_background()
	var title_font := FogArt.title_font()
	draw_string(title_font, Vector2(51, 105), "雾港", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(0, 0, 0, 0.55))
	draw_string(title_font, Vector2(52, 104), "雾港", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, FogUITheme.TEXT)
	var title_w := title_font.get_string_size("雾港", HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
	draw_string(title_font, Vector2(52 + title_w + 2, 105), "余烬", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(0, 0, 0, 0.55))
	draw_string(title_font, Vector2(52 + title_w, 104), "余烬", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, FogUITheme.AMBER)
	FogUITheme.draw_text(self, Vector2(54, 128), "FOGFALL EXTRACTION · 雾港搜打撤", 12, FogUITheme.DIM)
	draw_line(Vector2(54, 140), Vector2(250, 140), FogUITheme.AMBER_DIM, 1.5)
	_draw_credits()
	_draw_operator()
	_draw_controls_card()
	_draw_upgrades()
	_draw_warehouse()
	_draw_footer()


func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), FogUITheme.BG_DEEP, true)
	# 天空渐变
	for i in range(14):
		var t := float(i) / 13.0
		var color := Color("0b1b22").lerp(Color("1b3038"), t)
		draw_rect(Rect2(0, i * 30, 1280, 31), color, true)
	# 远处水面
	draw_rect(Rect2(0, 420, 1280, 300), Color("07151c"), true)
	for i in range(28):
		var y := 438.0 + i * 10.0
		var alpha := 0.035 + 0.025 * sin(float(i) * 1.4)
		draw_line(Vector2(20, y), Vector2(1260, y + 2), Color(0.35, 0.62, 0.68, alpha), 1.0)
	# 天际线剪影：吊机与集装箱
	for x in [70, 210, 520, 860, 1180]:
		draw_line(Vector2(x, 420), Vector2(x, 300), Color(0.03, 0.07, 0.085, 1), 8.0)
		draw_line(Vector2(x, 300), Vector2(x + 90, 300), Color(0.03, 0.07, 0.085, 1), 5.0)
		draw_line(Vector2(x + 70, 300), Vector2(x + 70, 338), Color(0.03, 0.07, 0.085, 1), 2.0)
	for i in range(14):
		var x := 12 + i * 94
		var h := 22 + (i * 17) % 34
		draw_rect(Rect2(x, 420 - h, 82, h), Color(0.04, 0.085, 0.1, 1), true)
	# 码头边缘
	draw_rect(Rect2(0, 416, 1280, 8), Color(0.14, 0.2, 0.21, 1), true)
	for x in range(0, 1280, 26):
		draw_line(Vector2(x, 424), Vector2(x + 14, 434), Color(0.18, 0.28, 0.3, 0.4), 1.0)
	# 灯光光晕
	for lamp in [Vector2(996, 420), Vector2(160, 420), Vector2(1130, 470)]:
		for r in range(120, 10, -14):
			draw_circle(lamp, float(r), Color(0.95, 0.68, 0.32, 0.006 * (130.0 - r)), true)
		draw_circle(lamp, 4.0, Color(0.95, 0.78, 0.45, 0.85), true)
	# 雾带
	_draw_fog_band(Vector2(80, 330), 420, 26, 0.035)
	_draw_fog_band(Vector2(560, 390), 640, 34, 0.045)
	_draw_fog_band(Vector2(880, 460), 520, 30, 0.05)
	_draw_fog_band(Vector2(180, 520), 560, 40, 0.04)
	# 暗角
	draw_rect(Rect2(0, 0, 1280, 60), Color(0.01, 0.03, 0.04, 0.45), true)
	draw_rect(Rect2(0, 660, 1280, 60), Color(0.01, 0.03, 0.04, 0.55), true)


func _draw_fog_band(center: Vector2, rx: float, ry: float, alpha: float) -> void:
	var points := PackedVector2Array()
	for i in range(28):
		var a := TAU * float(i) / 28.0
		var wobble := 1.0 + 0.08 * sin(float(i) * 2.3)
		points.append(center + Vector2(cos(a) * rx * wobble, sin(a) * ry))
	draw_colored_polygon(points, Color(0.55, 0.68, 0.72, alpha))


func _draw_credits() -> void:
	var rect := Rect2(978, 40, 258, 56)
	FogUITheme.draw_panel(self, rect, Color(0.04, 0.09, 0.11, 0.88), FogUITheme.BORDER)
	FogUITheme.draw_text(self, rect.position + Vector2(16, 22), "信用点", 11, FogUITheme.DIM)
	FogUITheme.draw_text(self, rect.position + Vector2(16, 48), str(state.credits), 24, FogUITheme.AMBER, true)
	FogUITheme.draw_text(self, Vector2(1120, 60), "CREDITS", 9, FogUITheme.AMBER_DIM)


func _draw_operator() -> void:
	var rect := Rect2(44, 150, 310, 300)
	FogUITheme.draw_panel(self, rect)
	FogUITheme.draw_text(self, rect.position + Vector2(18, 28), "拾荒者档案", 17, FogUITheme.TEXT, true)
	FogUITheme.draw_text(self, rect.position + Vector2(18, 48), "OPERATOR · 07", 10, FogUITheme.AMBER_DIM)
	# 原创头像
	var c := rect.position + Vector2(67, 118)
	draw_circle(c, 42.0, Color(0.06, 0.13, 0.15, 1), true)
	draw_arc(c, 42.0, 0.0, TAU, 32, FogUITheme.BORDER, 1.5)
	draw_circle(c + Vector2(0, 10), 22.0, Color("315e61"), true)
	draw_circle(c + Vector2(0, 0), 14.0, Color("d8b58e"), true)
	draw_arc(c + Vector2(0, 0), 15.0, PI, TAU, 12, Color("2d3a3a"), 5.0)
	draw_arc(c + Vector2(0, 14), 21.0, 0.1, PI - 0.1, 14, Color("d9834e"), 4.0)
	var stats: Dictionary = state.stats
	FogUITheme.draw_text(self, rect.position + Vector2(124, 90), "行动 %d · 撤离 %d" % [int(stats.get("runs", 0)), int(stats.get("extractions", 0))], 13, FogUITheme.TEXT)
	FogUITheme.draw_text(self, rect.position + Vector2(124, 112), "阵亡 %d" % int(stats.get("deaths", 0)), 13, FogUITheme.RED)
	FogUITheme.draw_text(self, rect.position + Vector2(124, 134), "仓库 %d / %d 格" % [state.warehouse_slots(), state.warehouse_capacity()], 13, FogUITheme.DIM)
	FogUITheme.draw_text(self, rect.position + Vector2(124, 156), "武器伤害 %d" % state.weapon_damage(), 13, FogUITheme.DIM)
	draw_line(rect.position + Vector2(18, 194), rect.position + Vector2(292, 194), FogUITheme.BORDER_SOFT, 1.0)
	FogUITheme.draw_wrapped(self, rect.position + Vector2(18, 218),
		"雾潮之后，旧港只剩下货柜、灯火和不肯离开的人。你靠潜入、搜刮和活着回来攒下基地的每一格仓库。",
		12, FogUITheme.DIM, 274, 4)
	FogUITheme.draw_text(self, rect.position + Vector2(18, 278), "死亡丢失随身物资，仓库与升级永久保留。", 11, FogUITheme.AMBER)


func _draw_controls_card() -> void:
	var rect := Rect2(44, 466, 310, 192)
	FogUITheme.draw_panel(self, rect)
	FogUITheme.draw_text(self, rect.position + Vector2(18, 28), "操作", 16, FogUITheme.TEXT, true)
	var lines := [
		"WASD 移动 · 鼠标瞄准 · 左键射击",
		"R 换弹 · Shift 冲刺（短暂无敌）",
		"E 搜箱（按住） · Tab/B 背包",
		"站入撤离点 3 秒完成撤离",
		"死亡或超时 → 丢失随身物资",
	]
	var y := 58.0
	for line in lines:
		FogUITheme.draw_text(self, rect.position + Vector2(18, y), line, 12, FogUITheme.DIM)
		y += 24.0
	draw_line(rect.position + Vector2(18, 166), rect.position + Vector2(292, 166), FogUITheme.BORDER_SOFT, 1.0)
	FogUITheme.draw_text(self, rect.position + Vector2(18, 184), "单局 6 分钟 · 撤离激活 2 分钟 / 搜箱 2 次", 10, FogUITheme.AMBER_DIM)


func _draw_upgrades() -> void:
	FogUITheme.draw_text(self, Vector2(376, 128), "基地工坊", 20, FogUITheme.TEXT, true)
	FogUITheme.draw_text(self, Vector2(508, 127), "永久升级 · 消耗信用点", 11, FogUITheme.DIM)
	for i in range(FogGameState.UPGRADE_ORDER.size()):
		var id: String = FogGameState.UPGRADE_ORDER[i]
		var def: Dictionary = FogGameState.UPGRADE_DEFS[id]
		var rect := Rect2(376, 150 + i * 128, 430, 114)
		FogUITheme.draw_panel(self, rect, Color(0.04, 0.09, 0.11, 0.9), FogUITheme.BORDER_SOFT)
		FogUITheme.draw_text(self, rect.position + Vector2(16, 28), String(def["name"]), 16, FogUITheme.TEXT, true)
		FogUITheme.draw_text(self, rect.position + Vector2(16, 50), String(def["desc"]), 11, FogUITheme.DIM)
		var level := state.upgrade_level(id)
		var max_level := int(def["max_level"])
		var effect := ""
		match id:
			"warehouse":
				effect = "仓库 %d → %d 格" % [state.warehouse_capacity(), state.warehouse_capacity() + FogGameState.WAREHOUSE_PER_LEVEL]
			"medkit":
				effect = "出发医疗包 %d → %d" % [state.starting_medkits(), state.starting_medkits() + 1]
			"damage":
				effect = "武器伤害 %d → %d" % [state.weapon_damage(), state.weapon_damage() + FogGameState.DAMAGE_PER_LEVEL]
		if state.is_upgrade_max(id):
			effect = "已达到最高等级"
		FogUITheme.draw_text(self, rect.position + Vector2(16, 86), effect, 12, FogUITheme.AMBER)
		for pip in range(max_level):
			var color := FogUITheme.TEAL if pip < level else FogUITheme.BORDER
			draw_circle(rect.position + Vector2(330 + pip * 16, 26), 4.0, color, true)
		draw_circle(rect.position + Vector2(330 + max_level * 16 + 8, 26), 2.0, Color(FogUITheme.AMBER_DIM, 0.5), true)


func _draw_warehouse() -> void:
	FogUITheme.draw_panel(self, WAREHOUSE_PANEL)
	FogUITheme.draw_text(self, WAREHOUSE_PANEL.position + Vector2(20, 30), "仓库", 20, FogUITheme.TEXT, true)
	FogUITheme.draw_text(self, WAREHOUSE_PANEL.position + Vector2(84, 28), "STASH", 10, FogUITheme.AMBER_DIM)
	FogUITheme.draw_text(self, WAREHOUSE_PANEL.position + Vector2(20, 58), "%d / %d 格" % [state.warehouse_slots(), state.warehouse_capacity()], 13, FogUITheme.DIM)
	FogUITheme.draw_text_right(self, Rect2(WAREHOUSE_PANEL.position.x + 20, WAREHOUSE_PANEL.position.y + 42, 368, 20),
		"估值 %d" % state.warehouse_value(), 13, FogUITheme.AMBER)
	draw_rect(WAREHOUSE_GRID, Color(0.035, 0.075, 0.09, 0.85), true)
	var slot_lines := PackedVector2Array()
	for y in range(7):
		for x in range(6):
			if y * 6 + x >= state.warehouse_capacity():
				continue
			var rect := Rect2(WAREHOUSE_GRID.position + Vector2(x * (SLOT.x + SLOT_GAP), y * (SLOT.y + SLOT_GAP)), SLOT)
			slot_lines.append(rect.position)
			slot_lines.append(Vector2(rect.end.x, rect.position.y))
			slot_lines.append(Vector2(rect.end.x, rect.position.y))
			slot_lines.append(rect.end)
			slot_lines.append(rect.end)
			slot_lines.append(Vector2(rect.position.x, rect.end.y))
			slot_lines.append(Vector2(rect.position.x, rect.end.y))
			slot_lines.append(rect.position)
	draw_multiline(slot_lines, Color(FogUITheme.BORDER_SOFT, 0.9), 1.0)
	for i in range(mini(state.warehouse.size(), state.warehouse_capacity())):
		var entry: Dictionary = state.warehouse[i]
		var item := FogItems.get_item(String(entry["id"]))
		if item.is_empty():
			continue
		var rect := Rect2(
			WAREHOUSE_GRID.position + Vector2((i % 6) * (SLOT.x + SLOT_GAP), (i / 6) * (SLOT.y + SLOT_GAP)),
			SLOT
		)
		var color := FogItems.rarity_color(int(item["rarity"]))
		draw_rect(rect.grow(-1), Color(color.r, color.g, color.b, 0.09), true)
		draw_rect(rect.grow(-1), Color(color.r, color.g, color.b, 0.65), false, 1.5)
		FogItemArt.draw_icon(self, rect.grow(-8), String(entry["id"]))
		if int(entry["count"]) > 1:
			FogUITheme.draw_text(self, rect.end - Vector2(18, 7), str(entry["count"]), 12, FogUITheme.WHITE, true)
	if state.warehouse.is_empty():
		FogUITheme.draw_text_center(self, Rect2(WAREHOUSE_GRID.position.x, WAREHOUSE_GRID.position.y + 150, WAREHOUSE_GRID.size.x, 30),
			"仓库是空的", 18, FogUITheme.DIM)
		FogUITheme.draw_text_center(self, Rect2(WAREHOUSE_GRID.position.x, WAREHOUSE_GRID.position.y + 184, WAREHOUSE_GRID.size.x, 24),
			"撤离成功带出的物资会出现在这里", 11, FogUITheme.DIM)


func _draw_footer() -> void:
	FogUITheme.draw_text(self, Vector2(376, 644), "单局 6:00 · 撤离点激活后站入 3 秒 · 死亡丢失随身物资", 11, FogUITheme.DIM)
	FogUITheme.draw_text(self, Vector2(376, 662), "仓库容量满时，溢出物资自动折现为信用点。", 11, FogUITheme.AMBER_DIM)
	if _message != "":
		FogUITheme.draw_text(self, Vector2(828, 680), _message, 12, FogUITheme.TEAL, true)
