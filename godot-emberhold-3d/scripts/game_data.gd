class_name GameData
extends RefCounted
## Static rules ported 1:1 from web-html-tower-defense/index.html.
## Values intentionally stay in HTML field pixels; views convert px -> world.

const TILE := 16.0
const GW := 29
const GH := 21
const FIELD_W := GW * TILE      # 464
const FIELD_H := GH * TILE      # 336
const MAX_WAVE := 12
const START_GOLD := 140
const START_LIVES := 20
const SKILL_CD := 35.0
const SKILL_DMG := 30
const STEP := 1.0 / 60.0
const PREP_TIME := 5.6
const AI_INTERVAL := 0.55
const SELL_RATIO := 0.65

const PAL := {
	"ink": "#08070c",
	"deep": "#121019",
	"night": "#1a1725",
	"panel": "#14101a",
	"panel2": "#1d1926",
	"line": "#3a3040",
	"line_hot": "#6f4d3b",
	"bone": "#e9dfc6",
	"bone_dim": "#b7a98e",
	"muted": "#8a7f74",
	"dim": "#5a524e",
	"gold": "#f2c46b",
	"gold_hi": "#ffe7a8",
	"ember": "#ff8a3d",
	"ember_hi": "#ffd27a",
	"ember_red": "#c94a34",
	"life": "#e46a52",
	"frost": "#7cd7d0",
	"frost_hi": "#d8f4ee",
	"frost_dim": "#3c8d93",
	"green": "#8fbf6a",
	"green_dim": "#55774b",
	"violet": "#a58ad6",
	"red": "#d66058",
	"white": "#fff6e2",
}

const TOWER_ORDER := ["bolt", "flame", "frost", "mint"]

const TOWERS := {
	"bolt": {
		"key": "bolt", "name": "燧石哨塔", "short": "燧石", "tag": "单体", "hotkey": "1",
		"cost": 40, "upgrades": [45, 70], "color": "#ff8a3d",
		"desc": "灼热弩箭，优先攻击最靠前的敌人。",
		"levels": [
			{"dmg": 10, "rate": 1.15, "range": 58.0},
			{"dmg": 16, "rate": 1.30, "range": 64.0},
			{"dmg": 25, "rate": 1.45, "range": 70.0},
		],
	},
	"flame": {
		"key": "flame", "name": "焰心炉", "short": "焰炉", "tag": "范围", "hotkey": "2",
		"cost": 65, "upgrades": [60, 85], "color": "#ff6b3a",
		"desc": "掷出炽炭，对落点周围造成溅射伤害。",
		"levels": [
			{"dmg": 13, "rate": 0.55, "range": 54.0, "splash": 24.0},
			{"dmg": 20, "rate": 0.62, "range": 58.0, "splash": 28.0},
			{"dmg": 30, "rate": 0.70, "range": 62.0, "splash": 32.0},
		],
	},
	"frost": {
		"key": "frost", "name": "霜苔环", "short": "霜环", "tag": "减速", "hotkey": "3",
		"cost": 55, "upgrades": [45, 70], "color": "#7cd7d0",
		"desc": "冻苔孢子命中后拖慢敌人，为火力争取时间。",
		"levels": [
			{"dmg": 3, "rate": 0.95, "range": 62.0, "slow": 0.45, "slow_time": 1.8},
			{"dmg": 5, "rate": 1.05, "range": 70.0, "slow": 0.55, "slow_time": 2.0},
			{"dmg": 8, "rate": 1.15, "range": 76.0, "slow": 0.62, "slow_time": 2.2},
		],
	},
	"mint": {
		"key": "mint", "name": "铸币圣坛", "short": "圣坛", "tag": "经济", "hotkey": "4",
		"cost": 50, "upgrades": [40, 60], "color": "#f2c46b",
		"desc": "每波结束时产出金币。越早建，回本越快。",
		"levels": [{"income": 6}, {"income": 10}, {"income": 15}],
	},
}

const ENEMIES := {
	"walker": {
		"key": "walker", "name": "灰烬行者", "hp": 30, "speed": 32.0, "reward": 7, "leak": 1,
		"armor": 0, "radius": 5.0, "color": "#5b5268", "dim": "#2e2938", "slow_resist": 0.0,
	},
	"moth": {
		"key": "moth", "name": "幽火蛾", "hp": 20, "speed": 50.0, "reward": 6, "leak": 1,
		"armor": 0, "radius": 4.0, "color": "#9addc9", "dim": "#458d86", "slow_resist": 0.0,
	},
	"brute": {
		"key": "brute", "name": "锈甲兽", "hp": 115, "speed": 19.0, "reward": 15, "leak": 2,
		"armor": 2, "radius": 6.0, "color": "#b97358", "dim": "#6f4034", "slow_resist": 0.0,
	},
	"spore": {
		"key": "spore", "name": "孢母", "hp": 205, "speed": 15.0, "reward": 24, "leak": 3,
		"armor": 1, "radius": 7.0, "color": "#a58ad6", "dim": "#5e4b7e", "slow_resist": 0.5,
		"heal": 6, "heal_radius": 38.0,
	},
	"boss": {
		"key": "boss", "name": "无光巨像", "hp": 1120, "speed": 13.0, "reward": 120, "leak": 8,
		"armor": 4, "radius": 11.0, "color": "#e8784a", "dim": "#6f3225", "slow_resist": 0.4,
		"boss": true,
	},
}

