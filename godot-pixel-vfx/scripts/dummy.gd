class_name TrainingDummy
extends Node2D

# Original straw training dummy. Drawn with integer pixel rects so hit recoil,
# flash, frost tint and burn tint stay crisp. No PixelFX actor is used.

const HEIGHT := 44.0

const STRAW := Color("#c9a24e")
const STRAW_DARK := Color("#9c7531")
const STRAW_LIGHT := Color("#e3bd68")
const WOOD := Color("#6b4a2f")
const WOOD_LIGHT := Color("#8a6238")
const WOOD_DARK := Color("#422c1d")
const ROPE := Color("#8f7440")
const CLOTH := Color("#b5433f")
const CREAM := Color("#efe0ba")
const INK := Color("#3a241a")

var time := 0.0
var flash := 0.0
var recoil := 0.0
var frozen_remaining := 0.0
var frozen_total := 0.0
var burn_remaining := 0.0
var burn_total := 0.0

func step(dt: float) -> void:
	time += dt
	flash = maxf(0.0, flash - dt * 7.0)
	recoil = move_toward(recoil, 0.0, dt * 26.0)
	frozen_remaining = maxf(0.0, frozen_remaining - dt)
	burn_remaining = maxf(0.0, burn_remaining - dt)
	queue_redraw()

func hit(strength: float = 1.0) -> void:
	flash = 1.0
	recoil = maxf(recoil, 3.4 * strength)

func apply_freeze(seconds: float) -> void:
	frozen_remaining = seconds
	frozen_total = maxf(seconds, 0.001)
	flash = maxf(flash, 0.7)
	queue_redraw()

func apply_burn(seconds: float) -> void:
	burn_remaining = seconds
	burn_total = maxf(seconds, 0.001)
	queue_redraw()

func is_frozen() -> bool:
	return frozen_remaining > 0.0

func is_burning() -> bool:
	return burn_remaining > 0.0

func clear_status() -> void:
	frozen_remaining = 0.0
	burn_remaining = 0.0
	frozen_total = 0.0
	burn_total = 0.0
	flash = 0.0
	recoil = 0.0
	queue_redraw()

func _tint(base: Color) -> Color:
	var c := base
	if flash > 0.0:
		c = c.lerp(Color.WHITE, clampf(flash, 0.0, 1.0) * 0.88)
	if burn_remaining > 0.0:
		var flick := 0.20 + 0.07 * sin(time * 23.0)
		c = c.lerp(Color("#ff7a33"), flick)
	if frozen_remaining > 0.0:
		c = c.lerp(Color("#8fd8ff"), 0.42)
	return c

func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(round(x), round(y), w, h), _tint(c))

