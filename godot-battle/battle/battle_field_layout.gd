class_name BattleFieldLayout
extends RefCounted

# 2.5D 俯视阵型表：每侧按 unit.slot 索引。
# FWJ 实机（/tmp/fwj_ref2）的关键比例：角色高约占屏高 10–14%，双方阵型中心相距
# 约 4–5 个角色高，中间是一整块空出来的圆形战场；每侧阵型本身很紧凑（宽 1.5–2 个角色高）。
# 本表按 1920×1080、角色美术高约 170px 落地：我方中心 (1185,900)、敌方中心 (565,479)，
# 中心距约 750px（≈4.4 个角色高），连线约 34°；两尖端 (1100,830)/(660,560) 相距约 516px，
# 中点 (880,695) 正落在中央石环。同侧间距按梦幻实机量得的 0.7–1.0 个角色高落地：
# 我方两两 150–192px（0.88–1.13）；敌方排成 2×2 交错块，相邻对 130–153px（0.76–0.90），
# 不再挤成一坨。中间仍留出完整空场。
# row 只描述战术关系，不直接等于屏幕 Y；镜头在我方背后，尖端都朝向对手。
# depth 表示离镜头的远近：我方后排 1.06~1.10、尖端 0.98；敌方尖端 0.94、后排 0.86~0.90。
# art_flip 只翻转美术层：-1 面向左（我方默认），+1 面向右（敌方默认）。
# view 只影响美术层：镜头位于我方队伍背后，我方显示背影（back），敌方显示正面（front）。
# pos 为脚底世界坐标。尖端点击优先；重叠的后排用 1–4 / QWE 数字键和单一目标箭头选择。
const ALLY_SLOTS := [
	{"row": 1, "pos": Vector2(1100, 830), "depth": 0.98, "art_flip": -1, "view": "back"}, # 剑客·尖端（唯一前排）
	{"row": 0, "pos": Vector2(1265, 870), "depth": 1.06, "art_flip": -1, "view": "back"}, # 法师·后排右扇（最高）
	{"row": 0, "pos": Vector2(1190, 1000), "depth": 1.10, "art_flip": -1, "view": "back"}, # 医师·后排中下（离镜头最近）
]

const ENEMY_SLOTS := [
	{"row": 0, "pos": Vector2(520, 520), "depth": 0.90, "art_flip": 1, "view": "front"}, # 妖兵甲·2×2 前排左
	{"row": 0, "pos": Vector2(470, 400), "depth": 0.88, "art_flip": 1, "view": "front"}, # 妖兵乙·2×2 后排左
	{"row": 1, "pos": Vector2(660, 560), "depth": 0.94, "art_flip": 1, "view": "front"}, # 妖将·尖端（唯一前排）
	{"row": 0, "pos": Vector2(610, 415), "depth": 0.86, "art_flip": 1, "view": "front"}, # 狐妖·2×2 后排右
]

func slot(side: int, index: int) -> Dictionary:
	var table := slots_for(side)
	if index < 0 or index >= table.size():
		return {}
	return table[index].duplicate(true)

func slots_for(side: int) -> Array:
	return ALLY_SLOTS.duplicate(true) if side == BattleTypes.Side.ALLY else ENEMY_SLOTS.duplicate(true)

func ally_slots() -> Array:
	return ALLY_SLOTS.duplicate(true)

func enemy_slots() -> Array:
	return ENEMY_SLOTS.duplicate(true)

func all_slots() -> Array:
	return ally_slots() + enemy_slots()
