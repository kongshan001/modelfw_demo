class_name LevelData
extends RefCounted

# 苔井工坊的关卡数据模型。所有编辑操作都落在这一层，
# UI / 画布只负责输入与呈现，方便 headless 测试与 JSON 往返。

const FORMAT := "mossgarden.level"
const FORMAT_RUNTIME := "mossgarden.level.runtime"
const VERSION := 1

const TILE_TYPES: Array[String] = ["grass", "dirt", "wall", "water"]
const TILE_NAMES := {
	"grass": "草地",
	"dirt": "泥土",
	"wall": "石墙",
	"water": "水面",
}
const TILE_SHORT := {
	"grass": "草",
	"dirt": "土",
	"wall": "墙",
	"water": "水",
}

const LAYER_IDS: Array[String] = ["terrain", "collision", "entities"]
const LAYER_NAMES := {
	"terrain": "地形",
	"collision": "碰撞",
	"entities": "实体",
}
const LAYER_DESCS := {
	"terrain": "绘制造草/土/墙/水，自动计算边缘",
	"collision": "标记不可通行的碰撞格",
	"entities": "放置出生点、敌人与宝箱",
}

const ENTITY_TYPES: Array[String] = ["spawn", "enemy", "chest"]
const ENTITY_NAMES := {
	"spawn": "出生点",
	"enemy": "敌人",
	"chest": "宝箱",
}
const FACING_LABELS := {
	"right": "朝右",
	"left": "朝左",
	"up": "朝上",
	"down": "朝下",
}
const FACING_VALUES: Array[String] = ["right", "left", "up", "down"]

const DEFAULT_PROPS := {
	"spawn": {"facing": "up"},
	"enemy": {"kind": "苔团", "hp": 30, "damage": 5, "facing": "left", "patrol": 3},
	"chest": {"loot": "金币", "amount": 25},
}
const ENEMY_KINDS: Array[String] = ["苔团", "夜蛾", "石卫"]
const LOOT_KINDS: Array[String] = ["金币", "药水", "钥匙"]

# 自动铺砖：连接掩码的位值（北/东/南/西）
const MASK_N := 1
const MASK_E := 2
const MASK_S := 4
const MASK_W := 8
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIR_BITS: Array[int] = [MASK_N, MASK_E, MASK_S, MASK_W]

var width: int = 36
var height: int = 20
var cell_size: int = 16
var level_name: String = "苔庭试炼"
var tiles: Array = []
var collision: Array = []
var entities: Array = []
var layers := {
	"terrain": {"visible": true, "locked": false},
	"collision": {"visible": true, "locked": false},
	"entities": {"visible": true, "locked": false},
}
var next_entity_id: int = 1


func _init(w: int = 36, h: int = 20, cs: int = 16, p_name: String = "苔庭试炼") -> void:
	width = clampi(w, 1, 256)
	height = clampi(h, 1, 256)
	cell_size = clampi(cs, 8, 64)
	level_name = p_name
	clear()


func clear() -> void:
	tiles = []
	collision = []
	for y in height:
		var tile_row: Array = []
		var col_row: Array = []
		for x in width:
			tile_row.append(null)
			col_row.append(0)
		tiles.append(tile_row)
		collision.append(col_row)
	entities = []
	next_entity_id = 1
	layers = {
		"terrain": {"visible": true, "locked": false},
		"collision": {"visible": true, "locked": false},
		"entities": {"visible": true, "locked": false},
	}


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func get_tile(x: int, y: int) -> Dictionary:
	if not in_bounds(x, y):
		return {}
	var cell = tiles[y][x]
	if cell is Dictionary:
		return cell
	return {}


func get_tile_type(x: int, y: int) -> String:
	var cell := get_tile(x, y)
	return String(cell.get("type", ""))


func set_tile(x: int, y: int, type: String, variant: int = -1, mask: int = 0) -> bool:
	if not in_bounds(x, y) or not TILE_TYPES.has(type):
		return false
	tiles[y][x] = {"type": type, "variant": clampi(variant, -1, 2), "mask": clampi(mask, 0, 15)}
	return true