func _draw() -> void:
	var l := recoil
	var l2 := l * 0.55
	var l3 := l * 1.35

	# ground shadow
	draw_rect(Rect2(-13, -2, 26, 2), Color(0, 0, 0, 0.32))
	draw_rect(Rect2(-9, 0, 18, 1), Color(0, 0, 0, 0.22))

	# timber base
	_r(-13, -4, 26, 3, WOOD_DARK)
	_r(-11, -5, 22, 2, WOOD)
	_r(-11, -5, 22, 1, WOOD_LIGHT)
	_r(-10 + l * 0.1, -7, 3, 2, WOOD_DARK)
	_r(8 + l * 0.1, -7, 3, 2, WOOD_DARK)

	# post (leans with the hit)
	_r(-2 + l2, -38, 4, 31, WOOD)
	_r(-2 + l2, -38, 1, 31, WOOD_LIGHT)
	_r(1 + l2, -38, 1, 31, WOOD_DARK)

	# crossbar arms + rope wraps
	_r(-19 + l2, -34, 38, 3, WOOD)
	_r(-19 + l2, -34, 38, 1, WOOD_LIGHT)
	_r(-19 + l2, -32, 38, 1, WOOD_DARK)
	_r(-17 + l2, -35, 2, 5, ROPE)
	_r(15 + l2, -35, 2, 5, ROPE)
	# red cloth tied to the right arm
	_r(13 + l2, -29, 4, 5, CLOTH)
	_r(14 + l2, -25, 2, 2, CLOTH.darkened(0.18))

	# straw torso
	_r(-11 + l, -32, 22, 17, STRAW)
	_r(-11 + l, -32, 22, 2, STRAW_LIGHT)
	_r(-11 + l, -18, 22, 3, STRAW_DARK)
	_r(-11 + l, -32, 2, 14, STRAW_LIGHT)
	_r(9 + l, -30, 2, 12, STRAW_DARK)
	# stray straw poking out
	_r(-13 + l, -27, 2, 1, STRAW_LIGHT)
	_r(11 + l, -23, 2, 1, STRAW_LIGHT)
	_r(-12 + l, -21, 2, 1, STRAW_DARK)
	_r(11 + l, -30, 2, 1, STRAW_LIGHT)

	# rope bindings
	_r(-12 + l, -26, 24, 2, ROPE)
	_r(-12 + l, -20, 24, 2, ROPE)
	_r(-12 + l, -26, 24, 1, ROPE.lightened(0.18))
	_r(-12 + l, -20, 24, 1, ROPE.lightened(0.18))
	_r(-3 + l, -25, 2, 1, ROPE.darkened(0.3))
	_r(3 + l, -19, 2, 1, ROPE.darkened(0.3))

	# painted target on the chest, facing the knight
	_r(-10 + l, -31, 10, 10, CREAM)
	_r(-9 + l, -30, 8, 8, CLOTH)
	_r(-7 + l, -28, 4, 4, CREAM)
	_r(-6 + l, -27, 2, 2, CLOTH.darkened(0.25))
	_r(-10 + l, -31, 10, 1, CREAM.darkened(0.1))
	_r(-10 + l, -22, 10, 1, INK)

	# straw head
	_r(-6 + l3, -44, 12, 11, STRAW)
	_r(-6 + l3, -44, 12, 1, STRAW_LIGHT)
	_r(-6 + l3, -35, 12, 2, STRAW_DARK)
	_r(-6 + l3, -44, 1, 9, STRAW_LIGHT)
	_r(5 + l3, -43, 1, 9, STRAW_DARK)
	# stitched X eyes + mouth
	_r(-4 + l3, -40, 1, 1, INK)
	_r(-2 + l3, -40, 1, 1, INK)
	_r(-4 + l3, -38, 1, 1, INK)
	_r(-2 + l3, -38, 1, 1, INK)
	_r(-3 + l3, -35, 3, 1, INK)
	# straw tufts
	_r(-4 + l3, -47, 1, 3, STRAW_DARK)
	_r(0 + l3, -48, 1, 4, STRAW)
	_r(4 + l3, -46, 1, 2, STRAW_LIGHT)
	_r(-6 + l3, -43, 2, 1, STRAW_LIGHT)
	_r(3 + l3, -43, 2, 1, STRAW_DARK)

	if frozen_remaining > 0.0:
		_draw_frost(l3)
	if burn_remaining > 0.0:
		_draw_burn(l3)
	_draw_status()

func _draw_frost(l3: float) -> void:
	var a := 0.55 + 0.12 * sin(time * 4.0)
	var ice_light := Color(0.82, 0.95, 1.0, a)
	var ice_mid := Color(0.49, 0.83, 1.0, a * 0.9)
	var ice_deep := Color(0.23, 0.55, 0.85, a * 0.75)
	# crystals at the feet
	_poly([Vector2(-14, -2), Vector2(-10, -13), Vector2(-6, -2)], ice_mid)
	_poly([Vector2(-10, -2), Vector2(-7, -8), Vector2(-4, -2)], ice_light)
	_poly([Vector2(7, -2), Vector2(11, -15), Vector2(16, -2)], ice_mid)
	_poly([Vector2(10, -2), Vector2(14, -9), Vector2(18, -2)], ice_deep)
	_poly([Vector2(-2, -2), Vector2(2, -6), Vector2(5, -2)], ice_light)
	# shoulder shards
	_poly([Vector2(-17, -33), Vector2(-14, -40), Vector2(-11, -33)], ice_light)
	_poly([Vector2(12, -33), Vector2(16, -41), Vector2(19, -33)], ice_mid)
	# frozen sparkles
	for p in [Vector2(-12, -8), Vector2(13, -5), Vector2(-16, -38), Vector2(9, -47), Vector2(3, -22)]:
		draw_rect(Rect2(p.x, p.y, 1, 1), Color.WHITE)
		draw_rect(Rect2(p.x - 1, p.y, 1, 1), ice_light)
		draw_rect(Rect2(p.x + 1, p.y, 1, 1), ice_light)
		draw_rect(Rect2(p.x, p.y - 1, 1, 1), ice_light)
		draw_rect(Rect2(p.x, p.y + 1, 1, 1), ice_light)
	# breath steam
	draw_rect(Rect2(6 + l3, -38, 1, 3), Color(0.85, 0.95, 1.0, 0.28))
	draw_rect(Rect2(8 + l3, -41, 1, 4), Color(0.85, 0.95, 1.0, 0.18))

