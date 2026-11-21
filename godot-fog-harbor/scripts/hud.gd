class_name FogHud
extends Control
## 行动 HUD：生命/弹药/计时/撤离状态/背包容量/交互提示/罗盘/消息。
## 全部原创绘制；1280×720 逻辑坐标。

var player: FogPlayer = null
var rules: FogRaidRules = null
var inventory: FogInventory = null
var extraction_pos := Vector2.ZERO
var chests_opened := 0
var kills := 0
var prompt_text := ""
var prompt_ratio := -1.0
var prompt_hint := ""
var demo_crosshair := Vector2(-1, -1)

var _toasts: Array = []
var _redraw_accum := 0.0
var _hit_flash := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func configure(player_node: FogPlayer, raid_rules: FogRaidRules, inv: FogInventory, extract_pos: Vector2) -> void:
	player = player_node
	rules = raid_rules
	inventory = inv
	extraction_pos = extract_pos
	_toasts.clear()
	queue_redraw()


func toast(text: String, color := FogUITheme.TEXT) -> void:
	_toasts.append({"text": text, "color": color, "t": 0.0, "life": 2.8})
	if _toasts.size() > 5:
		_toasts.pop_front()
	queue_redraw()


func show_hit() -> void:
	_hit_flash = 0.14
	queue_redraw()


func _process(delta: float) -> void:
	for i in range(_toasts.size() - 1, -1, -1):
		_toasts[i]["t"] = float(_toasts[i]["t"]) + delta
		if float(_toasts[i]["t"]) >= float(_toasts[i]["life"]):
			_toasts.remove_at(i)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_redraw_accum += delta
	if _redraw_accum >= 0.08:
		_redraw_accum = 0.0
		queue_redraw()


func _draw() -> void:
	if player == null or rules == null:
		return
	_draw_status()
	_draw_timer()
	_draw_objectives()
	_draw_prompt()
	_draw_controls()
	_draw_toasts()
	_draw_crosshair()


func _draw_status() -> void:
	var panel := Rect2(22, 20, 310, 94)
	FogUITheme.draw_panel(self, panel)
	FogUITheme.draw_text(self, panel.position + Vector2(16, 24), "拾荒者-07", 17, FogUITheme.TEXT, true)
	FogUITheme.draw_text(self, panel.position + Vector2(214, 22), "雾港", 11, FogUITheme.AMBER_DIM)
	var hp_ratio := clampf(player.hp / player.max_hp, 0.0, 1.0)
	var hp_color := FogUITheme.GREEN if hp_ratio > 0.35 else FogUITheme.RED
	FogUITheme.draw_bar(self, Rect2(panel.position + Vector2(16, 38), Vector2(278, 13)), hp_ratio, hp_color)
	FogUITheme.draw_text(self, panel.position + Vector2(16, 66), "生命 %d / %d" % [int(ceil(player.hp)), int(player.max_hp)], 12, FogUITheme.DIM)
	FogUITheme.draw_text(self, panel.position + Vector2(198, 66), "伤害 %d" % player.weapon_damage, 12, FogUITheme.DIM)
	# 弹药
	var ammo_panel := Rect2(22, 124, 196, 58)
	FogUITheme.draw_panel(self, ammo_panel)
	FogUITheme.draw_text(self, ammo_panel.position + Vector2(14, 20), "制式步枪", 11, FogUITheme.DIM)
	var ammo_color := FogUITheme.RED if player.mag == 0 else FogUITheme.TEXT
	FogUITheme.draw_text(self, ammo_panel.position + Vector2(14, 45), player.ammo_text(), 20, ammo_color, true)
	if player.reloading:
		FogUITheme.draw_text(self, ammo_panel.position + Vector2(116, 43), "换弹中", 12, FogUITheme.AMBER)
	elif player.reserve == 0 and player.mag == 0:
		FogUITheme.draw_text(self, ammo_panel.position + Vector2(116, 43), "弹药耗尽", 12, FogUITheme.RED)
	# 冲刺冷却
	var dash_ratio := 1.0 - clampf(player.dash_cooldown / FogPlayer.DASH_COOLDOWN, 0.0, 1.0)
	FogUITheme.draw_text(self, Vector2(24, 198), "冲刺", 10, FogUITheme.DIM)
	FogUITheme.draw_bar(self, Rect2(58, 190, 120, 7), dash_ratio, FogUITheme.TEAL)


func _draw_timer() -> void:
	var panel := Rect2(506, 16, 268, 76)
	FogUITheme.draw_panel(self, panel)
	var left := rules.time_left()
	var color := FogUITheme.TEXT
	if left <= 60.0:
		color = FogUITheme.RED
	elif left <= 150.0:
		color = FogUITheme.AMBER
	FogUITheme.draw_text_center(self, Rect2(panel.position.x, panel.position.y + 5, panel.size.x, 32),
		FogUITheme.format_time(left), 27, color, true)
	FogUITheme.draw_text_center(self, Rect2(panel.position.x, panel.position.y + 42, panel.size.x, 16),
		"行动剩余时间", 11, FogUITheme.DIM)
	var status := ""
	var status_color := FogUITheme.DIM
	if rules.active:
		status = "撤离点已激活"
		status_color = FogUITheme.TEAL
	elif rules.chests_searched >= 1:
		status = "再搜 1 个箱子 或 %s 后激活" % FogUITheme.format_time(rules.unlock_in())
	else:
		status = "%s 后 / 搜箱 2 次激活" % FogUITheme.format_time(rules.unlock_in())
	FogUITheme.draw_text_center(self, Rect2(panel.position.x, panel.position.y + 58, panel.size.x, 16),
		status, 10, status_color)


func _draw_objectives() -> void:
	var panel := Rect2(958, 20, 300, 104)
	FogUITheme.draw_panel(self, panel)
	FogUITheme.draw_text(self, panel.position + Vector2(16, 22), "行动记录", 12, FogUITheme.DIM)
	var used := inventory.cells_used() if inventory != null else 0
	var cap := inventory.capacity_cells() if inventory != null else 0
	FogUITheme.draw_text(self, panel.position + Vector2(16, 48), "背包", 13, FogUITheme.DIM)
	FogUITheme.draw_text(self, panel.position + Vector2(64, 48), "%d / %d 格" % [used, cap], 14, FogUITheme.TEXT, true)
	FogUITheme.draw_text(self, panel.position + Vector2(16, 72), "已搜箱", 12, FogUITheme.DIM)
	FogUITheme.draw_text(self, panel.position + Vector2(76, 72), str(chests_opened), 14, FogUITheme.AMBER, true)
	FogUITheme.draw_text(self, panel.position + Vector2(132, 72), "击杀", 12, FogUITheme.DIM)
	FogUITheme.draw_text(self, panel.position + Vector2(178, 72), str(kills), 14, FogUITheme.AMBER, true)
	# 撤离方向与距离
	if player != null and extraction_pos != Vector2.ZERO:
		var dir := (extraction_pos - player.global_position)
		var dist := dir.length() / 100.0
		var angle := dir.angle()
		var center := panel.position + Vector2(260, 52)
		draw_circle(center, 24.0, Color(0.06, 0.14, 0.16, 0.9), true)
		draw_circle(center, 24.0, Color(FogUITheme.BORDER, 0.8), false, 1.0)
		draw_set_transform(center, angle + PI * 0.5)
		var arrow := PackedVector2Array([Vector2(0, -13), Vector2(8, 9), Vector2(0, 4), Vector2(-8, 9)])
		draw_colored_polygon(arrow, FogUITheme.TEAL if rules.active else FogUITheme.DIM)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		FogUITheme.draw_text_center(self, Rect2(center.x - 24, center.y + 26, 48, 14), "%dm" % int(dist), 9, FogUITheme.DIM)


func _draw_prompt() -> void:
	if prompt_text == "":
		return
	var panel := Rect2(414, 596, 452, 82)
	FogUITheme.draw_panel(self, panel)
	FogUITheme.draw_text_center(self, Rect2(panel.position.x, panel.position.y + 10, panel.size.x, 24),
		prompt_text, 16, FogUITheme.AMBER, true)
	if prompt_ratio >= 0.0:
		FogUITheme.draw_bar(self, Rect2(panel.position.x + 92, panel.position.y + 42, 268, 9),
			prompt_ratio, FogUITheme.AMBER)
	if prompt_hint != "":
		FogUITheme.draw_text_center(self, Rect2(panel.position.x, panel.position.y + 56, panel.size.x, 18),
			prompt_hint, 11, FogUITheme.DIM)


func _draw_controls() -> void:
	var panel := Rect2(22, 650, 430, 50)
	FogUITheme.draw_panel(self, panel, Color(0.04, 0.09, 0.11, 0.82))
	FogUITheme.draw_text(self, panel.position + Vector2(14, 20),
		"WASD 移动 · 左键射击 · R 换弹 · Shift 冲刺", 11, FogUITheme.DIM)
	FogUITheme.draw_text(self, panel.position + Vector2(14, 38),
		"E 搜箱 · Tab/B 背包 · Esc 关闭", 11, FogUITheme.DIM)


func _draw_toasts() -> void:
	var y := 146.0
	for toast in _toasts:
		var t := float(toast["t"])
		var life := float(toast["life"])
		var alpha := 1.0
		if t > life - 0.5:
			alpha = maxf(0.0, (life - t) / 0.5)
		elif t < 0.15:
			alpha = t / 0.15
		var text: String = toast["text"]
		var width := FogUITheme.text_size(text, 13).x + 28.0
		var rect := Rect2(1258 - width, y, width, 28)
		draw_rect(rect, Color(0.03, 0.07, 0.09, 0.82 * alpha), true)
		draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), Color(toast["color"], alpha), true)
		FogUITheme.draw_text(self, Vector2(rect.position.x + 12, rect.position.y + 19),
			text, 13, Color(toast["color"].r, toast["color"].g, toast["color"].b, alpha))
		y += 34.0


func _draw_crosshair() -> void:
	var pos := demo_crosshair
	if pos.x < 0.0:
		pos = get_viewport().get_mouse_position()
		if pos.x < 2.0 and pos.y < 2.0:
			return
	var color := FogUITheme.AMBER
	draw_circle(pos, 10.0, Color(0.08, 0.09, 0.09, 0.45), false, 1.0)
	draw_line(pos + Vector2(-16, 0), pos + Vector2(-6, 0), color, 1.5)
	draw_line(pos + Vector2(6, 0), pos + Vector2(16, 0), color, 1.5)
	draw_line(pos + Vector2(0, -16), pos + Vector2(0, -6), color, 1.5)
	draw_line(pos + Vector2(0, 6), pos + Vector2(0, 16), color, 1.5)
	draw_circle(pos, 1.5, color, true)
	if _hit_flash > 0.0:
		var alpha := _hit_flash / 0.14
		draw_line(pos + Vector2(-9, -9), pos + Vector2(-3, -3), Color(1, 1, 1, alpha), 2.0)
		draw_line(pos + Vector2(9, -9), pos + Vector2(3, -3), Color(1, 1, 1, alpha), 2.0)
		draw_line(pos + Vector2(-9, 9), pos + Vector2(-3, 3), Color(1, 1, 1, alpha), 2.0)
		draw_line(pos + Vector2(9, 9), pos + Vector2(3, 3), Color(1, 1, 1, alpha), 2.0)
