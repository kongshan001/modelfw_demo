class_name MagicProjectile
extends Node3D

# A magic projectile built the way the reference tutorial builds its fireball:
# a 3D head mesh with a scrolling flame shader, a wavy scrolling flame trail,
# sparks, puffs and a moving OmniLight3D. Everything here is original.
#
# GL Compatibility note: GPUParticles3D trails are unavailable, so the tail is
# a cached scrolling quad sheet (TrailQuad) plus GPU spark/puff leftovers.

signal impacted(projectile: MagicProjectile, point: Vector3, dummy: Node)

var main: Node
var spell: Dictionary = {}
var from_pos := Vector3.ZERO
var to_pos := Vector3.ZERO
var ctrl := Vector3.ZERO
var dummy: Node = null
var power := 1.0
var progress := 0.0
var duration := 0.4
var done := false

var head: MeshInstance3D
var glow_big: MeshInstance3D
var glow_core: MeshInstance3D
var sparks: GPUParticles3D
var puffs: GPUParticles3D
var trail: Node3D

var _history: Array[Vector3] = []
var _trail_len := 3.0
var _seed := 0.0
var _clock := 0.0
var _head_base_scale := 1.0
var _spark_restart := 0.0

func setup(p_main: Node, p_spell: Dictionary, p_from: Vector3, p_to: Vector3, p_power: float, p_dummy: Node) -> void:
	main = p_main
	spell = p_spell
	from_pos = p_from
	to_pos = p_to
	dummy = p_dummy
	power = clampf(p_power, 0.5, 1.6)
	_seed = randf() * 10.0
	_clock = 0.0

	var dist := from_pos.distance_to(to_pos)
	var speed: float = float(spell.speed) * (0.85 + 0.15 * power)
	duration = clampf(dist / maxf(speed, 1.0), 0.16, 1.0)
	ctrl = (from_pos + to_pos) * 0.5 + Vector3(0.0, float(spell.arc) * (0.7 + 0.5 * power), 0.0)
	_trail_len = float(spell.trail_len) * (0.85 + 0.25 * power)

	if not main.debug_no_head:
		_build_head()
	if not main.debug_no_glow:
		_build_glow()
	if not main.debug_no_proj_particles:
		_build_particles()
	_build_trail()

	global_position = from_pos
	_history.clear()
	_history.append(from_pos)
	_face_along((to_pos - from_pos).normalized())

func _process(delta: float) -> void:
	if done:
		return
	_clock += delta
	var prev := progress
	progress = minf(1.0, progress + delta / duration)
	var p := _bezier(progress)
	var tangent := _bezier(progress + 0.01) - p
	if tangent.length_squared() < 0.000001:
		tangent = to_pos - from_pos
	global_position = p
	_face_along(tangent.normalized())

	# animate head
	if head:
		var pulse := 1.0 + 0.045 * sin(_clock * 26.0 + _seed)
		var s := _head_base_scale * pulse
		head.scale = Vector3(s, s, s)
		if float(spell.spin) > 0.5:
			head.rotation.z += delta * float(spell.spin) * 1.2
		else:
			head.rotation.z = sin(_clock * 7.0 + _seed) * 0.14
	if glow_big:
		var gs := (1.0 + 0.06 * sin(_clock * 19.0 + _seed)) * (0.9 + 0.25 * power)
		glow_big.scale = Vector3(gs, gs, gs)

	# record trail with sub-steps for a smooth strip
	if prev < 1.0:
		var prev_p := _bezier(prev)
		var steps := maxi(1, int(p.distance_to(prev_p) / 0.09))
		for i in range(1, steps + 1):
			var pp := prev_p.lerp(_bezier(progress), float(i) / steps)
			_history.insert(0, pp)
	# trim by length and count
	while _history.size() > 2 and (_history[0].distance_to(_history[_history.size() - 1]) > _trail_len or _history.size() > 64):
		_history.pop_back()
	if trail:
		trail.place(p, -tangent.normalized() * 1.0)

	if progress >= 1.0:
		_finish()

func _bezier(t: float) -> Vector3:
	var u := 1.0 - t
	return from_pos * (u * u) + ctrl * (2.0 * u * t) + to_pos * (t * t)

func _face_along(dir: Vector3) -> void:
	if dir.length_squared() < 0.000001:
		return
	var up := Vector3.UP
	if absf(dir.normalized().dot(up)) > 0.995:
		up = Vector3.FORWARD
	look_at(global_position + dir.normalized(), up)

