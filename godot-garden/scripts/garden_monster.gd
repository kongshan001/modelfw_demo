class_name GardenMonster
extends Node3D

# 石圈妖灵：低多边形紫色浮游怪，红色眼睛、紫色光晕、头顶血条。
# 靠近玩家会追击/攻击；死亡发出 died 信号，由任务系统计数。

signal died(monster: GardenMonster)
signal hp_changed(current: int, max_hp: int)

var hero
var shadow_texture: Texture2D
var halo_texture: Texture2D

var spawn_position := Vector3.ZERO
var max_hp := 48
var hp := 48
var attack_damage := 5
var attack_range := 1.35
var aggro_range := 5.5
var move_speed := 1.1
var dead := false

var _visual: Node3D
var _wisps: Node3D
var _aura: Sprite3D
var _hp_bg: Sprite3D
var _hp_fill: Sprite3D
var _time := 0.0
var _attack_timer := 0.0
var _phase := 0.0

func _ready() -> void:
	spawn_position = position
	_phase = float(get_instance_id() % 1000) * 0.37
	_build()

func _process(delta: float) -> void:
	if dead:
		return
	_time += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_visual.position.y = sin(_time * 2.2 + _phase) * 0.07
	_aura.modulate.a = 0.02 + sin(_time * 2.6 + _phase) * 0.01
	_wisps.rotation.y += delta * 1.2

	if hero != null and is_instance_valid(hero) and not hero.is_downed():
		var offset: Vector3 = hero.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < aggro_range:
			if distance > attack_range:
				position += offset.normalized() * move_speed * delta
				_face(offset)
			else:
				_face(offset)
				if _attack_timer <= 0.0:
					_attack_timer = 1.25
					_strike()
			return
	_wander(delta)

func _wander(delta: float) -> void:
	var target := spawn_position + Vector3(cos(_time * 0.3 + _phase) * 1.2, 0, sin(_time * 0.27 + _phase) * 1.2)
	var offset := target - global_position
	offset.y = 0.0
	if offset.length() > 0.15:
		position += offset.normalized() * 0.35 * delta
		_face(offset)

func _face(offset: Vector3) -> void:
	if offset.length_squared() > 0.001:
		rotation.y = atan2(-offset.x, -offset.z)

func _strike() -> void:
	if hero == null or not is_instance_valid(hero) or hero.is_downed():
		return
	hero.take_damage(attack_damage)
	var tween := create_tween()
	var base := _visual.position
	tween.tween_property(_visual, "position:z", -0.22, 0.08)
	tween.tween_property(_visual, "position:z", base.z, 0.16)

func take_damage(amount: int) -> void:
	if dead:
		return
	hp = maxi(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	_update_health_bar()
	_spawn_damage_number("-%d" % amount, Color(1.0, 0.82, 0.38))
	var punch := create_tween()
	punch.tween_property(_visual, "scale", Vector3.ONE * 1.16, 0.06)
	punch.tween_property(_visual, "scale", Vector3.ONE, 0.12)
	_spawn_flash(Color(1.0, 0.78, 0.35, 0.55), 1.6)
	if hp <= 0:
		_die()

func is_alive() -> bool:
	return not dead and hp > 0

func _die() -> void:
	dead = true
	hp = 0
	_hp_bg.visible = false
	_hp_fill.visible = false
	_aura.visible = false
	_wisps.visible = false
	died.emit(self)
	_spawn_flash(Color(0.72, 0.42, 1.0, 0.65), 3.2)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.08, 0.38)
	tween.tween_property(_visual, "position:y", 1.2, 0.38)
	tween.chain().tween_callback(queue_free)

# ---------------------------------------------------------------- 构建

