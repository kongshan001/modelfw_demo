class_name DollData
extends RefCounted

# 纸偶工坊的数据核心：17 个槽位、变体、配色、8 方向、4 动作、预设与序列化。
# 所有美术都由 PartPainter 程序化绘制，本文件只描述“穿什么”，不加载任何外部图片。

const SLOTS := [
	{
		"id": "aura", "label": "气场", "z": 0, "color_set": "aura",
		"default": "none", "default_color": "#f2b34c",
		"variants": [
			{"id": "none", "label": "无"},
			{"id": "spark", "label": "星屑"},
			{"id": "leaf", "label": "旋叶"},
			{"id": "flame", "label": "火苗"},
			{"id": "bubble", "label": "泡泡"},
			{"id": "halo", "label": "光环"},
		],
	},
	{
		"id": "cape", "label": "披风", "z": 10, "color_set": "cloth",
		"default": "none", "default_color": "#4fa58a",
		"variants": [
			{"id": "none", "label": "无"},
			{"id": "short", "label": "短披风"},
			{"id": "long", "label": "长披风"},
			{"id": "scarf", "label": "围巾"},
		],
	},
	{
		"id": "backpack", "label": "背饰", "z": 15, "color_set": "leather",
		"default": "none", "default_color": "#b07a4a",
		"variants": [
			{"id": "none", "label": "无"},
			{"id": "satchel", "label": "邮差包"},
			{"id": "shell", "label": "龟壳"},
			{"id": "wings", "label": "小翅膀"},
			{"id": "lantern", "label": "小灯笼"},
		],
	},
	{
		"id": "body", "label": "木偶身", "z": 20, "color_set": "wood",
		"default": "plain", "default_color": "#d9a86c",
		"variants": [
			{"id": "plain", "label": "原木"},
			{"id": "grain", "label": "年轮"},
			{"id": "patch", "label": "补丁"},
			{"id": "rivet", "label": "铆钉"},
		],
	},
	{
		"id": "pants", "label": "下装", "z": 30, "color_set": "cloth",
		"default": "trousers", "default_color": "#5a7fb8",
		"variants": [
			{"id": "shorts", "label": "短裤"},
			{"id": "trousers", "label": "长裤"},
			{"id": "skirt", "label": "小裙"},
			{"id": "leggings", "label": "贴身裤"},
		],
	},
	{
		"id": "shoes", "label": "鞋履", "z": 35, "color_set": "leather",
		"default": "boots", "default_color": "#8a5a3a",
		"variants": [
			{"id": "boots", "label": "皮靴"},
			{"id": "sneakers", "label": "软底鞋"},
			{"id": "clogs", "label": "木屐"},
			{"id": "bare", "label": "光脚"},
		],
	},
	{
		"id": "shirt", "label": "上衣", "z": 40, "color_set": "cloth",
		"default": "tunic", "default_color": "#e86a5c",
		"variants": [
			{"id": "tunic", "label": "罩衫"},
			{"id": "hoodie", "label": "连帽衫"},
			{"id": "vest", "label": "马甲"},
			{"id": "armor", "label": "护甲"},
			{"id": "dress", "label": "连衣裙"},
		],
	},
	{
		"id": "belt", "label": "腰带", "z": 45, "color_set": "leather",
		"default": "none", "default_color": "#b07a4a",
		"variants": [
			{"id": "none", "label": "无"},
			{"id": "rope", "label": "麻绳"},
			{"id": "sash", "label": "布带"},
			{"id": "pouch", "label": "工具带"},
		],
	},
	{
		"id": "head", "label": "头", "z": 50, "color_set": "wood",
		"default": "round", "default_color": "#d9a86c",
		"variants": [
			{"id": "round", "label": "圆木"},
			{"id": "square", "label": "方木"},
			{"id": "acorn", "label": "橡果"},
			{"id": "pebble", "label": "卵石"},
		],
	},
	{
		"id": "ear", "label": "耳朵", "z": 52, "color_set": "wood",
		"default": "none", "default_color": "#c08b56",
		"variants": [
			{"id": "none", "label": "无"},
			{"id": "round", "label": "圆耳"},
			{"id": "pointy", "label": "尖耳"},
			{"id": "horn", "label": "小角"},
			{"id": "antenna", "label": "触角"},
		],
	},
	{
		"id": "mask", "label": "面具", "z": 54, "color_set": "mask",
		"default": "none", "default_color": "#f3ead7",
		"variants": [
			{"id": "none", "label": "无"},
			{"id": "fox", "label": "狐面"},
			{"id": "owl", "label": "枭环"},
			{"id": "bandit", "label": "蒙面"},
			{"id": "specs", "label": "圆眼镜"},
		],
	},
	{
		"id": "eyes", "label": "眼睛", "z": 55, "color_set": "eye",
		"default": "dot", "default_color": "#33283f",
		"variants": [
			{"id": "dot", "label": "豆豆眼"},
			{"id": "happy", "label": "弯弯眼"},
			{"id": "fierce", "label": "锐利眼"},
			{"id": "sleepy", "label": "困困眼"},
			{"id": "sparkle", "label": "星星眼"},
			{"id": "visor", "label": "单片镜"},
		],
	},
	{
		"id": "hair", "label": "发型", "z": 60, "color_set": "hair",
		"default": "short", "default_color": "#7a5236",
		"variants": [
			{"id": "short", "label": "短毛"},
			{"id": "mess", "label": "乱毛"},
			{"id": "bob", "label": "波波头"},
			{"id": "bun", "label": "双丸子"},
			{"id": "long", "label": "长直发"},
			{"id": "spiky", "label": "刺猬头"},
		],
	},
	{
		"id": "hat", "label": "帽子", "z": 65, "color_set": "cloth",
		"default": "none", "default_color": "#4fa58a",
		"variants": [
			{"id": "none", "label": "无"},
			{"id": "beanie", "label": "毛线帽"},
			{"id": "acorn", "label": "橡果帽"},
			{"id": "wizard", "label": "尖顶帽"},
			{"id": "crown", "label": "小皇冠"},
			{"id": "leaf", "label": "叶子帽"},
		],
	},
	{
		"id": "gloves", "label": "手套", "z": 73, "color_set": "leather",
		"default": "none", "default_color": "#b07a4a",
		"variants": [
			{"id": "none", "label": "无"},
			{"id": "mittens", "label": "棉手套"},
			{"id": "bracers", "label": "护腕"},
			{"id": "claws", "label": "小爪"},
		],
	},
	{
		"id": "weapon", "label": "武器", "z": 71, "color_set": "wood",
		"default": "sword", "default_color": "#b07a4a",
		"variants": [
			{"id": "none", "label": "空手"},
			{"id": "sword", "label": "木剑"},
			{"id": "hammer", "label": "小锤"},
			{"id": "staff", "label": "长杖"},
			{"id": "fan", "label": "蒲扇"},
			{"id": "spoon", "label": "木勺"},
		],
	},
	{
		"id": "accessory", "label": "挂饰", "z": 80, "color_set": "metal",
		"default": "none", "default_color": "#e0c27a",
		"variants": [
			{"id": "none", "label": "无"},
			{"id": "bell", "label": "铃铛"},
			{"id": "pendant", "label": "星坠"},
			{"id": "badge", "label": "叶徽"},
			{"id": "charm", "label": "漂浮符"},
		],
	},
]

