class_name MistUI
extends RefCounted
## 雾屿守望的统一视觉：海雾青底、暖米色字、琥珀强调。字体走系统 CJK 回退，不打包第三方字体。

const BG_DEEP := Color("0b1a1c")
const BG := Color("102628")
const PANEL := Color(0.043, 0.10, 0.105, 0.92)
const PANEL_SOLID := Color("142c2e")
const PANEL_SOFT := Color("1a3537")
const BORDER := Color("355457")
const BORDER_SOFT := Color("244245")
const TEXT := Color("eee7d6")
const DIM := Color("9fb0aa")
const AMBER := Color("e9b45f")
const AMBER_DEEP := Color("b27c3c")
const SEA := Color("72bdb4")
const RED := Color("d96a55")
const GREEN := Color("93c47d")
const BLUE := Color("7fb0cf")
const SPEAR := Color("e0bd74")
const WHITE := Color("f7f3e8")

static var _font: SystemFont
static var _bold_font: SystemFont
static var _title_font: SystemFont


static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray([
			"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
			"Microsoft YaHei", "WenQuanYi Micro Hei", "sans-serif",
		])
	return _font


static func bold_font() -> SystemFont:
	if _bold_font == null:
		_bold_font = SystemFont.new()
		_bold_font.font_names = font().font_names
		_bold_font.font_weight = 700
	return _bold_font


static func title_font() -> SystemFont:
	if _title_font == null:
		_title_font = SystemFont.new()
		_title_font.font_names = font().font_names
		_title_font.font_weight = 800
	return _title_font


static func text_width(text: String, size: int, bold := false) -> float:
	var f: Font = bold_font() if bold else font()
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func draw_text(canvas: CanvasItem, pos: Vector2, text: String, size: int, color: Color, bold := false, shadow := true) -> void:
	var f: Font = bold_font() if bold else font()
	if shadow:
		canvas.draw_string(f, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.5))
	canvas.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func draw_center(canvas: CanvasItem, rect: Rect2, text: String, size: int, color: Color, bold := false, shadow := true) -> void:
	var f: Font = bold_font() if bold else font()
	var baseline := rect.position.y + rect.size.y * 0.5 + size * 0.36
	if shadow:
		canvas.draw_string(f, Vector2(rect.position.x + 1, baseline + 1), text,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, Color(0, 0, 0, 0.5))
	canvas.draw_string(f, Vector2(rect.position.x, baseline), text,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


static func draw_right(canvas: CanvasItem, rect: Rect2, text: String, size: int, color: Color, bold := false) -> void:
	var f: Font = bold_font() if bold else font()
	var baseline := rect.position.y + rect.size.y * 0.5 + size * 0.36
	canvas.draw_string(f, Vector2(rect.position.x, baseline), text,
		HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, size, color)


static func draw_panel(canvas: CanvasItem, rect: Rect2, fill := PANEL, border := BORDER, border_width := 1) -> void:
	canvas.draw_rect(rect, fill, true)
	if border_width > 0:
		canvas.draw_rect(rect, border, false, float(border_width))


static func draw_bracket_panel(canvas: CanvasItem, rect: Rect2, fill := PANEL, border := BORDER) -> void:
	canvas.draw_rect(rect, fill, true)
	var c := border
	var l := 9.0
	canvas.draw_line(rect.position + Vector2(0, 0), rect.position + Vector2(l, 0), c, 1.5)
	canvas.draw_line(rect.position + Vector2(0, 0), rect.position + Vector2(0, l), c, 1.5)
	canvas.draw_line(rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(rect.size.x - l, 0), c, 1.5)
	canvas.draw_line(rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(rect.size.x, l), c, 1.5)
	canvas.draw_line(rect.position + Vector2(0, rect.size.y), rect.position + Vector2(l, rect.size.y), c, 1.5)
	canvas.draw_line(rect.position + Vector2(0, rect.size.y), rect.position + Vector2(0, rect.size.y - l), c, 1.5)
	canvas.draw_line(rect.position + Vector2(rect.size.x, rect.size.y), rect.position + Vector2(rect.size.x - l, rect.size.y), c, 1.5)
	canvas.draw_line(rect.position + Vector2(rect.size.x, rect.size.y), rect.position + Vector2(rect.size.x, rect.size.y - l), c, 1.5)


static func draw_bar(canvas: CanvasItem, rect: Rect2, ratio: float, fill: Color, back := Color(0.02, 0.05, 0.055, 0.9), border := Color(0, 0, 0, 0.35)) -> void:
	canvas.draw_rect(rect, back, true)
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped > 0.0:
		canvas.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(maxf(0.0, (rect.size.x - 2) * clamped), rect.size.y - 2)), fill, true)
	canvas.draw_rect(rect, border, false, 1.0)


