class_name MistHouse
extends Node3D
## 岛民房屋：被海掠者攻击后掉血、起火，归零即焚毁。房屋全部焚毁 = 防线失败。

const Models = preload("res://scripts/models.gd")
const Balance = preload("res://scripts/balance.gd")
const UI = preload("res://scripts/ui_style.gd")

var game
var house_index := 0
var hp := Balance.HOUSE_HP
var max_hp := Balance.HOUSE_HP
var destroyed := false
var variant := 0
var _label: Label3D
var _light: OmniLight3D
var _fire: CPUParticles3D
var _smoke: CPUParticles3D
var _window_mat: StandardMaterial3D
var _body: MeshInstance3D
var _windows: MeshInstance3D
var _damage_flash := 0.0


func configure(game_ref, index: int, world_pos: Vector3, yaw_deg: float, mesh_variant: int) -> void:
	game = game_ref
	house_index = index
	variant = mesh_variant
	max_hp = Balance.HOUSE_HP
	hp = max_hp
	position = world_pos
	rotation_degrees.y = yaw_deg
	name = "House%d" % index

	var blob := Models.make_disc(3.4, Color(0.06, 0.09, 0.06), 0.22)
	blob.name = "GroundShadow"
	blob.position.y = 0.06
	add_child(blob)

	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = Models.house_mesh(variant)
	_body.material_override = Models.unit_material()
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_body)

	_window_mat = StandardMaterial3D.new()
	_window_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_window_mat.albedo_color = Color("f6c66e")
	_window_mat.emission_enabled = true
	_window_mat.emission = Color("f0a94e")
	_window_mat.emission_energy_multiplier = 1.2
	_windows = MeshInstance3D.new()
	_windows.name = "Windows"
	_windows.mesh = Models.house_window_mesh(variant)
	_windows.material_override = _window_mat
	_windows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_windows)

	_light = OmniLight3D.new()
	_light.name = "WarmLight"
	_light.position = Vector3(0, 1.7, -1.9)
	_light.light_color = Color("f0b46a")
	_light.light_energy = 0.55
	_light.omni_range = 6.0
	_light.shadow_enabled = false
	add_child(_light)

	_build_fire()

	_label = Models.make_label("房屋 %d / %d" % [int(hp), int(max_hp)], 46, Color("f3e8cc"))
	_label.pixel_size = 0.010
	_label.position = Vector3(0, 5.7, 0)
	_label.visible = false
	add_child(_label)


func _build_fire() -> void:
	_fire = CPUParticles3D.new()
	_fire.name = "Fire"
	_fire.position = Vector3(0.4, 3.2, 0.2)
	_fire.amount = 28
	_fire.lifetime = 1.1
	_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fire.emission_sphere_radius = 1.2
	_fire.direction = Vector3(0, 1, 0)
	_fire.spread = 22.0
	_fire.initial_velocity_min = 0.9
	_fire.initial_velocity_max = 2.4
	_fire.gravity = Vector3(0, 1.6, 0)
	_fire.scale_amount_min = 0.22
	_fire.scale_amount_max = 0.55
	_fire.color = Color("ffb35c")
	_fire.mesh = _particle_quad(Color("ff9d4f"), 0.8)
	_fire.emitting = false
	add_child(_fire)

	_smoke = CPUParticles3D.new()
	_smoke.name = "Smoke"
	_smoke.position = Vector3(0.2, 3.9, 0.1)
	_smoke.amount = 11
	_smoke.lifetime = 2.6
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 1.5
	_smoke.direction = Vector3(0, 1, 0)
	_smoke.spread = 18.0
	_smoke.initial_velocity_min = 0.5
	_smoke.initial_velocity_max = 1.2
	_smoke.gravity = Vector3(0.15, 0.7, 0)
	_smoke.scale_amount_min = 0.9
	_smoke.scale_amount_max = 2.1
	_smoke.color = Color(0.28, 0.30, 0.28, 0.25)
	_smoke.mesh = _particle_quad(Color(0.32, 0.34, 0.32, 0.28), 0.4)
	_smoke.amount = 5
	_smoke.emitting = true
	add_child(_smoke)


func _particle_quad(color: Color, alpha: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.albedo_texture = Models.soft_particle_texture()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	quad.material = mat
	return quad


func take_damage(amount: float, source_pos := Vector3.ZERO) -> void:
	if destroyed:
		return
	var before := hp
	hp = maxf(0.0, hp - maxf(0.0, amount))
	_damage_flash = 0.18
	if hp < max_hp:
		_label.visible = true
		_fire.emitting = true
		_smoke.emitting = true
		_smoke.amount = 12
		_smoke.color = Color(0.28, 0.30, 0.28, 0.42)
		_light.light_energy = 0.75
	if _label != null:
		_label.text = "房屋 %d / %d" % [int(ceil(hp)), int(max_hp)]
		var ratio := clampf(hp / max_hp, 0.0, 1.0)
		_label.modulate = Color("f3e8cc").lerp(Color("ffb06a"), 1.0 - ratio)
	if game != null and before > hp:
		game.on_house_damaged(self, before - hp)
	if hp <= 0.0:
		_destroy()


func _destroy() -> void:
	destroyed = true
	_fire.amount = 46
	_fire.emitting = true
	_smoke.amount = 24
	_smoke.emitting = true
	_smoke.lifetime = 3.4
	_light.light_energy = 0.0
	_windows.visible = false
	_label.text = "已成焦土"
	_label.modulate = Color("d9a06a")
	if _body != null:
		var charred := Models.unit_material().duplicate() as StandardMaterial3D
		charred.vertex_color_use_as_albedo = true
		charred.albedo_color = Color(0.36, 0.33, 0.30)
		_body.material_override = charred
	if game != null:
		game.on_house_destroyed(self)


func get_top_position() -> Vector3:
	return global_position + Vector3(0, 5.2, 0)


func get_damage_ratio() -> float:
	return 1.0 - clampf(hp / max_hp, 0.0, 1.0)


func _process(delta: float) -> void:
	if _damage_flash > 0.0:
		_damage_flash = maxf(0.0, _damage_flash - delta)
		if _body != null and not destroyed:
			var pulse := _damage_flash / 0.18
			_body.scale = Vector3.ONE * (1.0 + pulse * 0.025)
	elif _body != null and not destroyed and _body.scale != Vector3.ONE:
		_body.scale = Vector3.ONE
