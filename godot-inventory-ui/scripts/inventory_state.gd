class_name InventoryState
extends RefCounted

const PAGE_COUNT := 5
const PAGE_NAMES := ["一", "二", "三", "四", "临时"]
const CATEGORIES := ["全部", "装备", "消耗", "材料", "任务", "杂项"]
const CATEGORY_ORDER := {"装备": 0, "消耗": 1, "材料": 2, "任务": 3, "杂项": 4}

var player: Dictionary = {}
var equipment: Array = []
var items: Array = []
var loaded := false
var data_path := "res://data/items.json"


func load_from(path: String = "res://data/items.json") -> bool:
	data_path = path
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open inventory data: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid inventory JSON")
		return false
	var doc: Dictionary = parsed
	player = doc.get("player", {})
	equipment = doc.get("equipment_slots", [])
	items = doc.get("items", [])
	_normalize()
	loaded = true
	return true


func _normalize() -> void:
	var int_keys := ["level", "hp", "hp_max", "mp", "mp_max", "attack", "spirit", "defense", "speed", "gold", "silver", "capacity"]
	for k in int_keys:
		player[k] = int(player.get(k, 0))
	for slot in equipment:
		slot["level"] = int(slot.get("level", 1))
		slot["quality"] = int(slot.get("quality", 0))
		if slot.get("stats", null) == null:
			slot["stats"] = {}
	for it in items:
		it["quality"] = int(it.get("quality", 0))
		it["level"] = int(it.get("level", 1))
		it["stack"] = int(it.get("stack", 1))
		it["max_stack"] = int(it.get("max_stack", 1))
		it["page"] = int(it.get("page", 1))
		it["price"] = int(it.get("price", 0))
		it["bindable"] = bool(it.get("bindable", true))
		it["sellable"] = bool(it.get("sellable", false))
		it["discardable"] = bool(it.get("discardable", true))
		if it.get("stats", null) == null:
			it["stats"] = {}
		if it.has("use") and typeof(it["use"]) == TYPE_DICTIONARY:
			for uk in it["use"].keys():
				if uk in ["hp", "mp", "silver"]:
					it["use"][uk] = int(it["use"][uk])


func reload() -> bool:
	return load_from(data_path)


func page_all_items(page: int) -> Array:
	var out: Array = []
	for it in items:
		if int(it["page"]) == page:
			out.append(it)
	return out


func page_items(page: int, category: String = "全部") -> Array:
	var out: Array = []
	for it in items:
		if int(it["page"]) != page:
			continue
		if category != "全部" and str(it["category"]) != category:
			continue
		out.append(it)
	return out


func item_by_id(id: String) -> Dictionary:
	for it in items:
		if str(it["id"]) == id:
			return it
	return {}


func equipment_by_slot(slot_key: String) -> Dictionary:
	for slot in equipment:
		if str(slot["slot"]) == slot_key:
			return slot
	return {}


func used_capacity() -> int:
	return items.size()


func total_capacity() -> int:
	return int(player.get("capacity", 216))


func can_use(item: Dictionary) -> bool:
	return item.size() > 0 and item.has("use") and typeof(item["use"]) == TYPE_DICTIONARY


func can_discard(item: Dictionary) -> bool:
	return item.size() > 0 and bool(item.get("discardable", true))


func can_sell(item: Dictionary) -> bool:
	return item.size() > 0 and bool(item.get("sellable", false)) and int(item.get("price", 0)) > 0


