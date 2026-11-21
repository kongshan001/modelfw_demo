class_name VfxWorld
extends Node2D

# Original 640x360 pixel stage: dusk sky, ruined watchtower, lantern-lit stone
# floor, a 40px knight and a straw training dummy. All shapes are integer pixel
# primitives; no external background art is used.

const W := 640
const H := 360
const GROUND_Y := 300
const PLAYER_POS := Vector2(180, GROUND_Y)
const DUMMY_POS := Vector2(246, GROUND_Y)
const COIN_XS := [352, 404, 462, 524]

var camera: Camera2D
var knight: Knight
var dummy: TrainingDummy
var coins: Array[CoinPickup] = []
var fx_layer: Node2D
var popup_layer: Node2D
var popups: Array[PopupText] = []
var time := 0.0

const SKY_TOP := Color("#0a1020")
const SKY_BOTTOM := Color("#26414e")
const FAR := Color("#101b2b")
const NEAR := Color("#0b1421")
const RUIN := Color("#0a111c")
const GROUND := Color("#20242c")
const GROUND_DARK := Color("#171b22")
const STONE_A := Color("#272e38")
const STONE_B := Color("#2c3440")
const MOSS := Color("#5f7d4d")
const MOSS_LIGHT := Color("#7d9a58")
const MOSS_DARK := Color("#46603a")
const WARM := Color("#ffcf6e")

func setup(lib: FxLibrary) -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = Vector2(W * 0.5, H * 0.5)
	camera.enabled = true
	add_child(camera)

	fx_layer = Node2D.new()
	fx_layer.name = "FXLayer"
	fx_layer.z_index = 20
	add_child(fx_layer)

	popup_layer = Node2D.new()
	popup_layer.name = "PopupLayer"
	popup_layer.z_index = 50
	add_child(popup_layer)

	dummy = TrainingDummy.new()
	dummy.name = "Dummy"
	dummy.position = DUMMY_POS
	dummy.z_index = 10
	add_child(dummy)

	knight = Knight.new()
	knight.name = "Knight"
	knight.position = PLAYER_POS
	knight.z_index = 12
	add_child(knight)

	var coin_def := lib.get_def("coin")
	for i in COIN_XS.size():
		var coin := CoinPickup.new()
		coin.name = "Coin%d" % i
		coin.setup(coin_def, Vector2(COIN_XS[i], GROUND_Y), i)
		add_child(coin)
		coins.append(coin)

func step(dt: float) -> void:
	time += dt
	knight.step(dt)
	dummy.step(dt)
	for coin in coins:
		coin.step(dt)
	for p in popups.duplicate():
		if not p.step(dt):
			popups.erase(p)
			p.queue_free()
	queue_redraw()

func set_shake_offset(offset: Vector2i) -> void:
	camera.offset = Vector2(offset)

func spawn_popup(value: String, at: Vector2, tint: Color, px_scale: int = 2,
		seconds: float = 0.75) -> PopupText:
	var p := PopupText.new()
	p.setup(value, at, tint, px_scale, seconds)
	popup_layer.add_child(p)
	popups.append(p)
	return p

func clear_popups() -> void:
	for p in popups:
		p.queue_free()
	popups.clear()

func reset_coins() -> void:
	for coin in coins:
		coin.clear()

func collect_coin_index(i: int) -> bool:
	if i < 0 or i >= coins.size():
		return false
	return coins[i].collect()

func collect_coin_at(world_pos: Vector2) -> int:
	var best := -1
	var best_d := 999.0
	for i in coins.size():
		var c := coins[i]
		if not c.is_active():
			continue
		var d := world_pos.distance_to(c.position + Vector2(0, -26))
		if d < 16.0 and d < best_d:
			best_d = d
			best = i
	return best

func active_coin_count() -> int:
	var n := 0
	for c in coins:
		if c.is_active():
			n += 1
	return n

func clear_effects() -> void:
	for child in fx_layer.get_children():
		child.queue_free()
	clear_popups()