func erase_tile(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var existed := tiles[y][x] != null
	tiles[y][x] = null
	return existed


func paint_terrain(x: int, y: int, type: String, variant: int = -1, auto_update: bool = true) -> bool:
	if not in_bounds(x, y) or not TILE_TYPES.has(type):
		return false
	tiles[y][x] = {"type": type, "variant": clampi(variant, -1, 2), "mask": 0}
	autotile_cell(x, y)
	if auto_update:
		autotile_area(Rect2i(x - 1, y - 1, 3, 3))
	return true


func erase_terrain(x: int, y: int, auto_update: bool = true) -> bool:
	if not in_bounds(x, y):
		return false
	var had := tiles[y][x] != null
	tiles[y][x] = null
	if auto_update:
		autotile_area(Rect2i(x - 1, y - 1, 3, 3))
	return had


func collision_at(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	return int(collision[y][x]) != 0


func paint_collision(x: int, y: int, solid: bool) -> bool:
	if not in_bounds(x, y):
		return false
	collision[y][x] = 1 if solid else 0
	return true


# 同组才接边：草与土视为连续地面；石墙/水各自成组。
func _joins_with(nx: int, ny: int, type: String) -> bool:
	if not in_bounds(nx, ny):
		return false
	var other := get_tile_type(nx, ny)
	if other == "":
		return false
	if type == "grass" or type == "dirt":
		return other == "grass" or other == "dirt"
	return other == type


func compute_mask(x: int, y: int, type: String = "") -> int:
	if type == "":
		type = get_tile_type(x, y)
	if type == "":
		return 0
	var mask := 0
	for index in DIRS.size():
		var dir: Vector2i = DIRS[index]
		if _joins_with(x + dir.x, y + dir.y, type):
			mask |= DIR_BITS[index]
	return mask


func autotile_cell(x: int, y: int) -> int:
	var cell := get_tile(x, y)
	if cell.is_empty():
		return 0
	var mask := compute_mask(x, y, String(cell.get("type", "")))
	cell["mask"] = mask
	return mask


func autotile_area(rect: Rect2i) -> void:
	var x0 := maxi(0, rect.position.x)
	var y0 := maxi(0, rect.position.y)
	var x1 := mini(width, rect.end.x)
	var y1 := mini(height, rect.end.y)
	for y in range(y0, y1):
		for x in range(x0, x1):
			if tiles[y][x] != null:
				autotile_cell(x, y)


# 重算所有自动格。手动变体默认保留。
func recalculate_autotiles(include_manual: bool = false) -> int:
	var changed := 0
	for y in height:
		for x in width:
			var cell = tiles[y][x]
			if not (cell is Dictionary):
				continue
			if not include_manual and int(cell.get("variant", -1)) >= 0:
				continue
			var mask := compute_mask(x, y, String(cell.get("type", "")))
			if int(cell.get("mask", 0)) != mask:
				changed += 1
			cell["mask"] = mask
	return changed


func clear_manual_overrides() -> int:
	var cleared := 0
	for y in height:
		for x in width:
			var cell = tiles[y][x]
			if cell is Dictionary and int(cell.get("variant", -1)) >= 0:
				cell["variant"] = -1
				cleared += 1
	recalculate_autotiles(true)
	return cleared


func manual_variant_count() -> int:
	var count := 0
	for y in height:
		for x in width:
			var cell = tiles[y][x]
			if cell is Dictionary and int(cell.get("variant", -1)) >= 0:
				count += 1
	return count


static func rect_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var x0 := mini(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var x1 := maxi(a.x, b.x)
	var y1 := maxi(a.y, b.y)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			cells.append(Vector2i(x, y))
	return cells


static func line_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var x0 := a.x
	var y0 := a.y
	var x1 := b.x
	var y1 := b.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		cells.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 := err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return cells


func resize(new_width: int, new_height: int, new_cell_size: int) -> void:
	new_width = clampi(new_width, 8, 96)
	new_height = clampi(new_height, 8, 96)
	new_cell_size = clampi(new_cell_size, 16, 48)
	if new_width == width and new_height == height and new_cell_size == cell_size:
		return
	var new_tiles: Array = []
	var new_collision: Array = []
	for y in new_height:
		var row: Array = []
		var col: Array = []
		for x in new_width:
			var old_cell = tiles[y][x] if y < height and x < width else null
			row.append(old_cell)
			col.append(int(collision[y][x]) if y < height and x < width else 0)
		new_tiles.append(row)
		new_collision.append(col)
	var kept_entities: Array = []
	for entity in entities:
		if int(entity["x"]) < new_width and int(entity["y"]) < new_height:
			kept_entities.append(entity)
	width = new_width
	height = new_height
	cell_size = new_cell_size
	tiles = new_tiles
	collision = new_collision
	entities = kept_entities
	recalculate_autotiles(true)


# ---------------- 实体 ----------------

static func default_props(type: String) -> Dictionary:
	return DEFAULT_PROPS.get(type, {}).duplicate(true)


static func normalize_props(type: String, props: Dictionary) -> Dictionary:
	var out := default_props(type)
	for key in props:
		out[key] = props[key]
	match type:
		"spawn":
			out["facing"] = String(out.get("facing", "up"))
			if not FACING_VALUES.has(out["facing"]):
				out["facing"] = "up"
		"enemy":
			out["kind"] = String(out.get("kind", "苔团"))
			out["hp"] = clampi(_as_int(out.get("hp", 30), 30), 1, 999)
			out["damage"] = clampi(_as_int(out.get("damage", 5), 5), 0, 999)
			out["patrol"] = clampi(_as_int(out.get("patrol", 3), 3), 0, 32)
			out["facing"] = String(out.get("facing", "left"))
			if not FACING_VALUES.has(out["facing"]):
				out["facing"] = "left"
		"chest":
			out["loot"] = String(out.get("loot", "金币"))
			out["amount"] = clampi(_as_int(out.get("amount", 25), 25), 1, 9999)
	return out


static func _as_int(value, fallback: int) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(round(value))
	return fallback


func add_entity(type: String, x: int, y: int, props: Dictionary = {}) -> Dictionary:
	if not ENTITY_TYPES.has(type) or not in_bounds(x, y):
		return {}
	var entity := {
		"id": "e%d" % next_entity_id,
		"type": type,
		"x": x,
		"y": y,
		"props": normalize_props(type, props),
	}
	next_entity_id += 1
	entities.append(entity)
	return entity


func entity_at(x: int, y: int) -> Dictionary:
	for index in range(entities.size() - 1, -1, -1):
		var entity: Dictionary = entities[index]
		if int(entity["x"]) == x and int(entity["y"]) == y:
			return entity
	return {}


func entity_by_id(id: String) -> Dictionary:
	for entity in entities:
		if String(entity.get("id", "")) == id:
			return entity
	return {}


func move_entity(id: String, x: int, y: int) -> bool:
	var entity := entity_by_id(id)
	if entity.is_empty() or not in_bounds(x, y):
		return false
	entity["x"] = x
	entity["y"] = y
	return true


func remove_entity(id: String) -> bool:
	for index in entities.size():
		if String(entities[index].get("id", "")) == id:
			entities.remove_at(index)
			return true
	return false


func entity_count(type: String) -> int:
	var count := 0
	for entity in entities:
		if String(entity.get("type", "")) == type:
			count += 1
	return count


func spawn_entity() -> Dictionary:
	for entity in entities:
		if String(entity.get("type", "")) == "spawn":
			return entity
	return {}


# ---------------- 校验 / 预览 ----------------

func is_walkable(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	if collision_at(x, y):
		return false
	var type := get_tile_type(x, y)
	return type != "wall" and type != "water"


func find_preview_spawn() -> Vector2i:
	var spawn := spawn_entity()
	if not spawn.is_empty():
		var pos := Vector2i(int(spawn["x"]), int(spawn["y"]))
		if in_bounds(pos.x, pos.y):
			return pos
	for y in height:
		for x in width:
			if is_walkable(x, y):
				return Vector2i(x, y)
	return Vector2i(0, 0)


func validate() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var spawn_count := entity_count("spawn")
	if spawn_count == 0:
		warnings.append("未放置出生点，预览将从第一个可通行格开始。")
	elif spawn_count > 1:
		warnings.append("有 %d 个出生点；预览使用第一个。" % spawn_count)
	var walkable := 0
	for y in height:
		for x in width:
			if is_walkable(x, y):
				walkable += 1
	if walkable == 0:
		errors.append("地图没有可通行格，无法预览。")
	for entity in entities:
		var ex := int(entity.get("x", -1))
		var ey := int(entity.get("y", -1))
		if not in_bounds(ex, ey):
			errors.append("实体 %s 位于地图外。" % String(entity.get("id", "?")))
		elif String(entity.get("type", "")) == "spawn" and not is_walkable(ex, ey):
			warnings.append("出生点 %s 位于不可通行格。" % String(entity.get("id", "?")))
		elif String(entity.get("type", "")) == "chest" and not is_walkable(ex, ey):
			warnings.append("宝箱 %s 位于不可通行格，预览无法拾取。" % String(entity.get("id", "?")))
		elif String(entity.get("type", "")) == "enemy" and not is_walkable(ex, ey):
			warnings.append("敌人 %s 位于不可通行格。" % String(entity.get("id", "?")))
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"walkable": walkable,
		"spawn_count": spawn_count,
		"enemy_count": entity_count("enemy"),
		"chest_count": entity_count("chest"),
		"entities": entities.size(),
		"tiles": filled_tile_count(),
		"solids": collision_count(),
	}


func filled_tile_count() -> int:
	var count := 0
	for y in height:
		for x in width:
			if tiles[y][x] != null:
				count += 1
	return count


func collision_count() -> int:
	var count := 0
	for y in height:
		for x in width:
			if int(collision[y][x]) != 0:
				count += 1
	return count


# ---------------- JSON ----------------

func _tiles_to_json() -> Array:
	var rows: Array = []
	for y in height:
		var row: Array = []
		for x in width:
			var cell = tiles[y][x]
			if cell is Dictionary:
				row.append({
					"type": String(cell.get("type", "grass")),
					"variant": int(cell.get("variant", -1)),
					"mask": int(cell.get("mask", 0)),
				})
			else:
				row.append(null)
		rows.append(row)
	return rows


func _layers_to_json() -> Dictionary:
	var out := {}
	for id in LAYER_IDS:
		var meta: Dictionary = layers.get(id, {})
		out[id] = {
			"visible": bool(meta.get("visible", true)),
			"locked": bool(meta.get("locked", false)),
		}
	return out


func to_dict() -> Dictionary:
	return {
		"format": FORMAT,
		"version": VERSION,
		"name": level_name,
		"width": width,
		"height": height,
		"cell_size": cell_size,
		"tiles": _tiles_to_json(),
		"collision": collision.duplicate(true),
		"entities": entities.duplicate(true),
		"layers": _layers_to_json(),
		"next_entity_id": next_entity_id,
	}


func to_runtime_dict() -> Dictionary:
	return {
		"format": FORMAT_RUNTIME,
		"version": VERSION,
		"name": level_name,
		"width": width,
		"height": height,
		"cell_size": cell_size,
		"tiles": _tiles_to_json(),
		"collision": collision.duplicate(true),
		"entities": entities.duplicate(true),
	}


func to_json(runtime: bool = false, pretty: bool = true) -> String:
	var data := to_runtime_dict() if runtime else to_dict()
	return JSON.stringify(data, "\t" if pretty else "")


func from_json(text: String) -> Array:
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return ["JSON 解析失败：第 %d 行 %s" % [json.get_error_line(), json.get_error_message()]]
	if not (json.data is Dictionary):
		return ["JSON 根节点必须是对象。"]
	return from_dict(json.data)


func from_dict(data: Dictionary) -> Array:
	var errors: Array[String] = []
	var fmt := String(data.get("format", ""))
	if fmt != FORMAT and fmt != FORMAT_RUNTIME:
		errors.append("format 不匹配：需要 %s。" % FORMAT)
	if _as_int(data.get("version", -1), -1) != VERSION:
		errors.append("version 必须为 %d。" % VERSION)
	var new_width := _as_int(data.get("width", 0), 0)
	var new_height := _as_int(data.get("height", 0), 0)
	var new_cell := _as_int(data.get("cell_size", 0), 0)
	if new_width < 1 or new_width > 256:
		errors.append("width 需在 1..256。")
	if new_height < 1 or new_height > 256:
		errors.append("height 需在 1..256。")
	if new_cell < 8 or new_cell > 64:
		errors.append("cell_size 需在 8..64。")
	var raw_tiles = data.get("tiles", null)
	var raw_collision = data.get("collision", null)
	if not (raw_tiles is Array) or raw_tiles.size() != new_height:
		errors.append("tiles 必须是 height 行数组。")
	if not (raw_collision is Array) or raw_collision.size() != new_height:
		errors.append("collision 必须是 height 行数组。")
	if not errors.is_empty():
		return errors

	var new_tiles: Array = []
	for y in new_height:
		var row = raw_tiles[y]
		if not (row is Array) or row.size() != new_width:
			errors.append("tiles[%d] 必须是 width 列数组。" % y)
			break
		var out_row: Array = []
		for x in new_width:
			var cell = row[x]
			if cell == null:
				out_row.append(null)
				continue
			if not (cell is Dictionary):
				errors.append("tiles[%d][%d] 必须是对象或 null。" % [y, x])
				break
			var tile_type := String(cell.get("type", ""))
			if not TILE_TYPES.has(tile_type):
				errors.append("tiles[%d][%d] 的 type 非法。" % [y, x])
				break
			var variant := _as_int(cell.get("variant", -1), -1)
			var mask := _as_int(cell.get("mask", 0), 0)
			if variant < -1 or variant > 2 or mask < 0 or mask > 15:
				errors.append("tiles[%d][%d] 的 variant/mask 越界。" % [y, x])
				break
			out_row.append({"type": tile_type, "variant": variant, "mask": mask})
		new_tiles.append(out_row)
	if not errors.is_empty():
		return errors

	var new_collision: Array = []
	for y in new_height:
		var row = raw_collision[y]
		if not (row is Array) or row.size() != new_width:
			errors.append("collision[%d] 必须是 width 列数组。" % y)
			break
		var out_row: Array = []
		for x in new_width:
			var value = row[x]
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				errors.append("collision[%d][%d] 必须是 0/1。" % [y, x])
				break
			out_row.append(1 if int(value) != 0 else 0)
		new_collision.append(out_row)
	if not errors.is_empty():
		return errors

	var raw_entities = data.get("entities", [])
	if not (raw_entities is Array):
		errors.append("entities 必须是数组。")
		return errors
	var new_entities: Array = []
	var used_ids := {}
	var max_id := 0
	for index in raw_entities.size():
		var entity = raw_entities[index]
		if not (entity is Dictionary):
			errors.append("entities[%d] 必须是对象。" % index)
			break
		var entity_type := String(entity.get("type", ""))
		if not ENTITY_TYPES.has(entity_type):
			errors.append("entities[%d] 的 type 非法。" % index)
			break
		var ex := _as_int(entity.get("x", -1), -1)
		var ey := _as_int(entity.get("y", -1), -1)
		if ex < 0 or ey < 0 or ex >= new_width or ey >= new_height:
			errors.append("entities[%d] 的坐标越界。" % index)
			break
		var eid := String(entity.get("id", "")).strip_edges()
		if eid == "" or used_ids.has(eid):
			max_id += 1
			eid = "e%d" % max_id
			while used_ids.has(eid):
				max_id += 1
				eid = "e%d" % max_id
		used_ids[eid] = true
		if eid.begins_with("e") and eid.substr(1).is_valid_int():
			max_id = maxi(max_id, int(eid.substr(1)))
		var props = entity.get("props", {})
		if not (props is Dictionary):
			errors.append("entities[%d].props 必须是对象。" % index)
			break
		new_entities.append({
			"id": eid,
			"type": entity_type,
			"x": ex,
			"y": ey,
			"props": normalize_props(entity_type, props),
		})
	if not errors.is_empty():
		return errors

	var new_layers := {
		"terrain": {"visible": true, "locked": false},
		"collision": {"visible": true, "locked": false},
		"entities": {"visible": true, "locked": false},
	}
	var raw_layers = data.get("layers", {})
	if raw_layers is Dictionary:
		for id in LAYER_IDS:
			var meta = raw_layers.get(id, null)
			if meta is Dictionary:
				new_layers[id]["visible"] = bool(meta.get("visible", true))
				new_layers[id]["locked"] = bool(meta.get("locked", false))

	width = new_width
	height = new_height
	cell_size = new_cell
	level_name = String(data.get("name", "苔庭试炼"))
	tiles = new_tiles
	collision = new_collision
	entities = new_entities
	layers = new_layers
	next_entity_id = maxi(_as_int(data.get("next_entity_id", max_id + 1), max_id + 1), max_id + 1)
	return []


func snapshot() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"cell_size": cell_size,
		"name": level_name,
		"tiles": tiles.duplicate(true),
		"collision": collision.duplicate(true),
		"entities": entities.duplicate(true),
		"next_entity_id": next_entity_id,
	}


func restore(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	width = int(snap.get("width", width))
	height = int(snap.get("height", height))
	cell_size = int(snap.get("cell_size", cell_size))
	level_name = String(snap.get("name", level_name))
	tiles = snap.get("tiles", tiles).duplicate(true)
	collision = snap.get("collision", collision).duplicate(true)
	entities = snap.get("entities", entities).duplicate(true)
	next_entity_id = int(snap.get("next_entity_id", next_entity_id))


# ---------------- 示例关卡 ----------------

static func _fill(level: LevelData, rect: Rect2i, type: String, variant: int = -1) -> void:
	for y in range(maxi(0, rect.position.y), mini(level.height, rect.end.y)):
		for x in range(maxi(0, rect.position.x), mini(level.width, rect.end.x)):
			level.tiles[y][x] = {"type": type, "variant": variant, "mask": 0}


static func _set_cell(level: LevelData, x: int, y: int, type: String, variant: int = -1) -> void:
	if level.in_bounds(x, y):
		level.tiles[y][x] = {"type": type, "variant": variant, "mask": 0}


static func build_demo() -> LevelData:
	var level = new(36, 20, 16, "苔庭试炼")
	_fill(level, Rect2i(0, 0, level.width, level.height), "grass")

	# 十字小径与门前广场
	_fill(level, Rect2i(2, 14, 32, 2), "dirt")
	_fill(level, Rect2i(17, 12, 2, 7), "dirt")
	_fill(level, Rect2i(13, 8, 10, 5), "dirt")

	# 左上旧礼拜堂：石墙、泥土地面和南侧门洞
	_fill(level, Rect2i(8, 2, 10, 7), "dirt")
	_fill(level, Rect2i(7, 1, 11, 1), "wall")
	_fill(level, Rect2i(7, 2, 1, 7), "wall")
	_fill(level, Rect2i(17, 2, 1, 7), "wall")
	_fill(level, Rect2i(7, 8, 5, 1), "wall")
	_fill(level, Rect2i(15, 8, 3, 1), "wall")

	# 右上藏宝龛
	_fill(level, Rect2i(24, 3, 7, 1), "wall")
	_fill(level, Rect2i(24, 3, 1, 4), "wall")
	_fill(level, Rect2i(30, 3, 1, 4), "wall")
	_fill(level, Rect2i(24, 6, 2, 1), "wall")
	_fill(level, Rect2i(29, 6, 2, 1), "wall")
	_fill(level, Rect2i(25, 4, 5, 2), "dirt")

	# 右下池塘（椭圆）与北岸碎墙
	for y in range(10, level.height):
		for x in range(19, level.width):
			var dx := (x - 27) / 6.4
			var dy := (y - 14) / 3.4
			if dx * dx + dy * dy <= 1.0:
				level.tiles[y][x] = {"type": "water", "variant": -1, "mask": 0}
	_fill(level, Rect2i(20, 10, 2, 1), "wall")
	_fill(level, Rect2i(23, 9, 1, 2), "wall")
	_set_cell(level, 21, 10, "wall")
	_set_cell(level, 23, 10, "wall")

	# 手工变体：花草地、苔石、睡莲
	for cell in [Vector2i(12, 12), Vector2i(10, 15), Vector2i(20, 16), Vector2i(4, 6), Vector2i(32, 11)]:
		_set_cell(level, cell.x, cell.y, "grass", 1)
	for cell in [Vector2i(9, 3), Vector2i(16, 7), Vector2i(25, 5)]:
		_set_cell(level, cell.x, cell.y, "dirt", 1)
	for cell in [Vector2i(27, 13), Vector2i(29, 15)]:
		_set_cell(level, cell.x, cell.y, "water", 1)
	_set_cell(level, 11, 4, "wall", 1)
	_set_cell(level, 29, 4, "wall", 2)

	# 碰撞层跟随墙体；门洞/路径保持可走
	for y in level.height:
		for x in level.width:
			if level.get_tile_type(x, y) == "wall":
				level.collision[y][x] = 1
	# 一块“隐形路障”演示碰撞层与地形分离
	for x in range(14, 17):
		level.collision[13][x] = 1

	level.add_entity("spawn", 17, 18, {"facing": "up"})
	level.add_entity("enemy", 14, 11, {"kind": "苔团", "hp": 30, "damage": 5, "facing": "left", "patrol": 3})
	level.add_entity("enemy", 27, 8, {"kind": "夜蛾", "hp": 20, "damage": 3, "facing": "up", "patrol": 4})
	level.add_entity("chest", 15, 4, {"loot": "金币", "amount": 40})
	level.add_entity("chest", 27, 4, {"loot": "药水", "amount": 2})
	level.add_entity("chest", 20, 15, {"loot": "钥匙", "amount": 1})

	level.recalculate_autotiles(true)
	return level
