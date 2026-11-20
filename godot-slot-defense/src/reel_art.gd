extends RefCounted

# Procedural pixel-art factory for Reelward.
# Everything is generated at runtime from Image primitives:
#   - six 32x32 reel symbols with ink outlines, lit/shadow faces and accents
#   - 16x14 hearts, a 16x16 coin, 64x64 glow and 160x90 vignette textures
#   - pre-baked parallax backdrop layers (sky, clouds, mountains, temple,
#     ruins, ground, fog) drawn once and reused every frame for performance.
# No external images, fonts or third-party assets.

const S := 32
const SKY_W := 320
const SKY_H := 245
const CLOUD_W := 320
const CLOUD_H := 120
const MTN_W := 320
const MTN_H := 120
const TEMPLE_W := 320
const TEMPLE_H := 180
const RUIN_W := 320
const RUIN_H := 110
const GROUND_W := 320
const GROUND_H := 80
const FOG_W := 320
const FOG_H := 48

const INK := Color("#140e22")
const INK_SOFT := Color("#241936")
const WHITE := Color("#fff6e8")
const BONE := Color("#f4e6c8")
const BONE_DK := Color("#c9a978")
const STEEL_D := Color("#3f4f76")
const STEEL := Color("#7d94c9")
const STEEL_L := Color("#c9d8f5")
const BRASS_D := Color("#8a5a1c")
const BRASS := Color("#e0a94a")
const BRASS_L := Color("#ffe6a6")
const LEAF_D := Color("#235c3e")
const LEAF := Color("#48b070")
const LEAF_L := Color("#9ef0b2")
const ROYAL_D := Color("#1e3768")
const ROYAL := Color("#3e6fcf")
const ROYAL_L := Color("#8fc4ff")
const ARC_D := Color("#3b1f66")
const ARC := Color("#9a5ce0")
const ARC_L := Color("#e2c2ff")
const EMBER_D := Color("#8f3d1c")
const EMBER := Color("#e07a3f")
const EMBER_L := Color("#ffc888")
const CRIM_D := Color("#75172f")
const CRIM := Color("#d94a68")
const CRIM_L := Color("#ff9db0")
const CYAN_D := Color("#0d5a63")
const CYAN := Color("#35d8d0")
const CYAN_L := Color("#b9fff4")
const LEATHER := Color("#5a3b2a")
const LEATHER_L := Color("#8a5f3c")


static func build_symbol_textures() -> Dictionary:
	var out := {}
	out["blade"] = _tex(_blade())
	out["bow"] = _tex(_bow())
	out["shield"] = _tex(_shield())
	out["steed"] = _tex(_steed())
	out["orb"] = _tex(_orb())
	out["crown"] = _tex(_crown())
	return out


static func symbol_color(symbol: String) -> Color:
	match symbol:
		"blade": return STEEL_L
		"bow": return LEAF
		"shield": return ROYAL
		"steed": return EMBER
		"orb": return ARC
		"crown": return BRASS
	return Color.WHITE


static func symbol_dark(symbol: String) -> Color:
	match symbol:
		"blade": return STEEL_D
		"bow": return LEAF_D
		"shield": return ROYAL_D
		"steed": return EMBER_D
		"orb": return ARC_D
		"crown": return BRASS_D
	return INK


# 16x14 hearts with ink outline, two-tone shading and a specular glint.
static func build_heart_textures() -> Dictionary:
	var rows := [
		"....kk....kk....",
		"..kkRRkkkkRRkk..",
		".kRRLLRRRRRRRRk.",
		"kRRLLRRRRRRRRRRk",
		"kRLRRRRRRRRRRRRk",
		"kRRRRRRRRRRRRRRk",
		"kRRRRRRRRRRRRRRk",
		".kRRRRRRRRRRRRk.",
		"..kRRRRRRRRRRk..",
		"...kRRRRRRRRk...",
		"....kRRRRRRk....",
		".....kRRRRk.....",
		"......kRRk......",
		".......kk.......",
	]
	var full := Image.create(16, 14, false, Image.FORMAT_RGBA8)
	var empty := Image.create(16, 14, false, Image.FORMAT_RGBA8)
	full.fill(Color(0, 0, 0, 0))
	empty.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var line: String = rows[y]
		for x in 16:
			match line[x]:
				"k":
					full.set_pixel(x, y, INK)
					empty.set_pixel(x, y, INK)
				"R":
					full.set_pixel(x, y, Color("#e8485f"))
					empty.set_pixel(x, y, Color("#33243f"))
				"L":
					full.set_pixel(x, y, Color("#ff9db0"))
					empty.set_pixel(x, y, Color("#4a3558"))
	full.set_pixel(3, 3, Color("#ffd2da"))
	full.set_pixel(3, 4, Color("#ffb3c1"))
	empty.set_pixel(5, 4, Color("#55405f"))
	return {"full": _tex(full), "empty": _tex(empty)}


# 16x16 gold coin with rim, embossed diamond and specular crescent.
static func build_coin_texture() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_disc(img, 8, 8, 7, INK)
	_disc(img, 8, 8, 6, BRASS_D)
	_disc(img, 8, 8, 5, BRASS)
	_disc(img, 7, 7, 4, Color("#f0c063"))
	for i in 3:
		img.set_pixel(5 + i, 8, BRASS_L)
		img.set_pixel(8, 5 + i, BRASS_L)
		img.set_pixel(10 - i, 8, BRASS_D)
		img.set_pixel(8, 10 - i, BRASS_D)
	img.set_pixel(8, 8, BONE)
	img.set_pixel(5, 5, Color("#fff3c8"))
	img.set_pixel(6, 4, Color("#ffe6a6"))
	return _tex(img)


# Soft radial glow: white RGBA, tinted at draw time.
static func build_glow_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for y in 64:
		for x in 64:
			var dx := (x - 31.5) / 31.5
			var dy := (y - 31.5) / 31.5
			var d := sqrt(dx * dx + dy * dy)
			if d >= 1.0:
				continue
			var a := pow(1.0 - d, 2.4)
			var band := 0.86 + 0.14 * sin(float(x * 7 + y * 13))
			img.set_pixel(x, y, Color(1, 1, 1, a * band))
	return _tex(img)


# Screen-edge darkening; stretched over the whole view.
static func build_vignette_texture() -> ImageTexture:
	var w := 320
	var h := 180
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var dx := absf((x + 0.5) / w * 2.0 - 1.0)
			var dy := absf((y + 0.5) / h * 2.0 - 1.0)
			var d := sqrt(dx * dx * 0.85 + dy * dy * 1.15)
			var a := clampf((d - 0.42) / 0.58, 0.0, 1.0)
			a = a * a * 0.72
			if a > 0.001:
				img.set_pixel(x, y, Color(0.02, 0.01, 0.05, a))
	return _tex(img)


# Static cabinet chrome baked once: shell, brass bevel, marquee glass + bulb
# sockets, reel-bay frame, lever base and rivets. Dynamic elements (titles,
# reels, lever arm, button labels) are drawn on top by the game.
static func build_cabinet_shell() -> ImageTexture:
	var w := 580
	var h := 596
	var img := _blank(w, h)
	_rect(img, 0, 0, w, h, Color("#090610"))
	_rect(img, 5, 5, w - 10, h - 10, Color("#241735"))
	_rect(img, 9, 9, w - 18, h - 18, Color("#8a5a1c"))
	_rect(img, 12, 12, w - 24, h - 24, Color("#e0a94a"))
	_rect(img, 15, 15, w - 30, h - 30, Color("#6f4a18"))
	_rect(img, 16, 16, w - 32, h - 32, Color("#151021"))
	# brushed inner panel
	for i in 12:
		var t := float(i) / 11.0
		_rect(img, 18, 18 + i * 47, w - 36, 48, Color("#1b1330").lerp(Color("#100b1c"), t))
	# bevel light / shade edges
	_rect(img, 12, 12, w - 24, 1, Color("#ffe6a6"))
	_rect(img, 12, 12, 1, h - 24, Color(1.0, 0.9, 0.62, 0.7))
	_rect(img, 12, h - 13, w - 24, 1, Color("#5a3a12"))
	_rect(img, w - 13, 12, 1, h - 24, Color("#5a3a12"))
	# corner brackets
	for corner in [[8, 10, 1, 1], [572, 10, -1, 1], [8, 586, 1, -1], [572, 586, -1, -1]]:
		var cx: int = int(corner[0])
		var cy: int = int(corner[1])
		var sx: int = int(corner[2])
		var sy: int = int(corner[3])
		var rx := cx if sx > 0 else cx - 26
		var ry := cy if sy > 0 else cy - 6
		_rect(img, rx, ry, 26, 6, Color("#e0a94a"))
		var rx2 := cx if sx > 0 else cx - 6
		var ry2 := cy if sy > 0 else cy - 26
		_rect(img, rx2, ry2, 6, 26, Color("#e0a94a"))
		_rect(img, rx, ry, 26, 2, Color("#ffe6a6"))
		_disc(img, cx + 17 * sx, cy + 17 * sy, 2, Color("#4a2f12"))
		_px(img, cx + 16 * sx, cy + 16 * sy, Color("#ffe6a6"))
	# side rails + rivets
	for i in 12:
		var ry := 88 + i * 42
		_disc(img, 10, ry, 2, Color("#4a3566"))
		_disc(img, 570, ry, 2, Color("#4a3566"))
	# marquee glass + sockets
	var mx := 20
	var my := 14
	var mw := 540
	var mh := 50
	_rect(img, mx, my + 4, mw, mh, Color("#05030a"))
	_rect(img, mx, my, mw, mh, Color("#0d0818"))
	_rect(img, mx, my, mw, 4, Color("#8a5a1c"))
	_rect(img, mx, my + mh - 4, mw, 4, Color("#8a5a1c"))
	_rect(img, mx + 4, my + 4, mw - 8, 1, Color("#e0a94a"))
	_rect(img, mx + 4, my + mh - 5, mw - 8, 1, Color("#e0a94a"))
	for i in 8:
		var ly := my + 8 + i * 5
		_rect(img, mx + 6, ly, mw - 12, 1, Color(0.3, 0.18, 0.45, 0.16))
	for i in 20:
		var bx := mx + 36 + i * 22
		_disc(img, bx, my + 3, 2, Color("#4a2f12"))
		_disc(img, bx, my + mh - 3, 2, Color("#4a2f12"))
	# reel bay frame + inner depth
	var bx := 84
	var by := 74
	var bw := 416
	var bh := 408
	_rect(img, bx, by + 5, bw, bh, Color(0, 0, 0, 0.55))
	_rect(img, bx, by, bw, bh, Color("#060410"))
	_rect(img, bx, by, bw, 6, Color("#07050d"))
	_rect(img, bx, by + bh - 6, bw, 6, Color("#07050d"))
	_rect(img, bx, by, 6, bh, Color("#07050d"))
	_rect(img, bx + bw - 6, by, 6, bh, Color("#07050d"))
	_rect(img, bx + 2, by + 2, bw - 4, 3, Color("#8a5a1c"))
	_rect(img, bx + 2, by + bh - 5, bw - 4, 3, Color("#8a5a1c"))
	_rect(img, bx + 2, by + 2, 3, bh - 4, Color("#8a5a1c"))
	_rect(img, bx + bw - 5, by + 2, 3, bh - 4, Color("#8a5a1c"))
	_rect(img, bx + 5, by + 5, bw - 10, 1, Color("#e0a94a"))
	for i in 5:
		_rect(img, bx + 6, by + 6 + i * 4, bw - 12, 4, Color(0, 0, 0, 0.10 - i * 0.018))
	for i in 6:
		_rect(img, bx + 7, by + 7 + i * 66, bw - 14, 1, Color(0.25, 0.15, 0.35, 0.18))
	# payline lamp sockets on the left rail
	for i in 8:
		_disc(img, 68, 102 + i * 22, 3, Color("#2a1b3c"))
	# lever base
	_rect(img, 498, 430, 60, 22, Color("#120d1d"))
	_rect(img, 498, 430, 60, 2, Color("#8a5a1c"))
	_rect(img, 498, 450, 60, 2, Color("#8a5a1c"))
	_disc(img, 504, 441, 2, Color("#8a5a1c"))
	_disc(img, 552, 441, 2, Color("#8a5a1c"))
	# bottom trim
	_disc(img, 290, 588, 4, Color("#8a5a1c"))
	return _tex(img)


# Nine reel-cell backplates baked into one texture (icons stay dynamic).
static func build_reel_cells() -> ImageTexture:
	var img := _blank(416, 408)
	for c in 3:
		for r in 3:
			var x := 16 + c * 128
			var y := 12 + r * 128
			_rect(img, x, y, 116, 116, Color("#0a0712"))
			for i in 4:
				_rect(img, x, y + i * 29, 116, 30,
					Color("#151024").lerp(Color("#0b0814"), float(i) / 3.0))
			_rect(img, x, y, 116, 3, Color("#2c2140"))
			_rect(img, x, y, 3, 116, Color("#221934"))
			_rect(img, x + 1, y + 1, 114, 1, Color("#2a2040"))
			_rect(img, x, y + 115, 116, 1, Color("#2a2040"))
			_rect(img, x + 115, y, 1, 116, Color("#2a2040"))
			_rect(img, x + 4, y + 4, 108, 1, Color(0, 0, 0, 0.35))
			_rect(img, x + 6, y + 110, 104, 2, Color(0, 0, 0, 0.3))
			# baked violet bloom (replaces per-cell runtime glow quads)
			for by in 116:
				for bx in 116:
					var dx := (bx - 57.5) / 52.0
					var dy := (by - 55.5) / 52.0
					var d := dx * dx + dy * dy
					if d >= 1.0:
						continue
					var a := (1.0 - d) * (1.0 - d) * 0.18
					_over(img, x + bx, y + by, Color(0.55, 0.38, 0.9, a))
	return _tex(img)


