extends CanvasLayer

# 中文参数面板：Shader / 原生 Light2D 路径切换、点光/方向光、方位角/高度/
# 强度/光色、法线强度/高光/粗糙度/环境光/边缘光、法线对比、调试视图、
# 巡游/暂停/重置，以及 FPS / draw calls / 光照向量 / 法线图预览。
# 设计分辨率 1280×720；世界 320×180 由 Camera2D zoom=4 放大。

const PANEL_WIDTH := 366
const INK := Color(0.030, 0.048, 0.060, 0.95)
const PANEL_EDGE := Color(0.42, 0.58, 0.55, 0.75)
const BRASS := Color(0.93, 0.75, 0.43)
const TEAL := Color(0.44, 0.82, 0.77)
const MOSS := Color(0.62, 0.82, 0.52)
const SUBTLE := Color(0.72, 0.80, 0.79)
const DIM := Color(0.46, 0.57, 0.57)
const ROSE := Color(0.92, 0.56, 0.47)

const SLIDERS := [
	{"key": "angle", "label": "方位角", "min": 0.0, "max": 360.0, "step": 1.0},
	{"key": "height", "label": "光高", "min": 8.0, "max": 160.0, "step": 1.0},
	{"key": "energy", "label": "光强", "min": 0.0, "max": 3.0, "step": 0.05},
	{"key": "normal_strength", "label": "法线强度", "min": 0.0, "max": 2.0, "step": 0.05},
	{"key": "spec", "label": "高光", "min": 0.0, "max": 1.5, "step": 0.05},
	{"key": "rough", "label": "粗糙度", "min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "ambient", "label": "环境光", "min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "rim", "label": "边缘光", "min": 0.0, "max": 1.0, "step": 0.05},
]
const SHADER_ONLY := ["normal_strength", "spec", "rough", "rim"]
const DEBUG_NAMES := ["关", "法线图", "光向量", "漫反射", "光矢量标注"]

var main: Node
var _root: Control
var _panel: PanelContainer
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _buttons: Dictionary = {}
var _fps_label: Label
var _detail_label: Label
var _note_label: Label
var _hint_label: Label
var _dial
var _syncing := false
var _stats_accum := 0.0
var _fps_visible := true


func _ready() -> void:
	_build_ui()
	set_process(true)


func setup(main_node: Node) -> void:
	main = main_node
	sync_from_main()
	show_caption("灯影工坊 · 精灵法线受光实验")


func set_ui_visible(value: bool) -> void:
	if _root != null:
		_root.visible = value


func is_ui_visible() -> bool:
	return _root != null and _root.visible


func set_fps_visible(value: bool) -> void:
	_fps_visible = value
	_refresh_stats()


func show_caption(text: String) -> void:
	if _hint_label != null:
		_hint_label.tooltip_text = text


func sync_from_main() -> void:
	if main == null:
		return
	_syncing = true
	var p: Dictionary = main.get_params()
	for spec in SLIDERS:
		var key: String = spec["key"]
		var slider: HSlider = _sliders.get(key)
		if slider == null:
			continue
		slider.set_value_no_signal(float(p[key]))
		slider.editable = not (key == "angle" and bool(p["auto"]))
		if bool(p["native"]) and SHADER_ONLY.has(key):
			slider.editable = false
		var native_dim: bool = bool(p["native"]) and SHADER_ONLY.has(key)
		slider.modulate = Color(1, 1, 1, 0.42 if native_dim else 1.0)
		_update_value_label(key, float(p[key]))
		_update_slider_tint(key, bool(p["native"]))

	_buttons["path"].text = "路径: 原生 Light2D [M]" if bool(p["native"]) else "路径: 自定义 Shader [M]"
	_buttons["type"].text = "光型: 点光 [G]" if bool(p["point"]) else "光型: 方向光 [G]"
	_buttons["color"].text = "光色: %s [C]" % String(p["color_name"])
	_buttons["auto"].text = "巡游: ON [A]" if bool(p["auto"]) else "巡游: OFF [A]"
	_buttons["normals"].text = "法线: ON [V]" if bool(p["normals"]) else "法线: OFF [V]"
	_buttons["debug"].text = "调试: %s [F]" % DEBUG_NAMES[int(p["debug"])]
	_buttons["pause"].text = "继续 [Space]" if bool(p["paused"]) else "暂停 [Space]"
	_buttons["pause"].add_theme_color_override("font_color",
			BRASS if bool(p["paused"]) else SUBTLE)
	_buttons["auto"].add_theme_color_override("font_color",
			TEAL if bool(p["auto"]) else SUBTLE)
	_buttons["normals"].add_theme_color_override("font_color",
			TEAL if bool(p["normals"]) else ROSE)
	_buttons["path"].add_theme_color_override("font_color",
			MOSS if bool(p["native"]) else TEAL)
	_note_label.visible = bool(p["native"])
	if _dial != null:
		_dial.set_state(float(p["angle"]), float(p["height"]), p["color"])
	_syncing = false
	_refresh_stats()


