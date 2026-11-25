extends Control

const LevelData := preload("res://scripts/level_data.gd")
const TileArt := preload("res://scripts/tile_art.gd")

# 网格画布：绘制、选择、平移与缩放都在这里。
# 数据写入 LevelData；撤销/属性刷新通过 editor 回调。

const MIN_ZOOM := 1
const MAX_ZOOM := 4

const C_BG := Color("#0c1218")
const C_MAP_BG := Color("#111a21")
const C_BORDER := Color("#3c4d57")
const C_GRID := Color(0.84, 0.9, 0.87, 0.085)
const C_GRID_MAJOR := Color(0.84, 0.9, 0.87, 0.17)
const C_TEXT := Color("#c9d4cc")
const C_MUTED := Color("#7f938d")
const C_ACCENT := Color("#a9cf7a")
const C_GOLD := Color("#e8b36a")
const C_DANGER := Color("#e08a7a")
const C_PICK := Color("#7fb8de")
const C_HOVER := Color("#e6e3c8")
const C_SHAPE := Color(0.86, 0.73, 0.43, 0.2)

var editor: Control
var data: LevelData

var zoom: int = 1
var pan := Vector2.ZERO
var hover_cell := Vector2i(-1, -1)
var hover_entity_id := ""
var mouse_inside := false

var panning := false
var painting := false
var paint_layer := ""
var painting_erase := false
var last_paint_cell := Vector2i(-1, -1)

var shape_active := false
var shape_tool := ""
var shape_anchor := Vector2i(-1, -1)
var shape_cells: Array[Vector2i] = []

var drag_entity_id := ""
var drag_started := false
var drag_start_cell := Vector2i(-1, -1)

var _font: Font


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	resized.connect(_on_resized)
	_font = get_theme_default_font()


func bind_level(level: LevelData) -> void:
	data = level
	hover_cell = Vector2i(-1, -1)
	hover_entity_id = ""
	shape_active = false
	painting = false
	drag_entity_id = ""
	if is_inside_tree() and size.x > 0:
		fit_view()
	else:
		call_deferred("fit_view")
	queue_redraw()


func _cell_px() -> int:
	if data == null:
		return 16
	return data.cell_size * zoom


func _map_size_px() -> Vector2:
	if data == null:
		return Vector2.ZERO
	return Vector2(data.width, data.height) * _cell_px()


func map_origin() -> Vector2:
	if data == null:
		return Vector2.ZERO
	var base := (size - _map_size_px()) * 0.5
	return (base + pan).round()


func cell_center_local(cell: Vector2i) -> Vector2:
	return map_origin() + (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_px()


func local_to_cell(pos: Vector2) -> Vector2i:
	if data == null:
		return Vector2i(-1, -1)
	var px := _cell_px()
	var local := pos - map_origin()
	return Vector2i(floori(local.x / px), floori(local.y / px))


func _in_bounds(cell: Vector2i) -> bool:
	return data != null and data.in_bounds(cell.x, cell.y)


func fit_view() -> void:
	if data == null or size.x < 64 or size.y < 64:
		return
	var found := 1
	for candidate in [4, 3, 2, 1]:
		if data.width * data.cell_size * candidate <= size.x - 40 \
				and data.height * data.cell_size * candidate <= size.y - 48:
			found = candidate
			break
	zoom = found
	pan = Vector2.ZERO
	queue_redraw()


func set_zoom_level(new_zoom: int, focus_local: Vector2 = Vector2.INF) -> void:
	if data == null:
		return
	new_zoom = clampi(new_zoom, MIN_ZOOM, MAX_ZOOM)
	if new_zoom == zoom:
		return
	var focus := size * 0.5 if focus_local == Vector2.INF else focus_local
	var old_origin := map_origin()
	var before := (focus - old_origin) / float(_cell_px())
	zoom = new_zoom
	var base := (size - _map_size_px()) * 0.5
	pan = focus - before * float(_cell_px()) - base
	_clamp_pan()
	queue_redraw()


func zoom_in() -> void:
	set_zoom_level(zoom + 1)


func zoom_out() -> void:
	set_zoom_level(zoom - 1)


func _clamp_pan() -> void:
	if data == null:
		return
	var map := _map_size_px()
	var base := (size - map) * 0.5
	var origin := base + pan
	var keep := 72.0
	var min_origin := Vector2(mini(size.x - keep, 0.0) - map.x, mini(size.y - keep, 0.0) - map.y)
	var max_origin := Vector2(maxf(keep, size.x - keep), maxf(keep, size.y - keep))
	origin.x = clampf(origin.x, min_origin.x, max_origin.x)
	origin.y = clampf(origin.y, min_origin.y, max_origin.y)
	pan = origin - base


func _on_resized() -> void:
	_clamp_pan()
	queue_redraw()


func _mouse_exited() -> void:
	mouse_inside = false
	if painting:
		painting = false
		if editor != null:
			editor.end_action()
	if shape_active:
		shape_active = false
		shape_cells = []
	if drag_entity_id != "":
		if drag_started and editor != null:
			editor.end_action()
		drag_entity_id = ""
		drag_started = false
	panning = false
	if hover_cell != Vector2i(-1, -1):
		hover_cell = Vector2i(-1, -1)
		hover_entity_id = ""
		if editor != null:
			editor.update_hover(hover_cell)
	refresh_cursor()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse_exited()


func refresh_cursor() -> void:
	if editor == null:
		return
	if panning:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		return
	match String(editor.tool):
		"select":
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover_entity_id != "" else Control.CURSOR_ARROW
		"picker":
			mouse_default_cursor_shape = Control.CURSOR_CROSS
		"eraser":
			mouse_default_cursor_shape = Control.CURSOR_CROSS
		_:
			mouse_default_cursor_shape = Control.CURSOR_CROSS


# ---------------- 输入 ----------------

func _gui_input(event: InputEvent) -> void:
	if data == null or editor == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			set_zoom_level(zoom + 1, mb.position)
			editor.update_zoom_label()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			set_zoom_level(zoom - 1, mb.position)
			editor.update_zoom_label()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			panning = mb.pressed
			if panning:
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			else:
				refresh_cursor()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_cancel_gesture()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		grab_focus()
		if mb.pressed:
			if Input.is_key_pressed(KEY_SPACE):
				panning = true
				mouse_default_cursor_shape = Control.CURSOR_DRAG
				return
			_on_left_press(mb.position)
		else:
			_on_left_release(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if panning:
			pan += mm.relative
			_clamp_pan()
			queue_redraw()
			return
		_on_motion(mm.position)
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		pan -= pg.delta * 18.0
		_clamp_pan()
		queue_redraw()


func _update_hover(pos: Vector2) -> void:
	var cell := local_to_cell(pos)
	if not _in_bounds(cell):
		cell = Vector2i(-1, -1)
	if cell != hover_cell:
		hover_cell = cell
		var new_hover_id := ""
		if cell != Vector2i(-1, -1) and String(editor.layer_id) == "entities":
			var entity := data.entity_at(cell.x, cell.y)
			if not entity.is_empty():
				new_hover_id = String(entity["id"])
		hover_entity_id = new_hover_id
		editor.update_hover(hover_cell)
	refresh_cursor()
	queue_redraw()


func _on_motion(pos: Vector2) -> void:
	_update_hover(pos)
	var cell := local_to_cell(pos)
	if not _in_bounds(cell):
		return
	if painting:
		match paint_layer:
			"terrain":
				for c in LevelData.line_cells(last_paint_cell, cell):
					if _in_bounds(c):
						if painting_erase:
							data.erase_terrain(c.x, c.y, bool(editor.auto_tiles))
						else:
							data.paint_terrain(c.x, c.y, String(editor.paint_type), int(editor.paint_variant), bool(editor.auto_tiles))
			"collision":
				for c in LevelData.line_cells(last_paint_cell, cell):
					if _in_bounds(c):
						data.paint_collision(c.x, c.y, not painting_erase)
			"entities":
				if painting_erase:
					for c in LevelData.line_cells(last_paint_cell, cell):
						var entity := data.entity_at(c.x, c.y)
						if not entity.is_empty():
							data.remove_entity(String(entity["id"]))
		last_paint_cell = cell
		queue_redraw()
	elif shape_active:
		shape_cells = _shape_cells(shape_anchor, cell)
		queue_redraw()
	elif drag_entity_id != "":
		if cell != drag_start_cell and not drag_started:
			drag_started = true
			editor.begin_action("移动实体")
		if drag_started:
			var occupant := data.entity_at(cell.x, cell.y)
			if occupant.is_empty() or String(occupant["id"]) == drag_entity_id:
				if data.move_entity(drag_entity_id, cell.x, cell.y):
					editor.select_cell(cell)
					editor.sync_entity_selection()
					queue_redraw()


func _on_left_press(pos: Vector2) -> void:
	var cell := local_to_cell(pos)
	if not _in_bounds(cell):
		return
	var layer := String(editor.layer_id)
	if not editor.is_layer_visible(layer):
		editor.toast("当前图层已隐藏，先点图层左侧“显示”。")
		return
	if editor.is_layer_locked(layer):
		editor.toast("当前图层已锁定，解锁后才能编辑。")
		return
	var tool := String(editor.tool)
	editor.select_cell(cell)
	match tool:
		"select":
			if layer == "entities":
				var entity := data.entity_at(cell.x, cell.y)
				if entity.is_empty():
					editor.select_entity("")
				else:
					editor.select_entity(String(entity["id"]))
					drag_entity_id = String(entity["id"])
					drag_started = false
					drag_start_cell = cell
			else:
				editor.select_entity("")
		"brush":
			match layer:
				"terrain":
					editor.begin_action("画笔")
					painting = true
					paint_layer = "terrain"
					painting_erase = false
					last_paint_cell = cell
					data.paint_terrain(cell.x, cell.y, String(editor.paint_type), int(editor.paint_variant), bool(editor.auto_tiles))
					editor.select_entity("")
					queue_redraw()
				"collision":
					editor.begin_action("标记碰撞")
					painting = true
					paint_layer = "collision"
					painting_erase = false
					last_paint_cell = cell
					data.paint_collision(cell.x, cell.y, true)
					editor.select_entity("")
					queue_redraw()
				"entities":
					var existing := data.entity_at(cell.x, cell.y)
					if not existing.is_empty():
						editor.select_entity(String(existing["id"]))
						return
					editor.begin_action("放置实体")
					var entity := data.add_entity(String(editor.entity_type), cell.x, cell.y)
					editor.end_action()
					if not entity.is_empty():
						editor.select_entity(String(entity["id"]))
					queue_redraw()
		"eraser":
			match layer:
				"terrain":
					editor.begin_action("橡皮")
					painting = true
					paint_layer = "terrain"
					painting_erase = true
					last_paint_cell = cell
					data.erase_terrain(cell.x, cell.y, bool(editor.auto_tiles))
					editor.select_entity("")
					queue_redraw()
				"collision":
					editor.begin_action("擦除碰撞")
					painting = true
					paint_layer = "collision"
					painting_erase = true
					last_paint_cell = cell
					data.paint_collision(cell.x, cell.y, false)
					editor.select_entity("")
					queue_redraw()
				"entities":
					var entity := data.entity_at(cell.x, cell.y)
					if not entity.is_empty():
						editor.begin_action("删除实体")
						data.remove_entity(String(entity["id"]))
						editor.select_entity("")
						editor.end_action()
						queue_redraw()
		"rect", "line":
			if layer == "entities":
				editor.toast("实体层请用“放置/选择”；矩形与直线用于地形/碰撞。")
				return
			shape_active = true
			shape_tool = tool
			shape_anchor = cell
			shape_cells = [cell]
			editor.select_entity("")
			queue_redraw()
		"picker":
			_pick_at(cell, layer)


func _pick_at(cell: Vector2i, layer: String) -> void:
	match layer:
		"terrain":
			var tile := data.get_tile(cell.x, cell.y)
			if tile.is_empty():
				editor.toast("拾取了空格子。")
				return
			editor.apply_picked_tile(String(tile["type"]), int(tile.get("variant", -1)))
			editor.toast("已拾取：%s · %s" % [
				LevelData.TILE_NAMES.get(String(tile["type"]), "地形"),
				"自动" if int(tile.get("variant", -1)) < 0 else "手动变体 %d" % int(tile["variant"]),
			])
		"collision":
			var solid := data.collision_at(cell.x, cell.y)
			editor.toast("此格碰撞：%s" % ("实心" if solid else "可通行"))
		"entities":
			var entity := data.entity_at(cell.x, cell.y)
			if not entity.is_empty():
				editor.apply_picked_entity(String(entity["type"]))
				editor.toast("已拾取实体类型：%s" % LevelData.ENTITY_NAMES.get(String(entity["type"]), "实体"))
			else:
				editor.toast("这里有没实体可拾取。")


func _shape_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	if shape_tool == "line":
		return LevelData.line_cells(a, b)
	return LevelData.rect_cells(a, b)


func _on_left_release(pos: Vector2) -> void:
	if panning:
		panning = false
		refresh_cursor()
		return
	if painting:
		editor.end_action()
		painting = false
		last_paint_cell = Vector2i(-1, -1)
		queue_redraw()
		return
	if shape_active:
		var cell := local_to_cell(pos)
		if _in_bounds(cell):
			shape_cells = _shape_cells(shape_anchor, cell)
		_apply_shape()
		return
	if drag_entity_id != "":
		if drag_started:
			editor.end_action()
		drag_entity_id = ""
		drag_started = false
		queue_redraw()


func _apply_shape() -> void:
	if shape_cells.is_empty():
		shape_active = false
		return
	var layer := String(editor.layer_id)
	var bounds := Rect2i(shape_anchor, Vector2i.ONE)
	editor.begin_action("矩形填充" if shape_tool == "rect" else "直线绘制")
	for c in shape_cells:
		if not _in_bounds(c):
			continue
		bounds = bounds.expand(c)
		if layer == "terrain":
			data.paint_terrain(c.x, c.y, String(editor.paint_type), int(editor.paint_variant), false)
		elif layer == "collision":
			data.paint_collision(c.x, c.y, true)
	if layer == "terrain":
		if bool(editor.auto_tiles):
			data.autotile_area(bounds.grow(1))
		else:
			for c in shape_cells:
				if _in_bounds(c):
					data.autotile_cell(c.x, c.y)
	editor.end_action()
	shape_active = false
	shape_cells = []
	queue_redraw()


func _cancel_gesture() -> void:
	if shape_active:
		shape_active = false
		shape_cells = []
		editor.toast("已取消范围预览。")
	elif painting:
		painting = false
		editor.end_action()
	elif drag_entity_id != "":
		if drag_started:
			editor.end_action()
		drag_entity_id = ""
		drag_started = false
	queue_redraw()


# ---------------- 绘制 ----------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	_draw_backdrop()
	if data == null:
		return
	if _font == null:
		_font = get_theme_default_font()
	var px := _cell_px()
	var origin := map_origin()
	var map_rect := Rect2(origin, _map_size_px())
	draw_rect(Rect2(origin + Vector2(7, 8), _map_size_px()), Color(0, 0, 0, 0.3))
	draw_rect(map_rect, C_MAP_BG)
	draw_rect(map_rect, C_BORDER, false, 1.0)

	var top_left := Vector2i(
		clampi(floori(-origin.x / px), 0, data.width),
		clampi(floori(-origin.y / px), 0, data.height)
	)
	var bottom_right := Vector2i(
		clampi(ceili((size.x - origin.x) / px), 0, data.width),
		clampi(ceili((size.y - origin.y) / px), 0, data.height)
	)

	if editor.is_layer_visible("terrain"):
		for y in range(top_left.y, bottom_right.y):
			for x in range(top_left.x, bottom_right.x):
				_draw_terrain_cell(x, y, origin, px)
	else:
		_draw_hidden_watermark("地形层已隐藏", map_rect)

	if editor.is_layer_visible("collision"):
		var collision_focus := String(editor.layer_id) == "collision"
		for y in range(top_left.y, bottom_right.y):
			for x in range(top_left.x, bottom_right.x):
				if data.collision_at(x, y):
					_draw_collision_cell(x, y, origin, px, collision_focus)

	_draw_grid(origin, px, map_rect)

	if editor.is_layer_visible("entities"):
		for entity in data.entities:
			var cell := Vector2i(int(entity["x"]), int(entity["y"]))
			if cell.x < top_left.x - 1 or cell.x > bottom_right.x or cell.y < top_left.y - 1 or cell.y > bottom_right.y:
				continue
			_draw_entity(entity, cell, origin, px)
	else:
		_draw_hidden_watermark("实体层已隐藏", map_rect)

	if shape_active and not shape_cells.is_empty():
		for c in shape_cells:
			if _in_bounds(c):
				var r := Rect2(origin + Vector2(c) * px + Vector2.ONE * 1, Vector2(px - 2, px - 2))
				draw_rect(r, C_SHAPE)
		var a := shape_cells[0]
		var b := shape_cells[shape_cells.size() - 1]
		var bounds := Rect2(origin + Vector2(mini(a.x, b.x), mini(a.y, b.y)) * px, Vector2(absi(b.x - a.x) + 1, absi(b.y - a.y) + 1) * px)
		draw_rect(bounds, C_GOLD, false, 2.0)

	_draw_selection(origin, px)
	_draw_hover(origin, px)
	_draw_coords(origin, px, top_left, bottom_right)
	_draw_hud(map_rect)


func _draw_backdrop() -> void:
	var step := 32
	var max_x := int(size.x / step) + 1
	var max_y := int(size.y / step) + 1
	for y in max_y:
		for x in max_x:
			draw_rect(Rect2(Vector2(x, y) * step, Vector2.ONE), Color(0.55, 0.7, 0.63, 0.055))


func _draw_terrain_cell(x: int, y: int, origin: Vector2, px: int) -> void:
	var tile := data.get_tile(x, y)
	var rect := Rect2(origin + Vector2(x, y) * px, Vector2(px, px))
	if tile.is_empty():
		if (x + y) % 2 == 0:
			draw_rect(rect, Color(0.07, 0.11, 0.14, 0.5))
		return
	var tex := TileArt.tile_texture(
		String(tile["type"]),
		int(tile.get("mask", 0)),
		int(tile.get("variant", -1))
	)
	draw_texture_rect(tex, rect, false, Color.WHITE)


func _draw_collision_cell(x: int, y: int, origin: Vector2, px: int, strong: bool) -> void:
	var rect := Rect2(origin + Vector2(x, y) * px, Vector2(px, px))
	if strong:
		draw_rect(rect, Color(0.88, 0.25, 0.2, 0.22))
		var step := maxi(4, px / 2)
		for offset in range(-px, px, step):
			var p1 := rect.position + Vector2(maxi(0, offset), mini(px, offset + px))
			var p2 := rect.position + Vector2(mini(px, offset + px), maxi(0, offset))
			draw_line(p1, p2, Color(1.0, 0.42, 0.32, 0.55), 1.0)
		draw_rect(rect, Color(1.0, 0.48, 0.38, 0.4), false, 1.0)
	else:
		draw_rect(rect, Color(0.9, 0.36, 0.28, 0.055))
		var inset := maxi(2, px / 8)
		draw_line(rect.position + Vector2(inset, inset), rect.end - Vector2(inset, inset), Color(1.0, 0.5, 0.4, 0.22), 1.0)


func _draw_grid(origin: Vector2, px: int, map_rect: Rect2) -> void:
	if px < 12:
		return
	var x0 := int((0 - origin.x) / px)
	var x1 := int((size.x - origin.x) / px) + 1
	var y0 := int((0 - origin.y) / px)
	var y1 := int((size.y - origin.y) / px) + 1
	for x in range(maxi(0, x0), mini(data.width, x1) + 1):
		var sx := origin.x + x * px
		var major := x % 4 == 0
		draw_line(Vector2(sx, maxf(origin.y, 0)), Vector2(sx, minf(origin.y + data.height * px, size.y)), C_GRID_MAJOR if major else C_GRID, 1.0)
	for y in range(maxi(0, y0), mini(data.height, y1) + 1):
		var sy := origin.y + y * px
		var major := y % 4 == 0
		draw_line(Vector2(maxf(origin.x, 0), sy), Vector2(minf(origin.x + data.width * px, size.x), sy), C_GRID_MAJOR if major else C_GRID, 1.0)
	# 外框再压一层，避免网格盖住边线
	draw_rect(map_rect, Color(0.55, 0.65, 0.63, 0.22), false, 1.0)


func _draw_entity(entity: Dictionary, cell: Vector2i, origin: Vector2, px: int) -> void:
	var rect := Rect2(origin + Vector2(cell) * px, Vector2(px, px))
	var entity_type := String(entity["type"])
	var tex := TileArt.entity_texture(entity_type)
	draw_texture_rect(tex, rect, false, Color.WHITE)
	var color := C_GOLD
	if entity_type == "spawn":
		color = Color("#a9cf7a")
	elif entity_type == "enemy":
		color = Color("#b79bd8")
	draw_rect(rect, Color(color.r, color.g, color.b, 0.28), false, 1.0)
	if entity_type == "spawn" or entity_type == "enemy":
		var props: Dictionary = entity.get("props", {})
		_draw_facing_mark(rect, String(props.get("facing", "down")), color)
	var selected := String(editor.selected_entity_id) == String(entity["id"])
	var hovered := hover_entity_id == String(entity["id"])
	if selected or hovered:
		var outline := C_GOLD if selected else C_HOVER
		draw_rect(rect.grow(1), outline, false, 2.0)
		if selected:
			var label := "%s · %s" % [String(entity["id"]), LevelData.ENTITY_NAMES.get(entity_type, "实体")]
			_draw_entity_label(label, rect)


func _draw_facing_mark(rect: Rect2, facing: String, color: Color) -> void:
	var dir := Vector2.DOWN
	match facing:
		"up":
			dir = Vector2.UP
		"left":
			dir = Vector2.LEFT
		"right":
			dir = Vector2.RIGHT
	var center := rect.get_center() + dir * rect.size.x * 0.34
	var perp := Vector2(-dir.y, dir.x)
	var tip := center + dir * 3.5
	var a := center - dir * 1.5 + perp * 2.5
	var b := center - dir * 1.5 - perp * 2.5
	draw_colored_polygon(PackedVector2Array([tip, a, b]), Color(color.r, color.g, color.b, 0.9))


func _draw_entity_label(text: String, rect: Rect2) -> void:
	var fs := 11
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pad := Vector2(5, 3)
	var pos := Vector2(rect.position.x, rect.position.y - text_size.y - pad.y * 2 - 2)
	if pos.y < 4:
		pos.y = rect.position.y + rect.size.y + 2
	var box := Rect2(pos, text_size + pad * 2)
	draw_rect(box, Color(0.06, 0.09, 0.1, 0.94))
	draw_rect(box, C_GOLD, false, 1.0)
	draw_string(_font, pos + Vector2(pad.x, text_size.y + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#f3e7c6"))


func _draw_selection(origin: Vector2, px: int) -> void:
	var cell: Vector2i = editor.selected_cell
	if _in_bounds(cell):
		var rect := Rect2(origin + Vector2(cell) * px, Vector2(px, px))
		draw_rect(rect.grow(1), C_GOLD, false, 2.0)
		var hs := maxi(2, px / 10)
		for corner in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(0, rect.size.y), rect.end]:
			draw_rect(Rect2(corner - Vector2(hs, hs), Vector2(hs * 2, hs * 2)), C_GOLD)


func _draw_hover(origin: Vector2, px: int) -> void:
	if not _in_bounds(hover_cell):
		return
	var tool := String(editor.tool)
	var color := C_HOVER
	match tool:
		"brush":
			color = C_ACCENT
		"eraser":
			color = C_DANGER
		"picker":
			color = C_PICK
		"rect", "line":
			color = C_GOLD
	var rect := Rect2(origin + Vector2(hover_cell) * px, Vector2(px, px))
	if tool == "brush" or tool == "eraser" or tool == "rect" or tool == "line":
		draw_rect(rect, Color(color.r, color.g, color.b, 0.09))
	draw_rect(rect, color, false, 2.0 if tool != "select" else 1.0)
	if tool == "picker" and String(editor.layer_id) == "terrain":
		var tile := data.get_tile(hover_cell.x, hover_cell.y)
		if not tile.is_empty():
			draw_circle(rect.get_center(), maxf(3.0, px * 0.12), color)


func _draw_coords(origin: Vector2, px: int, top_left: Vector2i, bottom_right: Vector2i) -> void:
	if px < 24 or _font == null:
		return
	var fs := 9
	var label_color := Color(0.72, 0.82, 0.76, 0.72)
	var label_y := origin.y - 4.0
	if label_y < 8.0:
		label_y = maxf(9.0, origin.y + 4.0)
	var label_x := origin.x - 17.0
	if label_x < 2.0:
		label_x = maxf(3.0, origin.x + 4.0)
	for x in range(top_left.x, bottom_right.x + 1):
		if x % 4 != 0:
			continue
		var pos := origin + Vector2(x * px + 2, 0)
		pos.y = label_y
		if pos.x < 0 or pos.x > size.x - 12 or pos.y < 2 or pos.y > size.y - 4:
			continue
		draw_string(_font, pos, str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, label_color)
	for y in range(maxi(0, top_left.y), mini(data.height, bottom_right.y) + 1):
		if y % 4 != 0:
			continue
		var pos := origin + Vector2(0, y * px + 11)
		pos.x = label_x
		if pos.x < 0 or pos.y < 2 or pos.y > size.y - 4:
			continue
		draw_string(_font, pos, str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, label_color)


func _draw_hud(map_rect: Rect2) -> void:
	var layer_name := String(LevelData.LAYER_NAMES.get(String(editor.layer_id), "图层"))
	var tool_name := String(editor.tool_label())
	var text := "%s · %s" % [layer_name, tool_name]
	_draw_pill(text, Vector2(10, 9))
	var coord := "画布外"
	if _in_bounds(hover_cell):
		coord = "格 %d, %d" % [hover_cell.x, hover_cell.y]
		if editor.tool == "rect" or editor.tool == "line":
			coord += " · 拖拽范围"
	elif _in_bounds(editor.selected_cell):
		coord = "选中 %d, %d" % [editor.selected_cell.x, editor.selected_cell.y]
	_draw_pill_right(coord, Vector2(size.x - 10, 9))
	if not editor.is_layer_visible(String(editor.layer_id)):
		_draw_pill_center("当前图层已隐藏", map_rect)


func _draw_pill(text: String, pos: Vector2) -> void:
	if _font == null:
		return
	var fs := 11
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var box := Rect2(pos, ts + Vector2(14, 8))
	draw_rect(box, Color(0.055, 0.08, 0.095, 0.88))
	draw_rect(box, Color(0.3, 0.4, 0.4, 0.7), false, 1.0)
	draw_string(_font, pos + Vector2(7, 4 + ts.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TEXT)


func _draw_pill_right(text: String, pos: Vector2) -> void:
	if _font == null:
		return
	var fs := 11
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var box := Rect2(pos - Vector2(ts.x + 14, 0), ts + Vector2(14, 8))
	draw_rect(box, Color(0.055, 0.08, 0.095, 0.88))
	draw_rect(box, Color(0.3, 0.4, 0.4, 0.7), false, 1.0)
	draw_string(_font, box.position + Vector2(7, 4 + ts.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TEXT)


func _draw_pill_center(text: String, map_rect: Rect2) -> void:
	if _font == null:
		return
	var fs := 12
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := map_rect.get_center() - Vector2(ts.x * 0.5 + 10, 0)
	var box := Rect2(pos, ts + Vector2(20, 12))
	draw_rect(box, Color(0.05, 0.07, 0.08, 0.9))
	draw_rect(box, C_GOLD, false, 1.0)
	draw_string(_font, pos + Vector2(10, 9 + ts.y * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_GOLD)


func _draw_hidden_watermark(text: String, map_rect: Rect2) -> void:
	if _font == null:
		return
	var fs := 11
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(map_rect.position.x + 12, map_rect.position.y + 24)
	draw_rect(Rect2(pos - Vector2(5, 4), ts + Vector2(10, 8)), Color(0.05, 0.07, 0.08, 0.7))
	draw_string(_font, pos + Vector2(0, ts.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_MUTED)
