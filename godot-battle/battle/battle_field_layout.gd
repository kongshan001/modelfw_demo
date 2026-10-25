class_name BattleFieldLayout
extends RefCounted

# 2.5D 俯视阵型表：每侧按 unit.slot 索引。
# row 0 = 后排（脚底 y 较小，先绘制）；row 1 = 前排（脚底 y 较大，后绘制、压住后排）。
# depth 只缩放美术层（后排 0.9×/前排 1.05×）；art_flip 只翻转美术层：
# -1 面向左（我方默认），+1 面向右（敌方默认）。
# pos 为脚底世界坐标；命中区以它为中心，保持 x 区间互不相交。

const ALLY_SLOTS := [
	{"row": 1, "pos": Vector2(1150, 800), "depth": 1.05, "art_flip": -1}, # 剑客·前排
	{"row": 0, "pos": Vector2(1290, 680), "depth": 0.92, "art_flip": -1}, # 法师·后排
	{"row": 0, "pos": Vector2(930, 680), "depth": 0.90, "art_flip": -1}, # 医师·后排
]

const ENEMY_SLOTS := [
	{"row": 1, "pos": Vector2(790, 800), "depth": 1.05, "art_flip": 1}, # 妖兵甲·前排
	{"row": 0, "pos": Vector2(650, 680), "depth": 0.90, "art_flip": 1}, # 妖兵乙·后排
	{"row": 1, "pos": Vector2(450, 800), "depth": 1.05, "art_flip": 1}, # 妖将·前排
	{"row": 0, "pos": Vector2(230, 680), "depth": 0.90, "art_flip": 1}, # 狐妖·后排
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
