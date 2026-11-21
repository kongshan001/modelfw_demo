class_name InventoryGrid
extends Control

signal item_clicked(item, index)
signal item_double_clicked(item, index)
signal item_hovered(item, screen_pos)
signal item_unhovered()
signal selection_changed(index, item)
signal page_step(delta)
signal page_requested(page)

const COLS := 5
const ROWS := 5
const COL_W := 112
const ROW_H := 91
const CELL := Vector2(104, 84)

var _cells: Array = []
var _state: InventoryState
var _items: Array = []
var _page := 1
var _category := "全部"
var _selected := -1
var _empty_root: Control
var _empty_title: Label
var _empty_sub: Label
var scroll: PageScroll
var _fade_tween: Tween


func setup() -> void:
	size = Vector2(566, 448)
	mouse_filter = Control.MOUSE_FILTER_PASS
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
	scroll.position = Vector2(553, 0)
	scroll.size = Vector2(13, 448)
	add_child(scroll)
	scroll.page_requested.connect(func(p: int) -> void: page_requested.emit(p))


func _build_empty() -> void:
	_empty_root = Control.new()
	_empty_root.position = Vector2.ZERO
	_empty_root.size = Vector2(552, 448)
	_empty_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty_root)
	var glow := ThemeKit.glow_texture_rect("glow", Color(0.7, 0.9, 1.0, 0.20))
	glow.position = Vector2(200, 92)
	glow.size = Vector2(170, 170)
	_empty_root.add_child(glow)
	var ic := TextureRect.new()
	ic.texture = ThemeKit.icon("pouch")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(226, 108)
	ic.size = Vector2(112, 112)
	ic.modulate = Color(1, 1, 1, 0.75)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty_root.add_child(ic)
	_empty_title = ThemeKit.make_label(_empty_root, "这一页空空如也", 20, ThemeKit.TEXT_INK,
		Vector2(0, 236), Vector2(552, 30), HORIZONTAL_ALIGNMENT_CENTER)
	_empty_sub = ThemeKit.make_label(_empty_root, "试试切换页签，或调整上方分类", 14, ThemeKit.TEXT_INK_SOFT,
		Vector2(0, 268), Vector2(552, 26), HORIZONTAL_ALIGNMENT_CENTER)
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
		if i >= n:
			cell.visible = false
			cell.set_selected(false)
			continue
		var it: Dictionary = _items[i]
		cell.visible = true
		cell.set_item(it, i)
		var target := Vector2((i % COLS) * COL_W, (i / COLS) * ROW_H)
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
		var h: float = maxf(64.0, size.y / float(pages))
		var usable: float = maxf(1.0, size.y - h)
		var t: float = float(page - 1) / float(maxi(1, pages - 1))
		return Rect2(0, t * usable, size.x, h)

	func _draw() -> void:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0.06, 0.17, 0.26, 0.42)
		track.border_color = Color(0.78, 0.93, 1.0, 0.28)
		track.set_border_width_all(1)
		track.corner_radius_top_left = 5
		track.corner_radius_top_right = 5
		track.corner_radius_bottom_left = 5
		track.corner_radius_bottom_right = 5
		track.anti_aliasing = true
		draw_style_box(track, Rect2(1, 0, size.x - 2, size.y))
		for i in range(1, pages):
			var ty: float = size.y * float(i) / float(pages)
			draw_line(Vector2(4, ty), Vector2(size.x - 4, ty), Color(0.86, 0.96, 1.0, 0.22), 1.0)
		var thumb := StyleBoxFlat.new()
		thumb.bg_color = Color(0.99, 0.99, 1.0, 0.98) if _hover else Color(0.89, 0.97, 1.0, 0.92)
		thumb.border_color = Color(0.89, 0.70, 0.36, 0.95)
		thumb.set_border_width_all(2)
		thumb.corner_radius_top_left = 6
		thumb.corner_radius_top_right = 5
		thumb.corner_radius_bottom_left = 5
		thumb.corner_radius_bottom_right = 5
		thumb.anti_aliasing = true
		var tr := _thumb_rect()
		draw_style_box(thumb, tr)
		var mid := Vector2(size.x * 0.5, tr.position.y + tr.size.y * 0.5)
		draw_colored_polygon(PackedVector2Array([
			mid + Vector2(0, -4), mid + Vector2(3, 0), mid + Vector2(0, 4), mid + Vector2(-3, 0),
		]), Color(0.82, 0.62, 0.28, 0.85))
		draw_circle(Vector2(size.x * 0.5, 4), 2.2, Color(0.96, 0.85, 0.55, 0.9))
		draw_circle(Vector2(size.x * 0.5, size.y - 4), 2.2, Color(0.96, 0.85, 0.55, 0.9))

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
		var h: float = maxf(64.0, size.y / float(pages))
		var usable: float = maxf(1.0, size.y - h)
		var t: float = clampf((y - h * 0.5) / usable, 0.0, 1.0)
		var np: int = int(round(t * float(pages - 1))) + 1
		if np != page:
			page = np
			queue_redraw()
			page_requested.emit(page)
