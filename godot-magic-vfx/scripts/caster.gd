class_name MagicCaster
extends Node3D

# Original low-poly mage: dark robe, deep hood, glowing eyes, wooden staff with
# a floating crystal, charge rune circle and converging motes. Everything is
# built from primitives in code (no external models).

var main: Node
var spell: Dictionary = {}
var rig: Node3D
var staff_pivot: Node3D
var crystal: MeshInstance3D
var crystal_mat: StandardMaterial3D
var halo: MeshInstance3D
var halo_mat: StandardMaterial3D
var muzzle: Marker3D
var staff_light: OmniLight3D
var rune_root: Node3D
var rune_a: MeshInstance3D
var rune_b: MeshInstance3D
var rune_mat_a: ShaderMaterial
var rune_mat_b: ShaderMaterial
var charge_motes: GPUParticles3D
var muzzle_burst: GPUParticles3D
var muzzle_flash: MeshInstance3D
var muzzle_flash_mat: StandardMaterial3D
var eyes: Array[MeshInstance3D] = []
var accent_meshes: Array[MeshInstance3D] = []
var accent_mats: Array[StandardMaterial3D] = []
var orbiters: Array[MeshInstance3D] = []

var charging := false
var charge := 0.0
var _clock := 0.0
var _cast_time := 0.0
var _cast_dur := 0.32
var _aim_z := 0.0
var _base_staff_rot := -0.52
var _muzzle_flash_life := 0.0
var _crystal_base := Vector3(0.17, 0.26, 0.17)

func setup(p_main: Node) -> void:
	main = p_main
	_clock = randf() * 10.0
	_build()

func set_spell(p_spell: Dictionary) -> void:
	spell = p_spell
	var accent: Color = spell.accent
	var hot: Color = spell.hot
	for m in accent_mats:
		if m:
			m.albedo_color = accent.darkened(0.3)
			m.emission = accent
			m.emission_energy_multiplier = 1.15
	if crystal_mat:
		crystal_mat.albedo_color = hot
		crystal_mat.emission = spell.mid
		crystal_mat.emission_energy_multiplier = 3.2
	if halo_mat:
		halo_mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.5)
	if staff_light:
		staff_light.light_color = accent
	if rune_mat_a:
		rune_mat_a.set_shader_parameter("tint", Color(accent.r, accent.g, accent.b, 1.0))
	if rune_mat_b:
		rune_mat_b.set_shader_parameter("tint", Color(hot.r, hot.g, hot.b, 1.0))
	if charge_motes:
		_apply_mote_colors()
	if muzzle_burst:
		_apply_burst_colors()
	for e in eyes:
		var em := e.material_override as StandardMaterial3D
		if em:
			em.emission = hot
			em.albedo_color = hot

func set_charging(v: bool) -> void:
	charging = v
	if charge_motes:
		charge_motes.emitting = v
	if not v:
		charge = 0.0
		_apply_charge_visuals()
	if halo_mat:
		halo_mat.albedo_color.a = 0.16 + charge * 0.38

func set_charge(p: float) -> void:
	charge = clampf(p, 0.0, 1.0)
	_apply_charge_visuals()

func aim_at(point: Vector3) -> void:
	var d := point - global_position
	_aim_z = clampf(atan2(-d.z, maxf(d.x, 0.001)), -0.4, 0.4)

func get_muzzle_position() -> Vector3:
	return muzzle.global_position if muzzle else global_position + Vector3(0.8, 2.3, 0.3)

func play_cast(power: float) -> void:
	_cast_time = _cast_dur
	_muzzle_flash_life = 0.14
	if muzzle_burst:
		muzzle_burst.restart()
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_flash.scale = Vector3.ONE * (0.5 + 0.6 * power)
	if staff_light:
		staff_light.light_energy = 4.0 + 5.0 * power

