class_name KnotFont
extends RefCounted

## Loads the bundled CJK subset directly from disk with FontFile, bypassing
## Godot's import pipeline. That keeps direct command-line runs working even
## when no .godot/imported cache exists. Falls back to a system CJK font.

const FONT_PATH := "res://assets/fonts/NotoSansSC-Knotline.otf"

static var _cached: Font


static func ui_font() -> Font:
	if _cached != null:
		return _cached
	var f := FontFile.new()
	var err := f.load_dynamic_font(ProjectSettings.globalize_path(FONT_PATH))
	if err == OK:
		_cached = f
		return _cached
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Microsoft YaHei", "Noto Sans SC"])
	_cached = sf
	return _cached