const COLOR_SETS := {
	"wood": ["#d9a86c", "#c08b56", "#e8c79b", "#9a653f", "#f1ddc0", "#7d5236", "#b9784f", "#6a4730"],
	"hair": ["#4a3427", "#7a5236", "#b78252", "#e0b98a", "#2f2a36", "#c95f5f", "#5d7fb5", "#8a6fb0"],
	"cloth": ["#e86a5c", "#f2b34c", "#4fa58a", "#5a7fb8", "#8a6fb0", "#e88fae", "#f3ead7", "#45505e"],
	"eye": ["#33283f", "#5b4636", "#2f7e78", "#c47a2c", "#3c63a8", "#a65151", "#6f4a8a", "#f2e8d6"],
	"leather": ["#8a5a3a", "#b07a4a", "#5f4232", "#d1a06a", "#f0d9b8", "#4a4a55", "#7c6a58", "#a34d4d"],
	"metal": ["#b9c0c8", "#e0c27a", "#c98a5b", "#7d8794", "#f2eadf", "#5e6670", "#8fb3a8", "#b58a9e"],
	"aura": ["#f2b34c", "#4fa58a", "#e86a5c", "#8a6fb0", "#6fa8d8", "#e88fae", "#f3ead7", "#9ad17c"],
	"mask": ["#f3ead7", "#e8c79b", "#4a3a4f", "#e86a5c", "#4fa58a", "#f2b34c", "#5a7fb8", "#8a6fb0"],
}

