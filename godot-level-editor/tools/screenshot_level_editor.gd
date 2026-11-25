extends SceneTree

# 1920×1080 真实 GPU 截图矩阵：
# 总览 / 自动铺砖细节 / 实体属性 / 矩形工具+碰撞 / JSON 导出 / 运行预览。
# 使用 1920×1080 SubViewport + 1280×720 逻辑覆盖，避免受本机窗口尺寸限制。
#
# 运行：
# godot --path godot-level-editor -s tools/screenshot_level_editor.gd

const EditorScene := preload("res://scenes/editor.tscn")
const SHOT_DIR := "res://docs/shots"

var _editor: Control
var _viewport: SubViewport
var _count := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.size_2d_override = Vector2i(1280, 720)
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	root.add_child(_viewport)
	_editor = EditorScene.instantiate()
	_viewport.add_child(_editor)
	await process_frame
	await process_frame
	await create_timer(1.5).timeout
	_editor.canvas.fit_view()
	_editor.update_zoom_label()

	# 1. 总览：整张示例地图 + 工具栏 / 调色板 / 图层 / 规则说明
	_editor.select_entity("")
	_editor.layer_id = "terrain"
	_editor.tool = "brush"
	_editor.canvas.fit_view()
	_editor.update_zoom_label()
	await _settle()
	await _shot("01_editor_overview.png")

	# 2. 自动铺砖细节：挑一格自动水岸，放大查看泡沫与掩码
	var water_cell := _find_auto_water_cell()
	_editor._on_layer_pressed("terrain")
	_editor._on_tool_pressed("select")
	_editor.select_cell(water_cell)
	_editor.focus_cell(water_cell, 3)
	_editor.canvas.hover_cell = water_cell
	_editor.update_hover(water_cell)
	_editor.canvas.queue_redraw()
	await _settle()
	await _shot("02_autotile_edges.png")

	# 3. 实体属性：选中敌人，右侧显示种类/HP/伤害/朝向/巡逻
	var enemy_cell := _find_entity_cell("enemy")
	var enemy: Dictionary = _editor.data.entity_at(enemy_cell.x, enemy_cell.y)
	_editor._on_layer_pressed("entities")
	_editor._on_tool_pressed("select")
	_editor.select_entity(String(enemy["id"]))
	_editor.focus_cell(enemy_cell, 2)
	_editor.canvas.hover_cell = enemy_cell
	_editor.update_hover(enemy_cell)
	_editor.canvas.queue_redraw()
	await _settle()
	await _shot("03_entity_properties.png")

	# 4. 矩形工具 + 碰撞层：拖拽中的范围预览
	_editor._on_layer_pressed("collision")
	_editor._on_tool_pressed("rect")
	_editor.focus_cell(Vector2i(12, 5), 2)
	await process_frame
	var canvas = _editor.canvas
	_press(canvas, Vector2i(9, 3), true)
	_move_mouse(canvas, Vector2i(15, 7))
	_editor.select_cell(Vector2i(7, 3))
	_editor.update_hover(Vector2i(15, 7))
	await _settle()
	await _shot("04_rect_tool_collision.png")
	canvas._cancel_gesture()
	_editor._toast_panel.visible = false

	# 5. 导出 JSON：真实 writer 产出的运行时 JSON
	var export_path := "user://exports/screenshot.runtime.json"
	var text: String = _editor.export_to_path(export_path, true)
	await process_frame
	await process_frame
	var line := _line_of(text, "\"entities\"")
	_editor._json_edit.scroll_vertical = maxi(0, line - 2)
	await _settle()
	await _shot("05_json_export.png")

	# 6. 运行预览：从当前 JSON 重建，走到宝箱上触发拾取
	_editor._hide_json_panel()
	_editor.open_preview()
	await process_frame
	var preview = _editor.preview
	if preview != null and preview.level != null:
		preview.facing = "up"
		preview.try_move(Vector2(48, 0))
		preview.try_move(Vector2(0, -48))
		preview.try_pickups()
	await _settle()
	await _shot("06_preview_walk.png")

	print("LEVEL_EDITOR_SHOTS_OK n=%d" % _count)
	quit(0)


func _settle() -> void:
	await create_timer(0.8).timeout
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	var path := SHOT_DIR + "/" + file_name
	var abs_path := ProjectSettings.globalize_path(path)
	var err := image.save_png(abs_path)
	if err != OK:
		print("SHOT_FAIL ", file_name, " err=", err)
	else:
		_count += 1
		print("SHOT ", file_name, " ", image.get_width(), "x", image.get_height())


func _find_auto_water_cell() -> Vector2i:
	for y in _editor.data.height:
		for x in _editor.data.width:
			var tile: Dictionary = _editor.data.get_tile(x, y)
			if tile.is_empty():
				continue
			if String(tile["type"]) == "water" and int(tile.get("variant", -1)) < 0 and int(tile.get("mask", 15)) != 15:
				return Vector2i(x, y)
	return Vector2i(27, 13)


func _find_entity_cell(type: String) -> Vector2i:
	for entity in _editor.data.entities:
		if String(entity["type"]) == type:
			return Vector2i(int(entity["x"]), int(entity["y"]))
	return Vector2i(10, 10)


func _line_of(text: String, needle: String) -> int:
	var lines := text.split("\n")
	for index in lines.size():
		if String(lines[index]).contains(needle):
			return index
	return 0


func _press(canvas: Control, cell: Vector2i, pressed: bool) -> void:
	var pos: Vector2 = canvas.cell_center_local(cell)
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	canvas._gui_input(event)


func _move_mouse(canvas: Control, cell: Vector2i) -> void:
	var pos: Vector2 = canvas.cell_center_local(cell)
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	canvas._gui_input(event)