func _process(delta: float) -> void:
	_clock += delta
	# idle motion
	var bob := sin(_clock * 1.7) * 0.014
	rig.position.y = bob
	rig.rotation.z = sin(_clock * 0.8) * 0.008
	rig.rotation.y = lerpf(rig.rotation.y, _aim_z, 1.0 - exp(-8.0 * delta))

	if staff_pivot:
		var base := _base_staff_rot - 0.10 * charge
		if _cast_time > 0.0:
			_cast_time = maxf(0.0, _cast_time - delta)
			var k := 1.0 - _cast_time / _cast_dur
			base += sin(k * PI) * -0.45
		staff_pivot.rotation.z = lerpf(staff_pivot.rotation.z, base, 1.0 - exp(-24.0 * delta))
		staff_pivot.rotation.x = sin(_clock * 1.3) * 0.02

	if crystal:
		var cs := 1.0 + charge * 0.45 + sin(_clock * 3.0) * 0.02
		crystal.scale = _crystal_base * cs
		crystal.rotation.y += delta * (0.6 + charge * 3.0)
	if halo:
		var hs := (1.0 + charge * 0.55) * (0.95 + 0.06 * sin(_clock * 5.0))
		halo.scale = Vector3(hs, hs, hs)
		halo.rotation.z += delta * 0.6
	if staff_light:
		var target := 0.9 + charge * 4.2
		if _cast_time > 0.0:
			target += sin((1.0 - _cast_time / _cast_dur) * PI) * 3.0
		staff_light.light_energy = lerpf(staff_light.light_energy, target, 1.0 - exp(-10.0 * delta))
	if rune_root:
		rune_root.rotation.y += delta * (0.15 + charge * 0.7)
	if rune_mat_a:
		rune_mat_a.set_shader_parameter("spin", _clock * 0.25)
	if rune_mat_b:
		rune_mat_b.set_shader_parameter("spin", -_clock * 0.4)

	for i in orbiters.size():
		var o: MeshInstance3D = orbiters[i]
		if o:
			var a := _clock * (1.2 + charge * 2.2) + TAU * float(i) / float(orbiters.size())
			var rad := 0.34 + charge * 0.14
			o.position = crystal.position + Vector3(cos(a) * rad * 0.8, sin(a * 1.3) * 0.08, sin(a) * rad)
			var os := clampf(charge * 2.0 - 0.2, 0.001, 1.0)
			o.scale = Vector3(0.024, 0.075, 0.024) * os
			o.rotation.y += delta * 2.0

	if _muzzle_flash_life > 0.0 and muzzle_flash:
		_muzzle_flash_life = maxf(0.0, _muzzle_flash_life - delta)
		var k2 := clampf(_muzzle_flash_life / 0.14, 0.0, 1.0)
		muzzle_flash.scale = Vector3.ONE * (1.4 - k2 * 0.8)
		if muzzle_flash_mat:
			var fc: Color = muzzle_flash_mat.albedo_color
			muzzle_flash_mat.albedo_color = Color(fc.r, fc.g, fc.b, 0.9 * k2)
		if _muzzle_flash_life <= 0.0:
			muzzle_flash.visible = false

func _apply_charge_visuals() -> void:
	if charge_motes:
		charge_motes.amount_ratio = clampf(0.12 + charge * 0.88, 0.0, 1.0)
	if rune_mat_a:
		rune_mat_a.set_shader_parameter("alpha", 0.07 + charge * 0.6)
	if rune_mat_b:
		rune_mat_b.set_shader_parameter("alpha", 0.04 + charge * 0.35)
	if crystal_mat:
		crystal_mat.emission_energy_multiplier = 2.4 + charge * 4.5
	if halo_mat:
		halo_mat.albedo_color.a = 0.16 + charge * 0.38
	for e in eyes:
		if e and e.material_override:
			(e.material_override as StandardMaterial3D).emission_energy_multiplier = 2.5 + charge * 6.0

# ── build ────────────────────────────────────────────────────────────────────

