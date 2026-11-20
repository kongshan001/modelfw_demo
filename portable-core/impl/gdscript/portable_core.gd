extends RefCounted

# Reference implementation of the portable core (GDScript).
# Contract: spec/functions.md; golden vectors: spec/golden.json.
# Must stay bit-identical with impl/python/portable_core.py and
# impl/js/portable_core.mjs.
#
# This file is vendored into Godot projects by ../sync.py. Edit the copy in
# portable-core/impl/gdscript/, then run sync.py --check.

# 2:1 等距投影：屏幕纵向 1 px 对应地面纵向 0.5 px。
# 按下/上时屏幕位移只取一半，地面速度才和左右一致，斜向也不会变慢。
# 返回普通 Array（float64）而不是 Vector2：引擎类型留在适配层，
# 核心层才能与 Python/JS 逐值一致。
static func screen_motion(x: float, y: float) -> Array:
	return [x, y * 0.5]


# 把屏幕方向切成 8 个 45° 扇区。
# 先 +22.5° 再 floor：扇区中心落在正方向（右/下/左/上）上，
# 边界落在对角线中间，角色朝向不会在两条对角线之间抖动。
static func dir_index(x: float, y: float) -> int:
	if x * x + y * y < 0.0001:
		return 0
	var sector := int(floor((rad_to_deg(atan2(y, x)) + 22.5) / 45.0))
	return posmod(sector, 8)


# 确定性 32 位哈希：整数-only，溢出显式掩到 uint32。
static func hash32(x: int, y: int, seed: int) -> int:
	var v: int = (x * 374761393 + y * 668265263
		+ (seed & 0xFFFFFFFF) * 1013904223) & 0xFFFFFFFF
	v = (v ^ (v >> 13)) & 0xFFFFFFFF
	v = (v * 1274126177) & 0xFFFFFFFF
	v = (v ^ (v >> 16)) & 0xFFFFFFFF
	return v
