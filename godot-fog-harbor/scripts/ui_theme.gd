class_name FogUITheme
extends RefCounted
## 雾港余烬统一视觉：深青底、琥珀强调、细描边、系统 CJK 字体。
## 所有面板/按钮/文本都是原创样式。

const BG := Color("071116")
const BG_DEEP := Color("040a0e")
const PANEL := Color(0.043, 0.098, 0.12, 0.94)
const PANEL_SOLID := Color("0c1c22")
const PANEL_LIGHT := Color("12272e")
const BORDER := Color("2b4c53")
const BORDER_SOFT := Color("1b3238")
const TEXT := Color("d8e6e4")
const DIM := Color("8aa3a7")
const AMBER := Color("e9b35c")
const AMBER_DIM := Color("8a6a3a")
const TEAL := Color("5bcbb8")
const RED := Color("df655b")
const GREEN := Color("78d39a")
const BLUE := Color("7bb6d6")
const WHITE := Color("f2f6f4")


static func text_size(text: String, size: int, bold := false) -> Vector2:
	var f: Font = FogArt.bold_font() if bold else FogArt.font()
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)


static func draw_text(canvas: CanvasItem, pos: Vector2, text: String, size: int, color: Color, bold := false, shadow := true) -> void:
	var f: Font = FogArt.bold_font() if bold else FogArt.font()
	if shadow:
		canvas.draw_string(f, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.55))
	canvas.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func draw_text_center(canvas: CanvasItem, rect: Rect2, text: String, size: int, color: Color, bold := false) -> void:
	var f: Font = FogArt.bold_font() if bold else FogArt.font()
	var baseline := rect.position.y + rect.size.y * 0.5 + size * 0.36
	canvas.draw_string(f, Vector2(rect.position.x + 1, baseline + 1), text,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, Color(0, 0, 0, 0.55))
	canvas.draw_string(f, Vector2(rect.position.x, baseline), text,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


static func draw_text_right(canvas: CanvasItem, rect: Rect2, text: String, size: int, color: Color, bold := false) -> void:
	var f: Font = FogArt.bold_font() if bold else FogArt.font()
	var baseline := rect.position.y + rect.size.y * 0.5 + size * 0.36
	canvas.draw_string(f, Vector2(rect.position.x, baseline), text,
		HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, size, color)


static func draw_panel(canvas: CanvasItem, rect: Rect2, fill := PANEL, border := BORDER, border_width := 1) -> void:
	canvas.draw_rect(rect, fill, true)
	if border_width > 0:
		canvas.draw_rect(rect, border, false, float(border_width))


static func draw_bar(canvas: CanvasItem, rect: Rect2, ratio: float, fill: Color, back := Color(0.02, 0.05, 0.06, 0.9)) -> void:
	canvas.draw_rect(rect, back, true)
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped > 0.0:
		var inner := Rect2(rect.position + Vector2(1, 1), Vector2((rect.size.x - 2) * clamped, rect.size.y - 2))
		canvas.draw_rect(inner, fill, true)
	canvas.draw_rect(rect, Color(0, 0, 0, 0.45), false, 1.0)


static func wrap_text(text: String, size: int, max_width: float, bold := false) -> PackedStringArray:
	var f: Font = FogArt.bold_font() if bold else FogArt.font()
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


static func draw_wrapped(canvas: CanvasItem, pos: Vector2, text: String, size: int, color: Color, max_width: float, line_gap := 4.0) -> void:
	var lines := wrap_text(text, size, max_width)
	var y := pos.y
	for line in lines:
		draw_text(canvas, Vector2(pos.x, y), line, size, color)
		y += size + line_gap


static func make_button(text: String, rect: Rect2, accent := AMBER, font_size := 16) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FogArt.bold_font())
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", BG_DEEP)
	button.add_theme_color_override("font_hover_color", BG_DEEP)
	button.add_theme_color_override("font_pressed_color", BG_DEEP)
	button.add_theme_color_override("font_disabled_color", DIM)
	button.add_theme_stylebox_override("normal", _button_style(accent, 1))
	button.add_theme_stylebox_override("hover", _button_style(accent.lightened(0.14), 1))
	button.add_theme_stylebox_override("pressed", _button_style(accent.darkened(0.12), 1))
	button.add_theme_stylebox_override("disabled", _button_style(Color("25363a"), 0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


static func make_ghost_button(text: String, rect: Rect2, font_size := 14) -> Button:
	var button := make_button(text, rect, Color("20363d"), font_size)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_stylebox_override("normal", _ghost_style(Color("14282e"), BORDER))
	button.add_theme_stylebox_override("hover", _ghost_style(Color("1b353c"), AMBER_DIM))
	button.add_theme_stylebox_override("pressed", _ghost_style(Color("102227"), TEAL))
	return button


static func _button_style(color: Color, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(0.35)
	style.set_border_width_all(1 if border_alpha > 0.0 else 0)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func _ghost_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


static func format_time(seconds: float) -> String:
	var total := maxi(0, int(ceil(seconds)))
	return "%02d:%02d" % [total / 60, total % 60]
