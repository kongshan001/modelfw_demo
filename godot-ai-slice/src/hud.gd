extends CanvasLayer

# Title / HUD / win overlays and a tiny F1 debug readout. All UI is built in
# code so an AI can change story/copy without opening a scene file.

var _hud_root: Control
var _title_root: Control
var _win_root: Control
var _cores_label: Label
var _state_label: Label
var _debug_label: Label
var _debug_visible := false

func _ready() -> void:
	layer = 10
	_build()
	Game.state_changed.connect(_on_state_changed)
	Game.cores_changed.connect(_on_cores_changed)
	_on_state_changed(Game.state)
	_on_cores_changed(Game.collected, Game.TOTAL_CORES)

func _process(_delta: float) -> void:
	if not _debug_visible or _debug_label == null:
		return
	var players := get_tree().get_nodes_in_group("player")
	var pos := Vector3.ZERO
	if not players.is_empty():
		pos = (players[0] as Node3D).global_position
	_debug_label.text = "FPS %d\nPOS %.1f, %.1f, %.1f\nSTATE %s" % [
		Engine.get_frames_per_second(), pos.x, pos.y, pos.z, Game.state_name()
	]

func toggle_debug() -> void:
	_debug_visible = not _debug_visible
	if _debug_label != null:
		_debug_label.visible = _debug_visible

func _build() -> void:
	_hud_root = Control.new()
	_hud_root.name = "HUD"
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	var panel := PanelContainer.new()
	panel.position = Vector2(24.0, 24.0)
	panel.custom_minimum_size = Vector2(380.0, 0.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.06, 0.1, 0.84)
	panel_style.border_color = Color(0.3, 0.75, 0.9, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", panel_style)
	_hud_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	_add_label(box, "SKY CIRCUIT", 24, Color(1.0, 0.86, 0.5))
	_cores_label = _add_label(box, "CORES  0 / 3", 22, Color(0.55, 0.92, 1.0))
	_add_label(box, "WASD Move  ·  Space Jump  ·  F1 Debug", 14, Color(0.82, 0.88, 0.95))
	_state_label = _add_label(box, "STATE · TITLE", 14, Color(0.55, 0.95, 0.72))

	_debug_label = Label.new()
	_debug_label.position = Vector2(930.0, 24.0)
	_debug_label.custom_minimum_size = Vector2(320.0, 0.0)
	_debug_label.visible = false
	_debug_label.add_theme_font_size_override("font_size", 13)
	_debug_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_hud_root.add_child(_debug_label)

	_title_root = _make_overlay(Color(0.03, 0.05, 0.08, 0.42))
	add_child(_title_root)
	var title_box := _overlay_box(_title_root)
	_add_label(title_box, "SKY CIRCUIT", 64, Color(1.0, 0.86, 0.5))
	_add_label(title_box, "AI Slice · Godot 4.6", 20, Color(0.7, 0.85, 1.0))
	_add_label(title_box, "Collect 3 cores · Reach the portal", 20, Color(0.9, 0.94, 1.0))
	_add_label(title_box, "Enter / Space to start", 22, Color(0.9, 0.95, 0.85))

	_win_root = _make_overlay(Color(0.02, 0.03, 0.05, 0.68))
	add_child(_win_root)
	var win_box := _overlay_box(_win_root)
	_add_label(win_box, "CIRCUIT RESTORED", 52, Color(1.0, 0.86, 0.5))
	_add_label(win_box, "All 3 cores collected", 20, Color(0.7, 0.9, 1.0))
	_add_label(win_box, "Press R to restart", 22, Color(0.9, 0.95, 0.85))

func _add_label(parent: VBoxContainer, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _make_overlay(bg_color: Color) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = bg_color
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var box := VBoxContainer.new()
	box.name = "Content"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	return root

func _overlay_box(root: Control) -> VBoxContainer:
	return root.find_child("Content", true, false) as VBoxContainer

func _on_state_changed(state: int) -> void:
	if _title_root != null:
		_title_root.visible = state == Game.TITLE
	if _hud_root != null:
		_hud_root.visible = state != Game.TITLE
	if _win_root != null:
		_win_root.visible = state == Game.WON
	if _state_label != null:
		_state_label.text = "STATE · " + Game.state_name()

func _on_cores_changed(collected: int, total: int) -> void:
	if _cores_label != null:
		_cores_label.text = "CORES  %d / %d" % [collected, total]
