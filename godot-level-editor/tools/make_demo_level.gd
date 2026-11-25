extends SceneTree

const LevelData := preload("res://scripts/level_data.gd")

# 生成内置示例关卡 JSON。运行：
# godot --headless --path godot-level-editor -s tools/make_demo_level.gd


func _initialize() -> void:
	var demo := LevelData.build_demo()
	var text := demo.to_json(false, true)
	var path := "res://levels/demo_level.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("DEMO_WRITE_FAILED ", FileAccess.get_open_error())
		quit(1)
		return
	file.store_string(text)
	file.close()
	print("DEMO_OK path=%s bytes=%d" % [path, text.length()])
	quit(0)
