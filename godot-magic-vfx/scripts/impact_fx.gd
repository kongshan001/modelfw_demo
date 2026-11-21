class_name ImpactFX
extends Node3D

# Impact package: flash, expanding rings, fire/smoke/spark bursts, embers, a
# short-lived light, scorch glow, arcane rune or frost mist. Frees itself and
# every child once the afterglow is done (no leaked emitters).

var main: Node
var spell: Dictionary = {}
var power := 1.0
var hit_point := Vector3.ZERO
var round_dummy := false
var _ttl := 3.6
var _runtime := 0.0
var debug_no_particles := false

func setup(p_main: Node, p_point: Vector3, p_spell: Dictionary, p_power: float, p_dummy_hit: bool) -> void:
	main = p_main
	spell = p_spell
	power = clampf(p_power, 0.5, 1.6)
	hit_point = p_point
	round_dummy = p_dummy_hit
	global_position = p_point
	add_to_group("magic_ephemeral")
	set_meta("ephemeral_until", Time.get_ticks_msec() / 1000.0 + 4.0)

	_build_flash()
	if main.has_method("flash_impact_light"):
		main.flash_impact_light(hit_point, spell, power)
	_build_rings()
	if not debug_no_particles:
		_build_bursts()
		_build_fire_core()
		_build_embers()
		_build_smoke()
	_build_scorch()
	if float(spell.impact_rune) > 0.5:
		_build_rune()
	if float(spell.mist) > 0.5 and not debug_no_particles:
		_build_mist()

func _process(delta: float) -> void:
	_runtime += delta
	_ttl -= delta
	if _ttl <= 0.0:
		queue_free()

# ── pieces ───────────────────────────────────────────────────────────────────

