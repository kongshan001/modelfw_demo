class_name Knight
extends Node2D

# Original 40px knight, drawn from integer rects. Idle bob, sword attack pose
# and spell-cast pose. Facing right; the PixelFX sheets supply the actual VFX.

const TEAL := Color("#2f7d78")
const TEAL_DARK := Color("#1f5a57")
const TEAL_LIGHT := Color("#4aa39a")
const STEEL := Color("#9fb2c8")
const STEEL_LIGHT := Color("#cfdcce")
const STEEL_DARK := Color("#65788e")
const CAPE := Color("#a83950")
const CAPE_DARK := Color("#7a2338")
const GOLD := Color("#d6a33c")
const GOLD_LIGHT := Color("#f2cf70")
const SKIN := Color("#e8c39a")
const BOOT := Color("#5a3a26")
const PANTS := Color("#26344a")
const INK := Color("#151a24")

var time := 0.0
var attack_t := 0.0
var cast_t := 0.0
var attack_total := 0.38
var cast_total := 0.5

func step(dt: float) -> void:
	time += dt
	attack_t = maxf(0.0, attack_t - dt)
	cast_t = maxf(0.0, cast_t - dt)
	queue_redraw()

func attack() -> void:
	attack_t = attack_total
	queue_redraw()

func cast() -> void:
	cast_t = cast_total
	queue_redraw()

func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(round(x), round(y), w, h), c)

func _draw() -> void:
	var bob := int(round(sin(time * 2.4) * 0.8))
	var cape_sway := int(round(sin(time * 3.1) * 1.0))
	var atk := 0.0
	if attack_t > 0.0:
		atk = sin((1.0 - attack_t / attack_total) * PI)
	var cast := 0.0
	if cast_t > 0.0:
		cast = sin((1.0 - cast_t / cast_total) * PI)
	var lean := int(round(atk * 2.0 - cast * 1.0))

	# shadow
	draw_rect(Rect2(-10, -2, 20, 2), Color(0, 0, 0, 0.30))
	draw_rect(Rect2(-7, 0, 14, 1), Color(0, 0, 0, 0.18))

	# cape behind the body
	var cx := -5 + lean
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, -26 + bob), Vector2(cx - 6 + cape_sway, -9),
		Vector2(cx - 2 + cape_sway, -7), Vector2(cx + 2, -22 + bob),
	]), CAPE_DARK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 1, -26 + bob), Vector2(cx - 3 + cape_sway, -11),
		Vector2(cx, -10), Vector2(cx + 4, -23 + bob),
	]), CAPE)

	# legs + boots
	_r(-4 + lean, -13 + bob, 4, 9, PANTS)
	_r(1 + lean, -13 + bob, 4, 9, PANTS)
	_r(-5 + lean, -5, 5, 4, BOOT)
	_r(1 + lean, -5, 5, 4, BOOT)
	_r(-5 + lean, -5, 5, 1, BOOT.lightened(0.18))
	_r(1 + lean, -5, 5, 1, BOOT.lightened(0.18))
	_r(-5 + lean, -2, 5, 1, INK)
	_r(1 + lean, -2, 5, 1, INK)

	# tunic + steel chest
	_r(-6 + lean, -27 + bob, 13, 15, TEAL)
	_r(-6 + lean, -27 + bob, 2, 14, TEAL_LIGHT)
	_r(5 + lean, -26 + bob, 2, 13, TEAL_DARK)
	_r(-5 + lean, -26 + bob, 11, 7, STEEL)
	_r(-5 + lean, -26 + bob, 11, 1, STEEL_LIGHT)
	_r(-5 + lean, -21 + bob, 11, 2, STEEL_DARK)
	_r(-1 + lean, -25 + bob, 3, 4, GOLD)
	_r(-6 + lean, -16 + bob, 13, 2, GOLD)
	_r(-1 + lean, -16 + bob, 2, 2, GOLD_LIGHT)
	# scarf knot
	_r(-4 + lean, -29 + bob, 6, 2, CAPE)
	_r(-4 + lean, -29 + bob, 6, 1, CAPE.lightened(0.15))

	# shoulders
	_r(-8 + lean, -27 + bob, 4, 5, STEEL)
	_r(-8 + lean, -27 + bob, 4, 1, STEEL_LIGHT)
	_r(5 + lean, -27 + bob, 4, 5, STEEL)
	_r(5 + lean, -27 + bob, 4, 1, STEEL_LIGHT)

	# back arm (left side)
	if cast > 0.25:
		_r(-9 + lean, -34 + bob, 3, 9, TEAL)
		_r(-10 + lean, -37 + bob, 3, 4, SKIN)
		# spell orb in the raised hand
		var ox := -10 + lean
		var oy := -42 + bob
		draw_rect(Rect2(ox - 1, oy - 1, 5, 5), Color(1.0, 0.85, 0.4, 0.25))
		_r(ox, oy, 3, 3, Color("#ffd166"))
		_r(ox + 1, oy + 1, 1, 1, Color.WHITE)
	else:
		_r(-8 + lean, -24 + bob, 3, 9, TEAL)
		_r(-8 + lean, -17 + bob, 3, 3, BOOT)
		_r(-9 + lean, -25 + bob, 1, 3, TEAL_LIGHT)

	# head + helmet
	_r(-5 + lean, -37 + bob, 10, 8, SKIN)
	_r(-5 + lean, -37 + bob, 10, 1, SKIN.lightened(0.1))
	_r(3 + lean, -36 + bob, 2, 6, SKIN.darkened(0.12))
	_r(-6 + lean, -40 + bob, 12, 6, STEEL)
	_r(-6 + lean, -40 + bob, 12, 1, STEEL_LIGHT)
	_r(-4 + lean, -36 + bob, 9, 2, INK)
	_r(-4 + lean, -36 + bob, 2, 1, Color("#62c8f4"))
	_r(2 + lean, -36 + bob, 2, 1, Color("#62c8f4"))
	_r(-7 + lean, -38 + bob, 1, 4, STEEL_DARK)
	_r(5 + lean, -38 + bob, 1, 4, STEEL_DARK)
	# plume
	_r(-1 + lean, -44 + bob, 3, 4, CAPE)
	_r(-2 + lean, -45 + bob, 2, 2, CAPE.lightened(0.12))
	_r(2 + lean, -43 + bob, 2, 2, CAPE_DARK)

	# sword arm
	if atk > 0.35:
		# extended thrust, blade forward
		_r(7 + lean, -23 + bob, 6, 3, TEAL)
		_r(12 + lean, -23 + bob, 4, 3, BOOT)
		_r(14 + lean, -25 + bob, 2, 6, GOLD)
		_r(16 + lean, -24 + bob, 11, 2, STEEL_LIGHT)
		_r(16 + lean, -23 + bob, 11, 1, STEEL)
		_r(27 + lean, -24 + bob, 1, 2, Color.WHITE)
	else:
		# sword held low at the right side
		_r(7 + lean, -24 + bob, 3, 8, TEAL)
		_r(7 + lean, -17 + bob, 3, 3, BOOT)
		_r(8 + lean, -32 + bob, 2, 12, STEEL_LIGHT)
		_r(9 + lean, -32 + bob, 1, 12, STEEL)
		_r(6 + lean, -21 + bob, 6, 2, GOLD)
		_r(8 + lean, -19 + bob, 2, 3, BOOT)
		_r(10 + lean, -33 + bob, 1, 1, Color.WHITE)

	# boot scuff / ground contact
	_r(-7 + lean, -1, 4, 1, Color(0, 0, 0, 0.25))
