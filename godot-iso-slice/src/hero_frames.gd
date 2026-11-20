class_name HeroFrames
extends RefCounted

# hero.png：8 列方向 x 6 行，单元 112x160，脚底画在单元正中心。
# 行 0-1 = idle，行 2-5 = walk。
# 因为脚底就是单元中心，AnimatedSprite2D 放在 (0,0) 时节点原点 == 脚底，
# Y-Sort 和碰撞体自然共用同一个锚点。

const SHEET := preload("res://assets/sprites/hero.png")
const CELL := Vector2i(112, 160)
const DIRS := 8
const IDLE_FRAMES := 2
const WALK_FRAMES := 4


static func build() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for dir in DIRS:
		var idle := "idle_%d" % dir
		frames.add_animation(idle)
		frames.set_animation_speed(idle, 2.5)
		for i in IDLE_FRAMES:
			frames.add_frame(idle, _cell(dir, i))

		var walk := "walk_%d" % dir
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 10.0)
		for i in WALK_FRAMES:
			frames.add_frame(walk, _cell(dir, IDLE_FRAMES + i))
	return frames


static func _cell(col: int, row: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = Rect2(col * CELL.x, row * CELL.y, CELL.x, CELL.y)
	return tex