const WAVES := [
	{"name": "灰烬初潮", "groups": [{"type": "walker", "n": 6, "gap": 1.0}]},
	{"name": "踏火而行", "groups": [{"type": "walker", "n": 9, "gap": 0.85}]},
	{"name": "蛾群夜巡", "groups": [
		{"type": "moth", "n": 10, "gap": 0.5},
		{"type": "walker", "n": 4, "gap": 1.0, "delay": 4.0},
	]},
	{"name": "锈甲压境", "groups": [
		{"type": "brute", "n": 3, "gap": 1.8},
		{"type": "walker", "n": 8, "gap": 0.8, "delay": 3.0},
	]},
	{"name": "群翼蔽月", "groups": [
		{"type": "moth", "n": 14, "gap": 0.35},
		{"type": "brute", "n": 2, "gap": 2.0, "delay": 4.0},
	]},
	{"name": "孢雾蔓延", "groups": [
		{"type": "spore", "n": 1, "gap": 1.0},
		{"type": "walker", "n": 10, "gap": 0.7, "delay": 2.0},
		{"type": "moth", "n": 6, "gap": 0.45, "delay": 7.0},
	]},
	{"name": "重装推进", "groups": [
		{"type": "brute", "n": 6, "gap": 1.3},
		{"type": "walker", "n": 10, "gap": 0.6, "delay": 5.0},
	]},
	{"name": "暗翼狂潮", "groups": [
		{"type": "moth", "n": 18, "gap": 0.3},
		{"type": "brute", "n": 4, "gap": 1.6, "delay": 7.0},
	]},
	{"name": "腐殖之潮", "groups": [
		{"type": "spore", "n": 2, "gap": 3.0},
		{"type": "brute", "n": 6, "gap": 1.2, "delay": 2.0},
		{"type": "walker", "n": 10, "gap": 0.6, "delay": 7.0},
	]},
	{"name": "孢子围城", "groups": [
		{"type": "moth", "n": 20, "gap": 0.26},
		{"type": "spore", "n": 2, "gap": 4.0, "delay": 4.0},
		{"type": "brute", "n": 6, "gap": 1.2, "delay": 8.0},
	]},
	{"name": "铁苔洪流", "groups": [
		{"type": "brute", "n": 12, "gap": 0.8},
		{"type": "spore", "n": 2, "gap": 4.0, "delay": 5.0},
		{"type": "walker", "n": 12, "gap": 0.5, "delay": 9.0},
	]},
	{"name": "无光降临", "groups": [
		{"type": "boss", "n": 1, "gap": 1.0},
		{"type": "brute", "n": 6, "gap": 1.4, "delay": 5.0},
		{"type": "moth", "n": 14, "gap": 0.4, "delay": 8.0},
	]},
]


static func hp_scale(wave: int) -> float:
	return 1.0 + 0.10 * (wave - 1) + 0.005 * (wave - 1) * (wave - 1)


static func wave_composition(wave_idx: int) -> String:
	if wave_idx < 0 or wave_idx >= WAVES.size():
		return ""
	var parts: Array[String] = []
	for grp in WAVES[wave_idx]["groups"]:
		parts.append("%s×%d" % [ENEMIES[grp["type"]]["name"], grp["n"]])
	return " · ".join(parts)


static func count_wave_types(wave_idx: int) -> Dictionary:
	var res := {"walker": 0, "moth": 0, "brute": 0, "spore": 0, "boss": 0, "total": 0}
	if wave_idx < 0 or wave_idx >= WAVES.size():
		return res
	for g in WAVES[wave_idx]["groups"]:
		res[g["type"]] += g["n"]
		res["total"] += g["n"]
	return res


static func tower_stat_lines(type: String, level: int) -> Array[String]:
	var tdef: Dictionary = TOWERS[type]
	var lv: Dictionary = tdef["levels"][level]
	if type == "bolt":
		var next: int = tdef["upgrades"][level] if level < 2 else -1
		return [
			"伤害 %d · 射速 %.2f/s" % [lv["dmg"], lv["rate"]],
			"射程 %d%s" % [int(lv["range"]), (" · 升级 %d金" % next) if next > 0 else " · 已满级"],
		]
	if type == "flame":
		var next: int = tdef["upgrades"][level] if level < 2 else -1
		return [
			"伤害 %d · 溅射 %d" % [lv["dmg"], int(lv["splash"])],
			"射速 %.2f/s · 射程 %d%s" % [lv["rate"], int(lv["range"]), (" · 升 %d金" % next) if next > 0 else ""],
		]
	if type == "frost":
		var next: int = tdef["upgrades"][level] if level < 2 else -1
		return [
			"减速 %d%% · %.1fs" % [int(round(lv["slow"] * 100.0)), lv["slow_time"]],
			"伤害 %d · 射程 %d%s" % [lv["dmg"], int(lv["range"]), (" · 升 %d金" % next) if next > 0 else ""],
		]
	var next_inc: int = tdef["levels"][level + 1]["income"] if level < 2 else -1
	return ["每波 +%d 金" % lv["income"], ("升级后 +%d 金/波" % next_inc) if next_inc > 0 else "已满级"]


static func tower_range(type: String, level: int) -> float:
	if type == "mint":
		return 0.0
	return float(TOWERS[type]["levels"][level]["range"])
