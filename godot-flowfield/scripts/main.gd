extends Node2D

# 入口：布局、鼠标编辑、快捷键、UI 接线。
# 逻辑分辨率 1280×720；1920×1080 截图通过窗口拉伸渲染（canvas_items）。

const PLAY_RECT := Rect2(28, 96, 884, 596)

@onready var sim = $Sim
@onready var view = $View
@onready var ui = $UI

var view_mode := "flow"
var tool := "goal"

var _drag_active := false
var _drag_mode := ""
var _drag_button := 0
var _last_cell := Vector2i(-1, -1)


func _ready() -> void:
	get_window().title = "流场寻路 · Flow Field | 群体寻路可视化"
	sim.setup(PLAY_RECT, "medium", 421)
	view.bind(sim)
	view.set_show("grid", true)
	view.set_show("numbers", false)
	view.set_show("arrows", true)
	view.set_show("agents", true)
	view.set_show("trails", true)
	set_view_mode("flow")
	set_tool("goal")
	ui.bind(self, sim, view)
	ui.refresh()


func _process(_delta: float) -> void:
	if sim == null:
		return
	var mouse := get_global_mouse_position()
	var rect: Rect2 = view.grid_rect()
	var inside := rect.has_point(mouse)
	if inside:
		var cell: Vector2i = sim.field.world_to_cell(mouse)
		view.set_hover(cell, true, tool)
	elif not _drag_active:
		view.set_hover(Vector2i(-1, -1), false, tool)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var pos := get_global_mouse_position()
				if view.grid_rect().has_point(pos):
					_drag_active = true
					_drag_button = MOUSE_BUTTON_LEFT
					_drag_mode = "goal" if tool == "goal" else tool
					_last_cell = sim.field.world_to_cell(pos)
					_begin_stroke(pos)
					get_viewport().set_input_as_handled()
			else:
				_end_stroke()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var pos := get_global_mouse_position()
			if view.grid_rect().has_point(pos):
				if tool == "add_goal":
					if sim.remove_goal_near(pos):
						ui.notify("已移除最近目标")
					else:
						ui.notify("附近没有可移除的目标")
				else:
					if sim.set_goal_world(pos):
						ui.notify("快速设目标 · 重建 %.2f ms" % sim.build_ms())
					else:
						ui.notify("目标必须落在可行走格")
				ui.refresh()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _drag_active and _drag_button == MOUSE_BUTTON_LEFT:
			_continue_stroke(get_global_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				toggle_pause()
			KEY_R:
				reset_sim()
			KEY_G:
				random_map()
			KEY_C:
				clear_obstacles()
			KEY_1:
				set_view_mode("cost")
			KEY_2:
				set_view_mode("integration")
			KEY_3:
				set_view_mode("flow")
			KEY_H:
				ui.visible = not ui.visible
			_:
				return
		get_viewport().set_input_as_handled()


func _begin_stroke(pos: Vector2) -> void:
	var cell: Vector2i = sim.field.world_to_cell(pos)
	match _drag_mode:
		"goal":
			if Input.is_key_pressed(KEY_SHIFT):
				if sim.add_goal_world(pos):
					ui.notify("已添加目标（Shift+左键）")
				_drag_active = false
			else:
				if sim.set_goal_world(pos):
					ui.notify("放置目标 · 拖拽可移动")
		"add_goal":
			if sim.add_goal_world(pos):
				ui.notify("已添加目标 · 共 %d 个" % sim.field.goals.size())
			else:
				ui.notify("该处已有目标或已达上限（8 个）")
			_drag_active = false
		"obstacle":
			if sim.apply_brush(cell, "obstacle"):
				ui.notify("绘制障碍 · 流场实时重建")
		"erase":
			if not sim.apply_brush(cell, "erase"):
				ui.notify("该格已是可行走平地")
	ui.refresh()


func _continue_stroke(pos: Vector2) -> void:
	if not view.grid_rect().has_point(pos):
		return
	var cell: Vector2i = sim.field.world_to_cell(pos)
	if cell == _last_cell:
		return
	match _drag_mode:
		"goal":
			if sim.set_goal_world(pos):
				_last_cell = cell
		"obstacle":
			sim.apply_brush_line(_last_cell, cell, "obstacle")
			_last_cell = cell
		"erase":
			sim.apply_brush_line(_last_cell, cell, "erase")
			_last_cell = cell


func _end_stroke() -> void:
	if not _drag_active:
		return
	_drag_active = false
	_drag_button = 0
	if _drag_mode == "goal" or _drag_mode == "obstacle" or _drag_mode == "erase":
		ui.notify("重建完成 · %.2f ms · 可达 %d/%d" % [
			sim.build_ms(), sim.field.reachable_cells, sim.field.open_cells])
	_drag_mode = ""
	ui.refresh()


# UI / 工具 API -----------------------------------------------------------

func set_view_mode(mode: String) -> void:
	view_mode = mode
	view.set_view_mode(mode)
	match mode:
		"cost":
			view.set_show("numbers", true)
			view.set_show("arrows", false)
		"integration":
			view.set_show("numbers", true)
			view.set_show("arrows", false)
		"flow":
			view.set_show("numbers", false)
			view.set_show("arrows", true)
	ui.refresh()


func set_show(key: String, value: bool) -> void:
	view.set_show(key, value)


func set_tool(key: String) -> void:
	tool = key
	ui.refresh()


func set_agent_count(count: int) -> void:
	sim.set_agent_count(count)
	ui.notify("智能体数量 %d · 固定 30Hz 逻辑" % count)
	ui.refresh()


func set_map_size(key: String) -> void:
	sim.set_map_size(key)
	ui.notify("地图 %d × %d" % [sim.field.cols, sim.field.rows])
	ui.refresh()


func load_sample_map() -> void:
	sim.load_sample(sim.map_key)
	ui.notify("样例地图：C 形回廊 · %d × %d" % [sim.field.cols, sim.field.rows])
	ui.refresh()


func random_map() -> void:
	sim.reload_random()
	ui.notify("随机地图 · 种子 %d" % sim.seed)
	ui.refresh()


func clear_obstacles() -> void:
	if sim.clear_obstacles():
		ui.notify("已清空障碍 · 流场重建 %.2f ms" % sim.build_ms())
	else:
		ui.notify("当前没有障碍")
	ui.refresh()


func toggle_pause() -> void:
	sim.set_paused(not sim.paused)
	ui.refresh()


func reset_sim() -> void:
	sim.reset()
	ui.notify("已重置：同种子重新播撒 %d 个智能体" % sim.agent_count)
	ui.refresh()


# 截图 / 录制工具 API -----------------------------------------------------

func set_manual_capture(value: bool) -> void:
	sim.set_manual_capture(value)
	ui.set_recording(value)
	ui.refresh()


func advance_logic(dt: float) -> void:
	sim.step_fixed(dt)


func set_recording(value: bool) -> void:
	ui.set_recording(value)
