class_name GradientRect
extends ColorRect

const SHADER := preload("res://shaders/rounded_gradient.gdshader")

var _mat: ShaderMaterial


func _ensure_material() -> void:
	if _mat != null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(
		size_px: Vector2,
		rad: float,
		top: Color,
		bottom: Color,
		border: Color = Color(0, 0, 0, 0),
		border_w: float = 0.0,
		gloss_amount: float = 0.0,
		gloss_col: Color = Color(1, 1, 1, 1),
		sheen_amount: float = 0.0
	) -> GradientRect:
	_ensure_material()
	size = size_px
	color = Color.WHITE
	_mat.set_shader_parameter("rect_size", size_px)
	_mat.set_shader_parameter("radius", rad)
	_mat.set_shader_parameter("top_color", top)
	_mat.set_shader_parameter("bottom_color", bottom)
	_mat.set_shader_parameter("border_color", border)
	_mat.set_shader_parameter("border_width", border_w)
	_mat.set_shader_parameter("gloss", gloss_amount)
	_mat.set_shader_parameter("gloss_color", gloss_col)
	_mat.set_shader_parameter("sheen", sheen_amount)
	return self


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _mat != null:
		_mat.set_shader_parameter("rect_size", size)


func set_colors(top: Color, bottom: Color) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("top_color", top)
	_mat.set_shader_parameter("bottom_color", bottom)


func set_border(border: Color, width: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("border_color", border)
	_mat.set_shader_parameter("border_width", width)


func set_gloss(amount: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("gloss", amount)
