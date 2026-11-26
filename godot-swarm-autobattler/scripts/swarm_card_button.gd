class_name SwarmCardButton
extends Button

## Original production card face (T-20261126-026):
## illustration window + rarity frame + faction edge + cost gem + role icon +
## icon/value chips + large xN count. One button per shop slot / board slot.

const Cards = preload("res://scripts/swarm_cards.gd")
const ThemeKit = preload("res://scripts/swarm_theme.gd")
const Art = preload("res://scripts/swarm_art.gd")

var card_id := ""
var star := 1
var squad_units := 0
var price := 0
var sell_price := 0
var mode := "shop"
var selected := false
var affordable := true
var empty := true
var slot_index := 0

var _hovered := false
var _f_reg: Font = null
var _f_bold: Font = null
var _f_num: Font = null


func _ready() -> void:
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_f_reg = ThemeKit.make_font(false)
	_f_bold = ThemeKit.make_font(true)
	_f_num = ThemeKit.make_num_font()


func _on_hover(on: bool) -> void:
	_hovered = on
	queue_redraw()


func configure_empty(index: int, is_shop: bool = true) -> void:
	card_id = ""
	star = 1
	squad_units = 0
	price = 0
	sell_price = 0
	mode = "shop" if is_shop else "board"
	selected = false
	affordable = true
	empty = true
	slot_index = index
	disabled = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	tooltip_text = ""
	queue_redraw()


func configure_shop(id: String, units: int, can_afford: bool, index: int) -> void:
	var card := Cards.get_card(id)
	card_id = id
	star = 1
	squad_units = units
	price = int(card.get("cost", 0))
	sell_price = 0
	mode = "shop"
	selected = false
	affordable = can_afford
	empty = false
	slot_index = index
	disabled = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var tier := int(card.get("tier", 1))
	var lines := [
		"%s · %s阶 T%d · %s" % [String(card.get("name", "")), String(Cards.TIER_NAMES[tier]), tier, Cards.role_label(card)],
		"每单位  HP %d · ATK %d · 攻速 %.2f/s · 射程 %d" % [
			int(card["hp"]), int(card["atk"]), float(card["aspd"]), int(card["range"])],
		"编队 ×%s 单位 · 价格 ◆%d · 数字均为每单位" % [Cards.format_units(units), price],
		String(card.get("desc", "")),
	]
	tooltip_text = "\n".join(lines)
	queue_redraw()


func configure_board(entry: Dictionary, units: int, is_selected: bool, index: int) -> void:
	var card := Cards.get_card(String(entry.get("id", "")))
	card_id = String(entry.get("id", ""))
	star = int(entry.get("star", 1))
	squad_units = units
	price = 0
	sell_price = Cards.sell_value(entry)
	mode = "board"
	selected = is_selected
	affordable = true
	empty = false
	slot_index = index
	disabled = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var mult := 2 if star >= 2 else 1
	var tier := int(card.get("tier", 1))
	var lines := [
		"%s · %s · %s" % [String(card.get("name", "")), "★★ 金卡" if star >= 2 else "★",
			String(Cards.TIER_NAMES[tier]) + "阶"],
		"编队 ×%s 单位 · %s" % [Cards.format_units(units), Cards.role_label(card)],
		"每单位  HP %d · ATK %d · 攻速 %.2f/s · 射程 %d" % [
			int(card["hp"]) * mult, int(card["atk"]) * mult, float(card["aspd"]), int(card["range"])],
		String(card.get("desc", "")),
		"左键选中，右键直接出售（返还 ◆%d）" % sell_price,
	]
	tooltip_text = "\n".join(lines)
	queue_redraw()


func _panel(w: float, h: float, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(cut, 1), Vector2(w - 1, 1), Vector2(w - 1, h - cut),
		Vector2(w - cut, h - 1), Vector2(1, h - 1), Vector2(1, cut),
	])


