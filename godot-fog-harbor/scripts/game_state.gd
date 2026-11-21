class_name FogGameState
extends RefCounted
## 跨局持久化：信用点、仓库、3 项升级、统计。写入 user:// JSON。
## 死亡只影响本局携带（由 main 决定不调用 transfer_loot）；仓库/升级/信用点不动。

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://fogfall_save.json"
const BASE_WAREHOUSE_CAPACITY := 24
const WAREHOUSE_PER_LEVEL := 6
const BASE_WEAPON_DAMAGE := 18
const DAMAGE_PER_LEVEL := 3
const BASE_MEDKITS := 1

const UPGRADE_ORDER := ["warehouse", "medkit", "damage"]

const UPGRADE_DEFS := {
	"warehouse": {
		"name": "仓库扩容",
		"desc": "仓库堆叠格 +6，最多 42 格。",
		"max_level": 3,
		"costs": [120, 220, 360],
	},
	"medkit": {
		"name": "出发医疗包",
		"desc": "每局额外携带 1 个医疗包。",
		"max_level": 3,
		"costs": [80, 160, 260],
	},
	"damage": {
		"name": "武器校准",
		"desc": "步枪伤害 +3 / 级。",
		"max_level": 3,
		"costs": [140, 240, 380],
	},
}

var save_path := DEFAULT_SAVE_PATH
var credits := 0
var warehouse: Array = []          # [{id, count}]，每项占一个仓库格
var upgrades := {"warehouse": 0, "medkit": 0, "damage": 0}
var stats := {"runs": 0, "extractions": 0, "deaths": 0}


func _init(path := DEFAULT_SAVE_PATH) -> void:
	save_path = path


func set_path(path: String) -> void:
	save_path = path


func reset() -> void:
	credits = 0
	warehouse.clear()
	upgrades = {"warehouse": 0, "medkit": 0, "damage": 0}
	stats = {"runs": 0, "extractions": 0, "deaths": 0}


func seed_demo() -> void:
	## 仅用于截图/演示的固定基地状态，不写入正常存档路径时更安全。
	reset()
	credits = 460
	upgrades = {"warehouse": 1, "medkit": 1, "damage": 1}
	stats = {"runs": 6, "extractions": 4, "deaths": 2}
	for entry in [
		{"id": "fog_crystal", "count": 2},
		{"id": "shipping_chip", "count": 2},
		{"id": "military_cell", "count": 1},
		{"id": "precision_rig", "count": 1},
		{"id": "brass_parts", "count": 4},
		{"id": "medkit", "count": 2},
		{"id": "old_script", "count": 6},
		{"id": "black_box", "count": 1},
	]:
		warehouse.append(entry)


func load_save() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	credits = maxi(0, int(data.get("credits", 0)))
	warehouse.clear()
	var raw_warehouse = data.get("warehouse", [])
	if typeof(raw_warehouse) == TYPE_ARRAY:
		for raw in raw_warehouse:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var id := String(raw.get("id", ""))
			var count := int(raw.get("count", 0))
			var item := FogItems.get_item(id)
			if item.is_empty() or count <= 0:
				continue
			if warehouse.size() >= warehouse_capacity():
				break
			warehouse.append({"id": id, "count": mini(count, int(item["stack_max"]))})
	var raw_upgrades = data.get("upgrades", {})
	upgrades = {"warehouse": 0, "medkit": 0, "damage": 0}
	if typeof(raw_upgrades) == TYPE_DICTIONARY:
		for key in upgrades.keys():
			var max_level := int(UPGRADE_DEFS[key]["max_level"])
			upgrades[key] = clampi(int(raw_upgrades.get(key, 0)), 0, max_level)
	var raw_stats = data.get("stats", {})
	if typeof(raw_stats) == TYPE_DICTIONARY:
		for key in stats.keys():
			stats[key] = maxi(0, int(raw_stats.get(key, 0)))
	return true


func save() -> bool:
	var dir := save_path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return true


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"credits": credits,
		"warehouse": warehouse.duplicate(true),
		"upgrades": upgrades.duplicate(true),
		"stats": stats.duplicate(true),
	}


func warehouse_capacity() -> int:
	return BASE_WAREHOUSE_CAPACITY + WAREHOUSE_PER_LEVEL * int(upgrades.get("warehouse", 0))


func warehouse_slots() -> int:
	return warehouse.size()


func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func upgrade_cost(id: String) -> int:
	if not UPGRADE_DEFS.has(id):
		return -1
	var level := upgrade_level(id)
	var costs: Array = UPGRADE_DEFS[id]["costs"]
	if level >= costs.size():
		return -1
	return int(costs[level])


func is_upgrade_max(id: String) -> bool:
	return upgrade_level(id) >= int(UPGRADE_DEFS[id]["max_level"])


func can_buy_upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	return cost >= 0 and credits >= cost


func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	var cost := upgrade_cost(id)
	credits -= cost
	upgrades[id] = upgrade_level(id) + 1
	save()
	return true


func weapon_damage() -> int:
	return BASE_WEAPON_DAMAGE + DAMAGE_PER_LEVEL * upgrade_level("damage")


func starting_medkits() -> int:
	return BASE_MEDKITS + upgrade_level("medkit")


func add_credits(amount: int) -> void:
	credits = maxi(0, credits + amount)


func spend_credits(amount: int) -> bool:
	if amount < 0 or credits < amount:
		return false
	credits -= amount
	return true


func add_to_warehouse(id: String, count: int) -> Dictionary:
	## 返回 {stored, overflow, overflow_credits}。溢出的物资按价值自动折现。
	var item := FogItems.get_item(id)
	if item.is_empty() or count <= 0:
		return {"stored": 0, "overflow": count, "overflow_credits": 0}
	var max_stack := int(item["stack_max"])
	var remaining := count
	for entry in warehouse:
		if String(entry["id"]) != id:
			continue
		var current := int(entry["count"])
		if current >= max_stack:
			continue
		var take := mini(max_stack - current, remaining)
		entry["count"] = current + take
		remaining -= take
		if remaining <= 0:
			return {"stored": count, "overflow": 0, "overflow_credits": 0}
	while remaining > 0 and warehouse.size() < warehouse_capacity():
		var put := mini(max_stack, remaining)
		warehouse.append({"id": id, "count": put})
		remaining -= put
	var overflow := remaining
	var overflow_credits := overflow * int(item["value"])
	credits += overflow_credits
	return {"stored": count - overflow, "overflow": overflow, "overflow_credits": overflow_credits}


func transfer_loot(inventory: FogInventory) -> Dictionary:
	## 撤离成功：旧港币换信用点，其余入库；背包清空。返回结算摘要。
	var result := {
		"stored": 0,
		"currency_credits": 0,
		"overflow": 0,
		"overflow_credits": 0,
		"total_value": 0,
		"items": [],
	}
	for entry in inventory.snapshot():
		var id := String(entry["id"])
		var count := int(entry["count"])
		var item := FogItems.get_item(id)
		if item.is_empty():
			continue
		result["total_value"] = int(result["total_value"]) + FogItems.value_of(id, count)
		if String(item["kind"]) == "currency":
			var gained := FogItems.value_of(id, count)
			credits += gained
			result["currency_credits"] = int(result["currency_credits"]) + gained
			result["items"].append({"id": id, "count": count, "credits": gained})
		else:
			var add := add_to_warehouse(id, count)
			result["stored"] = int(result["stored"]) + int(add["stored"])
			result["overflow"] = int(result["overflow"]) + int(add["overflow"])
			result["overflow_credits"] = int(result["overflow_credits"]) + int(add["overflow_credits"])
			result["items"].append({"id": id, "count": count, "stored": int(add["stored"])})
	inventory.clear()
	save()
	return result


func lose_run(inventory: FogInventory) -> Dictionary:
	## 阵亡：清空当局背包，返回损失摘要；不触碰仓库/升级。
	var lost := {
		"items": inventory.snapshot(),
		"count": inventory.total_count(),
		"value": inventory.total_value(),
	}
	inventory.clear()
	record_run(false)
	save()
	return lost


func record_run(success: bool) -> void:
	stats["runs"] = int(stats.get("runs", 0)) + 1
	if success:
		stats["extractions"] = int(stats.get("extractions", 0)) + 1
	else:
		stats["deaths"] = int(stats.get("deaths", 0)) + 1
	save()


func sell_all_warehouse() -> int:
	var gained := 0
	for entry in warehouse:
		gained += FogItems.value_of(String(entry["id"]), int(entry["count"]))
	warehouse.clear()
	credits += gained
	save()
	return gained


func warehouse_value() -> int:
	var total := 0
	for entry in warehouse:
		total += FogItems.value_of(String(entry["id"]), int(entry["count"]))
	return total
