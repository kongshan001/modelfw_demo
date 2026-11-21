class_name StylePostProcess
extends CanvasLayer

# 屏幕空间画风切换：原画 / 卡通渲染 / 水墨。
#
# 结构：
#   StyleFX (CanvasLayer, layer 1)
#   ├── BackBufferCopy   把战场画面（背景 + 角色 + VFX）复制到屏幕纹理
#   ├── Stylize (ColorRect, 全屏)  用 style_post.gdshader 采样并重绘
#   └── StyleHint (Label)          画风提示，不参与后处理
# UILayer 固定 layer 2，因此 HUD/日志/对白不会被后处理影响。
#
# 切换键：F2（F1/F3/F6/F7 已被调试控制台占用）。

signal style_changed(index: int, style_name: String)

const STYLE_NAMES := ["原画", "卡通渲染", "水墨"]
const HINT_SECONDS := 2.4
const SHADER := preload("res://shaders/style_post.gdshader")

var _stylize: ColorRect
var _material: ShaderMaterial
var _hint: Label
var _hint_tween: Tween
var _index := 0

func _ready() -> void:
	layer = 1

	var copy := BackBufferCopy.new()
	copy.name = "BackBufferCopy"
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)

	_stylize = ColorRect.new()
	_stylize.name = "Stylize"
	_stylize.color = Color.WHITE
	_stylize.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stylize)
	_stylize.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_stylize.material = _material
	_update_pixel_size()
	get_viewport().size_changed.connect(_update_pixel_size)

	_hint = Label.new()
	_hint.name = "StyleHint"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font", FontUtil.cjk_font())
	_hint.add_theme_font_size_override("font_size", 19)
	_hint.add_theme_color_override("font_color", UiStyle.GOLD)
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_hint)
	_update_pixel_size()

	set_style(0, false, false)
	_show_hint()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F2:
		cycle_style()
		get_viewport().set_input_as_handled()

func cycle_style() -> void:
	set_style((_index + 1) % STYLE_NAMES.size())

func set_style(index: int, show_hint := true, animate := true) -> void:
	_index = clampi(index, 0, STYLE_NAMES.size() - 1)
	_material.set_shader_parameter("style_mode", _index)
	if animate and _index > 0:
		_material.set_shader_parameter("effect_strength", 0.0)
		var tween := create_tween()
		tween.tween_method(_set_effect_strength, 0.0, 1.0, 0.22)
	else:
		_material.set_shader_parameter("effect_strength", 1.0)
	style_changed.emit(_index, style_name())
	if show_hint:
		_show_hint()

func current_style() -> int:
	return _index

func style_name() -> String:
	return STYLE_NAMES[_index]

func _set_effect_strength(value: float) -> void:
	_material.set_shader_parameter("effect_strength", value)

func _update_pixel_size() -> void:
	if _material == null:
		return
	var size := get_viewport().get_visible_rect().size
	if size.x > 0.0 and size.y > 0.0:
		_material.set_shader_parameter("screen_pixel_size", Vector2(1.0 / size.x, 1.0 / size.y))
	if _hint != null:
		_hint.position = Vector2(0.0, size.y - 58.0)
		_hint.size = Vector2(size.x, 34.0)

func _show_hint() -> void:
	_hint.text = "画风 · %s    [F2 切换]" % STYLE_NAMES[_index]
	_hint.modulate.a = 1.0
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(HINT_SECONDS)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.45)
