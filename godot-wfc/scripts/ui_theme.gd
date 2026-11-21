extends RefCounted

# 统一的 UI 主题：月下庭院配色 + 系统 CJK 字体 + 自绘控件样式。
# 不做任何贴图/字体文件分发；字体通过 SystemFont 使用系统回退。

const BG_DEEP := Color("#0e1711")
const PANEL := Color("#18251b")
const PANEL_SOFT := Color("#1d2c20")
const PANEL_EDGE := Color("#3d533e")
const TEXT := Color("#efe7d2")
const MUTED := Color("#91a189")
const MINT := Color("#a9d6a8")
const AMBER := Color("#efbf73")
const CORAL := Color("#e88870")
const INK := Color("#152016")


static func make_theme(scale: float) -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "STHeiti",
		"Noto Sans CJK SC", "Source Han Sans SC", "Sans-Serif"])
	font.allow_system_fallback = true
	theme.default_font = font
	theme.default_font_size = int(round(14.0 * scale))

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", MINT)
	theme.set_color("font_pressed_color", "Button", AMBER)
	theme.set_color("font_focus_color", "Button", MINT)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_hover_color", "CheckBox", MINT)
	theme.set_color("font_pressed_color", "CheckBox", MINT)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", AMBER)
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", MINT)

	var button_normal := _box(PANEL_SOFT, PANEL_EDGE, 1, 5, scale, 11, 6)
	var button_hover := _box(Color("#263a2b"), Color(0.62, 0.82, 0.58, 0.7), 1, 5, scale, 11, 6)
	var button_pressed := _box(Color("#315037"), MINT, 1, 5, scale, 11, 6)
	var button_disabled := _box(Color(0.11, 0.16, 0.12, 0.7), Color(0.3, 0.38, 0.3, 0.5),
			1, 5, scale, 11, 6)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color(0.86, 0.73, 0.44, 0.65)
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

	var edit_normal := _box(Color("#111b14"), Color(0.32, 0.43, 0.31, 0.9), 1, 4,
			scale, 9, 4)
	var edit_focus := _box(Color("#131f17"), Color(0.63, 0.82, 0.59, 0.8), 1, 4,
			scale, 9, 4)
	theme.set_stylebox("normal", "LineEdit", edit_normal)
	theme.set_stylebox("focus", "LineEdit", edit_focus)
	theme.set_stylebox("read_only", "LineEdit", edit_normal)

	var popup := StyleBoxFlat.new()
	popup.bg_color = Color("#152118")
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
	slider_bg.bg_color = Color("#0f1811")
	slider_bg.set_corner_radius_all(int(round(3.0 * scale)))
	slider_bg.content_margin_top = 3.0 * scale
	slider_bg.content_margin_bottom = 3.0 * scale
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = Color(0.48, 0.67, 0.46, 0.9)
	slider_fill.set_corner_radius_all(int(round(3.0 * scale)))
	slider_fill.content_margin_top = 3.0 * scale
	slider_fill.content_margin_bottom = 3.0 * scale
	var slider_fill_hi := slider_fill.duplicate()
	slider_fill_hi.bg_color = Color(0.69, 0.83, 0.59, 0.95)
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill_hi)

	var progress_bg := StyleBoxFlat.new()
	progress_bg.bg_color = Color("#101a13")
	progress_bg.set_corner_radius_all(int(round(3.0 * scale)))
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color(0.50, 0.70, 0.47, 0.9)
	progress_fill.set_corner_radius_all(int(round(3.0 * scale)))
	theme.set_stylebox("background", "ProgressBar", progress_bg)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)
	theme.set_color("font_color", "ProgressBar", TEXT)
	return theme


static func panel_style(fill: Color = PANEL, border: Color = PANEL_EDGE,
		scale: float = 1.0, radius: float = 8.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(maxi(1, int(round(scale))))
	style.set_corner_radius_all(int(round(radius * scale)))
	style.content_margin_left = 16.0 * scale
	style.content_margin_right = 16.0 * scale
	style.content_margin_top = 14.0 * scale
	style.content_margin_bottom = 14.0 * scale
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = int(round(7.0 * scale))
	style.shadow_offset = Vector2(0, 3.0 * scale)
	return style


static func map_panel_style(scale: float) -> StyleBoxFlat:
	var style := _box(Color("#111c15"), Color(0.30, 0.42, 0.29, 0.8), 1, 9,
			scale, 12, 12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style.shadow_size = int(round(8.0 * scale))
	style.shadow_offset = Vector2(0, 4.0 * scale)
	return style


static func footer_style(scale: float) -> StyleBoxFlat:
	return _box(Color(0.050, 0.085, 0.060, 0.80), Color(0.26, 0.36, 0.25, 0.7),
			1, 5, scale, 12, 4)


static func style_primary(button: Button, scale: float) -> void:
	var normal := _box(Color("#d8b06f"), Color("#f0d295"), 1, 5, scale, 11, 6)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	normal.shadow_size = int(round(3.0 * scale))
	var hover := _box(Color("#e8c485"), Color("#f5e0b2"), 1, 5, scale, 11, 6)
	var pressed := _box(Color("#b88e51"), Color("#f0d295"), 1, 5, scale, 11, 6)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_focus_color", INK)


static func make_label(text: String, size: float, color: Color = TEXT,
		scale: float = 1.0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(round(size * scale)))
	label.add_theme_color_override("font_color", color)
	return label


static func divider(scale: float, color: Color = Color(0.39, 0.51, 0.37, 0.32)) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0.0, maxf(1.0, 1.0 * scale))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func _box(fill: Color, border: Color, border_width: int, radius: int,
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
