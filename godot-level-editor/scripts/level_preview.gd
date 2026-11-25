class_name LevelPreview
extends Control

const LevelData := preload("res://scripts/level_data.gd")
const TileArt := preload("res://scripts/tile_art.gd")

# “运行预览”：只接收导出的运行时 JSON，从零解析成可走的小场景。
# 这不是完整游戏，只验证存档能被读回、碰撞/出生点/实体都成立。

const SPEED := 94.0
const C_BG := Color("#0a1014")
const C_FRAME := Color("#334a46")
const C_TEXT := Color("#d5dfd7")
const C_MUTED := Color("#8a9d94")
const C_GOLD := Color("#e8b36a")

var level: LevelData
var player_pos := Vector2.ZERO
var facing := "down"
var collected := {}
var collected_order: Array[String] = []
var pickup_flash := 0.0
var last_pickup := ""
var elapsed := 0.0
var scale_factor := 1
var map_origin := Vector2.ZERO
var map_texture: Texture2D
var validation := {}
var moving_time := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = get_theme_default_font()
	set_process(true)


func load_json(text: String) -> Dictionary:
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return {"ok": false, "errors": ["运行时 JSON 解析失败：%s" % json.get_error_message()], "warnings": []}
	if not (json.data is Dictionary):
		return {"ok": false, "errors": ["运行时 JSON 根节点必须是对象。"], "warnings": []}
	var new_level := LevelData.new(1, 1, 16)
	var errors := new_level.from_dict(json.data)
	if not errors.is_empty():
		level = null
		queue_redraw()
		return {"ok": false, "errors": errors, "warnings": []}
	level = new_level
	_build_map_texture()
	validation = level.validate()
	var spawn := level.find_preview_spawn()
	var spawn_entity := level.spawn_entity()
	if not spawn_entity.is_empty():
		facing = String(spawn_entity.get("props", {}).get("facing", "down"))
	if not LevelData.FACING_VALUES.has(facing):
		facing = "down"
	player_pos = (Vector2(spawn) + Vector2(0.5, 0.5)) * level.cell_size
	collected = {}
	collected_order = []
	pickup_flash = 0.0
	last_pickup = ""
	elapsed = 0.0
	queue_redraw()
	return {
		"ok": true,
		"errors": [],
		"warnings": validation.get("warnings", []),
		"spawn": spawn,
		"stats": validation,
	}


