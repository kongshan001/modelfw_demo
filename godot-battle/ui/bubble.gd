class_name Bubble
extends Control

# 单位头顶喊招气泡（规格 6.4）：弹出、停留、自动淡出。不拦截鼠标。

var hold_seconds := 1.0
var fade_seconds := 0.35

const TAIL_HEIGHT := 12.0
const BG_COLOR := Color(0.07, 0.06, 0.1, 0.94)

var _panel: PanelContainer
var _label: Label
var _fade_tween: Tween

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.08, 0.94)
	style.border_color = Color(1.0, 0.84, 0.42, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_override("font", FontUtil.cjk_font())
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_panel.add_child(_label)

func show_text(text: String, anchor: Vector2) -> void:
	if text.is_empty():
		return
	_label.text = text
	_panel.reset_size()
	var box_size := _panel.get_combined_minimum_size()
	_panel.size = box_size
	_panel.position = Vector2(-box_size.x * 0.5, -box_size.y - TAIL_HEIGHT)
	position = anchor
	var view_size := get_viewport_rect().size
	position.x = clampf(position.x, box_size.x * 0.5 + 24.0, view_size.x - box_size.x * 0.5 - 24.0)
	position.y = maxf(position.y, box_size.y + TAIL_HEIGHT + 12.0)
	queue_redraw()

	visible = true
	modulate.a = 1.0
	_panel.pivot_offset = box_size * 0.5
	_panel.scale = Vector2(0.72, 0.72)
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_interval(hold_seconds)
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_seconds)
	_fade_tween.tween_callback(_on_faded)

func hide_now() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	visible = false
	modulate.a = 1.0
	_panel.scale = Vector2.ONE

func _on_faded() -> void:
	_fade_tween = null
	visible = false
	modulate.a = 1.0
	_panel.scale = Vector2.ONE

func _draw() -> void:
	if not visible:
		return
	var tail := PackedVector2Array([
		Vector2(-10.0, -TAIL_HEIGHT),
		Vector2(10.0, -TAIL_HEIGHT),
		Vector2(0.0, 0.0),
	])
	draw_colored_polygon(tail, BG_COLOR)