# ── visual construction ─────────────────────────────────────────────────────

func _build_head() -> void:
	head = MeshInstance3D.new()
	head.name = "Head"
	var style := int(spell.head_style)
	head.mesh = main.get_head_mesh(style)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	head.material_override = main.get_head_material(spell)
	_head_base_scale = float(spell.head_scale) * (0.82 + 0.3 * power)
	head.scale = Vector3.ONE * _head_base_scale
	add_child(head)

static func build_scoop_mesh() -> ArrayMesh:
	# Hollow flame scoop: wide open tail, bulging belly, tapered hot front.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 16
	var segs := 20
	var profile := [0.235, 0.27, 0.29, 0.285, 0.265, 0.24, 0.205, 0.165, 0.12, 0.07]
	var pts: Array = []
	for i in range(rings + 1):
		var t := float(i) / float(rings)
		var z := lerpf(0.36, -0.34, t)
		var pf := t * float(profile.size() - 1)
		var p0 := mini(int(pf), profile.size() - 1)
		var p1 := mini(p0 + 1, profile.size() - 1)
		var r: float = lerpf(float(profile[p0]), float(profile[p1]), pf - float(p0))
		var yc := -0.26 + 0.52 * pow(t, 1.75) + 0.03 * sin(t * PI)
		var ring_pts: Array = []
		for j in range(segs + 1):
			var a := TAU * float(j) / float(segs)
			var x := cos(a) * r * 0.92
			var y := sin(a) * r * 1.12
			ring_pts.append(Vector3(x, yc + y, z))
		pts.append(ring_pts)

	for i in range(rings):
		for j in range(segs):
			var t0 := float(i) / float(rings)
			var t1 := float(i + 1) / float(rings)
			var v0 := TAU * float(j) / float(segs) / TAU
			var v1 := TAU * float(j + 1) / float(segs) / TAU
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j + 1]
			var c: Vector3 = pts[i + 1][j]
			var d: Vector3 = pts[i + 1][j + 1]
			st.set_uv(Vector2(t0, v0)); st.add_vertex(a)
			st.set_uv(Vector2(t0, v1)); st.add_vertex(b)
			st.set_uv(Vector2(t1, v0)); st.add_vertex(c)
			st.set_uv(Vector2(t0, v1)); st.add_vertex(b)
			st.set_uv(Vector2(t1, v1)); st.add_vertex(d)
			st.set_uv(Vector2(t1, v0)); st.add_vertex(c)
	# close the front tip
	var tip_z := -0.36
	var tip_y := -0.26 + 0.52 * pow(1.0, 1.75)
	for j in range(segs):
		var a2: Vector3 = pts[rings][j]
		var b2: Vector3 = pts[rings][j + 1]
		st.set_uv(Vector2(1.0, 0.5)); st.add_vertex(Vector3(0, tip_y + 0.01, tip_z))
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(a2)
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(b2)
	st.generate_normals()
	return st.commit()

static func build_crystal_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 6
	var ring1: Array = []
	var ring2: Array = []
	var radius1 := 0.15
	var radius2 := 0.105
	for j in range(segs):
		var a := TAU * float(j) / float(segs)
		ring1.append(Vector3(cos(a) * radius1 * 0.7, sin(a) * radius1, 0.10))
		ring2.append(Vector3(cos(a) * radius2 * 0.7, sin(a) * radius2, -0.24))
	var back_tip := Vector3(0, 0, 0.28)
	var front_tip := Vector3(0, 0, -0.52)
	for j in range(segs):
		var j2 := (j + 1) % segs
		# back cap
		var a1: Vector3 = ring1[j]
		var b1: Vector3 = ring1[j2]
		st.set_uv(Vector2(0.15, 0.0)); st.add_vertex(back_tip)
		st.set_uv(Vector2(0.2, 0.2)); st.add_vertex(b1)
		st.set_uv(Vector2(0.2, 0.8)); st.add_vertex(a1)
		# waist
		st.set_uv(Vector2(0.45, 0.0)); st.add_vertex(a1)
		st.set_uv(Vector2(0.45, 1.0)); st.add_vertex(b1)
		st.set_uv(Vector2(0.7, 0.0)); st.add_vertex(ring2[j])
		st.set_uv(Vector2(0.45, 1.0)); st.add_vertex(b1)
		st.set_uv(Vector2(0.7, 1.0)); st.add_vertex(ring2[j2])
		st.set_uv(Vector2(0.7, 0.0)); st.add_vertex(ring2[j])
		# front
		var a2: Vector3 = ring2[j]
		var b2: Vector3 = ring2[j2]
		st.set_uv(Vector2(0.7, 0.0)); st.add_vertex(a2)
		st.set_uv(Vector2(0.7, 1.0)); st.add_vertex(b2)
		st.set_uv(Vector2(1.0, 0.5)); st.add_vertex(front_tip)
	st.generate_normals()
	return st.commit()

