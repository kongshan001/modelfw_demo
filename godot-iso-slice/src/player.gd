class_name IsoPlayer
extends CharacterBody2D

# 玩家脚本保持和官方 demo 一样的骨架：
#   读输入 -> 纵向 /2 -> 归一化 * 速度 -> move_and_slide
# 差别只在于动画资源由 HeroFrames 在运行时从图集切出来。
const SPEED := 190.0

@onready var sprite: AnimatedSprite2D = $Sprite

var facing := 2  # 2 = front，开局面向镜头
var demo_input := Vector2.ZERO  # 截图/GIF 工具用它驱动，不走键盘
var autopilot := false

var _anim := ""

func _ready() -> void:
	sprite.sprite_frames = HeroFrames.build()
	_play("idle")


func _physics_process(_delta: float) -> void:
	var input := demo_input if autopilot else Input.get_vector(
		"move_left", "move_right", "move_up", "move_down")

	# 关键一行：屏幕 Y 只走一半，补偿 2:1 菱形投影
	var desired := IsoMath.screen_motion(input)
	if desired.length_squared() > 0.0001:
		facing = IsoMath.dir_index(desired)
		desired = desired.normalized() * SPEED
		_play("walk")
	else:
		desired = Vector2.ZERO
		_play("idle")

	velocity = desired
	move_and_slide()


func teleport(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO


func _play(prefix: String) -> void:
	var next := "%s_%d" % [prefix, facing]
	if next == _anim:
		return
	_anim = next
	sprite.play(next)
