class_name BattleFieldLayout
extends RefCounted

# 2.5D 俯视阵型表：每侧按 unit.slot 索引。
# FWJ 实际战斗更接近“单尖端战士 + 扇形后排”：每侧只有一个 row=1 的尖端（战士），
# 法系/辅助沿尖端后方**向两侧展开成扇形**，而不是堆在战士正后方。
# 双方尖端几乎相接，中点落在中央石环；后排向外扇开，保证后排彼此可读。
# row 只描述战术关系，不直接等于屏幕 Y；镜头在我方背后，尖端都朝向对手。
# depth 表示离镜头的远近：我方后排 1.06~1.10、尖端 0.98；敌方尖端 0.94、后排 0.86~0.90。
# art_flip 只翻转美术层：-1 面向左（我方默认），+1 面向右（敌方默认）。
# view 只影响美术层：镜头位于我方队伍背后，我方显示背影（back），敌方显示正面（front）。
# pos 为脚底世界坐标。尖端点击优先；重叠的后排用 1–4 / QWE 数字键和单一目标箭头选择。
# 两侧中心约 (1043,860) 与 (637,620)，连线约 31°；尖端 (1000,800)/(850,700)
# 是双方最近的一对，连线中点正落在中央石环 (925,750)。

const ALLY_SLOTS := [
	{"row": 1, "pos": Vector2(1000, 800), "depth": 0.98, "art_flip": -1, "view": "back"}, # 剑客·尖端（唯一前排）
	{"row": 0, "pos": Vector2(1200, 880), "depth": 1.06, "art_flip": -1, "view": "back"}, # 法师·后排右侧扇形
	{"row": 0, "pos": Vector2(930, 900), "depth": 1.10, "art_flip": -1, "view": "back"}, # 医师·后排左侧扇形（离镜头最近）
]

const ENEMY_SLOTS := [
	{"row": 0, "pos": Vector2(700, 640), "depth": 0.90, "art_flip": 1, "view": "front"}, # 妖兵甲·后排扇形
	{"row": 0, "pos": Vector2(540, 600), "depth": 0.88, "art_flip": 1, "view": "front"}, # 妖兵乙·后排扇形
	{"row": 1, "pos": Vector2(850, 700), "depth": 0.94, "art_flip": 1, "view": "front"}, # 妖将·尖端（唯一前排）
	{"row": 0, "pos": Vector2(460, 540), "depth": 0.86, "art_flip": 1, "view": "front"}, # 狐妖·后排扇形（最远）
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