func _build() -> void:
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)

	var robe := _mat(Color(0.175, 0.14, 0.30), 0.88)
	var robe_light := _mat(Color(0.24, 0.19, 0.40), 0.82)
	var leather := _mat(Color(0.09, 0.075, 0.12), 0.92)
	var wood := _mat(Color(0.32, 0.21, 0.13), 0.75)
	var gold := _mat(Color(0.56, 0.42, 0.22), 0.42, 0.6)

	# feet / robe / mantle
	_mesh(rig, BoxMesh.new(), leather, Vector3(0.12, 0.05, 0.16), Vector3(0.06, 0.05, -0.14))
	_mesh(rig, BoxMesh.new(), leather, Vector3(0.12, 0.05, 0.16), Vector3(0.06, 0.05, 0.14))
	var robe_mesh := CylinderMesh.new()
	robe_mesh.top_radius = 0.26
	robe_mesh.bottom_radius = 0.62
	robe_mesh.height = 1.18
	robe_mesh.radial_segments = 16
	_mesh(rig, robe_mesh, robe, Vector3.ONE, Vector3(0.0, 0.63, 0.0))
	var mantle := CylinderMesh.new()
	mantle.top_radius = 0.33
	mantle.bottom_radius = 0.5
	mantle.height = 0.3
	mantle.radial_segments = 16
	_mesh(rig, mantle, robe_light, Vector3.ONE, Vector3(0.0, 1.3, 0.0))
	# belt + gem
	var belt := CylinderMesh.new()
	belt.top_radius = 0.34
	belt.bottom_radius = 0.36
	belt.height = 0.07
	belt.radial_segments = 16
	_mesh(rig, belt, leather, Vector3.ONE, Vector3(0.0, 1.02, 0.0))
	_mesh(rig, SphereMesh.new(), gold, Vector3(0.09, 0.12, 0.06), Vector3(0.31, 1.02, 0.0))
	var belt_gem := _mesh(rig, SphereMesh.new(), _accent_mat(Color.WHITE), Vector3(0.045, 0.06, 0.03), Vector3(0.36, 1.02, 0.0))
	accent_meshes.append(belt_gem)

	# arms: a sleeve reaching for the staff + a hanging off-hand
	var sleeve := CapsuleMesh.new()
	sleeve.radius = 0.075
	sleeve.height = 0.62
	var arm := _mesh(rig, sleeve, robe_light, Vector3.ONE, Vector3(0.16, 1.22, 0.2))
	arm.rotation.z = -0.72
	var hand := _mesh(rig, SphereMesh.new(), leather, Vector3(0.075, 0.09, 0.075), Vector3(0.18, 1.13, 0.28))
	var sleeve2 := CapsuleMesh.new()
	sleeve2.radius = 0.06
	sleeve2.height = 0.55
	var arm2 := _mesh(rig, sleeve2, robe, Vector3.ONE, Vector3(-0.02, 1.16, -0.24))
	arm2.rotation.z = -0.18
	arm2.rotation.x = -0.2
	var aura := _make_billboard(load("res://assets/textures/glow.png"), 2.4)
	var aura_mat := aura.material_override as StandardMaterial3D
	aura_mat.albedo_color = Color(0.45, 0.35, 0.9, 0.28)
	aura.position = Vector3(-0.15, 1.5, -0.65)
	rig.add_child(aura)

	# head / hood
	var head := _mesh(rig, SphereMesh.new(), robe, Vector3(0.19, 0.36, 0.2), Vector3(0.04, 1.55, 0.0))
	var face := _mesh(rig, SphereMesh.new(), leather, Vector3(0.13, 0.2, 0.14), Vector3(0.17, 1.54, 0.0))
	var hood := CylinderMesh.new()
	hood.top_radius = 0.02
	hood.bottom_radius = 0.27
	hood.height = 0.42
	hood.radial_segments = 12
	var hood_mi := _mesh(rig, hood, robe_light, Vector3.ONE, Vector3(-0.04, 1.74, 0.0))
	hood_mi.rotation.z = 0.16
	for z in [-0.07, 0.07]:
		var eye := _mesh(rig, SphereMesh.new(), _emissive_mat(Color.WHITE, 2.5), Vector3(0.022, 0.034, 0.024), Vector3(0.27, 1.56, z))
		eyes.append(eye)

	# cloak tail + shoulder pad
	var cape := BoxMesh.new()
	cape.size = Vector3(0.05, 0.9, 0.46)
	var cape_mi := _mesh(rig, cape, robe, Vector3.ONE, Vector3(-0.3, 0.78, 0.0))
	cape_mi.rotation.z = 0.18
	var sz := SphereMesh.new()
	_mesh(rig, sz, robe_light, Vector3(0.24, 0.16, 0.26), Vector3(0.0, 1.36, 0.0))

	# staff
	staff_pivot = Node3D.new()
	staff_pivot.name = "StaffPivot"
	staff_pivot.position = Vector3(0.16, 1.12, 0.28)
	staff_pivot.rotation.z = _base_staff_rot
	rig.add_child(staff_pivot)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.028
	shaft.bottom_radius = 0.035
	shaft.height = 2.0
	shaft.radial_segments = 8
	_mesh(staff_pivot, shaft, wood, Vector3.ONE, Vector3(0.0, 0.5, 0.0))
	for y in [-0.42, 0.12, 0.86]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.03
		ring.outer_radius = 0.052
		ring.rings = 8
		ring.ring_segments = 6
		_mesh(staff_pivot, ring, gold, Vector3.ONE, Vector3(0.0, y, 0.0))
	crystal_mat = _emissive_mat(Color.WHITE, 3.2)
	crystal = _mesh(staff_pivot, SphereMesh.new(), crystal_mat, _crystal_base, Vector3(0.0, 1.54, 0.0))
	crystal.rotation = Vector3(0.3, 0.6, 0.2)
	# halo billboard
	halo = _make_billboard(load("res://assets/textures/glow.png"), 0.72)
	halo_mat = halo.material_override as StandardMaterial3D
	halo.position = Vector3(0.0, 1.54, 0.0)
	staff_pivot.add_child(halo)
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 1.54, 0.0)
	staff_pivot.add_child(muzzle)

	# orbiting shards
	for i in 3:
		var shard := _mesh(staff_pivot, PrismMesh.new(), _accent_mat(Color.WHITE), Vector3(0.025, 0.11, 0.025), Vector3(0.0, 1.54, 0.0))
		shard.scale = Vector3.ONE * 0.001
		orbiters.append(shard)

	staff_light = OmniLight3D.new()
	staff_light.light_color = Color(1.0, 0.8, 0.5)
	staff_light.light_energy = 0.9
	staff_light.omni_range = 4.5
	staff_light.omni_attenuation = 1.6
	staff_light.shadow_enabled = false
	staff_light.position = Vector3(0.0, 1.54, 0.0)
	staff_pivot.add_child(staff_light)

	_build_rune_circle()
	_build_charge_motes()
	_build_muzzle_fx()

	# contact shadow
	var shadow := _make_billboard(load("res://assets/textures/contact_shadow.png"), 1.7)
	var smat := shadow.material_override as StandardMaterial3D
	smat.albedo_color = Color(0, 0, 0, 0.6)
	smat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	shadow.rotation.x = -PI / 2
	shadow.position = Vector3(0.0, 0.015, 0.0)
	add_child(shadow)

