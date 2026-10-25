class_name BattleFieldLayout
extends RefCounted

# 2.5D 俯视阵型表：每侧按 unit.slot 索引。
# row 是战术前后排：1=靠近对手的前排（战士/近战），0=后排（法系/辅助）。
# row 只描述战术关系，不直接等于屏幕 Y；镜头在我方背后，所以两侧“靠近镜头”的排不同：
# 我方后排脚底 y 更大（更近/更大），敌方前排脚底 y 更大（更近/更大）。
# depth 表示离镜头的远近，乘在美术层上（我方 1.08~1.12，敌方 0.74~0.86），不等同于 row。
# art_flip 只翻转美术层：-1 面向左（我方默认），+1 面向右（敌方默认）。
# view 只影响美术层：镜头位于我方队伍背后，我方显示背影（back），敌方显示正面（front）。
# pos 为脚底世界坐标；命中区以它为中心，保持 x 区间互不相交。
# 两个阵型中心约 (1100, 890) 与 (528, 590)，连线呈约 28° 斜线：
# 敌方整体在左上（远/小），我方整体在右下（近/大）；双方前排战士沿线相向而立。

const ALLY_SLOTS := [
	{"row": 1, "pos": Vector2(950, 840), "depth": 0.98, "art_flip": -1, "view": "back"}, # 剑客·前排（离对手近，离镜头远）
	{"row": 0, "pos": Vector2(1090, 930), "depth": 1.12, "art_flip": -1, "view": "back"}, # 法师·后排（离镜头近）
	{"row": 0, "pos": Vector2(1260, 900), "depth": 1.08, "art_flip": -1, "view": "back"}, # 医师·后排（离镜头近）
]

const ENEMY_SLOTS := [
	{"row": 1, "pos": Vector2(620, 660), "depth": 0.84, "art_flip": 1, "view": "front"}, # 妖兵甲·前排
	{"row": 0, "pos": Vector2(450, 540), "depth": 0.74, "art_flip": 1, "view": "front"}, # 妖兵乙·后排
	{"row": 1, "pos": Vector2(810, 640), "depth": 0.86, "art_flip": 1, "view": "front"}, # 妖将·前排（靠近对手）
	{"row": 0, "pos": Vector2(230, 520), "depth": 0.74, "art_flip": 1, "view": "front"}, # 狐妖·后排
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