# ── stage painting ─────────────────────────────────────────────────────────────

func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(round(x), round(y), w, h), c)

func _draw() -> void:
	# overscan so a 2-3px camera shake never exposes the clear colour
	draw_rect(Rect2(-8, -8, W + 16, H + 16), Color("#070a12"))
	_sky()
	_aurora()
	_stars()
	_moon()
	_clouds()
	_birds()
	_moonbeam()
	_mountains()
	_ruins()
	_fence()
	_ground()
	_props()
	_ambient()

func _sky() -> void:
	for i in 14:
		var k := float(i) / 13.0
		var y := i * 20
		draw_rect(Rect2(-8, y, W + 16, 21), SKY_TOP.lerp(SKY_BOTTOM, k))
	# band of pale teal right above the horizon
	draw_rect(Rect2(-8, 244, W + 16, 10), Color("#2e4d56"))
	draw_rect(Rect2(-8, 254, W + 16, 8), Color("#243b47"))

func _stars() -> void:
	for i in 48:
		var x := float(int(i * 109.3) % 648) - 4
		var y := float(int(i * 57.7) % 214) + 6
		if absf(x - 530.0) < 30.0 and absf(y - 96.0) < 30.0:
			continue
		var tw := 0.30 + 0.40 * (0.5 + 0.5 * sin(time * 1.4 + i * 1.7))
		var c := Color(0.72, 0.84, 0.92, tw)
		draw_rect(Rect2(x, y, 1, 1), c)
		if i % 9 == 0:
			draw_rect(Rect2(x + 1, y, 1, 1), Color(c.r, c.g, c.b, tw * 0.5))

func _moon() -> void:
	var cx := 530.0
	var cy := 96.0
	# stepped halo
	for rad in [30, 26, 22]:
		var a := 0.035 if rad == 30 else (0.05 if rad == 26 else 0.065)
		_pixel_circle(cx, cy, rad, Color(0.63, 0.82, 0.86, a))
	_pixel_circle(cx, cy, 18, Color("#bcd6d4"))
	_pixel_circle(cx - 2, cy - 2, 14, Color("#d7e9e4"))
	# craters
	draw_rect(Rect2(cx - 8, cy - 6, 5, 4), Color("#a8c5c2"))
	draw_rect(Rect2(cx + 3, cy + 2, 4, 3), Color("#a8c5c2"))
	draw_rect(Rect2(cx - 3, cy + 7, 3, 2), Color("#a8c5c2"))
	draw_rect(Rect2(cx + 6, cy - 9, 2, 2), Color("#b6d1ce"))

func _pixel_circle(cx: float, cy: float, rad: int, c: Color) -> void:
	for y in range(-rad, rad + 1):
		var half := int(floor(sqrt(float(rad * rad - y * y))))
		draw_rect(Rect2(cx - half, cy + y, half * 2 + 1, 1), c)

func _clouds() -> void:
	var drift := int(time * 1.5) % 720
	_r(-40 + drift, 168, 90, 4, Color(0.55, 0.72, 0.78, 0.10))
	_r(-16 + drift, 172, 56, 3, Color(0.55, 0.72, 0.78, 0.08))
	_r(330 - drift, 196, 120, 3, Color(0.55, 0.72, 0.78, 0.07))
	_r(360 - drift, 192, 64, 4, Color(0.55, 0.72, 0.78, 0.09))

func _aurora() -> void:
	var t := time * 0.06
	for band in 2:
		var pts := PackedVector2Array()
		var top := 92.0 + band * 24.0
		for i in 21:
			var x := -20.0 + i * 34.0
			pts.append(Vector2(x, top + sin(i * 0.8 + t * 2.0 + band * 1.7) * 10.0))
		for i in range(20, -1, -1):
			var x := -20.0 + i * 34.0
			pts.append(Vector2(x, top + 27.0 + sin(i * 0.8 + t * 2.0 + band * 1.7) * 10.0))
		var c := Color(0.18, 0.52, 0.52, 0.085) if band == 0 else Color(0.38, 0.26, 0.55, 0.065)
		draw_colored_polygon(pts, c)
	# thin bright fringe
	for k in 2:
		var yy := 118.0 + k * 20.0 + sin(time * 0.4 + k) * 3.0
		_r(-8, yy, W + 16, 1, Color(0.35, 0.75, 0.72, 0.07))

