extends RefCounted

# 统一 UI 主题：制图台的墨绿/羊皮纸/黄铜配色。
# 字体通过 SystemFont 使用系统 CJK 回退，不随工程分发字体文件。

const BG_DEEP := Color("#0b1416")
const BG_SOFT := Color("#0f1c1e")
const PANEL := Color("#152427")
const PANEL_SOFT := Color("#1b2e30")
const PANEL_EDGE := Color("#3d5552")
const TEXT := Color("#efe7d2")
const MUTED := Color("#93a69d")
const MINT := Color("#9fd6bd")
const TEAL := Color("#64b0a3")
const AMBER := Color("#e4b96f")
const CORAL := Color("#e39079")
const INK := Color("#122022")

const FONT_NAMES := [
	"PingFang SC", "Hiragino Sans GB", "STHeiti",
	"Noto Sans CJK SC", "Source Han Sans SC", "Sans-Serif"]


static func make_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)
	font.allow_system_fallback = true
	return font


static func make_theme(scale: float) -> Theme:
	var theme := Theme.new()
	theme.default_font = make_font()
	theme.default_font_size = int(round(14.0 * scale))

	for color_name in ["font_color"]:
		theme.set_color(color_name, "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", MINT)
	theme.set_color("font_pressed_color", "Button", AMBER)
	theme.set_color("font_focus_color", "Button", MINT)
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.55, 0.52, 0.65))
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_hover_color", "CheckBox", MINT)
	theme.set_color("font_pressed_color", "CheckBox", MINT)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", AMBER)
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", MINT)
	theme.set_color("font_pressed_color", "OptionButton", AMBER)

	var button_normal := _box(PANEL_SOFT, PANEL_EDGE, 1, 5, scale, 10, 5)
	var button_hover := _box(Color("#243a3b"), Color(0.65, 0.84, 0.74, 0.75), 1, 5,
			scale, 10, 5)
	var button_pressed := _box(Color("#2d4a44"), MINT, 1, 5, scale, 10, 5)
	var button_disabled := _box(Color(0.09, 0.14, 0.15, 0.7), Color(0.3, 0.4, 0.38, 0.45),
			1, 5, scale, 10, 5)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color(0.88, 0.76, 0.48, 0.7)
	focus.set_border_width_all(maxi(1, int(round(scale))))
	focus.set_corner_radius_all(int(round(5.0 * scale)))
	focus.set_expand_margin_all(1.0 * scale)
	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("disabled", "Button", button_disabled)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("normal", "OptionButton", button_normal)
	theme.set_stylebox("hover", "OptionButton", button_hover)
	theme.set_stylebox("pressed", "OptionButton", button_pressed)
	theme.set_stylebox("focus", "OptionButton", focus)
	theme.set_stylebox("disabled", "OptionButton", button_disabled)

	var edit_normal := _box(Color("#0d181a"), Color(0.34, 0.47, 0.45, 0.9), 1, 4,
			scale, 8, 4)
	var edit_focus := _box(Color("#102022"), Color(0.65, 0.85, 0.75, 0.85), 1, 4,
			scale, 8, 4)
	theme.set_stylebox("normal", "LineEdit", edit_normal)
	theme.set_stylebox("focus", "LineEdit", edit_focus)
	theme.set_stylebox("read_only", "LineEdit", edit_normal)

	var popup := StyleBoxFlat.new()
	popup.bg_color = Color("#112022")
	popup.border_color = PANEL_EDGE
	popup.set_border_width_all(maxi(1, int(round(scale))))
	popup.set_corner_radius_all(int(round(4.0 * scale)))
	popup.content_margin_left = 7.0 * scale
	popup.content_margin_right = 7.0 * scale
	popup.content_margin_top = 5.0 * scale
	popup.content_margin_bottom = 5.0 * scale
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", MINT)

	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color("#0b1517")
	slider_bg.set_corner_radius_all(int(round(3.0 * scale)))
	slider_bg.content_margin_top = 3.0 * scale
	slider_bg.content_margin_bottom = 3.0 * scale
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = Color(0.43, 0.68, 0.59, 0.9)
	slider_fill.set_corner_radius_all(int(round(3.0 * scale)))
	slider_fill.content_margin_top = 3.0 * scale
	slider_fill.content_margin_bottom = 3.0 * scale
	var slider_fill_hi := slider_fill.duplicate()
	slider_fill_hi.bg_color = Color(0.68, 0.85, 0.72, 0.95)
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill_hi)

	var progress_bg := StyleBoxFlat.new()
	progress_bg.bg_color = Color("#0b1517")
	progress_bg.set_corner_radius_all(int(round(3.0 * scale)))
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color(0.48, 0.72, 0.61, 0.9)
	progress_fill.set_corner_radius_all(int(round(3.0 * scale)))
	theme.set_stylebox("background", "ProgressBar", progress_bg)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)
	theme.set_color("font_color", "ProgressBar", TEXT)
	return theme


static func make_label(text: String, font_size: float, color: Color, scale: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(round(font_size * scale)))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func panel_style(fill: Color = PANEL, border: Color = PANEL_EDGE,
		scale: float = 1.0, radius: float = 8.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(maxi(1, int(round(scale))))
	style.set_corner_radius_all(int(round(radius * scale)))
	style.content_margin_left = 14.0 * scale
	style.content_margin_right = 14.0 * scale
	style.content_margin_top = 12.0 * scale
	style.content_margin_bottom = 12.0 * scale
	return style


static func map_panel_style(scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0a1416")
	style.border_color = Color("#4d645f")
	style.set_border_width_all(maxi(1, int(round(1.0 * scale))))
	style.set_corner_radius_all(int(round(6.0 * scale)))
	style.content_margin_left = 2.0 * scale
	style.content_margin_right = 2.0 * scale
	style.content_margin_top = 2.0 * scale
	style.content_margin_bottom = 2.0 * scale
	return style


static func style_primary(button: Button, scale: float) -> void:
	var normal := _box(Color("#3c6153"), Color("#8fcdb2"), 1, 5, scale, 10, 5)
	var hover := _box(Color("#4a7664"), Color("#b6e6ca"), 1, 5, scale, 10, 5)
	var pressed := _box(Color("#2c4b41"), Color("#e4b96f"), 1, 5, scale, 10, 5)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("#f4f0df"))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))


static func style_segmented(button: Button, scale: float) -> void:
	var normal := _box(Color("#122225"), Color("#334b48"), 1, 5, scale, 10, 5)
	var hover := _box(Color("#1d3536"), Color("#6e9a8c"), 1, 5, scale, 10, 5)
	var pressed := _box(Color("#31574e"), Color("#9fd6bd"), 1, 5, scale, 10, 5)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func divider(scale: float, color := Color(0.35, 0.47, 0.44, 0.55)) -> Control:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0.0, maxf(1.0, scale))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func _box(fill: Color, border: Color, border_width: int, radius: float,
		scale: float, pad_x: float, pad_y: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(maxi(1, int(round(border_width * scale))))
	style.set_corner_radius_all(int(round(radius * scale)))
	style.content_margin_left = pad_x * scale
	style.content_margin_right = pad_x * scale
	style.content_margin_top = pad_y * scale
	style.content_margin_bottom = pad_y * scale
	return style