func _build_map_texture() -> void:
	map_texture = null
	if level == null:
		return
	var img := Image.create(level.width * 16, level.height * 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in level.height:
		for x in level.width:
			var tile := level.get_tile(x, y)
			if tile.is_empty():
				continue
			var source := TileArt.tile_texture(String(tile["type"]), int(tile.get("mask", 0)), int(tile.get("variant", -1))).get_image()
			if source == null:
				continue
			img.blit_rect(source, Rect2i(0, 0, 16, 16), Vector2i(x * 16, y * 16))
	map_texture = ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	if level == null or not is_visible_in_tree():
		return
	elapsed += delta
	pickup_flash = maxf(0.0, pickup_flash - delta)
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		_update_facing(dir)
		if try_move(dir * SPEED * delta):
			moving_time += delta
	try_pickups()
	queue_redraw()


func _update_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		facing = "right" if dir.x > 0.0 else "left"
	else:
		facing = "down" if dir.y > 0.0 else "up"


func try_move(delta: Vector2) -> bool:
	if level == null or delta == Vector2.ZERO:
		return false
	var steps := maxi(1, ceili(maxf(absf(delta.x), absf(delta.y)) / maxf(1.0, float(level.cell_size) * 0.4)))
	var step := delta / float(steps)
	var moved := false
	for i in steps:
		if absf(step.x) > 0.0001:
			var next_x := player_pos + Vector2(step.x, 0)
			if not _blocked(next_x):
				player_pos.x = next_x.x
				moved = true
		if absf(step.y) > 0.0001:
			var next_y := player_pos + Vector2(0, step.y)
			if not _blocked(next_y):
				player_pos.y = next_y.y
				moved = true
	if moved:
		moving_time += 0.05
	return moved


func _blocked(pos: Vector2) -> bool:
	if level == null:
		return true
	var cs := float(level.cell_size)
	var half := Vector2(maxf(1.5, cs * 0.24), maxf(1.0, cs * 0.18))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var point := pos + Vector2(half.x * sx, half.y * sy)
			var cx := floori(point.x / cs)
			var cy := floori(point.y / cs)
			if _cell_solid(cx, cy):
				return true
	return false


func _cell_solid(x: int, y: int) -> bool:
	if level == null or not level.in_bounds(x, y):
		return true
	if level.collision_at(x, y):
		return true
	var type := level.get_tile_type(x, y)
	return type == "wall" or type == "water"


func try_pickups() -> void:
	if level == null:
		return
	for entity in level.entities:
		if String(entity.get("type", "")) != "chest":
			continue
		var id := String(entity.get("id", ""))
		if collected.has(id):
			continue
		var center := (Vector2(float(entity["x"]), float(entity["y"])) + Vector2(0.5, 0.5)) * level.cell_size
		if player_pos.distance_to(center) <= level.cell_size * 0.62:
			collected[id] = true
			var props: Dictionary = entity.get("props", {})
			last_pickup = "%s ×%d" % [String(props.get("loot", "战利品")), int(props.get("amount", 1))]
			collected_order.append(last_pickup)
			pickup_flash = 2.2
			queue_redraw()


func player_cell() -> Vector2i:
	if level == null:
		return Vector2i.ZERO
	return Vector2i(floori(player_pos.x / level.cell_size), floori(player_pos.y / level.cell_size))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	if _font == null:
		_font = get_theme_default_font()
	if level == null:
		_draw_center_text("预览未加载：请检查运行时 JSON。", Color("#e08a7a"))
		return
	var cs := float(level.cell_size)
	var available := size - Vector2(6, 6)
	var fit := int(minf(available.x / (level.width * cs), available.y / (level.height * cs)))
	scale_factor = clampi(fit, 1, 4)
	var map_size := Vector2(level.width, level.height) * cs * scale_factor
	map_origin = ((size - map_size) * 0.5).round()
	var map_rect := Rect2(map_origin, map_size)

	# 柔和的地图外发光
	for i in 5:
		draw_rect(map_rect.grow(4 + i * 5), Color(0.45, 0.7, 0.55, 0.018))
	draw_rect(map_rect.grow(3), Color(0.03, 0.05, 0.06, 0.9))
	draw_rect(map_rect, Color("#101a20"))
	draw_rect(map_rect, C_FRAME, false, 2.0)
	draw_rect(map_rect.grow(2), Color(0.42, 0.58, 0.5, 0.25), false, 1.0)
	if map_texture != null:
		draw_texture_rect(map_texture, map_rect, false, Color.WHITE)
	else:
		for y in level.height:
			for x in level.width:
				var tile := level.get_tile(x, y)
				if tile.is_empty():
					continue
				var tex := TileArt.tile_texture(String(tile["type"]), int(tile.get("mask", 0)), int(tile.get("variant", -1)))
				var r := Rect2(map_origin + Vector2(x, y) * cs * scale_factor, Vector2(cs, cs) * scale_factor)
				draw_texture_rect(tex, r, false, Color.WHITE)

	if scale_factor >= 2:
		for y in level.height:
			for x in level.width:
				var tile := level.get_tile(x, y)
				if tile.is_empty() or String(tile["type"]) != "water" or (x + y) % 4 != 0:
					continue
				var t := fmod(elapsed * 0.8 + float(x * 3 + y) * 0.17, 1.0)
				var px := map_origin.x + (x + 0.15 + t * 0.7) * cs * scale_factor
				var py := map_origin.y + (y + 0.35 + fmod(float(x + y) * 0.21, 0.4)) * cs * scale_factor
				draw_rect(Rect2(Vector2(px, py).round(), Vector2(2, 1) * scale_factor), Color(0.75, 0.88, 0.9, 0.55))

	_draw_spawn_hint()
	_draw_entities()

	var bob := 0.0
	if moving_time > 0.0:
		bob = -absf(sin(moving_time * 12.0)) * 2.0 * scale_factor
	var foot := map_origin + player_pos * scale_factor + Vector2(0, cs * 0.28 * scale_factor)
	draw_circle(foot + Vector2(0, 1), maxf(4.0, cs * 0.28 * scale_factor), Color(0, 0, 0, 0.24))
	var player_tex := TileArt.player_texture(facing)
	var sprite_size := Vector2(16, 20) * scale_factor
	var sprite_rect := Rect2((foot + Vector2(-8 * scale_factor, -20 * scale_factor + bob)).round(), sprite_size)
	draw_texture_rect(player_tex, sprite_rect, false, Color.WHITE)

	_draw_hud(map_rect)
	if pickup_flash > 0.0:
		var alpha := clampf(pickup_flash, 0.0, 1.0)
		_draw_flash_text("拾取  %s" % last_pickup, alpha, map_rect)


func _draw_spawn_hint() -> void:
	if level == null:
		return
	var spawn := level.spawn_entity()
	if spawn.is_empty():
		return
	var cell := Vector2i(int(spawn["x"]), int(spawn["y"]))
	var center := map_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * level.cell_size * scale_factor
	var radius := level.cell_size * 0.5 * scale_factor
	draw_arc(center, radius, 0.0, TAU, 28, Color(0.66, 0.84, 0.55, 0.28), 2.0)


func _draw_entities() -> void:
	if level == null:
		return
	for entity in level.entities:
		var type := String(entity.get("type", ""))
		var cell := Vector2i(int(entity["x"]), int(entity["y"]))
		if type == "spawn":
			continue
		if type == "chest" and collected.has(String(entity.get("id", ""))):
			continue
		var center := map_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * level.cell_size * scale_factor
		var phase := float(cell.x * 7 + cell.y * 13) * 0.35
		var bob := sin(elapsed * 2.2 + phase) * 1.5 * scale_factor
		var size_px := Vector2(level.cell_size, level.cell_size) * scale_factor
		var rect := Rect2((center - size_px * 0.5 + Vector2(0, bob)).round(), size_px)
		if type == "chest":
			draw_rect(Rect2(rect.position + Vector2(4 * scale_factor, rect.size.y - 3 * scale_factor), Vector2(rect.size.x - 8 * scale_factor, 2 * scale_factor)), Color(0, 0, 0, 0.18))
		draw_texture_rect(TileArt.entity_texture(type), rect, false, Color.WHITE)
		if type == "enemy":
			var hp := int(entity.get("props", {}).get("hp", 30))
			var bar_w := rect.size.x * 0.7
			var bar_pos := Vector2(center.x - bar_w * 0.5, rect.position.y - 4 * scale_factor)
			draw_rect(Rect2(bar_pos, Vector2(bar_w, maxf(2.0, 2.0 * scale_factor))), Color(0, 0, 0, 0.55))
			draw_rect(Rect2(bar_pos, Vector2(bar_w * clampf(float(hp) / 50.0, 0.1, 1.0), maxf(2.0, 2.0 * scale_factor))), Color(0.75, 0.42, 0.5, 0.9))


func _draw_hud(map_rect: Rect2) -> void:
	var title := "%s · 运行预览" % level.level_name
	_draw_pill(title, map_rect.position + Vector2(8, 8))
	var total_chests := level.entity_count("chest")
	var stats := "宝箱 %d/%d · 敌人 %d" % [collected.size(), total_chests, level.entity_count("enemy")]
	_draw_pill_right(stats, Vector2(map_rect.end.x - 8, map_rect.position.y + 8))
	_draw_pill("WASD / 方向键移动 · Esc 返回编辑", Vector2(map_rect.position.x + 8, map_rect.end.y - 34), C_MUTED)
	var warnings: Array = validation.get("warnings", [])
	if not warnings.is_empty():
		_draw_pill_right(String(warnings[0]), Vector2(map_rect.end.x - 8, map_rect.end.y - 34), Color("#e0c58a"))


func _draw_pill(text: String, pos: Vector2, color: Color = C_TEXT) -> void:
	if _font == null:
		return
	var fs := 12
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var box := Rect2(pos, ts + Vector2(16, 8))
	draw_rect(box, Color(0.04, 0.07, 0.08, 0.9))
	draw_rect(box, Color(0.33, 0.46, 0.42, 0.8), false, 1.0)
	draw_string(_font, pos + Vector2(8, 4 + ts.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _draw_pill_right(text: String, pos: Vector2, color: Color = C_TEXT) -> void:
	if _font == null:
		return
	var fs := 12
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var box := Rect2(pos - Vector2(ts.x + 16, 0), ts + Vector2(16, 8))
	draw_rect(box, Color(0.04, 0.07, 0.08, 0.9))
	draw_rect(box, Color(0.33, 0.46, 0.42, 0.8), false, 1.0)
	draw_string(_font, box.position + Vector2(8, 4 + ts.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _draw_flash_text(text: String, alpha: float, map_rect: Rect2) -> void:
	if _font == null:
		return
	var fs := 16
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(map_rect.get_center().x - ts.x * 0.5 - 16, map_rect.end.y - 92)
	var box := Rect2(pos, ts + Vector2(32, 14))
	draw_rect(box, Color(0.05, 0.08, 0.09, 0.92 * alpha))
	draw_rect(box, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, alpha), false, 1.0)
	draw_string(_font, box.position + Vector2(16, 12 + ts.y * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, alpha))


func _draw_center_text(text: String, color: Color) -> void:
	if _font == null:
		_font = ThemeDB.fallback_font
	var fs := 16
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(_font, (size - ts) * 0.5, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