func _birds() -> void:
	var c := Color(0.05, 0.08, 0.12, 0.9)
	for i in 3:
		var x := fmod(time * 9.0 + i * 240.0, 760.0) - 80.0
		var y := 118.0 + i * 17.0 + sin(time * 0.7 + i * 1.3) * 4.0
		var wing := 1.0 if sin(time * 5.0 + i * 1.3) > 0.0 else -1.0
		draw_rect(Rect2(x, y, 1, 1), c)
		draw_rect(Rect2(x - 1, y - wing, 1, 1), c)
		draw_rect(Rect2(x + 1, y - wing, 1, 1), c)

func _moonbeam() -> void:
	var drift := sin(time * 0.25) * 4.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(514 + drift, 112), Vector2(548 + drift, 112),
		Vector2(636, 300), Vector2(468, 300),
	]), Color(0.58, 0.84, 0.82, 0.028))
	draw_colored_polygon(PackedVector2Array([
		Vector2(522 + drift, 112), Vector2(542 + drift, 112),
		Vector2(604, 300), Vector2(504, 300),
	]), Color(0.70, 0.92, 0.88, 0.022))

func _mountains() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 264), Vector2(52, 216), Vector2(108, 244), Vector2(176, 202),
		Vector2(240, 246), Vector2(308, 214), Vector2(378, 250), Vector2(452, 218),
		Vector2(524, 248), Vector2(590, 226), Vector2(648, 246), Vector2(648, 304),
		Vector2(-8, 304),
	]), FAR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 282), Vector2(66, 244), Vector2(140, 268), Vector2(210, 238),
		Vector2(282, 274), Vector2(348, 246), Vector2(418, 278), Vector2(492, 252),
		Vector2(560, 276), Vector2(616, 258), Vector2(648, 262), Vector2(648, 312),
		Vector2(-8, 312),
	]), NEAR)
	# mist
	draw_rect(Rect2(-8, 258, W + 16, 6), Color(0.18, 0.28, 0.34, 0.35))
	draw_rect(Rect2(-8, 264, W + 16, 8), Color(0.16, 0.25, 0.30, 0.22))

func _ruins() -> void:
	# broken watchtower on the left
	_r(40, 178, 34, 122, RUIN)
	_r(36, 174, 42, 6, RUIN)
	for i in 4:
		_r(37 + i * 11, 168, 7, 10, RUIN)
	_r(48, 214, 4, 6, Color("#d6a33c"))
	_r(49, 215, 2, 4, WARM)
	_r(61, 240, 3, 5, Color("#2c4350"))
	_r(62, 242, 1, 2, Color("#62c8f4"))
	_r(70, 190, 2, 40, Color("#05090f"))
	_r(40, 280, 34, 20, Color("#0d1521"))
	# collapsed arch on the right
	_r(428, 214, 10, 86, RUIN)
	_r(486, 226, 10, 74, RUIN)
	_r(428, 206, 68, 8, RUIN)
	_r(444, 206, 12, 4, Color("#070b14"))
	_r(470, 206, 10, 4, Color("#070b14"))
	_r(430, 250, 62, 3, Color("#111c2a"))
	_r(438, 244, 2, 2, Color("#62c8f4"))
	_r(480, 258, 2, 2, Color("#f2cf70"))
	# hanging chain
	for i in 6:
		_r(468, 214 + i * 4, 1, 2, Color("#2b3a46"))
	# moonlit stone edges so the silhouettes read
	_r(74, 180, 1, 116, Color("#1a2a38"))
	_r(40, 178, 1, 116, Color("#1a2a38"))
	_r(428, 214, 1, 86, Color("#1a2a38"))
	_r(495, 226, 1, 74, Color("#1a2a38"))
	# torn banner hanging from the arch
	draw_colored_polygon(PackedVector2Array([
		Vector2(446, 214), Vector2(462, 214), Vector2(460, 240), Vector2(454, 234),
		Vector2(448, 242),
	]), Color("#1e4a52"))
	_r(450, 218, 6, 1, Color("#2f6b6a"))
	_r(452, 224, 2, 2, Color("#d6a33c"))
	# ivy on the tower and arch
	_r(72, 236, 1, 20, Color("#2c4a31"))
	_r(73, 246, 1, 12, Color("#3b5f3b"))
	_r(430, 260, 1, 18, Color("#2c4a31"))
	_r(431, 270, 1, 10, Color("#3b5f3b"))

