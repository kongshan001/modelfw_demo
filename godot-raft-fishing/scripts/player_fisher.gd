class_name RaftPlayer
extends Node3D

# 木筏上的小人：相机相对的 WASD、朝向像素帧、冲刺体力。
const PIXEL := 0.04
const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.2

var world: Node
var sprite: Sprite3D
var shadow: MeshInstance3D
var frames: Dictionary
var facing := 0
var frame := 0
var anim_t := 0.0
var moving := false
var bob_t := 0.0


func setup(world_ref: Node) -> void:
	world = world_ref
	frames = Art.fisher_frames()
	sprite = Sprite3D.new()
	sprite.name = "Sprite"
	sprite.texture = frames[0][0]
	sprite.pixel_size = PIXEL
	sprite.centered = true
	sprite.position = Vector3(0.0, 0.72, 0.0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.double_sided = true
	sprite.render_priority = 3
	add_child(sprite)

	shadow = MeshInstance3D.new()
	shadow.name = "Shadow"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.15, 0.52)
	shadow.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = Art.shadow()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow.material_override = mat
	shadow.rotation.x = -PI / 2.0
	shadow.position.y = 0.018
	add_child(shadow)


func _physics_process(delta: float) -> void:
	bob_t += delta
	if world == null:
		return
	if not world.input_active():
		moving = false
		_animate(delta)
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir: Vector3 = world.camera_relative(input)
	var wants_sprint := Input.is_action_pressed("sprint") and input.length_squared() > 0.01
	var can_sprint: bool = world.update_stamina(delta, wants_sprint)
	var speed := SPRINT_SPEED if can_sprint else WALK_SPEED
	moving = dir.length_squared() > 0.001
	if moving:
		var motion: Vector3 = dir.normalized() * speed * delta
		global_position = world.move_player(global_position, motion)
		if world.locked_loot == null:
			_set_facing_from_world(dir)
	_animate(delta)


func _animate(delta: float) -> void:
	anim_t += delta
	var rate := 0.20 if moving else 0.46
	if anim_t >= rate:
		anim_t = 0.0
		frame = 1 - frame
		if not moving and world != null and world.is_charging():
			frame = 0
		_apply_texture()
	# 抛钩时朝向锁定目标
	if world != null and world.is_charging() and world.locked_loot != null:
		var d: Vector3 = world.locked_loot.global_position - global_position
		if d.length_squared() > 0.001:
			_set_facing_from_world(d)


func _set_facing_from_world(dir: Vector3) -> void:
	if world == null:
		return
	var scr: Vector2 = world.world_dir_to_screen(dir)
	var f := facing
	if absf(scr.x) > absf(scr.y):
		f = 2 if scr.x > 0.0 else 1
	else:
		f = 0 if scr.y < 0.0 else 3
	if f != facing:
		facing = f
		_apply_texture()


func _apply_texture() -> void:
	if sprite != null and frames.has(facing):
		sprite.texture = frames[facing][frame]
