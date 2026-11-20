extends Control

@onready var world = $ViewportContainer/WorldViewport/World
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	hud.setup(world)
