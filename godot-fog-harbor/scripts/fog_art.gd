class_name FogArt
extends RefCounted
## 程序化资源：系统 CJK 字体、可平铺雾噪声纹理。全部运行时生成，无外部素材。

static var _font: SystemFont
static var _bold_font: SystemFont
static var _title_font: SystemFont
static var _fog_noise: ImageTexture


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
		_title_font.font_names = PackedStringArray([
			"Kaiti SC", "STKaiti", "KaiTi", "Songti SC", "PingFang SC", "sans-serif",
		])
		_title_font.font_weight = 700
	return _title_font


static func fog_noise() -> ImageTexture:
	if _fog_noise == null:
		var noise := FastNoiseLite.new()
		noise.seed = 20261121
		noise.frequency = 0.032
		noise.fractal_octaves = 3
		var size := 128
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in range(size):
			for x in range(size):
				var v := 0.5 + 0.5 * noise.get_noise_2d(float(x), float(y))
				img.set_pixel(x, y, Color(v, v, v, 1.0))
		_fog_noise = ImageTexture.create_from_image(img)
	return _fog_noise