func _fence() -> void:
	var wood := Color("#1a1511")
	var wood_hi := Color("#2c211a")
	var moss := Color("#2f4a2d")
	var posts := [110, 174, 238, 302, 366, 430, 494, 558]
	for px in posts:
		_r(px, 280, 3, 22, wood)
		_r(px, 280, 1, 22, wood_hi)
		_r(px - 1, 278, 5, 2, wood_hi)
		_r(px, 288, 3, 1, moss)
	# two rails with a broken gap in the middle
	for rail_y in [285, 292]:
		_r(92, rail_y, 198, 2, wood)
		_r(92, rail_y, 198, 1, wood_hi)
		_r(382, rail_y, 194, 2, wood)
		_r(382, rail_y, 194, 1, wood_hi)
	# leaning planks + tufts
	_r(330, 278, 2, 22, wood_hi)
	_r(336, 282, 2, 16, wood)
	_r(120, 276, 1, 5, moss)
	_r(121, 274, 1, 4, Color("#46603a"))
	_r(508, 276, 1, 6, moss)

func _ground() -> void:
	draw_rect(Rect2(-8, 300, W + 16, 60), GROUND)
	# mossy surface lip
	draw_rect(Rect2(-8, 296, W + 16, 6), MOSS_DARK)
	draw_rect(Rect2(-8, 296, W + 16, 2), MOSS)
	draw_rect(Rect2(-8, 298, W + 16, 2), MOSS_LIGHT.darkened(0.18))
	# warm lantern pools on the floor
	_r(10, 301, 58, 3, Color(1.0, 0.78, 0.40, 0.10))
	_r(20, 304, 40, 3, Color(1.0, 0.78, 0.40, 0.06))
	_r(574, 301, 54, 3, Color(1.0, 0.78, 0.40, 0.09))
	_r(586, 304, 34, 3, Color(1.0, 0.78, 0.40, 0.05))

	# stone floor tiles
	for row in 6:
		var y := 304 + row * 10
		var stagger := 14 if row % 2 == 1 else 0
		for col in 24:
			var x := -20 + col * 28 + stagger
			var c := STONE_A if (row + col) % 2 == 0 else STONE_B
			draw_rect(Rect2(x, y, 26, 8), c)
			draw_rect(Rect2(x, y, 26, 1), c.lightened(0.10))
			draw_rect(Rect2(x, y + 7, 26, 1), GROUND_DARK)
	# arena ring inlay, with a faint pulse
	var pulse := 0.10 + 0.04 * sin(time * 1.7)
	_pixel_ellipse(258, 307, 118, 8, Color(0.36, 0.44, 0.50, 0.95))
	_pixel_ellipse(258, 307, 110, 6, Color(0.20, 0.26, 0.32, 0.85))
	_pixel_ellipse(258, 307, 104, 5, Color(0.35, 0.80, 0.82, pulse))
	for i in 8:
		var a := i * TAU / 8.0 + 0.2
		var rx := int(round(cos(a) * 112.0))
		var ry := int(round(sin(a) * 6.0))
		_r(258 + rx - 1, 307 + ry - 1, 3, 3, Color("#5f7d4d"))
		_r(258 + rx, 307 + ry, 1, 1, Color("#a6ecff"))
	for i in 4:
		var a := i * TAU / 4.0 + 0.6
		var rx := int(round(cos(a) * 104.0))
		var ry := int(round(sin(a) * 5.0))
		_r(258 + rx, 307 + ry, 2, 1, Color(0.55, 0.90, 0.90, 0.45))
	# drifting ground fog
	_r(-8, 286, W + 16, 5, Color(0.35, 0.48, 0.52, 0.06))
	_r(-8, 293, W + 16, 4, Color(0.35, 0.48, 0.52, 0.04))
	# cracks + pebbles
	_r(160, 326, 18, 1, GROUND_DARK)
	_r(178, 327, 6, 1, GROUND_DARK)
	_r(392, 338, 22, 1, GROUND_DARK)
	_r(412, 337, 5, 1, GROUND_DARK)
	_r(300, 318, 2, 1, Color("#3a4350"))
	_r(452, 324, 3, 1, Color("#3a4350"))
	_r(518, 346, 2, 1, Color("#3a4350"))
	# grass tufts on the lip
	for i in 16:
		var x := 12 + (i * 41) % 616
		var h := 2 + (i * 7) % 3
		_r(x, 296 - h, 1, h, MOSS_LIGHT)
		if i % 3 == 0:
			_r(x + 2, 297 - h, 1, h - 1, MOSS)
	# a couple of pale flowers
	_r(96, 292, 1, 1, Color("#efe0ba"))
	_r(353, 294, 1, 1, Color("#ffd2f6"))
	_r(552, 292, 1, 1, Color("#a6ecff"))

