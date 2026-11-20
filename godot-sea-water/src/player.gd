extends Node2D

# Top-down hero. Its feet sit at the node origin; the waterline shader on the
# sprite follows the depth map at the feet.

@onready var sprite: AnimatedSprite2D = $Sprite

var world: Node
var facing := 0                # 0 down, 1 up, 2 left, 3 right
var _anim := ""
var _ripple_t := 0.0
var _submerge := 0.0
var _idle_t := 0.0


func setup(w: Node) -> void:
	world = w
	sprite.sprite_frames = HeroFrames.build()
	_play("idle")


func set_day(day: float, tint: Color) -> void:
	var m := sprite.material as ShaderMaterial
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	var water_col := Vector3(0.30, 0.78, 0.73).lerp(
		Vector3(0.10, 0.34, 0.54), 1.0 - day)
	m.set_shader_parameter("water_col", water_col)


func _physics_process(delta: float) -> void:
	if world == null:
		return

	var input := Input.get_vector("move_left", "move_right",
		"move_up", "move_down")
	var depth: float = world.depth_at(position)
	var speed := 64.0
	if depth > 0.04:
		speed = 44.0

	position += input * speed * delta
	position.x = clampf(position.x, 8.0, 632.0)
	position.y = clampf(position.y, 8.0, 352.0)

	if input.length() > 0.1:
		if absf(input.x) >= absf(input.y):
			facing = 3 if input.x > 0.0 else 2
		else:
			facing = 0 if input.y > 0.0 else 1
		_play("walk")
		if depth > 0.04:
			_ripple_t -= delta
			if _ripple_t <= 0.0:
				world.spawn_ripple(position, 0.65)
				_ripple_t = 0.26
	else:
		_play("idle")

	_idle_t -= delta
	if depth > 0.04 and _idle_t <= 0.0:
		world.spawn_ripple(position, 0.35)
		_idle_t = 1.15
	_submerge = lerpf(_submerge, clampf(world.depth_at(position), 0.0, 1.0), 0.35)
	var m := sprite.material as ShaderMaterial
	m.set_shader_parameter("submerge", _submerge)
	m.set_shader_parameter("time", world.time)
	var anim_name := str(sprite.animation)
	var row := facing
	var col := sprite.frame + (2 if anim_name.begins_with("walk") else 0)
	m.set_shader_parameter("u_frame_origin", Vector2(col / 6.0, row / 4.0))
	m.set_shader_parameter("u_frame_size", Vector2(1.0 / 6.0, 1.0 / 4.0))


func _play(prefix: String) -> void:
	var anim_name := "%s_%d" % [prefix, facing]
	if anim_name == _anim:
		return
	_anim = anim_name
	sprite.play(anim_name)
