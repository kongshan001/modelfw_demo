extends RefCounted
## 原创视觉基元：苔绿/石青/琥珀色板、系统 CJK 字体、面板/血条/图标绘制。
## 无外部贴图；所有图形由 GDScript 运行时绘制。

const BG := Color("0b1511")
const GRASS_DARK := Color("1a2d24")
const GRASS := Color("284437")
const GRASS_LIGHT := Color("355845")
const MOSS := Color("3f634a")
const SOIL := Color("2c271c")
const PATH := Color("b7a070")
const PATH_DARK := Color("6d5a3f")
const PATH_LIGHT := Color("d2bd8e")
const STONE := Color("59655c")
const STONE_DARK := Color("394740")
const STONE_LIGHT := Color("7c897d")
const CREAM := Color("f3e6c8")
const GOLD := Color("e8b45d")
const GOLD_DIM := Color("9a7339")
const AMBER := Color("d18b45")
const TEAL := Color("57b7a2")
const TEAL_DARK := Color("2f6f64")
const INK := Color("0d1612")
const PANEL := Color(0.055, 0.098, 0.078, 0.95)
const PANEL_2 := Color(0.078, 0.14, 0.11, 0.97)
const BORDER := Color("40594b")
const BORDER_SOFT := Color("26382e")
const TEXT := Color("eadfc7")
const DIM := Color("9aa78f")
const RED := Color("cf5d4c")
const RUST := Color("b8553f")
const GREEN := Color("74c58b")
const WHITE := Color("fff6e2")
const SHADOW := Color(0, 0, 0, 0.35)

static var _font: SystemFont
static var _bold: SystemFont
static var _title: SystemFont


static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray([
			"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
			"Microsoft YaHei", "WenQuanYi Micro Hei", "sans-serif",
		])
	return _font


static func bold_font() -> SystemFont:
	if _bold == null:
		_bold = SystemFont.new()
		_bold.font_names = font().font_names
		_bold.font_weight = 700
	return _bold


static func title_font() -> SystemFont:
	if _title == null:
		_title = SystemFont.new()
		_title.font_names = PackedStringArray([
			"Kaiti SC", "STKaiti", "KaiTi", "Songti SC", "PingFang SC", "sans-serif",
		])
		_title.font_weight = 700
	return _title


static func text_width(value: String, size: int, bold := false) -> float:
	var f: Font = bold_font() if bold else font()
	return f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func text(canvas: CanvasItem, pos: Vector2, value: String, size: int, color: Color, bold := false, shadow := true) -> void:
	var f: Font = bold_font() if bold else font()
	if shadow:
		canvas.draw_string(f, pos + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.55))
	canvas.draw_string(f, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_center(canvas: CanvasItem, rect: Rect2, value: String, size: int, color: Color, bold := false) -> void:
	var f: Font = bold_font() if bold else font()
	var baseline := rect.position.y + rect.size.y * 0.5 + size * 0.35
	canvas.draw_string(f, Vector2(rect.position.x + 1, baseline + 1), value,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, Color(0, 0, 0, 0.55))
	canvas.draw_string(f, Vector2(rect.position.x, baseline), value,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


static func text_right(canvas: CanvasItem, rect: Rect2, value: String, size: int, color: Color, bold := false) -> void:
	var f: Font = bold_font() if bold else font()
	var baseline := rect.position.y + rect.size.y * 0.5 + size * 0.35
	canvas.draw_string(f, Vector2(rect.position.x + 1, baseline + 1), value,
		HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, size, Color(0, 0, 0, 0.55))
	canvas.draw_string(f, Vector2(rect.position.x, baseline), value,
		HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, size, color)


static func panel(canvas: CanvasItem, rect: Rect2, fill := PANEL, border := BORDER, accent := true) -> void:
	canvas.draw_rect(rect, fill, true)
	canvas.draw_rect(rect, border, false, 1.0)
	if accent:
		var c := 13.0
		canvas.draw_line(rect.position + Vector2(0, 4), rect.position + Vector2(0, 4 + c), GOLD_DIM, 2.0)
		canvas.draw_line(rect.position + Vector2(4, 0), rect.position + Vector2(4 + c, 0), GOLD_DIM, 2.0)
		canvas.draw_line(rect.end - Vector2(0, 4), rect.end - Vector2(0, 4 + c), GOLD_DIM, 2.0)
		canvas.draw_line(rect.end - Vector2(4, 0), rect.end - Vector2(4 + c, 0), GOLD_DIM, 2.0)


static func bar(canvas: CanvasItem, rect: Rect2, ratio: float, fill: Color, back := Color(0.02, 0.04, 0.03, 0.9)) -> void:
	canvas.draw_rect(rect, back, true)
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped > 0.0:
		var inner := Rect2(rect.position + Vector2(1, 1), Vector2((rect.size.x - 2) * clamped, rect.size.y - 2))
		canvas.draw_rect(inner, fill, true)
	canvas.draw_rect(rect, Color(0, 0, 0, 0.5), false, 1.0)


static func coin(canvas: CanvasItem, center: Vector2, radius: float, fill := GOLD) -> void:
	canvas.draw_circle(center + Vector2(0, 1), radius + 1.0, Color(0, 0, 0, 0.35))
	canvas.draw_circle(center, radius, fill)
	canvas.draw_circle(center, radius * 0.62, fill.darkened(0.18))
	canvas.draw_line(center + Vector2(-radius * 0.28, 0), center + Vector2(radius * 0.28, 0), fill.lightened(0.35), 1.5)


static func diamond(canvas: CanvasItem, center: Vector2, radius: float, fill: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.7, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.7, 0),
	])
	canvas.draw_colored_polygon(pts, fill)


static func dashed_circle(canvas: CanvasItem, center: Vector2, radius: float, color: Color, width := 1.5, segments := 28) -> void:
	var step := TAU / float(segments)
	for i in range(segments):
		if i % 2 == 1:
			continue
		var a0 := step * float(i)
		canvas.draw_arc(center, radius, a0, a0 + step * 0.72, 6, color, width, true)


static func shadow(canvas: CanvasItem, center: Vector2, radius_x: float, radius_y: float, alpha := 0.32) -> void:
	canvas.draw_set_transform(center, 0.0, Vector2(1.0, maxf(0.12, radius_y / maxf(1.0, radius_x))))
	canvas.draw_circle(Vector2.ZERO, radius_x, Color(0, 0, 0, alpha))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func wrap_text(text_value: String, size: int, max_width: float, bold := false) -> PackedStringArray:
	var f: Font = bold_font() if bold else font()
	var lines := PackedStringArray()
	var current := ""
	for i in range(text_value.length()):
		var ch := text_value.substr(i, 1)
		if ch == "\n":
			lines.append(current)
			current = ""
			continue
		var probe := current + ch
		if f.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width and current != "":
			lines.append(current)
			current = ch
		else:
			current = probe
	if current != "":
		lines.append(current)
	return lines


static func wrapped(canvas: CanvasItem, pos: Vector2, value: String, size: int, color: Color, max_width: float, line_gap := 4.0) -> void:
	var y := pos.y
	for line in wrap_text(value, size, max_width):
		text(canvas, Vector2(pos.x, y), line, size, color)
		y += float(size) + line_gap
