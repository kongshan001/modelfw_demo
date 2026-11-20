class_name AtelierTheme
extends RefCounted

# 纸偶工坊的统一视觉：奶油纸面、墨色描边、珊瑚/青绿/芥末三色强调。

const INK := Color("#3a2f43")
const CREAM := Color("#fff9ee")
const PAPER := Color("#f3e7d4")
const SOFT := Color("#f7efe2")
const CORAL := Color("#e86a5c")
const TEAL := Color("#3f9c8a")
const GOLD := Color("#f2b34c")
const PLUM := Color("#8a6fb0")
const MUTED := Color("#837586")
const WHITE := Color("#fffdf7")

static var _font: SystemFont = null


static func font() -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray([
			"PingFang SC", "Hiragino Sans GB", "Heiti SC",
			"Arial Unicode MS", "Noto Sans CJK SC", "Arial",
		])
		_font.allow_system_fallback = true
	return _font


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font()
	theme.default_font_size = 12
	return theme


static func panel_style(radius := 16, shadow := true, bg := CREAM) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(2)
	box.border_color = Color(INK, 0.82)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	if shadow:
		box.shadow_color = Color(INK, 0.16)
		box.shadow_size = 4
		box.shadow_offset = Vector2(0, 3)
	return box


static func inner_style(radius := 10, bg := SOFT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(1)
	box.border_color = Color(INK, 0.14)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


static func card_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = CREAM if not selected else Color("#fff3df")
	box.set_border_width_all(3 if selected else 1)
	box.border_color = CORAL if selected else Color(INK, 0.22)
	box.set_corner_radius_all(12)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	box.shadow_color = Color(INK, 0.10 if not selected else 0.18)
	box.shadow_size = 2 if not selected else 4
	box.shadow_offset = Vector2(0, 2)
	return box


static func accent_style(bg: Color, radius := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(1)
	box.border_color = Color(INK, 0.30)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


static func style_button(button: Button, size := 11) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", font())
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", WHITE)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_stylebox_override("normal", accent_style(SOFT))
	button.add_theme_stylebox_override("hover", accent_style(Color("#ffe6c9")))
	button.add_theme_stylebox_override("pressed", accent_style(Color("#f0c8a2")))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func style_toggle(button: Button, active: bool, active_bg := CORAL, size := 11) -> void:
	style_button(button, size)
	var normal := accent_style(active_bg if active else SOFT)
	var hover := accent_style((active_bg if active else SOFT).lightened(0.10))
	var pressed := accent_style((active_bg if active else SOFT).darkened(0.08))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", WHITE if active else INK)
	button.add_theme_color_override("font_hover_color", WHITE if active else INK)


static func make_label(text: String, size := 12, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func contrast_text(bg: Color) -> Color:
	var luma := bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114
	return INK if luma > 0.62 else WHITE