func use_item(id: String) -> Dictionary:
	var item := item_by_id(id)
	if item.is_empty():
		return {"ok": false, "reason": "物品不存在"}
	if not can_use(item):
		return {"ok": false, "reason": "该物品不可直接使用"}
	var use: Dictionary = item["use"]
	var text := str(use.get("text", "已使用"))
	if use.has("hp"):
		var before := int(player["hp"])
		player["hp"] = mini(int(player["hp_max"]), before + int(use["hp"]))
		var gained := int(player["hp"]) - before
		if gained <= 0:
			text = "气血已满，药力化入经脉"
	if use.has("mp"):
		var before_mp := int(player["mp"])
		player["mp"] = mini(int(player["mp_max"]), before_mp + int(use["mp"]))
		if int(player["mp"]) - before_mp <= 0:
			text = "魔法已满，灵气散入丹田"
	if use.has("silver"):
		player["silver"] = int(player["silver"]) + int(use["silver"])
		text = "%s（+%d 银两）" % [text, int(use["silver"])]
	item["stack"] = int(item["stack"]) - 1
	var removed := int(item["stack"]) <= 0
	var display_name := str(item["name"])
	if removed:
		for i in range(items.size()):
			if str(items[i]["id"]) == id:
				items.remove_at(i)
				break
	return {
		"ok": true, "message": text, "removed": removed,
		"name": display_name, "item": item,
	}


func discard_item(id: String) -> Dictionary:
	var item := item_by_id(id)
	if item.is_empty():
		return {"ok": false, "reason": "物品不存在"}
	if not can_discard(item):
		return {"ok": false, "reason": "任务物品不可丢弃"}
	var display_name := str(item["name"])
	var count := int(item["stack"])
	for i in range(items.size()):
		if str(items[i]["id"]) == id:
			items.remove_at(i)
			break
	return {"ok": true, "name": display_name, "count": count,
		"message": "已丢弃「%s」×%d" % [display_name, count]}


func sell_item(id: String) -> Dictionary:
	var item := item_by_id(id)
	if item.is_empty():
		return {"ok": false, "reason": "物品不存在"}
	if not can_sell(item):
		var reason := "任务物品不可出售"
		if str(item.get("category", "")) == "装备":
			reason = "已认主的装备不可出售"
		return {"ok": false, "reason": reason}
	var display_name := str(item["name"])
	var count := int(item["stack"])
	var total := int(item["price"]) * count
	player["silver"] = int(player["silver"]) + total
	for i in range(items.size()):
		if str(items[i]["id"]) == id:
			items.remove_at(i)
			break
	return {"ok": true, "name": display_name, "count": count,
		"silver": total, "message": "出售「%s」×%d，获得 %d 银两" % [display_name, count, total]}


func sort_page(page: int) -> void:
	var others: Array = []
	var page_batch: Array = []
	for it in items:
		if int(it["page"]) == page:
			page_batch.append(it)
		else:
			others.append(it)
	page_batch.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var qa := int(a.get("quality", 0))
		var qb := int(b.get("quality", 0))
		if qa != qb:
			return qa > qb
		var ca: int = int(CATEGORY_ORDER.get(str(a.get("category", "")), 9))
		var cb: int = int(CATEGORY_ORDER.get(str(b.get("category", "")), 9))
		if ca != cb:
			return ca < cb
		var la := int(a.get("level", 1))
		var lb := int(b.get("level", 1))
		if la != lb:
			return la > lb
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	# keep page grouping, but reorder this page's items in the master list
	var rebuilt: Array = []
	for p in range(1, PAGE_COUNT + 1):
		for it in others:
			if int(it["page"]) == p:
				rebuilt.append(it)
		if p == page:
			rebuilt.append_array(page_batch)
	items = rebuilt


func count_on_page(page: int, category: String = "全部") -> int:
	return page_items(page, category).size()


func format_stats(stats: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for key in stats.keys():
		var v := int(stats[key])
		lines.append("%s  +%d" % [str(key), v])
	return lines


func apply_use_preview(item: Dictionary) -> String:
	if not can_use(item):
		return ""
	var use: Dictionary = item["use"]
	var parts: Array[String] = []
	if use.has("hp"):
		parts.append("气血 +%d" % int(use["hp"]))
	if use.has("mp"):
		parts.append("魔法 +%d" % int(use["mp"]))
	if use.has("silver"):
		parts.append("银两 +%d" % int(use["silver"]))
	return " · ".join(parts)
