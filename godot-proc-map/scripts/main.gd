extends Control

# 主控：统一查看器。算法切换、固定种子、分阶段生成、单步/连续/速度、
# 调试叠加、统计/FPS、相机与工具 API。

const GenDungeon = preload("res://scripts/gen_dungeon.gd")
const GenBiome = preload("res://scripts/gen_biome.gd")
const MapViewScript = preload("res://scripts/map_view.gd")
const HudScript = preload("res://scripts/hud.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Utils = preload("res://scripts/gen_utils.gd")

const SIZE_OPTIONS := {
	"dungeon": [
		{"label": "64 × 48 · 标准", "w": 64, "h": 48},
		{"label": "80 × 60 · 压力", "w": 80, "h": 60},
	],
	"biome": [
		{"label": "96 × 64 · 标准", "w": 96, "h": 64},
		{"label": "112 × 72 · 大图", "w": 112, "h": 72},
	],
}
const DEFAULT_SEED := {"dungeon": "2137", "biome": "9001"}
const DEFAULT_SIZE := {"dungeon": 0, "biome": 0}
const DEFAULT_PARAM := {"dungeon": 12.0, "biome": 0.0}
const DEFAULT_SPEED := 2.0

var _mode := "biome"
var _seed_text := "9001"
var _size_index := 0
var _param_ui := 0.0
var _speed := DEFAULT_SPEED
var _paused := false
var _gen = null
var _stage := -1
var _stage_count := 0
var _finished := false
var _apply_ms := 0.0
var _stage_accum := 0.0
var _hud_accum := 0.0
var _ui_scale := 1.0
var _debug := {"connectivity": false, "rooms": false, "biomes": false,
	"noise": false, "bounds": false}
var _noise_field := "elevation"
var _sig_history: Dictionary = {}
var _pending_sig := ""
var _sig_match := false
var _signature := ""
var _last_key := ""
var _syncing_ui := false
var _started := false

var view = null
var hud = null
var _backdrop: Control
var _main_margin: MarginContainer
var _page: VBoxContainer
var _topbar: HBoxContainer
var _content: HBoxContainer
var _right_column: VBoxContainer
var _map_frame: PanelContainer
var _footer: PanelContainer
var _stage_label: Label
var _hover_label: Label
var _seed_sig_label: Label
var _mode_buttons: Dictionary = {}
var _mode_group: ButtonGroup
var _top_status: Label
var _hud_visible := true
var _capture_mode := false


func _ready() -> void:
	var viewport_size := get_viewport_rect().size
	var layout_size := size
	if layout_size.x < 10.0 or layout_size.y < 10.0:
		layout_size = viewport_size
	_ui_scale = clampf(minf(layout_size.x / 1280.0, layout_size.y / 720.0), 0.78, 2.0)
	theme = UiTheme.make_theme(_ui_scale)
	_mode = "biome"
	_seed_text = DEFAULT_SEED[_mode]
	_size_index = DEFAULT_SIZE[_mode]
	_param_ui = DEFAULT_PARAM[_mode]
	_build_layout()
	_configure_hud_mode()
	_start_generation(false, true)
	_started = true
	set_process(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _backdrop != null:
		_backdrop.queue_redraw()


func _process(delta: float) -> void:
	if _gen != null and not _paused and not _finished:
		_stage_accum += delta * _speed
		var steps := 0
		while _stage_accum >= 1.0 and not _finished and steps < 2:
			_stage_accum -= 1.0
			_advance_stage()
			steps += 1
	_hud_accum += delta
	if _hud_accum >= 0.14:
		_hud_accum = 0.0
		_refresh_ui()


# ---------------------------------------------------------------------------
# 布局
# ---------------------------------------------------------------------------

func _build_layout() -> void:
	_backdrop = Control.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_backdrop.draw.connect(_draw_backdrop.bind(_backdrop))

	_main_margin = MarginContainer.new()
	_main_margin.name = "MainMargin"
	_main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := int(round(16.0 * _ui_scale))
	_main_margin.add_theme_constant_override("margin_left", margin)
	_main_margin.add_theme_constant_override("margin_right", margin)
	_main_margin.add_theme_constant_override("margin_top", margin)
	_main_margin.add_theme_constant_override("margin_bottom", margin)
	add_child(_main_margin)

	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", int(round(9.0 * _ui_scale)))
	_main_margin.add_child(_page)

	_topbar = HBoxContainer.new()
	_topbar.custom_minimum_size = Vector2(0.0, 48.0 * _ui_scale)
	_topbar.add_theme_constant_override("separation", int(round(14.0 * _ui_scale)))
	_page.add_child(_topbar)
	_build_topbar()

	_content = HBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", int(round(12.0 * _ui_scale)))
	_page.add_child(_content)

	hud = HudScript.new()
	hud.name = "HUD"
	hud.custom_minimum_size = Vector2(306.0 * _ui_scale, 0.0)
	hud.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(hud)
	hud.setup(self, _ui_scale)

	_right_column = VBoxContainer.new()
	_right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_column.add_theme_constant_override("separation", int(round(7.0 * _ui_scale)))
	_content.add_child(_right_column)

	_map_frame = PanelContainer.new()
	_map_frame.name = "MapFrame"
	_map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_frame.add_theme_stylebox_override("panel", UiTheme.map_panel_style(_ui_scale))
	_right_column.add_child(_map_frame)

	view = MapViewScript.new()
	view.name = "MapView"
	_map_frame.add_child(view)
	view.setup()
	view.hover_changed.connect(_on_hover_changed)

	_footer = PanelContainer.new()
	_footer.custom_minimum_size = Vector2(0.0, 28.0 * _ui_scale)
	_footer.add_theme_stylebox_override("panel", UiTheme.panel_style(
		Color(0.06, 0.10, 0.105, 0.9), Color(0.25, 0.36, 0.34, 0.7), _ui_scale, 5.0))
	var pad := int(round(7.0 * _ui_scale))
	_footer.add_theme_constant_override("margin_left", pad)
	_footer.add_theme_constant_override("margin_right", pad)
	_right_column.add_child(_footer)
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", int(round(12.0 * _ui_scale)))
	_footer.add_child(footer_row)
	_stage_label = UiTheme.make_label("准备生成", 10.0, UiTheme.MINT, _ui_scale)
	_stage_label.custom_minimum_size = Vector2(150.0 * _ui_scale, 0.0)
	footer_row.add_child(_stage_label)
	_hover_label = UiTheme.make_label("悬停地图查看地块 · 左键拖动 / 滚轮缩放 / 双击复位",
			10.0, Color(0.68, 0.79, 0.73, 0.95), _ui_scale)
	_hover_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hover_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer_row.add_child(_hover_label)
	_seed_sig_label = UiTheme.make_label("SEED — · SIG —", 9.5, UiTheme.AMBER, _ui_scale)
	_seed_sig_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer_row.add_child(_seed_sig_label)


func _build_topbar() -> void:
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	_topbar.add_child(title_box)
	var title := UiTheme.make_label("边境制图台", 21.0, Color(0.94, 0.89, 0.75, 1), _ui_scale)
	title_box.add_child(title)
	var subtitle := UiTheme.make_label("程序化地图实验 · BSP 地牢 × 噪声群岛", 9.5,
			Color(0.60, 0.73, 0.67, 0.95), _ui_scale)
	title_box.add_child(subtitle)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topbar.add_child(spacer)

	_mode_group = ButtonGroup.new()
	var modes := [["dungeon", "地牢 · BSP", "切分→房间→走廊→连通→装饰"],
		["biome", "群岛 · 噪声", "海拔/湿度/温度→群系→河流→植被→地标"]]
	for entry in modes:
		var button := Button.new()
		button.text = entry[1]
		button.tooltip_text = entry[2]
		button.toggle_mode = true
		button.button_group = _mode_group
		button.custom_minimum_size = Vector2(132.0 * _ui_scale, 34.0 * _ui_scale)
		button.add_theme_font_size_override("font_size", int(round(11.5 * _ui_scale)))
		button.focus_mode = Control.FOCUS_NONE
		UiTheme.style_segmented(button, _ui_scale)
		button.pressed.connect(_on_mode_pressed.bind(entry[0]))
		_topbar.add_child(button)
		_mode_buttons[entry[0]] = button
	_mode_buttons[_mode].button_pressed = true

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8.0 * _ui_scale, 0.0)
	_topbar.add_child(gap)
	_top_status = UiTheme.make_label("固定种子 · 6 子流 · 分阶段", 9.5,
			Color(0.64, 0.76, 0.70, 0.9), _ui_scale)
	_top_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_topbar.add_child(_top_status)


func _draw_backdrop(canvas: CanvasItem) -> void:
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		w = get_viewport_rect().size.x
		h = get_viewport_rect().size.y
	var top := Color("#0d1a1c")
	var bottom := Color("#070d0f")
	var bands := 28
	for i in bands:
		var t := float(i) / float(bands - 1)
		var color := top.lerp(bottom, t)
		canvas.draw_rect(Rect2(0, h * i / bands, w, h / bands + 1.0), color, true)
	var step := 96.0 * _ui_scale
	var line := Color(0.35, 0.48, 0.44, 0.035)
	for x in range(0, int(w) + 1, int(step)):
		canvas.draw_line(Vector2(x, 0), Vector2(x, h), line, 1.0)
	for y in range(0, int(h) + 1, int(step)):
		canvas.draw_line(Vector2(0, y), Vector2(w, y), line, 1.0)
	canvas.draw_circle(Vector2(w * 0.86, h * 0.10), 240.0 * _ui_scale,
			Color(0.16, 0.28, 0.25, 0.08))


# ---------------------------------------------------------------------------
# 生成调度
# ---------------------------------------------------------------------------

func _start_generation(auto_run: bool, keep_param := true) -> void:
	var options: Array = SIZE_OPTIONS[_mode]
	_size_index = clampi(_size_index, 0, options.size() - 1)
	if not keep_param:
		_param_ui = DEFAULT_PARAM[_mode]
	var option: Dictionary = options[_size_index]
	var w := int(option["w"])
	var h := int(option["h"])
	var param_quant := int(round(_param_ui))
	_last_key = "%s|%s|%d|%d" % [_mode, _seed_text, _size_index, param_quant]
	_pending_sig = String(_sig_history.get(_last_key, ""))
	_sig_match = false
	_signature = ""
	_apply_ms = 0.0
	_stage_accum = 0.0
	_hud_accum = 0.0
	_stage = -1
	_finished = false
	_paused = not auto_run
	if _mode == "dungeon":
		var gen_d := GenDungeon.new()
		gen_d.setup(_seed_text, w, h, _param_ui / 100.0)
		_gen = gen_d
	else:
		var gen_b := GenBiome.new()
		gen_b.setup(_seed_text, w, h, _param_ui / 100.0)
		_gen = gen_b
	_stage_count = _gen.get_stage_count()
	view.prepare(_mode, _gen, _stage_count)
	view.set_debug(_debug, _noise_field)
	view.set_stage_caption("准备")
	_advance_stage()
	_configure_hud_mode()
	_refresh_ui(true)


func _advance_stage() -> void:
	if _gen == null or _finished:
		return
	var next := _stage + 1
	if next >= _stage_count:
		_finish_generation_internal()
		return
	_gen.run_stage(next)
	_stage = next
	var view_start := Time.get_ticks_usec()
	view.set_stage_caption("%d/%d · %s" % [_stage + 1, _stage_count,
			_gen.get_stage_label(_stage)])
	view.apply(_gen, _stage, _stage == _stage_count - 1)
	_apply_ms += float(Time.get_ticks_usec() - view_start) / 1000.0
	if _stage == _stage_count - 1:
		_finish_generation_internal()
	_refresh_ui(true)


func _finish_generation_internal() -> void:
	if _gen == null:
		return
	_finished = true
	_signature = _gen.get_signature()
	_sig_match = _pending_sig != "" and _pending_sig == _signature
	_sig_history[_last_key] = _signature
	_paused = false
	_refresh_ui(true)


func _refresh_ui(force := false) -> void:
	if hud == null or _gen == null:
		return
	var stats: Dictionary = _gen.get_stats()
	var stage_name: String = "完成" if _finished else _gen.get_stage_label(maxi(0, _stage))
	var state := {
		"mode": _mode,
		"seed_text": _seed_text,
		"size_index": _size_index,
		"sizes": _size_labels(),
		"param": _param_config(),
		"speed": _speed,
		"paused": _paused,
		"finished": _finished,
		"stage_index": _stage,
		"stage_count": _stage_count,
		"stage_name": stage_name,
		"fps": Engine.get_frames_per_second(),
		"capture_mode": _capture_mode,
		"debug": _debug,
		"noise_field": _noise_field,
		"signature": _signature if _signature != "" else "—",
		"sig_match": _sig_match,
		"streams_text": _streams_text(),
		"scale_text": _scale_text(stats),
		"connect_text": _connect_text(stats),
		"detail_text": _detail_text(stats),
		"life_text": _life_text(stats),
		"time_text": _time_text(stats),
	}
	hud.refresh(state)
	_stage_label.text = "阶段 %d/%d · %s" % [clampi(_stage + 1, 1, _stage_count),
			_stage_count, stage_name]
	if _finished:
		_stage_label.text = "生成完成 · %d 阶段 · %s" % [_stage_count,
				"签名一致 ✓" if _sig_match else "新签名"]
	_seed_sig_label.text = "SEED %s · SIG %s" % [_seed_text,
			_signature if _signature != "" else "—"]
	_top_status.text = "%s · %d 子流 · %s" % [
		"固定种子" if _finished else ("生成中" if not _paused else "已暂停"),
		_gen.get_streams().size(),
		"同签名 ✓" if _sig_match else "分阶段可复现"]
	for key in _mode_buttons:
		_mode_buttons[key].button_pressed = key == _mode


func _configure_hud_mode() -> void:
	if hud == null:
		return
	hud.configure_mode({
		"mode": _mode,
		"size_index": _size_index,
		"sizes": _size_labels(),
		"param": _param_config(),
	})


func _size_labels() -> Array:
	var labels: Array = []
	for option in SIZE_OPTIONS[_mode]:
		labels.append(String(option["label"]))
	return labels


func _param_config() -> Dictionary:
	if _mode == "dungeon":
		return {"label": "环路", "min": 0.0, "max": 30.0, "step": 1.0,
			"value": _param_ui, "text": "%d%%" % int(round(_param_ui))}
	return {"label": "海平面", "min": -8.0, "max": 8.0, "step": 1.0,
		"value": _param_ui, "text": "%+.2f" % (_param_ui / 100.0)}


func _scale_text(stats: Dictionary) -> String:
	if _mode == "dungeon":
		return "%d×%d · %d 房间" % [_gen.width, _gen.height, int(stats.get("rooms", 0))]
	return "%d×%d · 陆地 %.0f%%" % [_gen.width, _gen.height,
			float(stats.get("land_pct", 0.0)) * 100.0]


func _connect_text(stats: Dictionary) -> String:
	if _mode == "dungeon":
		return "%.0f%% · %d 块" % [float(stats.get("reachable_pct", 0.0)),
				int(stats.get("component_count", 0))]
	return "最大陆块 %.0f%%" % float(stats.get("largest_land_pct", 0.0))


func _detail_text(stats: Dictionary) -> String:
	if _mode == "dungeon":
		return "走廊 %d 格 · 环路 %d" % [int(stats.get("corridor_cells", 0)),
				int(stats.get("loops", 0))]
	return "河流 %d · 入海 %d" % [int(stats.get("rivers", 0)),
			int(stats.get("rivers_to_sea", 0))]


func _life_text(stats: Dictionary) -> String:
	if _mode == "dungeon":
		return "火把 %d · 装饰 %d" % [int(stats.get("torches", 0)),
				int(stats.get("props", 0))]
	return "树 %d · POI %d · 区域 %d" % [int(stats.get("trees", 0)),
			int(stats.get("pois", 0)), int(stats.get("regions", 0))]


func _time_text(stats: Dictionary) -> String:
	var gen_ms := float(stats.get("total_ms", 0.0))
	return "%.1f ms · 应用 %.1f ms" % [gen_ms, _apply_ms]


func _streams_text() -> String:
	var streams: Dictionary = _gen.get_streams()
	var names: Array = streams.keys()
	var parts: Array[String] = []
	for key in names:
		parts.append("%s %s" % [String(key), Utils.fmt_seed(int(streams[key]))])
	var lines: Array[String] = []
	for i in range(0, parts.size(), 3):
		lines.append(" · ".join(parts.slice(i, mini(i + 3, parts.size()))))
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# UI 回调
# ---------------------------------------------------------------------------

func ui_generate(seed_text: String, size_index: int, param_value: float) -> void:
	var clean := seed_text.strip_edges()
	if clean.is_empty():
		clean = DEFAULT_SEED[_mode]
	_seed_text = clean
	_size_index = size_index
	_param_ui = param_value
	_start_generation(true)


func ui_randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_seed_text = str(rng.randi_range(1, 999999))
	_start_generation(true)


func ui_restart() -> void:
	_start_generation(true)


func ui_param_changed(value: float) -> void:
	_param_ui = value


func ui_apply_param() -> void:
	if _gen == null:
		return
	_start_generation(true)


func ui_toggle_pause() -> void:
	if _finished:
		return
	_paused = not _paused
	_refresh_ui(true)


func ui_step() -> void:
	if _finished:
		return
	_paused = true
	_advance_stage()
	_refresh_ui(true)


func ui_finish() -> void:
	if _finished:
		return
	_paused = true
	while not _finished:
		_advance_stage()
	_refresh_ui(true)


func ui_set_debug(key: String, pressed: bool) -> void:
	if not _debug.has(key):
		return
	_debug[key] = pressed
	view.set_debug(_debug, _noise_field)
	_refresh_ui(true)


func ui_set_noise_field(field: String) -> void:
	_noise_field = field
	view.set_debug(_debug, _noise_field)
	_refresh_ui(true)


func set_speed(value: float) -> void:
	_speed = clampf(value, 1.0, 8.0)


func _on_mode_pressed(mode: String) -> void:
	if _syncing_ui or mode == _mode:
		return
	_switch_mode(mode)


func _switch_mode(mode: String) -> void:
	if mode == _mode:
		return
	_mode = mode
	_size_index = DEFAULT_SIZE[_mode]
	_param_ui = DEFAULT_PARAM[_mode]
	_sig_match = false
	_pending_sig = ""
	_configure_hud_mode()
	for key in _mode_buttons:
		_mode_buttons[key].button_pressed = key == _mode
	_start_generation(true)


func _on_hover_changed(info: Dictionary) -> void:
	if info.is_empty():
		_hover_label.text = "悬停地图查看地块 · 左键拖动 / 滚轮缩放 / 双击复位"
		return
	var cell: Vector2i = info.get("cell", Vector2i(-1, -1))
	var prefix := "格 %d,%d · " % [cell.x, cell.y]
	if _mode == "dungeon":
		var text := prefix + "%s · 可达: %s · BFS 距离: %d" % [
			String(info.get("district", "—")),
			"是" if bool(info.get("reachable", false)) else "否",
			int(info.get("distance", -1))]
		_hover_label.text = text
	else:
		var text := prefix + "%s · 海拔 %.2f · 湿度 %.2f · 温度 %.2f" % [
			String(info.get("biome_name", "—")),
			float(info.get("elevation", 0.0)),
			float(info.get("moisture", 0.0)),
			float(info.get("temperature", 0.0))]
		if bool(info.get("river", false)):
			text += " · 河流"
		if info.has("poi_name"):
			text += " · " + String(info["poi_name"])
		_hover_label.text = text


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			ui_toggle_pause()
		KEY_S:
			ui_step()
		KEY_R:
			ui_restart()
		KEY_N:
			ui_randomize()
		KEY_F:
			ui_finish()
		KEY_H:
			_hud_visible = not _hud_visible
			hud.visible = _hud_visible
		KEY_C:
			ui_set_debug("connectivity", not _debug["connectivity"])
		KEY_M:
			ui_set_debug("rooms", not _debug["rooms"])
		KEY_B:
			ui_set_debug("biomes", not _debug["biomes"])
		KEY_V:
			ui_set_debug("noise", not _debug["noise"])
		KEY_O:
			ui_set_debug("bounds", not _debug["bounds"])
		KEY_1:
			_switch_mode("dungeon")
		KEY_2:
			_switch_mode("biome")
		KEY_ESCAPE:
			view.reset_camera()


# ---------------------------------------------------------------------------
# 工具 API（截图 / 视频 / 探针）
# ---------------------------------------------------------------------------

func api_new(mode: String, seed_text: String, size_index := 0, param_ui := 0.0,
		paused := true) -> void:
	_mode = mode
	_seed_text = seed_text
	_size_index = size_index
	_param_ui = param_ui
	_configure_hud_mode()
	_syncing_ui = true
	for key in _mode_buttons:
		_mode_buttons[key].button_pressed = key == _mode
	_syncing_ui = false
	_start_generation(not paused)


func api_step() -> void:
	ui_step()


func api_finish() -> void:
	ui_finish()


func api_set_debug(flags: Dictionary) -> void:
	for key in _debug:
		_debug[key] = bool(flags.get(key, false))
	view.set_debug(_debug, _noise_field)
	_refresh_ui(true)


func api_set_noise_field(field: String) -> void:
	ui_set_noise_field(field)


func api_get_view():
	return view


func api_get_gen():
	return _gen


func api_get_signature() -> String:
	return _signature


func api_debug_state() -> Dictionary:
	return _debug.duplicate()



func api_focus(world_pos: Vector2, zoom_multiplier := 1.0) -> void:
	view.focus_camera(world_pos, zoom_multiplier)


func api_reset_camera() -> void:
	view.reset_camera()


func api_set_paused(paused: bool) -> void:
	_paused = paused
	_refresh_ui(true)


func api_set_capture_mode(enabled: bool) -> void:
	_capture_mode = enabled
	_refresh_ui(true)


func api_finish_stage_count() -> int:
	return _stage_count