func _build_flash() -> void:
	var flare := _billboard(load("res://assets/textures/flare.png"), Color(spell.mid.r, spell.mid.g, spell.mid.b, 0.85), 2.2 * power)
	flare.name = "FlashFlare"
	add_child(flare)
	flare.scale = Vector3.ONE * 0.5
	var fm: StandardMaterial3D = flare.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flare, "scale", Vector3.ONE * (2.4 * power + 0.6), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fm, "albedo_color:a", 0.0, 0.26)

	var core := _billboard(load("res://assets/textures/glow.png"), Color(spell.hot.r, spell.hot.g, spell.hot.b, 0.7), 1.35 * power)
	core.name = "FlashCore"
	add_child(core)
	core.scale = Vector3.ONE * 0.7
	var cm: StandardMaterial3D = core.material_override as StandardMaterial3D
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(core, "scale", Vector3.ONE * 2.1, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(cm, "albedo_color:a", 0.0, 0.34)


func _build_rings() -> void:
	var ring_col: Color = spell.ring_color
	# camera-facing shock ring
	var ring := _billboard(load("res://assets/textures/ring.png"), Color(ring_col.r, ring_col.g, ring_col.b, 0.55), 2.1 * power)
	ring.name = "ShockRing"
	add_child(ring)
	ring.scale = Vector3.ONE * 0.3
	var rm: StandardMaterial3D = ring.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * (2.0 * power + 0.45), 0.38).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.42)
	# ground shockwave
	var gring := _ring_quad(ring_col, 3.1 * power)
	gring.name = "GroundRing"
	gring.position = Vector3(0.0, 0.03 - (hit_point.y - _ground_y()), 0.0)
	add_child(gring)
	gring.scale = Vector3.ONE * 0.25
	var gm: StandardMaterial3D = gring.material_override as StandardMaterial3D
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(gring, "scale", Vector3.ONE * (1.6 * power + 0.5), 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw2.tween_property(gm, "albedo_color:a", 0.0, 0.55)

func _build_bursts() -> void:
	var burst := _make_system("Burst", int(spell.burst), 0.62, load("res://assets/textures/smoke.png"), 1.25, true)
	var bp: ParticleProcessMaterial = burst.process_material
	bp.direction = Vector3(0, 1, 0)
	bp.spread = 180.0
	bp.initial_velocity_min = 1.5
	bp.initial_velocity_max = float(spell.burst_vel) * (0.8 + 0.4 * power)
	bp.gravity = Vector3(0, 1.2, 0)
	bp.damping_min = 2.0
	bp.damping_max = 4.0
	bp.scale_min = 0.5
	bp.scale_max = 1.2
	bp.color_ramp = main.ramp("impact_burst_" + String(spell.id), [spell.hot, spell.mid, spell.deep, Color(spell.deep, 0.0)], [0.0, 0.25, 0.6, 1.0])
	bp.scale_curve = main.curve("impact_burst_scale", [[0, 0.6], [1, 2.3]])
	burst.amount = int(burst.amount * (0.8 + 0.3 * power))
	add_child(burst)
	burst.restart()

	var sparks := _make_system("ImpactSparks", int(spell.sparks_burst), 0.8, load("res://assets/textures/spark_streak.png"), 0.45, true)
	sparks.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var spark_mesh := sparks.draw_pass_1 as QuadMesh
	spark_mesh.size = Vector2(0.055, 0.34)
	var sp: ParticleProcessMaterial = sparks.process_material
	sp.direction = Vector3(0, 1, 0)
	sp.spread = 180.0
	sp.initial_velocity_min = 2.5
	sp.initial_velocity_max = 6.5 * (0.8 + 0.35 * power)
	sp.gravity = Vector3(0, -8.0, 0)
	sp.damping_min = 0.5
	sp.damping_max = 2.0
	sp.scale_min = 0.6
	sp.scale_max = 1.3
	sp.color_ramp = main.ramp("impact_sparks_" + String(spell.id), [spell.hot, spell.mid, spell.deep, Color(spell.deep, 0.0)], [0.0, 0.25, 0.6, 1.0])
	sp.scale_curve = main.curve("impact_sparks_scale", [[0, 1], [1, 0.2]])
	add_child(sparks)
	sparks.restart()

	if float(spell.mist) > 0.5:
		var shards := _make_system("IceShards", 12, 0.95, load("res://assets/textures/shard.png"), 0.3, true)
		shards.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
		var shard_mesh := shards.draw_pass_1 as QuadMesh
		shard_mesh.size = Vector2(0.16, 0.4)
		var ip: ParticleProcessMaterial = shards.process_material
		ip.direction = Vector3(0, 1, 0)
		ip.spread = 110.0
		ip.initial_velocity_min = 3.0
		ip.initial_velocity_max = 7.0
		ip.gravity = Vector3(0, -7.0, 0)
		ip.damping_min = 0.3
		ip.damping_max = 1.0
		ip.scale_min = 0.5
		ip.scale_max = 1.0
		ip.color_ramp = main.ramp("impact_shards_" + String(spell.id), [spell.mid, spell.mid, Color(spell.deep, 0.0)], [0.0, 0.5, 1.0])
		add_child(shards)
		shards.restart()

func _build_fire_core() -> void:
	var core := _make_system("FireCore", 26, 0.55, load("res://assets/textures/glow.png"), 0.95, true)
	core.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	var cp: ParticleProcessMaterial = core.process_material
	cp.direction = Vector3(0, 1, 0)
	cp.spread = 180.0
	cp.initial_velocity_min = 0.5
	cp.initial_velocity_max = 3.0
	cp.gravity = Vector3(0, 1.0, 0)
	cp.damping_min = 2.0
	cp.damping_max = 4.0
	cp.scale_min = 0.7
	cp.scale_max = 1.5
	cp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	cp.emission_sphere_radius = 0.28
	cp.color_ramp = main.ramp("impact_core_" + String(spell.id), [spell.hot, spell.mid, Color(spell.deep, 0.0)], [0.0, 0.45, 1.0])
	cp.scale_curve = main.curve("impact_core_scale", [[0, 0.8], [1, 1.8]])
	add_child(core)
	core.restart()

func _build_embers() -> void:
	if int(spell.embers) <= 0:
		return
	var embers := _make_system("Embers", int(spell.embers), 1.7, load("res://assets/textures/glow.png"), 0.08, true)
	var ep: ParticleProcessMaterial = embers.process_material
	ep.direction = Vector3(0, 1, 0)
	ep.spread = 75.0
	ep.initial_velocity_min = 0.8
	ep.initial_velocity_max = 3.2
	ep.gravity = Vector3(0, -1.6, 0)
	ep.damping_min = 1.0
	ep.damping_max = 2.5
	ep.scale_min = 0.6
	ep.scale_max = 1.6
	ep.color_ramp = main.ramp("impact_embers_" + String(spell.id), [spell.hot, spell.mid, Color(spell.deep, 0.0)], [0.0, 0.5, 1.0])
	ep.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	ep.emission_sphere_radius = 0.35
	add_child(embers)
	embers.restart()

func _build_smoke() -> void:
	if int(spell.smoke) <= 0:
		return
	var smoke := _make_system("Smoke", maxi(4, int(spell.smoke) - 8), 1.4, load("res://assets/textures/smoke.png"), 0.65, true, false)
	var sm: ParticleProcessMaterial = smoke.process_material
	sm.direction = Vector3(0, 1, 0)
	sm.spread = 70.0
	sm.initial_velocity_min = 0.4
	sm.initial_velocity_max = 1.6
	sm.gravity = Vector3(0, 0.7, 0)
	sm.damping_min = 1.8
	sm.damping_max = 3.0
	sm.scale_min = 0.7
	sm.scale_max = 1.4
	sm.angle_min = -180
	sm.angle_max = 180
	sm.angular_velocity_min = -25
	sm.angular_velocity_max = 25
	sm.color_ramp = main.ramp("impact_smoke", [Color(0.16, 0.11, 0.09, 0.0), Color(0.16, 0.11, 0.09, 0.34), Color(0.08, 0.07, 0.07, 0.0)], [0.0, 0.3, 1.0])
	sm.scale_curve = main.curve("impact_smoke_scale", [[0, 0.6], [1, 2.6]])
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.25
	add_child(smoke)
	smoke.restart()

func _build_scorch() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 2.6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load("res://assets/textures/glow.png")
	var col: Color = spell.deep
	m.albedo_color = Color(col.r, col.g, col.b, 0.0)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	var scorch := MeshInstance3D.new()
	scorch.name = "ScorchGlow"
	scorch.mesh = q
	scorch.rotation.x = -PI / 2
	scorch.position = Vector3(0, 0.035 - (hit_point.y - _ground_y()), 0)
	scorch.scale = Vector3.ONE * (0.6 + 0.3 * power)
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(scorch)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.55, 0.12)
	tw.tween_property(m, "albedo_color:a", 0.0, 2.2)
	tw.tween_callback(scorch.queue_free)

