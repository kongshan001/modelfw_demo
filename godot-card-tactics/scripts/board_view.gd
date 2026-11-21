class_name BoardView
extends Control

const AssetLoaderScript = preload("res://scripts/asset_loader.gd")

const BattleCoreScript = preload("res://scripts/battle_core.gd")

# 9×5 棋盘的绘制与点击区域。只画格子和高亮，单位由 main 管理的 UnitView 负责。
# T-019 美术整改：格面明度 +4 L*；高亮改为“颜色 + 形状”双编码，固定绘制顺序
# 移动 < 召唤 < 法术 < 选中 < 攻击；攻击环带 0.6s 呼吸，成为全场最高视觉权重。

signal tile_clicked(pos: Vector2i)

const COLS := 9
const ROWS := 5
const CELL := 88.0

const TILE_A := Color("#202b3d")
const TILE_B := Color("#1e293a")
const GRID_LINE := Color(0.5, 0.66, 0.76, 0.12)
const MOVE_COLOR := Color("#6ff2cf")
const ATTACK_COLOR := Color("#e5484d")
const ATTACK_DARK := Color(0.10, 0.02, 0.03, 0.85)
const SPELL_COLOR := Color("#7aa2ff")
const SUMMON_COLOR := Color("#e8c56a")
const SELECT_COLOR := Color("#f7f2df")
const ENEMY_EDGE := Color(0.83, 0.40, 0.48, 0.42)
const ALLY_EDGE := Color(0.91, 0.77, 0.42, 0.46)

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
var _pulse := 0.0
var _pulse_accum := 0.0


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


func _process(delta: float) -> void:
	# 仅在存在攻击目标时做低频呼吸重绘（约 13 次/秒），避免空场常驻开销。
	if attack_tiles.is_empty():
		return
	_pulse_accum += delta
	if _pulse_accum < 0.075:
		return
	_pulse_accum = 0.0
	_pulse = fposmod(_pulse + 0.075 / 0.6, 1.0)
	queue_redraw()


func _draw() -> void:
	var board_rect := Rect2(Vector2.ZERO, size)
	draw_rect(board_rect.grow(8.0), Color(0.03, 0.05, 0.075, 0.96))
	draw_rect(board_rect.grow(8.0), Color(0.33, 0.43, 0.5, 0.45), false, 2.0)

	for y in ROWS:
		for x in COLS:
			var rect := Rect2(Vector2(x * CELL + 1.5, y * CELL + 1.5), Vector2(CELL - 3.0, CELL - 3.0))
			var base := TILE_A if (x + y) % 2 == 0 else TILE_B
			draw_rect(rect, base)
			draw_rect(rect, GRID_LINE, false, 1.0)

	# 阵地只保留 3px 外缘线（上 = 敌方绯，下 = 己方金），不再整行染色，
	# 避免第 4 行的橄榄底色与金色召唤圈抢语义。
	draw_rect(Rect2(0, 0, COLS * CELL, 3), ENEMY_EDGE)
	draw_rect(Rect2(0, ROWS * CELL - 3, COLS * CELL, 3), ALLY_EDGE)

	# 中线的装饰刻点。
	for x in COLS:
		draw_circle(Vector2((x + 0.5) * CELL, ROWS * 0.5 * CELL), 1.5, Color(0.7, 0.8, 0.85, 0.16))
	for y in ROWS:
		draw_circle(Vector2(COLS * 0.5 * CELL, (y + 0.5) * CELL), 1.5, Color(0.7, 0.8, 0.85, 0.16))

	if hovered.x >= 0 and hovered.x < COLS and hovered.y >= 0 and hovered.y < ROWS:
		draw_texture_rect(_tex_hover, _tile_rect(hovered), false, Color(0.85, 0.95, 1.0, 0.10))

	# 1) 移动：青框 + 四角刻度 + 22% 填充 + 中心点（不再整格高亮压过攻击）。
	for pos: Vector2i in move_tiles:
		var rect := _tile_rect(pos).grow(-3.0)
		draw_rect(rect, _a(MOVE_COLOR, 0.12))
		draw_texture_rect(_tex_hover, _tile_rect(pos), false, _a(MOVE_COLOR, 0.10))
		draw_rect(rect, _a(MOVE_COLOR, 0.90), false, 2.0)
		_draw_corner_ticks(rect, _a(MOVE_COLOR, 0.95), 8.0, 2.0)
		draw_circle(cell_center(pos), 3.5, _a(MOVE_COLOR, 0.92))

	# 2) 召唤：金圈 + “+” + 15% 填充，与移动/攻击/法术各自结构不同。
	for pos: Vector2i in summon_tiles:
		var center := cell_center(pos)
		draw_rect(_tile_rect(pos).grow(-2.0), _a(SUMMON_COLOR, 0.15))
		draw_texture_rect(_tex_spawn, _tile_rect(pos), false, _a(SUMMON_COLOR, 0.22))
		draw_arc(center, 30.0, 0.0, TAU, 40, Color(0.03, 0.02, 0.01, 0.58), 4.0, true)
		draw_arc(center, 29.0, 0.0, TAU, 40, _a(SUMMON_COLOR, 0.95), 2.5, true)
		draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), _a(SUMMON_COLOR, 0.95), 2.0, true)
		draw_line(center + Vector2(0, -7), center + Vector2(0, 7), _a(SUMMON_COLOR, 0.95), 2.0, true)

	# 3) 法术：虚线环 + 中心符心，与攻击同为 r≈30 但结构不同（色弱可区分）。
	for pos: Vector2i in spell_targets:
		var center := cell_center(pos)
		draw_rect(_tile_rect(pos).grow(-2.0), _a(SPELL_COLOR, 0.12))
		draw_texture_rect(_tex_spell, _tile_rect(pos), false, _a(SPELL_COLOR, 0.18))
		for i in 8:
			var start := TAU * float(i) / 8.0
			draw_arc(center, 30.0, start, start + TAU / 8.0 * 0.55, 6, _a(SPELL_COLOR, 0.95), 4.0, true)
		var rune := PackedVector2Array([
			center + Vector2(0, -6), center + Vector2(6, 0),
			center + Vector2(0, 6), center + Vector2(-6, 0),
		])
		draw_colored_polygon(rune, _a(SPELL_COLOR, 0.95))

	# 4) 选中：近白双环 + 四角括号；不再与金色单位/召唤圈共用金色。
	if selected_pos.x >= 0:
		var center := cell_center(selected_pos)
		draw_rect(_tile_rect(selected_pos).grow(-2.0), _a(SELECT_COLOR, 0.10))
		draw_texture_rect(_tex_target, _tile_rect(selected_pos), false, _a(SELECT_COLOR, 0.14))
		draw_arc(center, 34.0, 0.0, TAU, 48, _a(SELECT_COLOR, 0.95), 3.0, true)
		draw_arc(center, 39.0, 0.0, TAU, 48, _a(SELECT_COLOR, 0.55), 1.5, true)
		_draw_corner_brackets(_tile_rect(selected_pos).grow(-1.0), _a(SELECT_COLOR, 0.95), 12.0, 2.0)

	# 5) 攻击：最高权重，最后绘制；18% 填充 + 4px 环 + 4 个向内箭头 + 呼吸。
	var pulse := 0.5 + 0.5 * sin(_pulse * TAU) if not attack_tiles.is_empty() else 0.5
	for pos: Vector2i in attack_tiles:
		var center := cell_center(pos)
		draw_rect(_tile_rect(pos).grow(-2.0), _a(ATTACK_COLOR, 0.24 + pulse * 0.04))
		draw_texture_rect(_tex_attack, _tile_rect(pos), false, _a(ATTACK_COLOR, 0.32))
		draw_arc(center, 28.0 + pulse * 0.8, 0.0, TAU, 44, ATTACK_DARK, 6.0, true)
		draw_arc(center, 29.0 + pulse * 1.2, 0.0, TAU, 44, _a(ATTACK_COLOR, 0.88 + pulse * 0.12), 4.0, true)
		for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var side := Vector2(-dir.y, dir.x)
			var tip := center + dir * 20.0
			var base := center + dir * 28.0
			var arrow := PackedVector2Array([tip, base + side * 4.0, base - side * 4.0])
			draw_colored_polygon(arrow, ATTACK_DARK)
			var inner := PackedVector2Array([
				center + dir * 21.0,
				center + dir * 26.5 + side * 2.8,
				center + dir * 26.5 - side * 2.8,
			])
			draw_colored_polygon(inner, _a(ATTACK_COLOR, 0.98))


