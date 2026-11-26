class_name SwarmHeroChip
extends Control

## 顶栏英雄状态：切角甲片 + 阵营徽记 + 血条 + 熄灭火印。

const ThemeKit = preload("res://scripts/swarm_theme.gd")

var hero: Dictionary = {}
var is_active := false
var font: Font = null


func setup(data: Dictionary, active: bool, use_font: Font) -> void:
	hero = data
	is_active = active
	font = use_font
	queue_redraw()


func _draw() -> void:
	if hero.is_empty():
		return
	var w := size.x
	var h := size.y
	var hp := int(hero.get("hp", 0))
	var max_hp := maxi(1, int(hero.get("max_hp", 1)))
	var col: Color = hero.get("color", ThemeKit.CYAN)
	var is_you := bool(hero.get("you", false))
	var dead := hp <= 0
	var pts := PackedVector2Array([
		Vector2(5, 1), Vector2(w - 5, 1), Vector2(w - 1, 5), Vector2(w - 1, h - 5),
		Vector2(w - 5, h - 1), Vector2(5, h - 1), Vector2(1, h - 5), Vector2(1, 5),
	])
	draw_colored_polygon(pts, Color(0.05, 0.09, 0.14, 0.96))
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, col.darkened(0.35) if not dead else ThemeKit.DIM, 1.2, true)
	if is_active:
		draw_polyline(outline, col, 1.6, true)
	# 徽记
	var c := Vector2(22, h * 0.5)
	var hex := ThemeKit.hex_points(c, 13.0, 0.95)
	draw_colored_polygon(hex, Color(col.r, col.g, col.b, 0.18 if not dead else 0.05))
	var hex_out := PackedVector2Array(hex)
	hex_out.append(hex[0])
	draw_polyline(hex_out, col.darkened(0.2) if not dead else ThemeKit.DIM, 1.1, true)
	if font != null:
		var glyph := "巢" if is_you else String(hero.get("short", "?")).substr(0, 1)
		draw_string(font, Vector2(c.x - 10, c.y + 6), glyph, HORIZONTAL_ALIGNMENT_CENTER, 20, 14,
			col if not dead else ThemeKit.DIM)
		var name := String(hero.get("name", ""))
		draw_string(font, Vector2(40, 19), name, HORIZONTAL_ALIGNMENT_LEFT, w - 54, 13,
			ThemeKit.TEXT if not dead else ThemeKit.DIM)
		var hp_text := ("熄灭" if dead else "HP %d/%d" % [hp, max_hp])
		draw_string(font, Vector2(w - 96, 19), hp_text, HORIZONTAL_ALIGNMENT_RIGHT, 86, 11,
			ThemeKit.MUTED if not dead else ThemeKit.DIM)
		if is_active and not dead:
			var cx := w * 0.5
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - 6, 0.5), Vector2(cx + 6, 0.5), Vector2(cx, 7.0)]), ThemeKit.GOLD)
	# 血条
	var bar_x := 40.0
	var bar_w := w - 52.0
	draw_rect(Rect2(bar_x, h - 12, bar_w, 5), Color(0.02, 0.04, 0.06, 0.9), true)
	var frac := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	if frac > 0.0:
		draw_rect(Rect2(bar_x, h - 12, bar_w * frac, 5), col.darkened(0.1), true)
	draw_rect(Rect2(bar_x, h - 12, bar_w, 5), Color(col.r, col.g, col.b, 0.5), false, 1.0)
	if dead:
		draw_rect(Rect2(1, 1, w - 2, h - 2), Color(0.02, 0.03, 0.05, 0.62), true)