# Spin button plate, pre-baked for ready / disabled states.
static func build_spin_button(ready: bool) -> ImageTexture:
	var img := _blank(300, 48)
	var top := Color("#f0bd5a") if ready else Color("#3b2b4d")
	var bottom := Color("#8f5f22") if ready else Color("#1d1530")
	for i in 48:
		_rect(img, 0, i, 300, 1, top.lerp(bottom, float(i) / 47.0))
	var border := Color("#ffe3a8") if ready else Color("#8f5f22")
	_rect(img, 0, 0, 300, 2, border)
	_rect(img, 0, 46, 300, 2, border)
	_rect(img, 0, 0, 2, 48, border)
	_rect(img, 298, 0, 2, 48, border)
	_rect(img, 4, 3, 292, 2, Color(1.0, 0.95, 0.75, 0.65) if ready else Color(1, 1, 1, 0.05))
	_rect(img, 4, 43, 292, 2, Color("#5a3a12") if ready else Color("#0e0917"))
	_rect(img, 2, 2, 296, 1, Color(0, 0, 0, 0.25))
	return _tex(img)


# Whole-screen ambience behind the cabinet / battle frames: gradient + stars
# + faint nebula, baked once so the page background costs a single quad.
static func build_page_sky() -> ImageTexture:
	var w := 640
	var h := 360
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / float(h)
		var c: Color
		if t < 0.55:
			c = Color("#05050c").lerp(Color("#0d0a19"), t / 0.55)
		elif t < 0.85:
			c = Color("#0d0a19").lerp(Color("#221329"), (t - 0.55) / 0.30)
		else:
			c = Color("#221329").lerp(Color("#3a1f3a"), (t - 0.85) / 0.15)
		img.set_pixel(0, y, c)
		for x in range(1, w):
			var n := (_hash01(x, y, 11) - 0.5) * 0.010
			img.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in 60:
		var cx := rng.randi_range(0, w)
		var cy := rng.randi_range(0, 240)
		var rx := rng.randi_range(20, 80)
		var ry := rng.randi_range(6, 22)
		var tint := Color("#3a2a6a") if i % 2 == 0 else Color("#1d3a5a")
		_blob(img, cx, cy, rx, ry, tint, rng.randf_range(0.02, 0.05))
	for i in 220:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, h - 70)
		var bright := rng.randf()
		var c := Color(1, 1, 1)
		if bright > 0.85:
			c = Color("#ffe6a6")
		elif bright > 0.7:
			c = Color("#9ff4ff")
		_px(img, x, y, Color(c.r, c.g, c.b, 0.20 + bright * 0.6))
		if bright > 0.93:
			_px(img, x - 1, y, Color(c.r, c.g, c.b, 0.25))
			_px(img, x + 1, y, Color(c.r, c.g, c.b, 0.25))
			_px(img, x, y - 1, Color(c.r, c.g, c.b, 0.25))
			_px(img, x, y + 1, Color(c.r, c.g, c.b, 0.25))
	return _tex(img)


# Soft elliptical drop shadow reused by every actor (one quad, no transform).
static func build_shadow_texture() -> ImageTexture:
	var img := _blank(64, 32)
	for y in 32:
		for x in 64:
			var dx := (x - 31.5) / 31.5
			var dy := (y - 15.5) / 15.5
			var d := sqrt(dx * dx + dy * dy)
			if d >= 1.0:
				continue
			var a := (1.0 - d) * (1.0 - d) * 0.55
			img.set_pixel(x, y, Color(0, 0, 0, a))
	return _tex(img)


# All parallax layers, baked once. Layer sizes are intentionally small and
# drawn at 2x with nearest filtering for a chunky pixel-fantasy look.
static func build_backdrop() -> Dictionary:
	var out := {}
	out["sky"] = _tex(_sky_image())
	out["clouds_far"] = _tex(_clouds_image(91, 0.055, 0.030))
	out["clouds_near"] = _tex(_clouds_image(47, 0.085, 0.045))
	out["mountains"] = _tex(_mountains_image())
	out["temple"] = _tex(_temple_image())
	out["ruins"] = _tex(_ruins_image())
	out["ground"] = _tex(_ground_image())
	out["fog"] = _tex(_fog_image())
	return out


# ---------------------------------------------------------------------------
# Image helpers
# ---------------------------------------------------------------------------