func _process(delta: float) -> void:
	_stats_accum += delta
	if _stats_accum < 0.2:
		return
	_stats_accum = 0.0
	if main == null or not is_ui_visible():
		return
	var p: Dictionary = main.get_params()
	if bool(p["auto"]):
		var slider: HSlider = _sliders.get("angle")
		if slider != null:
			_syncing = true
			slider.set_value_no_signal(float(p["angle"]))
			_update_value_label("angle", float(p["angle"]))
			_syncing = false
	if _dial != null:
		_dial.set_state(float(p["angle"]), float(p["height"]), p["color"])
	_refresh_stats()


func _refresh_stats() -> void:
	if main == null or _fps_label == null:
		return
	var p: Dictionary = main.get_params()
	var fps_text := ("FPS %d   " % main.get_fps()) if _fps_visible else ""
	_fps_label.text = "%sDRAW %d   %s · %s" % [
		fps_text, main.get_draw_calls(),
		"NATIVE" if bool(p["native"]) else "SHADER",
		"POINT" if bool(p["point"]) else "DIR"]
	var l: Vector3 = main.get_light_vector_at(Vector2(202, 124))
	var notes := []
	notes.append("法线 %s" % ("ON" if bool(p["normals"]) else "OFF"))
	notes.append("调试 %s" % DEBUG_NAMES[int(p["debug"])])
	notes.append("巡游 %s" % ("ON" if bool(p["auto"]) else "OFF"))
	if bool(p["flip"]):
		notes.append("石狐翻转")
	if bool(p["scale"]):
		notes.append("苔灵 2×")
	_detail_label.text = "L=(%.2f, %.2f, %.2f)  h=%.0f  R=%.0f\n%s" % [
		l.x, l.y, l.z, float(p["height"]), float(p["radius"]),
		" · ".join(PackedStringArray(notes))]


func _update_value_label(key: String, value: float) -> void:
	var label: Label = _value_labels.get(key)
	if label == null:
		return
	match key:
		"angle":
			var p: Dictionary = main.get_params()
			label.text = "AUTO" if bool(p["auto"]) else "%d°" % roundi(value)
		"height":
			label.text = "%d" % roundi(value)
		_:
			label.text = "%.2f" % value


func _update_slider_tint(key: String, native: bool) -> void:
	var label: Label = _value_labels.get(key)
	if label == null:
		return
	var dim: bool = native and SHADER_ONLY.has(key)
	label.add_theme_color_override("font_color", DIM if dim else SUBTLE)


func _on_slider(value: float, key: String) -> void:
	if _syncing or main == null:
		return
	main.set_param(key, value)
	_update_value_label(key, value)


func _on_button(action: String) -> void:
	if main == null:
		return
	match action:
		"path":
			main.set_native_mode(not main.is_native_mode())
		"type":
			main.set_point_mode(not main.is_point_mode())
		"color":
			main.cycle_light_color()
		"auto":
			var p: Dictionary = main.get_params()
			main.set_auto_orbit(not bool(p["auto"]))
		"normals":
			var p2: Dictionary = main.get_params()
			main.set_normals_on(not bool(p2["normals"]))
		"debug":
			main.cycle_debug()
		"pause":
			main.set_playing(main.is_paused())
		"reset":
			main.reset()


