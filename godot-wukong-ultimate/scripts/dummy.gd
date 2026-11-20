extends StaticBody3D
class_name StoneSentinel

## Stone sentinel training dummy: bulky, slow telegraph, punishable pulse.
## HP, recoil, collapse and the warning ring all live here.

signal hit_taken(amount: int, world_pos: Vector3, dir: Vector3)
signal hp_changed(hp: int, max_hp: int)
signal defeated
signal pulse_telegraph
signal pulse_hit

const MAX_HP := 240
const PULSE_RADIUS := 3.4
const PULSE_DAMAGE := 14

var hp := MAX_HP
var max_hp := MAX_HP
var ai_enabled := true
var is_defeated := false
var player: WukongPlayer
var stone_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var gold_material: StandardMaterial3D
var rune_material: StandardMaterial3D

var visual: Node3D
var core: MeshInstance3D
var core_light: OmniLight3D
var warning_ring: MeshInstance3D
var rune_ring: MeshInstance3D
var eye_glow: MeshInstance3D

var _home := Vector3.ZERO
var _cooldown := 2.4
var _telegraphing := false
var _telegraph_t := 0.0
var _bob := 0.0
var _hit_tween: Tween
var _collapse_tween: Tween


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	_home = global_position
	_build_materials()
	_build_body()
	_build_signals()
	hp_changed.emit(hp, max_hp)
	add_to_group("dummy")


func _build_materials() -> void:
	if stone_material == null:
		stone_material = StandardMaterial3D.new()
		stone_material.albedo_color = Color(0.18, 0.21, 0.30)
		stone_material.roughness = 0.8
	if dark_material == null:
		dark_material = StandardMaterial3D.new()
		dark_material.albedo_color = Color(0.08, 0.10, 0.16)
		dark_material.roughness = 0.9
		dark_material.metallic = 0.15
		dark_material.rim_enabled = true
		dark_material.rim = 0.35
	if gold_material == null:
		gold_material = StandardMaterial3D.new()
		gold_material.albedo_color = Color(0.80, 0.52, 0.16)
		gold_material.metallic = 0.5
		gold_material.roughness = 0.35


