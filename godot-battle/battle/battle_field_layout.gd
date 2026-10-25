class_name BattleFieldLayout
extends RefCounted

# 2.5D 俯视阵型表：每侧按 unit.slot 索引。
# 阵型为 FWJ 式紧凑菱形/箭头：每侧只有一个 row=1 的“尖端”（战士），
# 法系/辅助以 row=0 背向两侧展开，整队围绕中央石环，双方尖端几乎相接。
# row 只描述战术关系，不直接等于屏幕 Y；镜头在我方背后，尖端都朝向对手。
# depth 表示离镜头的远近，乘在美术层上（我方 0.98~1.10，敌方 0.86~0.94），不等同于 row。
# art_flip 只翻转美术层：-1 面向左（我方默认），+1 面向右（敌方默认）。
# view 只影响美术层：镜头位于我方队伍背后，我方显示背影（back），敌方显示正面（front）。
# pos 为脚底世界坐标。命中区允许在屏幕空间重叠（参考作同样如此），
# 目标选择以“1–4 / QWE”按键和单一目标箭头为主，鼠标点击尖端作为补充。
# 两侧阵型中心约 (1057,857) 与 (750,635)，连线约 36°：
# 敌方整体在左上（远/小），我方整体在右下（近/大）；尖端 (1000,800)/(850,700)
# 是双方最近的一对，连线中点正落在中央石环 (925,750)。

const ALLY_SLOTS := [
	{"row": 1, "pos": Vector2(1000, 800), "depth": 0.98, "art_flip": -1, "view": "back"}, # 剑客·尖端（唯一前排，面向敌方）
	{"row": 0, "pos": Vector2(1100, 860), "depth": 1.10, "art_flip": -1, "view": "back"}, # 法师·后排（镜头最近）
	{"row": 0, "pos": Vector2(1070, 910), "depth": 1.06, "art_flip": -1, "view": "back"}, # 医师·后排
]

const ENEMY_SLOTS := [
	{"row": 0, "pos": Vector2(760, 640), "depth": 0.90, "art_flip": 1, "view": "front"}, # 妖兵甲·后排
	{"row": 0, "pos": Vector2(740, 620), "depth": 0.88, "art_flip": 1, "view": "front"}, # 妖兵乙·后排
	{"row": 1, "pos": Vector2(850, 700), "depth": 0.94, "art_flip": 1, "view": "front"}, # 妖将·尖端（唯一前排，面向我方）
	{"row": 0, "pos": Vector2(650, 580), "depth": 0.86, "art_flip": 1, "view": "front"}, # 狐妖·后排（最远）
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