func _build_rune_circle() -> void:
	rune_root = Node3D.new()
	rune_root.name = "RuneCircle"
	rune_root.position = Vector3(0.0, 0.02, 0.0)
	add_child(rune_root)
	rune_mat_a = ShaderMaterial.new()
	rune_mat_a.shader = load("res://shaders/rune.gdshader")
	rune_mat_a.set_shader_parameter("rune_tex", load("res://assets/textures/rune.png"))
	rune_mat_a.set_shader_parameter("alpha", 0.07)
	rune_mat_a.set_shader_parameter("tint", Color(0.6, 0.4, 1.0, 1.0))
	rune_a = _make_ground_quad(3.6, rune_mat_a)
	rune_root.add_child(rune_a)
	rune_mat_b = ShaderMaterial.new()
	rune_mat_b.shader = load("res://shaders/rune.gdshader")
	rune_mat_b.set_shader_parameter("rune_tex", load("res://assets/textures/rune.png"))
	rune_mat_b.set_shader_parameter("alpha", 0.04)
	rune_mat_b.set_shader_parameter("tint", Color(1.0, 0.7, 0.4, 1.0))
	rune_b = _make_ground_quad(2.3, rune_mat_b)
	rune_b.position.y = 0.004
	rune_root.add_child(rune_b)

