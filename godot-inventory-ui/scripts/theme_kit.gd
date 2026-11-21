class_name ThemeKit
extends RefCounted

# ---- palette (original, inspired only by the reference's "ice blue + gold + red ribbon" language)
const PANEL_LIGHT := Color("ecf9ff")
const PANEL_ICE := Color("c6e0f0")
const PANEL_DEEP := Color("a7c8e0")
const CELL_TOP := Color("c8e1f2")
const CELL_BOTTOM := Color("9fc0db")
const CELL_TOP_HOT := Color("e2f4ff")
const CELL_BOTTOM_HOT := Color("b6d8ea")
const TEXT_LIGHT := Color("f4fdff")
const TEXT_INK := Color("1d4259")
const TEXT_INK_SOFT := Color("3f6b84")
const TEXT_MUTED := Color("7f9fb2")
const GOLD := Color("e8c778")
const GOLD_BRIGHT := Color("fff0bd")
const GOLD_DEEP := Color("a87527")
const GOLD_DARK := Color("6f4a16")
const RED_PLAQUE := Color("8f1d29")
const RED_RIBBON := Color("a92c35")
const MINT := Color("72d8c6")
const MINT_BRIGHT := Color("b5f5e9")
const NAVY_GLASS := Color("122f44")
const NAVY_GLASS_DEEP := Color("0a1e2e")
const HP_TOP := Color("ff9c8d")
const HP_BOTTOM := Color("e85049")
const MP_TOP := Color("8bd8ff")
const MP_BOTTOM := Color("2f8fe0")
const BUTTON_TEXT := Color("5a3410")
const DISABLED_TOP := Color("b9c6cf")
const DISABLED_BOTTOM := Color("94a5b1")

const QUALITY_NAMES := ["凡品", "良品", "珍品", "绝品"]
const QUALITY_COLORS := [
	Color("e8f0f5"),
	Color("74d99e"),
	Color("68adff"),
	Color("c48bff"),
]
const QUALITY_DARK := [
	Color("aabac6"),
	Color("3b9e68"),
	Color("346fbb"),
	Color("7c4bb8"),
]

static var _body_font: Font
static var _title_font: Font
static var _icon_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func body_font() -> Font:
	if _body_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray([
			"PingFang SC", "Hiragino Sans GB", "Heiti SC", "Noto Sans CJK SC",
			"Source Han Sans SC", "Microsoft YaHei", "sans-serif",
		])
		f.font_weight = 500
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_body_font = f
	return _body_font


static func title_font() -> Font:
	if _title_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray([
			"STKaiti", "Kaiti SC", "Songti SC", "STSong", "Noto Serif CJK SC",
			"Source Han Serif SC", "serif",
		])
		f.font_weight = 700
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_title_font = f
	return _title_font


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 16
	return t


static func icon(name: String) -> Texture2D:
	if not _icon_cache.has(name):
		var path := "res://assets/icons/icon_%s.svg" % name
		_icon_cache[name] = load(path)
	return _icon_cache[name]


static func ui_tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load("res://assets/ui/%s.png" % name)
	return _tex_cache[name]


static func bg_tex(name: String) -> Texture2D:
	return load("res://assets/bg/%s.png" % name)


static func quality_name(q: int) -> String:
	return QUALITY_NAMES[clampi(q, 0, 3)]


static func quality_color(q: int) -> Color:
	return QUALITY_COLORS[clampi(q, 0, 3)]


static func quality_dark(q: int) -> Color:
	return QUALITY_DARK[clampi(q, 0, 3)]


static func make_label(
		parent: Node,
		text: String,
		font_size: int,
		color: Color,
		pos: Vector2,
		size_px: Vector2,
		align: int = HORIZONTAL_ALIGNMENT_LEFT,
		font: Font = null,
		outline_size: int = 0,
		outline_color: Color = Color(0.06, 0.15, 0.22, 0.8)
	) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size_px
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font if font != null else body_font())
	var ls := LabelSettings.new()
	ls.font = font if font != null else body_font()
	ls.font_size = font_size
	ls.font_color = color
	if outline_size > 0:
		ls.outline_size = outline_size
		ls.outline_color = outline_color
	l.label_settings = ls
	parent.add_child(l)
	return l


static func make_glow(parent: Node, color: Color, size_px: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = ui_tex("glow")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(size_px, size_px)
	tr.modulate = color
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


static func glow_texture_rect(tex_name: String, color: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = ui_tex(tex_name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.modulate = color
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func gradient_rect(
		parent: Node,
		pos: Vector2,
		size_px: Vector2,
		rad: float,
		top: Color,
		bottom: Color,
		border: Color = Color(0, 0, 0, 0),
		border_w: float = 0.0,
		gloss_amount: float = 0.0,
		gloss_col: Color = Color(1, 1, 1, 1),
		sheen_amount: float = 0.0
	) -> GradientRect:
	var g := GradientRect.new()
	g.position = pos
	g.setup(size_px, rad, top, bottom, border, border_w, gloss_amount, gloss_col, sheen_amount)
	parent.add_child(g)
	return g


static func pill_style(bg: Color, border: Color, rad: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = rad
	sb.corner_radius_top_right = rad
	sb.corner_radius_bottom_left = rad
	sb.corner_radius_bottom_right = rad
	sb.border_color = border
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	return sb


static func format_number(n: int) -> String:
	return str(n)


static func animate_fade_in(node: CanvasItem, duration: float, target_alpha: float = 1.0) -> Tween:
	var tw := node.create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", target_alpha, duration)
	return tw


static func clamp_tooltip(pos: Vector2, tip_size: Vector2, screen: Vector2) -> Vector2:
	var x := clampf(pos.x, 12.0, screen.x - tip_size.x - 12.0)
	var y := clampf(pos.y, 12.0, screen.y - tip_size.y - 12.0)
	return Vector2(x, y)
