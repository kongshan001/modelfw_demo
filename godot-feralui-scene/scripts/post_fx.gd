extends CanvasLayer
## 极轻的屏幕校色层：暖高光/冷阴影、暗角、微颗粒。放在 HUD 之下，不干扰交互与文字。

const POST_SHADER = preload("res://shaders/post_grade.gdshader")

var rect: ColorRect
var material: ShaderMaterial
var time := 0.0
var high := true


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	material = ShaderMaterial.new()
	material.shader = POST_SHADER
	material.set_shader_parameter("nightness", 1.0)
	material.set_shader_parameter("rain_amount", 0.0)
	material.set_shader_parameter("u_time", 0.0)
	material.set_shader_parameter("vignette_strength", 0.26)
	material.set_shader_parameter("grain_strength", 0.007)

	rect = ColorRect.new()
	rect.name = "GradeRect"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	rect.material = material
	add_child(rect)


func tick(delta: float, nightness: float, rain: float) -> void:
	time += delta
	material.set_shader_parameter("nightness", nightness)
	material.set_shader_parameter("rain_amount", rain)
	material.set_shader_parameter("u_time", time)
	material.set_shader_parameter("vignette_strength", 0.25 + rain * 0.05)
	material.set_shader_parameter("grain_strength", 0.006 if high else 0.004)


func set_quality(value: bool) -> void:
	high = value
	rect.visible = true


func set_effect_visible(value: bool) -> void:
	rect.visible = value


func reset() -> void:
	time = 0.0
	material.set_shader_parameter("u_time", 0.0)