func _build_charge_motes() -> void:
	charge_motes = GPUParticles3D.new()
	charge_motes.name = "ChargeMotes"
	charge_motes.amount = 48
	charge_motes.lifetime = 0.7
	charge_motes.local_coords = false
	charge_motes.emitting = false
	charge_motes.amount_ratio = 0.12
	charge_motes.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	charge_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(0.085, 0.085)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load("res://assets/textures/spark.png")
	m.vertex_color_use_as_albedo = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	q.material = m
	charge_motes.draw_pass_1 = q
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.05
	pm.radial_accel_min = -9.0
	pm.radial_accel_max = -14.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.2
	pm.damping_min = 0.4
	pm.damping_max = 1.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.color_ramp = _ramp([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)], [0.0, 0.35, 1.0])
	charge_motes.process_material = pm
	charge_motes.add_to_group("magic_particles")
	muzzle.add_child(charge_motes)
	_apply_mote_colors()

func _build_muzzle_fx() -> void:
	muzzle_burst = GPUParticles3D.new()
	muzzle_burst.name = "MuzzleBurst"
	muzzle_burst.amount = 18
	muzzle_burst.lifetime = 0.35
	muzzle_burst.one_shot = true
	muzzle_burst.explosiveness = 1.0
	muzzle_burst.emitting = false
	muzzle_burst.local_coords = false
	muzzle_burst.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	muzzle_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load("res://assets/textures/spark.png")
	m.vertex_color_use_as_albedo = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	muzzle_burst.draw_pass_1 = q
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, 0.2, 0.0)
	pm.spread = 55.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0.0, -2.0, 0.0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.color_ramp = _ramp([Color(1, 1, 1, 1), Color(1, 0.8, 0.4, 0.8), Color(1, 0.4, 0.1, 0)], [0.0, 0.4, 1.0])
	muzzle_burst.process_material = pm
	muzzle_burst.add_to_group("magic_particles")
	muzzle.add_child(muzzle_burst)

	muzzle_flash = _make_billboard(load("res://assets/textures/flare.png"), 1.5)
	muzzle_flash.position = Vector3.ZERO
	muzzle_flash.visible = false
	muzzle_flash_mat = muzzle_flash.material_override as StandardMaterial3D
	muzzle.add_child(muzzle_flash)

func _apply_mote_colors() -> void:
	if spell.is_empty() or charge_motes == null:
		return
	var pm: ParticleProcessMaterial = charge_motes.process_material
	pm.color_ramp = _ramp([Color(spell.hot, 0.0), spell.hot, Color(spell.accent, 0.0)], [0.0, 0.4, 1.0])

func _apply_burst_colors() -> void:
	if spell.is_empty() or muzzle_burst == null:
		return
	var pm: ParticleProcessMaterial = muzzle_burst.process_material
	pm.color_ramp = _ramp([spell.hot, spell.mid, Color(spell.deep, 0.0)], [0.0, 0.4, 1.0])
	if muzzle_flash:
		var fs := muzzle_flash.material_override as StandardMaterial3D
		fs.albedo_color = Color(spell.hot.r, spell.hot.g, spell.hot.b, 0.85)

func _ramp(colors: Array, offsets: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex

# ── helpers ──────────────────────────────────────────────────────────────────

func _mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _emissive_mat(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _accent_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.2
	accent_mats.append(m)
	return m

func _mesh(parent: Node3D, mesh: Mesh, mat: Material, scl: Vector3, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.scale = scl
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _make_ground_quad(size: float, mat: Material) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.rotation.x = -PI / 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-size, -0.1, -size), Vector3(size * 2, 1, size * 2))
	return mi

func _make_billboard(tex: Texture2D, size: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.albedo_color = Color(1, 1, 1, 0.8)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
