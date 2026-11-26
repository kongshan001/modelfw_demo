class_name FontLib
extends RefCounted
## System CJK font entry point. No font files are shipped with the project.

const NAMES := ["PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans CJK SC",
	"Source Han Sans SC", "Arial Unicode MS", "sans-serif"]

static var _regular: Font
static var _bold: Font
static var _mono: Font


static func regular() -> Font:
	if _regular == null:
		_regular = _make(500)
	return _regular


static func bold() -> Font:
	if _bold == null:
		_bold = _make(700)
	return _bold


static func mono() -> Font:
	if _mono == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Menlo", "SF Mono", "Consolas", "Noto Sans Mono",
			"PingFang SC", "sans-serif"])
		f.font_weight = 500
		_mono = f
	return _mono


static func _make(weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(NAMES)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f
