class_name CameraRig
extends Camera2D

var _visual_rng := RandomNumberGenerator.new()

func _ready() -> void:
	position = Vector2(960, 540)
	_visual_rng.seed = 4242
	zoom = Vector2.ONE

func shake(amount: float = 5.0, duration: float = 0.14) -> void:
	var tween := create_tween()
	var steps := 4
	for i in steps:
		var offset_target := Vector2(_visual_rng.randf_range(-amount, amount), _visual_rng.randf_range(-amount, amount))
		tween.tween_property(self, "offset", offset_target, duration / float(steps))
	tween.tween_property(self, "offset", Vector2.ZERO, 0.06)

func punch_zoom(amount: float = 1.04, duration: float = 0.15) -> void:
	var tween := create_tween()
	tween.tween_property(self, "zoom", Vector2(amount, amount), duration / 2.0)
	tween.tween_property(self, "zoom", Vector2.ONE, duration / 2.0)
