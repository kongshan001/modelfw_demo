extends Control

@onready var container: SubViewportContainer = $ViewportContainer
@onready var world = $ViewportContainer/WorldViewport/World
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	hud.setup(world)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if container.size.x <= 1.0 or container.size.y <= 1.0:
			return
		var local := container.get_local_mouse_position()
		var wp := local * Vector2(640.0, 360.0) / container.size
		if wp.x >= 0.0 and wp.x < 640.0 and wp.y >= 0.0 and wp.y < 360.0:
			if world.is_water(wp):
				world.spawn_ripple(wp, 1.2)