# 面向约定：美术一律按“朝右”绘制，左侧方向通过节点水平镜像实现。
# 评审 P0-4：yaw 正 0.0 / 斜 0.55（原 0.78）/ 侧 1.0，让正、斜、侧三档剪影真正分开。
const DIRS := [
	{"id": "down", "label": "↓", "name": "下", "yaw": 0.0, "back": false, "flip": false},
	{"id": "down_left", "label": "↙", "name": "左下", "yaw": 0.55, "back": false, "flip": true},
	{"id": "left", "label": "←", "name": "左", "yaw": 1.0, "back": false, "flip": true},
	{"id": "up_left", "label": "↖", "name": "左上", "yaw": 0.55, "back": true, "flip": true},
	{"id": "up", "label": "↑", "name": "上", "yaw": 0.0, "back": true, "flip": false},
	{"id": "up_right", "label": "↗", "name": "右上", "yaw": 0.55, "back": true, "flip": false},
	{"id": "right", "label": "→", "name": "右", "yaw": 1.0, "back": false, "flip": false},
	{"id": "down_right", "label": "↘", "name": "右下", "yaw": 0.55, "back": false, "flip": false},
]

const ACTIONS := [
	{"id": "idle", "label": "待机", "hint": "呼吸 / 摆臂"},
	{"id": "walk", "label": "行走", "hint": "四拍步态"},
	{"id": "attack", "label": "挥击", "hint": "蓄力 / 挥砍 / 收势"},
	{"id": "hit", "label": "受击", "hint": "后仰 / 抖动 / 回正"},
]

const PRESET_PATH := "res://presets/lineup_16.json"


static func slot_by_id(slot_id: String) -> Dictionary:
	for slot in SLOTS:
		if slot["id"] == slot_id:
			return slot
	return {}


static func variant_by_id(slot_id: String, variant_id: String) -> Dictionary:
	var slot := slot_by_id(slot_id)
	if slot.is_empty():
		return {}
	for variant in slot["variants"]:
		if variant["id"] == variant_id:
			return variant
	return {}


static func palette_for(slot_id: String) -> Array:
	var slot := slot_by_id(slot_id)
	if slot.is_empty():
		return []
	var out: Array = []
	for hex in COLOR_SETS.get(slot["color_set"], []):
		out.append(Color(hex))
	return out


static func dir_by_id(dir_id: String) -> int:
	for i in DIRS.size():
		if DIRS[i]["id"] == dir_id:
			return i
	return 0


static func showcase_time(index: int, action: String) -> float:
	# 阵容卡/剪影展示用的定格相位：攻击取挥砍中段，行走取触地，待机按序号错开。
	match action:
		"attack":
			return 0.52
		"walk":
			return 0.205
		_:
			return 0.31 * float(index)


static func is_action(action_id: String) -> bool:
	for action in ACTIONS:
		if action["id"] == action_id:
			return true
	return false


static func action_label(action_id: String) -> String:
	for action in ACTIONS:
		if action["id"] == action_id:
			return action["label"]
	return action_id


static func combination_count() -> float:
	var total := 1.0
	for slot in SLOTS:
		total *= float(slot["variants"].size() * palette_for(slot["id"]).size())
	return total


static func combination_text() -> String:
	var total := combination_count()
	var exponent := int(floor(log(total) / log(10.0)))
	var mantissa := total / pow(10.0, exponent)
	return "≈ %.1f×10%s 种外观" % [mantissa, _superscript(exponent)]


static func _superscript(value: int) -> String:
	const DIGITS := ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
	var text := str(value)
	var out := ""
	for i in text.length():
		out += DIGITS[int(text[i])]
	return out


static func default_outfit() -> Dictionary:
	var outfit := {}
	for slot in SLOTS:
		outfit[slot["id"]] = {
			"variant": slot["default"],
			"color": Color(slot["default_color"]),
		}
	return outfit


# 评审 P1-4：先选 8 套 outfit scheme，再分配 primary/secondary/accent/neutral；
# 面积 60/30/10，高饱和色 ≤2，禁止“帽子/披风/裤/鞋各一个随机高饱和色”。
const OUTFIT_SCHEMES := [
	{"primary": "#4fa58a", "secondary": "#45505e", "accent": "#f2b34c"}, # 苔藓
	{"primary": "#e86a5c", "secondary": "#8a6fb0", "accent": "#f2b34c"}, # 余烬
	{"primary": "#5a7fb8", "secondary": "#f3ead7", "accent": "#f2b34c"}, # 云朵
	{"primary": "#e88fae", "secondary": "#4fa58a", "accent": "#f3ead7"}, # 铃兰
	{"primary": "#f2b34c", "secondary": "#4fa58a", "accent": "#c95f5f"}, # 麦田
	{"primary": "#8a6fb0", "secondary": "#5a7fb8", "accent": "#f2b34c"}, # 星夜
	{"primary": "#c95f5f", "secondary": "#45505e", "accent": "#f2b34c"}, # 铁锈
	{"primary": "#6fa8d8", "secondary": "#f3ead7", "accent": "#8a6fb0"}, # 霜糖
]


static func random_outfit(rng: RandomNumberGenerator) -> Dictionary:
	var scheme: Dictionary = OUTFIT_SCHEMES[rng.randi_range(0, OUTFIT_SCHEMES.size() - 1)]
	var primary := Color(scheme["primary"])
	var secondary := Color(scheme["secondary"])
	var accent := Color(scheme["accent"])
	var flip := rng.randf() < 0.5
	var major := secondary if flip else primary
	var minor := primary if flip else secondary
	var outfit := {}
	for slot in SLOTS:
		var slot_id: String = slot["id"]
		var palette := palette_for(slot_id)
		var color: Color = palette[rng.randi_range(0, palette.size() - 1)]
		var variant_id := _random_variant_id(slot, rng)
		match slot_id:
			"shirt":
				color = major
			"pants":
				color = minor if rng.randf() < 0.68 else major
			"cape":
				color = minor
			"hat":
				color = major if rng.randf() < 0.5 else minor
			"belt":
				color = accent if rng.randf() < 0.72 else palette[0]
			"accessory":
				color = accent if rng.randf() < 0.68 else palette[1]
			"backpack":
				color = primary if rng.randf() < 0.35 else palette[0]
			"weapon":
				color = palette[rng.randi_range(0, mini(2, palette.size() - 1))]
			"aura":
				color = accent if rng.randf() < 0.6 else minor
			"hair":
				color = palette[rng.randi_range(0, 4)]
			"eyes":
				color = palette[rng.randi_range(0, 4)]
			"body", "head":
				color = palette[rng.randi_range(0, 2)]
			"ear":
				color = palette[rng.randi_range(0, 2)]
			"shoes", "gloves":
				color = palette[rng.randi_range(0, 3)]
			"mask":
				color = palette[0] if rng.randf() < 0.6 else palette[2]
		outfit[slot_id] = {"variant": variant_id, "color": color}
	return outfit


static func _random_variant_id(slot: Dictionary, rng: RandomNumberGenerator) -> String:
	var variants: Array = slot["variants"]
	var slot_id: String = slot["id"]
	# 剪影预算：随机器也要保证大多数角色有帽子/破形件与可见武器。
	var none_chance := 0.0
	match slot_id:
		"hat":
			none_chance = 0.15
		"weapon":
			none_chance = 0.20
		"cape":
			none_chance = 0.45
		"backpack":
			none_chance = 0.55
		"aura":
			none_chance = 0.55
		"accessory":
			none_chance = 0.50
		"ear":
			none_chance = 0.30
		"mask":
			none_chance = 0.70
		"belt":
			none_chance = 0.35
		"gloves":
			none_chance = 0.50
	if none_chance > 0.0 and rng.randf() < none_chance:
		return "none"
	var candidates: Array = []
	for variant in variants:
		if str(variant["id"]) != "none":
			candidates.append(variant["id"])
	if candidates.is_empty():
		return "none"
	return String(candidates[rng.randi_range(0, candidates.size() - 1)])


static func parse_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	var text := str(value).strip_edges()
	if text.begins_with("#"):
		text = text.substr(1)
	if text.length() != 6:
		return fallback
	for i in text.length():
		if "0123456789abcdefABCDEF".find(text[i]) < 0:
			return fallback
	return Color.html("#" + text)


static func normalize_outfit(source: Variant) -> Dictionary:
	var outfit := {}
	for slot in SLOTS:
		var slot_id: String = slot["id"]
		var chosen_variant := String(slot["default"])
		var chosen_color := Color(slot["default_color"])
		if source is Dictionary and source.has(slot_id):
			var entry: Variant = source[slot_id]
			if entry is Dictionary:
				var variant_id := str(entry.get("variant", ""))
				if not variant_by_id(slot_id, variant_id).is_empty():
					chosen_variant = variant_id
				chosen_color = parse_color(entry.get("color", chosen_color.to_html(false)), chosen_color)
			elif entry is String and not variant_by_id(slot_id, entry).is_empty():
				chosen_variant = entry
		outfit[slot_id] = {"variant": chosen_variant, "color": chosen_color}
	return outfit


static func outfit_signature(outfit: Dictionary) -> String:
	var normalized := normalize_outfit(outfit)
	var parts: Array[String] = []
	for slot in SLOTS:
		var entry: Dictionary = normalized[slot["id"]]
		parts.append("%s:%s:%s" % [
			slot["id"], str(entry["variant"]),
			(entry["color"] as Color).to_html(false),
		])
	return "|".join(parts)


static func encode_outfit(outfit: Dictionary) -> Dictionary:
	var out := {}
	for slot in SLOTS:
		var slot_id: String = slot["id"]
		var entry: Dictionary = outfit.get(slot_id, {})
		out[slot_id] = {
			"variant": str(entry.get("variant", slot["default"])),
			"color": parse_color(entry.get("color", slot["default_color"]), Color(slot["default_color"])).to_html(false),
		}
	return out


static func z_bonus(slot_id: String, dir_index: int, variant_id: String) -> int:
	if variant_id == "none":
		return 0
	var back: bool = DIRS[clampi(dir_index, 0, 7)]["back"]
	match slot_id:
		"cape":
			if back:
				return 54
			if variant_id == "scarf":
				return 36
		"backpack":
			if back:
				return 47
		"weapon":
			if back:
				return -60
	return 0


static func draw_order(dir_index: int, outfit: Dictionary) -> Array:
	var entries: Array = []
	for i in SLOTS.size():
		var slot: Dictionary = SLOTS[i]
		var slot_id: String = slot["id"]
		var variant_id := str(outfit.get(slot_id, {}).get("variant", slot["default"]))
		entries.append({
			"id": slot_id,
			"index": i,
			"z": int(slot["z"]) + z_bonus(slot_id, dir_index, variant_id),
		})
	entries.sort_custom(func(a, b):
		if a["z"] == b["z"]:
			return a["index"] < b["index"]
		return a["z"] < b["z"]
	)
	return entries


static func load_lineup(path := PRESET_PATH) -> Array:
	var roles: Array = []
	if not FileAccess.file_exists(path):
		push_warning("preset file missing: " + path)
		return roles
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("cannot open preset file: " + path)
		return roles
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("preset file is not a JSON object")
		return roles
	var raw_roles: Variant = parsed.get("roles", [])
	if not raw_roles is Array:
		return roles
	for i in raw_roles.size():
		if not raw_roles[i] is Dictionary:
			continue
		var raw: Dictionary = raw_roles[i]
		var action := str(raw.get("action", "idle"))
		if not is_action(action):
			action = "idle"
		roles.append({
			"name": str(raw.get("name", "纸偶 %02d" % (i + 1))),
			"direction": dir_by_id(str(raw.get("direction", "down"))),
			"action": action,
			"outfit": normalize_outfit(raw.get("outfit", {})),
		})
	return roles


static func save_doll(path: String, outfit: Dictionary, direction: int, action: String, doll_name := "我的纸偶") -> bool:
	var data := {
		"format": "paperdoll.outfit/1",
		"name": doll_name,
		"direction": DIRS[clampi(direction, 0, 7)]["id"],
		"action": action if is_action(action) else "idle",
		"outfit": encode_outfit(outfit),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


static func load_doll(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	var action := str(data.get("action", "idle"))
	if not is_action(action):
		action = "idle"
	return {
		"name": str(data.get("name", "我的纸偶")),
		"direction": dir_by_id(str(data.get("direction", "down"))),
		"action": action,
		"outfit": normalize_outfit(data.get("outfit", {})),
	}


# 预设缺失时的兜底：使用确定性随机，保证 16 人阵容与截图工具永远有内容。
static func fallback_lineup() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	var roles: Array = []
	for i in 16:
		roles.append({
			"name": "纸偶 %02d" % (i + 1),
			"direction": i % 8,
			"action": "idle" if i % 5 != 0 else "walk",
			"outfit": random_outfit(rng),
		})
	return roles
