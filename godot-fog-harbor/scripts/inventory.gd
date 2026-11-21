class_name FogInventory
extends RefCounted
## 6×4 网格背包。物品按 grid(宽×高) 占格，可堆叠物品先补已有堆叠。
## entries 每项：{id, count, x, y}；x/y 是左上角格坐标。

var width := 6
var height := 4
var entries: Array = []


func _init(w := 6, h := 4) -> void:
	width = w
	height = h


func clear() -> void:
	entries.clear()


func capacity_cells() -> int:
	return width * height


func cells_used() -> int:
	var used := 0
	for entry in entries:
		var item := FogItems.get_item(String(entry["id"]))
		if item.is_empty():
			continue
		var grid: Vector2i = item["grid"]
		used += grid.x * grid.y
	return used


func slots_used() -> int:
	return entries.size()


func total_value() -> int:
	var total := 0
	for entry in entries:
		total += FogItems.value_of(String(entry["id"]), int(entry["count"]))
	return total


func total_count() -> int:
	var total := 0
	for entry in entries:
		total += int(entry["count"])
	return total


func _occupancy(exclude_index := -1) -> PackedByteArray:
	var occ := PackedByteArray()
	occ.resize(width * height)
	occ.fill(0)
	for i in range(entries.size()):
		if i == exclude_index:
			continue
		var entry: Dictionary = entries[i]
		var item := FogItems.get_item(String(entry["id"]))
		if item.is_empty():
			continue
		var grid: Vector2i = item["grid"]
		for dy in range(grid.y):
			for dx in range(grid.x):
				var cx := int(entry["x"]) + dx
				var cy := int(entry["y"]) + dy
				if cx >= 0 and cy >= 0 and cx < width and cy < height:
					occ[cy * width + cx] = 1
	return occ


func can_place(grid: Vector2i, x: int, y: int, exclude_index := -1) -> bool:
	if grid.x <= 0 or grid.y <= 0:
		return false
	if x < 0 or y < 0 or x + grid.x > width or y + grid.y > height:
		return false
	var occ := _occupancy(exclude_index)
	for dy in range(grid.y):
		for dx in range(grid.x):
			if occ[(y + dy) * width + (x + dx)] == 1:
				return false
	return true


func find_slot(grid: Vector2i, exclude_index := -1) -> Vector2i:
	var occ := _occupancy(exclude_index)
	for y in range(height - grid.y + 1):
		for x in range(width - grid.x + 1):
			var free := true
			for dy in range(grid.y):
				for dx in range(grid.x):
					if occ[(y + dy) * width + (x + dx)] == 1:
						free = false
						break
				if not free:
					break
			if free:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func add_item(id: String, count: int) -> int:
	## 返回实际放入数量（可能因容量不足小于 count）。
	if count <= 0:
		return 0
	var item := FogItems.get_item(id)
	if item.is_empty():
		return 0
	var max_stack := int(item.get("stack_max", 1))
	var remaining := count
	if max_stack > 1:
		for entry in entries:
			if String(entry["id"]) != id:
				continue
			var current := int(entry["count"])
			if current >= max_stack:
				continue
			var take := mini(max_stack - current, remaining)
			entry["count"] = current + take
			remaining -= take
			if remaining <= 0:
				return count
	var grid: Vector2i = item["grid"]
	while remaining > 0:
		var slot := find_slot(grid)
		if slot.x < 0:
			break
		var put := mini(max_stack, remaining)
		entries.append({"id": id, "count": put, "x": slot.x, "y": slot.y})
		remaining -= put
	return count - remaining


func remove_at(index: int, count := 0) -> Dictionary:
	## count<=0 或超过堆叠数时整组移除；返回 {id, count}。
	if index < 0 or index >= entries.size():
		return {}
	var entry: Dictionary = entries[index]
	var have := int(entry["count"])
	var removed := have if count <= 0 else mini(count, have)
	if removed >= have:
		entries.remove_at(index)
	else:
		entry["count"] = have - removed
	return {"id": String(entry["id"]), "count": removed}


func use_at(index: int) -> Dictionary:
	if index < 0 or index >= entries.size():
		return {"ok": false, "reason": "没有选中物品"}
	var entry: Dictionary = entries[index]
	var item := FogItems.get_item(String(entry["id"]))
	if item.get("kind", "") != "consumable":
		return {"ok": false, "reason": "该物品无法直接使用"}
	var heal := int(item.get("heal", 0))
	remove_at(index, 1)
	return {
		"ok": true, "id": String(entry["id"]), "heal": heal,
		"message": "使用 %s，回复 %d 生命" % [String(item["name"]), heal],
	}


func drop_at(index: int) -> Dictionary:
	return remove_at(index, 0)


func entry_at_cell(x: int, y: int) -> int:
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var item := FogItems.get_item(String(entry["id"]))
		if item.is_empty():
			continue
		var grid: Vector2i = item["grid"]
		var ex := int(entry["x"])
		var ey := int(entry["y"])
		if x >= ex and y >= ey and x < ex + grid.x and y < ey + grid.y:
			return i
	return -1


func add_loot(loot: Array) -> Dictionary:
	## 返回 {added: [{id,count}], missed: [{id,count}]}。
	var added: Array = []
	var missed: Array = []
	for raw in loot:
		var id := String(raw["id"])
		var want := int(raw["count"])
		var got := add_item(id, want)
		if got > 0:
			added.append({"id": id, "count": got})
		if got < want:
			missed.append({"id": id, "count": want - got})
	return {"added": added, "missed": missed}


func snapshot() -> Array:
	return entries.duplicate(true)


func load_snapshot(data: Array) -> void:
	entries.clear()
	for raw in data:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var id := String(raw.get("id", ""))
		if not FogItems.has_item(id):
			continue
		var item := FogItems.get_item(id)
		var grid: Vector2i = item["grid"]
		var x := int(raw.get("x", 0))
		var y := int(raw.get("y", 0))
		if can_place(grid, x, y):
			entries.append({
				"id": id, "count": int(raw.get("count", 1)), "x": x, "y": y,
			})
