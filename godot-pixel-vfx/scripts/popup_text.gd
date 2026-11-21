class_name PopupText
extends Node2D

# Floating damage / score text drawn with the original 5x7 bitmap font.
# Integer positions and scale multiples keep it pixel-perfect.

var text := ""
var color := Color.WHITE
var scale_px := 2
var life := 0.0
var total := 0.75
var rise := 18.0
var start := Vector2.ZERO

func setup(value: String, at: Vector2, tint: Color, px_scale: int = 2, seconds: float = 0.75) -> void:
	text = value
	start = at
	position = at
	color = tint
	scale_px = px_scale
	life = 0.0
	total = seconds
	z_index = 50
	queue_redraw()

func step(dt: float) -> bool:
	life += dt
	if life >= total:
		return false
	var k := clampf(life / total, 0.0, 1.0)
	position = Vector2(start.x, start.y - rise * (1.0 - pow(1.0 - k, 2.0)))
	queue_redraw()
	return true

func _draw() -> void:
	var k := clampf(life / total, 0.0, 1.0)
	var alpha := 1.0
	if k > 0.55:
		alpha = 1.0 - (k - 0.55) / 0.45
	var c := Color(color.r, color.g, color.b, alpha)
	var shadow := Color(0.04, 0.04, 0.07, alpha * 0.9)
	var w := PixelFont.width(text, scale_px, 1)
	var pos := Vector2(-round(w / 2.0), 0)
	PixelFont.draw(self, text, pos + Vector2(1, 1), scale_px, shadow)
	PixelFont.draw(self, text, pos, scale_px, c)
	if scale_px >= 3:
		PixelFont.draw(self, text, pos + Vector2(0, 1), scale_px, Color(c.r, c.g, c.b, alpha * 0.25))
