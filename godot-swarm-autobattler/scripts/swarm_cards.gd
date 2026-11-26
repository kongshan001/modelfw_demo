class_name SwarmCards
extends RefCounted

## 原创单位表：微型铸造蜂群。每张卡是一个“编队模板”，战斗时展开为
## squad 个独立单位；金卡（★2）数值与单位数都 ×2。
## 数值都是“每个单位”的数值，不是整队数值。

const SHOP_SIZE := 5
const BOARD_MAX := 7
const MAX_LEVEL := 6
const MAX_GREED := 5
const UNIT_CAP_PER_SIDE := 1500
const FLOOD_MULT := 100.0

const TIER_NAMES := ["", "灰烬", "微光", "棱镜", "熔核", "潮心"]
const TIER_COLORS := [
	Color("#5d7386"),
	Color("#7b8ea0"),
	Color("#52b7c9"),
	Color("#8f7ae6"),
	Color("#e08b5a"),
	Color("#f0c15a"),
]

const CARD_LIST := [
	{
		"id": "spark_flea", "name": "火花蚤", "tier": 1, "cost": 3, "squad": 3,
		"hp": 12.0, "atk": 4.0, "aspd": 1.6, "range": 14.0, "speed": 42.0,
		"tank": false, "support": false, "splash": 0.0,
		"desc": "最便宜的突击群。数量就是护甲，适合在洪流里填满战线。",
	},
	{
		"id": "rivet_grub", "name": "铆钉虫", "tier": 1, "cost": 3, "squad": 2,
		"hp": 34.0, "atk": 3.0, "aspd": 0.85, "range": 14.0, "speed": 30.0,
		"tank": true, "support": false, "splash": 0.0,
		"desc": "重型铆接甲虫。缓慢、耐打，负责把敌人黏在前线。",
	},
	{
		"id": "prism_gadfly", "name": "棱镜虻", "tier": 2, "cost": 4, "squad": 2,
		"hp": 11.0, "atk": 7.0, "aspd": 1.1, "range": 90.0, "speed": 34.0,
		"tank": false, "support": false, "splash": 0.0,
		"desc": "折射光束的轻量射手。脆，但能在前线后方持续输出。",
	},
	{
		"id": "magwire_mantis", "name": "磁线螳", "tier": 2, "cost": 4, "squad": 2,
		"hp": 20.0, "atk": 8.0, "aspd": 1.5, "range": 16.0, "speed": 46.0,
		"tank": false, "support": false, "splash": 0.0,
		"desc": "磁轨镰足。高速近战，专切敌方远程编队。",
	},
	{
		"id": "arc_ant", "name": "电弧蚁", "tier": 3, "cost": 5, "squad": 3,
		"hp": 14.0, "atk": 6.0, "aspd": 1.9, "range": 78.0, "speed": 38.0,
		"tank": false, "support": false, "splash": 0.0,
		"desc": "快速放电的小型射手。单发伤害不高，胜在攻击频率。",
	},
	{
		"id": "spore_ballista", "name": "孢弩台", "tier": 3, "cost": 5, "squad": 2,
		"hp": 26.0, "atk": 16.0, "aspd": 0.55, "range": 130.0, "speed": 26.0,
		"tank": false, "support": false, "splash": 0.0,
		"desc": "沉重的孢子弩。射程最远的常规单位，换弹很慢。",
	},
	{
		"id": "weave_moth", "name": "织焰蛾", "tier": 4, "cost": 6, "squad": 2,
		"hp": 20.0, "atk": 5.0, "aspd": 1.0, "range": 95.0, "speed": 34.0,
		"tank": false, "support": true, "splash": 0.0,
		"desc": "只要还有一只存活，全场友军攻击速度 +15%。编队越大，光环越值。",
	},
	{
		"id": "molten_weaver", "name": "熔核蛛", "tier": 4, "cost": 6, "squad": 2,
		"hp": 30.0, "atk": 9.0, "aspd": 0.8, "range": 110.0, "speed": 32.0,
		"tank": false, "support": false, "splash": 28.0,
		"desc": "熔滴抛射器。攻击命中后对 28 像素内最多 4 个敌人造成 50% 溅射。",
	},
	{
		"id": "crown_colossus", "name": "冠熔巨像", "tier": 5, "cost": 7, "squad": 3,
		"hp": 120.0, "atk": 20.0, "aspd": 0.7, "range": 18.0, "speed": 24.0,
		"tank": true, "support": false, "splash": 0.0,
		"desc": "核心重装。极慢、极硬，负责为后方编队撑出空间。",
	},
	{
		"id": "tideheart_engine", "name": "潮心机核", "tier": 5, "cost": 7, "squad": 2,
		"hp": 75.0, "atk": 26.0, "aspd": 0.9, "range": 135.0, "speed": 28.0,
		"tank": false, "support": false, "splash": 0.0,
		"desc": "核心远程。单发最高的潮汐炮，射程覆盖半个战场。",
	},
]

## 商店等级 2..6 的各阶出现权重。索引 0 对应 T1。
const SHOP_ODDS := {
	2: [80, 20, 0, 0, 0],
	3: [60, 30, 10, 0, 0],
	4: [45, 33, 18, 4, 0],
	5: [30, 30, 25, 12, 3],
	6: [22, 26, 28, 16, 8],
}
const LEVEL_COST := {2: 5, 3: 7, 4: 9, 5: 11}


static func get_card(id: String) -> Dictionary:
	for card in CARD_LIST:
		if card["id"] == id:
			return card
	return {}


static func all_ids() -> Array:
	var out := []
	for card in CARD_LIST:
		out.append(card["id"])
	return out


static func ids_for_tier(tier: int) -> Array:
	var out := []
	for card in CARD_LIST:
		if int(card["tier"]) == tier:
			out.append(card["id"])
	return out


static func role_label(card: Dictionary) -> String:
	if card.is_empty():
		return ""
	if bool(card.get("support", false)):
		return "支援"
	if float(card.get("splash", 0.0)) > 0.0:
		return "溅射"
	if bool(card.get("tank", false)):
		return "重甲"
	if float(card.get("range", 0.0)) > 40.0:
		return "远程"
	return "近战"


static func star_squad_mult(star: int) -> float:
	return 2.0 if star >= 2 else 1.0


static func star_stat_mult(star: int) -> float:
	return 2.0 if star >= 2 else 1.0


static func sell_value(card_entry: Dictionary) -> int:
	var card := get_card(String(card_entry.get("id", "")))
	if card.is_empty():
		return 0
	var mult := 3 if int(card_entry.get("star", 1)) >= 2 else 1
	return int(card["cost"]) * mult


## 把一整个编队按比例压进每边单位上限。返回与 cards 等长的整数数组。
## greed_mult 是贪婪潮造成的单位倍率（友军与敌军不同）。
static func allocate_units(cards: Array, greed_mult: float, flood: bool, cap: int, scale_override: float = 1.0) -> Array:
	var desired: Array[float] = []
	var total := 0.0
	for entry in cards:
		var card := get_card(String(entry.get("id", "")))
		if card.is_empty():
			desired.append(0.0)
			continue
		var n := float(card["squad"])
		n *= star_squad_mult(int(entry.get("star", 1)))
		n *= greed_mult
		n *= scale_override
		if flood:
			n *= FLOOD_MULT
		n = maxf(1.0, n)
		desired.append(n)
		total += n
	var out: Array = []
	if cards.is_empty():
		return out
	if total <= float(cap):
		for n in desired:
			out.append(maxi(1, int(round(n))))
		return out
	var factor := float(cap) / total
	var sum := 0
	for n in desired:
		var v := maxi(1, int(floor(n * factor)))
		out.append(v)
		sum += v
	# 把超出的部分从最大的编队里扣回，保证总数不超过 cap。
	var guard := 0
	while sum > cap and guard < 200:
		var max_i := 0
		for i in range(1, out.size()):
			if out[i] > out[max_i]:
				max_i = i
		if out[max_i] <= 1:
			break
		out[max_i] -= 1
		sum -= 1
		guard += 1
	# 把 floor 丢掉的零头补回，让满编时精确命中上限。
	var leftover := cap - sum
	if leftover > 0 and not out.is_empty():
		var order: Array[int] = []
		for i in out.size():
			order.append(i)
		for i in range(1, order.size()):
			var key := order[i]
			var j := i - 1
			while j >= 0 and desired[order[j]] < desired[key]:
				order[j + 1] = order[j]
				j -= 1
			order[j + 1] = key
		var oi := 0
		while leftover > 0:
			out[order[oi % order.size()]] += 1
			leftover -= 1
			oi += 1
	return out


static func squad_total(cards: Array, greed_mult: float, flood: bool, cap: int, scale_override: float = 1.0) -> int:
	var counts := allocate_units(cards, greed_mult, flood, cap, scale_override)
	var total := 0
	for n in counts:
		total += int(n)
	return total


static func level_cost(level: int) -> int:
	return int(LEVEL_COST.get(level, -1))


static func shop_odds(level: int) -> Array:
	return SHOP_ODDS.get(clampi(level, 2, MAX_LEVEL), [80, 20, 0, 0, 0])


static func roll_shop(rng: RandomNumberGenerator, level: int, size: int = SHOP_SIZE) -> Array:
	var odds: Array = shop_odds(level)
	var total_weight := 0
	for w in odds:
		total_weight += int(w)
	var out: Array = []
	for i in size:
		var pick := rng.randi_range(1, maxi(1, total_weight))
		var tier := 1
		var acc := 0
		for t in range(5):
			acc += int(odds[t])
			if pick <= acc:
				tier = t + 1
				break
		var pool := ids_for_tier(tier)
		if pool.is_empty():
			pool = ids_for_tier(1)
		out.append(pool[rng.randi_range(0, pool.size() - 1)])
	return out


static func roll_ai_roster(rng: RandomNumberGenerator, round_no: int) -> Array:
	var level := clampi(2 + int(round_no / 2), 2, MAX_LEVEL)
	var count := clampi(2 + int((round_no + 1) / 2), 2, BOARD_MAX)
	var golden_chance := clampf(0.05 + 0.05 * float(round_no - 3), 0.0, 0.45)
	var out: Array = []
	var ids := roll_shop(rng, level, count)
	for id in ids:
		var star := 1
		if rng.randf() < golden_chance:
			star = 2
		out.append({"id": id, "star": star})
	return out


static func format_units(n: int) -> String:
	if n >= 1000:
		return "%d,%03d" % [int(n / 1000), n % 1000]
	return str(n)
