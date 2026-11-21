class_name HarborMap
extends Node2D
## 原创俯视角雾港：码头、仓库、集装箱、木栈桥、雾与灯。
## 布局手写、确定性；所有图形由 _draw() 程序化绘制，碰撞为 StaticBody2D 矩形。

const WORLD_RECT := Rect2(0, 0, 2400, 1500)
const BOUNDS := Rect2(100, 100, 2200, 1320)
const PLAYER_SPAWN := Vector2(280, 1260)
const BUILDING := Rect2(260, 200, 640, 420)
const EXTRACTION_RECT := Rect2(2080, 1200, 200, 160)

const CHESTS := [
	{"id": "wh_west", "pos": Vector2(500, 470), "tier": 0},
	{"id": "wh_east", "pos": Vector2(790, 500), "tier": 0},
	{"id": "yard_mid", "pos": Vector2(1260, 620), "tier": 0},
	{"id": "yard_alley", "pos": Vector2(1510, 660), "tier": 0},
	{"id": "yard_west", "pos": Vector2(1940, 520), "tier": 1},
	{"id": "pier_west", "pos": Vector2(410, 1010), "tier": 0},
	{"id": "yard_south", "pos": Vector2(1080, 1110), "tier": 0},
	{"id": "north_crate", "pos": Vector2(1790, 200), "tier": 0},
	{"id": "extraction", "pos": Vector2(1960, 1300), "tier": 1},
]

const ENEMY_SPAWNS := [
	{"type": "gunner", "pos": Vector2(950, 400), "patrol": [Vector2(-55, 20), Vector2(45, -25), Vector2(0, 55)]},
	{"type": "lurker", "pos": Vector2(1000, 690), "patrol": [Vector2(-45, 0), Vector2(0, 55), Vector2(50, 0)]},
	{"type": "gunner", "pos": Vector2(1600, 540), "patrol": [Vector2(-30, 40), Vector2(55, 5)]},
	{"type": "lurker", "pos": Vector2(1200, 1000), "patrol": [Vector2(-60, 0), Vector2(0, 50)]},
	{"type": "gunner", "pos": Vector2(1940, 760), "patrol": [Vector2(-35, 55), Vector2(30, -30)]},
	{"type": "elite", "pos": Vector2(2130, 1120), "patrol": [Vector2(-45, 25), Vector2(30, -20)]},
	{"type": "elite", "pos": Vector2(810, 530), "patrol": [Vector2(-70, -50), Vector2(35, 30)]},
	{"type": "lurker", "pos": Vector2(600, 870), "patrol": [Vector2(45, -35), Vector2(-35, 50)]},
]

const LAMPS := [
	{"pos": Vector2(520, 300), "color": Color("ffc97a")},
	{"pos": Vector2(1250, 690), "color": Color("bcd8e8")},
	{"pos": Vector2(1760, 700), "color": Color("bcd8e8")},
	{"pos": Vector2(470, 1080), "color": Color("ffc97a")},
	{"pos": Vector2(2130, 1240), "color": Color("8fe3c8")},
	{"pos": Vector2(1870, 210), "color": Color("bcd8e8")},
]

const CONTAINERS := [
	{"rect": Rect2(1080, 240, 260, 88), "color": Color("9c4f3f"), "horizontal": true},
	{"rect": Rect2(1400, 240, 260, 88), "color": Color("3f7a78"), "horizontal": true},
	{"rect": Rect2(1080, 420, 260, 88), "color": Color("4a5f75"), "horizontal": true},
	{"rect": Rect2(1400, 420, 260, 88), "color": Color("a06a3e"), "horizontal": true},
	{"rect": Rect2(1700, 340, 88, 260), "color": Color("3f7a78"), "horizontal": false},
	{"rect": Rect2(1080, 760, 88, 260), "color": Color("8e4b3c"), "horizontal": false},
	{"rect": Rect2(1350, 760, 88, 260), "color": Color("4a5f75"), "horizontal": false},
	{"rect": Rect2(1600, 760, 88, 260), "color": Color("3f7a78"), "horizontal": false},
	{"rect": Rect2(1850, 620, 260, 88), "color": Color("a06a3e"), "horizontal": true},
	{"rect": Rect2(1850, 850, 260, 88), "color": Color("4a5f75"), "horizontal": true},
	{"rect": Rect2(1700, 1040, 260, 88), "color": Color("8e4b3c"), "horizontal": true},
]

