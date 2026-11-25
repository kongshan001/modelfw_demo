class_name NormalWaterLayout
extends RefCounted

# 场景布局：世界 320×180（显示时 4× 最近邻到 1280×720，6× 到 1920×1080）。
# 所有坐标都是“世界像素”，物体图底与脚底对齐；程序化美术、光照、倒影共用这份数据。
# 单相机固定取景，不滚动、不额外开 Viewport。

const WORLD := Vector2(320.0, 180.0)
const CAMERA_ZOOM := 4.0
const WATERLINE := 120.0

# 河岸/近景物体。pos 是图片左上角的世界坐标；foot 是沿水线翻折的锚点。
const OBJECTS := [
	{"id": "tavern", "pos": Vector2i(16, 30), "z": 10, "reflect": true, "emission": 0.52},
	{"id": "maple", "pos": Vector2i(110, 36), "z": 11, "reflect": true, "emission": 0.0},
	{"id": "townhouse", "pos": Vector2i(204, 40), "z": 10, "reflect": true, "emission": 0.42},
	{"id": "pine", "pos": Vector2i(286, 48), "z": 10, "reflect": true, "emission": 0.0},
]

# 街灯：灯芯世界坐标用于方向 shader 的 2D 点光与水面暖色倒影。
const LAMPS := [
	{"id": "lamp_a", "pos": Vector2i(100, 60), "z": 13, "lantern": Vector2i(13, 10)},
	{"id": "lamp_b", "pos": Vector2i(172, 60), "z": 13, "lantern": Vector2i(13, 10)},
]

# 不参与倒影、但参与法线受光的近景/道具。
const BANK := {"id": "bank", "pos": Vector2i(0, 96), "z": 5, "emission": 0.0}
const DOCK := {"id": "dock", "pos": Vector2i(0, 140), "z": 30, "emission": 0.0}
const ROCKS := [
	{"id": "rock_quay", "pos": Vector2i(72, 94), "z": 12, "emission": 0.0},
	{"id": "rock_wall", "pos": Vector2i(282, 96), "z": 12, "emission": 0.0},
]
const BOULDER := {"id": "boulder", "pos": Vector2i(278, 154), "z": 31, "emission": 0.0}

const MOON_X := 252.0

# 所有 lighting material 共享的默认值；HUD 可实时覆盖方向/强度/颜色。
const DEFAULT_LIGHT_ANGLE_DEG := 35.0
const DEFAULT_LIGHT_ENERGY := 1.18
const DEFAULT_WAVE_SPEED := 1.0
const DEFAULT_WAVE_AMPLITUDE := 2.0
const DEFAULT_WAVE_STEP := 1.0

# 三个光源预设：冷月 / 暮蓝 / 暖烛。颜色是线性近似的 RGB，不需要贴图。
const LIGHT_PRESETS := [
	{
		"name": "冷月",
		"color": Vector3(0.64, 0.78, 1.00),
		"ambient": Vector3(0.125, 0.180, 0.290),
		"energy": 1.18,
		"angle": 35.0,
	},
	{
		"name": "暮蓝",
		"color": Vector3(0.40, 0.56, 0.86),
		"ambient": Vector3(0.105, 0.165, 0.285),
		"energy": 0.92,
		"angle": 332.0,
	},
	{
		"name": "暖烛",
		"color": Vector3(1.00, 0.72, 0.44),
		"ambient": Vector3(0.205, 0.155, 0.205),
		"energy": 0.74,
		"angle": 205.0,
	},
]

const LAMP_COLOR := Vector3(1.0, 0.60, 0.28)
const LAMP_ENERGY := 2.0
const LAMP_RADIUS := 60.0
const LAMP_HEIGHT := 22.0


static func object_by_id(id: String) -> Dictionary:
	for o in OBJECTS:
		if String(o["id"]) == id:
			return o
	return {}


static func lamp_world(index: int) -> Vector2:
	var lamp: Dictionary = LAMPS[index]
	var p: Vector2 = Vector2(lamp["pos"])
	var l: Vector2 = Vector2(lamp["lantern"])
	return p + l
