class_name LegionData
extends RefCounted

# 所有局内数值与文案集中在这里：原创单位 / 塔 / 敌人 / 波次 / 肉鸽强化。
# 命名与外观均为净室原创，只复刻「塔防 + RTS + 每波三选一」的抽象机制。

const TITLE := "LEGIONFALL"
const TITLE_CN := "军团陨落"
const SUBTITLE := "余烬守望 · 三线裂隙"

# ---- 调色板 ---------------------------------------------------------------
const C_TEXT := Color("#efe6d4")
const C_DIM := Color("#8d8797")
const C_FAINT := Color("#5b5668")
const C_TEAL := Color("#5fe3cb")
const C_TEAL_DARK := Color("#1d6f66")
const C_GOLD := Color("#ffc65a")
const C_ESSENCE := Color("#86d9ff")
const C_EMBER := Color("#ff7f3f")
const C_ENEMY := Color("#c47bff")
const C_BLOOD := Color("#ff5f74")
const C_HEAL := Color("#72e39b")
const C_ICE := Color("#9fe8ff")
const C_PANEL := Color(0.052, 0.058, 0.082, 0.93)
const C_PANEL_2 := Color(0.075, 0.083, 0.112, 0.94)
const C_LINE := Color(0.36, 0.78, 0.72, 0.55)

# ---- 阵营 -----------------------------------------------------------------
const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

# ---- 玩家单位 -------------------------------------------------------------
const UNIT_ORDER := ["guard", "bolt", "adept"]

const UNITS := {
	"guard": {
		"name": "灰烬卫士", "role": "近战 · 前排", "icon": "sword",
		"cost": 55, "essence": 0, "pop": 1, "cooldown": 4.0,
		"hp": 170.0, "damage": 15.0, "range": 1.9, "interval": 0.95,
		"speed": 5.4, "aggro": 8.5, "radius": 0.55, "height": 1.85,
		"color": Color("#74b0a4"), "accent": Color("#9cffe8"),
		"desc": "持盾的余烬步兵，顶在最前面。",
	},
	"bolt": {
		"name": "余烬弩手", "role": "远程 · 单体", "icon": "bow",
		"cost": 75, "essence": 0, "pop": 1, "cooldown": 5.0,
		"hp": 105.0, "damage": 13.0, "range": 8.2, "interval": 1.15,
		"speed": 5.2, "aggro": 10.5, "radius": 0.5, "height": 1.75,
		"color": Color("#619fa8"), "accent": Color("#b0f4ff"),
		"desc": "自裂隙边缘征召的弩手，优先集火。",
	},
	"adept": {
		"name": "熔火术士", "role": "远程 · 溅射", "icon": "staff",
		"cost": 110, "essence": 5, "pop": 2, "cooldown": 8.0,
		"hp": 120.0, "damage": 27.0, "range": 7.0, "interval": 1.7,
		"speed": 4.6, "aggro": 10.0, "radius": 0.55, "height": 1.8,
		"splash": 2.6,
		"color": Color("#9b6375"), "accent": Color("#ffb47a"),
		"desc": "投掷熔渣火球，命中点 2.6m 溅射。",
	},
	"hero": {
		"name": "焰语者 · 凯尔", "role": "英雄 · 范围技", "icon": "flame",
		"cost": 0, "essence": 0, "pop": 0, "cooldown": 0.0,
		"hp": 540.0, "damage": 32.0, "range": 2.5, "interval": 0.85,
		"speed": 6.2, "aggro": 10.0, "radius": 0.72, "height": 2.25,
		"color": Color("#a05a7c"), "accent": Color("#ffdd92"),
		"desc": "队伍核心。Q：熔火震击，伤害并减速周围敌人。",
		"skill": {
			"name": "熔火震击", "radius": 9.0, "damage": 72.0,
			"slow": 0.5, "slow_time": 2.5, "cooldown": 20.0,
		},
	},
}

# ---- 敌人 -----------------------------------------------------------------
const ENEMY_ORDER := ["crawler", "spitter", "colossus"]

