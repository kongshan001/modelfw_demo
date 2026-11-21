class_name AtlasAnim
extends Sprite2D

const AssetLoaderScript = preload("res://scripts/asset_loader.gd")

# 按 open-duelyst-assets 的 JSON 帧数据切图集，播放 idle/run/attack/hit/death 等动画。
# Sprite2D 直接换 AtlasTexture；不依赖 AnimatedSprite2D 的 SpriteFrames 导入。

signal finished(anim_name: String)

var sheet_id := ""
var anim_name := ""
var fps := 12.0
var loop := true

var _frames: Dictionary = {}
var _sheet: Texture2D
var _cache: Dictionary = {}
var _frame_i := 0
var _acc := 0.0
var _playing := false
var _last_texture: AtlasTexture

static var _frames_cache: Dictionary = {}
static var _static_texture_cache: Dictionary = {}


func load_sheet(id: String, folder := "units") -> bool:
	sheet_id = id
	var base := "res://assets/duelyst_cc0/%s/%s" % [folder, id]
	if not FileAccess.file_exists(base + ".png"):
		push_warning("AtlasAnim: missing sheet %s" % base)
		return false
	_sheet = AssetLoaderScript.texture(base + ".png")
	if _frames_cache.has(base):
		_frames = _frames_cache[base]
	else:
		var json_file := FileAccess.open(base + ".json", FileAccess.READ)
		if json_file == null:
			push_warning("AtlasAnim: missing frames %s.json" % base)
			return false
		var parsed: Variant = JSON.parse_string(json_file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			push_warning("AtlasAnim: bad JSON %s.json" % base)
			return false
		_frames = parsed.get("frames", {})
		_frames_cache[base] = _frames
	_cache.clear()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return not _frames.is_empty()


func play(next_anim: String, next_fps := -1.0, next_loop := true) -> void:
	if _frames.is_empty():
		return
	var resolved := _resolve_anim(next_anim)
	if next_fps > 0.0:
		fps = next_fps
	loop = next_loop
	if resolved == anim_name and _playing:
		return
	if resolved != anim_name:
		anim_name = resolved
		_frame_i = 0
		_acc = 0.0
	_playing = true
	_apply_frame()


func set_anim_phase(offset_frames: int) -> void:
	if _frames.is_empty():
		return
	var list: Array = _frames.get(anim_name, [])
	if list.is_empty():
		return
	_frame_i = absi(offset_frames) % list.size()
	_apply_frame()


func current_texture() -> AtlasTexture:
	return _last_texture


func frame_count(requested: String) -> int:
	if _frames.is_empty():
		return 0
	var list: Array = _frames.get(_resolve_anim(requested), [])
	return list.size()


func _resolve_anim(requested: String) -> String:
	if _frames.has(requested):
		return requested
	match requested:
		"hit":
			if _frames.has("hurt"):
				return "hurt"
		"idle":
			if _frames.has("breathing"):
				return "breathing"
		"run":
			if _frames.has("idle"):
				return "idle"
		"death":
			if _frames.has("idle"):
				return "idle"
		"attack":
			if _frames.has("cast"):
				return "cast"
	if _frames.has("idle"):
		return "idle"
	return String(_frames.keys()[0])


func _process(delta: float) -> void:
	if not _playing or _frames.is_empty():
		return
	var list: Array = _frames.get(anim_name, [])
	if list.is_empty():
		return
	_acc += delta * fps
	while _acc >= 1.0:
		_acc -= 1.0
		if _frame_i + 1 >= list.size():
			if loop:
				_frame_i = 0
			else:
				_playing = false
				_apply_frame()
				finished.emit(anim_name)
				return
		else:
			_frame_i += 1
	_apply_frame()


func _apply_frame() -> void:
	var list: Array = _frames.get(anim_name, [])
	if list.is_empty():
		return
	_frame_i = clampi(_frame_i, 0, list.size() - 1)
	var atlas := _atlas_for(anim_name, _frame_i)
	texture = atlas
	_last_texture = atlas


func _atlas_for(anim: String, index: int) -> AtlasTexture:
	if not _cache.has(anim):
		_cache[anim] = _build_cache(anim)
	var cached: Array = _cache[anim]
	if cached.is_empty():
		return null
	return cached[clampi(index, 0, cached.size() - 1)]


func _build_cache(anim: String) -> Array:
	var out: Array = []
	var list: Array = _frames.get(anim, [])
	for frame in list:
		var atlas := AtlasTexture.new()
		atlas.atlas = _sheet
		atlas.region = Rect2(
			int(frame["x0"]), int(frame["y0"]),
			int(frame["width"]), int(frame["height"]))
		atlas.filter_clip = true
		out.append(atlas)
	return out


static func static_frame(id: String, folder: String, anim: String, index := 0) -> AtlasTexture:
	var base := "res://assets/duelyst_cc0/%s/%s" % [folder, id]
	var key := "%s|%s|%d" % [base, anim, index]
	if _static_texture_cache.has(key):
		return _static_texture_cache[key]
	if not FileAccess.file_exists(base + ".png"):
		return null
	var frames: Dictionary = {}
	if _frames_cache.has(base):
		frames = _frames_cache[base]
	else:
		var json_file := FileAccess.open(base + ".json", FileAccess.READ)
		if json_file == null:
			return null
		var parsed: Variant = JSON.parse_string(json_file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			return null
		frames = parsed.get("frames", {})
		_frames_cache[base] = frames
	var list: Array = frames.get(anim, [])
	if list.is_empty():
		list = frames.values()[0]
	if list.is_empty():
		return null
	var frame: Dictionary = list[clampi(index, 0, list.size() - 1)]
	var atlas := AtlasTexture.new()
	atlas.atlas = AssetLoaderScript.texture(base + ".png")
	atlas.region = Rect2(
		int(frame["x0"]), int(frame["y0"]),
		int(frame["width"]), int(frame["height"]))
	atlas.filter_clip = true
	_static_texture_cache[key] = atlas
	return atlas
