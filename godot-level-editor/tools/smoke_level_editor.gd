extends SceneTree

# 苔井工坊 headless 验收：
# 画/擦/矩形/直线、自动铺砖规则、实体属性、撤销/重做、
# 保存/加载 roundtrip、JSON schema、预览加载、真实 UI 输入路径。
#
# 运行：
# godot --headless --path godot-level-editor -s tools/smoke_level_editor.gd

const LevelDataScript := preload("res://scripts/level_data.gd")
const EditorScene := preload("res://scenes/editor.tscn")

var checks := 0
var failures: Array[String] = []
var _editor: Control


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("[FAIL] ", message)


func _initialize() -> void:
	print("=== 苔井工坊 · 关卡编辑器 smoke ===")
	_test_level_data()
	_test_autotile()
	_test_shapes()
	_test_entities_and_schema()
	_test_roundtrip()
	await _test_preview()
	await _test_editor_ui_and_tools()
	print("checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty():
		print("LEVEL_EDITOR_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			print("[FAILED] ", failure)
		print("LEVEL_EDITOR_SMOKE_FAIL")
		quit(1)


func _test_level_data() -> void:
	var level := LevelDataScript.new(12, 8, 16, "烟测")
	check(level.width == 12 and level.height == 8, "初始尺寸")
	check(level.in_bounds(0, 0) and not level.in_bounds(-1, 0), "边界判定")
	check(level.get_tile(0, 0).is_empty(), "初始为空")
	check(level.paint_terrain(2, 2, "grass"), "画笔写入地形")
	check(not level.paint_terrain(2, 2, "lava"), "非法瓦片类型被拒绝")
	check(level.erase_terrain(2, 2), "橡皮擦除")
	check(level.get_tile(2, 2).is_empty(), "擦除后为空")
	check(not level.erase_terrain(2, 2), "重复擦除返回 false")
	level.paint_collision(6, 4, true)
	check(level.collision_at(6, 4), "碰撞写入")
	level.paint_collision(6, 4, false)
	check(not level.collision_at(6, 4), "碰撞擦除")
	check(not level.is_walkable(99, 99), "地图外不可走")


func _test_autotile() -> void:
	var level := LevelDataScript.new(12, 8, 16, "自动铺砖")
	for y in range(2, 5):
		for x in range(2, 5):
			level.paint_terrain(x, y, "grass")
	check(int(level.get_tile(3, 3)["mask"]) == 15, "草地中心四向连接 mask=15")
	check(int(level.get_tile(2, 2)["mask"]) == 6, "草地左上角 mask=6（东+南）")
	check(int(level.get_tile(2, 3)["mask"]) == 7, "草地左边 mask=7（北+东+南）")

	level.erase_terrain(3, 2)
	check(int(level.get_tile(3, 3)["mask"]) == 14, "擦除上方邻格后中心 mask 更新为 14")

	# 关闭自动更新：只写当前格，周围保持旧掩码；重算后再更新。
	level.paint_terrain(3, 2, "grass", -1, false)
	check(int(level.get_tile(3, 3)["mask"]) == 14, "自动关闭时邻格不更新（可手动覆盖）")
	level.recalculate_autotiles()
	check(int(level.get_tile(3, 3)["mask"]) == 15, "重算后邻格恢复 mask=15")

	# 手动变体优先，重算不清除。
	level.paint_terrain(4, 3, "grass", 1, true)
	check(int(level.get_tile(4, 3)["variant"]) == 1, "手动变体写入")
	var manual_mask := int(level.get_tile(4, 3)["mask"])
	level.recalculate_autotiles()
	check(int(level.get_tile(4, 3)["variant"]) == 1, "重算保留手动变体")
	check(int(level.get_tile(4, 3)["mask"]) == manual_mask, "重算跳过手动格")
	level.clear_manual_overrides()
	check(int(level.get_tile(4, 3)["variant"]) == -1, "清除手动覆盖")

	# 石墙：直线连接 + 转角。
	for x in range(2, 6):
		level.paint_terrain(x, 6, "wall")
	check(int(level.get_tile(3, 6)["mask"]) == 10, "石墙中段 mask=10（东+西）")
	check(int(level.get_tile(2, 6)["mask"]) == 2, "石墙端点 mask=2（东）")
	level.paint_terrain(5, 7, "wall")
	check(int(level.get_tile(5, 6)["mask"]) == 12, "石墙转角 mask=12（南+西）")

	# 水岸：非水邻居产生外露位。
	level.paint_terrain(8, 2, "water")
	level.paint_terrain(9, 2, "water")
	check(int(level.get_tile(8, 2)["mask"]) == 2, "水面相邻 mask=2（东）")
	check(int(level.get_tile(9, 2)["mask"]) == 8, "水面相邻 mask=8（西）")


func _test_shapes() -> void:
	var rect: Array = LevelDataScript.rect_cells(Vector2i(1, 1), Vector2i(3, 2))
	check(rect.size() == 6, "矩形填充覆盖 3×2=6 格")
	check(rect.has(Vector2i(1, 1)) and rect.has(Vector2i(3, 2)), "矩形包含首尾角")
	var diagonal: Array = LevelDataScript.line_cells(Vector2i(1, 1), Vector2i(4, 3))
	check(diagonal.size() == 4, "直线 Bresenham 格数")
	check(diagonal[0] == Vector2i(1, 1) and diagonal[diagonal.size() - 1] == Vector2i(4, 3), "直线端点")
	var vertical: Array = LevelDataScript.line_cells(Vector2i(5, 1), Vector2i(5, 5))
	check(vertical.size() == 5, "竖直直线 5 格")


func _test_entities_and_schema() -> void:
	var level := LevelDataScript.new(12, 8, 16, "实体")
	var spawn := level.add_entity("spawn", 2, 2, {"facing": "left"})
	check(not spawn.is_empty(), "添加出生点")
	var enemy := level.add_entity("enemy", 5, 4, {"kind": "夜蛾", "hp": 77, "damage": 9, "facing": "up", "patrol": 5})
	check(String(enemy["props"]["kind"]) == "夜蛾" and int(enemy["props"]["hp"]) == 77, "敌人属性")
	var chest := level.add_entity("chest", 8, 6, {"loot": "钥匙", "amount": 3})
	check(String(chest["props"]["loot"]) == "钥匙" and int(chest["props"]["amount"]) == 3, "宝箱掉落属性")
	check(level.entity_at(5, 4)["id"] == enemy["id"], "格子查询实体")
	check(level.move_entity(String(enemy["id"]), 6, 4), "移动实体")
	check(level.entity_at(6, 4)["id"] == enemy["id"], "移动后查询")
	check(not level.move_entity(String(enemy["id"]), 99, 99), "越界移动被拒绝")

	var dict := level.to_dict()
	var required := ["format", "version", "name", "width", "height", "cell_size", "tiles", "collision", "entities", "layers"]
	for key in required:
		check(dict.has(key), "schema 根字段 " + key)
	check(String(dict["format"]) == "mossgarden.level", "format 标识")
	check(int(dict["version"]) == 1, "schema version")
	check(dict["entities"].size() == 3, "entities 数量")
	var enemy_dict: Dictionary = {}
	for entity in dict["entities"]:
		if String(entity["type"]) == "enemy":
			enemy_dict = entity
	check(not enemy_dict.is_empty(), "entities 含敌人")
	check(int(enemy_dict["props"]["hp"]) == 77, "JSON 保留 HP")
	var runtime := level.to_runtime_dict()
	check(String(runtime["format"]) == "mossgarden.level.runtime", "运行时 format")
	check(not runtime.has("layers"), "运行时 JSON 不含图层 UI 元数据")
	var parsed = JSON.parse_string(level.to_json(true, false))
	check(parsed is Dictionary, "运行时 JSON 可 parse")
	check(parsed["tiles"].size() == 8, "运行时 tiles 行数")

	var bad := LevelDataScript.new(2, 2, 16, "坏")
	var errors := bad.from_json("{\"format\":\"nope\"}")
	check(not errors.is_empty(), "非法 format 被拒绝")
	var broken: Dictionary = level.to_dict()
	broken["tiles"][0][0] = {"type": "lava", "variant": -1, "mask": 0}
	var errors2 := bad.from_dict(broken)
	check(not errors2.is_empty(), "非法瓦片类型被拒绝")
	var broken2: Dictionary = level.to_dict()
	broken2["collision"] = [[2, 2]]
	var errors3 := bad.from_dict(broken2)
	check(not errors3.is_empty(), "非法 collision 维度被拒绝")
	check(bad.from_json(level.to_json(false, true)).is_empty(), "完整 JSON 通过 schema")
	check(level.validate()["ok"], "合法关卡校验通过")
	check(level.remove_entity(String(chest["id"])), "删除实体")
	check(level.entity_count("chest") == 0, "删除后计数")


func _test_roundtrip() -> void:
	var level := LevelDataScript.build_demo()
	var text := level.to_json(false, true)
	var restored := LevelDataScript.new(1, 1, 16)
	var errors := restored.from_json(text)
	check(errors.is_empty(), "保存→加载 JSON 无错误")
	check(restored.width == level.width and restored.height == level.height, "roundtrip 尺寸")
	check(restored.cell_size == level.cell_size, "roundtrip 格子尺寸")
	check(restored.filled_tile_count() == level.filled_tile_count(), "roundtrip 地块数量")
	check(restored.collision_count() == level.collision_count(), "roundtrip 碰撞数量")
	check(restored.entities.size() == level.entities.size(), "roundtrip 实体数量")
	var original_enemy: Dictionary = level.entities[1]
	var loaded_enemy: Dictionary = restored.entities[1]
	check(String(original_enemy["props"]["kind"]) == String(loaded_enemy["props"]["kind"]), "roundtrip 敌人类型")
	check(int(original_enemy["props"]["hp"]) == int(loaded_enemy["props"]["hp"]), "roundtrip HP")
	var spawn_cell := Vector2i(int(level.spawn_entity()["x"]), int(level.spawn_entity()["y"]))
	var original_tile := level.get_tile(spawn_cell.x, spawn_cell.y)
	var loaded_tile := restored.get_tile(spawn_cell.x, spawn_cell.y)
	if original_tile.is_empty():
		check(loaded_tile.is_empty(), "roundtrip 出生点格为空")
	else:
		check(int(original_tile["mask"]) == int(loaded_tile["mask"]), "roundtrip 掩码")
	check(restored.to_json(false, false) == level.to_json(false, false), "二次序列化完全一致")


func _test_preview() -> void:
	var level := LevelDataScript.new(12, 8, 16, "预览烟测")
	for y in 8:
		for x in 12:
			level.paint_terrain(x, y, "grass", -1, false)
	level.paint_collision(5, 5, true)
	level.paint_terrain(7, 5, "wall", -1, false)
	level.paint_terrain(8, 5, "water", -1, false)
	level.add_entity("spawn", 3, 5, {"facing": "right"})
	level.add_entity("chest", 4, 5, {"loot": "金币", "amount": 40})
	level.recalculate_autotiles(true)

	var preview = preload("res://scripts/level_preview.gd").new()
	preview.size = Vector2(640, 360)
	root.add_child(preview)
	await process_frame
	var result: Dictionary = preview.load_json(level.to_json(true, true))
	check(bool(result.get("ok", false)), "预览加载运行时 JSON")
	check(preview.player_cell() == Vector2i(3, 5), "预览玩家从出生点开始")
	var before_cell: Vector2i = preview.player_cell()
	var moved: bool = preview.try_move(Vector2(level.cell_size, 0))
	check(moved and preview.player_cell() != before_cell, "预览玩家可移动")
	preview.try_pickups()
	check(preview.collected_order.size() == 1, "预览宝箱可拾取")
	check(String(preview.last_pickup).contains("金币"), "预览拾取显示掉落")
	var chest_cell: Vector2i = preview.player_cell()
	var blocked_move: bool = preview.try_move(Vector2(level.cell_size, 0))
	check(not blocked_move, "预览碰撞格阻挡移动")
	check(preview.player_cell() == chest_cell, "阻挡后位置不变")

	var broken: Dictionary = preview.load_json("{ not json")
	check(not bool(broken.get("ok", true)), "预览拒绝坏 JSON")
	var broken_schema: Dictionary = preview.load_json(level.to_json(false, true).replace("\"format\": \"mossgarden.level\"", "\"format\": \"bad\""))
	check(not bool(broken_schema.get("ok", true)), "预览拒绝错误 schema")
	preview.queue_free()
	await process_frame


func _test_editor_ui_and_tools() -> void:
	_editor = EditorScene.instantiate()
	root.add_child(_editor)
	await process_frame
	await process_frame
	check(_editor.data != null, "编辑器启动并载入数据")
	check(_editor.canvas != null and _editor.canvas.size.x > 100, "画布已布局")
	check(_editor._props_box != null, "属性面板已构建")

	var clean := LevelDataScript.new(12, 8, 16, "输入烟测")
	_editor.set_level(clean)
	await process_frame
	check(_editor.data.width == 12, "测试关卡载入编辑器")

	_editor.layer_id = "terrain"
	_editor.tool = "brush"
	_editor.paint_type = "grass"
	_editor.paint_variant = -1
	_editor.auto_tiles = true
	var canvas = _editor.canvas

	# 画笔拖拽：从 (2,2) 拖到 (4,2)
	_click(canvas, Vector2i(2, 2), true)
	_move(canvas, Vector2i(4, 2))
	_click(canvas, Vector2i(4, 2), false)
	check(not _editor.data.get_tile(2, 2).is_empty(), "画布画笔落下第一格")
	check(not _editor.data.get_tile(3, 2).is_empty(), "拖拽补间不丢格")
	check(not _editor.data.get_tile(4, 2).is_empty(), "画布画笔落下末格")
	check(_editor.get_undo_count() == 1, "一次拖拽只产生一个撤销记录")

	# 橡皮 + 撤销/重做
	_editor.tool = "eraser"
	_click(canvas, Vector2i(3, 2), true)
	_click(canvas, Vector2i(3, 2), false)
	check(_editor.data.get_tile(3, 2).is_empty(), "画布橡皮擦除")
	check(_editor.get_undo_count() == 2, "橡皮产生撤销记录")
	_editor.undo()
	check(not _editor.data.get_tile(3, 2).is_empty(), "撤销恢复橡皮")
	check(_editor.get_redo_count() == 1, "撤销进入重做栈")
	_editor.redo()
	check(_editor.data.get_tile(3, 2).is_empty(), "重做再次擦除")
	_editor.undo()
	check(not _editor.data.get_tile(3, 2).is_empty(), "再次撤销恢复")

	# 矩形 3×3
	_editor.tool = "rect"
	_click(canvas, Vector2i(1, 1), true)
	_click(canvas, Vector2i(3, 3), false)
	var rect_ok := true
	for y in range(1, 4):
		for x in range(1, 4):
			if _editor.data.get_tile(x, y).is_empty():
				rect_ok = false
	check(rect_ok, "矩形工具填充 3×3")

	# 直线 y=5，从 x=1 到 x=5
	_editor.tool = "line"
	_click(canvas, Vector2i(1, 5), true)
	_click(canvas, Vector2i(5, 5), false)
	var line_ok := true
	for x in range(1, 6):
		if _editor.data.get_tile(x, 5).is_empty():
			line_ok = false
	check(line_ok, "直线工具绘制 5 格")

	# 自动铺砖在真实输入路径上更新邻居
	check(int(_editor.data.get_tile(2, 2)["mask"]) > 0, "真实画笔路径自动掩码已计算")

	# 取色：先放水，再拾取水
	_editor.data.paint_terrain(8, 1, "water", 1, true)
	_editor.tool = "picker"
	_click(canvas, Vector2i(8, 1), true)
	_click(canvas, Vector2i(8, 1), false)
	check(_editor.paint_type == "water" and _editor.paint_variant == 1, "取色拾取类型与手动变体")
	check(_editor.tool == "brush", "取色后切回画笔")

	# 实体放置 + 属性面板 + 修改 + 移动 + 删除
	_editor.layer_id = "entities"
	_editor.tool = "brush"
	_editor.entity_type = "enemy"
	_click(canvas, Vector2i(7, 6), true)
	_click(canvas, Vector2i(7, 6), false)
	check(_editor.data.entity_at(7, 6).size() > 0, "实体层放置敌人")
	check(_editor.selected_entity_id != "", "放置后自动选中实体")
	check(_editor._props_box.get_child_count() > 4, "实体属性面板已生成")
	var enemy_id: String = _editor.selected_entity_id
	_editor._on_entity_prop_number(77.0, "hp")
	check(int(_editor.data.entity_by_id(enemy_id)["props"]["hp"]) == 77, "属性面板写回 HP")
	_editor._on_entity_prop_option(1, "facing", LevelDataScript.FACING_VALUES)
	check(String(_editor.data.entity_by_id(enemy_id)["props"]["facing"]) == "left", "属性面板写回朝向")
	_editor._on_entity_position_changed(6.0, "x")
	check(int(_editor.data.entity_by_id(enemy_id)["x"]) == 6, "属性面板移动实体")
	_editor._delete_selected_entity()
	check(_editor.data.entity_by_id(enemy_id).is_empty(), "属性面板删除实体")
	check(_editor.selected_entity_id == "", "删除后清空选中")

	# 保存 / 加载 roundtrip 走编辑器真实接口
	var path := "user://smoke_level.json"
	_editor.data.add_entity("spawn", 2, 6, {"facing": "up"})
	_editor.data.add_entity("chest", 9, 3, {"loot": "药水", "amount": 2})
	_editor.data.level_name = "烟测存档"
	check(_editor.save_to_path(path), "编辑器保存 JSON")
	check(FileAccess.file_exists(path), "保存文件存在")
	var saved_text := FileAccess.get_file_as_string(path)
	var saved_level := LevelDataScript.new(1, 1, 16)
	check(saved_level.from_json(saved_text).is_empty(), "保存文件 schema 合法")
	check(saved_level.entities.size() == 2, "保存文件实体数量")
	_editor._on_clear_pressed()
	check(_editor.data.entities.is_empty(), "清空关卡")
	_editor.undo()
	check(_editor.data.entities.size() == 2, "撤销清空")
	check(_editor.load_from_path(path), "编辑器加载 JSON")
	check(_editor.data.entities.size() == 2, "加载后实体恢复")
	check(_editor.data.level_name == "烟测存档", "加载后关卡名恢复")

	# 导出运行时 JSON
	var export_path := "user://smoke_export.json"
	var exported: String = _editor.export_to_path(export_path, false)
	check(exported != "", "导出运行时 JSON")
	check(FileAccess.file_exists(export_path), "导出文件存在")
	var parsed_runtime = JSON.parse_string(exported)
	check(parsed_runtime is Dictionary and String(parsed_runtime["format"]) == "mossgarden.level.runtime", "导出格式正确")

	# 运行预览
	_editor.open_preview()
	await process_frame
	check(_editor._preview_overlay.visible, "预览覆盖层打开")
	check(_editor.preview.level != null, "预览从当前 JSON 建图")
	_editor.preview.try_move(Vector2(16, 0))
	check(_editor.preview.player_pos != Vector2.ZERO, "预览玩家存在")
	_editor.close_preview()
	check(not _editor._preview_overlay.visible, "预览可返回编辑")

	# 图层锁与隐藏状态、地图尺寸、格子大小
	var layers_before: int = _editor.get_undo_count()
	_editor._on_layer_visible_pressed("collision")
	check(not _editor.is_layer_visible("collision"), "图层隐藏")
	_editor._on_layer_visible_pressed("collision")
	_editor._on_layer_lock_pressed("terrain")
	check(_editor.is_layer_locked("terrain"), "图层锁定")
	_editor._on_layer_lock_pressed("terrain")
	_editor._on_cell_size_selected(1)
	check(_editor.data.cell_size == 32, "格子大小切换为 32")
	check(_editor.get_undo_count() > layers_before, "格子大小可撤销")
	_editor._on_map_size_changed(0.0) # SpinBox 值未变，不应改变
	var before_w: int = _editor.data.width
	_editor._map_width_spin.value = 14
	check(_editor.data.width == 14, "地图宽度调整")
	_editor.undo()
	check(_editor.data.width == before_w, "撤销地图尺寸")

	# 手动覆盖与重算按钮路径
	_editor.tool = "brush"
	_editor.layer_id = "terrain"
	_editor.paint_type = "grass"
	_editor._on_variant_selected(3)
	check(_editor.paint_variant == 2, "调色板变体选择")
	_editor._on_clear_overrides_pressed()
	check(_editor.data.manual_variant_count() == 0, "清除全部手动覆盖")

	_editor.queue_free()
	await process_frame


func _click(canvas: Control, cell: Vector2i, pressed: bool) -> void:
	var pos: Vector2 = canvas.cell_center_local(cell)
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	canvas._gui_input(event)


func _move(canvas: Control, cell: Vector2i) -> void:
	var pos: Vector2 = canvas.cell_center_local(cell)
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	canvas._gui_input(event)
