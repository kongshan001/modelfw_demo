class_name IsoMath
extends RefCounted

# 适配层：可移植数学在 src/core/portable_core.gd（由 portable-core/sync.py 同步）。
# 这里只把 Godot 的 Vector2 换成核心层的标量契约；换引擎时这一层重写，
# 核心层与 golden 向量不动。
const Core := preload("res://src/core/portable_core.gd")


static func screen_motion(input: Vector2) -> Vector2:
	var motion: Array = Core.screen_motion(input.x, input.y)
	return Vector2(motion[0], motion[1])


static func dir_index(v: Vector2) -> int:
	return Core.dir_index(v.x, v.y)
