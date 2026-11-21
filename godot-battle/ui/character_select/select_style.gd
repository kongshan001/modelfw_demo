class_name SelectStyle
extends RefCounted

# 主角选择界面的视觉语言：比战斗 HUD 更通透的檀木底、金边、角色主色点缀。
# 复用 FontUtil 与 UiStyle 的字体/面板基础，但独立控制字号与留白。

const GOLD := Color(1.0, 0.84, 0.46)
const GOLD_SOFT := Color(0.86, 0.68, 0.36)
const GOLD_DIM := Color(0.45, 0.35, 0.2)
const TEXT := Color(1.0, 0.95, 0.84)
const MUTED := Color(0.7, 0.67, 0.62)
const INK := Color(0.055, 0.04, 0.075)
const PANEL := Color(0.068, 0.046, 0.084, 0.93)
const PANEL_SOFT := Color(0.11, 0.075, 0.125, 0.82)
const HINT := Color(0.62, 0.58, 0.54)
const DANGER := Color(1.0, 0.55, 0.4)

static func font() -> Font:
	return FontUtil.cjk_font()

static func label(text: String, size: int, color: Color = TEXT) -> Label:
	var out := Label.new()
	out.text = text
	out.add_theme_font_override("font", font())
	out.add_theme_font_size_override("font_size", size)
	out.add_theme_color_override("font_color", color)
	out.add_theme_color_override("font_outline_color", Color(0.02, 0.014, 0.03, 0.85))
	out.add_theme_constant_override("outline_size", 5)
	out.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	out.add_theme_constant_override("shadow_offset_x", 0)
	out.add_theme_constant_override("shadow_offset_y", 2)
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return out

static func panel_style(accent: Color = GOLD_SOFT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = GOLD_SOFT
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 24
	style.shadow_offset = Vector2(0, 8)
	return style

static func tag(text: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.13)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", style)
	var line := label(text, 18, Color(1.0, 0.95, 0.86))
	chip.add_child(line)
	return chip

static func divider(color: Color = Color(1.0, 0.84, 0.46, 0.28)) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

static func big_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", font())
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.94))
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
	button.add_theme_constant_override("outline_size", 4)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.14, 0.12)
	normal.border_color = GOLD_SOFT
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.content_margin_top = 16
	normal.content_margin_bottom = 16
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.32, 0.2, 0.14)
	hover.border_color = GOLD
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.14, 0.09, 0.1)
	pressed.border_color = accent
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button

static func stat_bar(accent: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1.0, 0.95, 0.82, 0.1)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar
