extends CanvasLayer
## 单 pass 屏幕后处理（位于 HUD 之下）：径向 god rays（围绕精灵/月亮的屏幕位置）、
## 轻微色调分级、暗角、细颗粒。GL Compatibility 下使用 hint_screen_texture，不依赖 depth texture。

var overlay: ColorRect
var material: ShaderMaterial
var high_quality := true


func _ready() -> void:
	layer = 10
	overlay = ColorRect.new()
	overlay.name = "PostFX"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/post_fx.gdshader")
	material.set_shader_parameter("resolution", Vector2(1280, 720))
	overlay.material = material
	add_child(overlay)


func set_light_uv(uv: Vector2) -> void:
	material.set_shader_parameter("light_uv", uv)


func set_ray_strength(value: float) -> void:
	material.set_shader_parameter("ray_strength", maxf(value, 0.0))


func set_ray_color(color: Color) -> void:
	material.set_shader_parameter("ray_color", color)


func set_quality(high: bool) -> void:
	high_quality = high
	if not high:
		set_ray_strength(0.0)


func set_vignette(value: float) -> void:
	material.set_shader_parameter("vignette_strength", clampf(value, 0.0, 0.8))