const ENEMIES := {
	"crawler": {
		"name": "裂爪兽", "role": "近战", "elite": false,
		"hp": 95.0, "damage": 9.0, "range": 1.9, "interval": 1.05,
		"speed": 4.6, "aggro": 6.8, "radius": 0.62, "height": 1.35,
		"gold": 6, "essence": 0,
		"color": Color("#7e5aa0"), "accent": Color("#e3a6ff"),
	},
	"spitter": {
		"name": "酸刺虫", "role": "远程", "elite": false,
		"hp": 82.0, "damage": 11.0, "range": 7.6, "interval": 1.8,
		"speed": 4.0, "aggro": 8.5, "radius": 0.55, "height": 1.25,
		"gold": 8, "essence": 1,
		"color": Color("#837398"), "accent": Color("#ccffa8"),
	},
	"colossus": {
		"name": "熔核巨像", "role": "精英", "elite": true,
		"hp": 950.0, "damage": 30.0, "range": 2.9, "interval": 1.5,
		"speed": 3.0, "aggro": 8.0, "radius": 1.25, "height": 2.9,
		"gold": 70, "essence": 18,
		"color": Color("#7a5a70"), "accent": Color("#ffa374"),
	},
}

# ---- 塔 -------------------------------------------------------------------
const TOWER_ORDER := ["prism", "mortar", "frost"]

const TOWERS := {
	"prism": {
		"name": "棱镜塔", "role": "单体 · 高频", "icon": "prism",
		"cost": 90, "essence": 8,
		"damage": 24.0, "range": 11.5, "interval": 0.75,
		"aoe": 0.0, "slow": 0.0, "slow_time": 0.0,
		"upgrade_gold": [0, 80, 130], "upgrade_essence": [0, 8, 14],
		"color": Color("#2c6666"), "accent": Color("#7ff5da"),
		"desc": "聚焦余烬光束，稳定点杀单个目标。",
	},
	"mortar": {
		"name": "熔渣炮台", "role": "范围 · 慢速", "icon": "mortar",
		"cost": 120, "essence": 14,
		"damage": 38.0, "range": 13.0, "interval": 2.0,
		"aoe": 3.4, "slow": 0.0, "slow_time": 0.0,
		"upgrade_gold": [0, 100, 150], "upgrade_essence": [0, 12, 18],
		"color": Color("#6b4530"), "accent": Color("#ff9a4f"),
		"desc": "抛射熔渣，命中点 3.4m 范围伤害。",
	},
	"frost": {
		"name": "暮霜图腾", "role": "减速 · 控场", "icon": "frost",
		"cost": 85, "essence": 18,
		"damage": 7.0, "range": 9.5, "interval": 1.2,
		"aoe": 0.0, "slow": 0.5, "slow_time": 2.0,
		"upgrade_gold": [0, 75, 120], "upgrade_essence": [0, 10, 16],
		"color": Color("#345a6b"), "accent": Color("#a8ecff"),
		"desc": "霜环脉冲，减速目标 50%，持续 2s。",
	},
}

const TOWER_MAX_LEVEL := 3
const TOWER_SELL_RATE := 0.6

# ---- 波次 -----------------------------------------------------------------
# portals: 0=北门 1=西门 2=东门。groups 里的 lane 可覆盖。
const WAVES := [
	{
		"name": "裂隙初响", "short": "第一波",
		"groups": [{"type": "crawler", "count": 7, "lane": 0}],
		"reward_gold": 60, "reward_essence": 6, "spacing": 0.8,
	},
	{
		"name": "虫群试探", "short": "第二波",
		"groups": [
			{"type": "crawler", "count": 9, "lane": 0},
			{"type": "crawler", "count": 4, "lane": 1},
		],
		"reward_gold": 75, "reward_essence": 8, "spacing": 0.7,
	},
	{
		"name": "酸刺来袭", "short": "第三波",
		"groups": [
			{"type": "crawler", "count": 8, "lane": 1},
			{"type": "spitter", "count": 4, "lane": 0},
		],
		"reward_gold": 90, "reward_essence": 10, "spacing": 0.65,
	},
	{
		"name": "双线夹击", "short": "第四波",
		"groups": [
			{"type": "crawler", "count": 8, "lane": 1},
			{"type": "crawler", "count": 8, "lane": 2},
			{"type": "spitter", "count": 4, "lane": 0},
		],
		"reward_gold": 110, "reward_essence": 12, "spacing": 0.6,
	},
	{
		"name": "精英先遣", "short": "第五波",
		"groups": [
			{"type": "crawler", "count": 10, "lane": 0},
			{"type": "spitter", "count": 6, "lane": 1},
			{"type": "colossus", "count": 1, "lane": 2},
		],
		"reward_gold": 145, "reward_essence": 18, "spacing": 0.6,
	},
	{
		"name": "熔核降临", "short": "终波",
		"groups": [
			{"type": "colossus", "count": 2, "lane": 1},
			{"type": "crawler", "count": 12, "lane": 0},
			{"type": "spitter", "count": 6, "lane": 2},
		],
		"reward_gold": 0, "reward_essence": 0, "spacing": 0.55,
	},
]

