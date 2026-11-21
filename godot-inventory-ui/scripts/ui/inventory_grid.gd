class_name InventoryGrid
extends Control

signal item_clicked(item, index)
signal item_double_clicked(item, index)
signal item_hovered(item, screen_pos)
signal item_unhovered()
signal selection_changed(index, item)
signal page_step(delta)
signal page_requested(page)

# Reference grid (529x356): x 270..497, y 60..284, 5x5, pitch 45.4x44.8,
# cell 42x42 -> 1280x720: 102x85 cells, pitch 110x91.
const COLS := 5
const ROWS := 5
const COL_W := 110
const ROW_H := 91
const CELL := Vector2(102, 85)

var _cells: Array = []
var _state: InventoryState
var _items: Array = []
var _page := 1
var _category := "全部"
var _selected := -1
var _empty_root: Control
var _empty_title: Label
var _empty_sub: Label
var _backing: GradientRect
var scroll: PageScroll
var _fade_tween: Tween


func setup() -> void:
	size = Vector2(551, 455)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_backing = GradientRect.new()
	_backing.position = Vector2(-6, -6)
	_backing.setup(Vector2(555, 461), 10.0, ThemeKit.GRID_BACK_TOP, ThemeKit.GRID_BACK_BOTTOM,
		Color(0.66, 0.83, 0.95, 0.30), 1.2, 0.18)
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backing)
	for i in range(COLS * ROWS):
		var cell := ItemCell.new()
		cell.allocate(CELL)
		add_child(cell)
		cell.visible = false
		cell.clicked.connect(_on_cell_clicked)
		cell.double_clicked.connect(_on_cell_double)
		cell.hovered.connect(_on_cell_hovered)
		cell.unhovered.connect(_on_cell_unhovered)
		_cells.append(cell)

	_build_empty()
	scroll = PageScroll.new()
	scroll.position = Vector2(535, 2)
	scroll.size = Vector2(10, 445)
	add_child(scroll)
	scroll.page_requested.connect(func(p: int) -> void: page_requested.emit(p))


func _build_empty() -> void:
	_empty_root = Control.new()
	_empty_root.position = Vector2.ZERO
	_empty_root.size = Vector2(543, 449)
	_empty_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty_root)
	var glow := ThemeKit.glow_texture_rect("glow", Color(0.8, 0.95, 1.0, 0.42))
	glow.position = Vector2(176, 74)
	glow.size = Vector2(198, 198)
	_empty_root.add_child(glow)
	var ic := TextureRect.new()
	ic.texture = ThemeKit.icon("pouch")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(215, 104)
	ic.size = Vector2(112, 112)
	ic.modulate = Color(1, 1, 1, 0.98)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty_root.add_child(ic)
	_empty_title = ThemeKit.make_label(_empty_root, "这一页空空如也", 22, Color("f2fbff"),
		Vector2(0, 234), Vector2(543, 30), HORIZONTAL_ALIGNMENT_CENTER, ThemeKit.body_font(), 3,
		Color(0.06, 0.16, 0.24, 0.92))
	_empty_sub = ThemeKit.make_label(_empty_root, "试试切换页签，或调整下方筛选", 15, Color("d9ecf8"),
		Vector2(0, 266), Vector2(543, 26), HORIZONTAL_ALIGNMENT_CENTER, ThemeKit.body_font(), 2,
		Color(0.06, 0.16, 0.24, 0.8))
	_empty_root.visible = false


func refresh(
		state: InventoryState,
		page: int,
		category: String,
		preserve_id: String = "",
		animate_map: Dictionary = {}
	) -> void:
	_state = state
	_page = page
	_category = category
	_items = state.page_items(page, category)
	var n: int = mini(_items.size(), _cells.size())
	for i in range(_cells.size()):
		var cell: ItemCell = _cells[i]
		cell.visible = true
		var target := Vector2((i % COLS) * COL_W, (i / COLS) * ROW_H)
		if i >= n:
			# Keep all 25 slot frames visible, exactly like the reference;
			# empty frames are inert and only show the cell bevel.
			cell.set_empty(i)
			cell.position = target
			continue
		var it: Dictionary = _items[i]
		cell.set_item(it, i)
		if animate_map.has(str(it["id"])):
			cell.position = animate_map[str(it["id"])]
			var tw := cell.create_tween()
			tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(cell, "position", target, 0.18).set_delay(0.012 * i)
		else:
			cell.position = target
		cell.set_selected(false)
	_selected = -1
	if preserve_id != "":
		for i in range(n):
			if str(_items[i]["id"]) == preserve_id:
				_selected = i
				_cells[i].set_selected(true)
				break
	_empty_root.visible = _items.is_empty()
	if _items.is_empty():
		if category != "全部":
			_empty_title.text = "此分类在本页暂无物品"
			_empty_sub.text = "试试切换分类，或翻到其他页签"
		else:
			_empty_title.text = "这一页空空如也"
			_empty_sub.text = "切换页签看看，或整理背包后再来"
	scroll.set_page(page)
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.14)


func set_selected_index(index: int, emit_signal: bool = true) -> void:
	if _selected == index:
		if index >= 0 and index < _items.size():
			if emit_signal:
				selection_changed.emit(index, _items[index])
		return
	if _selected >= 0 and _selected < _cells.size():
		_cells[_selected].set_selected(false)
	_selected = index
	if _selected >= 0 and _selected < _items.size() and _selected < _cells.size():
		_cells[_selected].set_selected(true)
		if emit_signal:
			selection_changed.emit(_selected, _items[_selected])
	else:
		_selected = -1


func clear_selection() -> void:
	if _selected >= 0 and _selected < _cells.size():
		_cells[_selected].set_selected(false)
	_selected = -1


func selected_index() -> int:
	return _selected


func selected_item() -> Dictionary:
	if _selected >= 0 and _selected < _items.size():
		return _items[_selected]
	return {}


func item_count() -> int:
	return _items.size()


func items_snapshot() -> Array:
	return _items.duplicate()


func is_empty_state_visible() -> bool:
	return _empty_root != null and _empty_root.visible


func cell_at(index: int) -> ItemCell:
	if index >= 0 and index < _cells.size():
		return _cells[index]
	return null


func cell_for_item_id(id: String) -> ItemCell:
	for i in range(_items.size()):
		if str(_items[i]["id"]) == id:
			return _cells[i]
	return null


func move_selection(dx: int, dy: int) -> void:
	var n := _items.size()
	if n == 0:
		return
	var idx := _selected
	if idx < 0:
		set_selected_index(0)
		return
	var next := idx
	if dx != 0:
		next = clampi(idx + dx, 0, n - 1)
	if dy != 0:
		next = clampi(idx + dy * COLS, 0, n - 1)
	set_selected_index(next)


func get_position_map() -> Dictionary:
	var map := {}
	for i in range(_items.size()):
		if i < _cells.size():
			map[str(_items[i]["id"])] = _cells[i].position
	return map


func demo_hover(index: int) -> void:
	if index >= 0 and index < _items.size() and index < _cells.size():
		_cells[index].simulate_hover(true)


func demo_unhover() -> void:
	for cell in _cells:
		if cell.hovered_state:
			cell.simulate_hover(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		page_step.emit(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		accept_event()


func _on_cell_clicked(cell, item: Dictionary, index: int) -> void:
	set_selected_index(index, false)
	item_clicked.emit(item, index)


func _on_cell_double(cell, item: Dictionary, index: int) -> void:
	set_selected_index(index, false)
	item_double_clicked.emit(item, index)


func _on_cell_hovered(cell, item: Dictionary, screen_pos: Vector2) -> void:
	item_hovered.emit(item, screen_pos)


func _on_cell_unhovered(_cell) -> void:
	item_unhovered.emit()


class PageScroll extends Control:
	signal page_requested(page: int)

	var page := 1
	var pages := 5
	var _dragging := false
	var _hover := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func set_page(p: int) -> void:
		page = clampi(p, 1, pages)
		queue_redraw()

	func _thumb_rect() -> Rect2:
		var h: float = maxf(52.0, size.y / float(pages))
		var usable: float = maxf(1.0, size.y - h)
		var t: float = float(page - 1) / float(maxi(1, pages - 1))
		return Rect2(1, t * usable, size.x - 2, h)

	func _draw() -> void:
		# deliberately low-contrast: the reference has no visible scrollbar
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0.10, 0.24, 0.36, 0.10 if not _hover else 0.18)
		track.border_color = Color(0.85, 0.96, 1.0, 0.16)
		track.set_border_width_all(1)
		track.corner_radius_top_left = 4
		track.corner_radius_top_right = 4
		track.corner_radius_bottom_left = 4
		track.corner_radius_bottom_right = 4
		track.anti_aliasing = true
		draw_style_box(track, Rect2(1, 0, size.x - 2, size.y))
		for i in range(1, pages):
			var ty: float = size.y * float(i) / float(pages)
			draw_line(Vector2(2, ty), Vector2(size.x - 2, ty), Color(0.90, 0.98, 1.0, 0.14), 1.0)
		var thumb := StyleBoxFlat.new()
		thumb.bg_color = Color(0.92, 0.98, 1.0, 0.16 if not _hover else 0.45)
		thumb.border_color = Color(0.95, 0.78, 0.42, 0.28 if not _hover else 0.65)
		thumb.set_border_width_all(1)
		thumb.corner_radius_top_left = 4
		thumb.corner_radius_top_right = 4
		thumb.corner_radius_bottom_left = 4
		thumb.corner_radius_bottom_right = 4
		thumb.anti_aliasing = true
		draw_style_box(thumb, _thumb_rect())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
				page_requested.emit(clampi(page + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 1, pages))
				accept_event()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_dragging = true
					_set_from_y(event.position.y)
					accept_event()
				else:
					_dragging = false
		elif event is InputEventMouseMotion and _dragging:
			_set_from_y(event.position.y)
			accept_event()

	func _set_from_y(y: float) -> void:
		var h: float = maxf(52.0, size.y / float(pages))
		var usable: float = maxf(1.0, size.y - h)
		var t: float = clampf((y - h * 0.5) / usable, 0.0, 1.0)
		var np: int = int(round(t * float(pages - 1))) + 1
		if np != page:
			page = np
			queue_redraw()
			page_requested.emit(page)
