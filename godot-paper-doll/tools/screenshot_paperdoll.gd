extends SceneTree

# 真实 GPU 截图（1280×720）：试衣镜 / 衣柜 / 16 人阵容 / 8 向对照 / 4 动作对照。
# 用法：godot --path godot-paper-doll --resolution 1280x720 -s tools/screenshot_paperdoll.gd

const OUT := "res://docs/shots"
const SIZE := Vector2i(1280, 720)

var _vp: SubViewport
var _scene


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(1.0).timeout
	_scene.set_fps_visible(false)

	# 01 试衣镜：默认 preset，正面偏右 3/4，待机。
	_scene.load_lineup_entry(0)
	_scene.set_timeline_clock(0.9, true)
	await _settle()
	await _shot("01_studio")

	# 02 衣柜：载入乐手，换尖帽/长发/配色，走路朝右，展示变体与色板。
	_scene.load_lineup_entry(3)
	_scene.set_selected_slot("hat")
	_scene.set_slot_variant("hat", "wizard")
	_scene.set_slot_color("hat", Color("#e86a5c"))
	_scene.set_slot_variant("hair", "long")
	_scene.set_slot_color("hair", Color("#4a3427"))
	_scene.set_slot_variant("cape", "short")
	_scene.set_slot_color("cape", Color("#8a6fb0"))
	_scene.set_action("walk")
	_scene.set_direction(6)
	_scene.set_timeline_clock(0.55, true)
	await _settle()
	await _shot("02_wardrobe")

	# 03 4 动作对照：预设 11（纸灯剑客），挥击定格在抬臂段。
	_scene.load_lineup_entry(10)
	_scene.show_actions_sheet()
	await _settle()
	_scene.set_timeline_clock(0.0, true)
	await _settle()
	await _shot("03_actions")

	# 04 8 方向对照：短发的苔藓骑士，行走相位一致。
	_scene.close_sheet()
	_scene.load_lineup_entry(0)
	_scene.show_directions_sheet()
	await _settle()
	_scene.set_timeline_clock(0.0, true)
	await _settle()
	await _shot("04_directions")

	# 07 层视：试衣镜里 17 层沿右下展开，选中帽子层高亮。
	_scene.close_sheet()
	_scene.load_lineup_entry(0)
	_scene.set_selected_slot("hat")
	_scene.toggle_layer_view()
	_scene.set_direction(7)
	_scene.set_action("idle")
	_scene.set_timeline_clock(0.9, true)
	await _settle()
	await _shot("07_layer")
	_scene.toggle_layer_view()

	# 05 16 人阵容：整队随机后逐卡展示，试衣镜停在一个干净的朝右姿势。
	_scene.close_sheet()
	_scene.randomize_lineup()
	_scene.load_lineup_entry(4)
	_scene.set_direction(6)
	_scene.set_action("idle")
	_scene.set_timeline_clock(0.9, true)
	await _settle()
	await _shot("05_lineup")

	# 06 存档状态：回到试衣镜，保存一份 JSON 并展示底部状态。
	_scene.close_sheet()
	_scene.load_lineup_entry(6)
	_scene.set_slot_color("shirt", Color("#4fa58a"))
	_scene.set_slot_variant("weapon", "hammer")
	_scene.set_direction(7)
	_scene.set_action("idle")
	_scene.set_timeline_clock(1.1, true)
	_scene.save_current("user://paperdoll_shot_save.json")
	await _settle()
	await _shot("06_saved")

	print("PAPERDOLL_SHOTS_OK")
	quit(0)


func _settle() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path)
