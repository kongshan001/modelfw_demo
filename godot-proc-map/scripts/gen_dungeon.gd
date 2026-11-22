extends RefCounted

# BSP 地牢生成器（纯数据，可在 headless 直接实例化）。
# 阶段：切分 → 房间 → 走廊 → 连通验证 → 装饰。
# 所有随机来自独立 RandomNumberGenerator 流；同一 seed/尺寸/参数得到完整一致的网格与签名。

const Utils = preload("res://scripts/gen_utils.gd")

const STAGES := ["split", "rooms", "corridors", "connectivity", "decor"]
const STAGE_LABELS := ["BSP 切分", "放置房间", "走廊连接", "连通验证", "装饰与灯光"]
const MIN_LEAF_W := 10
const MIN_LEAF_H := 8
const MIN_ROOM_W := 5
const MIN_ROOM_H := 4
const MAX_DEPTH := 6
const MAX_LEAVES := 16
const MAX_TORCHES := 34

var width := 64
var height := 48
var seed_text := "2137"
var base_seed := 0
var loop_ratio := 0.12
var stage_index := -1
var finished := false
var stage_ms: Array[float] = []
var total_ms := 0.0

var streams: Dictionary = {}
var grid: PackedByteArray
var cell_room: PackedInt32Array
var leaves: Array = []
var splits: Array = []
var rooms: Array = []
var corridor_cells := 0
var loops := 0
var start := Vector2i.ZERO
var exit := Vector2i.ZERO
var dist: PackedInt32Array
var component_count := 0
var decor: Array = []
var torch_count := 0
var prop_count := 0
var valid := false
var signature := ""

var _rngs: Dictionary = {}
var _used_cells: Dictionary = {}


func setup(seed_value: String, map_w: int, map_h: int, loop_param := 0.12) -> void:
	seed_text = seed_value
	width = map_w
	height = map_h
	loop_ratio = clampf(loop_param, 0.0, 0.4)
	base_seed = Utils.seed_from_text(seed_text)
	streams = {
		"切分": Utils.mix32(base_seed, 1101),
		"房间": Utils.mix32(base_seed, 2203),
		"走廊": Utils.mix32(base_seed, 3307),
		"装饰": Utils.mix32(base_seed, 4409),
	}
	_rngs = {}
	for key in streams:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(streams[key])
		_rngs[key] = rng
	stage_index = -1
	finished = false
	stage_ms = []
	total_ms = 0.0
	leaves = []
	splits = []
	rooms = []
	corridor_cells = 0
	loops = 0
	decor = []
	torch_count = 0
	prop_count = 0
	valid = false
	signature = ""
	_used_cells = {}
	grid = PackedByteArray()
	grid.resize(width * height)
	grid.fill(0)
	cell_room = PackedInt32Array()
	cell_room.resize(width * height)
	cell_room.fill(-1)
	dist = PackedInt32Array()
	dist.resize(width * height)
	dist.fill(-1)
	component_count = 0
	start = Vector2i.ZERO
	exit = Vector2i.ZERO


func get_stage_count() -> int:
	return STAGES.size()


func get_stage_label(index: int) -> String:
	return STAGE_LABELS[clampi(index, 0, STAGE_LABELS.size() - 1)]


func run_stage(index: int) -> void:
	if index < 0 or index >= STAGES.size():
		return
	var started := Time.get_ticks_usec()
	match index:
		0:
			_run_split()
		1:
			_run_rooms()
		2:
			_run_corridors()
		3:
			_run_connectivity()
		4:
			_run_decor()
	stage_index = index
	finished = index >= STAGES.size() - 1
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	stage_ms.append(elapsed)
	total_ms += elapsed


func generate_all() -> bool:
	for index in STAGES.size():
		run_stage(index)
	return valid


func get_streams() -> Dictionary:
	return streams


func get_stats() -> Dictionary:
	var floor_count := 0
	for value in grid:
		if int(value) != 0:
			floor_count += 1
	var reachable := 0
	for value in dist:
		if value >= 0:
			reachable += 1
	var reachable_rooms := 0
	for room in rooms:
		var center: Vector2i = room["center"]
		if dist[center.y * width + center.x] >= 0:
			reachable_rooms += 1
	return {
		"rooms": rooms.size(),
		"floor_cells": floor_count,
		"corridor_cells": corridor_cells,
		"loops": loops,
		"reachable_pct": (float(reachable) / float(maxi(1, floor_count))) * 100.0,
		"reachable_rooms": reachable_rooms,
		"component_count": component_count,
		"exit_distance": int(dist[exit.y * width + exit.x]) if dist.size() > 0 else 0,
		"torches": torch_count,
		"props": prop_count,
		"total_ms": total_ms,
		"stage_ms": stage_ms.duplicate(),
		"valid": valid,
		"signature": signature,
	}


func get_signature() -> String:
	return signature


func floor_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false
	return int(grid[cell.y * width + cell.x]) != 0


func room_at(cell: Vector2i) -> Dictionary:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return {}
	var id := int(cell_room[cell.y * width + cell.x])
	if id < 0:
		return {}
	return rooms[id]


func cell_info(cell: Vector2i) -> Dictionary:
	var info := {"valid": false}
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return info
	var index := cell.y * width + cell.x
	info["valid"] = true
	info["floor"] = int(grid[index]) != 0
	info["district"] = "走廊" if int(cell_room[index]) < 0 else "房间 %d" % int(cell_room[index])
	info["reachable"] = dist[index] >= 0 if dist.size() == width * height else false
	info["distance"] = dist[index] if dist.size() == width * height else -1
	return info


# ---------------------------------------------------------------------------
# 阶段 0：BSP 切分
# ---------------------------------------------------------------------------

func _run_split() -> void:
	var root := Rect2i(1, 1, width - 2, height - 2)
	_split_rect(root, 0)


func _split_rect(rect: Rect2i, depth: int) -> void:
	leaves.append({"rect": rect, "depth": depth})
	if depth >= MAX_DEPTH or leaves.size() >= MAX_LEAVES:
		return
	var can_v := rect.size.x >= MIN_LEAF_W * 2 + 1
	var can_h := rect.size.y >= MIN_LEAF_H * 2 + 1
	if not can_v and not can_h:
		return
	if depth > 2 and _rngs["切分"].randf() < 0.16:
		return
	var vertical := false
	if can_v and not can_h:
		vertical = true
	elif can_h and not can_v:
		vertical = false
	else:
		var aspect := float(rect.size.x) / float(rect.size.y)
		if aspect > 1.35:
			vertical = true
		elif aspect < 0.74:
			vertical = false
		else:
			vertical = _rngs["切分"].randf() < 0.5
	var min_side := MIN_LEAF_W if vertical else MIN_LEAF_H
	var side := rect.size.x if vertical else rect.size.y
	var split: int = _rngs["切分"].randi_range(min_side, side - min_side)
	var first: Rect2i
	var second: Rect2i
	if vertical:
		first = Rect2i(rect.position, Vector2i(split, rect.size.y))
		second = Rect2i(rect.position + Vector2i(split, 0),
				Vector2i(rect.size.x - split, rect.size.y))
	else:
		first = Rect2i(rect.position, Vector2i(rect.size.x, split))
		second = Rect2i(rect.position + Vector2i(0, split),
				Vector2i(rect.size.x, rect.size.y - split))
	splits.append({"rect": rect, "vertical": vertical, "position": split, "depth": depth})
	# 移除父叶，只保留真正的叶子。
	leaves.pop_back()
	_split_rect(first, depth + 1)
	_split_rect(second, depth + 1)


# ---------------------------------------------------------------------------
# 阶段 1：房间
# ---------------------------------------------------------------------------

func _run_rooms() -> void:
	var room_rng: RandomNumberGenerator = _rngs["房间"]
	for leaf in leaves:
		var rect: Rect2i = leaf["rect"]
		var max_w := rect.size.x - 2
		var max_h := rect.size.y - 2
		if max_w < MIN_ROOM_W or max_h < MIN_ROOM_H:
			continue
		var room_w := room_rng.randi_range(MIN_ROOM_W, max_w)
		var room_h := room_rng.randi_range(MIN_ROOM_H, max_h)
		# 大房间更容易接近叶节点大小；小概率做小密室。
		if room_rng.randf() < 0.55:
			room_w = maxi(MIN_ROOM_W, max_w - room_rng.randi_range(0, 2))
			room_h = maxi(MIN_ROOM_H, max_h - room_rng.randi_range(0, 2))
		if room_rng.randf() < 0.16:
			room_w = mini(room_w, MIN_ROOM_W + 1)
			room_h = mini(room_h, MIN_ROOM_H + 1)
		var ox := rect.position.x + 1 + room_rng.randi_range(0, maxi(0, max_w - room_w))
		var oy := rect.position.y + 1 + room_rng.randi_range(0, maxi(0, max_h - room_h))
		var room_rect := Rect2i(ox, oy, room_w, room_h)
		var roll := room_rng.randf()
		var kind := "stone"
		if roll < 0.20:
			kind = "moss"
		elif roll < 0.33:
			kind = "wood"
		elif roll < 0.43:
			kind = "gold"
		var room := {
			"id": rooms.size(),
			"rect": room_rect,
			"center": room_rect.position + room_rect.size / 2,
			"kind": kind,
			"depth": int(leaf["depth"]),
		}
		rooms.append(room)
		for y in range(room_rect.position.y, room_rect.end.y):
			for x in range(room_rect.position.x, room_rect.end.x):
				var index := y * width + x
				grid[index] = 1
				cell_room[index] = int(room["id"])


