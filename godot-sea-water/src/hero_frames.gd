class_name HeroFrames
extends RefCounted

# hero.png: 6 columns x 4 rows, cell 32x48.
# rows: 0 down, 1 up, 2 left, 3 right; frames 0-1 idle, 2-5 walk.

const SHEET := preload("res://assets/char/hero.png")
const CELL := Vector2i(32, 48)
const ROWS := 4
const IDLE := 2
const WALK := 4


static func build() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for row in ROWS:
		var idle := "idle_%d" % row
		sf.add_animation(idle)
		sf.set_animation_speed(idle, 2.0)
		sf.set_animation_loop(idle, true)
		for i in IDLE:
			sf.add_frame(idle, _cell(row, i))

		var walk := "walk_%d" % row
		sf.add_animation(walk)
		sf.set_animation_speed(walk, 8.5)
		sf.set_animation_loop(walk, true)
		for i in WALK:
			sf.add_frame(walk, _cell(row, IDLE + i))
	return sf


static func _cell(row: int, col: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = Rect2(col * CELL.x, row * CELL.y, CELL.x, CELL.y)
	return tex