func _build_rune() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 3.0)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rune.gdshader")
	m.set_shader_parameter("rune_tex", load("res://assets/textures/rune.png"))
	m.set_shader_parameter("tint", Color(spell.accent.r, spell.accent.g, spell.accent.b, 1.0))
	m.set_shader_parameter("alpha", 0.85)
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.rotation.x = -PI / 2
	mi.position = Vector3(0, 0.045 - (hit_point.y - _ground_y()), 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.scale = Vector3.ONE * 0.4
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 2.1, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "shader_parameter/alpha", 0.0, 1.7).set_delay(0.25)
	tw.tween_property(mi, "rotation:y", TAU * 0.8, 2.0)

func _build_mist() -> void:
	var mist := _make_system("FrostMist", 26, 1.6, load("res://assets/textures/smoke.png"), 1.3, true, false)
	mist.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	var mp: ParticleProcessMaterial = mist.process_material
	mp.direction = Vector3(0, 1, 0)
	mp.spread = 120.0
	mp.initial_velocity_min = 0.3
	mp.initial_velocity_max = 1.6
	mp.gravity = Vector3(0, -0.2, 0)
	mp.damping_min = 1.2
	mp.damping_max = 2.6
	mp.scale_min = 0.8
	mp.scale_max = 1.8
	mp.color_ramp = main.ramp("impact_mist_" + String(spell.id), [Color(spell.mid.r, spell.mid.g, spell.mid.b, 0.0), Color(spell.mid.r, spell.mid.g, spell.mid.b, 0.55), Color(0.5, 0.8, 1.0, 0.0)], [0.0, 0.25, 1.0])
	mp.scale_curve = main.curve("impact_mist_scale", [[0, 0.6], [1, 2.6]])
	add_child(mist)
	mist.restart()

# ── helpers ──────────────────────────────────────────────────────────────────

func _ground_y() -> float:
	return 0.0

func _billboard(tex: Texture2D, col: Color, size: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.albedo_color = col
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _ring_quad(col: Color, size: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load("res://assets/textures/ring.png")
	m.albedo_color = Color(col.r, col.g, col.b, 0.45)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.rotation.x = -PI / 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _make_system(name: String, amount: int, lifetime: float, tex: Texture2D, quad_size: float, additive := true, one_shot := true) -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.name = name
	ps.amount = maxi(1, amount)
	ps.lifetime = lifetime
	ps.one_shot = one_shot
	ps.explosiveness = 1.0 if one_shot else 0.0
	ps.emitting = false
	ps.local_coords = false
	ps.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.draw_pass_1 = main.particle_mesh(tex.resource_path, quad_size, additive)
	var pm := ParticleProcessMaterial.new()
	pm.lifetime_randomness = 0.25
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	ps.process_material = pm
	ps.add_to_group("magic_particles")
	return ps

func _ramp(colors: Array, offsets: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex
