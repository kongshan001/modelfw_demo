class_name SnowHeroFrames
extends RefCounted

const SHEET := preload("res://assets/char/hero.png")
const CELL := Vector2i(32, 48)
const ROWS := 4


static func build() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for row in ROWS:
		var idle := "idle_%d" % row
		sf.add_animation(idle)
		sf.set_animation_speed(idle, 2.0)
		for i in 2:
			sf.add_frame(idle, _cell(row, i))
		var walk := "walk_%d" % row
		sf.add_animation(walk)
		sf.set_animation_speed(walk, 8.0)
		for i in 4:
			sf.add_frame(walk, _cell(row, 2 + i))
	return sf


static func _cell(row: int, col: int) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = SHEET
	t.region = Rect2(col * CELL.x, row * CELL.y, CELL.x, CELL.y)
	return t