static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _blank(w: int = S, h: int = S) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for iy in range(y, y + h):
		for ix in range(x, x + w):
			if ix >= 0 and iy >= 0 and ix < img.get_width() and iy < img.get_height():
				img.set_pixel(ix, iy, c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _over(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
		return
	var d: Color = img.get_pixel(x, y)
	var a: float = c.a + d.a * (1.0 - c.a)
	if a <= 0.002:
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var r := (c.r * c.a + d.r * d.a * (1.0 - c.a)) / a
	var g := (c.g * c.a + d.g * d.a * (1.0 - c.a)) / a
	var b := (c.b * c.a + d.b * d.a * (1.0 - c.a)) / a
	img.set_pixel(x, y, Color(r, g, b, a))


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		_px(img, x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r * r:
				_px(img, x, y, c)


# Add a 1px ink outline around every opaque cluster (does not touch alpha).
static func _outline(img: Image, c: Color = INK) -> void:
	var marks: Array[Vector2i] = []
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.15:
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and img.get_pixel(nx, ny).a > 0.6:
					near = true
					break
			if near:
				marks.append(Vector2i(x, y))
	for m in marks:
		img.set_pixel(m.x, m.y, c)


static func _hash01(x: int, y: int, seed_value: int = 0) -> float:
	var n := (x * 374761393 + y * 668265263 + seed_value * 2147483647) & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177
	n = n & 0x7fffffff
	return float(n) / float(0x7fffffff)


# ---------------------------------------------------------------------------
# 32x32 reel symbols
# ---------------------------------------------------------------------------

# Leaf-bladed sword: lit left edge, shadowed right edge, brass guard, runes.
static func _blade() -> Image:
	var img := _blank()
	var widths := {
		2: 2, 3: 2, 4: 4, 5: 4, 6: 6, 7: 6, 8: 6, 9: 6, 10: 6, 11: 6,
		12: 6, 13: 6, 14: 6, 15: 4, 16: 4, 17: 2,
	}
	for y in widths.keys():
		var w: int = widths[y]
		var x0 := 16 - w / 2
		for i in w:
			var c := STEEL
			if i == 0:
				c = STEEL_L
			elif i == w - 1:
				c = STEEL_D
			elif i == w / 2 and w >= 4:
				c = Color("#eef4ff")
			_px(img, x0 + i, y, c)
	# fuller line + rune glints
	for y in range(5, 15):
		_px(img, 16, y, STEEL_D)
	_px(img, 13, 7, CYAN_L)
	_px(img, 13, 8, CYAN)
	_px(img, 18, 11, CYAN_L)
	_px(img, 18, 12, CYAN)
	_px(img, 15, 3, WHITE)
	# winged crossguard
	_rect(img, 5, 19, 22, 1, BRASS_L)
	_rect(img, 5, 20, 22, 2, BRASS)
	_rect(img, 6, 22, 21, 1, BRASS_D)
	_rect(img, 3, 18, 4, 2, BRASS_L)
	_rect(img, 3, 20, 3, 2, BRASS)
	_rect(img, 25, 18, 4, 2, BRASS_L)
	_rect(img, 26, 20, 3, 2, BRASS)
	_px(img, 2, 18, BRASS)
	_px(img, 29, 18, BRASS)
	_px(img, 3, 19, BRASS_L)
	_px(img, 28, 19, BRASS_L)
	# grip with wrap
	_rect(img, 14, 23, 4, 5, CRIM)
	_px(img, 14, 24, CRIM_D)
	_px(img, 17, 25, CRIM_D)
	_px(img, 14, 26, CRIM_D)
	_px(img, 15, 23, CRIM_L)
	_px(img, 15, 27, CRIM_D)
	# pommel
	_disc(img, 16, 29, 2, BRASS)
	_px(img, 15, 28, BRASS_L)
	_px(img, 15, 30, BRASS_D)
	# ambient sparkles
	_px(img, 6, 6, CYAN_L)
	_px(img, 26, 7, BRASS_L)
	_px(img, 27, 15, CYAN)
	_px(img, 4, 14, BRASS_L)
	_px(img, 24, 4, CYAN)
	_outline(img)
	return img


# Recurve bow with nocked arrow; leaf wraps on the limbs.
static func _bow() -> Image:
	var img := _blank()
	# back limb arc (outer dark, inner leaf)
	var arc_pts: Array[Vector2i] = []
	for i in range(0, 17):
		var a := deg_to_rad(128.0 + 6.5 * float(i))
		arc_pts.append(Vector2i(19 + int(cos(a) * 12.0), 16 + int(sin(a) * 12.0)))
	for i in arc_pts.size():
		var p: Vector2i = arc_pts[i]
		_disc(img, p.x, p.y, 1, LEAF_D)
		if i > 0 and i < arc_pts.size() - 1:
			_px(img, p.x - 1, p.y, LEAF)
			_px(img, p.x - 2, p.y, LEAF_L)
	# leaf fletching on the limb tips
	_px(img, 9, 4, LEAF_L)
	_px(img, 8, 5, LEAF)
	_px(img, 9, 28, LEAF_L)
	_px(img, 8, 27, LEAF)
	# grip
	_rect(img, 5, 13, 3, 6, LEATHER)
	_rect(img, 5, 14, 3, 1, LEATHER_L)
	_rect(img, 5, 16, 3, 1, LEATHER_L)
	_rect(img, 5, 18, 3, 1, LEATHER_L)
	# string
	_line(img, 10, 4, 10, 28, BONE_DK)
	_line(img, 10, 4, 10, 15, BONE)
	_line(img, 10, 17, 10, 28, BONE)
	# arrow
	_rect(img, 10, 15, 16, 2, BONE)
	_rect(img, 10, 16, 16, 1, BONE_DK)
	_px(img, 26, 14, STEEL_L)
	_px(img, 26, 16, STEEL_L)
	_px(img, 27, 15, STEEL)
	_px(img, 28, 15, STEEL_L)
	_px(img, 27, 14, STEEL)
	_px(img, 27, 16, STEEL)
	_px(img, 29, 15, WHITE)
	# fletching
	_px(img, 8, 14, CRIM)
	_px(img, 8, 17, CRIM)
	_px(img, 9, 13, CRIM_L)
	_px(img, 9, 18, CRIM_L)
	_px(img, 7, 15, CRIM_D)
	_px(img, 7, 16, CRIM_D)
	# nock + sparkles
	_px(img, 23, 5, BRASS_L)
	_px(img, 24, 20, CYAN)
	_px(img, 3, 10, BRASS_L)
	_outline(img)
	return img


# Kite shield: royal enamel, brass cross, rivets, lit bevel.
static func _shield() -> Image:
	var img := _blank()
	var rows := {
		4: [8, 16], 5: [7, 18], 6: [7, 18], 7: [7, 18], 8: [6, 20],
		9: [6, 20], 10: [6, 20], 11: [6, 20], 12: [6, 20], 13: [6, 20],
		14: [6, 20], 15: [6, 20], 16: [7, 18], 17: [8, 16], 18: [9, 14],
		19: [10, 12], 20: [11, 10], 21: [12, 8], 22: [13, 6], 23: [14, 4],
		24: [15, 2],
	}
	for y in rows.keys():
		var span: Array = rows[y]
		_rect(img, int(span[0]), y, int(span[1]), 1, ROYAL_D)
	# inner enamel with left light / right shade
	for y in rows.keys():
		var span: Array = rows[y]
		var x0: int = int(span[0]) + 1
		var w: int = int(span[1]) - 2
		if w <= 0:
			continue
		_rect(img, x0, y, w, 1, ROYAL)
		if w >= 3:
			_px(img, x0, y, ROYAL_L)
			_px(img, x0 + 1, y, Color("#5b8ce6"))
			_px(img, x0 + w - 1, y, ROYAL_D)
	# brass trim + rivets
	_rect(img, 8, 4, 16, 1, BRASS)
	_px(img, 7, 5, BRASS)
	_px(img, 24, 5, BRASS)
	for y in range(5, 21):
		var span: Array = rows[y]
		_px(img, int(span[0]), y, BRASS_D)
		_px(img, int(span[0]) + int(span[1]) - 1, y, BRASS_D)
	# cross
	_rect(img, 15, 6, 2, 15, BRASS)
	_rect(img, 9, 12, 14, 2, BRASS)
	_px(img, 15, 6, BRASS_L)
	_px(img, 9, 12, BRASS_L)
	_px(img, 16, 20, BRASS_D)
	_px(img, 22, 13, BRASS_D)
	_disc(img, 16, 13, 2, BONE)
	_px(img, 15, 12, WHITE)
	# rivets
	for p in [Vector2i(9, 6), Vector2i(23, 6), Vector2i(10, 18), Vector2i(21, 18)]:
		_px(img, p.x, p.y, STEEL_L)
		_px(img, p.x + 1, p.y, STEEL)
	# gem
	_px(img, 16, 24, CYAN_L)
	_px(img, 16, 25, CYAN)
	_outline(img)
	return img


# Chess-knight steed bust with brass mane and royal armor plate.
static func _steed() -> Image:
	var img := _blank()
	# ears
	_rect(img, 10, 3, 2, 5, EMBER)
	_px(img, 10, 2, EMBER_L)
	_rect(img, 15, 2, 2, 5, EMBER)
	_px(img, 15, 1, EMBER_L)
	# skull / muzzle
	_rect(img, 8, 6, 12, 7, EMBER)
	_rect(img, 5, 9, 6, 5, EMBER)
	_rect(img, 4, 11, 3, 3, EMBER_D)
	_px(img, 3, 13, EMBER_D)
	# jaw
	_rect(img, 7, 13, 7, 3, EMBER)
	_rect(img, 7, 15, 8, 2, EMBER_D)
	# neck / chest
	for y in range(12, 26):
		var x0 := 12 - maxi(0, (y - 20) / 2)
		var x1 := 22 + maxi(0, (y - 16) / 3)
		_rect(img, x0, y, x1 - x0, 1, EMBER)
	# lit left edges
	for y in range(6, 12):
		_px(img, 8, y, EMBER_L)
	for y in range(12, 24):
		_px(img, 11, y, EMBER_L)
	_px(img, 5, 9, EMBER_L)
	_px(img, 10, 3, EMBER_L)
	# shadow under jaw / right side
	_rect(img, 20, 8, 2, 4, EMBER_D)
	for y in range(14, 25):
		_px(img, 24, y, EMBER_D)
		_px(img, 23, y, EMBER_D)
	# eye + nostril
	_rect(img, 9, 9, 2, 2, INK)
	_px(img, 9, 9, Color("#fff0c0"))
	_px(img, 5, 12, INK)
	# mane: jagged brass running down the right of the neck
	var mane := [
		Vector2i(20, 3), Vector2i(21, 4), Vector2i(21, 5), Vector2i(22, 6),
		Vector2i(22, 7), Vector2i(23, 8), Vector2i(23, 9), Vector2i(24, 10),
		Vector2i(24, 11), Vector2i(25, 12), Vector2i(24, 13), Vector2i(25, 14),
		Vector2i(24, 15), Vector2i(25, 16), Vector2i(24, 17), Vector2i(25, 18),
		Vector2i(24, 19), Vector2i(24, 20),
	]
	for p in mane:
		_px(img, p.x, p.y, BRASS)
		_px(img, p.x + 1, p.y, BRASS_D)
	_px(img, 21, 4, BRASS_L)
	_px(img, 22, 6, BRASS_L)
	_px(img, 23, 9, BRASS_L)
	# armor plate on the chest
	_rect(img, 14, 17, 8, 6, ROYAL_D)
	_rect(img, 15, 17, 6, 5, ROYAL)
	_rect(img, 15, 17, 6, 1, BRASS)
	_rect(img, 15, 21, 6, 1, BRASS_D)
	_rect(img, 18, 18, 1, 3, BRASS_D)
	_px(img, 16, 18, ROYAL_L)
	# neck strap + base
	_line(img, 12, 16, 22, 16, LEATHER)
	_px(img, 13, 16, BRASS_L)
	_rect(img, 9, 25, 16, 1, BRASS_D)
	_rect(img, 10, 26, 14, 1, BRASS)
	_rect(img, 11, 27, 12, 1, BRASS_D)
	_outline(img)
	return img


# Faceted arcane orb with a tilted orbit ring and sparkles.
static func _orb() -> Image:
	var img := _blank()
	# back half of the orbit ring
	for i in range(0, 21):
		var a := PI + PI * float(i) / 20.0
		var x := 16 + int(cos(a) * 13.0)
		var y := 16 + int(sin(a) * 4.0 + cos(a) * 3.0)
		_px(img, x, y, CYAN_D)
	# sphere body
	_disc(img, 16, 16, 11, INK)
	_disc(img, 16, 16, 10, ARC_D)
	_disc(img, 16, 16, 9, ARC)
	# lower-right shadow crescent
	for y in range(10, 26):
		for x in range(13, 27):
			var dx := x - 16
			var dy := y - 16
			if dx * dx + dy * dy <= 81 and dx + dy > 7:
				_px(img, x, y, ARC_D)
	# lit facets
	for y in range(8, 16):
		for x in range(10, 19):
			var dx := x - 16
			var dy := y - 16
			if dx * dx + dy * dy <= 49 and dx + dy < -2:
				_px(img, x, y, ARC_L)
	_disc(img, 13, 12, 3, Color("#f3ddff"))
	_px(img, 11, 10, WHITE)
	_px(img, 12, 9, WHITE)
	_px(img, 13, 20, CYAN_L)
	# facet strokes
	_line(img, 12, 18, 16, 23, ARC_D)
	_line(img, 16, 23, 21, 19, ARC_D)
	_line(img, 12, 18, 14, 14, Color("#c79bf2"))
	# front half of the orbit ring (over the sphere)
	for i in range(0, 21):
		var a := PI * float(i) / 20.0
		var x := 16 + int(cos(a) * 13.0)
		var y := 16 + int(sin(a) * 4.0 + cos(a) * 3.0)
		_px(img, x, y, CYAN)
		if i % 4 == 0:
			_px(img, x, y - 1, CYAN_L)
	# sparkles
	_px(img, 4, 7, CYAN_L)
	_px(img, 3, 8, CYAN)
	_px(img, 28, 20, BRASS_L)
	_px(img, 27, 6, BONE)
	_px(img, 27, 22, CYAN_L)
	_px(img, 6, 23, ARC_L)
	return img


# Ornate crown: four points, velvet inner arches, jewels, glints.
static func _crown() -> Image:
	var img := _blank()
	# silhouette rows [y, x0, width]
	var spans := [
		[4, 15, 2], [5, 14, 4], [6, 14, 4], [7, 13, 6], [8, 13, 6],
		[9, 12, 8], [10, 12, 8], [11, 11, 10], [12, 11, 10],
		[13, 10, 12], [14, 10, 12], [15, 9, 14], [16, 9, 14],
		[17, 8, 16], [18, 8, 16], [19, 7, 18], [20, 7, 18],
		[21, 6, 20], [22, 6, 20],
	]
	for row in spans:
		_rect(img, int(row[1]), int(row[0]), int(row[2]), 1, BRASS)
	# side points rising to shoulders
	for y in range(10, 22):
		var x := 8 - (21 - y) / 4
		_px(img, x, y, BRASS)
		_px(img, x + 1, y, BRASS_L)
		_px(img, 24 + (21 - y) / 4, y, BRASS)
	# shadow / lit faces
	for y in range(5, 22):
		var row: Array = spans[mini(spans.size() - 1, y - 4)]
		var x1: int = int(row[1]) + int(row[2]) - 1
		_px(img, x1, y, BRASS_D)
		_px(img, int(row[1]), y, BRASS_L)
	# inner velvet arches
	_rect(img, 10, 15, 3, 5, CRIM_D)
	_rect(img, 13, 13, 6, 7, CRIM_D)
	_rect(img, 19, 15, 3, 5, CRIM_D)
	_rect(img, 14, 14, 4, 5, Color("#a32548"))
	# band
	_rect(img, 6, 22, 20, 2, BRASS)
	_rect(img, 6, 24, 20, 2, BRASS_D)
	_rect(img, 7, 26, 18, 1, BRASS_D)
	_rect(img, 7, 22, 18, 1, BRASS_L)
	# jewels
	_px(img, 10, 23, CRIM)
	_px(img, 11, 23, CRIM_L)
	_px(img, 16, 23, CYAN_L)
	_px(img, 17, 23, CYAN)
	_px(img, 22, 23, CRIM)
	_px(img, 23, 23, CRIM_L)
	_px(img, 16, 4, CYAN_L)
	_px(img, 16, 5, CYAN)
	# point beads
	_px(img, 15, 9, BONE)
	_px(img, 7, 12, BONE)
	_px(img, 24, 12, BONE)
	# glints
	_px(img, 9, 7, BRASS_L)
	_px(img, 22, 7, BRASS_L)
	_px(img, 26, 24, BONE)
	_px(img, 5, 10, BRASS_L)
	_px(img, 27, 8, CYAN)
	_outline(img)
	return img


# ---------------------------------------------------------------------------
# Backdrop layers
# ---------------------------------------------------------------------------

static func _sky_color_at(y: int, h: int) -> Color:
	var t := float(y) / float(h)
	var c: Color
	if t < 0.40:
		c = Color("#06060f").lerp(Color("#140d26"), t / 0.40)
	elif t < 0.70:
		c = Color("#140d26").lerp(Color("#2a1538"), (t - 0.40) / 0.30)
	elif t < 0.90:
		c = Color("#2a1538").lerp(Color("#4a2448"), (t - 0.70) / 0.20)
	else:
		c = Color("#4a2448").lerp(Color("#5c2d4c"), (t - 0.90) / 0.10)
	return c


static func _sky_image() -> Image:
	var img := _blank(SKY_W, SKY_H)
	for y in SKY_H:
		var base := _sky_color_at(y, SKY_H)
		for x in SKY_W:
			var n := (_hash01(x, y, 7) - 0.5) * 0.012
			img.set_pixel(x, y, Color(base.r + n, base.g + n, base.b + n, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261119
	# nebula veils
	for i in 90:
		var cx := rng.randi_range(0, SKY_W)
		var cy := rng.randi_range(10, 170)
		var rx := rng.randi_range(18, 64)
		var ry := rng.randi_range(5, 18)
		var tint := Color("#4a2a78") if i % 3 == 0 else Color("#233e66")
		if i % 4 == 0:
			tint = Color("#1b4a5a")
		if i % 5 == 0:
			tint = Color("#5c2a58")
		var a := rng.randf_range(0.025, 0.075)
		_blob(img, cx, cy, rx, ry, tint, a)
	# aurora ribbons
	for band in 3:
		var base_y := 72.0 + band * 26.0
		var col := Color("#35d8d0") if band == 0 else Color("#9a5ce0")
		for x in SKY_W:
			var y := base_y + sin(float(x) * 0.021 + float(band) * 1.7) * 13.0 + sin(float(x) * 0.006) * 7.0
			for dy in range(-4, 5):
				var a := (1.0 - absf(float(dy)) / 5.0) * 0.045
				if (x + dy) % 2 == 0:
					a *= 0.6
				_over(img, x, int(y) + dy, Color(col.r, col.g, col.b, a))
	# milky band
	for i in 260:
		var t := rng.randf()
		var x := int(t * SKY_W)
		var y := int(150.0 - t * 120.0 + rng.randf_range(-14, 14))
		_over(img, x, y, Color(0.55, 0.48, 0.85, rng.randf_range(0.03, 0.08)))
	# stars
	for i in 210:
		var x := rng.randi_range(0, SKY_W - 1)
		var y := rng.randi_range(0, 205)
		var bright := rng.randf()
		var c := Color(1, 1, 1)
		if bright > 0.86:
			c = Color("#ffe6a6")
		elif bright > 0.72:
			c = Color("#9ff4ff")
		var a := 0.25 + bright * 0.70
		_px(img, x, y, Color(c.r, c.g, c.b, a))
		if bright > 0.90:
			_px(img, x - 1, y, Color(c.r, c.g, c.b, a * 0.35))
			_px(img, x + 1, y, Color(c.r, c.g, c.b, a * 0.35))
			_px(img, x, y - 1, Color(c.r, c.g, c.b, a * 0.35))
			_px(img, x, y + 1, Color(c.r, c.g, c.b, a * 0.35))
	# crescent-ish moon at battle-right position
	var mx := 262
	var my := 48
	for r in range(26, 19, -1):
		_disc(img, mx, my, r, Color(1.0, 0.9, 0.72, 0.022 * float(27 - r)))
	_disc(img, mx, my, 20, Color("#d8bd88"))
	_disc(img, mx - 1, my - 1, 19, Color("#f2dcae"))
	_disc(img, mx - 5, my - 4, 13, Color("#fff0c8"))
	_disc(img, mx + 6, my + 6, 14, Color("#e3c68f"))
	_disc(img, mx - 1, my - 1, 15, Color("#f2dcae"))
	for crater in [[5, -6, 4], [-7, 5, 3], [9, 7, 2], [-2, 11, 2]]:
		_disc(img, mx + int(crater[0]), my + int(crater[1]), int(crater[2]), Color("#e0c086"))
		_px(img, mx + int(crater[0]) - 1, my + int(crater[1]) - 1, Color("#f7e4b6"))
	# a few distant birds
	for b in 5:
		var bx := rng.randi_range(60, 250)
		var by := rng.randi_range(60, 135)
		_px(img, bx, by, Color(0.1, 0.07, 0.16, 0.7))
		_px(img, bx - 1, by - 1, Color(0.1, 0.07, 0.16, 0.7))
		_px(img, bx + 1, by - 1, Color(0.1, 0.07, 0.16, 0.7))
	return img


static func _blob(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color, a: float) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var dx := float(x - cx) / float(maxi(1, rx))
			var dy := float(y - cy) / float(maxi(1, ry))
			var d := dx * dx + dy * dy
			if d >= 1.0:
				continue
			if (x + y) % 2 == 0:
				continue
			var fade := (1.0 - d) * (1.0 - d)
			_over(img, x, y, Color(c.r, c.g, c.b, a * fade))
			if (x * 3 + y * 5) % 7 == 0:
				_over(img, x, y, Color(c.r, c.g, c.b, a * fade * 0.6))


static func _clouds_image(seed_value: int, alpha_hi: float, alpha_lo: float) -> Image:
	var img := _blank(CLOUD_W, CLOUD_H)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 26:
		var cx := rng.randi_range(-24, CLOUD_W + 24)
		var cy := rng.randi_range(8, CLOUD_H - 8)
		var rx := rng.randi_range(22, 70)
		var ry := rng.randi_range(3, 9)
		var tint := Color("#5a4a92") if i % 2 == 0 else Color("#3a2c63")
		var a := rng.randf_range(alpha_lo, alpha_hi)
		for y in range(cy - ry, cy + ry + 1):
			for x in range(cx - rx, cx + rx + 1):
				var dx := float(x - cx) / float(rx)
				var dy := float(y - cy) / float(ry)
				var d := dx * dx + dy * dy
				if d >= 1.0:
					continue
				if (x + y * 2) % 3 == 0:
					continue
				_over(img, x, y, Color(tint.r, tint.g, tint.b, a * (1.0 - d) * (1.0 - d)))
	# thin wisp streaks
	for i in 14:
		var y := rng.randi_range(6, CLOUD_H - 6)
		var x0 := rng.randi_range(0, CLOUD_W - 40)
		var length := rng.randi_range(24, 90)
		for x in range(x0, mini(CLOUD_W, x0 + length)):
			_over(img, x, y + int(sin(float(x) * 0.1) * 1.5), Color(0.65, 0.58, 0.95, alpha_lo * 0.9))
	return img


static func _mountains_image() -> Image:
	var img := _blank(MTN_W, MTN_H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8841
	# far range
	var far: Array[int] = []
	var h := 40
	for x in MTN_W:
		h += rng.randi_range(-3, 3)
		h = clampi(h, 18, 64)
		if x % 53 == 0:
			h = clampi(h + rng.randi_range(-18, 18), 12, 64)
		far.append(h)
	for x in MTN_W:
		var top: int = far[x]
		for y in range(top, MTN_H):
			img.set_pixel(x, y, Color("#1b1533"))
		_px(img, x, top, Color("#4a3f7e"))
		_px(img, x, top + 1, Color("#332a5c"))
		if x % 29 == 0:
			_px(img, x, top, Color("#6ff0e0"))
	# near range
	var near: Array[int] = []
	h = 70
	for x in MTN_W:
		h += rng.randi_range(-4, 4)
		h = clampi(h, 44, 106)
		if x % 37 == 0:
			h = clampi(h + rng.randi_range(-22, 22), 40, 106)
		near.append(h)
	for x in MTN_W:
		var top: int = near[x]
		for y in range(top, MTN_H):
			img.set_pixel(x, y, Color("#100b20"))
		_px(img, x, top, Color("#3a2d63"))
		_px(img, x, top + 1, Color("#261c40"))
	# a lone broken tower on the ridge
	_rect(img, 46, 52, 5, 60, Color("#100b20"))
	_rect(img, 47, 52, 3, 60, Color("#1a1430"))
	_rect(img, 44, 50, 9, 3, Color("#100b20"))
	_px(img, 51, 51, Color("#4a3f7e"))
	_px(img, 48, 57, Color("#ffcf8a"))
	# snow/neon caps
	for x in range(0, MTN_W, 3):
		if far[x] == 12 or far[x] < 16:
			_px(img, x, far[x] + 1, Color("#4a3f6e"))
	# crevice lines
	for i in 18:
		var x := rng.randi_range(0, MTN_W - 1)
		var y := rng.randi_range(near[x] + 6, MTN_H - 1)
		var seg := rng.randi_range(4, 16)
		for j in seg:
			_px(img, x + j / 4, y + j, Color(0.03, 0.02, 0.06, 0.35))
	return img


static func _temple_image() -> Image:
	var img := _blank(TEMPLE_W, TEMPLE_H)
	var stone := Color("#241a3d")
	var stone_dk := Color("#150f27")
	var stone_hi := Color("#4a3a6e")
	var gold := Color("#e0a94a")
	var gold_dk := Color("#7c5218")
	var cyan := Color("#62e6d6")
	# foundation steps
	for i in 3:
		_rect(img, 52 - i * 8, 166 + i * 4, 216 + i * 16, 4, stone)
		_rect(img, 52 - i * 8, 166 + i * 4, 216 + i * 16, 1, stone_hi)
	# side towers
	_rect(img, 48, 62, 26, 104, stone)
	_rect(img, 48, 62, 26, 3, stone_hi)
	_rect(img, 54, 44, 14, 20, stone)
	_rect(img, 56, 36, 10, 10, stone)
	_px(img, 60, 33, gold)
	_rect(img, 246, 74, 26, 92, stone)
	_rect(img, 246, 74, 26, 3, stone_hi)
	_rect(img, 252, 58, 14, 18, stone)
	_rect(img, 254, 50, 10, 9, stone)
	_px(img, 258, 47, gold)
	# tower windows with a soft halo
	for wy in [80, 100, 120, 140]:
		for dy in range(-2, 8):
			for dx in range(-2, 6):
				_over(img, 59 + dx, wy + dy, Color(1.0, 0.8, 0.4, 0.055))
				_over(img, 258 + dx, wy + dy, Color(0.3, 1.0, 0.9, 0.055))
		_rect(img, 59, wy, 3, 5, Color("#ffcf8a"))
		_rect(img, 258, wy, 3, 5, Color("#62e6d6"))
		_px(img, 59, wy, Color("#fff3c8"))
		_px(img, 258, wy, Color("#d8fff8"))
	# colonnade
	for i in 5:
		var x := 82 + i * 18
		if x > 150:
			x += 22
		var top := 112 + (i % 3) * 6
		_rect(img, x, top, 9, 166 - top, stone)
		_rect(img, x, top, 9, 2, stone_hi)
		_rect(img, x, top, 2, 166 - top, stone_hi)
		_rect(img, x + 7, top, 2, 166 - top, stone_dk)
		_rect(img, x - 2, top - 3, 13, 3, stone_hi)
		_rect(img, x - 2, 163, 13, 3, stone_hi)
		# vines
		if i % 2 == 0:
			for v in 7:
				_px(img, x + 1 + v % 2, top + 10 + v * 6, Color("#2f7a4e"))
				if v % 3 == 0:
					_px(img, x + 2, top + 10 + v * 6, Color("#6fce8a"))
	# central broken arch
	_rect(img, 146, 118, 30, 48, stone_dk)
	_rect(img, 150, 122, 22, 44, Color("#0a0614"))
	var draw_arch := [[152, 118, 18, 2], [150, 120, 22, 2], [148, 122, 26, 2]]
	for row in draw_arch:
		_rect(img, int(row[0]), int(row[1]), int(row[2]), int(row[3]), stone)
	# glowing doorway
	for dy in range(0, 36):
		for dx in range(-8, 10):
			_over(img, 161 + dx, 134 + dy, Color(0.4, 1.0, 0.92, 0.035))
	_rect(img, 158, 136, 6, 30, Color(0.35, 0.95, 0.88, 0.22))
	_rect(img, 159, 140, 4, 26, Color(0.45, 1.0, 0.92, 0.38))
	_over(img, 160, 152, Color(0.6, 1.0, 0.95, 0.28))
	_rect(img, 157, 132, 8, 3, gold)
	_px(img, 157, 131, gold)
	_px(img, 164, 131, gold)
	_px(img, 160, 135, Color("#d8fff8"))
	# pediment (broken)
	for i in 30:
		var w := i * 2
		_rect(img, 160 - w, 112 - i, w * 2, 1, stone)
		_px(img, 160 - w, 112 - i, stone_hi)
		if i == 20:
			_rect(img, 122, 92, 30, 3, stone_dk)
	_px(img, 160, 81, gold)
	_rect(img, 120, 91, 40, 2, gold_dk)
	_rect(img, 176, 96, 20, 2, gold_dk)
	_line(img, 130, 104, 160, 82, Color("#b0802e"))
	_line(img, 160, 82, 190, 104, Color("#b0802e"))
	_px(img, 144, 96, Color("#6ff0e0"))
	_px(img, 176, 99, Color("#6ff0e0"))
	# hanging banners
	_rect(img, 74, 58, 7, 34, Color("#6e1f38"))
	_rect(img, 75, 58, 5, 34, Color("#9a2b4c"))
	_rect(img, 74, 86, 7, 3, gold_dk)
	_rect(img, 238, 70, 7, 30, Color("#6e1f38"))
	_rect(img, 239, 70, 5, 30, Color("#9a2b4c"))
	_rect(img, 238, 95, 7, 3, gold_dk)
	# floating embers around the ruin
	for i in 12:
		_px(img, 60 + i * 17, 100 - (i * 13) % 44, Color(1.0, 0.75, 0.4, 0.35))
	return img


static func _ruins_image() -> Image:
	var img := _blank(RUIN_W, RUIN_H)
	var stone := Color("#151020")
	var stone_hi := Color("#3a2b56")
	var stone_dk := Color("#0a0712")
	var moss := Color("#2f7a4e")
	# left wall
	_rect(img, 0, 44, 58, 66, stone)
	for i in 5:
		_rect(img, i * 12, 40, 7, 8, stone)
	_rect(img, 0, 44, 58, 2, stone_hi)
	for i in 6:
		_px(img, 8 + i * 8, 40, stone_dk)
	# arch
	_rect(img, 58, 58, 20, 52, stone)
	_rect(img, 58, 58, 20, 2, stone_hi)
	_rect(img, 62, 66, 12, 44, stone_dk)
	_rect(img, 66, 60, 4, 6, stone_dk)
	_rect(img, 78, 58, 12, 52, stone)
	_rect(img, 78, 58, 12, 2, stone_hi)
	# broken pillar
	_rect(img, 108, 52, 12, 58, stone)
	_rect(img, 108, 52, 12, 2, stone_hi)
	_rect(img, 108, 52, 3, 58, stone_hi)
	_rect(img, 106, 48, 16, 4, stone)
	_rect(img, 109, 40, 10, 8, stone)
	_px(img, 109, 39, stone_hi)
	_px(img, 118, 39, stone_hi)
	# low crenellated wall
	_rect(img, 150, 76, 84, 34, stone)
	_rect(img, 150, 76, 84, 2, stone_hi)
	for i in 6:
		_rect(img, 152 + i * 14, 70, 8, 6, stone)
	# spikes
	for i in 4:
		var x := 240 + i * 12
		_rect(img, x, 64, 4, 46, stone)
		_px(img, x + 1, 60, stone_hi)
		_px(img, x + 1, 61, stone)
	# rubble
	for i in 26:
		var x := (i * 37) % RUIN_W
		var y := 88 + (i * 17) % 18
		_rect(img, x, y, 3 + i % 4, 2 + i % 3, stone)
		_px(img, x, y, stone_hi)
	# moss / rune accents
	for i in 14:
		var x := (i * 53) % RUIN_W
		var y := 70 + (i * 29) % 34
		_px(img, x, y, moss)
		if i % 4 == 0:
			_px(img, x, y + 1, Color("#6fce8a"))
	for rune in [[94, 70], [95, 71], [206, 82], [132, 88], [172, 92]]:
		_px(img, int(rune[0]), int(rune[1]), Color("#62e6d6"))
		_over(img, int(rune[0]), int(rune[1]), Color(0.4, 1.0, 0.9, 0.25))
	_px(img, 206, 82, Color("#ffcf8a"))
	_rect(img, 0, 44, 58, 1, Color("#3a2b56"))
	return img


static func _ground_image() -> Image:
	var img := _blank(GROUND_W, GROUND_H)
	img.fill(Color("#191124"))
	_rect(img, 0, 0, GROUND_W, 3, Color("#432f52"))
	_rect(img, 0, 0, GROUND_W, 1, Color("#5c4370"))
	# perspective stone rows
	var rng := RandomNumberGenerator.new()
	rng.seed = 3311
	var y := 4
	var row := 0
	while y < GROUND_H:
		var h := 6 + row * 1
		var w := 18 + row * 4
		var x := -((row * 13) % w)
		while x < GROUND_W:
			var bw := w + rng.randi_range(-4, 5)
			_rect(img, x + 1, y + 1, bw - 2, h - 2, Color("#1c1429"))
			_rect(img, x + 1, y + 1, bw - 2, 1, Color("#382849"))
			_rect(img, x + 1, y + 1, 1, h - 2, Color("#2c1e3e"))
			_rect(img, x + 1, y + h - 2, bw - 2, 1, Color("#100b19"))
			if rng.randf() < 0.2:
				_px(img, x + 3, y + 3, Color("#2c1e3e"))
			if rng.randf() < 0.04:
				_px(img, x + 4, y + 2, Color("#62e6d6"))
			x += w
		y += h
		row += 1
	# cracks
	for i in 15:
		var cx := rng.randi_range(0, GROUND_W)
		var cy := rng.randi_range(6, GROUND_H)
		var seg := rng.randi_range(6, 20)
		for j in seg:
			_px(img, cx + j, cy + j / 3, Color(0.03, 0.02, 0.05, 0.55))
	# grass tufts and rubble
	for i in 46:
		var gx := rng.randi_range(0, GROUND_W - 2)
		var gy := rng.randi_range(8, GROUND_H - 2)
		_px(img, gx, gy, Color("#3f6a4e"))
		_px(img, gx + 1, gy - 1, Color("#4f8a5e"))
		if i % 3 == 0:
			_px(img, gx + 2, gy - 2, Color("#2f5a42"))
	for i in 20:
		var rx := rng.randi_range(0, GROUND_W - 3)
		var ry := rng.randi_range(10, GROUND_H - 2)
		_rect(img, rx, ry, 2, 1, Color("#241a30"))
		_px(img, rx, ry, Color("#33243f"))
	# faint rune glow near the gate side
	for i in 6:
		_px(img, 12 + i * 3, 28, Color(0.3, 0.9, 0.85, 0.18))
		_px(img, 14 + i * 2, 42, Color(0.3, 0.9, 0.85, 0.12))
	return img


static func _fog_image() -> Image:
	var img := _blank(FOG_W, FOG_H)
	for x in FOG_W:
		var center := 24.0 + sin(float(x) * 0.033) * 5.0 + sin(float(x) * 0.012 + 1.7) * 7.0
		for y in FOG_H:
			var d := absf(float(y) - center) / 14.0
			if d >= 1.0:
				continue
			var a := (1.0 - d) * (1.0 - d) * 0.34
			if (x + y) % 2 == 0:
				a *= 0.55
			_over(img, x, y, Color(0.72, 0.65, 0.95, a))
	return img