func _build_body() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.45, 2.25, 0.95)
	col.shape = box
	col.position = Vector3(0, 1.12, 0)
	add_child(col)

	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	var pedestal := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.90
	cm.bottom_radius = 1.05
	cm.height = 0.20
	cm.radial_segments = 12
	pedestal.mesh = cm
	pedestal.material_override = dark_material
	pedestal.position.y = 0.10
	visual.add_child(pedestal)

	_add_box(Vector3(0, 1.18, 0), Vector3(1.00, 1.10, 0.68), stone_material, 0.05)
	_add_box(Vector3(0, 1.72, 0.02), Vector3(0.62, 0.45, 0.52), stone_material, 0.04)
	_add_box(Vector3(0, 1.94, 0.0), Vector3(0.50, 0.28, 0.48), dark_material, 0.03)
	_add_box(Vector3(0, 1.18, 0.36), Vector3(0.52, 0.58, 0.10), dark_material, 0.02)
	_add_box(Vector3(0, 1.63, 0.28), Vector3(0.42, 0.06, 0.05), dark_material, 0.01)

	for sx in [-1.0, 1.0]:
		_add_box(Vector3(sx * 0.63, 1.52, 0.0), Vector3(0.30, 0.30, 0.34), dark_material, 0.04)
		var arm := MeshInstance3D.new()
		var acm := CylinderMesh.new()
		acm.top_radius = 0.13
		acm.bottom_radius = 0.16
		acm.height = 0.72
		acm.radial_segments = 8
		arm.mesh = acm
		arm.material_override = stone_material
		arm.position = Vector3(sx * 0.68, 1.06, 0.0)
		arm.rotation.z = sx * 0.16
		visual.add_child(arm)
		_add_box(Vector3(sx * 0.72, 0.65, 0.04), Vector3(0.28, 0.26, 0.30), dark_material, 0.04)
		var leg := MeshInstance3D.new()
		var lcm := CylinderMesh.new()
		lcm.top_radius = 0.16
		lcm.bottom_radius = 0.20
		lcm.height = 0.48
		lcm.radial_segments = 8
		leg.mesh = lcm
		leg.material_override = dark_material
		leg.position = Vector3(sx * 0.28, 0.38, 0.0)
		visual.add_child(leg)

	# chest core + eye slit (orange rune)
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1.0, 0.55, 0.18)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.42, 0.10)
	core_mat.emission_energy_multiplier = 2.8
	core = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 16
	sm.rings = 8
	core.mesh = sm
	core.material_override = core_mat
	core.position = Vector3(0, 1.22, 0.39)
	visual.add_child(core)

	eye_glow = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.34, 0.05, 0.05)
	eye_glow.mesh = bm
	eye_glow.material_override = core_mat
	eye_glow.position = Vector3(0, 1.77, 0.27)
	visual.add_child(eye_glow)

	core_light = OmniLight3D.new()
	core_light.light_color = Color(1.0, 0.45, 0.12)
	core_light.light_energy = 0.8
	core_light.omni_range = 4.5
	core_light.position = Vector3(0, 1.25, 0.5)
	core_light.shadow_enabled = false
	visual.add_child(core_light)

	# gold waist band
	var band := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.48
	tm.outer_radius = 0.56
	tm.rings = 40
	tm.ring_segments = 8
	band.mesh = tm
	band.material_override = gold_material
	band.position = Vector3(0, 1.02, 0)
	visual.add_child(band)

	# floating rune halo
	rune_ring = MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.74
	rm.outer_radius = 0.80
	rm.rings = 36
	rm.ring_segments = 8
	rune_ring.mesh = rm
	rune_ring.material_override = _rune_material(Color(0.36, 0.70, 1.0))
	rune_ring.position = Vector3(0, 2.42, 0)
	visual.add_child(rune_ring)

	# soft blob shadow
	var blob := MeshInstance3D.new()
	var blob_mesh := CylinderMesh.new()
	blob_mesh.top_radius = 0.95
	blob_mesh.bottom_radius = 1.05
	blob_mesh.height = 0.012
	blob_mesh.radial_segments = 20
	blob.mesh = blob_mesh
	var blob_mat := StandardMaterial3D.new()
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.38)
	blob_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blob_mat.disable_receive_shadows = true
	blob.material_override = blob_mat
	blob.position.y = 0.016
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)

	# warning ring on the floor
	warning_ring = MeshInstance3D.new()
	var wm := TorusMesh.new()
	wm.inner_radius = PULSE_RADIUS - 0.10
	wm.outer_radius = PULSE_RADIUS + 0.02
	wm.rings = 64
	wm.ring_segments = 8
	warning_ring.mesh = wm
	warning_ring.material_override = _rune_material(Color(1.0, 0.35, 0.12))
	warning_ring.position.y = 0.04
	warning_ring.visible = false
	add_child(warning_ring)


func _add_box(pos: Vector3, size: Vector3, mat: Material, bevel: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	# fake bevel with a slightly smaller dark cap
	visual.add_child(mi)
	if bevel > 0.0:
		var cap := MeshInstance3D.new()
		var cbm := BoxMesh.new()
		cbm.size = Vector3(size.x + 0.02, 0.03, size.z + 0.02)
		cap.mesh = cbm
		cap.material_override = dark_material
		cap.position = pos + Vector3(0, size.y * 0.5, 0)
		visual.add_child(cap)
	return mi


func _rune_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, 0.9)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	m.disable_receive_shadows = true
	return m


func _build_signals() -> void:
	pass


func _process(delta: float) -> void:
	_bob += delta
	if visual != null:
		visual.position.y = sin(_bob * 1.3) * 0.018 if not is_defeated else visual.position.y
	if rune_ring != null and not is_defeated:
		rune_ring.rotation.y += delta * 0.9
		rune_ring.position.y = 2.42 + sin(_bob * 1.7) * 0.05
	if is_defeated:
		return
	if _telegraphing:
		_telegraph_t -= delta
		var grow := clampf(1.0 - _telegraph_t / 1.15, 0.0, 1.0)
		warning_ring.scale = Vector3(0.25 + grow * 0.75, 1.0, 0.25 + grow * 0.75)
		warning_ring.visible = true
		core_light.light_energy = 0.8 + 4.5 * (0.5 + 0.5 * sin(_bob * 24.0))
		if _telegraph_t <= 0.0:
			_execute_pulse()
		else:
			return
	if not ai_enabled:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		if player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < 8.0:
			start_pulse()
		else:
			_cooldown = 0.8