func _draw_burn(l3: float) -> void:
	var ember_a := Color("#ffd166")
	var ember_b := Color("#ff7a33")
	var ember_c := Color("#c9281f")
	for i in 3:
		var phase := fmod(time * 22.0 + i * 13.0, 38.0)
		var yy := -8.0 - phase
		var xx := -6.0 + i * 6.0 + sin(time * 5.0 + i * 2.1) * 2.5
		draw_rect(Rect2(round(xx), round(yy), 1, 1), ember_a)
		draw_rect(Rect2(round(xx + 1), round(yy - 1), 1, 1), ember_b)
		draw_rect(Rect2(round(xx - 1), round(yy - 2), 1, 1), ember_c)
	# small licking flames on the shoulders
	var flick := int(round(sin(time * 18.0) * 1.0))
	draw_rect(Rect2(-15, -37 + flick, 2, 3), ember_b)
	draw_rect(Rect2(-14, -39 + flick, 1, 2), ember_a)
	draw_rect(Rect2(12, -38 - flick, 2, 3), ember_b)
	draw_rect(Rect2(13, -40 - flick, 1, 2), ember_a)
	# soot wisps
	draw_rect(Rect2(1 + l3, -48, 1, 1), Color(0.35, 0.32, 0.36, 0.5))
	draw_rect(Rect2(2 + l3, -51, 1, 1), Color(0.35, 0.32, 0.36, 0.35))

func _draw_status() -> void:
	var row := 0
	if frozen_remaining > 0.0:
		_draw_bar(-52.0 - row * 8.0, frozen_remaining / maxf(frozen_total, 0.001),
				Color("#1b2d4a"), Color("#62c8f4"), Color("#dcfbff"))
		# snowflake icon
		var ix := -27.0
		var iy := -53.0 - row * 8.0
		var ice := Color("#a6ecff")
		draw_rect(Rect2(ix + 2, iy, 1, 5), ice)
		draw_rect(Rect2(ix, iy + 2, 5, 1), ice)
		draw_rect(Rect2(ix + 1, iy + 1, 1, 1), ice)
		draw_rect(Rect2(ix + 3, iy + 3, 1, 1), ice)
		draw_rect(Rect2(ix + 3, iy + 1, 1, 1), ice)
		draw_rect(Rect2(ix + 1, iy + 3, 1, 1), ice)
		row += 1
	if burn_remaining > 0.0:
		_draw_bar(-52.0 - row * 8.0, burn_remaining / maxf(burn_total, 0.001),
				Color("#3a1710"), Color("#ff7a33"), Color("#ffd166"))
		var ix := -27.0
		var iy := -53.0 - row * 8.0
		draw_rect(Rect2(ix + 1, iy + 1, 3, 3), Color("#ff7a33"))
		draw_rect(Rect2(ix + 2, iy, 1, 1), Color("#ffd166"))
		draw_rect(Rect2(ix + 2, iy + 4, 1, 1), Color("#c9281f"))

func _draw_bar(y: float, ratio: float, bg: Color, fill: Color, tip: Color) -> void:
	var x := -17.0
	var w := 34.0
	draw_rect(Rect2(x - 1, y - 1, w + 2, 5), Color(0.04, 0.04, 0.07, 0.9))
	draw_rect(Rect2(x, y, w, 3), bg)
	var fill_w := roundf(w * clampf(ratio, 0.0, 1.0))
	if fill_w > 0.0:
		draw_rect(Rect2(x, y, fill_w, 3), fill)
		draw_rect(Rect2(x, y, fill_w, 1), tip)

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)
