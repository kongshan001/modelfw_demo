extends Node2D
## 单场地“苔关”静态场景：草地、主路、敌军入口、主城、三个固定建造位、路旁火把。
## 除建造位悬停 / 主城受损外不重绘；美术全部为原创程序化几何。

const Data = preload("res://scripts/game_data.gd")
const Art = preload("res://scripts/art.gd")

var decorations: Array = []
var torches: Array = []
var hover_pad := -1
var castle_ratio := 1.0


func _ready() -> void:
	_build_scenery()
	queue_redraw()


func set_hover_pad(index: int) -> void:
	if index != hover_pad:
		hover_pad = index
		queue_redraw()


func set_castle_ratio(ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	if absf(clamped - castle_ratio) > 0.02 or clamped == 0.0:
		castle_ratio = clamped
		queue_redraw()


func _build_scenery() -> void:
	decorations.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 90731
	var attempts := 0
	while decorations.size() < 58 and attempts < 600:
		attempts += 1
		var p := Vector2(rng.randf_range(34.0, 1246.0), rng.randf_range(108.0, 696.0))
		if Data.distance_to_path(p) < 76.0:
			continue
		if p.distance_to(Data.CASTLE_POS) < 150.0:
			continue
		var near_pad := false
		for pad in Data.BUILD_PADS:
			if p.distance_to(Vector2(pad["pos"])) < 78.0:
				near_pad = true
				break
		if near_pad:
			continue
		if p.distance_to(Data.SPAWN_POS) < 120.0:
			continue
		var pick := rng.randf()
		var kind := "grass"
		if pick < 0.16:
			kind = "tree"
		elif pick < 0.34:
			kind = "rock"
		elif pick < 0.52:
			kind = "fern"
		elif pick < 0.62:
			kind = "mushroom"
		elif pick < 0.70:
			kind = "stump"
		elif pick < 0.80:
			kind = "flowers"
		decorations.append({
			"kind": kind,
			"pos": p,
			"scale": rng.randf_range(0.8, 1.35),
			"flip": 1.0 if rng.randf() > 0.5 else -1.0,
			"tone": rng.randf(),
		})
	decorations.sort_custom(func(a, b):
		var ap: Vector2 = a["pos"]
		var bp: Vector2 = b["pos"]
		return ap.y < bp.y)

	torches.clear()
	var dists := [0.17, 0.34, 0.51, 0.68, 0.84]
	var side := 1.0
	for frac in dists:
		var d := Data.path_length() * float(frac)
		var p := Data.path_point_at(d)
		var t := Data.path_tangent_at(d)
		var perp := Vector2(-t.y, t.x) * side * 45.0
		torches.append({"pos": p + perp, "phase": float(torches.size()) * 0.9})
		side *= -1.0


func _draw() -> void:
	_draw_ground()
	_draw_path()
	_draw_scenery()
	_draw_torches()
	_draw_spawn_gate()
	_draw_castle()
	_draw_pads()
	_draw_labels()


func _draw_ground() -> void:
	draw_rect(Rect2(Vector2.ZERO, Data.ARENA_SIZE), Art.BG, true)
	# 大块苔草地被，确定性摆放。
	var rng := RandomNumberGenerator.new()
	rng.seed = 5517
	for i in range(24):
		var center := Vector2(rng.randf_range(-40, 1320), rng.randf_range(90, 750))
		var radius := rng.randf_range(70, 190)
		var col := Art.GRASS_DARK.lerp(Art.GRASS, rng.randf_range(0.15, 0.55))
		col.a = 0.55
		draw_circle(center, radius, col)
	# 顶部山脊与底部灌木剪影，给单屏一个边框。
	var ridge := PackedVector2Array([
		Vector2(-20, 0), Vector2(1300, 0), Vector2(1300, 78),
		Vector2(1180, 66), Vector2(1090, 88), Vector2(960, 62),
		Vector2(840, 84), Vector2(700, 58), Vector2(560, 80),
		Vector2(430, 54), Vector2(300, 74), Vector2(160, 52),
		Vector2(-20, 70),
	])
	draw_colored_polygon(ridge, Color("101f1a"))
	var mist := PackedVector2Array([
		Vector2(-20, 58), Vector2(1300, 46), Vector2(1300, 92),
		Vector2(1080, 76), Vector2(820, 96), Vector2(540, 72),
		Vector2(240, 92), Vector2(-20, 76),
	])
	draw_colored_polygon(mist, Color(0.22, 0.33, 0.27, 0.28))
	# 边缘暗角。
	draw_rect(Rect2(0, 690, 1280, 30), Color(0.03, 0.06, 0.05, 0.55), true)
	draw_rect(Rect2(0, 0, 22, 720), Color(0.03, 0.06, 0.05, 0.35), true)


func _draw_path() -> void:
	var pts := PackedVector2Array(Data.PATH_POINTS)
	for p in pts:
		draw_circle(p, 33.0, Art.PATH_DARK)
	draw_polyline(pts, Art.PATH_DARK, 66.0, true)
	for p in pts:
		draw_circle(p, 28.0, Art.PATH)
	draw_polyline(pts, Art.PATH, 56.0, true)
	# 中央浅色虚线。
	var total := Data.path_length()
	var d := 12.0
	while d < total:
		var p := Data.path_point_at(d)
		var t := Data.path_tangent_at(d)
		draw_line(p - t * 7.0, p + t * 7.0, Color(0.85, 0.78, 0.60, 0.42), 2.0)
		d += 30.0
	# 两侧碎石。
	d = 18.0
	var side := 1.0
	while d < total:
		var p := Data.path_point_at(d)
		var t := Data.path_tangent_at(d)
		var perp := Vector2(-t.y, t.x) * side
		var stone := p + perp * 34.0
		var shade := Art.STONE_DARK.lerp(Art.STONE_LIGHT, fmod(d * 0.013, 1.0))
		draw_circle(stone + Vector2(1, 2), 3.4, Color(0, 0, 0, 0.30))
		draw_circle(stone, 2.7, shade)
		side *= -1.0
		d += 52.0


func _draw_scenery() -> void:
	for deco in decorations:
		var p: Vector2 = deco["pos"]
		var s: float = deco["scale"]
		match String(deco["kind"]):
			"grass":
				_draw_grass(p, s, float(deco["tone"]))
			"rock":
				_draw_rock(p, s)
			"fern":
				_draw_fern(p, s)
			"mushroom":
				_draw_mushroom(p, s)
			"stump":
				_draw_stump(p, s)
			"flowers":
				_draw_flowers(p, s)
			"tree":
				_draw_tree(p, s)
	# 主城脚下的石阶。
	for i in range(4):
		var r := Rect2(220 + i * 12, 486 + i * 7, 44 - i * 4, 5)
		draw_rect(r, Art.STONE_DARK.lerp(Art.STONE, 0.35 + i * 0.12), true)


func _draw_grass(p: Vector2, s: float, tone: float) -> void:
	var col := Art.MOSS.lerp(Art.GRASS_LIGHT, tone)
	for i in range(4):
		var off := Vector2(-7.0 + i * 4.5, 0.0) * s
		draw_line(p + off, p + off + Vector2(2.0 - i * 1.5, -8.0 - i * 2.0) * s, col, 1.3)
	draw_circle(p + Vector2(0, 1), 5.0 * s, Color(0.08, 0.16, 0.11, 0.35))


func _draw_rock(p: Vector2, s: float) -> void:
	Art.shadow(self, p + Vector2(2, 3), 14.0 * s, 5.0 * s, 0.30)
	var pts := PackedVector2Array([
		p + Vector2(-13, 1) * s, p + Vector2(-8, -9) * s,
		p + Vector2(2, -12) * s, p + Vector2(12, -5) * s,
		p + Vector2(10, 4) * s, p + Vector2(-5, 5) * s,
	])
	draw_colored_polygon(pts, Art.STONE_DARK)
	var hi := PackedVector2Array([
		p + Vector2(-8, -8) * s, p + Vector2(1, -11) * s, p + Vector2(5, -5) * s, p + Vector2(-4, -2) * s,
	])
	draw_colored_polygon(hi, Art.STONE.lerp(Art.STONE_LIGHT, 0.35))


func _draw_fern(p: Vector2, s: float) -> void:
	draw_line(p, p + Vector2(0, -12) * s, Art.TEAL_DARK, 1.4)
	for i in range(4):
		var t := float(i) / 3.0
		var base := p + Vector2(0, -3.0 * t) * s
		var spread := (4.0 + 5.5 * t) * s
		draw_line(base, base + Vector2(-spread, -6.0 * s), Art.MOSS.lerp(Art.GRASS_LIGHT, 0.5), 1.2)
		draw_line(base, base + Vector2(spread, -6.0 * s), Art.MOSS.lerp(Art.GRASS_LIGHT, 0.5), 1.2)


func _draw_mushroom(p: Vector2, s: float) -> void:
	draw_line(p, p + Vector2(0, -8) * s, Art.CREAM.darkened(0.2), 2.4 * s)
	draw_circle(p + Vector2(0, -9) * s, 5.2 * s, Art.AMBER.darkened(0.28))
	draw_circle(p + Vector2(-1.4, -10.5) * s, 1.3 * s, Art.CREAM.darkened(0.1))


func _draw_stump(p: Vector2, s: float) -> void:
	Art.shadow(self, p + Vector2(2, 3), 11.0 * s, 4.0 * s, 0.28)
	draw_rect(Rect2(p + Vector2(-7, -8) * s, Vector2(14, 10) * s), Color("4b3b28"), true)
	draw_set_transform(p + Vector2(0, -8) * s, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 7.0 * s, Color("7a613f"))
	draw_arc(Vector2.ZERO, 4.8 * s, 0, TAU, 12, Color("5a472e"), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_flowers(p: Vector2, s: float) -> void:
	for i in range(3):
		var off := Vector2(-6.0 + i * 6.0, (i % 2) * 4.0) * s
		draw_line(p + off, p + off + Vector2(0, -6) * s, Art.MOSS, 1.0)
		draw_circle(p + off + Vector2(0, -7) * s, 1.7 * s, Art.GOLD.lerp(Art.CREAM, 0.35))


func _draw_tree(p: Vector2, s: float) -> void:
	Art.shadow(self, p + Vector2(4, 2), 18.0 * s, 6.0 * s, 0.35)
	draw_line(p + Vector2(0, 0), p + Vector2(0, -26) * s, Color("3f3325"), 4.0 * s)
	draw_circle(p + Vector2(-8, -27) * s, 13.0 * s, Color("1c3327"))
	draw_circle(p + Vector2(8, -30) * s, 15.0 * s, Color("203b2c"))
	draw_circle(p + Vector2(0, -40) * s, 13.5 * s, Color("294a35"))
	draw_circle(p + Vector2(-3, -45) * s, 7.0 * s, Color("355a3f"))


func _draw_torches() -> void:
	for t in torches:
		var p: Vector2 = t["pos"]
		draw_circle(p + Vector2(0, -18), 34.0, Color(0.95, 0.72, 0.32, 0.055))
		draw_circle(p + Vector2(0, -18), 18.0, Color(0.95, 0.72, 0.32, 0.07))
		draw_line(p, p + Vector2(0, -25), Color("4b3a27"), 3.0)
		draw_line(p + Vector2(-4, -22), p + Vector2(4, -22), Color("4b3a27"), 2.0)
		draw_circle(p + Vector2(0, -29), 4.6, Art.AMBER)
		draw_circle(p + Vector2(0, -31), 2.6, Art.GOLD)
		draw_circle(p + Vector2(0, -33), 1.3, Art.CREAM)


func _draw_spawn_gate() -> void:
	var base := Vector2(1206, 150)
	draw_rect(Rect2(1172, 96, 78, 112), Color(0, 0, 0, 0.18), true)
	# 两根焦木柱与横梁。
	draw_line(base + Vector2(3, 48), base + Vector2(3, -48), Color("38291e"), 8.0)
	draw_line(base + Vector2(27, 42), base + Vector2(27, -42), Color("443122"), 6.0)
	draw_line(base + Vector2(-2, -44), base + Vector2(32, -38), Color("4f3a27"), 7.0)
	draw_circle(base + Vector2(3, -52), 6.0, Art.RUST.darkened(0.25))
	draw_circle(base + Vector2(27, -47), 5.0, Art.RUST.darkened(0.25))
	# 门洞与敌军旗。
	var arch := PackedVector2Array([
		base + Vector2(8, 36), base + Vector2(8, -22),
		base + Vector2(20, -34), base + Vector2(32, -22), base + Vector2(32, 36),
	])
	draw_colored_polygon(arch, Color("160f0c"))
	var flag := PackedVector2Array([
		base + Vector2(33, -30), base + Vector2(61, -22),
		base + Vector2(33, -10),
	])
	draw_colored_polygon(flag, Art.RUST.darkened(0.15))
	draw_line(base + Vector2(33, -34), base + Vector2(33, 6), Color("3b2c20"), 2.0)
	# 敌方箭头。
	for i in range(3):
		var x := 1146.0 - i * 22.0
		var pts := PackedVector2Array([
			Vector2(x, 150), Vector2(x + 10, 143), Vector2(x + 10, 147),
			Vector2(x + 18, 147), Vector2(x + 18, 153), Vector2(x + 10, 153), Vector2(x + 10, 157),
		])
		draw_colored_polygon(pts, Color(0.86, 0.40, 0.30, 0.55 - i * 0.12))


func _draw_castle() -> void:
	var p := Data.CASTLE_POS
	Art.shadow(self, p + Vector2(0, 34), 78.0, 18.0, 0.38)
	# 基座与主堡。
	draw_rect(Rect2(92, 500, 142, 16), Art.STONE_DARK, true)
	draw_rect(Rect2(100, 414, 128, 92), Art.STONE_DARK, true)
	draw_rect(Rect2(106, 420, 116, 80), Art.STONE, true)
	# 城垛。
	for i in range(5):
		draw_rect(Rect2(104 + i * 25, 406, 16, 16), Art.STONE, true)
		draw_rect(Rect2(104 + i * 25, 406, 16, 4), Art.STONE_LIGHT, true)
	# 两侧圆塔。
	for side in [-1.0, 1.0]:
		var tx: float = 150.0 + float(side) * 62.0
		draw_circle(Vector2(tx, 470), 23.0, Art.STONE_DARK)
		draw_circle(Vector2(tx, 470), 18.0, Art.STONE)
		for i in range(5):
			var a := -PI * 0.5 + (float(i) - 2.0) * 0.55
			var bp := Vector2(tx, 470) + Vector2(cos(a), sin(a)) * 21.0
			draw_circle(bp, 5.0, Art.STONE, true)
		draw_circle(Vector2(tx + 0, 470), 6.0, Color("22302a"))
	# 右侧门楼与城门。
	draw_rect(Rect2(188, 446, 38, 62), Art.STONE_DARK, true)
	draw_rect(Rect2(192, 450, 30, 58), Art.STONE, true)
	draw_rect(Rect2(204, 470, 18, 38), Color("1a221d"), true)
	draw_arc(Vector2(213, 470), 9.0, PI, TAU, 12, Art.STONE_LIGHT, 3.0)
	# 青色旗帜与原创太阳纹。
	draw_line(Vector2(124, 420), Vector2(124, 392), Color("3b2c20"), 3.0)
	var banner := PackedVector2Array([Vector2(125, 392), Vector2(173, 398), Vector2(168, 432), Vector2(125, 426)])
	draw_colored_polygon(banner, Art.TEAL_DARK)
	var sun_center := Vector2(147, 410)
	draw_circle(sun_center, 8.5, Art.GOLD)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		draw_line(sun_center + Vector2(cos(a), sin(a)) * 10.5, sun_center + Vector2(cos(a), sin(a)) * 15.0, Art.GOLD, 2.0)
	draw_circle(sun_center, 3.5, Art.TEAL_DARK)
	# 窗。
	draw_rect(Rect2(116, 438, 10, 18), Color("1c2620"), true)
	draw_rect(Rect2(180, 438, 10, 18), Color("1c2620"), true)
	# 受损裂纹。
	var crack_col := Color(0.12, 0.08, 0.06, 0.8)
	if castle_ratio < 0.66:
		draw_line(Vector2(132, 426), Vector2(141, 448), crack_col, 2.0)
		draw_line(Vector2(141, 448), Vector2(134, 466), crack_col, 2.0)
		draw_line(Vector2(141, 448), Vector2(152, 458), crack_col, 1.5)
	if castle_ratio < 0.33:
		draw_line(Vector2(186, 432), Vector2(175, 454), crack_col, 2.0)
		draw_line(Vector2(175, 454), Vector2(184, 476), crack_col, 2.0)
		draw_circle(Vector2(150, 430), 9.0, Color(0.35, 0.18, 0.12, 0.22))
	# 门灯。
	draw_circle(Vector2(196, 462), 16.0, Color(1.0, 0.75, 0.35, 0.07))
	draw_circle(Vector2(196, 462), 3.2, Art.GOLD)


func _draw_pads() -> void:
	for i in range(Data.BUILD_PADS.size()):
		var pad: Dictionary = Data.BUILD_PADS[i]
		var p: Vector2 = pad["pos"]
		var hov := i == hover_pad
		Art.shadow(self, p + Vector2(0, 7), 34.0, 11.0, 0.34)
		draw_circle(p, 31.0, Art.STONE_DARK)
		draw_circle(p, 27.0, Art.STONE if not hov else Art.STONE.lerp(Art.TEAL, 0.30))
		draw_arc(p, 24.0, 0, TAU, 24, Art.GOLD_DIM if not hov else Art.GOLD, 2.0 if hov else 1.0)
		for k in range(4):
			var a := TAU * float(k) / 4.0 + PI * 0.25
			draw_circle(p + Vector2(cos(a), sin(a)) * 20.0, 2.3, Art.GOLD_DIM)
		draw_circle(p, 5.0, Color("2b3a31"))
		Art.text_center(self, Rect2(p.x - 56, p.y + 32, 112, 18), String(pad["name"]), 12,
			Art.TEAL if hov else Art.DIM, true)
		if hov:
			draw_arc(p, 39.0, 0, TAU, 40, Color(0.47, 0.80, 0.69, 0.55), 2.0)
			Art.dashed_circle(self, p, 190.0, Color(0.47, 0.80, 0.69, 0.20), 1.2, 36)


func _draw_labels() -> void:
	Art.text(self, Vector2(1152, 238), "敌军入口", 13, Color(0.86, 0.55, 0.42, 0.85), true)
	Art.text(self, Vector2(112, 542), "主城 · 苔关", 14, Art.TEAL, true)
	Art.text(self, Vector2(294, 560), "最后卡口", 12, Color(0.75, 0.68, 0.52, 0.7))
	Art.text(self, Vector2(24, 666), "第 1–8 波 · 单局 8–12 分钟", 12, Color(0.55, 0.62, 0.52, 0.55))
