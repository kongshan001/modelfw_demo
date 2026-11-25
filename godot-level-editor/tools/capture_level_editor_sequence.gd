extends SceneTree

# 10 秒演示序列（20 fps × 200 帧，1280×720 SubViewport）：
# 画结构 → 自动铺砖 → 实体属性 → 保存/导出 → 运行预览。
#
# 运行：
# godot --path godot-level-editor -s tools/capture_level_editor_sequence.gd
# 产物：user://screenshots/level_editor_seq/frame_000.png ...

const EditorScene := preload("res://scenes/editor.tscn")
const LevelDataScript := preload("res://scripts/level_data.gd")
const SEQ_DIR := "user://screenshots/level_editor_seq"
const TARGET_FRAMES := 200

var _editor: Control
var _viewport: SubViewport
var _frame := 0
var _caption_root: Control
var _caption_label: Label


func _initialize() -> void:
	var dir_abs := ProjectSettings.globalize_path(SEQ_DIR)
	DirAccess.make_dir_recursive_absolute(dir_abs)
	for file in DirAccess.get_files_at(SEQ_DIR):
		if file.ends_with(".png"):
			DirAccess.remove_absolute(dir_abs + "/" + file)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	root.add_child(_viewport)
	_editor = EditorScene.instantiate()
	_viewport.add_child(_editor)
	_build_caption_overlay()
	await process_frame
	await process_frame
	await create_timer(1.5).timeout
	_editor.canvas.fit_view()
	_editor.update_zoom_label()
	_editor.select_entity("")
	_editor._hide_json_panel()
	_editor._fps_label.visible = false

	# 0–29：总览
	_set_caption("苔井工坊 · 原创 2D 关卡编辑器")
	for i in 30:
		if i == 14:
			_set_caption("画结构 → 自动铺砖 → 实体属性 → JSON → 预览")
		await _capture()

	# 30–87：墙体绘制 + 自动接边
	_set_caption("① 先画结构：画笔连绘，墙体自动接边")
	_editor._on_layer_pressed("terrain")
	_editor._on_tile_pressed("wall")
	_editor.focus_cell(Vector2i(8, 13), 2)
	await _capture()
	var path: Array[Vector2i] = []
	for x in range(4, 12):
		path.append(Vector2i(x, 11))
	for y in range(12, 17):
		path.append(Vector2i(11, y))
	for x in range(12, 16):
		path.append(Vector2i(x, 16))
	var canvas = _editor.canvas
	_press(canvas, path[0], true)
	var draw_frames := 44
	for i in draw_frames:
		var idx := mini(path.size() - 1, int(float(i) / float(draw_frames - 1) * float(path.size() - 1)))
		_move_mouse(canvas, path[idx])
		await _capture()
	_press(canvas, path[path.size() - 1], false)
	_set_caption("② 自动铺砖：转角/端点由 4 邻掩码即时计算")
	for i in 6:
		await _capture()

	# 88–101：挖掉一块墙，边缘即时重算
	_set_caption("挖掉一块墙，边缘与相邻掩码自动更新")
	_editor._on_tool_pressed("eraser")
	_press(canvas, Vector2i(8, 11), true)
	_press(canvas, Vector2i(8, 11), false)
	for i in 5:
		await _capture()
	_editor.undo()
	for i in 4:
		await _capture()

	# 102–131：放置敌人并编辑属性
	_set_caption("③ 实体 + 属性：HP / 种类 / 朝向写入 JSON")
	_editor._on_entity_pressed("enemy")
	_editor.focus_cell(Vector2i(15, 12), 2)
	await _capture()
	_press(canvas, Vector2i(17, 12), true)
	_press(canvas, Vector2i(17, 12), false)
	await process_frame
	await capture_frame()
	var values := [40, 55, 70, 85]
	for index in values.size():
		_editor._on_entity_prop_number(float(values[index]), "hp")
		for i in 3:
			await _capture()
	_editor._on_entity_prop_option(1, "kind", LevelDataScript.ENEMY_KINDS)
	for i in 3:
		await _capture()
	_editor._on_entity_prop_option(3, "facing", LevelDataScript.FACING_VALUES)
	for i in 4:
		await _capture()

	# 111–142：保存 + 导出 JSON
	for i in 4:
		await _capture()
	_set_caption("④ 保存编辑器 JSON，导出运行时 JSON")
	_editor.save_to_path("user://levels/sequence_demo.json")
	for i in 6:
		await _capture()
	var runtime_text: String = _editor.export_to_path("user://exports/sequence.runtime.json", true)
	_set_caption("JSON 可直接交给 Godot / Unity / Web 读取")
	await process_frame
	_editor._json_edit.scroll_vertical = maxi(0, _line_of(runtime_text, "\"entities\"") - 1)
	for i in 21:
		await _capture()
	_editor._hide_json_panel()

	# 143–199：运行预览并走向宝箱
	_set_caption("⑤ 运行预览：把当前 JSON 载入可走的校验地图")
	_editor.open_preview()
	await process_frame
	for i in 4:
		await _capture()
	var preview = _editor.preview
	if preview != null and preview.level != null:
		preview.facing = "right"
		for i in 16:
			preview.try_move(Vector2(3.125, 0))
			preview.try_pickups()
			await _capture()
		preview.facing = "up"
		for i in 12:
			preview.try_move(Vector2(0, -4.0))
			preview.try_pickups()
			await _capture()
	while _frame < TARGET_FRAMES:
		if preview != null and preview.pickup_flash > 0.0:
			preview.pickup_flash = 3.0
			preview.queue_redraw()
		await _capture()

	print("LEVEL_EDITOR_SEQ_OK frames=%d dir=%s" % [_frame, SEQ_DIR])
	quit(0)


func _capture() -> void:
	await capture_frame()


func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	var path := "%s/frame_%03d.png" % [SEQ_DIR, _frame]
	image.save_png(ProjectSettings.globalize_path(path))
	_frame += 1
	if _frame % 50 == 0:
		print("SEQ progress ", _frame, "/", TARGET_FRAMES)


func _line_of(text: String, needle: String) -> int:
	var lines := text.split("\n")
	for index in lines.size():
		if String(lines[index]).contains(needle):
			return index
	return 0


func _set_caption(text: String) -> void:
	if _caption_label != null:
		_caption_label.text = "  " + text + "  "


func _build_caption_overlay() -> void:
	_caption_root = Control.new()
	_caption_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_caption_root)
	var center := CenterContainer.new()
	center.anchor_left = 0.0
	center.anchor_right = 1.0
	center.anchor_top = 0.0
	center.anchor_bottom = 0.0
	center.offset_top = 62
	center.offset_bottom = 100
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_root.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.075, 0.94)
	style.border_color = Color("#7d9f69")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Microsoft YaHei", "Noto Sans"])
	font.font_weight = 600
	font.allow_system_fallback = true
	_caption_label = Label.new()
	_caption_label.add_theme_font_override("font", font)
	_caption_label.add_theme_font_size_override("font_size", 15)
	_caption_label.add_theme_color_override("font_color", Color("#e8b36a"))
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_caption_label)


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
