class_name SwarmCardButton
extends Button

## 原创卡牌绘制：切角卡片、阶色条、六角徽记、编队数量、金卡描边。
## 一个按钮同时用于商店与上场槽。

const Cards = preload("res://scripts/swarm_cards.gd")
const ThemeKit = preload("res://scripts/swarm_theme.gd")

var card_id := ""
var star := 1
var squad_units := 0
var price := 0
var sell_price := 0
var mode := "shop" # shop / board
var selected := false
var affordable := true
var empty := true
var slot_index := 0


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
	var lines := [
		String(card.get("name", "")) + "  T" + str(int(card.get("tier", 1))) + "  " + Cards.role_label(card),
		"每单位 HP %d / ATK %d / 攻速 %.2f / 射程 %d" % [
			int(card["hp"]), int(card["atk"]), float(card["aspd"]), int(card["range"])],
		"编队 ×%s 单位 · 价格 %d◆" % [Cards.format_units(units), price],
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
	var lines := [
		String(card.get("name", "")) + "  " + ("★★ 金卡" if star >= 2 else "★"),
		"编队 ×%s 单位" % Cards.format_units(units),
		"每单位 HP %d / ATK %d / 攻速 %.2f / 射程 %d" % [
			int(card["hp"]) * (2 if star >= 2 else 1),
			int(card["atk"]) * (2 if star >= 2 else 1),
			float(card["aspd"]), int(card["range"])],
		String(card.get("desc", "")),
		"左键选中，右键直接出售（返还 %d◆）" % sell_price,
	]
	tooltip_text = "\n".join(lines)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var f := get_theme_font("font")
	if f == null:
		f = ThemeDB.fallback_font
	if empty:
		draw_rect(Rect2(1, 1, w - 2, h - 2), Color(0.03, 0.06, 0.09, 0.55), true)
		draw_rect(Rect2(1.5, 1.5, w - 3, h - 3), Color(0.13, 0.23, 0.31, 0.8), false, 1.0)
		var empty_text := "已取走" if mode == "shop" else "空槽"
		draw_string(f, Vector2(0, h * 0.5 + 4), empty_text, HORIZONTAL_ALIGNMENT_CENTER, w, 11, ThemeKit.DIM)
		return
	var card := Cards.get_card(card_id)
	if card.is_empty():
		return
	var tier := clampi(int(card.get("tier", 1)), 1, 5)
	var tier_col: Color = Cards.TIER_COLORS[tier]
	var pad := 8.0
	var is_shop := mode == "shop"
	draw_rect(Rect2(1.5, 1.5, w - 3, 3), tier_col, true)
	# 左上角切角装饰
	draw_line(Vector2(1, 12), Vector2(1, 1), tier_col, 1.0)
	draw_line(Vector2(1, 1), Vector2(12, 1), tier_col, 1.0)
	if star >= 2:
		draw_rect(Rect2(1.5, 1.5, w - 3, h - 3), ThemeKit.GOLD, false, 1.0)
	if selected:
		draw_rect(Rect2(0.5, 0.5, w - 1, h - 1), ThemeKit.CYAN, false, 2.0)
	# 六角徽记
	var sigil_r := 13.0 if is_shop else 10.0
	var sigil_c := Vector2(pad + sigil_r, (31.0 if is_shop else 24.0))
	var pts := ThemeKit.hex_points(sigil_c, sigil_r)
	draw_colored_polygon(pts, Color(tier_col.r, tier_col.g, tier_col.b, 0.20))
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, tier_col, 1.2, true)
	var sigil := String(card.get("name", "?")).substr(0, 1)
	draw_string(f, Vector2(sigil_c.x - sigil_r, sigil_c.y + sigil_r * 0.36), sigil,
		HORIZONTAL_ALIGNMENT_CENTER, sigil_r * 2.0, 12 if is_shop else 10, tier_col.lightened(0.25))
	# 名称与星级
	var name_x := pad + sigil_r * 2.0 + 6.0
	var name_y := 21.0 if is_shop else 18.0
	draw_string(f, Vector2(name_x, name_y), String(card.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT,
		w - name_x - 32.0, 14 if is_shop else 11, ThemeKit.TEXT)
	var star_text := "★★" if star >= 2 else "★"
	draw_string(f, Vector2(name_x, name_y + 13.0), star_text, HORIZONTAL_ALIGNMENT_LEFT,
		40, 10, ThemeKit.GOLD if star >= 2 else ThemeKit.DIM)
	# 价格/出售
	if is_shop:
		var cost_text := "◆%d" % price
		draw_string(f, Vector2(w - 52, 20), cost_text, HORIZONTAL_ALIGNMENT_RIGHT, 44,
			13, ThemeKit.GOLD if affordable else ThemeKit.RED)
	else:
		draw_string(f, Vector2(w - 48, h - 8), "售%d" % sell_price, HORIZONTAL_ALIGNMENT_RIGHT, 40,
			9, ThemeKit.GOLD_DIM)
	# 编队数量
	var count_text := "编队 ×%s" % Cards.format_units(squad_units)
	var count_col := ThemeKit.CYAN if not (is_shop and not affordable) else ThemeKit.CYAN_DIM
	if is_shop:
		draw_string(f, Vector2(pad, 53), count_text, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, 12, count_col)
		var stat_text := "HP %d · ATK %d · %.2f/s · R%d" % [
			int(card["hp"]), int(card["atk"]), float(card["aspd"]), int(card["range"])]
		draw_string(f, Vector2(pad, 67), stat_text, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, 9.5, ThemeKit.MUTED)
		draw_string(f, Vector2(pad, 79), Cards.role_label(card) + " · " + String(Cards.TIER_NAMES[tier]) + "阶",
			HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, 8.5, ThemeKit.DIM)
	else:
		draw_string(f, Vector2(pad, 48), "×%s" % Cards.format_units(squad_units), HORIZONTAL_ALIGNMENT_LEFT,
			w - pad * 2.0, 11, count_col)
		var stat_text := "%s · HP%d ATK%d" % [Cards.role_label(card),
			int(card["hp"]) * (2 if star >= 2 else 1), int(card["atk"]) * (2 if star >= 2 else 1)]
		draw_string(f, Vector2(pad, 62), stat_text, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, 8.5, ThemeKit.MUTED)
	if is_shop and not affordable:
		draw_rect(Rect2(1.5, 5, w - 3, h - 6), Color(0.02, 0.04, 0.07, 0.52), true)
		draw_string(f, Vector2(0, h - 8), "金币不足", HORIZONTAL_ALIGNMENT_CENTER, w, 10, ThemeKit.RED)