# ── UI 构建 ───────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "STHeiti",
		"Noto Sans CJK SC", "Sans-Serif"])
	font.allow_system_fallback = true
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Monaco", "Consolas", "Monospace"])
	mono.allow_system_fallback = true

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 12
	theme.set_color("font_color", "Label", SUBTLE)
	theme.set_color("font_color", "Button", SUBTLE)
	theme.set_constant("separation", "HBoxContainer", 5)
	theme.set_constant("separation", "VBoxContainer", 4)

	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = theme
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 14)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.058, 0.068, 0.95)
	style.border_color = PANEL_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	var shell := PanelContainer.new()
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = INK
	shell_style.border_color = Color(0.16, 0.30, 0.30, 0.9)
	shell_style.set_border_width_all(1)
	shell_style.content_margin_left = 10
	shell_style.content_margin_right = 10
	shell_style.content_margin_top = 8
	shell_style.content_margin_bottom = 8
	shell.add_theme_stylebox_override("panel", shell_style)
	_panel.add_child(shell)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	shell.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := Label.new()
	title.text = "灯影工坊"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", BRASS)
	title_row.add_child(title)
	var tag := Label.new()
	tag.text = "SPRITE NORMAL LIGHT LAB"
	tag.add_theme_font_size_override("font_size", 8)
	tag.add_theme_color_override("font_color", DIM)
	tag.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(tag)

	var subtitle := Label.new()
	subtitle.text = "像素精灵 · 高度图 Sobel 法线 · 可移动光源"
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", TEAL)
	column.add_child(subtitle)

	var stats := PanelContainer.new()
	var stat_style := StyleBoxFlat.new()
	stat_style.bg_color = Color(0.016, 0.038, 0.046, 0.9)
	stat_style.border_color = Color(0.16, 0.28, 0.28, 0.9)
	stat_style.set_border_width_all(1)
	stat_style.content_margin_left = 6
	stat_style.content_margin_right = 6
	stat_style.content_margin_top = 3
	stat_style.content_margin_bottom = 3
	stats.add_theme_stylebox_override("panel", stat_style)
	column.add_child(stats)
	var stats_col := VBoxContainer.new()
	stats_col.add_theme_constant_override("separation", 0)
	stats.add_child(stats_col)
	_fps_label = Label.new()
	_fps_label.add_theme_font_override("font", mono)
	_fps_label.add_theme_font_size_override("font_size", 11)
	_fps_label.add_theme_color_override("font_color", MOSS)
	stats_col.add_child(_fps_label)
	_detail_label = Label.new()
	_detail_label.add_theme_font_override("font", mono)
	_detail_label.add_theme_font_size_override("font_size", 9)
	_detail_label.add_theme_color_override("font_color", DIM)
	stats_col.add_child(_detail_label)

	column.add_child(_section("光照路径 / LIGHT PATH", TEAL))
	var row1 := HBoxContainer.new()
	column.add_child(row1)
	_buttons["path"] = _button(row1, "路径: 自定义 Shader [M]", "path", 11)
	_buttons["path"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row2 := HBoxContainer.new()
	column.add_child(row2)
	_buttons["type"] = _button(row2, "光型: 点光 [G]", "type")
	_buttons["color"] = _button(row2, "光色: 暖灯 [C]", "color")
	var row3 := HBoxContainer.new()
	column.add_child(row3)
	_buttons["auto"] = _button(row3, "巡游: ON [A]", "auto")
	_buttons["normals"] = _button(row3, "法线: ON [V]", "normals")
	var row4 := HBoxContainer.new()
	column.add_child(row4)
	_buttons["debug"] = _button(row4, "调试: 关 [F]", "debug")
	_buttons["pause"] = _button(row4, "暂停 [Space]", "pause")
	_buttons["reset"] = _button(row4, "重置 [R]", "reset")

	column.add_child(_section("参数 / LIGHT & MATERIAL", BRASS))
	for spec in SLIDERS:
		column.add_child(_slider_row(spec))

	_note_label = Label.new()
	_note_label.text = "原生路径：法线强度 / 高光 / 粗糙度 / 边缘光不适用"
	_note_label.add_theme_font_size_override("font_size", 9)
	_note_label.add_theme_color_override("font_color", ROSE)
	_note_label.visible = false
	column.add_child(_note_label)

	column.add_child(_section("法线图 + 光照向量 / DEBUG", MOSS))
	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 8)
	column.add_child(preview_row)
	var normal_col := VBoxContainer.new()
	normal_col.add_theme_constant_override("separation", 1)
	preview_row.add_child(normal_col)
	var normal_title := Label.new()
	normal_title.text = "石狐法线 · G=Y↑"
	normal_title.add_theme_font_size_override("font_size", 9)
	normal_title.add_theme_color_override("font_color", DIM)
	normal_col.add_child(normal_title)
	var normal_frame := PanelContainer.new()
	var nf_style := StyleBoxFlat.new()
	nf_style.bg_color = Color(0.02, 0.04, 0.05, 0.9)
	nf_style.border_color = Color(0.22, 0.36, 0.36, 0.9)
	nf_style.set_border_width_all(1)
	nf_style.content_margin_left = 2
	nf_style.content_margin_right = 2
	nf_style.content_margin_top = 2
	nf_style.content_margin_bottom = 2
	normal_frame.add_theme_stylebox_override("panel", nf_style)
	normal_col.add_child(normal_frame)
	var normal_rect := TextureRect.new()
	normal_rect.texture = load("res://assets/sprites/guardian_normal.png")
	normal_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	normal_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	normal_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	normal_rect.custom_minimum_size = Vector2(72, 100)
	normal_frame.add_child(normal_rect)

	var dial_col := VBoxContainer.new()
	dial_col.add_theme_constant_override("separation", 1)
	preview_row.add_child(dial_col)
	var dial_title := Label.new()
	dial_title.text = "光照向量 · az / h"
	dial_title.add_theme_font_size_override("font_size", 9)
	dial_title.add_theme_color_override("font_color", DIM)
	dial_col.add_child(dial_title)
	_dial = load("res://scripts/light_dial.gd").new()
	_dial.custom_minimum_size = Vector2(104, 88)
	dial_col.add_child(_dial)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 2)
	dial_col.add_child(spacer)
	var native_hint := Label.new()
	native_hint.text = "高度进入 L.z\n绿色=+Y 上"
	native_hint.add_theme_font_size_override("font_size", 9)
	native_hint.add_theme_color_override("font_color", DIM)
	dial_col.add_child(native_hint)

	_hint_label = Label.new()
	_hint_label.text = "拖拽/方向键移光 · X 翻转石狐 · Z 缩放苔灵 · H 隐藏 UI"
	_hint_label.add_theme_font_size_override("font_size", 9)
	_hint_label.add_theme_color_override("font_color", DIM)
	column.add_child(_hint_label)

	_fps_label.text = "FPS --   DRAW --   SHADER · POINT"
	_detail_label.text = "L=(0.00, 0.00, 1.00)  h=0  R=0"


func _section(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	return label


func _button(parent: Node, text: String, action: String, font_size: int = 10) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_button.bind(action))
	parent.add_child(button)
	return button


func _slider_row(spec: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var label := Label.new()
	label.text = spec["label"]
	label.custom_minimum_size = Vector2(58, 0)
	label.add_theme_font_size_override("font_size", 10)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = spec["min"]
	slider.max_value = spec["max"]
	slider.step = spec["step"]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 14)
	slider.value_changed.connect(_on_slider.bind(spec["key"]))
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size = Vector2(38, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 10)
	value.add_theme_color_override("font_color", SUBTLE)
	row.add_child(value)
	_sliders[spec["key"]] = slider
	_value_labels[spec["key"]] = value
	return row
