class_name FogItems
extends RefCounted
## 8 类原创战利品数据表。
## 字段：id / name / rarity(0-3) / value(信用点) / stack_max / grid(占格) / kind / desc。
## 稀有度：0 常见、1 少见、2 稀有、3 绝密。

const RARITY_NAMES := ["常见", "少见", "稀有", "绝密"]
const RARITY_COLORS := [
	Color("93a8b4"),
	Color("59c9b6"),
	Color("b48cff"),
	Color("f0b24d"),
]

const ITEM_LIST := [
	{
		"id": "old_script", "name": "旧港币", "rarity": 0, "value": 20,
		"stack_max": 8, "grid": Vector2i(1, 1), "kind": "currency",
		"desc": "雾港旧时代的纸币，边角被雾浸得发软。撤离后会在基地自动兑换成信用点。",
	},
	{
		"id": "medkit", "name": "医疗包", "rarity": 0, "value": 20,
		"stack_max": 3, "grid": Vector2i(1, 1), "kind": "consumable", "heal": 45,
		"desc": "港区诊所遗留的压缩医疗包。使用后回复 45 点生命，不能在交火中站桩硬用。",
	},
	{
		"id": "brass_parts", "name": "黄铜零件", "rarity": 0, "value": 35,
		"stack_max": 5, "grid": Vector2i(1, 1), "kind": "material",
		"desc": "从报废吊机里拆下的黄铜齿轮和轴承，基地工坊愿意回收。",
	},
	{
		"id": "shipping_chip", "name": "船运芯片", "rarity": 1, "value": 90,
		"stack_max": 3, "grid": Vector2i(1, 1), "kind": "material",
		"desc": "记录着旧航线编号的加密芯片，雾港的拾荒者都在找这种东西。",
	},
	{
		"id": "military_cell", "name": "军用电池", "rarity": 1, "value": 75,
		"stack_max": 2, "grid": Vector2i(1, 1), "kind": "material",
		"desc": "仍有余电的加固电池，接口规格罕见，只有基地能安全拆解。",
	},
	{
		"id": "precision_rig", "name": "精密仪器", "rarity": 2, "value": 170,
		"stack_max": 1, "grid": Vector2i(2, 1), "kind": "material",
		"desc": "带防潮外壳的测量仪，占了两个背包格。黑市上能卖出不错的价钱。",
	},
	{
		"id": "fog_crystal", "name": "雾晶", "rarity": 2, "value": 240,
		"stack_max": 2, "grid": Vector2i(1, 1), "kind": "material",
		"desc": "在雾中缓慢生长的青色结晶，贴近时能听见极轻的嗡鸣。",
	},
	{
		"id": "black_box", "name": "黑匣子", "rarity": 3, "value": 480,
		"stack_max": 1, "grid": Vector2i(2, 2), "kind": "material",
		"desc": "沉船记录仪，外壳焦黑，四角占满背包。港区看守会为它拼命。",
	},
]

static var _by_id: Dictionary = {}


static func get_item(id: String) -> Dictionary:
	if _by_id.is_empty():
		for item in ITEM_LIST:
			_by_id[String(item["id"])] = item
	return _by_id.get(id, {})


static func has_item(id: String) -> bool:
	return not get_item(id).is_empty()


static func all_ids() -> Array:
	var ids: Array = []
	for item in ITEM_LIST:
		ids.append(String(item["id"]))
	return ids


static func rarity_color(rarity: int) -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]


static func rarity_name(rarity: int) -> String:
	return RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)]


static func value_of(id: String, count := 1) -> int:
	var item := get_item(id)
	return int(item.get("value", 0)) * count


static func roll_chest(rng: RandomNumberGenerator, tier := 0) -> Array:
	## 2–3 次抽取；精英箱（tier>=1）保底至少一件稀有物品。
	var draws: int = rng.randi_range(2, 3)
	var loot: Array = []
	var best_rarity := -1
	for _i in range(draws):
		var id: String = _weighted_id(rng, tier)
		var count: int = _roll_count(rng, id)
		best_rarity = maxi(best_rarity, int(get_item(id)["rarity"]))
		_merge_entry(loot, id, count)
	if tier >= 1 and best_rarity < 2:
		_merge_entry(loot, "fog_crystal", 1)
	return loot


static func _weighted_id(rng: RandomNumberGenerator, tier: int) -> String:
	# [id, 普通箱权重, 精英箱权重]
	var table := [
		["old_script", 30, 20],
		["medkit", 14, 10],
		["brass_parts", 24, 15],
		["shipping_chip", 15, 18],
		["military_cell", 10, 14],
		["precision_rig", 4, 10],
		["fog_crystal", 2, 8],
		["black_box", 1, 5],
	]
	var total := 0
	var col := 1 if tier <= 0 else 2
	for row in table:
		total += int(row[col])
	var pick := rng.randi_range(1, total)
	for row in table:
		pick -= int(row[col])
		if pick <= 0:
			return String(row[0])
	return "brass_parts"


static func _roll_count(rng: RandomNumberGenerator, id: String) -> int:
	match id:
		"old_script":
			return rng.randi_range(2, 5)
		"medkit":
			return rng.randi_range(1, 2)
		"brass_parts":
			return rng.randi_range(1, 3)
		"shipping_chip", "military_cell":
			return rng.randi_range(1, 2)
		_:
			return 1


static func _merge_entry(loot: Array, id: String, count: int) -> void:
	for entry in loot:
		if String(entry["id"]) == id:
			entry["count"] = int(entry["count"]) + count
			return
	loot.append({"id": id, "count": count})


static func total_value(loot: Array, currency_id := "old_script") -> int:
	var total := 0
	for entry in loot:
		var id := String(entry["id"])
		var count := int(entry["count"])
		if id == currency_id:
			continue
		total += value_of(id, count)
	return total