const CRATES := [
	{"rect": Rect2(860, 760, 54, 54)},
	{"rect": Rect2(905, 815, 44, 44)},
	{"rect": Rect2(700, 900, 60, 44)},
	{"rect": Rect2(1950, 300, 50, 50)},
	{"rect": Rect2(350, 1150, 56, 56)},
	{"rect": Rect2(700, 1210, 50, 50)},
	{"rect": Rect2(1250, 1320, 60, 44)},
]

const PUDDLES := [
	{"pos": Vector2(1150, 1120), "rx": 70.0, "ry": 22.0},
	{"pos": Vector2(620, 700), "rx": 55.0, "ry": 18.0},
	{"pos": Vector2(1870, 1040), "rx": 45.0, "ry": 14.0},
	{"pos": Vector2(1450, 940), "rx": 60.0, "ry": 16.0},
]

const CONCRETE := Color("2a3638")
const WATER := Color("0a1b24")
const PLANK := Color("6d5638")
const PLANK_DARK := Color("4b3b28")

var build_collisions := true


func _ready() -> void:
	z_index = -10
	if build_collisions:
		_build_collision()
	queue_redraw()


func _build_collision() -> void:
	# 场外水域
	_add_static(Rect2(-20, -20, WORLD_RECT.size.x + 40, 120))
	_add_static(Rect2(-20, WORLD_RECT.size.y - 80, WORLD_RECT.size.x + 40, 120))
	_add_static(Rect2(-20, -20, 120, WORLD_RECT.size.y + 40))
	_add_static(Rect2(WORLD_RECT.size.x - 80, -20, 120, WORLD_RECT.size.y + 40))
	# 仓库墙体（南墙留门）
	_add_static(Rect2(260, 200, 640, 22))
	_add_static(Rect2(260, 200, 22, 420))
	_add_static(Rect2(878, 200, 22, 420))
	_add_static(Rect2(260, 598, 260, 22))
	_add_static(Rect2(636, 598, 264, 22))
	# 仓库货架
	_add_static(Rect2(320, 270, 130, 28))
	_add_static(Rect2(320, 360, 130, 28))
	_add_static(Rect2(700, 270, 140, 28))
	_add_static(Rect2(700, 510, 140, 28))
	# 集装箱
	for box in CONTAINERS:
		_add_static(box["rect"])
	# 木箱
	for crate in CRATES:
		_add_static(crate["rect"])


