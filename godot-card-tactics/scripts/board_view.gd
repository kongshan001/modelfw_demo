class_name BoardView
extends Control

const AssetLoaderScript = preload("res://scripts/asset_loader.gd")

const BattleCoreScript = preload("res://scripts/battle_core.gd")

# 9×5 棋盘的绘制与点击区域。只画格子和高亮，单位由 main 管理的 UnitView 负责。

signal tile_clicked(pos: Vector2i)

const COLS := 9
const ROWS := 5
const CELL := 88.0

var core: BattleCoreScript
var hovered := Vector2i(-1, -1)
var move_tiles: Array[Vector2i] = []
var attack_tiles: Array[Vector2i] = []
var summon_tiles: Array[Vector2i] = []
var spell_targets: Array[Vector2i] = []
var selected_uid := -1
var selected_pos := Vector2i(-1, -1)

var _tex_hover: Texture2D
var _tex_attack: Texture2D
var _tex_spawn: Texture2D
var _tex_spell: Texture2D
var _tex_target: Texture2D


func _ready() -> void:
	size = Vector2(COLS * CELL, ROWS * CELL)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tex_hover = AssetLoaderScript.texture("res://assets/duelyst_cc0/tiles/tile_hover.png")
	_tex_attack = AssetLoaderScript.texture("res://assets/duelyst_cc0/tiles/tile_attack.png")
	_tex_spawn = AssetLoaderScript.texture("res://assets/duelyst_cc0/tiles/tile_spawn.png")
	_tex_spell = AssetLoaderScript.texture("res://assets/duelyst_cc0/tiles/tile_spell.png")
	_tex_target = AssetLoaderScript.texture("res://assets/duelyst_cc0/tiles/tile_target.png")
	mouse_exited.connect(_on_mouse_exited)


func set_core(battle: BattleCoreScript) -> void:
	core = battle
	queue_redraw()


func set_highlights(moves: Array[Vector2i], attacks: Array[Vector2i], summons: Array[Vector2i], spells: Array[Vector2i], uid: int) -> void:
	move_tiles = moves
	attack_tiles = attacks
	summon_tiles = summons
	spell_targets = spells
	selected_uid = uid
	selected_pos = Vector2i(-1, -1)
	if uid >= 0 and core:
		var unit := core.find_unit(uid)
		if not unit.is_empty():
			selected_pos = Vector2i(unit["x"], unit["y"])
	queue_redraw()


func clear_highlights() -> void:
	move_tiles.clear()
	attack_tiles.clear()
	summon_tiles.clear()
	spell_targets.clear()
	selected_uid = -1
	selected_pos = Vector2i(-1, -1)
	queue_redraw()


func cell_center(pos: Vector2i) -> Vector2:
	return Vector2((pos.x + 0.5) * CELL, (pos.y + 0.5) * CELL)


func _draw() -> void:
	var board_rect := Rect2(Vector2.ZERO, size)
	draw_rect(board_rect.grow(8.0), Color(0.03, 0.05, 0.075, 0.96))
	draw_rect(board_rect.grow(8.0), Color(0.33, 0.43, 0.5, 0.45), false, 2.0)

	for y in ROWS:
		for x in COLS:
			var pos := Vector2i(x, y)
			var rect := Rect2(Vector2(x * CELL + 1.5, y * CELL + 1.5), Vector2(CELL - 3.0, CELL - 3.0))
			var base := Color("#1c2737")
			if y == 0:
				base = Color("#2a2235")
			elif y == ROWS - 1:
				base = Color("#2b2a23")
			elif (x + y) % 2 == 0:
				base = Color("#1b2636")
			else:
				base = Color("#192232")
			draw_rect(rect, base)
			draw_rect(rect, Color(0.45, 0.6, 0.7, 0.10), false, 1.0)
			if y == 0:
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color(0.62, 0.32, 0.46, 0.38))
			elif y == ROWS - 1:
				draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 3), Vector2(rect.size.x, 3)), Color(0.75, 0.62, 0.28, 0.38))

	# 中线的装饰刻点。
	for x in COLS:
		draw_circle(Vector2((x + 0.5) * CELL, ROWS * 0.5 * CELL), 1.5, Color(0.7, 0.8, 0.85, 0.18))
	for y in ROWS:
		draw_circle(Vector2(COLS * 0.5 * CELL, (y + 0.5) * CELL), 1.5, Color(0.7, 0.8, 0.85, 0.18))

	if hovered.x >= 0 and hovered.x < COLS and hovered.y >= 0 and hovered.y < ROWS:
		draw_texture_rect(_tex_hover, _tile_rect(hovered), false, Color(0.85, 0.95, 1.0, 0.12))

	for pos in move_tiles:
		draw_texture_rect(_tex_hover, _tile_rect(pos), false, Color(0.32, 0.95, 0.75, 0.55))
		draw_circle(cell_center(pos), 5.0, Color(0.65, 1.0, 0.88, 0.85))

	for pos in summon_tiles:
		draw_texture_rect(_tex_spawn, _tile_rect(pos), false, Color(1.0, 0.82, 0.36, 0.72))
		draw_arc(cell_center(pos), 12.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.55, 0.9), 2.0)

	for pos in attack_tiles:
		draw_texture_rect(_tex_attack, _tile_rect(pos), false, Color(1.0, 0.32, 0.28, 0.72))
		draw_arc(cell_center(pos), 27.0, 0.0, TAU, 32, Color(1.0, 0.48, 0.4, 0.95), 2.5)

	for pos in spell_targets:
		draw_texture_rect(_tex_spell, _tile_rect(pos), false, Color(0.55, 0.72, 1.0, 0.65))
		draw_arc(cell_center(pos), 27.0, 0.0, TAU, 32, Color(0.65, 0.85, 1.0, 0.95), 2.5)

	if selected_pos.x >= 0:
		var center := cell_center(selected_pos)
		draw_texture_rect(_tex_target, _tile_rect(selected_pos), false, Color(1.0, 0.9, 0.5, 0.4))
		draw_arc(center, 31.0, 0.0, TAU, 40, Color(1.0, 0.86, 0.42, 0.95), 2.5)
		draw_arc(center, 35.0, 0.0, TAU, 40, Color(1.0, 0.86, 0.42, 0.35), 1.5)


func _tile_rect(pos: Vector2i) -> Rect2:
	return Rect2(Vector2(pos.x * CELL, pos.y * CELL), Vector2(CELL, CELL))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos := _pos_from_event(event.position)
		if pos != hovered:
			hovered = pos
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var pos := _pos_from_event(event.position)
			if pos.x >= 0:
				tile_clicked.emit(pos)
				accept_event()


func _pos_from_event(local: Vector2) -> Vector2i:
	var x := int(local.x / CELL)
	var y := int(local.y / CELL)
	if x < 0 or x >= COLS or y < 0 or y >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func _on_mouse_exited() -> void:
	hovered = Vector2i(-1, -1)
	queue_redraw()