func _build() -> void:
	_visual = Node3D.new()
	_visual.position.y = 0.0
	add_child(_visual)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.09, 0.27)
	body_mat.roughness = 0.75
	body_mat.emission_enabled = true
	body_mat.emission = Color(0.36, 0.12, 0.5)
	body_mat.emission_energy_multiplier = 0.08

	var body := _sphere(_visual, Vector3(0, 0.62, 0), 0.32, body_mat)
	body.scale = Vector3(1.0, 1.15, 1.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var tail := _cylinder(_visual, Vector3(0, 0.28, 0.02), 0.1, 0.27, 0.42, body_mat)
	tail.scale = Vector3(1.0, 1.0, 0.8)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.16, 0.12)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.18, 0.1)
	eye_mat.emission_energy_multiplier = 2.0
	for side in [-1.0, 1.0]:
		_sphere(_visual, Vector3(side * 0.12, 0.66, -0.27), 0.045, eye_mat, 6, 3)

	_wisps = Node3D.new()
	_wisps.position = Vector3(0, 0.65, 0)
	_visual.add_child(_wisps)
	var wisp_mat := StandardMaterial3D.new()
	wisp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wisp_mat.albedo_color = Color(0.65, 0.38, 0.9, 0.25)
	wisp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wisp_mat.emission_enabled = true
	wisp_mat.emission = Color(0.5, 0.25, 0.8)
	for index in 3:
		var angle := TAU * float(index) / 3.0
		_sphere(_wisps, Vector3(cos(angle) * 0.45, sin(_time + index) * 0.08, sin(angle) * 0.45), 0.055, wisp_mat, 6, 3)

	if halo_texture != null:
		_aura = Sprite3D.new()
		_aura.texture = halo_texture
		_aura.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_aura.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		_aura.pixel_size = 0.01
		_aura.scale = Vector3(1.8, 1.8, 1.0)
		_aura.modulate = Color(0.65, 0.35, 1.0, 0.12)
		_aura.position = Vector3(0, 0.6, 0)
		_aura.no_depth_test = true
		add_child(_aura)

	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var white_tex := ImageTexture.create_from_image(white)
	_hp_bg = Sprite3D.new()
	_hp_bg.texture = white_tex
	_hp_bg.pixel_size = 0.01
	_hp_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bg.centered = false
	_hp_bg.no_depth_test = true
	_hp_bg.modulate = Color(0.02, 0.02, 0.03, 0.8)
	_hp_bg.position = Vector3(-0.36, 1.35, 0)
	_hp_bg.scale = Vector3(0.72, 0.075, 1.0)
	add_child(_hp_bg)
	_hp_fill = Sprite3D.new()
	_hp_fill.texture = white_tex
	_hp_fill.pixel_size = 0.01
	_hp_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_fill.centered = false
	_hp_fill.no_depth_test = true
	_hp_fill.modulate = Color(0.95, 0.32, 0.24)
	_hp_fill.position = Vector3(-0.34, 1.355, 0)
	_hp_fill.scale = Vector3(0.68, 0.045, 1.0)
	add_child(_hp_fill)

	if shadow_texture != null:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.9, 0.9)
		var shadow_mat := StandardMaterial3D.new()
		shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_mat.albedo_texture = shadow_texture
		shadow_mat.albedo_color = Color(0, 0, 0, 0.5)
		shadow_mat.disable_receive_shadows = true
		quad.material = shadow_mat
		var shadow := MeshInstance3D.new()
		shadow.mesh = quad
		shadow.material_override = shadow_mat
		shadow.rotation.x = -PI * 0.5
		shadow.position = Vector3(0, 0.025, 0)
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shadow)

	_update_health_bar()

func _update_health_bar() -> void:
	if _hp_fill == null:
		return
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_fill.scale.x = 0.68 * ratio
	_hp_fill.visible = ratio > 0.001

func _spawn_damage_number(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = ThemeDB.fallback_font
	label.font_size = 64
	label.pixel_size = 0.004
	label.outline_size = 10
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = global_position + Vector3(0, 1.25, 0)
	get_parent().add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.8, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)

func _spawn_flash(color: Color, size: float) -> void:
	if halo_texture == null:
		return
	var sprite := Sprite3D.new()
	sprite.texture = halo_texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.pixel_size = 0.01
	sprite.modulate = color
	sprite.position = global_position + Vector3(0, 0.7, 0)
	get_parent().add_child(sprite)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", Vector3.ONE * size, 0.25)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(sprite.queue_free)

func _sphere(parent: Node3D, pos: Vector3, radius: float, material: Material,
		radial := 8, rings := 4) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial
	mesh.rings = rings
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node3D, pos: Vector3, top_radius: float, bottom_radius: float,
		height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance
