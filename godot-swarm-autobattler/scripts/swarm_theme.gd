class_name SwarmTheme
extends RefCounted

## 原创 UI 主题：冷铸巢 + 青蓝/赤锈双阵营，几何切角、细线边框。
## 不使用任何外部字体/贴图；字体走系统中文字体，颜色与样式全部代码生成。

const BG := Color("#050a12")
const BG_DEEP := Color("#03070d")
const PANEL := Color("#0a1420")
const PANEL2 := Color("#0d1b2a")
const PANEL3 := Color("#112336")
const PANEL_HI := Color("#163247")
const LINE := Color("#1d374b")
const LINE_HI := Color("#3f7288")
const CYAN := Color("#37e0c7")
const CYAN_SOFT := Color("#b9fff4")
const CYAN_DIM := Color("#4cd8c4")
const GOLD := Color("#f0b45a")
const GOLD_DIM := Color("#f0b45a")
const RED := Color("#ff6248")
const RED_SOFT := Color("#ffd6c9")
const VIOLET := Color("#b8a6ff")
const GREEN := Color("#8bffb0")
const TEXT := Color("#e6f2fa")
const MUTED := Color("#8fa6b8")
const DIM := Color("#7590a4")
const BLACK := Color("#02050a")
const PANEL_EDGE := Color("#3f7288")

const Cards = preload("res://scripts/swarm_cards.gd")

const FONT_NAMES := [
	"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Microsoft YaHei", "Arial", "sans-serif",
]
const FONT_CJK_REG := "res://assets/fonts/NotoSansSC-Regular-subset.otf"
const FONT_CJK_BOLD := "res://assets/fonts/NotoSansSC-Bold-subset.otf"
const FONT_NUM := "res://assets/fonts/Oxanium-SemiBold.ttf"

static var _font_cache: Dictionary = {}


static func _load_font(path: String) -> FontFile:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is FontFile:
			return res
	return null


static func make_font(bold: bool = false) -> Font:
	var key := "bold" if bold else "reg"
	if _font_cache.has(key):
		return _font_cache[key]
	var loaded := _load_font(FONT_CJK_BOLD if bold else FONT_CJK_REG)
	if loaded == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(FONT_NAMES)
		f.font_weight = 700 if bold else 400
		f.allow_system_fallback = true
		f.multichannel_signed_distance_field = true
		_font_cache[key] = f
		return f
	loaded.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	loaded.allow_system_fallback = true
	_font_cache[key] = loaded
	return loaded


static func make_num_font() -> Font:
	if _font_cache.has("num"):
		return _font_cache["num"]
	var loaded := _load_font(FONT_NUM)
	if loaded == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Oxanium", "Arial", "sans-serif"])
		f.font_weight = 600
		f.allow_system_fallback = true
		_font_cache["num"] = f
		return f
	loaded.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	loaded.allow_system_fallback = true
	_font_cache["num"] = loaded
	return loaded


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = make_font(false)
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 1)
	var tip := make_style(PANEL2, LINE_HI, 4, 1)
	tip.content_margin_left = 10
	tip.content_margin_right = 10
	tip.content_margin_top = 7
	tip.content_margin_bottom = 7
	theme.set_stylebox("panel", "TooltipPanel", tip)
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font("font", "TooltipLabel", make_font(false))
	theme.set_font_size("font_size", "TooltipLabel", 12)
	theme.set_constant("line_spacing", "TooltipLabel", 5)
	return theme


static func make_style(bg: Color, border: Color, radius: int = 4, border_width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = border_width
	s.border_width_top = border_width
	s.border_width_right = border_width
	s.border_width_bottom = border_width
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.anti_aliasing = true
	return s


static func style_button(btn: Button, accent: Color = CYAN, font_size: int = 13, big: bool = false) -> void:
	var normal_bg := PANEL3 if not big else Color("#123a3a")
	var border := LINE_HI if not big else accent.darkened(0.35)
	var normal := make_style(normal_bg, border, 4, 1)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	var hover := make_style(Color("#12303f") if not big else Color("#17514c"), accent, 4, 1)
	hover.content_margin_left = 8
	hover.content_margin_right = 8
	hover.content_margin_top = 5
	hover.content_margin_bottom = 5
	var pressed := make_style(Color("#183d4b") if not big else Color("#1b6259"), accent, 4, 2)
	pressed.content_margin_left = 8
	pressed.content_margin_right = 8
	pressed.content_margin_top = 5
	pressed.content_margin_bottom = 5
	var disabled := make_style(Color("#08111b"), Color("#142635"), 4, 1)
	disabled.content_margin_left = 8
	disabled.content_margin_right = 8
	disabled.content_margin_top = 5
	disabled.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_override("font", make_font(big))
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", accent if big else TEXT)
	btn.add_theme_color_override("font_hover_color", CYAN_SOFT if accent == CYAN else accent)
	btn.add_theme_color_override("font_pressed_color", CYAN_SOFT)
	btn.add_theme_color_override("font_disabled_color", DIM)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func panel_style(bg: Color = PANEL, border: Color = LINE, radius: int = 6) -> StyleBoxFlat:
	var s := make_style(bg, border, radius, 1)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s


static func hex_points(center: Vector2, radius: float, squash: float = 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := PI / 3.0 * float(i) - PI / 6.0
		pts.append(center + Vector2(cos(a) * radius, sin(a) * radius * squash))
	return pts


static func fmt_int(n: int) -> String:
	return Cards.format_units(n)
