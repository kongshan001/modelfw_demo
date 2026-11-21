class_name AssetLoader
extends RefCounted

# 直接按字节读取 PNG 并创建 ImageTexture。
# 目的：从干净 clone 直接运行游戏时，不依赖 Godot 编辑器生成的 .godot/imported 缓存；
# 也避免 Image.load() 在未导入资源上的 “will not work on export” 警告。
# 本项目所有美术都是 PNG；如需导出 PCK，可改用常规导入资源或在导出过滤器中包含 PNG。

static var _textures: Dictionary = {}


static func texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	if not FileAccess.file_exists(path):
		push_error("AssetLoader: missing %s" % path)
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_error("AssetLoader: empty %s" % path)
		return null
	var image := Image.new()
	var err := image.load_png_from_buffer(bytes)
	if err != OK:
		push_error("AssetLoader: cannot decode %s (%d)" % [path, err])
		return null
	var tex := ImageTexture.create_from_image(image)
	_textures[path] = tex
	return tex


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)