func _draw() -> void:
	var w := size.x
	var h := size.y
	if _f_reg == null:
		_f_reg = ThemeKit.make_font(false)
		_f_bold = ThemeKit.make_font(true)
		_f_num = ThemeKit.make_num_font()
	if empty:
		_draw_empty(w, h)
		return
	var card := Cards.get_card(card_id)
	if card.is_empty():
		return
	var is_shop := mode == "shop"
	var tier := clampi(int(card.get("tier", 1)), 1, 5)
	var tier_col: Color = Cards.TIER_COLORS[tier]
	var mult := 2 if star >= 2 else 1

	# card body / cut corners
	var poly := _panel(w, h, 8.0)
	draw_colored_polygon(poly, Color(0.030, 0.070, 0.105, 0.98))
	var out := PackedVector2Array(poly)
	out.append(poly[0])
	draw_polyline(out, ThemeKit.PANEL_EDGE, 1.0, true)
	# tier bar + faction edge
	draw_rect(Rect2(1, 1, w - 2, 3), tier_col, true)
	draw_rect(Rect2(1, 4, 3, h - 5), ThemeKit.CYAN, true)
	# rarity frame: 1* gray single line, 2* gold double line + ornaments
	if star >= 2:
		draw_rect(Rect2(1.5, 1.5, w - 3, h - 3), ThemeKit.GOLD, false, 2.0)
		draw_rect(Rect2(4.5, 4.5, w - 9, h - 9), Color(0.94, 0.71, 0.35, 0.45), false, 1.0)
		_corner_marks(w, h, ThemeKit.GOLD, 4)
	else:
		draw_rect(Rect2(1.5, 1.5, w - 3, h - 3), Color("#6b7f91"), false, 1.0)
		_corner_marks(w, h, Color("#6b7f91"), 1)

	# illustration
	var art_rect := Rect2(7, 8, 52, 52) if is_shop else Rect2(7, 10, 40, 40)
	Art.draw_card_art(self, card_id, art_rect)
	draw_rect(art_rect, Color(tier_col.r, tier_col.g, tier_col.b, 0.85), false, 1.0)
	# tier badge
	var badge := 15.0 if is_shop else 13.0
	draw_rect(Rect2(art_rect.position.x, art_rect.position.y, badge, badge), Color(0.02, 0.05, 0.08, 0.9), true)
	draw_rect(Rect2(art_rect.position.x + 0.5, art_rect.position.y + 0.5, badge - 1, badge - 1),
		tier_col, false, 1.0)
	draw_string(_f_num, Vector2(art_rect.position.x + 1, art_rect.position.y + badge - 3), str(tier),
		HORIZONTAL_ALIGNMENT_CENTER, badge - 2, 10, tier_col)
	# xN main number on the illustration
	var strip_h := 16.0 if is_shop else 13.0
	var strip := Rect2(art_rect.position.x, art_rect.end.y - strip_h, art_rect.size.x, strip_h)
	draw_rect(strip, Color(0.02, 0.05, 0.07, 0.82), true)
	draw_string(_f_num, Vector2(strip.position.x, strip.position.y + strip_h - 3.5),
		"×" + Cards.format_units(squad_units), HORIZONTAL_ALIGNMENT_CENTER, strip.size.x,
		15 if is_shop else 12, ThemeKit.CYAN_SOFT)

	if is_shop:
		_draw_shop_text(w, h, card, tier, tier_col, mult)
	else:
		_draw_board_text(w, h, card, tier, tier_col, mult)

	# state overlays
	if selected:
		for i in 3:
			var a := 0.20 - float(i) * 0.05
			draw_rect(Rect2(-i, -i, w + i * 2, h + i * 2), Color(0.22, 0.88, 0.78, a), false, 1.0)
		draw_rect(Rect2(0.5, 0.5, w - 1, h - 1), ThemeKit.CYAN, false, 2.0)
	if _hovered and not disabled:
		draw_rect(Rect2(1.5, 1.5, w - 3, 1.5), Color(1, 1, 1, 0.18), true)
		draw_rect(Rect2(0.5, 0.5, w - 1, h - 1), ThemeKit.CYAN_SOFT, false, 1.0)
	if is_shop and not affordable:
		draw_rect(Rect2(1.5, 4.5, w - 3, h - 5.5), Color(0.01, 0.03, 0.05, 0.55), true)
		Art.draw_icon(self, "coin", Vector2(w - 33, 34), 12, ThemeKit.RED)
		draw_line(Vector2(w - 33, 34), Vector2(w - 21, 46), ThemeKit.RED, 2.0)
		draw_string(_f_reg, Vector2(6, h - 5), "金币不足", HORIZONTAL_ALIGNMENT_LEFT, 60, 10, ThemeKit.RED)


func _draw_shop_text(w: float, h: float, card: Dictionary, tier: int, tier_col: Color, _mult: int) -> void:
	# cost gem
	var cx := w - 20.0
	var cy := 20.0
	var gem := PackedVector2Array([
		Vector2(cx, 6), Vector2(cx + 12, cy), Vector2(cx, 34), Vector2(cx - 12, cy),
	])
	draw_colored_polygon(gem, Color(0.24, 0.18, 0.09, 1.0))
	var gem_out := PackedVector2Array(gem)
	gem_out.append(gem[0])
	draw_polyline(gem_out, ThemeKit.GOLD, 1.5, true)
	draw_string(_f_num, Vector2(cx - 12, cy + 5), str(price), HORIZONTAL_ALIGNMENT_CENTER, 24, 13,
		ThemeKit.GOLD if affordable else ThemeKit.RED)
	# name
	draw_string(_f_bold, Vector2(66, 22), String(card.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT,
		w - 66 - 34, 14, ThemeKit.TEXT)
	# stars
	var sx := 66.0
	for i in (2 if star >= 2 else 1):
		Art.draw_icon(self, "star", Vector2(sx + i * 10, 29), 9,
			ThemeKit.GOLD if star >= 2 else Color("#8fa6b8"))
	# role
	Art.draw_icon(self, Art.role_icon(card), Vector2(66, 40), 12, tier_col.lightened(0.2))
	draw_string(_f_reg, Vector2(80, 51), Cards.role_label(card), HORIZONTAL_ALIGNMENT_LEFT, 72, 12,
		ThemeKit.MUTED)
	# 2x2 chips
	var col_x := [66.0, 112.0]
	var row_y := [55.0, 76.0]
	_chip(Rect2(col_x[0], row_y[0], 45, 18), "hp", str(int(card["hp"])), ThemeKit.TEXT)
	_chip(Rect2(col_x[1], row_y[0], 45, 18), "atk", str(int(card["atk"])), ThemeKit.TEXT)
	_chip(Rect2(col_x[0], row_y[1], 45, 18), "aspd", "%.1f" % float(card["aspd"]), ThemeKit.MUTED)
	_chip(Rect2(col_x[1], row_y[1], 45, 18), "range", str(int(card["range"])), ThemeKit.MUTED)


func _draw_board_text(w: float, _h: float, card: Dictionary, tier: int, tier_col: Color, mult: int) -> void:
	# name / stars / role in the right column
	draw_string(_f_bold, Vector2(52, 22), String(card.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT,
		w - 52 - 4, 12, ThemeKit.TEXT)
	for i in (2 if star >= 2 else 1):
		Art.draw_icon(self, "star", Vector2(52 + i * 9, 28), 8,
			ThemeKit.GOLD if star >= 2 else Color("#8fa6b8"))
	Art.draw_icon(self, Art.role_icon(card), Vector2(52, 40), 11, tier_col.lightened(0.2))
	draw_string(_f_reg, Vector2(64, 50), Cards.role_label(card), HORIZONTAL_ALIGNMENT_LEFT,
		w - 64 - 4, 11, ThemeKit.MUTED)
	# two chips
	_chip(Rect2(7, 56, 49, 19), "hp", str(int(card["hp"]) * mult), ThemeKit.TEXT)
	_chip(Rect2(61, 56, 49, 19), "atk", str(int(card["atk"]) * mult), ThemeKit.TEXT)
	# large xN count is the main number on board cards
	draw_string(_f_num, Vector2(7, 89), "×" + Cards.format_units(squad_units),
		HORIZONTAL_ALIGNMENT_LEFT, 80, 15, ThemeKit.CYAN_SOFT)
	draw_string(_f_reg, Vector2(60, 89), "单位", HORIZONTAL_ALIGNMENT_LEFT, 50, 11, ThemeKit.MUTED)


func _chip(rect: Rect2, icon: String, value: String, value_color: Color) -> void:
	draw_rect(rect, Color(0.025, 0.055, 0.08, 0.95), true)
	draw_rect(rect, Color(0.13, 0.23, 0.31, 0.9), false, 1.0)
	Art.draw_icon(self, icon, rect.position + Vector2(3, 3), 12, ThemeKit.MUTED)
	draw_string(_f_num, rect.position + Vector2(17, 14), value, HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x - 19, 12, value_color)


func _corner_marks(w: float, h: float, col: Color, count: int) -> void:
	var corners := [Vector2(2, 2), Vector2(w - 2, 2), Vector2(2, h - 2), Vector2(w - 2, h - 2)]
	for i in mini(count, 4):
		var c: Vector2 = corners[i]
		var sx := 1.0 if c.x < w * 0.5 else -1.0
		var sy := 1.0 if c.y < h * 0.5 else -1.0
		draw_line(c, c + Vector2(6 * sx, 0), col, 1.4)
		draw_line(c, c + Vector2(0, 6 * sy), col, 1.4)


func _draw_empty(w: float, h: float) -> void:
	var dash_col := Color(0.28, 0.42, 0.50, 0.55)
	for i in range(0, int(w) - 12, 10):
		draw_line(Vector2(6 + i, 1.5), Vector2(6 + i + 5, 1.5), dash_col, 1.0)
		draw_line(Vector2(6 + i, h - 1.5), Vector2(6 + i + 5, h - 1.5), dash_col, 1.0)
	for i in range(0, int(h) - 12, 10):
		draw_line(Vector2(1.5, 6 + i), Vector2(1.5, 6 + i + 5), dash_col, 1.0)
		draw_line(Vector2(w - 1.5, 6 + i), Vector2(w - 1.5, 6 + i + 5), dash_col, 1.0)
	var label := "已取走" if mode == "shop" else "空槽"
	draw_string(_f_reg, Vector2(0, h * 0.5 + 4), label, HORIZONTAL_ALIGNMENT_CENTER, w, 12,
		ThemeKit.MUTED)
