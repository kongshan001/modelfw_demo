class_name VisualCatalog
extends RefCounted

# 可选美术目录：把 AI / 外部美术接入点集中在一个 JSON 里。
# 所有映射都是可选的；文件缺失、JSON 非法或纹理加载失败时，
# UnitView / BackgroundView 会安静地回退到程序化绘制，核心与数据层零改动。
#
# 支持 res:// 与 user:// 路径。res:// 下的图片需先经过 Godot 导入；
# 若资源未导入但文件存在，则用 Image.load_from_file 直接加载。
#
# 角色立绘的 scale 是相对原始像素的倍率，不是目标高度。接入未来 AI 图片时
# 先按目标高度（推荐 300px）换算：scale = 300 / 图片像素高度，再用 offset
# 校正脚底对齐；否则大图会压住头顶信息条。
# 单位条目支持 sprites: {front, back} 分别提供正面/背影贴图（值可以是路径字符串，
# 也可以是 {sprite/path, scale, offset} 字典）；缺省时回退旧版 sprite/path，
# 贴图缺失或加载失败再由 UnitView 回退到对应的程序化正面/背影绘制。
# 全局美术缩放由 UnitView.BASE_ART_SCALE 统一应用，与贴图自身 scale 相乘。

const CATALOG_PATH := "res://assets/visuals/visual_catalog.json"

static var _data: Dictionary = {}
static var _loaded := false
static var _texture_cache: Dictionary = {}


static func catalog() -> Dictionary:
	if _loaded:
		return _data
	_loaded = true
	_data = {}
	if not FileAccess.file_exists(CATALOG_PATH):
		return _data
	var text := FileAccess.get_file_as_string(CATALOG_PATH)
	if text.strip_edges().is_empty():
		return _data
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_data = parsed
	else:
		push_warning("VisualCatalog: %s is not a JSON object; using procedural art" % CATALOG_PATH)
	return _data


static func unit_entry(unit_id: StringName) -> Dictionary:
	return _group_entry("units", String(unit_id))


static func unit_sprite(unit_id: StringName, view: String = "front") -> Dictionary:
	# 解析当前视图的贴图条目：sprites.back / sprites.front 优先，其次旧版 sprite/path。
	# 返回 {path, scale?, offset?}；路径为空表示使用程序化绘制。
	var entry := unit_entry(unit_id)
	var result: Dictionary = {}
	var view_key := "back" if view == "back" else "front"
	var sprites: Variant = entry.get("sprites", {})
	if sprites is Dictionary:
		var view_entry: Variant = (sprites as Dictionary).get(view_key, {})
		if view_entry is String:
			result["path"] = view_entry
		elif view_entry is Dictionary:
			result["path"] = String(view_entry.get("sprite", view_entry.get("path", "")))
			if view_entry.has("scale"):
				result["scale"] = float(view_entry.get("scale", 1.0))
			if view_entry.has("offset"):
				result["offset"] = view_entry.get("offset")
	if String(result.get("path", "")).strip_edges().is_empty():
		result["path"] = String(entry.get("sprite", entry.get("path", "")))
		if entry.has("scale"):
			result["scale"] = float(entry.get("scale", 1.0))
		if entry.has("offset"):
			result["offset"] = entry.get("offset")
	return result


static func background_entry() -> Dictionary:
	var section: Variant = catalog().get("background", {})
	if not (section is Dictionary):
		return {}
	return section


static func status_entry(status_id: StringName) -> Dictionary:
	return _group_entry("status_icons", String(status_id))


static func command_entry(command_id: StringName) -> Dictionary:
	return _group_entry("command_icons", String(command_id))


static func status_icon(status_id: StringName) -> Texture2D:
	return load_texture(status_entry(status_id).get("path", ""))


static func command_icon(command_id: StringName) -> Texture2D:
	return load_texture(command_entry(command_id).get("path", ""))


static func load_texture(path: Variant) -> Texture2D:
	var resolved := String(path).strip_edges()
	if resolved.is_empty():
		return null
	if _texture_cache.has(resolved):
		return _texture_cache[resolved] as Texture2D
	var texture: Texture2D = null
	if ResourceLoader.exists(resolved):
		var resource := ResourceLoader.load(resolved)
		if resource is Texture2D:
			texture = resource
	if texture == null and FileAccess.file_exists(resolved):
		var image := Image.load_from_file(ProjectSettings.globalize_path(resolved))
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	_texture_cache[resolved] = texture
	return texture


static func _group_entry(group: String, key: String) -> Dictionary:
	var section: Variant = catalog().get(group, {})
	if not (section is Dictionary):
		return {}
	var entry: Variant = (section as Dictionary).get(key, {})
	if entry is Dictionary:
		return entry
	# 允许直接把路径写成字符串，例如 "hero_swordsman": "res://units/hero.png"。
	if entry is String:
		return {"sprite": entry, "path": entry}
	return {}
