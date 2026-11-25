extends RefCounted
## 《苔关八波》数据表：路径、建造位、敌人、塔、8 波组成、三选一构筑。
## 所有数值均为本项目原创起点，只抽象“走位 + 自动攻击 + 固定塔位 + 波间变强”。

const TITLE := "苔关八波"
const SUBTITLE := "Mossgate Stand"

const ARENA_SIZE := Vector2(1280, 720)
const DEFAULT_SEED := 20261122
const MAX_ENEMIES := 80

const START_GOLD := 60
const CASTLE_MAX_HP := 100
const CASTLE_HEAL_PER_WAVE := 5
const WALL_MAX_HP := 120
const WALL_REPAIR_COST := 25
const WALL_REBUILD_COST := 40
const PLAYER_REVIVE_COST := 10
const PLAYER_RESPAWN_TIME := 4.0

## 单条主路从右上敌军入口蜿蜒到左下山口主城。
const PATH_POINTS := [
	Vector2(1206, 150),
	Vector2(1030, 146),
	Vector2(940, 158),
	Vector2(870, 196),
	Vector2(820, 248),
	Vector2(792, 308),
	Vector2(786, 372),
	Vector2(758, 420),
	Vector2(708, 462),
	Vector2(642, 498),
	Vector2(570, 522),
	Vector2(492, 532),
	Vector2(420, 526),
	Vector2(360, 508),
	Vector2(310, 490),
	Vector2(278, 470),
]

const CASTLE_POS := Vector2(150, 470)
const CASTLE_GATE := Vector2(214, 470)
const CASTLE_ATTACK_POS := Vector2(206, 470)
const WALL_POS := Vector2(278, 470)
const WALL_ATTACK_POS := Vector2(318, 470)
const SPAWN_POS := Vector2(1206, 150)

const BUILD_PADS := [
	{"id": "B1", "name": "前哨台", "pos": Vector2(876, 286)},
	{"id": "B2", "name": "卡口台", "pos": Vector2(688, 386)},
	{"id": "B3", "name": "城前台", "pos": Vector2(404, 438)},
]

const PLAYER := {
	"hp": 100.0,
	"speed": 178.0,
	"range": 182.0,
	"damage": 12.0,
	"rate": 1.2,
	"skill_damage": 35.0,
	"skill_radius": 118.0,
	"skill_cd": 8.0,
	"dash": 72.0,
	"pickup": 130.0,
	"aggro": 240.0,
}

const ENEMY_ORDER := ["militia", "runner", "shield", "elite", "boss"]

const ENEMIES := {
	"militia": {
		"name": "叛军民兵",
		"hp": 30.0,
		"speed": 66.0,
		"damage": 5.0,
		"gold": 2,
		"radius": 10.0,
		"attack_interval": 1.0,
		"aggro": 108.0,
		"color": Color("b8553f"),
		"desc": "缓慢成列推进，用数量磨掉防线。",
	},
	"runner": {
		"name": "疾行斥候",
		"hp": 18.0,
		"speed": 125.0,
		"damage": 4.0,
		"gold": 2,
		"radius": 8.0,
		"attack_interval": 0.8,
		"aggro": 145.0,
		"color": Color("e0874e"),
		"desc": "低血量高速度，逼玩家离开安全站位。",
	},
	"shield": {
		"name": "铁盾卫",
		"hp": 80.0,
		"speed": 50.0,
		"damage": 8.0,
		"gold": 4,
		"radius": 12.5,
		"attack_interval": 1.2,
		"aggro": 102.0,
		"armor_bolt": 0.6,
		"color": Color("9d4738"),
		"desc": "重盾减伤：弩箭只造成 60%，炮塔克制。",
	},
	"elite": {
		"name": "破阵精英",
		"hp": 280.0,
		"speed": 56.0,
		"damage": 18.0,
		"gold": 15,
		"radius": 15.5,
		"attack_interval": 1.35,
		"aggro": 128.0,
		"prefers_tower": true,
		"color": Color("d0613f"),
		"desc": "高血量，优先拆最近的塔；需要集火。",
	},
	"boss": {
		"name": "裂关巨兽",
		"hp": 1200.0,
		"speed": 44.0,
		"damage": 28.0,
		"gold": 50,
		"radius": 25.0,
		"attack_interval": 1.6,
		"aggro": 160.0,
		"prefers_tower": true,
		"summon_ratio": 0.5,
		"summon_count": 4,
		"color": Color("8d5d44"),
		"desc": "终局巨兽：半血召唤四名民兵，重击城墙。",
	},
}

const TOWERS := {
	"crossbow": {
		"name": "弩塔",
		"cost": 50,
		"upgrade_cost": 60,
		"range": 205.0,
		"rate": 1.5,
		"damage": 10.0,
		"hp": 180.0,
		"kind": "bolt",
		"color": Color("7fb3a0"),
		"desc": "单体连射；便宜稳定，对铁盾卫伤害打折。",
	},
	"cannon": {
		"name": "炮塔",
		"cost": 70,
		"upgrade_cost": 80,
		"range": 190.0,
		"rate": 0.6,
		"damage": 25.0,
		"hp": 200.0,
		"splash": 58.0,
		"kind": "cannon",
		"color": Color("d9a45a"),
		"desc": "范围爆炸；克制密集兵潮与铁盾卫，射速慢。",
	},
}

const TOWER_ORDER := ["crossbow", "cannon"]

const UPGRADES := {
	"range": {
		"name": "鹰眼工事",
		"tag": "工事",
		"desc": "所有塔射程 +20%。",
		"icon": "range",
	},
	"lord_rate": {
		"name": "快剑训练",
		"tag": "领主",
		"desc": "领主普攻速度 +25%。",
		"icon": "blade",
	},
	"gold": {
		"name": "战地征缴",
		"tag": "经济",
		"desc": "每次击杀额外获得 1 金币。",
		"icon": "coin",
	},
	"castle_heal": {
		"name": "城防抢修",
		"tag": "城防",
		"desc": "主城立即回复 20 HP。",
		"icon": "shield",
	},
	"cannon": {
		"name": "重炮校准",
		"tag": "炮塔",
		"desc": "炮塔伤害 +25%，爆炸范围 +20%。",
		"icon": "cannon",
	},
	"skill_cd": {
		"name": "疾风身法",
		"tag": "技能",
		"desc": "回旋斩冷却时间 -2 秒。",
		"icon": "wind",
	},
	"tower_rate": {
		"name": "轮班操炮",
		"tag": "工事",
		"desc": "所有塔攻击速度 +20%。",
		"icon": "gear",
	},
	"lord_damage": {
		"name": "破甲利刃",
		"tag": "领主",
		"desc": "领主攻击伤害 +30%。",
		"icon": "blade",
	},
	"gold2": {
		"name": "凯旋赏金",
		"tag": "经济",
		"desc": "每次击杀额外获得 1 金币。",
		"icon": "coin",
	},
}

const UPGRADE_MILESTONES := [
	{"after_wave": 2, "title": "第一道战功", "subtitle": "选择一项构筑，继续守下一波。", "options": ["range", "lord_rate", "gold"]},
	{"after_wave": 4, "title": "工事抉择", "subtitle": "兵潮变重，补上城防或火力。", "options": ["castle_heal", "cannon", "skill_cd"]},
	{"after_wave": 6, "title": "终局构筑", "subtitle": "最后一波只剩巨兽，选定你的答案。", "options": ["tower_rate", "lord_damage", "gold2"]},
]

const WAVES := [
	{
		"prep": 10.0,
		"reward": 20,
		"groups": [
			{"type": "militia", "count": 6, "interval": 1.2, "start": 0.4},
		],
	},
	{
		"prep": 10.0,
		"reward": 25,
		"groups": [
			{"type": "militia", "count": 10, "interval": 1.1, "start": 0.4},
			{"type": "runner", "count": 2, "interval": 1.2, "start": 5.2},
		],
	},
	{
		"prep": 10.0,
		"reward": 30,
		"groups": [
			{"type": "militia", "count": 12, "interval": 1.0, "start": 0.4},
			{"type": "shield", "count": 3, "interval": 1.5, "start": 4.5},
		],
	},
	{
		"prep": 10.0,
		"reward": 35,
		"groups": [
			{"type": "runner", "count": 6, "interval": 0.9, "start": 0.4},
			{"type": "shield", "count": 4, "interval": 1.2, "start": 2.5},
			{"type": "elite", "count": 1, "interval": 1.0, "start": 7.5},
		],
	},
	{
		"prep": 10.0,
		"reward": 40,
		"groups": [
			{"type": "militia", "count": 8, "interval": 0.85, "start": 0.4},
			{"type": "runner", "count": 5, "interval": 0.9, "start": 2.0},
			{"type": "shield", "count": 4, "interval": 1.2, "start": 4.0},
			{"type": "elite", "count": 2, "interval": 3.0, "start": 7.0},
		],
	},
	{
		"prep": 10.0,
		"reward": 45,
		"groups": [
			{"type": "militia", "count": 8, "interval": 0.8, "start": 0.4},
			{"type": "runner", "count": 6, "interval": 0.8, "start": 2.5},
			{"type": "shield", "count": 4, "interval": 1.1, "start": 4.5},
			{"type": "elite", "count": 3, "interval": 2.8, "start": 7.0},
		],
	},
	{
		"prep": 10.0,
		"reward": 50,
		"groups": [
			{"type": "militia", "count": 6, "interval": 0.8, "start": 0.4},
			{"type": "runner", "count": 4, "interval": 0.9, "start": 2.0},
			{"type": "shield", "count": 2, "interval": 1.2, "start": 4.0},
			{"type": "elite", "count": 2, "interval": 3.0, "start": 6.5},
		],
	},
	{
		"prep": 12.0,
		"reward": 100,
		"groups": [
			{"type": "militia", "count": 10, "interval": 0.9, "start": 0.4},
			{"type": "boss", "count": 1, "interval": 1.0, "start": 1.0},
		],
	},
]

static var _path_cum := PackedFloat32Array()


static func path_length() -> float:
	_ensure_path()
	return _path_cum[_path_cum.size() - 1]


static func _ensure_path() -> void:
	if _path_cum.size() == PATH_POINTS.size():
		return
	_path_cum = PackedFloat32Array()
	_path_cum.append(0.0)
	var total := 0.0
	for i in range(1, PATH_POINTS.size()):
		total += PATH_POINTS[i].distance_to(PATH_POINTS[i - 1])
		_path_cum.append(total)


static func path_point_at(distance: float) -> Vector2:
	_ensure_path()
	var total := _path_cum[_path_cum.size() - 1]
	var d := clampf(distance, 0.0, total)
	for i in range(1, _path_cum.size()):
		if d <= _path_cum[i]:
			var seg := _path_cum[i] - _path_cum[i - 1]
			var t := 0.0 if seg <= 0.001 else (d - _path_cum[i - 1]) / seg
			return PATH_POINTS[i - 1].lerp(PATH_POINTS[i], t)
	return PATH_POINTS[PATH_POINTS.size() - 1]


static func path_tangent_at(distance: float) -> Vector2:
	_ensure_path()
	var total := _path_cum[_path_cum.size() - 1]
	var d := clampf(distance, 0.0, total)
	for i in range(1, _path_cum.size()):
		if d <= _path_cum[i]:
			return (PATH_POINTS[i] - PATH_POINTS[i - 1]).normalized()
	return (PATH_POINTS[PATH_POINTS.size() - 1] - PATH_POINTS[PATH_POINTS.size() - 2]).normalized()


static func distance_to_path(point: Vector2) -> float:
	var best := INF
	for i in range(1, PATH_POINTS.size()):
		var a: Vector2 = PATH_POINTS[i - 1]
		var b: Vector2 = PATH_POINTS[i]
		var ab: Vector2 = b - a
		var len_sq: float = ab.length_squared()
		var t := 0.0 if len_sq <= 0.001 else clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
		best = minf(best, point.distance_to(a + ab * t))
	return best


static func wave_enemy_total(wave_index: int) -> int:
	var total := 0
	for group in WAVES[wave_index]["groups"]:
		total += int(group["count"])
	return total


static func wave_summary(wave_index: int) -> String:
	if wave_index < 0 or wave_index >= WAVES.size():
		return ""
	var counts := {}
	for group in WAVES[wave_index]["groups"]:
		var type_id := String(group["type"])
		counts[type_id] = int(counts.get(type_id, 0)) + int(group["count"])
	var parts: Array[String] = []
	for type_id in ENEMY_ORDER:
		if counts.has(type_id):
			parts.append("%s ×%d" % [String(ENEMIES[type_id]["name"]), int(counts[type_id])])
	return " · ".join(parts)


static func milestone_for_wave(cleared_wave: int) -> int:
	for i in range(UPGRADE_MILESTONES.size()):
		if int(UPGRADE_MILESTONES[i]["after_wave"]) == cleared_wave:
			return i
	return -1


static func tower_stats(type_id: String, level: int, mods: Dictionary) -> Dictionary:
	var def: Dictionary = TOWERS[type_id]
	var lv := maxi(1, level)
	var range_mult := 1.0 + 0.10 * float(lv - 1)
	var rate_mult := 1.0 + 0.10 * float(lv - 1)
	var dmg_mult := 1.0 + 0.25 * float(lv - 1)
	var stats := {
		"range": float(def["range"]) * range_mult * float(mods.get("tower_range", 1.0)),
		"rate": float(def["rate"]) * rate_mult * float(mods.get("tower_rate", 1.0)),
		"damage": float(def["damage"]) * dmg_mult * float(mods.get("tower_damage", 1.0)),
		"splash": 0.0,
	}
	if type_id == "cannon":
		stats["damage"] = float(stats["damage"]) * float(mods.get("cannon_damage", 1.0))
		stats["splash"] = float(def["splash"]) * (1.0 + 0.10 * float(lv - 1)) * float(mods.get("cannon_splash", 1.0))
	return stats
