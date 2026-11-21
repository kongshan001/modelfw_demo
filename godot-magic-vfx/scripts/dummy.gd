class_name TrainingDummy
extends Node3D

# Original wooden training dummy: base, post, crossbar, straw head, target
# discs. Hit reaction is a spring wobble + white flash + element light;
# three hits topple it, then it rebuilds itself.

const MAX_HP := 3

var main: Node
var index := 0
var hp := MAX_HP
var alive := true
var busy := false

var model: Node3D
var meshes: Array[MeshInstance3D] = []
var flash_mat: StandardMaterial3D
var _flash := 0.0
var _wobble := Vector2.ZERO
var _wobble_vel := Vector2.ZERO
var _hit_lights: Array[OmniLight3D] = []
var _hit_light_ttl: Array[float] = []
var _respawn_timer := -1.0
var _clock := 0.0
var _base_pos := Vector3.ZERO

func setup(p_main: Node, p_index: int, pos: Vector3) -> void:
	main = p_main
	index = p_index
	position = pos
	_base_pos = pos
	_clock = randf() * 10.0
	_build()

func get_chest_position() -> Vector3:
	return global_position + Vector3(-0.05, 1.12, 0.0)

func get_head_position() -> Vector3:
	return global_position + Vector3(0.0, 1.5, 0.0)

func take_hit(power: float, spell: Dictionary) -> bool:
	if not alive:
		return false
	hp -= 1
	_flash = 1.0
	_wobble_vel.y = -2.6 * (0.7 + 0.5 * power) * (1.0 + randf() * 0.25)
	_wobble_vel.x = randf_range(-0.7, 0.7)
	_spawn_hit_light(spell, power)
	if hp <= 0:
		_break_apart()
		return true
	# hit-stop-free, but a tiny squash sells the impact
	model.scale = Vector3(1.03, 0.96, 1.03)
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return false

func reset_state() -> void:
	alive = true
	hp = MAX_HP
	busy = false
	_respawn_timer = -1.0
	_flash = 0.0
	_wobble = Vector2.ZERO
	_wobble_vel = Vector2.ZERO
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	model.scale = Vector3.ONE
	visible = true
	_flash_apply(0.0)

func _break_apart() -> void:
	alive = false
	busy = true
	_respawn_timer = 3.4
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(model, "rotation:z", -1.45, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "position:y", -0.28, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		visible = false
	)

func _process(delta: float) -> void:
	_clock += delta
	# spring wobble
	_wobble_vel += -_wobble * 55.0 * delta
	_wobble_vel *= exp(-5.0 * delta)
	_wobble += _wobble_vel * delta
	if alive and not busy or (busy and _respawn_timer > 0.0):
		if alive:
			model.rotation.z = _wobble.y
			model.rotation.x = _wobble.x
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 9.0)
		_flash_apply(_flash)
	for i in range(_hit_lights.size() - 1, -1, -1):
		_hit_light_ttl[i] -= delta
		if _hit_light_ttl[i] <= 0.0:
			if is_instance_valid(_hit_lights[i]):
				_hit_lights[i].queue_free()
			_hit_lights.remove_at(i)
			_hit_light_ttl.remove_at(i)
		else:
			_hit_lights[i].light_energy = maxf(0.0, _hit_light_ttl[i] / 0.9) * 2.4
	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()

func _respawn() -> void:
	alive = true
	busy = false
	hp = MAX_HP
	visible = true
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	model.scale = Vector3(0.2, 0.2, 0.2)
	_flash = 1.0
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_hit_light(_spell: Dictionary, _power: float) -> void:
	# Impact lighting is handled by the pooled light in main (light-count stable).
	pass

func _flash_apply(amount: float) -> void:
	if flash_mat:
		flash_mat.albedo_color = Color(1.0, 0.78, 0.5, 0.16 * amount)

# ── build ────────────────────────────────────────────────────────────────────

func _build() -> void:
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1.0, 0.83, 0.6, 0)
	flash_mat.disable_receive_shadows = true

	var wood := _mat(Color(0.24, 0.16, 0.10), 0.9)
	var wood_dark := _mat(Color(0.14, 0.095, 0.06), 0.92)
	var straw := _mat(Color(0.62, 0.47, 0.25), 0.95)
	var rope := _mat(Color(0.74, 0.66, 0.46), 0.95)
	var red := _mat(Color(0.55, 0.13, 0.10), 0.8)
	var cream := _mat(Color(0.78, 0.70, 0.52), 0.85)

	var base := CylinderMesh.new()
	base.top_radius = 0.32
	base.bottom_radius = 0.38
	base.height = 0.12
	base.radial_segments = 12
	_add(model, base, wood_dark, Vector3.ZERO + Vector3(0, 0.06, 0))

	var post := CylinderMesh.new()
	post.top_radius = 0.07
	post.bottom_radius = 0.085
	post.height = 1.08
	post.radial_segments = 10
	_add(model, post, wood, Vector3(0, 0.65, 0))

	var bar := BoxMesh.new()
	bar.size = Vector3(0.92, 0.075, 0.075)
	var bar_mi := _add(model, bar, wood, Vector3(0, 1.22, 0))
	bar_mi.rotation.z = 0.03
	for x in [-0.46, 0.46]:
		var cap := SphereMesh.new()
		cap.radius = 0.055
		cap.height = 0.11
		_add(model, cap, wood, Vector3(x, 1.22, 0))

	var head := SphereMesh.new()
	head.radius = 0.165
	head.height = 0.34
	head.radial_segments = 12
	head.rings = 8
	_add(model, head, straw, Vector3(0, 1.47, 0))

	var torso := CylinderMesh.new()
	torso.top_radius = 0.155
	torso.bottom_radius = 0.175
	torso.height = 0.52
	torso.radial_segments = 12
	_add(model, torso, straw, Vector3(0, 0.96, 0))

	# rope wraps
	for y in [0.94, 1.10]:
		var wrap := CylinderMesh.new()
		wrap.top_radius = 0.185
		wrap.bottom_radius = 0.185
		wrap.height = 0.035
		wrap.radial_segments = 10
		_add(model, wrap, rope, Vector3(0, y, 0))

	# target discs, facing the caster (-X)
	var discs := [
		[0.255, 0.018, Color(0.55, 0.13, 0.10)],
		[0.175, 0.026, Color(0.78, 0.70, 0.52)],
		[0.095, 0.034, Color(0.55, 0.13, 0.10)],
	]
	for i in discs.size():
		var d: Array = discs[i]
		var disc := CylinderMesh.new()
		disc.top_radius = float(d[0])
		disc.bottom_radius = float(d[0])
		disc.height = float(d[1])
		disc.radial_segments = 18
		var mi := _add(model, disc, _mat(d[2], 0.8), Vector3(-0.195 - 0.012 * i, 1.12, 0))
		mi.rotation.z = PI / 2.0

	var shadow_q := QuadMesh.new()
	shadow_q.size = Vector2(1.5, 1.5)
	var shadow_m := StandardMaterial3D.new()
	shadow_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_m.albedo_texture = load("res://assets/textures/contact_shadow.png")
	shadow_m.albedo_color = Color(0, 0, 0, 0.62)
	shadow_m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	shadow_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow_q.material = shadow_m
	var shadow := MeshInstance3D.new()
	shadow.mesh = shadow_q
	shadow.rotation.x = -PI / 2
	shadow.position = Vector3(0, 0.02, 0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

	for m in meshes:
		m.material_overlay = flash_mat

func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	meshes.append(mi)
	return mi

func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
