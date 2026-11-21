class_name FogBackpackPanel
extends Control
## 6×4 随身背包面板：选中/使用/丢弃/容量。打开时暂停世界。

signal use_requested(index: int)
signal drop_requested(index: int)
signal closed

const PANEL := Rect2(190, 64, 900, 590)
const GRID := Rect2(236, 186, 587, 365)
const CELL := Vector2(92, 86)
const GAP := 7.0
const INFO := Rect2(850, 186, 200, 350)

var inventory: FogInventory = null
var selected_index := -1
var selected_cell := Vector2i(0, 0)
var _message := ""

var _use_button: Button
var _drop_button: Button
var _close_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_use_button = FogUITheme.make_button("使用 U", Rect2(850, 556, 94, 34), FogUITheme.TEAL, 13)
	_use_button.pressed.connect(_on_use_pressed)
	add_child(_use_button)
	_drop_button = FogUITheme.make_ghost_button("丢弃 X", Rect2(952, 556, 94, 34), 13)
	_drop_button.pressed.connect(_on_drop_pressed)
	add_child(_drop_button)
	_close_button = FogUITheme.make_ghost_button("关闭 Tab", Rect2(986, 80, 82, 30), 12)
	_close_button.pressed.connect(close)
	add_child(_close_button)


func configure(inv: FogInventory) -> void:
	inventory = inv
	selected_index = -1
	_message = ""
	refresh()


func open() -> void:
	if inventory == null:
		return
	visible = true
	selected_index = -1
	selected_cell = Vector2i(0, 0)
	get_tree().paused = true
	refresh()


func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()
	queue_redraw()


func refresh() -> void:
	if inventory != null and selected_index >= inventory.entries.size():
		selected_index = -1
	if inventory != null and selected_index >= 0:
		selected_cell = Vector2i(int(inventory.entries[selected_index]["x"]), int(inventory.entries[selected_index]["y"]))
	var item := _selected_item()
	var can_use := not item.is_empty() and String(item.get("kind", "")) == "consumable"
	if _use_button != null:
		_use_button.disabled = not can_use
		_use_button.text = "使用 U" if can_use else "不可使用"
	if _drop_button != null:
		_drop_button.disabled = item.is_empty()
	queue_redraw()


func flash_message(text: String) -> void:
	_message = text
	refresh()


func handle_input(event: InputEvent) -> bool:
	if not visible or inventory == null or not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	match key_event.keycode:
		KEY_ESCAPE, KEY_TAB, KEY_B, KEY_I:
			close()
			return true
		KEY_LEFT, KEY_A:
			selected_cell.x = maxi(0, selected_cell.x - 1)
			_sync_selection()
			return true
		KEY_RIGHT, KEY_D:
			selected_cell.x = mini(inventory.width - 1, selected_cell.x + 1)
			_sync_selection()
			return true
		KEY_UP, KEY_W:
			selected_cell.y = maxi(0, selected_cell.y - 1)
			_sync_selection()
			return true
		KEY_DOWN, KEY_S:
			selected_cell.y = mini(inventory.height - 1, selected_cell.y + 1)
			_sync_selection()
			return true
		KEY_U, KEY_ENTER, KEY_KP_ENTER:
			if selected_index >= 0:
				use_requested.emit(selected_index)
			return true
		KEY_X, KEY_DELETE, KEY_BACKSPACE:
			if selected_index >= 0:
				drop_requested.emit(selected_index)
			return true
	return false


func _sync_selection() -> void:
	selected_index = inventory.entry_at_cell(selected_cell.x, selected_cell.y)
	refresh()


func _on_use_pressed() -> void:
	if selected_index >= 0 and _selected_item().get("kind", "") == "consumable":
		use_requested.emit(selected_index)


func _on_drop_pressed() -> void:
	if selected_index >= 0:
		drop_requested.emit(selected_index)


func _selected_item() -> Dictionary:
	if inventory == null or selected_index < 0 or selected_index >= inventory.entries.size():
		return {}
	return FogItems.get_item(String(inventory.entries[selected_index]["id"]))


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			if GRID.has_point(mouse.position):
				var col := int((mouse.position.x - GRID.position.x) / (CELL.x + GAP))
				var row := int((mouse.position.y - GRID.position.y) / (CELL.y + GAP))
				if col >= 0 and col < inventory.width and row >= 0 and row < inventory.height:
					selected_cell = Vector2i(col, row)
					_sync_selection()
					accept_event()


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.04, 0.65), true)
	FogUITheme.draw_panel(self, PANEL, Color(0.035, 0.082, 0.1, 0.98), FogUITheme.BORDER)
	# 标题
	FogUITheme.draw_text(self, Vector2(236, 112), "随身背包", 26, FogUITheme.TEXT, true)
	FogUITheme.draw_text(self, Vector2(372, 110), "FIELD PACK · 6×4", 11, FogUITheme.AMBER_DIM)
	var used := inventory.cells_used()
	var cap := inventory.capacity_cells()
	FogUITheme.draw_text(self, Vector2(236, 144), "格子 %d / %d" % [used, cap], 13, FogUITheme.DIM)
	FogUITheme.draw_text(self, Vector2(360, 144), "估值 %d 信用点" % inventory.total_value(), 13, FogUITheme.AMBER)
	FogUITheme.draw_text(self, Vector2(570, 144), "撤离后入库 · 阵亡丢失", 12, FogUITheme.RED)
	# 网格底板与空格：整块底 + 一条 multiline 画所有格线
	draw_rect(Rect2(GRID.position, GRID.size), Color(0.035, 0.075, 0.09, 0.95), true)
	var cell_lines := PackedVector2Array()
	for y in range(inventory.height):
		for x in range(inventory.width):
			var rect := _cell_rect(x, y)
			cell_lines.append(rect.position)
			cell_lines.append(Vector2(rect.end.x, rect.position.y))
			cell_lines.append(Vector2(rect.end.x, rect.position.y))
			cell_lines.append(rect.end)
			cell_lines.append(rect.end)
			cell_lines.append(Vector2(rect.position.x, rect.end.y))
			cell_lines.append(Vector2(rect.position.x, rect.end.y))
			cell_lines.append(rect.position)
	draw_multiline(cell_lines, Color(FogUITheme.BORDER_SOFT, 0.9), 1.0)
	# 物品
	for i in range(inventory.entries.size()):
		_draw_entry(i)
	# 选中框
	if selected_index >= 0:
		var entry: Dictionary = inventory.entries[selected_index]
		var grid: Vector2i = FogItems.get_item(String(entry["id"]))["grid"]
		var rect := _footprint_rect(int(entry["x"]), int(entry["y"]), grid)
		draw_rect(rect.grow(1), FogUITheme.AMBER, false, 2.0)
		draw_rect(rect, Color(0.9, 0.7, 0.35, 0.06), true)
	elif GRID.has_point(_cell_rect(selected_cell.x, selected_cell.y).position):
		var rect := _cell_rect(selected_cell.x, selected_cell.y)
		if rect.position.x >= GRID.position.x and rect.end.x <= GRID.end.x:
			draw_rect(rect, FogUITheme.AMBER_DIM, false, 1.5)
	# 空背包提示
	if inventory.entries.is_empty():
		FogUITheme.draw_text_center(self, Rect2(GRID.position.x, GRID.position.y + 130, GRID.size.x, 32),
			"背包是空的", 18, FogUITheme.DIM)
		FogUITheme.draw_text_center(self, Rect2(GRID.position.x, GRID.position.y + 166, GRID.size.x, 24),
			"去集装箱和仓库找补给箱，按住 E 搜索", 12, FogUITheme.DIM)
	# 右侧详情
	FogUITheme.draw_panel(self, INFO, Color(0.03, 0.07, 0.085, 0.9), FogUITheme.BORDER_SOFT)
	_draw_detail()
	# 底部提示
	FogUITheme.draw_text(self, Vector2(236, 612), "方向键 选择 · U 使用 · X 丢弃 · Tab / Esc 关闭", 12, FogUITheme.DIM)
	if _message != "":
		FogUITheme.draw_text(self, Vector2(620, 612), _message, 12, FogUITheme.AMBER)


func _draw_entry(index: int) -> void:
	var entry: Dictionary = inventory.entries[index]
	var id := String(entry["id"])
	var item := FogItems.get_item(id)
	var grid: Vector2i = item["grid"]
	var rect := _footprint_rect(int(entry["x"]), int(entry["y"]), grid)
	var rarity := int(item["rarity"])
	var color := FogItems.rarity_color(rarity)
	draw_rect(rect.grow(-2), Color(color.r, color.g, color.b, 0.08), true)
	draw_rect(rect.grow(-2), Color(color.r, color.g, color.b, 0.65), false, 1.5)
	FogItemArt.draw_icon(self, rect.grow(-12), id)
	if int(entry["count"]) > 1:
		FogUITheme.draw_text(self, rect.end - Vector2(20, 8), str(entry["count"]), 13, FogUITheme.WHITE, true)
	if index == selected_index:
		draw_rect(rect.grow(1), FogUITheme.AMBER, false, 2.0)


func _draw_detail() -> void:
	var item := _selected_item()
	if item.is_empty():
		FogUITheme.draw_text(self, INFO.position + Vector2(14, 28), "未选择物品", 15, FogUITheme.DIM, true)
		FogUITheme.draw_wrapped(self, INFO.position + Vector2(14, 58),
			"点击格子查看详情。物品按尺寸占格，紫色/金色边框代表更高稀有度。", 12, FogUITheme.DIM, 170, 4)
		return
	var rarity := int(item["rarity"])
	var color := FogItems.rarity_color(rarity)
	FogUITheme.draw_text(self, INFO.position + Vector2(14, 28), String(item["name"]), 18, color, true)
	FogUITheme.draw_text(self, INFO.position + Vector2(14, 50), FogItems.rarity_name(rarity), 11, color)
	var grid: Vector2i = item["grid"]
	var entry: Dictionary = inventory.entries[selected_index]
	FogUITheme.draw_text(self, INFO.position + Vector2(14, 76), "占格 %d×%d · 数量 %d/%d" % [grid.x, grid.y, int(entry["count"]), int(item["stack_max"])], 11, FogUITheme.DIM)
	FogUITheme.draw_text(self, INFO.position + Vector2(14, 96), "单价 %d 信用点" % int(item["value"]), 11, FogUITheme.AMBER)
	draw_line(INFO.position + Vector2(14, 108), INFO.position + Vector2(186, 108), FogUITheme.BORDER_SOFT, 1.0)
	FogUITheme.draw_wrapped(self, INFO.position + Vector2(14, 130), String(item["desc"]), 12, FogUITheme.TEXT, 172, 5)
	if String(item.get("kind", "")) == "consumable":
		FogUITheme.draw_text(self, INFO.position + Vector2(14, 320), "使用回复 %d 生命" % int(item.get("heal", 0)), 12, FogUITheme.GREEN)


func _cell_rect(x: int, y: int) -> Rect2:
	return Rect2(GRID.position + Vector2(x * (CELL.x + GAP), y * (CELL.y + GAP)), CELL)


func _footprint_rect(x: int, y: int, grid: Vector2i) -> Rect2:
	return Rect2(
		GRID.position + Vector2(x * (CELL.x + GAP), y * (CELL.y + GAP)),
		Vector2(grid.x * CELL.x + (grid.x - 1) * GAP, grid.y * CELL.y + (grid.y - 1) * GAP)
	)