# 波次修饰：seed 决定，允许同波多入口。
const MODIFIERS := [
	{"id": "none", "name": "常规攻势", "desc": "无额外修饰", "hp": 1.0, "speed": 1.0, "damage": 1.0, "count": 1.0, "gold": 1.0, "extra_lane": false},
	{"id": "elite", "name": "精英潮", "desc": "敌人生命 +35%，金币 +25%", "hp": 1.35, "speed": 1.0, "damage": 1.1, "count": 1.0, "gold": 1.25, "extra_lane": false},
	{"id": "swift", "name": "疾行虫群", "desc": "敌人移速 +30%", "hp": 1.0, "speed": 1.3, "damage": 1.05, "count": 1.0, "gold": 1.0, "extra_lane": false},
	{"id": "swarm", "name": "虫群增殖", "desc": "数量 +50%，生命 -20%", "hp": 0.8, "speed": 1.05, "damage": 1.0, "count": 1.5, "gold": 1.0, "extra_lane": false},
	{"id": "twoline", "name": "双线进攻", "desc": "额外入口增援 50%", "hp": 1.0, "speed": 1.0, "damage": 1.0, "count": 1.0, "gold": 1.1, "extra_lane": true},
	{"id": "frenzy", "name": "嗜血", "desc": "敌人伤害 +35%", "hp": 1.0, "speed": 1.05, "damage": 1.35, "count": 1.0, "gold": 1.05, "extra_lane": false},
]

# ---- 肉鸽强化 -------------------------------------------------------------
const UPGRADE_POOL := [
	{"id": "train", "name": "军团训练", "max": 3, "icon": "sword", "color": "#5fe3cb",
		"desc": "所有单位伤害 +18%", "detail": "训练 II 起叠乘，最多 3 级"},
	{"id": "vigor", "name": "坚韧战团", "max": 3, "icon": "shield", "color": "#72e39b",
		"desc": "单位最大生命 +18%", "detail": "立即补足新增生命值"},
	{"id": "haste", "name": "疾行军令", "max": 2, "icon": "boot", "color": "#86d9ff",
		"desc": "单位移动速度 +12%", "detail": "更快的包抄与回防"},
	{"id": "range", "name": "高地射程", "max": 3, "icon": "tower", "color": "#9fe8ff",
		"desc": "塔射程 +15%", "detail": "所有已建塔与新建塔生效"},
	{"id": "slag", "name": "熔渣回收", "max": 3, "icon": "gear", "color": "#ff9a4f",
		"desc": "塔伤害 +22%", "detail": "棱镜塔单发收益最高"},
	{"id": "tax", "name": "岛屿税收", "max": 3, "icon": "coin", "color": "#ffc65a",
		"desc": "波次金币奖励 +30%", "detail": "立即结算下一次清波奖励"},
	{"id": "essence", "name": "精粹涌动", "max": 3, "icon": "crystal", "color": "#c47bff",
		"desc": "每次击杀额外 +1 精粹", "detail": "精英仍然掉落额外精粹"},
	{"id": "hero", "name": "英雄共鸣", "max": 3, "icon": "flame", "color": "#ff9bb0",
		"desc": "英雄技能冷却 -20%", "detail": "Q 熔火震击来得更频繁"},
	{"id": "frost", "name": "暮霜附魔", "max": 2, "icon": "snow", "color": "#a8ecff",
		"desc": "所有塔命中附带减速", "detail": "每级 20% 减速，持续 1.2s"},
	{"id": "pop", "name": "扩编令", "max": 2, "icon": "banner", "color": "#5fe3cb",
		"desc": "人口上限 +4", "detail": "立刻可招募更多军团"},
]

# ---- 局内常量 -------------------------------------------------------------
const START_GOLD := 300
const START_ESSENCE := 36
const START_POP_CAP := 12
const CORE_HP := 100
const PREP_TIME := 10.0
const FIRST_PREP_TIME := 14.0
const HERO_RESPAWN := 24.0
const UNIT_CAP_HARD := 28

# ---- 工具函数 -------------------------------------------------------------
static func unit_def(kind: String) -> Dictionary:
	return UNITS.get(kind, UNITS["guard"])

static func enemy_def(kind: String) -> Dictionary:
	return ENEMIES.get(kind, ENEMIES["crawler"])

static func tower_def(kind: String) -> Dictionary:
	return TOWERS.get(kind, TOWERS["prism"])

static func wave_def(index: int) -> Dictionary:
	return WAVES[clampi(index, 0, WAVES.size() - 1)]

static func upgrade_def(id: String) -> Dictionary:
	for u in UPGRADE_POOL:
		if u.id == id:
			return u
	return {}

static func color(hex: String) -> Color:
	return Color(hex)
