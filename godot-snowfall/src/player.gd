extends Node2D

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var lantern: PointLight2D = $Lantern

var world: Node
var facing := 0
var _anim := ""
var _foot_t := 0.0
var _foot_side := 1
var _time := 0.0


func setup(w: Node) -> void:
	world = w
	sprite.sprite_frames = SnowHeroFrames.build()
	_play("idle")


func _process(delta: float) -> void:
	_time += delta
	# soft lantern breathing
	if lantern:
		lantern.energy = 0.55 + 0.05 * sin(_time * 6.5) + 0.03 * sin(_time * 11.3)


func _physics_process(delta: float) -> void:
	if world == null:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := 58.0
	position += input * speed * delta
	position.x = clampf(position.x, 10.0, 630.0)
	position.y = clampf(position.y, 100.0, 352.0)

	if input.length() > 0.1:
		if absf(input.x) >= absf(input.y):
			facing = 3 if input.x > 0.0 else 2
		else:
			facing = 0 if input.y > 0.0 else 1
		_play("walk")
		_foot_t -= delta
		if _foot_t <= 0.0:
			world.add_footprint(position, facing, _foot_side)
			_foot_side = -_foot_side
			_foot_t = 0.28
	else:
		_play("idle")


func _play(prefix: String) -> void:
	var name := "%s_%d" % [prefix, facing]
	if name == _anim:
		return
	_anim = name
	sprite.play(name)
