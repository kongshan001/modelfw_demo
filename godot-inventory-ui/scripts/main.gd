extends Control

var ui: BackpackUI
var _fps_label: Label
var _bg_glow_a: TextureRect
var _bg_glow_b: TextureRect
var _t := 0.0
var _show_fps := false


func _ready() -> void:
	theme = ThemeKit.make_theme()
	get_window().min_size = Vector2i(960, 540)
	_build_backdrop()
	ui = BackpackUI.new()
	ui.position = Vector2.ZERO
	add_child(ui)
	_build_fps()
	set_process(true)


func _build_backdrop() -> void:
	var bg := TextureRect.new()
	bg.texture = ThemeKit.bg_tex("night_palace")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_bg_glow_a = ThemeKit.glow_texture_rect("glow", Color(1.0, 0.72, 0.38, 0.14))
	_bg_glow_a.position = Vector2(1080, 180)
	_bg_glow_a.size = Vector2(320, 320)
	add_child(_bg_glow_a)
	_bg_glow_b = ThemeKit.glow_texture_rect("glow", Color(0.52, 0.9, 1.0, 0.11))
	_bg_glow_b.position = Vector2(-90, 420)
	_bg_glow_b.size = Vector2(360, 360)
	add_child(_bg_glow_b)

	var vig := TextureRect.new()
	vig.texture = ThemeKit.ui_tex("vignette")
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.position = Vector2.ZERO
	vig.size = Vector2(1280, 720)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)


func _build_fps() -> void:
	_fps_label = ThemeKit.make_label(self, "", 12, Color(0.9, 1.0, 1.0, 0.9), Vector2(16, 10), Vector2(240, 20),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(0.02, 0.06, 0.1, 0.8))
	_fps_label.modulate.a = 0.9
	_fps_label.visible = false
	_fps_label.z_index = 100


func _process(delta: float) -> void:
	_t += delta
	if _bg_glow_a != null:
		_bg_glow_a.modulate.a = 0.11 + 0.035 * sin(_t * 0.9)
	if _bg_glow_b != null:
		_bg_glow_b.modulate.a = 0.09 + 0.03 * sin(_t * 0.7 + 1.7)
	if _fps_label != null and _show_fps:
		_fps_label.text = "FPS %d  ·  绘制 %d" % [
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F3:
			_show_fps = not _show_fps
			_fps_label.visible = _show_fps
			get_viewport().set_input_as_handled()
			return
		if key_event.pressed and ui != null and ui.handle_key(key_event):
			get_viewport().set_input_as_handled()


func get_fps() -> float:
	return Engine.get_frames_per_second()