# ---------------------------------------------------------------------------
# 阶段 2：走廊
# ---------------------------------------------------------------------------

func _run_corridors() -> void:
	if rooms.size() < 2:
		return
	var pairs: Array = []
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			var a: Vector2i = rooms[i]["center"]
			var b: Vector2i = rooms[j]["center"]
			var dx := a.x - b.x
			var dy := a.y - b.y
			pairs.append({"a": i, "b": j, "d": dx * dx + dy * dy})
	pairs.sort_custom(_pair_less)
	var parent: Array[int] = []
	for i in rooms.size():
		parent.append(i)
	var connected := 0
	for pair in pairs:
		var ra := _find(parent, int(pair["a"]))
		var rb := _find(parent, int(pair["b"]))
		if ra == rb:
			continue
		parent[ra] = rb
		_carve_corridor(rooms[int(pair["a"])]["center"], rooms[int(pair["b"])]["center"])
		connected += 1
		if connected >= rooms.size() - 1:
			break
	# 额外环路：随机选房间对，避免重复。
	var extra := int(round(float(rooms.size()) * loop_ratio * 2.0))
	var attempts := 0
	while extra > 0 and attempts < 40:
		attempts += 1
		var i: int = _rngs["走廊"].randi_range(0, rooms.size() - 1)
		var j: int = _rngs["走廊"].randi_range(0, rooms.size() - 1)
		if i == j:
			continue
		var ca: Vector2i = rooms[i]["center"]
		var cb: Vector2i = rooms[j]["center"]
		if ca.distance_squared_to(cb) > 28.0 * 28.0:
			continue
		_carve_corridor(ca, cb)
		loops += 1
		extra -= 1


func _pair_less(a: Dictionary, b: Dictionary) -> bool:
	if int(a["d"]) == int(b["d"]):
		return int(a["a"]) < int(b["a"])
	return int(a["d"]) < int(b["d"])


func _find(parent: Array, index: int) -> int:
	while int(parent[index]) != index:
		parent[index] = parent[int(parent[index])]
		index = int(parent[index])
	return index


func _carve_corridor(a: Vector2i, b: Vector2i) -> void:
	var horizontal_first: bool = _rngs["走廊"].randf() < 0.5
	if horizontal_first:
		_carve_h(a.x, b.x, a.y)
		_carve_v(a.y, b.y, b.x)
	else:
		_carve_v(a.y, b.y, a.x)
		_carve_h(a.x, b.x, b.y)


func _carve_h(x0: int, x1: int, y: int) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		_carve_cell(x, y)


func _carve_v(y0: int, y1: int, x: int) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		_carve_cell(x, y)


func _carve_cell(x: int, y: int) -> void:
	if x < 1 or y < 1 or x >= width - 1 or y >= height - 1:
		return
	var index := y * width + x
	if int(grid[index]) == 0:
		grid[index] = 1
		corridor_cells += 1


# ---------------------------------------------------------------------------
# 阶段 3：连通验证与起点/终点
# ---------------------------------------------------------------------------