func _pixel_ellipse(cx: float, cy: float, rx: int, ry: int, c: Color) -> void:
	for y in range(-ry, ry + 1):
		if ry == 0:
			continue
		var half := int(round(float(rx) * sqrt(maxf(0.0, 1.0 - float(y * y) / float(ry * ry)))))
		draw_rect(Rect2(cx - half, cy + y, half * 2 + 1, 1), c)

func _props() -> void:
	# left lantern post
	_r(24, 208, 4, 92, Color("#241a14"))
	_r(24, 208, 1, 92, Color("#3b2a1e"))
	_r(14, 208, 24, 3, Color("#241a14"))
	_r(14, 208, 24, 1, Color("#3b2a1e"))
	_lantern(34, 214)
	# right lantern, hanging from the arch
	_r(600, 222, 3, 78, Color("#241a14"))
	_r(600, 222, 1, 78, Color("#3b2a1e"))
	_lantern(606, 230)
	# moss on the lantern posts
	_r(24, 264, 1, 8, MOSS_DARK)
	_r(27, 276, 1, 5, MOSS)
	# small signpost
	_r(560, 278, 3, 22, Color("#3a2a1f"))
	_r(546, 264, 30, 15, Color("#2c211a"))
	_r(548, 266, 26, 11, Color("#3d2c20"))
	_r(551, 269, 20, 1, Color("#8f7440"))
	_r(551, 272, 15, 1, Color("#8f7440"))
	# hay bale behind the knight
	_r(60, 284, 28, 16, Color("#3a2c16"))
	_r(62, 282, 24, 16, Color("#8f7440"))
	_r(64, 280, 20, 4, Color("#c9a24e"))
	_r(66, 280, 16, 1, Color("#e3bd68"))
	_r(62, 290, 24, 2, Color("#4a3324"))
	_r(70, 284, 2, 8, Color("#6b4a2f"))
	_r(80, 284, 2, 8, Color("#6b4a2f"))
	# barrel at the right edge
	_r(594, 278, 22, 22, Color("#3b2a1e"))
	_r(596, 276, 18, 24, Color("#5a3a26"))
	_r(596, 276, 18, 2, Color("#8a6238"))
	_r(596, 284, 18, 2, Color("#2c211a"))
	_r(596, 294, 18, 2, Color("#2c211a"))
	_r(604, 277, 2, 22, Color("#7a5230"))
	_r(600, 280, 1, 16, Color("#8a6238"))
	# mushrooms
	_r(116, 290, 1, 4, Color("#ded6c2"))
	_r(114, 287, 5, 3, Color("#b5433f"))
	_r(115, 286, 3, 1, Color("#d8625c"))
	_r(130, 294, 1, 3, Color("#ded6c2"))
	_r(128, 292, 5, 2, Color("#9c7531"))
	_r(129, 291, 3, 1, Color("#c9a24e"))
	# tattered banner hanging over the right side of the arena
	var sway := int(round(sin(time * 0.8) * 1.0))
	_r(600 + sway, 40, 26, 2, Color("#241a14"))
	_r(602 + sway, 42, 22, 104, Color("#0f252c"))
	_r(604 + sway, 44, 18, 100, Color("#173a42"))
	_r(605 + sway, 44, 2, 98, Color("#24555a"))
	_r(620 + sway, 44, 2, 98, Color("#0c2026"))
	# tattered hem
	_r(604 + sway, 140, 5, 6, Color("#173a42"))
	_r(612 + sway, 140, 6, 10, Color("#173a42"))
	_r(621 + sway, 140, 4, 5, Color("#0f252c"))
	# gold rune
	_r(611 + sway, 78, 4, 4, Color("#d6a33c"))
	_r(609 + sway, 82, 8, 2, Color("#d6a33c"))
	_r(612 + sway, 84, 2, 6, Color("#f2cf70"))
	_r(610 + sway, 92, 6, 1, Color("#8a6238"))
	# rope knot + a small bell
	_r(608 + sway, 40, 2, 4, Color("#5a3a26"))
	_r(618 + sway, 40, 2, 4, Color("#5a3a26"))

