class_name HD2DFarmer
extends Node2D

# 沿土路往返的农夫。节点原点在脚底，Sprite 上移 17px。
# 自带 2D 遮挡体（被方向光/灯笼投影）和夜间手提灯。

const SPEED := 15.0
const WAIT_SECONDS := 1.15

var paused := false
var night := false
var _sprite: AnimatedSprite2D
var _hand_light: PointLight2D
var _hand_glow: Sprite2D
var _points := PackedVector2Array([
	Vector2(248, 218), Vector2(254, 228), Vector2(260, 238),
	Vector2(266, 246), Vector2(272, 252),
])
var _index := 1
var _step := 1
var _wait := 0.0
var _facing := 1


func setup(frames: SpriteFrames, glow_texture: Texture2D, light_texture: Texture2D) -> void:
	position = _points[0]
	z_index = int(position.y)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.centered = true
	_sprite.offset = Vector2(0, -17)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.play("walk")
	add_child(_sprite)

	var contact := Sprite2D.new()
	contact.texture = HD2DArt.make_contact_shadow(26, 9)
	contact.centered = true
	contact.position = Vector2(0, -1)
	contact.z_index = -1
	contact.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var contact_mat := CanvasItemMaterial.new()
	contact_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	contact.material = contact_mat
	add_child(contact)

	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-5, -30), Vector2(6, -30), Vector2(7, -10),
		Vector2(5, 0), Vector2(-4, 0), Vector2(-7, -12),
	])
	var occ := LightOccluder2D.new()
	occ.occluder = poly
	add_child(occ)

	_hand_glow = Sprite2D.new()
	_hand_glow.texture = glow_texture
	_hand_glow.position = Vector2(11, -15)
	_hand_glow.z_index = 2
	_hand_glow.modulate = Color(1.0, 0.78, 0.42, 0.0)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_hand_glow.material = mat
	add_child(_hand_glow)

	_hand_light = PointLight2D.new()
	_hand_light.texture = light_texture
	_hand_light.position = Vector2(11, -15)
	_hand_light.color = Color("#ffb765")
	_hand_light.energy = 0.0
	_hand_light.texture_scale = 0.55
	_hand_light.shadow_enabled = false
	_hand_light.z_index = 1
	add_child(_hand_light)


func _process(delta: float) -> void:
	if paused:
		return
	if _wait > 0.0:
		_wait -= delta
		_sprite.play("idle")
		return
	var target := _points[_index]
	var to := target - position
	if to.length() < 0.7:
		position = target
		_wait = WAIT_SECONDS
		if _index == _points.size() - 1:
			_step = -1
		elif _index == 0:
			_step = 1
		_index = clampi(_index + _step, 0, _points.size() - 1)
		_sprite.play("idle")
		return
	var motion := to.normalized() * SPEED * delta
	position += motion
	if absf(motion.x) > 0.01:
		_facing = 1 if motion.x > 0.0 else -1
		_sprite.flip_h = _facing < 0
	_sprite.play("walk")
	z_index = int(position.y)


func set_paused(value: bool) -> void:
	paused = value
	if _sprite != null:
		_sprite.speed_scale = 0.0 if value else 1.0


func set_night(value: bool) -> void:
	night = value
	if _hand_light != null:
		_hand_light.energy = 1.05 if night else 0.0
		_hand_glow.modulate.a = 0.55 if night else 0.0


func facing() -> int:
	return _facing


func reset_to_start() -> void:
	position = _points[0]
	_index = 1
	_step = 1
	_wait = 0.0
	_facing = 1
	z_index = int(position.y)
	if _sprite != null:
		_sprite.flip_h = false
		_sprite.play("walk")
		_sprite.frame = 0
