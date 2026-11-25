class_name RainLayout
extends RefCounted

# 场景布局：世界 640×360（显示时 2×/3× 最近邻放大）。
# 所有坐标都是“世界像素”，脚底为 y。程序化美术、低洼场、倒影共用这份数据。

const WORLD := Vector2(640.0, 360.0)
const TEX_SCALE := 2.0                       # 低洼场每 texel = 2 世界像素
const RULE_CELL := 16.0                      # 占位/灯柱规则格 = 16×16 世界像素

# 灯柱：脚底位置 + 是否水平翻转（臂朝左）。1×1 格规则只吃脚底那一格。
const LAMPS := [
	{"pos": Vector2(150.0, 232.0), "flip": false},
	{"pos": Vector2(506.0, 228.0), "flip": true},
]

const MAPLE := {"pos": Vector2(352.0, 138.0)}
const PINE := {"pos": Vector2(262.0, 274.0)}

# 低洼盆地：世界坐标中心 / 半径 / 下挖深度（0..1 高度单位）。
const BASINS := [
	{"pos": Vector2(176.0, 266.0), "radii": Vector2(92.0, 56.0), "depth": 0.30},
	{"pos": Vector2(352.0, 198.0), "radii": Vector2(84.0, 50.0), "depth": 0.27},
	{"pos": Vector2(512.0, 260.0), "radii": Vector2(74.0, 50.0), "depth": 0.28},
	{"pos": Vector2(270.0, 312.0), "radii": Vector2(72.0, 48.0), "depth": 0.24},
	{"pos": Vector2(520.0, 136.0), "radii": Vector2(54.0, 36.0), "depth": 0.17},
	{"pos": Vector2(78.0, 318.0), "radii": Vector2(56.0, 32.0), "depth": 0.18},
]

# 放在水洼里的大石头：占位格会挡住积水，形成不规则干岛。
const ROCK_CLUSTERS := [
	{"pos": Vector2(452.0, 294.0), "rx": 26.0, "ry": 19.0},
	{"pos": Vector2(560.0, 250.0), "rx": 22.0, "ry": 17.0},
]

# 左下角石岸：干区，给水洼边缘提供对比。
const STONE_BANK := {"pos": Vector2(44.0, 350.0), "rx": 78.0, "ry": 24.0}

# 灯柱灯笼相对脚底的偏移（默认臂朝右；翻转时 x 取反）。
const LANTERN_OFFSET := Vector2(18.0, -76.0)

# 世界内固定的小道具位置，美术与倒影共用。
const MAPLE_LEAF_PATCH := Vector2(352.0, 176.0)


static func lamp_cell(lamp: Dictionary) -> Vector2i:
	var p: Vector2 = lamp["pos"]
	return Vector2i(int(floor(p.x / RULE_CELL)), int(floor(p.y / RULE_CELL)))


static func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / RULE_CELL)), int(floor(pos.y / RULE_CELL)))


static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * RULE_CELL, Vector2(RULE_CELL, RULE_CELL))
