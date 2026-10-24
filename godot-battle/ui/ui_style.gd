class_name UiStyle
extends RefCounted

# 统一的 HUD 视觉语言：深紫檀木底、金边、内描边、圆角徽章。
# 供 HUD / 日志 / 对白 / 气泡 / 胜利面板共用，避免各面板风格漂移。

const GOLD := Color(1.0, 0.84, 0.46)
const GOLD_SOFT := Color(0.86, 0.68, 0.36)
const GOLD_DIM := Color(0.62, 0.47, 0.24)
const TEXT := Color(1.0, 0.94, 0.8)
const MUTED := Color(0.72, 0.68, 0.63)
const DANGER := Color(1.0, 0.55, 0.4)
const INK := Color(0.09, 0.06, 0.11)
const PANEL_BG := Color(0.105, 0.068, 0.112, 0.95)
const PANEL_BG_SOFT := Color(0.13, 0.085, 0.145, 0.94)
const PANEL_BG_DEEP := Color(0.07, 0.045, 0.09, 0.97)
const INNER_BORDER := Color(0.98, 0.83, 0.52, 0.24)
const BADGE_FILL := Color(0.93, 0.73, 0.31)
const BADGE_BORDER := Color(1.0, 0.92, 0.66)
const BADGE_INK := Color(0.19, 0.11, 0.05)


static func panel_style(
	radius: int = 12,
	padding: Vector2i = Vector2i(16, 12),
	bg: Color = PANEL_BG,
	border: Color = GOLD_SOFT,
	border_width: int = 2
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style


# 在 PanelContainer 的内容区内再压一圈极细的金色内描边，形成双击边质感。
# 必须作为第一个子节点加入，才能画在内容之后（底层）。
static func attach_inner_border(panel: PanelContainer, radius: int = 9) -> void:
	if panel == null:
		return
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.name = "InnerFrame"
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = INNER_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	frame.add_theme_stylebox_override("panel", style)
	panel.add_child(frame)
	panel.move_child(frame, 0)


static func button_style(bg: Color, border: Color, width: int, radius: int = 9) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func apply_button(button: Button, danger: bool = false, font_size: int = 22) -> Button:
	button.add_theme_font_override("font", FontUtil.cjk_font())
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.92))
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.49, 0.46))
	var border := Color(0.9, 0.5, 0.38) if danger else GOLD_DIM
	button.add_theme_stylebox_override("normal", button_style(Color(0.2, 0.125, 0.19), border, 2))
	button.add_theme_stylebox_override("hover", button_style(Color(0.3, 0.18, 0.25), GOLD, 2))
	button.add_theme_stylebox_override("pressed", button_style(Color(0.4, 0.26, 0.16), GOLD, 2))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.115, 0.09, 0.12, 0.86), Color(0.3, 0.26, 0.24), 1))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


static func make_badge(
	text: String,
	fill: Color = BADGE_FILL,
	border: Color = BADGE_BORDER,
	font_color: Color = BADGE_INK,
	size: int = 24,
	font_size: int = 15
) -> Label:
	var badge := Label.new()
	badge.text = text
	badge.custom_minimum_size = Vector2(size, size)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_override("font", FontUtil.cjk_font())
	badge.add_theme_font_size_override("font_size", font_size)
	badge.add_theme_color_override("font_color", font_color)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(size / 2)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	badge.add_theme_stylebox_override("normal", style)
	return badge


static func command_badge(text: String) -> Label:
	return make_badge(text)


static func status_badge(text: String, color: Color, size: int = 20, font_size: int = 12) -> Label:
	var fill := color.darkened(0.45)
	fill.a = 0.96
	var border := color.lightened(0.4)
	return make_badge(text, fill, border, Color(1.0, 0.97, 0.9), size, font_size)


# 把一字符徽章挂在按钮左侧，按钮文字保持原样（探针仍按 text 查找按钮）。
static func attach_button_badge(button: Button, text: String) -> Label:
	if button == null or text.is_empty():
		return null
	var badge := command_badge(text)
	badge.anchor_left = 0.0
	badge.anchor_right = 0.0
	badge.anchor_top = 0.5
	badge.anchor_bottom = 0.5
	badge.offset_left = 10.0
	badge.offset_right = 34.0
	badge.offset_top = -12.0
	badge.offset_bottom = 12.0
	button.add_child(badge)
	return badge