func _build_glow() -> void:
	glow_big = _make_glow(load("res://assets/textures/glow.png"), Color(spell.mid, 0.38), 2.0)
	glow_big.name = "GlowBig"
	add_child(glow_big)
	glow_core = _make_glow(load("res://assets/textures/glow.png"), Color(spell.hot, 0.85), 0.7)
	glow_core.name = "GlowCore"
	add_child(glow_core)

func _make_glow(tex: Texture2D, col: Color, size: float) -> MeshInstance3D:
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
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _build_particles() -> void:
	sparks = _make_spark_system()
	add_child(sparks)
	puffs = _make_puff_system()
	add_child(puffs)

func _make_spark_system() -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.name = "Sparks"
	ps.amount = int(float(spell.spark_amount) * lerpf(0.75, 1.25, clampf(power - 0.5, 0.0, 1.0)))
	ps.lifetime = 0.55
	ps.local_coords = false
	ps.emitting = true
	ps.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.draw_pass_1 = main.particle_mesh(String(spell.spark_tex), float(spell.spark_size), true)

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, 0.2, 1.0)
	pm.spread = 48.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = float(spell.spark_vel)
	pm.gravity = Vector3(0.0, -float(spell.spark_gravity), 0.0)
	pm.damping_min = 0.8
	pm.damping_max = 2.2
	pm.scale_min = 0.55
	pm.scale_max = 1.25
	pm.color_ramp = main.ramp("proj_spark_" + String(spell.id), [spell.hot, spell.mid, Color(spell.deep, 0.0)], [0.0, 0.35, 1.0])
	pm.scale_curve = main.curve("proj_spark_scale", [[0.0, 1.0], [1.0, 0.15]])
	ps.process_material = pm
	ps.add_to_group("magic_particles")
	return ps

func _make_puff_system() -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.name = "FlamePuffs"
	ps.amount = int(float(spell.puff_amount) * lerpf(0.7, 1.2, clampf(power - 0.5, 0.0, 1.0)))
	ps.lifetime = 0.55
	ps.local_coords = false
	ps.emitting = true
	ps.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.draw_pass_1 = main.particle_mesh("res://assets/textures/smoke.png", float(spell.puff_size), true)

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, 0.25, 1.0)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0.0, 0.4, 0.0)
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	pm.color_ramp = main.ramp("proj_puff_" + String(spell.id), [spell.puff_color, Color(spell.deep, 0.35), Color(spell.deep, 0.0)], [0.0, 0.45, 1.0])
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -40.0
	pm.angular_velocity_max = 40.0
	pm.scale_curve = main.curve("proj_puff_scale", [[0.0, 0.7], [1.0, 2.1]])
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

func _build_trail() -> void:
	if main.debug_no_trails:
		return
	trail = main.acquire_trail(spell, power)
	var fwd := (to_pos - from_pos).normalized()
	trail.place(global_position - fwd * 0.15, -fwd)

func _finish() -> void:
	if done:
		return
	done = true
	if sparks:
		sparks.emitting = false
	if puffs:
		puffs.emitting = false
	if trail:
		main.release_trail(trail)
		trail = null
	# keep embers alive after the projectile node disappears: reparent, then
	# free them after their lifetime so nothing leaks.
	for node in [sparks, puffs]:
		if node:
			var vfx_root: Node = main.get_vfx_root()
			if node.get_parent() != vfx_root:
				node.reparent(vfx_root, true)
			node.set_meta("ephemeral_until", Time.get_ticks_msec() / 1000.0 + 1.2)
			node.add_to_group("magic_ephemeral")
			var timer := get_tree().create_timer(1.2, true, false, true)
			timer.timeout.connect(node.queue_free)
	var point := to_pos
	if is_instance_valid(dummy) and dummy.has_method("get_chest_position"):
		point = dummy.get_chest_position()
	impacted.emit(self, point, dummy if is_instance_valid(dummy) else null)
	queue_free()

