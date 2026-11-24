class_name MistBalance
extends RefCounted
## 单局规则与数值的唯一事实来源：兵种、克制、高度、敌人、岛屿与波次。
## 全部命名、数值与关卡编排均为本项目原创；只复刻“分队实时防守”的抽象玩法类型。

const SQUAD_SIZE := 4
const WATER_LEVEL := 0.55
const HOUSE_HP := 150.0

const PREP_TIME := 20.0
const INTERMISSION := 8.0
const BOAT_TRAVEL := 3.1
const DISEMBARK_INTERVAL := 0.55

const HIGH_GROUND_BONUS := 1.20
const HIGH_GROUND_MALUS := 0.85
const HEIGHT_THRESHOLD := 1.5

# 克制三角：盾克弓、弓克矛、矛克盾。优势 ×1.8，劣势 ×0.62。
const COUNTER := {
	"shield": {"archer": 1.8, "spear": 0.62, "shield": 1.0, "raider": 1.0},
	"archer": {"spear": 1.8, "shield": 0.62, "archer": 1.0, "raider": 1.0},
	"spear": {"shield": 1.8, "archer": 0.62, "spear": 1.0, "raider": 1.0},
	"raider": {"shield": 1.0, "archer": 1.0, "spear": 1.0, "raider": 1.0},
}

const PLAYER_CLASSES := {
	"shield": {
		"name": "盾卫", "title": "苔盾队", "icon": "shield", "hotkey": "1",
		"hp": 74.0, "damage": 13.0, "range": 2.6, "cooldown": 1.05, "speed": 3.25,
		"ranged": false, "class_id": "shield",
		"color": "7fb0cf", "accent": "e0bd74",
		"desc": "重盾抵挡箭矢；贴身压制弓手，但畏惧长矛。",
	},
	"archer": {
		"name": "弓手", "title": "风弦队", "icon": "archer", "hotkey": "2",
		"hp": 34.0, "damage": 11.0, "range": 15.5, "cooldown": 1.55, "speed": 3.0,
		"ranged": true, "projectile_speed": 26.0, "class_id": "archer",
		"color": "8fc7a8", "accent": "33544a",
		"desc": "远距抛射，专克矛手与重甲；被盾卫近身则险。",
	},
	"spear": {
		"name": "矛手", "title": "潮枪队", "icon": "spear", "hotkey": "3",
		"hp": 48.0, "damage": 15.0, "range": 3.35, "cooldown": 1.2, "speed": 3.55,
		"ranged": false, "class_id": "spear",
		"color": "e0bd74", "accent": "5b6f95",
		"desc": "长杆拒止盾阵；推进最快，但会被弓手远距消耗。",
	},
}

const ENEMY_TYPES := {
	"raider": {
		"name": "海掠者", "hp": 46.0, "damage": 9.0, "range": 2.25, "cooldown": 1.0,
		"speed": 2.95, "class_id": "raider", "ranged": false, "house_mult": 1.0,
		"scale": 1.0, "color": "9b5a45",
	},
	"brute": {
		"name": "重盾蛮兵", "hp": 128.0, "damage": 17.0, "range": 2.45, "cooldown": 1.4,
		"speed": 2.15, "class_id": "shield", "ranged": false, "house_mult": 1.6,
		"scale": 1.30, "ranged_resist": 0.5, "color": "7d4a3d",
	},
	"skirmisher": {
		"name": "掷斧手", "hp": 36.0, "damage": 8.5, "range": 11.5, "cooldown": 1.8,
		"speed": 2.7, "class_id": "archer", "ranged": true, "projectile_speed": 18.0,
		"house_mult": 0.6, "scale": 0.95, "color": "a56d4c",
	},
	"chieftain": {
		"name": "潮汐首领", "hp": 310.0, "damage": 24.0, "range": 2.9, "cooldown": 1.35,
		"speed": 2.4, "class_id": "shield", "ranged": false, "house_mult": 2.0,
		"scale": 1.5, "ranged_resist": 0.35, "color": "b04938",
	},
}

const ISLANDS := [
	{
		"id": "verdant_bluff",
		"name": "青崖岛",
		"subtitle": "雾中第一道屋脊",
		"seed": 31415,
		"radius": 40.0,
		"plateau": 7.2,
		"hill_offsets": [Vector2(-5, -2), Vector2(6, 5)],
		"house_positions": [Vector2(-9, -5), Vector2(10, -3), Vector2(2, 11)],
		"house_yaws": [18.0, -24.0, 8.0],
		"squad_positions": [Vector2(-6.5, 2.5), Vector2(7.0, -0.5), Vector2(1.5, 7.5)],
		"landing_angles": [200.0, 338.0, 92.0],
		"waves": [
			{"groups": [{"type": "raider", "count": 5, "landing": 0}]},
			{"groups": [
				{"type": "raider", "count": 5, "landing": 1},
				{"type": "brute", "count": 2, "landing": 0},
			]},
			{"groups": [
				{"type": "raider", "count": 6, "landing": 0},
				{"type": "brute", "count": 2, "landing": 1},
				{"type": "skirmisher", "count": 2, "landing": 2},
				{"type": "chieftain", "count": 1, "landing": 1},
			]},
		],
	},
	{
		"id": "duskfire_cove",
		"name": "暮火湾",
		"subtitle": "潮声深处的最后一夜",
		"seed": 90210,
		"radius": 43.0,
		"plateau": 7.9,
		"hill_offsets": [Vector2(-8, 4), Vector2(8, -5), Vector2(0, -12)],
		"house_positions": [Vector2(-12, -4), Vector2(12, -7), Vector2(4, 12)],
		"house_yaws": [-12.0, 26.0, 160.0],
		"squad_positions": [Vector2(-8, 2), Vector2(10, 2), Vector2(0, -9)],
		"landing_angles": [168.0, 312.0, 58.0],
		"waves": [
			{"groups": [{"type": "raider", "count": 6, "landing": 0}]},
			{"groups": [
				{"type": "raider", "count": 6, "landing": 1},
				{"type": "brute", "count": 2, "landing": 2},
			]},
			{"groups": [
				{"type": "raider", "count": 7, "landing": 0},
				{"type": "skirmisher", "count": 3, "landing": 1},
				{"type": "brute", "count": 2, "landing": 0},
			]},
			{"groups": [
				{"type": "raider", "count": 8, "landing": 0},
				{"type": "brute", "count": 4, "landing": 1},
				{"type": "skirmisher", "count": 4, "landing": 2},
				{"type": "chieftain", "count": 1, "landing": 2},
			]},
		],
	},
]


static func island(index: int) -> Dictionary:
	return ISLANDS[clampi(index, 0, ISLANDS.size() - 1)]


static func island_count() -> int:
	return ISLANDS.size()


static func player_class(id: String) -> Dictionary:
	return PLAYER_CLASSES.get(id, PLAYER_CLASSES["shield"])


static func enemy_type(id: String) -> Dictionary:
	return ENEMY_TYPES.get(id, ENEMY_TYPES["raider"])


static func wave_count(island_index: int) -> int:
	return island(island_index)["waves"].size()


static func wave_total_enemies(island_index: int, wave_index: int) -> int:
	var waves: Array = island(island_index)["waves"]
	if wave_index < 0 or wave_index >= waves.size():
		return 0
	var total := 0
	for group in waves[wave_index]["groups"]:
		total += int(group["count"])
	return total


static func counter(attacker_class: String, defender_class: String) -> float:
	var row: Dictionary = COUNTER.get(attacker_class, {})
	return float(row.get(defender_class, 1.0))


static func height_multiplier(attacker_height: float, defender_height: float) -> float:
	var diff := attacker_height - defender_height
	if diff >= HEIGHT_THRESHOLD:
		return HIGH_GROUND_BONUS
	if diff <= -HEIGHT_THRESHOLD:
		return HIGH_GROUND_MALUS
	return 1.0


static func height_label(attacker_height: float, defender_height: float) -> String:
	var diff := attacker_height - defender_height
	if diff >= HEIGHT_THRESHOLD:
		return "居高"
	if diff <= -HEIGHT_THRESHOLD:
		return "仰攻"
	return ""


static func ranged_resist(defender_class_id: String, enemy_type_id := "") -> float:
	if enemy_type_id != "":
		var enemy: Dictionary = ENEMY_TYPES.get(enemy_type_id, {})
		if enemy.has("ranged_resist"):
			return float(enemy["ranged_resist"])
	match defender_class_id:
		"shield":
			return 0.5
		"chieftain":
			return 0.35
		"brute":
			return 0.5
		_:
			return 1.0


static func squad_color(class_id: String) -> Color:
	return Color(PLAYER_CLASSES.get(class_id, PLAYER_CLASSES["shield"])["color"])


static func counter_summary() -> String:
	return "盾克弓 · 弓克矛 · 矛克盾"