func start_pulse() -> void:
	if is_defeated or _telegraphing:
		return
	_telegraphing = true
	_telegraph_t = 1.15
	_cooldown = 6.6
	warning_ring.visible = true
	warning_ring.scale = Vector3(0.25, 1.0, 0.25)
	pulse_telegraph.emit()
	# audio-free warning: the light and ring are the tell


func _execute_pulse() -> void:
	_telegraphing = false
	warning_ring.visible = false
	core_light.light_energy = 0.8
	if player != null and is_instance_valid(player):
		var d := global_position.distance_to(player.global_position)
		if d <= PULSE_RADIUS:
			player.take_damage(PULSE_DAMAGE, global_position)
			pulse_hit.emit()
	_spawn_shock_ring()


func _spawn_shock_ring() -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.8
	tm.outer_radius = 0.95
	tm.rings = 48
	tm.ring_segments = 8
	ring.mesh = tm
	var mat := _rune_material(Color(1.0, 0.35, 0.12))
	mat.emission_energy_multiplier = 2.0
	ring.material_override = mat
	ring.position = Vector3(0, 0.07, 0)
	ring.scale = Vector3(0.4, 1.0, 0.4)
	add_child(ring)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(3.5, 1.0, 3.5), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.42)
	tw.chain().tween_callback(ring.queue_free)


func take_hit(amount: int, dir: Vector3, world_pos: Vector3) -> void:
	if is_defeated:
		return
	hp = maxi(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	hit_taken.emit(amount, world_pos, dir)
	core_light.light_energy = 3.5
	var tw := create_tween()
	tw.tween_property(core_light, "light_energy", 0.8, 0.35)
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	visual.position = Vector3.ZERO
	_hit_tween = create_tween()
	var knock := Vector3(dir.x, 0, dir.z).normalized() * 0.22
	_hit_tween.set_parallel(true)
	_hit_tween.tween_property(visual, "position", knock, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(visual, "rotation", Vector3(0, 0, -0.08), 0.09)
	_hit_tween.chain().tween_property(visual, "position", Vector3.ZERO, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hit_tween.chain().tween_property(visual, "rotation", Vector3.ZERO, 0.25)
	if hp <= 0:
		_defeat()


func _defeat() -> void:
	if is_defeated:
		return
	is_defeated = true
	ai_enabled = false
	_telegraphing = false
	warning_ring.visible = false
	hp = 0
	hp_changed.emit(hp, max_hp)
	if _collapse_tween != null and _collapse_tween.is_valid():
		_collapse_tween.kill()
	_collapse_tween = create_tween().set_parallel(true)
	_collapse_tween.tween_property(visual, "rotation", Vector3(0.15, 0.0, 1.35), 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	_collapse_tween.tween_property(visual, "position", Vector3(-0.25, -0.52, 0), 0.65)
	_collapse_tween.tween_property(core_light, "light_energy", 0.0, 0.4)
	_collapse_tween.tween_property(core, "scale", Vector3(0.1, 0.1, 0.1), 0.5)
	await get_tree().create_timer(0.55).timeout
	defeated.emit()


func force_defeat() -> void:
	if is_defeated:
		return
	hp = 1
	take_hit(999, Vector3.BACK, global_position + Vector3(0, 1.1, 0.4))


func reset_state() -> void:
	hp = MAX_HP
	is_defeated = false
	ai_enabled = true
	_telegraphing = false
	_telegraph_t = 0.0
	_cooldown = 2.4
	global_position = _home
	position = _home
	if visual != null:
		visual.position = Vector3.ZERO
		visual.rotation = Vector3.ZERO
		visual.scale = Vector3.ONE
	if core != null:
		core.scale = Vector3.ONE
	if core_light != null:
		core_light.light_energy = 0.8
	if warning_ring != null:
		warning_ring.visible = false
	hp_changed.emit(hp, max_hp)


func trigger_pulse_now() -> void:
	start_pulse()
	_telegraph_t = 0.01