func _run_connectivity() -> void:
	if rooms.is_empty():
		valid = false
		return
	var repair_rounds := 0
	var first_center: Vector2i = rooms[0]["center"]
	while true:
		dist = Utils.bfs_distances(width, height, grid, first_center)
		var unreachable: Array = []
		for room in rooms:
			var center: Vector2i = room["center"]
			if dist[center.y * width + center.x] < 0:
				unreachable.append(room)
		if unreachable.is_empty() or repair_rounds >= 4:
			break
		# 把不可达房间接到最近的可达地板。
		for room in unreachable:
			var target: Vector2i = room["center"]
			var best := Vector2i(-1, -1)
			var best_distance := 1 << 30
			for y in height:
				for x in width:
					if dist[y * width + x] < 0:
						continue
					var d := absi(x - target.x) + absi(y - target.y)
					if d < best_distance:
						best_distance = d
						best = Vector2i(x, y)
			if best.x >= 0:
				_carve_corridor(best, target)
		repair_rounds += 1
	# 把仍然不可达的地板回填，保证 100% 连通。
	dist = Utils.bfs_distances(width, height, grid, first_center)
	for i in width * height:
		if int(grid[i]) != 0 and dist[i] < 0:
			grid[i] = 0
			cell_room[i] = -1
	dist = Utils.bfs_distances(width, height, grid, first_center)
	# 用已有距离取最远点 A，再从 A 做一次 BFS 得到终点 B。
	var farthest_a := first_center
	var best_distance := 0
	for i in width * height:
		if dist[i] > best_distance:
			best_distance = dist[i]
			farthest_a = Vector2i(i % width, i / width)
	var dist_from_a := Utils.bfs_distances(width, height, grid, farthest_a)
	var farthest_b := farthest_a
	best_distance = 0
	for i in width * height:
		if dist_from_a[i] > best_distance:
			best_distance = dist_from_a[i]
			farthest_b = Vector2i(i % width, i / width)
	start = farthest_a
	exit = farthest_b
	dist = dist_from_a
	var reachable_rooms := 0
	for room in rooms:
		var center: Vector2i = room["center"]
		if dist[center.y * width + center.x] >= 0:
			reachable_rooms += 1
	var floor_count := 0
	var reachable_count := 0
	for i in width * height:
		if int(grid[i]) != 0:
			floor_count += 1
			if dist[i] >= 0:
				reachable_count += 1
	component_count = 1 if reachable_count == floor_count else 2
	valid = reachable_rooms == rooms.size() and component_count == 1
	# 起点/终点不放在房间角落，稍微向房间中心收一点仍保持地板。
	start = _nearest_floor(start)
	exit = _nearest_floor(exit)


func _nearest_floor(cell: Vector2i) -> Vector2i:
	if floor_cell(cell):
		return cell
	for radius in range(1, 5):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var candidate := cell + Vector2i(dx, dy)
				if floor_cell(candidate):
					return candidate
	return cell


# ---------------------------------------------------------------------------
# 阶段 4：装饰
# ---------------------------------------------------------------------------

func _run_decor() -> void:
	decor = []
	torch_count = 0
	prop_count = 0
	_used_cells = {}
	_place_torches()
	_place_room_props()
	decor.append({"kind": "start", "pos": _cell_center(start) + Vector2(0, 6), "scale": 0.9})
	decor.append({"kind": "exit", "pos": _cell_center(exit) + Vector2(0, 6), "scale": 0.9})
	# 先画地毯，其他装饰按 y 排序在视图层处理。
	var rugs: Array = []
	var others: Array = []
	for item in decor:
		if String(item["kind"]).begins_with("rug"):
			rugs.append(item)
		else:
			others.append(item)
	decor = rugs + others
	_finish_signature()


func _place_torches() -> void:
	var candidates: Array = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			if int(grid[y * width + x]) != 0:
				continue
			for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var neighbor: Vector2i = Vector2i(x, y) + offset
				if floor_cell(neighbor):
					candidates.append({"cell": Vector2i(x, y), "dir": offset})
					break
	var rng: RandomNumberGenerator = _rngs["装饰"]
	# 用确定性的 Fisher-Yates 打乱候选。
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var chosen: Array[Vector2i] = []
	for candidate in candidates:
		if torch_count >= MAX_TORCHES:
			break
		var wall_cell: Vector2i = candidate["cell"]
		var direction: Vector2i = candidate["dir"]
		var spaced := true
		for other in chosen:
			if absi(other.x - wall_cell.x) <= 3 and absi(other.y - wall_cell.y) <= 2:
				spaced = false
				break
		if not spaced:
			continue
		chosen.append(wall_cell)
		var pos := _cell_center(wall_cell) + Vector2(direction.x, direction.y) * 11.0
		decor.append({"kind": "torch", "pos": pos, "scale": 1.0})
		torch_count += 1


func _place_room_props() -> void:
	var rng: RandomNumberGenerator = _rngs["装饰"]
	for room in rooms:
		var rect: Rect2i = room["rect"]
		var kind: String = room["kind"]
		var center: Vector2i = room["center"]
		if kind == "gold":
			_add_rug(room, "rug_a")
			_add_prop("chest", center + Vector2i(0, 0))
			_add_prop("pillar", rect.position + Vector2i(1, 1))
			_add_prop("pillar", Vector2i(rect.end.x - 2, rect.position.y + 1))
			_add_prop("pillar", Vector2i(rect.position.x + 1, rect.end.y - 2))
			_add_prop("pillar", Vector2i(rect.end.x - 2, rect.end.y - 2))
			continue
		if kind == "wood":
			_add_rug(room, "rug_b")
			_add_prop("table", center)
			for i in 2:
				_add_random_prop(room, ["barrel", "crate"], rng)
		elif kind == "moss":
			_add_prop("mushrooms", center + Vector2i(1, 1))
			_add_prop("bones", center + Vector2i(-1, 1))
			_add_random_prop(room, ["mushrooms", "bones"], rng)
		else:
			if rect.size.x >= 9 and rect.size.y >= 7:
				_add_rug(room, "rug_b")
			for i in rng.randi_range(1, 3):
				_add_random_prop(room, ["crate", "barrel", "table", "bones"], rng)
			if rect.size.x >= 8 and rect.size.y >= 6 and rng.randf() < 0.5:
				_add_prop("pillar", rect.position + Vector2i(1, 1))
				_add_prop("pillar", Vector2i(rect.end.x - 2, rect.end.y - 2))


func _add_rug(room: Dictionary, kind: String) -> void:
	var rect: Rect2i = room["rect"]
	if rect.size.x < 7 or rect.size.y < 5:
		return
	var size := Vector2i(mini(rect.size.x - 2, 5), mini(rect.size.y - 2, 3))
	var origin := Vector2i(rect.position.x + (rect.size.x - size.x) / 2,
			rect.position.y + (rect.size.y - size.y) / 2)
	decor.append({"kind": kind, "rect": Rect2i(origin, size)})


func _add_random_prop(room: Dictionary, kinds: Array, rng: RandomNumberGenerator) -> void:
	var rect: Rect2i = room["rect"]
	for attempt in 8:
		var cell := Vector2i(rng.randi_range(rect.position.x + 1, rect.end.x - 2),
				rng.randi_range(rect.position.y + 1, rect.end.y - 2))
		if cell == start or cell == exit:
			continue
		if floor_cell(cell) and not _used_cells.has(cell):
			_used_cells[cell] = true
			decor.append({"kind": kinds[rng.randi_range(0, kinds.size() - 1)],
					"pos": _cell_center(cell) + Vector2(0, 8), "scale": 1.0})
			prop_count += 1
			return


func _add_prop(kind: String, cell: Vector2i) -> void:
	if not floor_cell(cell) or cell == start or cell == exit:
		return
	if _used_cells.has(cell):
		return
	_used_cells[cell] = true
	decor.append({"kind": kind, "pos": _cell_center(cell) + Vector2(0, 8), "scale": 1.0})
	prop_count += 1


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5) * 32.0


func _finish_signature() -> void:
	var h := Utils.signature_start()
	h = Utils.fnv_int(h, base_seed)
	h = Utils.fnv_int(h, int(round(loop_ratio * 1000.0)))
	h = Utils.fnv_bytes(h, grid)
	for room in rooms:
		var rect: Rect2i = room["rect"]
		h = Utils.fnv_int(h, rect.position.x)
		h = Utils.fnv_int(h, rect.position.y)
		h = Utils.fnv_int(h, rect.size.x)
		h = Utils.fnv_int(h, rect.size.y)
		h = Utils.fnv_int(h, String(room["kind"]).hash())
	for item in decor:
		h = Utils.fnv_int(h, String(item["kind"]).hash())
		if item.has("pos"):
			var pos: Vector2 = item["pos"]
			h = Utils.fnv_int(h, Utils.quantize(pos.x))
			h = Utils.fnv_int(h, Utils.quantize(pos.y))
		if item.has("rect"):
			var rect: Rect2i = item["rect"]
			h = Utils.fnv_int(h, rect.position.x)
			h = Utils.fnv_int(h, rect.position.y)
			h = Utils.fnv_int(h, rect.size.x)
			h = Utils.fnv_int(h, rect.size.y)
	h = Utils.fnv_int(h, start.x)
	h = Utils.fnv_int(h, start.y)
	h = Utils.fnv_int(h, exit.x)
	h = Utils.fnv_int(h, exit.y)
	signature = Utils.fmt_sig(h)