func _add_static(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	body.add_child(shape)
	add_child(body)


func _draw() -> void:
	_draw_water()
	draw_rect(Rect2(BOUNDS.position + Vector2(10, 12), BOUNDS.size), Color(0, 0, 0, 0.4), true)
	draw_rect(BOUNDS, CONCRETE, true)
	_draw_concrete_detail()
	_draw_decks()
	_draw_building()
	_draw_puddles()
	_draw_fence()
	_draw_containers()
	_draw_crates()
	_draw_lamp_fixtures()
	_draw_extraction_deck()
	_draw_water_markings()


func _draw_water() -> void:
	draw_rect(WORLD_RECT, WATER, true)
	var waves := PackedVector2Array()
	var y := 16.0
	var i := 0
	while y < WORLD_RECT.size.y:
		waves.append(Vector2(8 + i % 3 * 12, y))
		waves.append(Vector2(WORLD_RECT.size.x - 20, y + 3))
		y += 34.0
		i += 1
	draw_multiline(waves, Color(0.25, 0.55, 0.64, 0.05), 1.0)
	for buoy in [Vector2(60, 420), Vector2(2350, 620), Vector2(70, 1390), Vector2(2300, 1430)]:
		draw_circle(buoy, 7.0, Color("a55a3f"), true)


func _draw_concrete_detail() -> void:
	var seams := PackedVector2Array()
	for x in range(180, 2300, 180):
		seams.append(Vector2(x, BOUNDS.position.y + 8))
		seams.append(Vector2(x, BOUNDS.end.y - 8))
	for y in range(180, 1420, 150):
		seams.append(Vector2(BOUNDS.position.x + 8, y))
		seams.append(Vector2(BOUNDS.end.x - 8, y))
	draw_multiline(seams, Color(1, 1, 1, 0.025), 1.0)
	var warning := PackedVector2Array()
	for x in range(140, 2260, 46):
		warning.append(Vector2(x, 126))
		warning.append(Vector2(x + 22, 126))
	draw_multiline(warning, Color(0.85, 0.7, 0.35, 0.14), 3.0)
	FogUITheme.draw_text(self, Vector2(150, 180), "雾港 04 号泊位", 18, Color(0.7, 0.82, 0.82, 0.22), true)
	FogUITheme.draw_text(self, Vector2(1520, 148), "集装箱堆场 · C 区", 16, Color(0.7, 0.82, 0.82, 0.2), true)


func _draw_decks() -> void:
	_draw_planks(Rect2(100, 690, 230, 190), true)
	_draw_planks(Rect2(2020, 150, 280, 170), true)
	for p in [Vector2(120, 710), Vector2(120, 850), Vector2(310, 710), Vector2(310, 850)]:
		draw_circle(p, 7.0, Color("4b4436"), true)


func _draw_planks(rect: Rect2, horizontal: bool) -> void:
	draw_rect(rect, PLANK, true)
	var lines := PackedVector2Array()
	var step := 22.0
	if horizontal:
		var y := rect.position.y
		while y < rect.end.y:
			lines.append(Vector2(rect.position.x, y))
			lines.append(Vector2(rect.end.x, y))
			y += step
	else:
		var x := rect.position.x
		while x < rect.end.x:
			lines.append(Vector2(x, rect.position.y))
			lines.append(Vector2(x, rect.end.y))
			x += step
	draw_multiline(lines, PLANK_DARK, 1.0)
	draw_rect(rect, Color(0, 0, 0, 0.25), false, 2.0)


func _draw_building() -> void:
	draw_rect(Rect2(282, 222, 596, 376), Color("20292a"), true)
	draw_rect(Rect2(282, 222, 596, 376), Color(1, 1, 1, 0.025), false, 1.0)
	var wall := Color("3a4645")
	for wall_rect in [
		Rect2(260, 200, 640, 22), Rect2(260, 200, 22, 420), Rect2(878, 200, 22, 420),
		Rect2(260, 598, 260, 22), Rect2(636, 598, 264, 22),
	]:
		draw_rect(wall_rect, wall, true)
	draw_line(Vector2(260, 200), Vector2(900, 200), Color(1, 1, 1, 0.13), 2.0)
	draw_line(Vector2(520, 609), Vector2(636, 609), FogUITheme.AMBER_DIM, 2.0)
	FogUITheme.draw_text(self, Vector2(536, 590), "库门", 11, Color(0.85, 0.72, 0.42, 0.42))
	var slats := PackedVector2Array()
	for rack in [Rect2(320, 270, 130, 28), Rect2(320, 360, 130, 28), Rect2(700, 270, 140, 28), Rect2(700, 510, 140, 28)]:
		draw_rect(rack, Color("4f4030"), true)
		draw_rect(rack, Color("7c6546"), false, 1.0)
		for x in range(int(rack.position.x) + 10, int(rack.end.x) - 4, 20):
			slats.append(Vector2(x, rack.position.y + 4))
			slats.append(Vector2(x, rack.end.y - 4))
	draw_multiline(slats, Color(0, 0, 0, 0.25), 1.0)
	draw_line(Vector2(520, 222), Vector2(520, 300), Color(0.4, 0.4, 0.35, 0.4), 1.0)
	draw_circle(Vector2(520, 304), 7.0, Color("f2cf8a"), true)


func _draw_puddles() -> void:
	for p in PUDDLES:
		_ellipse(p["pos"], p["rx"], p["ry"], Color(0.12, 0.28, 0.33, 0.42))


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)


func _draw_fence() -> void:
	var rails := PackedVector2Array([
		Vector2(112, 112), Vector2(2288, 112), Vector2(112, 1408), Vector2(2288, 1408),
		Vector2(112, 112), Vector2(112, 1408), Vector2(2288, 112), Vector2(2288, 1408),
	])
	draw_multiline(rails, Color(0.3, 0.38, 0.38, 0.75), 2.0)
	var posts := PackedVector2Array()
	for x in range(112, 2290, 84):
		posts.append(Vector2(x, 100)); posts.append(Vector2(x, 124))
		posts.append(Vector2(x, 1396)); posts.append(Vector2(x, 1420))
	for y in range(112, 1410, 84):
		posts.append(Vector2(100, y)); posts.append(Vector2(124, y))
		posts.append(Vector2(2276, y)); posts.append(Vector2(2300, y))
	draw_multiline(posts, Color(0.45, 0.55, 0.53, 0.55), 3.0)