static func draw_class_icon(canvas: CanvasItem, center: Vector2, radius: float, class_id: String, color: Color) -> void:
	match class_id:
		"shield":
			canvas.draw_circle(center, radius, Color(0, 0, 0, 0.25))
			canvas.draw_circle(center, radius * 0.86, color)
			canvas.draw_circle(center, radius * 0.66, Color(0.07, 0.15, 0.16, 0.85))
			canvas.draw_circle(center, radius * 0.20, color)
			canvas.draw_line(center + Vector2(0, -radius * 0.55), center + Vector2(0, radius * 0.55), color, 2.0)
			canvas.draw_line(center + Vector2(-radius * 0.45, 0), center + Vector2(radius * 0.45, 0), color, 2.0)
		"archer":
			canvas.draw_arc(center + Vector2(-radius * 0.35, 0), radius * 0.95, -PI * 0.55, PI * 0.55, 16, color, 2.4)
			canvas.draw_line(center + Vector2(-radius * 0.35, -radius * 0.86), center + Vector2(-radius * 0.35, radius * 0.86), color, 1.4)
			canvas.draw_line(center + Vector2(-radius * 0.85, 0), center + Vector2(radius * 0.6, 0), color, 1.8)
			var tip := center + Vector2(radius * 0.6, 0)
			canvas.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-6, -4), tip + Vector2(-6, 4)]), color)
		"spear":
			canvas.draw_line(center + Vector2(-radius * 0.62, radius * 0.66), center + Vector2(radius * 0.36, -radius * 0.42), color, 2.2)
			canvas.draw_line(center + Vector2(-radius * 0.78, radius * 0.80), center + Vector2(-radius * 0.48, radius * 0.50), color, 3.0)
			var tip2 := center + Vector2(radius * 0.36, -radius * 0.42)
			canvas.draw_colored_polygon(PackedVector2Array([tip2 + Vector2(radius * 0.30, -radius * 0.30), tip2 + Vector2(-2, -9), tip2 + Vector2(9, 2)]), color)
		_:
			canvas.draw_circle(center, radius * 0.7, color)


static func class_color(class_id: String) -> Color:
	match class_id:
		"shield": return BLUE
		"archer": return GREEN
		"spear": return SPEAR
		"brute", "chieftain": return RED
		"skirmisher": return Color("c98a62")
		_: return Color("b7a08c")


static func make_button(text: String, rect: Rect2, accent := AMBER, font_size := 16, ghost := false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", bold_font())
	button.add_theme_font_size_override("font_size", font_size)
	if ghost:
		button.add_theme_color_override("font_color", TEXT)
		button.add_theme_color_override("font_hover_color", WHITE)
		button.add_theme_color_override("font_pressed_color", TEXT)
		button.add_theme_stylebox_override("normal", _style(Color("142c2e"), BORDER))
		button.add_theme_stylebox_override("hover", _style(Color("1b3739"), AMBER_DEEP))
		button.add_theme_stylebox_override("pressed", _style(Color("102426"), SEA))
	else:
		button.add_theme_color_override("font_color", BG_DEEP)
		button.add_theme_color_override("font_hover_color", BG_DEEP)
		button.add_theme_color_override("font_pressed_color", BG_DEEP)
		button.add_theme_color_override("font_disabled_color", DIM)
		button.add_theme_stylebox_override("normal", _style(accent, accent.darkened(0.35)))
		button.add_theme_stylebox_override("hover", _style(accent.lightened(0.12), accent.lightened(0.08)))
		button.add_theme_stylebox_override("pressed", _style(accent.darkened(0.12), accent.darkened(0.3)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


static func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func wrap(text: String, size: int, max_width: float, bold := false) -> PackedStringArray:
	var f: Font = bold_font() if bold else font()
	var lines := PackedStringArray()
	var current := ""
	for i in range(text.length()):
		var ch := text.substr(i, 1)
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


static func draw_wrapped(canvas: CanvasItem, pos: Vector2, text: String, size: int, color: Color, max_width: float, line_gap := 5.0) -> void:
	var y := pos.y
	for line in wrap(text, size, max_width):
		draw_text(canvas, Vector2(pos.x, y), line, size, color)
		y += size + line_gap


static func format_time(seconds: float) -> String:
	var total := maxi(0, int(ceil(seconds)))
	return "%02d:%02d" % [total / 60, total % 60]