func _lantern(x: float, y: float) -> void:
	# warm stepped halo
	_pixel_circle(x + 4, y + 7, 22, Color(1.0, 0.78, 0.40, 0.035))
	_pixel_circle(x + 4, y + 7, 15, Color(1.0, 0.78, 0.40, 0.055))
	_pixel_circle(x + 4, y + 7, 10, Color(1.0, 0.78, 0.40, 0.09))
	# frame
	_r(x, y, 9, 14, Color("#17110c"))
	_r(x + 1, y + 1, 7, 3, Color("#3b2a1e"))
	_r(x + 1, y + 4, 7, 7, Color(1.0, 0.82, 0.45, 0.92))
	_r(x + 2, y + 5, 3, 4, WARM)
	_r(x + 2, y + 5, 1, 3, Color("#fff3c4"))
	_r(x + 1, y + 11, 7, 2, Color("#17110c"))
	_r(x + 2, y + 13, 5, 1, Color("#3b2a1e"))
	_r(x + 3, y - 2, 1, 3, Color("#2b3a46"))

func _ambient() -> void:
	var motes := [
		Vector2(112, 266), Vector2(208, 246), Vector2(318, 272), Vector2(438, 252),
		Vector2(556, 268), Vector2(84, 232), Vector2(486, 286),
	]
	for i in motes.size():
		var base: Vector2 = motes[i]
		var x := base.x + sin(time * 0.7 + i * 1.9) * 9.0
		var y := base.y + sin(time * 1.1 + i * 2.7) * 5.0
		var a := 0.35 + 0.35 * (0.5 + 0.5 * sin(time * 2.0 + i))
		draw_rect(Rect2(round(x), round(y), 1, 1), Color(1.0, 0.92, 0.60, a))
		draw_rect(Rect2(round(x) - 1, round(y), 1, 1), Color(1.0, 0.82, 0.42, a * 0.45))
		draw_rect(Rect2(round(x) + 1, round(y), 1, 1), Color(1.0, 0.82, 0.42, a * 0.45))
		draw_rect(Rect2(round(x), round(y) - 1, 1, 1), Color(1.0, 0.82, 0.42, a * 0.45))
		draw_rect(Rect2(round(x), round(y) + 1, 1, 1), Color(1.0, 0.82, 0.42, a * 0.45))