func _draw_containers() -> void:
	var ribs := PackedVector2Array()
	var doors := PackedVector2Array()
	var labels: Array = []
	for i in range(CONTAINERS.size()):
		var box: Dictionary = CONTAINERS[i]
		var rect: Rect2 = box["rect"]
		var color: Color = box["color"]
		var horizontal: bool = box["horizontal"]
		draw_rect(rect, color.darkened(0.24), true)
		draw_rect(rect.grow(-3), color, true)
		if horizontal:
			var x := rect.position.x + 14
			while x < rect.end.x - 10:
				ribs.append(Vector2(x, rect.position.y + 8))
				ribs.append(Vector2(x, rect.end.y - 8))
				x += 18.0
			var door_x := rect.end.x - 26
			doors.append(Vector2(door_x, rect.position.y + 6))
			doors.append(Vector2(door_x, rect.end.y - 6))
		else:
			var y := rect.position.y + 14
			while y < rect.end.y - 10:
				ribs.append(Vector2(rect.position.x + 8, y))
				ribs.append(Vector2(rect.end.x - 8, y))
				y += 18.0
			var door_y := rect.end.y - 26
			doors.append(Vector2(rect.position.x + 6, door_y))
			doors.append(Vector2(rect.end.x - 6, door_y))
		if i % 3 == 0:
			labels.append({"pos": rect.position + Vector2(12, 17), "text": "C-%02d" % (i + 3), "color": color.lightened(0.5)})
	draw_multiline(ribs, Color(0, 0, 0, 0.22), 1.5)
	draw_multiline(doors, Color(0, 0, 0, 0.32), 2.0)
	for label in labels:
		FogUITheme.draw_text(self, label["pos"], String(label["text"]), 8, label["color"])


func _draw_crates() -> void:
	var crosses := PackedVector2Array()
	for crate in CRATES:
		var rect: Rect2 = crate["rect"]
		draw_rect(rect, Color("5b4a33"), true)
		draw_rect(rect, Color("8a7050"), false, 1.5)
		crosses.append(rect.position)
		crosses.append(rect.end)
		crosses.append(Vector2(rect.end.x, rect.position.y))
		crosses.append(Vector2(rect.position.x, rect.end.y))
	draw_multiline(crosses, Color(0.3, 0.22, 0.14, 0.6), 1.5)


func _draw_lamp_fixtures() -> void:
	var poles := PackedVector2Array()
	for lamp in LAMPS:
		var p: Vector2 = lamp["pos"]
		draw_circle(p, 18.0, Color(lamp["color"], 0.10), true)
		draw_circle(p, 4.5, lamp["color"], true)
		poles.append(p + Vector2(0, 2))
		poles.append(p + Vector2(0, 26))
	draw_multiline(poles, Color("2b3233"), 3.0)


func _draw_extraction_deck() -> void:
	_draw_planks(EXTRACTION_RECT, true)
	var rail := PackedVector2Array()
	for x in range(int(EXTRACTION_RECT.position.x), int(EXTRACTION_RECT.end.x), 40):
		rail.append(Vector2(x, EXTRACTION_RECT.end.y - 10))
		rail.append(Vector2(x, EXTRACTION_RECT.end.y))
	rail.append(Vector2(EXTRACTION_RECT.position.x, EXTRACTION_RECT.end.y - 10))
	rail.append(Vector2(EXTRACTION_RECT.end.x, EXTRACTION_RECT.end.y - 10))
	draw_multiline(rail, Color(0.4, 0.5, 0.48, 0.55), 2.0)


func _draw_water_markings() -> void:
	# 水面上的旧货轮剪影，增加港区尺度感
	var hull := PackedVector2Array([
		Vector2(1860, 60), Vector2(2240, 60), Vector2(2200, 110),
		Vector2(1900, 110),
	])
	draw_colored_polygon(hull, Color(0.06, 0.12, 0.15, 0.9))
	draw_rect(Rect2(1940, 36, 120, 28), Color(0.06, 0.12, 0.15, 0.9), true)
	draw_line(Vector2(2100, 56), Vector2(2100, 20), Color(0.06, 0.12, 0.15, 0.9), 2.0)
	draw_circle(Vector2(2112, 18), 2.5, Color(0.8, 0.5, 0.25, 0.5), true)
