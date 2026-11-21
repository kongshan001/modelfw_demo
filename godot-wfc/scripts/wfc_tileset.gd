extends RefCounted

# 原创庭院瓦片集：规则与视觉共用同一份定义。
# 每条边只有两种「接口」：0 = 泥土/草地，1 = 石径。
# 相邻两格只有在接触边的接口相同时才允许共存；地图外边界禁止石径伸出。

const N := 0
const E := 1
const S := 2
const W := 3
const DIRS := [N, E, S, W]
const OPPOSITE := [S, W, N, E]
const TILE_COUNT := 14

enum {
	MEADOW, FLOWERS, FOREST, POND, COTTAGE, GREENHOUSE, RUIN,
	PATH_H, PATH_V, PATH_NE, PATH_ES, PATH_SW, PATH_WN, PATH_CROSS,
}

const NAMES := [
	"草甸", "花圃", "林地", "池塘", "石屋", "温室", "废墟",
	"石径·横", "石径·竖", "石径·拐 NE", "石径·拐 ES", "石径·拐 SW", "石径·拐 WN",
	"石径·十字",
]

# 18 世纪庭院调色：暖石、苔绿、陶土屋顶、深青池水。
const BASES := [
	Color("#607b4c"), # 草甸
	Color("#6c8551"), # 花圃
	Color("#455f41"), # 林地
	Color("#526f52"), # 池塘底
	Color("#657d4e"), # 石屋
	Color("#617c52"), # 温室
	Color("#667250"), # 废墟
	Color("#66804e"), # 石径·横
	Color("#66804e"),
	Color("#66804e"),
	Color("#66804e"),
	Color("#66804e"),
	Color("#66804e"),
	Color("#66804e"),
	Color("#66804e"),
	Color("#66804e"),
	Color("#66804e"),
]

const ACCENTS := [
	Color("#8aa15d"),
	Color("#df8c7d"),
	Color("#2f4934"),
	Color("#4f8b88"),
	Color("#b8644d"),
	Color("#8eb6a6"),
	Color("#b4ac91"),
	Color("#c8ad78"),
	Color("#c8ad78"),
	Color("#c8ad78"),
	Color("#c8ad78"),
	Color("#c8ad78"),
	Color("#c8ad78"),
	Color("#c8ad78"),
	Color("#c8ad78"),
	Color("#c8ad78"),
	Color("#c8ad78"),
]

# 路径权重与路网规模：石径没有断头，每条路臂必须接到下一格，
# 因此随机选择会形成环路，也会在边界/水岸附近制造可观察的矛盾。
const WEIGHTS := [
	4.20, 1.55, 2.55, 1.20, 0.82, 0.48, 0.52,
	0.62, 0.62, 0.38, 0.38, 0.38, 0.38, 0.14,
]

# [N, E, S, W]，1 表示石径接口。
const SOCKETS := [
	[0, 0, 0, 0],
	[0, 0, 0, 0],
	[0, 0, 0, 0],
	[0, 0, 0, 0],
	[0, 0, 0, 0],
	[0, 0, 0, 0],
	[0, 0, 0, 0],
	[0, 1, 0, 1],
	[1, 0, 1, 0],
	[1, 1, 0, 0],
	[0, 1, 1, 0],
	[0, 0, 1, 1],
	[1, 0, 0, 1],
	[1, 1, 1, 1],
]

const PATHS := [
	PATH_H, PATH_V, PATH_NE, PATH_ES, PATH_SW, PATH_WN, PATH_CROSS,
]

const STRUCTURES := [COTTAGE, GREENHOUSE, RUIN, POND]


static func all_mask() -> int:
	return (1 << TILE_COUNT) - 1


static func bit(tile: int) -> int:
	return 1 << tile


static func is_path(tile: int) -> bool:
	return tile >= PATH_H and tile <= PATH_CROSS


static func socket(tile: int, direction: int) -> int:
	return int(SOCKETS[tile][direction])


static func name_of(tile: int) -> String:
	if tile < 0 or tile >= TILE_COUNT:
		return "—"
	return String(NAMES[tile])


static func base_color(tile: int) -> Color:
	if tile < 0 or tile >= TILE_COUNT:
		return Color("#303a2c")
	return BASES[tile]


static func accent_color(tile: int) -> Color:
	if tile < 0 or tile >= TILE_COUNT:
		return Color("#d9c07e")
	return ACCENTS[tile]


# 每个方向 × 每种瓦片：可放到该方向邻格的瓦片位掩码。
static func build_compat() -> Array:
	var table: Array = []
	for d in DIRS:
		var row := PackedInt32Array()
		row.resize(TILE_COUNT)
		for a in TILE_COUNT:
			var allowed := 0
			for b in TILE_COUNT:
				if socket(a, d) == socket(b, OPPOSITE[d]):
					allowed |= bit(b)
			row[a] = allowed
		table.append(row)
	return table


# 边界格不允许石径接口朝向地图外，避免出现“断头路伸到屏幕外”。
static func boundary_mask(x: int, y: int, width: int, height: int) -> int:
	var mask := all_mask()
	for t in TILE_COUNT:
		if (x == 0 and socket(t, W) == 1) \
				or (x == width - 1 and socket(t, E) == 1) \
				or (y == 0 and socket(t, N) == 1) \
				or (y == height - 1 and socket(t, S) == 1):
			mask &= ~bit(t)
	return mask


static func is_structure(tile: int) -> bool:
	return STRUCTURES.has(tile)
