class_name Art
extends RefCounted

# 原创视觉常量：紫黑舞台、霓虹青/品红、少量暖金点缀。
# 字体走系统字体列表，不随仓库分发字体文件。

const INK := Color("#f8f5ff")
const DIM := Color("#8f82b8")
const LINE := Color("#6b5a99")
const MAGENTA := Color("#ff5fce")
const CYAN := Color("#67f3ff")
const GOLD := Color("#ffd166")
const LILAC := Color("#a78bfa")
const RED := Color("#ff5a7a")
const BG_TOP := Color("#1d0b33")
const BG_BOTTOM := Color("#04050d")

const BULLET_PALETTE: Array[Color] = [MAGENTA, CYAN, GOLD, LILAC, Color("#ffffff")]

static var _font: SystemFont
static var _bold: SystemFont
static var _title: SystemFont
static var _glow_tex: ImageTexture

static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray([
			"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
			"Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Micro Hei", "sans-serif",
		])
		_font.font_weight = 400
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return _font

static func bold_font() -> SystemFont:
	if _bold == null:
		_bold = SystemFont.new()
		_bold.font_names = font().font_names
		_bold.font_weight = 700
		_bold.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return _bold

static func title_font() -> SystemFont:
	if _title == null:
		_title = SystemFont.new()
		_title.font_names = PackedStringArray([
			"Songti SC", "STSong", "Noto Serif CJK SC", "Source Han Serif SC",
			"PingFang SC", "serif",
		])
		_title.font_weight = 700
	return _title

static func bullet_color(index: int) -> Color:
	return BULLET_PALETTE[posmod(index, BULLET_PALETTE.size())]

static func glow_texture() -> ImageTexture:
	if _glow_tex != null:
		return _glow_tex
	const S := 96
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var c := Vector2(S - 1, S - 1) * 0.5
	for y in S:
		for x in S:
			var d: float = Vector2(x, y).distance_to(c) / (S * 0.5)
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			a = pow(a, 2.4)
			var core: float = clamp(1.0 - d * 2.8, 0.0, 1.0)
			core = pow(core, 1.2)
			var v: float = min(1.0, a * 0.85 + core * 0.7)
			img.set_pixel(x, y, Color(v * 0.85, v * 0.92, 1.0, v))
	_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex

static func draw_text(ci: CanvasItem, pos: Vector2, text: String, size: int, color: Color = INK, bold := false, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, shadow := true) -> void:
	var f: Font = bold_font() if bold else font()
	if shadow:
		ci.draw_string(f, pos + Vector2(1.0, 2.0), text, align, width, size, Color(0.01, 0.0, 0.03, 0.72))
	ci.draw_string(f, pos, text, align, width, size, color)

static func draw_title(ci: CanvasItem, pos: Vector2, text: String, size: int, color: Color = INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	if width < 0.0:
		ci.draw_string(title_font(), pos + Vector2(2.0, 3.0), text, align, width, size, Color(0.0, 0.0, 0.0, 0.7))
	else:
		ci.draw_string(title_font(), pos + Vector2(2.0, 3.0), text, align, width, size, Color(0.0, 0.0, 0.0, 0.7))
	ci.draw_string(title_font(), pos, text, align, width, size, color)

static func text_width(text: String, size: int, bold := false) -> float:
	var f: Font = bold_font() if bold else font()
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
