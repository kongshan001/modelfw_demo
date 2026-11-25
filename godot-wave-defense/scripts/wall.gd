extends Node2D
## 最后卡口的可修木石墙：敌人先拆墙，墙破后才会攻击主城。波间花金币修缮/重建。

const Data = preload("res://scripts/game_data.gd")
const Art = preload("res://scripts/art.gd")

var max_hp := Data.WALL_MAX_HP
var hp := 80.0
var alive := true
var flash := 0.0
var _main


func setup(main_ref) -> void:
	_main = main_ref
	position = Data.WALL_POS
	reset()


func reset() -> void:
	max_hp = Data.WALL_MAX_HP
	hp = 80.0
	alive = true
	flash = 0.0
	queue_redraw()


func tick(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta)
		queue_redraw()


func damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	flash = 0.16
	if _main != null:
		_main.on_wall_damaged(amount, position)
	if hp <= 0.0:
		alive = false
		if _main != null:
			_main.on_wall_destroyed()
	queue_redraw()


func repair() -> void:
	alive = true
	hp = max_hp
	flash = 0.0
	queue_redraw()


func repair_cost() -> int:
	if alive and hp >= max_hp:
		return 0
	if not alive:
		return Data.WALL_REBUILD_COST
	return Data.WALL_REPAIR_COST


func ratio() -> float:
	return clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)


func _draw() -> void:
	var tangent := Data.path_tangent_at(Data.path_length())
	var angle := Vector2(-tangent.y, tangent.x).angle()
	if not alive:
		_draw_rubble()
		return
	draw_line(Vector2(-42, 8), Vector2(42, 8), Color(0, 0, 0, 0.35), 12.0)
	draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	var tint := 1.0 - clampf(flash / 0.16, 0.0, 1.0) * 0.55
	var wood := Color("6b5036").lerp(Color.WHITE, 1.0 - tint)
	var wood_dark := Color("463424").lerp(Color.WHITE, 1.0 - tint)
	var stone := Art.STONE.lerp(Color.WHITE, 1.0 - tint)
	# 两侧石柱。
	for x in [-40.0, 40.0]:
		draw_rect(Rect2(x - 6, -28, 12, 40), stone, true)
		draw_rect(Rect2(x - 7, -31, 14, 5), stone.lightened(0.15), true)
	# 横向木墙与斜撑。
	draw_rect(Rect2(-38, -20, 76, 30), wood_dark, true)
	for i in range(5):
		draw_rect(Rect2(-34 + i * 15, -22, 10, 33), wood, true)
		draw_line(Vector2(-34 + i * 15, 10), Vector2(-24 + i * 15, -21), Color(0, 0, 0, 0.20), 1.5)
	draw_line(Vector2(-38, -13), Vector2(38, -13), wood_dark, 3.0)
	draw_line(Vector2(-36, 14), Vector2(36, 14), stone.darkened(0.2), 4.0)
	# 盾牌与青色小旗（原创纹样）。
	draw_circle(Vector2(-2, -4), 10.5, Color("2b3a31"))
	draw_circle(Vector2(-2, -4), 8.2, Art.TEAL_DARK)
	Art.diamond(self, Vector2(-2, -4), 5.2, Art.GOLD)
	draw_line(Vector2(24, -20), Vector2(24, -44), Color("3b2c20"), 2.5)
	var flag := PackedVector2Array([Vector2(25, -43), Vector2(48, -38), Vector2(25, -30)])
	draw_colored_polygon(flag, Art.TEAL)
	# 损伤。
	if ratio() < 0.65:
		draw_line(Vector2(-20, -18), Vector2(-9, 3), Color(0.14, 0.09, 0.05, 0.75), 2.0)
		draw_line(Vector2(-9, 3), Vector2(-18, 10), Color(0.14, 0.09, 0.05, 0.75), 2.0)
	if ratio() < 0.32:
		draw_line(Vector2(17, -17), Vector2(6, 1), Color(0.14, 0.09, 0.05, 0.8), 2.0)
		draw_line(Vector2(6, 1), Vector2(16, 11), Color(0.14, 0.09, 0.05, 0.8), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 墙上的小血条。
	if hp < max_hp:
		var bar_rect := Rect2(-30, -56, 60, 5)
		draw_rect(bar_rect, Color(0, 0, 0, 0.65), true)
		draw_rect(Rect2(bar_rect.position + Vector2(1, 1), Vector2(58.0 * ratio(), 3)), Art.RUST.lerp(Art.GREEN, ratio()), true)


func _draw_rubble() -> void:
	draw_line(Vector2(-42, 8), Vector2(42, 8), Color(0, 0, 0, 0.3), 10.0)
	for i in range(7):
		var x := -34.0 + i * 11.0
		var y := float((i * 7) % 9)
		draw_rect(Rect2(x, -4 + y, 9, 5), Color("4a3a2b") if i % 2 == 0 else Art.STONE_DARK, true)
	draw_line(Vector2(-38, -2), Vector2(-28, -18), Color("3d2c1e"), 5.0)
	draw_line(Vector2(32, 0), Vector2(41, -13), Color("3d2c1e"), 5.0)
	Art.text_center(self, Rect2(-40, -38, 80, 16), "城墙已破", 12, Art.RED, true)