func _tile_rect(pos: Vector2i) -> Rect2:
	return Rect2(Vector2(pos.x * CELL, pos.y * CELL), Vector2(CELL, CELL))


func _a(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func _draw_corner_ticks(rect: Rect2, color: Color, length: float, width: float) -> void:
	var p := rect.position
	var q := rect.end
	draw_line(p, p + Vector2(length, 0), color, width, true)
	draw_line(p, p + Vector2(0, length), color, width, true)
	draw_line(Vector2(q.x, p.y), Vector2(q.x - length, p.y), color, width, true)
	draw_line(Vector2(q.x, p.y), Vector2(q.x, p.y + length), color, width, true)
	draw_line(Vector2(p.x, q.y), Vector2(p.x + length, q.y), color, width, true)
	draw_line(Vector2(p.x, q.y), Vector2(p.x, q.y - length), color, width, true)
	draw_line(q, q - Vector2(length, 0), color, width, true)
	draw_line(q, q - Vector2(0, length), color, width, true)


func _draw_corner_brackets(rect: Rect2, color: Color, length: float, width: float) -> void:
	# 只画朝内的 L 形括号，避免与选中双环重复。
	var p := rect.position
	var q := rect.end
	draw_line(p + Vector2(4, 0), p + Vector2(length, 0), color, width, true)
	draw_line(p + Vector2(0, 4), p + Vector2(0, length), color, width, true)
	draw_line(Vector2(q.x - 4, p.y), Vector2(q.x - length, p.y), color, width, true)
	draw_line(Vector2(q.x, p.y + 4), Vector2(q.x, p.y + length), color, width, true)
	draw_line(Vector2(p.x + 4, q.y), Vector2(p.x + length, q.y), color, width, true)
	draw_line(Vector2(p.x, q.y - 4), Vector2(p.x, q.y - length), color, width, true)
	draw_line(q - Vector2(4, 0), q - Vector2(length, 0), color, width, true)
	draw_line(q - Vector2(0, 4), q - Vector2(0, length), color, width, true)


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
