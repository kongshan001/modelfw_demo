extends Node3D
class_name MagicLab

# Magic Projectile Lab — interactive 3D VFX demo (Godot 4.6, GL Compatibility).
# Reference technique: Le Lu "VFX for Games #11" fireball (head mesh + scrolling
# flame texture + trail + sparks + moving light), rebuilt with original art.
# Full chain: charge -> launch -> flight trail -> impact -> afterglow.

const SpellDataScript = preload("res://scripts/spell_data.gd")
const CasterScript = preload("res://scripts/caster.gd")
const DummyScript = preload("res://scripts/dummy.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const ImpactScript = preload("res://scripts/impact_fx.gd")
const HudScript = preload("res://scripts/hud.gd")

const CAM_POS := Vector3(0.0, 2.08, 6.8)
const CAM_LOOK := Vector3(0.08, 1.02, 0.0)
const GROUND_Y := 0.0
const CHARGE_TIME := 1.05
const BUDGET := 2400
const DUMMY_POSITIONS := [Vector3(1.8, 0.0, -1.25), Vector3(2.55, 0.0, 0.2), Vector3(1.95, 0.0, 1.45)]

var camera: Camera3D
var env_node: WorldEnvironment
var vfx_root: Node3D
var fx_root: Node3D
var caster: MagicCaster
var dummies: Array[TrainingDummy] = []
var projectiles: Array[MagicProjectile] = []
var impacts: Array[ImpactFX] = []
var hud: MagicHud
var aim_marker: Node3D
var aim_ring: MeshInstance3D
var aim_ring_mat: StandardMaterial3D
var aim_rune: MeshInstance3D
var aim_rune_mat: ShaderMaterial
var deco_rune: MeshInstance3D
var lanterns: Array[Node3D] = []
var _lantern_base: Array[Vector3] = []

var spell_index := 0
var spell: Dictionary = {}
var charging := false
var charge := 0.0
var power := 1.0
var cast_from_space := false
var mouse_pos := Vector2(640, 360)
var mouse_seen := false
var aim_point := Vector3(2.2, 0.0, 0.2)
var aim_dummy: TrainingDummy = null
var hover_dummy: TrainingDummy = null

var stats_visible := true
var slowmo := false
var auto_demo := true
var demo_timer := 3.0
var demo_charging := false
var idle_time := 0.0
var time := 0.0
var casts := 0
var hits := 0
var breaks := 0
var capture_mode := false
var capture_badge := ""
var debug_no_impact := false
var debug_no_trails := false
var debug_no_lights := false
var debug_no_proj_particles := false
var debug_no_head := false
var debug_no_glow := false
var debug_no_caster_fx := false
var debug_no_impact_particles := false

var fps_current := 60.0
var fps_override := 0.0
var display_still := false
var still_freeze := false
var particles_now := 0
var draw_calls := 0
var _stat_timer := 0.0
var _prune_timer := 0.0
var _cam_base_pos := CAM_POS
var _cam_base_rot := Vector3.ZERO
var proj_light: OmniLight3D
var impact_light: OmniLight3D
var impact_light_top := 0.0
var impact_light_ttl := 0.0
var _shake_time := 0.0
var _shake_dur := 0.001
var _shake_amp := 0.0
var _rng := RandomNumberGenerator.new()

var _head_mesh_cache := {}
var _head_mat_cache := {}
var _trail_mesh: QuadMesh
var _trail_mat_cache := {}
var _trail_pool: Array[Node3D] = []
var _particle_mesh_cache := {}
var _ramp_cache := {}
var _curve_cache := {}
var _capture_t := 0.0
var _capture_events: Array = []
var _capture_next := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 20261121
	_build_environment()
	_build_arena()
	_build_caster()
	_build_dummies()
	_build_aim_marker()
	_build_hud()
	_build_dust()
	switch_spell(0)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	print("MAGIC_VFX_READY spells=%d dummies=%d budget=%d" % [SpellDataScript.count(), dummies.size(), BUDGET])
	if "--capture" in OS.get_cmdline_user_args() or capture_mode:
		_enable_capture_timeline()

func _process(delta: float) -> void:
	time += delta
	fps_current = lerpf(fps_current, float(Engine.get_frames_per_second()), 0.08)
	if still_freeze:
		Engine.time_scale = 0.2
	elif slowmo:
		Engine.time_scale = 0.25
	else:
		Engine.time_scale = 1.0

	if not capture_mode:
		_update_aim()
		_update_idle_and_demo(delta)
	else:
		_update_capture_timeline(delta)

	if charging:
		charge = minf(1.0, charge + delta / CHARGE_TIME)
		caster.set_charge(charge)

	_stat_timer -= delta
	if _stat_timer <= 0.0:
		_stat_timer = 0.25
		particles_now = _estimate_particles()
		draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_prune_timer -= delta
	if _prune_timer <= 0.0:
		_prune_timer = 0.5
		_prune_arrays()

	_update_dynamic_lights(delta)
	_update_camera_shake(delta)
	_update_aim_marker(delta)
	if deco_rune:
		deco_rune.rotation.z += delta * 0.03
	for i in lanterns.size():
		var b := _lantern_base[i]
		lanterns[i].position = b + Vector3(0.0, sin(time * 0.7 + float(i) * 1.7) * 0.12, 0.0)
		lanterns[i].rotation.y += delta * (0.3 + float(i) * 0.08)

# ── input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if capture_mode:
		return
	if event is InputEventMouseMotion:
		mouse_pos = event.position
		mouse_seen = true
		idle_time = 0.0
		auto_demo = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_pos = event.position
			begin_charge(false)
		else:
			release_charge()
	elif event is InputEventKey and not event.echo:
		idle_time = 0.0
		auto_demo = false
		match event.keycode:
			KEY_SPACE:
				if event.pressed:
					begin_charge(true)
				else:
					release_charge()
			KEY_1:
				switch_spell(0)
			KEY_2:
				switch_spell(1)
			KEY_3:
				switch_spell(2)
			KEY_R:
				reset_all()
			KEY_T:
				set_slowmo(not slowmo)
			KEY_F:
				stats_visible = not stats_visible
			KEY_A:
				auto_demo = not auto_demo
				demo_timer = 0.8
			KEY_ESCAPE:
				if charging:
					_cancel_charge()
				else:
					get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and charging:
		_cancel_charge()

# ── casting ──────────────────────────────────────────────────────────────────

func switch_spell(index: int) -> void:
	if charging:
		_cancel_charge()
	spell_index = posmod(index, SpellDataScript.count())
	spell = SpellDataScript.get_spell(spell_index)
	caster.set_spell(spell)
	if aim_ring_mat:
		aim_ring_mat.albedo_color = Color(spell.accent.r, spell.accent.g, spell.accent.b, 0.75)
	if aim_rune_mat:
		aim_rune_mat.set_shader_parameter("tint", Color(spell.accent.r, spell.accent.g, spell.accent.b, 1.0))
	if hud:
		hud.queue_redraw()

func begin_charge(from_space := false) -> void:
	if charging:
		return
	charging = true
	cast_from_space = from_space
	charge = 0.0
	power = 0.55
	caster.set_charging(true)
	caster.set_charge(0.0)
	idle_time = 0.0
	if hud and hud.has_method("pulse_charge"):
		hud.pulse_charge()

func release_charge() -> void:
	if not charging:
		return
	charging = false
	var p := lerpf(0.6, 1.35, pow(charge, 0.75))
	var point := aim_point
	var target: TrainingDummy = null
	if is_instance_valid(aim_dummy) and aim_dummy.alive:
		target = aim_dummy
		point = target.get_chest_position()
	elif cast_from_space:
		var best := _nearest_alive_dummy(aim_point)
		if best:
			target = best
			point = best.get_chest_position()
	caster.set_charging(false)
	caster.set_charge(0.0)
	charge = 0.0
	_cast(point, target, p)

func _cancel_charge() -> void:
	charging = false
	charge = 0.0
	caster.set_charging(false)

func cast_at(point: Vector3, target: TrainingDummy, p_power: float) -> MagicProjectile:
	return _cast(point, target, p_power)

func fire_at_dummy(index: int, p_power := 1.0) -> MagicProjectile:
	if index < 0 or index >= dummies.size():
		return null
	var d := dummies[index]
	var point := d.get_chest_position() if d.alive else d.global_position + Vector3(0, 0.1, 0)
	aim_dummy = d if d.alive else null
	aim_point = point
	return _cast(point, d if d.alive else null, p_power)

func fire_at_ground(x: float, z: float, p_power := 1.0) -> MagicProjectile:
	return _cast(Vector3(x, 0.05, z), null, p_power)

func _cast(point: Vector3, target: TrainingDummy, p_power: float) -> MagicProjectile:
	if not is_instance_valid(caster):
		return null
	caster.aim_at(point)
	if not debug_no_caster_fx:
		caster.play_cast(p_power)
	var proj := ProjectileScript.new()
	proj.name = "MagicProjectile"
	fx_root.add_child(proj)
	proj.setup(self, spell, caster.get_muzzle_position(), point, p_power, target)
	proj.impacted.connect(_on_projectile_impacted)
	projectiles.append(proj)
	casts += 1
	add_shake(0.018 + 0.02 * p_power, 0.12)
	return proj

func _on_projectile_impacted(proj: MagicProjectile, point: Vector3, dummy: Node) -> void:
	projectiles.erase(proj)
	if debug_no_impact:
		if is_instance_valid(dummy) and dummy is TrainingDummy and dummy.alive:
			dummy.take_hit(proj.power, proj.spell)
			hits += 1
		return
	var impact := ImpactScript.new()
	impact.name = "Impact"
	fx_root.add_child(impact)
	impact.debug_no_particles = debug_no_impact_particles
	impact.setup(self, point, proj.spell, proj.power, is_instance_valid(dummy))
	impacts.append(impact)
	var pspell: Dictionary = proj.spell
	add_shake(float(pspell.shake) * (0.7 + 0.5 * proj.power), 0.34)
	if is_instance_valid(dummy) and dummy is TrainingDummy and dummy.alive:
		dummy.take_hit(proj.power, pspell)
		hits += 1
		var broke: bool = not dummy.alive
		if broke:
			breaks += 1
		if hud:
			hud.add_popup(point + Vector3(0, 0.45, 0), "BREAK" if broke else "HIT", pspell.hot, 0.9)
		# a little extra kick toward the camera
		add_shake(0.05 * proj.power, 0.2)
	elif hud:
		hud.add_popup(point + Vector3(0, 0.3, 0), "BURST", pspell.mid, 0.8)

# ── per-frame helpers ───────────────────────────────────────────────────────

func _update_aim() -> void:
	if camera == null:
		return
	var mp := get_viewport().get_mouse_position() if not mouse_seen else mouse_pos
	if not mouse_seen:
		mp = get_viewport().get_visible_rect().size * 0.5
	# hover detection on dummies (screen space)
	hover_dummy = null
	var best := 52.0
	for d in dummies:
		if not d.alive:
			continue
		var sp := camera.unproject_position(d.get_chest_position())
		var dist := sp.distance_to(mp)
		if dist < best:
			best = dist
			hover_dummy = d
	aim_dummy = hover_dummy
	if hover_dummy:
		aim_point = hover_dummy.get_chest_position()
	else:
		var from := camera.project_ray_origin(mp)
		var dir := camera.project_ray_normal(mp)
		var t := 50.0
		if absf(dir.y) > 0.0001:
			t = (GROUND_Y - from.y) / dir.y
		if t < 0.0:
			t = 50.0
		var p := from + dir * t
		p.x = clampf(p.x, -6.0, 7.0)
		p.z = clampf(p.z, -5.0, 5.0)
		p.y = GROUND_Y + 0.04
		aim_point = p
	caster.aim_at(aim_point)
	if hud:
		hud.set_aim(mp if mouse_seen else Vector2(-100, -100), hover_dummy)

func _update_aim_marker(delta: float) -> void:
	if aim_marker == null:
		return
	var ground := Vector3(aim_point.x, GROUND_Y + 0.035, aim_point.z)
	aim_marker.global_position = ground
	var t := time
	var s := 0.9 + 0.08 * sin(t * 4.0)
	if charging:
		s *= 1.0 + charge * 0.45
	aim_marker.scale = Vector3(s, 1, s)
	aim_marker.rotation.y += delta * 0.5
	if aim_ring_mat:
		var col: Color = spell.accent if not spell.is_empty() else Color.WHITE
		aim_ring_mat.albedo_color = Color(col.r, col.g, col.b, 0.45 + (0.35 if aim_dummy else 0.0) + (0.15 if charging else 0.0))
	if aim_rune_mat:
		aim_rune_mat.set_shader_parameter("alpha", 0.22 + (0.25 if aim_dummy else 0.0) + charge * 0.3)

func _update_camera_shake(delta: float) -> void:
	if camera == null:
		return
	var base := _cam_base_pos
	if not capture_mode:
		base += Vector3(sin(time * 0.6) * 0.006, sin(time * 0.9) * 0.004, 0.0)
	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		var k := _shake_time / _shake_dur
		var amp := _shake_amp * k * k
		var off := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * amp
		camera.position = base + off
		camera.rotation = _cam_base_rot + Vector3(off.y * 0.012, off.x * 0.012, off.x * 0.004)
	else:
		camera.position = base
		camera.rotation = _cam_base_rot

func _update_dynamic_lights(delta: float) -> void:
	if proj_light == null:
		return
	var live: MagicProjectile = null
	for i in range(projectiles.size() - 1, -1, -1):
		var p: MagicProjectile = projectiles[i]
		if is_instance_valid(p) and not p.done:
			live = p
			break
	if live != null:
		proj_light.global_position = live.global_position + Vector3(0, 0.15, 0)
		proj_light.light_color = live.spell.light
		var flick := 0.82 + 0.18 * sin(time * 31.0 + float(live.get_instance_id() % 17))
		proj_light.light_energy = float(live.spell.light_energy) * flick * (0.85 + 0.25 * live.power)
	else:
		proj_light.light_energy = lerpf(proj_light.light_energy, 0.0, 1.0 - exp(-10.0 * delta))
	if impact_light_ttl > 0.0:
		impact_light_ttl = maxf(0.0, impact_light_ttl - delta)
		var k := impact_light_ttl / 0.9
		impact_light.light_energy = impact_light_top * k * k + 0.5 * maxf(0.0, 1.0 - (0.9 - impact_light_ttl) / 2.2)
	else:
		impact_light.light_energy = lerpf(impact_light.light_energy, 0.0, 1.0 - exp(-6.0 * delta))

func flash_impact_light(point: Vector3, p_spell: Dictionary, p_power: float) -> void:
	if debug_no_lights or impact_light == null:
		return
	impact_light.global_position = point + Vector3(0.0, 0.35, 0.75)
	impact_light.light_color = p_spell.light
	impact_light_top = 5.0 * clampf(p_power, 0.5, 1.6)
	impact_light_ttl = 0.9
	impact_light.light_energy = impact_light_top

func add_shake(amp: float, dur: float) -> void:
	if amp > _shake_amp * (_shake_time / maxf(_shake_dur, 0.001)):
		_shake_amp = amp
		_shake_dur = maxf(dur, 0.01)
		_shake_time = _shake_dur

func _update_idle_and_demo(delta: float) -> void:
	idle_time += delta
	if not auto_demo:
		if idle_time > 14.0 and not charging and projectiles.is_empty():
			auto_demo = true
			demo_timer = 0.8
		return
	if demo_charging:
		demo_timer -= delta
		if demo_timer <= 0.0:
			release_charge()
			demo_charging = false
			demo_timer = 3.0
			if casts % 3 == 0:
				switch_spell(spell_index + 1)
		return
	if charging:
		return
	demo_timer -= delta
	if demo_timer <= 0.0:
		# aim at a live dummy so the auto demo always reads clearly
		var alive: Array = dummies.filter(func(d): return d.alive)
		if alive.is_empty():
			demo_timer = 2.0
			return
		var d: TrainingDummy = alive[_rng.randi() % alive.size()]
		aim_dummy = d
		aim_point = d.get_chest_position()
		begin_charge(true)
		demo_charging = true
		demo_timer = 0.72

func _nearest_alive_dummy(from: Vector3) -> TrainingDummy:
	var best: TrainingDummy = null
	var best_d := INF
	for d in dummies:
		if not d.alive:
			continue
		var dist := d.get_chest_position().distance_to(from)
		if dist < best_d:
			best_d = dist
			best = d
	return best

func set_slowmo(v: bool) -> void:
	slowmo = v
	Engine.time_scale = 0.25 if v else 1.0

func reset_all() -> void:
	if charging:
		_cancel_charge()
	for p in projectiles:
		if is_instance_valid(p):
			p.queue_free()
	projectiles.clear()
	impacts.clear()
	if hud:
		hud.clear_popups()
	if fx_root:
		fx_root.queue_free()
	fx_root = _make_fx_root()
	for t in _trail_pool:
		if is_instance_valid(t):
			t.visible = false
	for d in dummies:
		d.reset_state()
	aim_dummy = null
	hover_dummy = null
	set_slowmo(false)
	still_freeze = false
	auto_demo = not capture_mode
	demo_charging = false
	demo_timer = 2.0
	idle_time = 0.0

func _prune_arrays() -> void:
	# Safety net: any transient VFX node past its lifetime is freed even if its
	# owner node or timer callable was already gone (prevents emitter leaks).
	var now := Time.get_ticks_msec() / 1000.0
	for n in get_tree().get_nodes_in_group("magic_ephemeral"):
		if not is_instance_valid(n):
			continue
		if now >= float(n.get_meta("ephemeral_until", now + 30.0)):
			n.queue_free()
	for i in range(projectiles.size() - 1, -1, -1):
		if not is_instance_valid(projectiles[i]):
			projectiles.remove_at(i)
	for i in range(impacts.size() - 1, -1, -1):
		if not is_instance_valid(impacts[i]):
			impacts.remove_at(i)

func _estimate_particles() -> int:
	var total := 0
	for n in get_tree().get_nodes_in_group("magic_particles"):
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var amt: int = int(n.amount)
		if n.emitting:
			total += int(float(amt) * float(n.amount_ratio))
		elif n.one_shot:
			var born: float = float(n.get_meta("born", -100.0))
			if time - born < float(n.lifetime) + 0.15:
				total += amt
	return total

# ── capture timeline (movie writer) ─────────────────────────────────────────

func _enable_capture_timeline() -> void:
	capture_mode = true
	auto_demo = false
	mouse_seen = false
	capture_badge = "REC · CINEMATIC 30 FPS"
	fps_override = 30.0
	_capture_t = 0.0
	_capture_next = 0
	_capture_events = [
		[0.3, func(): switch_spell(0)],
		[0.7, func(): _cap_aim_dummy(0)],
		[0.8, func(): begin_charge(true)],
		[1.85, func(): release_charge()],
		[2.55, func(): switch_spell(1)],
		[2.7, func(): _cap_aim_dummy(1)],
		[2.8, func(): begin_charge(true)],
		[3.45, func(): release_charge()],
		[3.95, func(): switch_spell(2)],
		[4.1, func(): _cap_aim_dummy(2)],
		[4.2, func(): begin_charge(true)],
		[4.8, func(): release_charge()],
		[5.3, func(): switch_spell(0)],
		[5.45, func(): _cap_aim_dummy(0)],
		[5.55, func(): begin_charge(true)],
		[6.25, func(): release_charge()],
		[6.85, func(): set_slowmo(true)],
		[7.05, func(): _cap_aim_dummy(1)],
		[7.15, func(): begin_charge(true)],
		[8.0, func(): release_charge()],
		[10.35, func(): set_slowmo(false)],
		[10.9, func(): get_tree().quit()],
	]
	if hud:
		hud.queue_redraw()

func _update_capture_timeline(delta: float) -> void:
	# Keep the recording timeline in wall-clock seconds even during slow-mo.
	_capture_t += delta / maxf(Engine.time_scale, 0.01)
	while _capture_next < _capture_events.size() and _capture_t >= float(_capture_events[_capture_next][0]):
		var cb: Callable = _capture_events[_capture_next][1]
		cb.call()
		_capture_next += 1

func aim_at_dummy(i: int) -> void:
	if i >= 0 and i < dummies.size():
		aim_dummy = dummies[i]
		aim_point = dummies[i].get_chest_position()
		caster.aim_at(aim_point)

func _cap_aim_dummy(i: int) -> void:
	aim_at_dummy(i)

# ── scene construction ──────────────────────────────────────────────────────

func _build_environment() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.position = CAM_POS
	camera.look_at(CAM_LOOK, Vector3.UP)
	camera.fov = 41.0
	camera.near = 0.1
	camera.far = 80.0
	camera.current = true
	_cam_base_pos = camera.position
	_cam_base_rot = camera.rotation

	env_node = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.020, 0.027, 0.050)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.31, 0.50)
	env.ambient_light_energy = 2.15
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	add_child(env_node)

	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color(0.72, 0.80, 1.0)
	key.light_energy = 3.0
	key.rotation_degrees = Vector3(-40, -32, 0)
	key.shadow_enabled = false
	add_child(key)

	var rim := OmniLight3D.new()
	rim.name = "RimLight"
	rim.light_color = Color(1.0, 0.62, 0.38)
	rim.light_energy = 2.6
	rim.omni_range = 15.0
	rim.position = Vector3(1.2, 3.2, -4.5)
	rim.shadow_enabled = false
	add_child(rim)

	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color(0.36, 0.46, 0.78)
	fill.light_energy = 3.8
	fill.omni_range = 22.0
	fill.position = Vector3(-2.4, 3.4, 5.2)
	fill.shadow_enabled = false
	add_child(fill)

	var mage_fill := OmniLight3D.new()
	mage_fill.name = "MageFill"
	mage_fill.light_color = Color(0.6, 0.65, 1.0)
	mage_fill.light_energy = 2.4
	mage_fill.omni_range = 6.5
	mage_fill.position = Vector3(-2.2, 2.2, 3.4)
	mage_fill.shadow_enabled = false
	add_child(mage_fill)

	# Pooled dynamic lights: one follows the newest projectile, one flashes at
	# impacts. Keeping the light count stable avoids forward-renderer churn.
	proj_light = OmniLight3D.new()
	proj_light.name = "ProjectileLight"
	proj_light.light_energy = 0.0
	proj_light.omni_range = 9.0
	proj_light.omni_attenuation = 1.3
	proj_light.shadow_enabled = false
	add_child(proj_light)
	impact_light = OmniLight3D.new()
	impact_light.name = "ImpactLight"
	impact_light.light_energy = 0.0
	impact_light.omni_range = 9.0
	impact_light.omni_attenuation = 1.25
	impact_light.shadow_enabled = false
	add_child(impact_light)

	vfx_root = Node3D.new()
	vfx_root.name = "VfxRoot"
	add_child(vfx_root)
	fx_root = _make_fx_root()

func _make_fx_root() -> Node3D:
	var n := Node3D.new()
	n.name = "FxRoot"
	vfx_root.add_child(n)
	return n

func _build_arena() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	ground.mesh = plane
	var gmat := ShaderMaterial.new()
	gmat.shader = load("res://shaders/ground.gdshader")
	gmat.set_shader_parameter("noise_tex", load("res://assets/textures/noise.png"))
	gmat.set_shader_parameter("pool_center", Vector3(0.0, 0.0, 0.0))
	ground.material_override = gmat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	# night backdrop gradient
	var back := MeshInstance3D.new()
	back.name = "Backdrop"
	var bq := QuadMesh.new()
	bq.size = Vector2(48, 22)
	var bmat := ShaderMaterial.new()
	bmat.shader = load("res://shaders/backdrop.gdshader")
	bmat.set_shader_parameter("horizon_color", Color(0.045, 0.07, 0.145))
	bmat.set_shader_parameter("top_color", Color(0.008, 0.012, 0.03))
	bmat.set_shader_parameter("glow_color", Color(0.1, 0.2, 0.42))
	bmat.set_shader_parameter("star_amount", 0.982)
	bq.material = bmat
	back.mesh = bq
	back.position = Vector3(0.0, 8.5, -16.5)
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(back)

	# decorative static rune inlay
	deco_rune = _make_rune_quad(9.5, 0.07)
	deco_rune.name = "DecoRune"
	deco_rune.position = Vector3(0.3, 0.012, -0.4)
	add_child(deco_rune)

	# ground pools anchor the characters without extra lights
	_add_pool(Vector3(-2.45, 0.02, 0.55), Color(0.45, 0.32, 0.85, 0.26), 2.7)
	_add_pool(DUMMY_POSITIONS[0] + Vector3(0, 0.02, 0), Color(1.0, 0.55, 0.25, 0.2), 2.0)
	_add_pool(DUMMY_POSITIONS[1] + Vector3(0, 0.02, 0), Color(1.0, 0.55, 0.25, 0.2), 2.0)
	_add_pool(DUMMY_POSITIONS[2] + Vector3(0, 0.02, 0), Color(1.0, 0.55, 0.25, 0.2), 2.0)
	_build_lanterns()

	# background monoliths + gate ring
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.045, 0.055, 0.09)
	dark.roughness = 0.95
	var edge := StandardMaterial3D.new()
	edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge.albedo_color = Color(0.06, 0.10, 0.24)
	edge.emission_enabled = true
	edge.emission = Color(0.08, 0.13, 0.32)
	edge.emission_energy_multiplier = 0.35
	for i in 6:
		var x := -10.5 + i * 4.2 + _rng.randf_range(-0.6, 0.6)
		var h := _rng.randf_range(3.2, 6.0)
		var w := _rng.randf_range(1.0, 1.9)
		var box := BoxMesh.new()
		box.size = Vector3(w, h, 0.6)
		var mi := MeshInstance3D.new()
		mi.name = "Monolith%d" % i
		mi.mesh = box
		mi.material_override = dark
		mi.position = Vector3(x, h * 0.5, -12.5 - _rng.randf_range(0.0, 4.0))
		mi.rotation.y = _rng.randf_range(-0.2, 0.2)
		add_child(mi)
		var cap := BoxMesh.new()
		cap.size = Vector3(w * 0.75, 0.04, 0.7)
		var cmi := MeshInstance3D.new()
		cmi.name = "Cap%d" % i
		cmi.mesh = cap
		cmi.material_override = edge
		cmi.position = mi.position + Vector3(0.0, h * 0.5 - 0.02, 0.0)
		add_child(cmi)

	var gate := MeshInstance3D.new()
	gate.name = "GateRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 2.55
	torus.outer_radius = 2.59
	torus.rings = 48
	torus.ring_segments = 4
	gate.mesh = torus
	var gate_mat := StandardMaterial3D.new()
	gate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gate_mat.albedo_color = Color(0.05, 0.075, 0.16)
	gate_mat.emission_enabled = true
	gate_mat.emission = Color(0.11, 0.18, 0.42)
	gate_mat.emission_energy_multiplier = 0.35
	gate.material_override = gate_mat
	gate.rotation.x = PI / 2.0
	gate.position = Vector3(0.6, 3.0, -11.5)
	add_child(gate)

func _add_pool(pos: Vector3, col: Color, size: float) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load("res://assets/textures/glow.png")
	m.albedo_color = col
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.rotation.x = -PI / 2
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_lanterns() -> void:
	var spots := [
		Vector3(-4.3, 2.15, -2.4), Vector3(4.4, 1.95, -2.9),
		Vector3(-2.0, 2.6, -5.2), Vector3(3.1, 2.4, -5.0),
	]
	var cols := [Color(0.55, 0.4, 1.0), Color(1.0, 0.5, 0.25), Color(0.4, 0.7, 1.0), Color(1.0, 0.6, 0.3)]
	for i in spots.size():
		var root := Node3D.new()
		root.name = "Lantern%d" % i
		root.position = spots[i]
		add_child(root)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = cols[i]
		mat.emission_enabled = true
		mat.emission = cols[i]
		mat.emission_energy_multiplier = 2.2
		var mesh := SphereMesh.new()
		mesh.radius = 0.1
		mesh.height = 0.2
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		var halo := _make_glow_quad(load("res://assets/textures/glow.png"), Color(cols[i], 0.45), 0.8)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(halo)
		lanterns.append(root)
		_lantern_base.append(spots[i])

func _make_glow_quad(tex: Texture2D, col: Color, size: float) -> MeshInstance3D:
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
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	return mi

func _build_caster() -> void:
	caster = CasterScript.new()
	caster.name = "Caster"
	caster.position = Vector3(-2.45, 0.0, 0.55)
	add_child(caster)
	caster.setup(self)
	caster.set_spell(SpellDataScript.get_spell(spell_index))
	caster.aim_at(Vector3(2.0, 1.1, 0.0))

func _build_dummies() -> void:
	for i in DUMMY_POSITIONS.size():
		var d := DummyScript.new()
		d.name = "Dummy%d" % i
		add_child(d)
		d.setup(self, i, DUMMY_POSITIONS[i])
		dummies.append(d)

func _build_aim_marker() -> void:
	aim_marker = Node3D.new()
	aim_marker.name = "AimMarker"
	add_child(aim_marker)
	var q := QuadMesh.new()
	q.size = Vector2(0.95, 0.95)
	aim_ring_mat = StandardMaterial3D.new()
	aim_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aim_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aim_ring_mat.albedo_texture = load("res://assets/textures/ring.png")
	aim_ring_mat.albedo_color = Color(1, 1, 1, 0.85)
	aim_ring_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	aim_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = aim_ring_mat
	aim_ring = MeshInstance3D.new()
	aim_ring.mesh = q
	aim_ring.rotation.x = -PI / 2.0
	aim_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_marker.add_child(aim_ring)
	aim_rune = _make_rune_quad(2.0, 0.4)
	aim_rune.position.y = 0.006
	aim_rune_mat = aim_rune.material_override as ShaderMaterial
	aim_marker.add_child(aim_rune)

func _make_rune_quad(size: float, alpha: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rune.gdshader")
	m.set_shader_parameter("rune_tex", load("res://assets/textures/rune.png"))
	m.set_shader_parameter("alpha", alpha)
	m.set_shader_parameter("tint", Color(0.6, 0.45, 1.0, 1.0))
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.rotation.x = -PI / 2.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-size, -0.2, -size), Vector3(size * 2, 1, size * 2))
	return mi

func _build_dust() -> void:
	var ps := GPUParticles3D.new()
	ps.name = "DustMotes"
	ps.amount = 80
	ps.lifetime = 12.0
	ps.preprocess = 12.0
	ps.local_coords = true
	ps.emitting = true
	ps.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.add_to_group("magic_particles")
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load("res://assets/textures/dust.png")
	m.vertex_color_use_as_albedo = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	ps.draw_pass_1 = q
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9.0, 3.0, 6.0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.gravity = Vector3(0, 0.01, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.1
	pm.color_ramp = _ramp([Color(0.6, 0.75, 1.0, 0.0), Color(0.55, 0.72, 1.0, 0.5), Color(0.6, 0.75, 1.0, 0.0)], [0.0, 0.5, 1.0])
	ps.process_material = pm
	ps.position = Vector3(0.5, 2.2, -1.0)
	vfx_root.add_child(ps)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	layer.layer = 10
	add_child(layer)
	hud = HudScript.new()
	hud.name = "HUD"
	layer.add_child(hud)
	hud.setup(self)

	# vignette below HUD
	var vlayer := CanvasLayer.new()
	vlayer.name = "VignetteLayer"
	vlayer.layer = 5
	add_child(vlayer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	rect.material = mat
	vlayer.add_child(rect)

func _ramp(colors: Array, offsets: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex

func get_vfx_root() -> Node:
	return fx_root

func get_head_mesh(style: int) -> ArrayMesh:
	if not _head_mesh_cache.has(style):
		_head_mesh_cache[style] = ProjectileScript.build_crystal_mesh() if style == 2 else ProjectileScript.build_scoop_mesh()
	return _head_mesh_cache[style]

func particle_mesh(tex_path: String, size: float, additive := true) -> QuadMesh:
	var key := "%s|%.3f|%s" % [tex_path, size, additive]
	if _particle_mesh_cache.has(key):
		return _particle_mesh_cache[key]
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = load(tex_path)
	m.vertex_color_use_as_albedo = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED if additive else BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	q.material = m
	_particle_mesh_cache[key] = q
	return q

func ramp(key: String, colors: Array, offsets: Array) -> GradientTexture1D:
	if _ramp_cache.has(key):
		return _ramp_cache[key]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex := GradientTexture1D.new()
	tex.gradient = g
	_ramp_cache[key] = tex
	return tex

func curve(key: String, points: Array) -> CurveTexture:
	if _curve_cache.has(key):
		return _curve_cache[key]
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(float(p[0]), float(p[1])))
	var ct := CurveTexture.new()
	ct.curve = c
	_curve_cache[key] = ct
	return ct

func get_trail_material(sp: Dictionary) -> ShaderMaterial:
	var key: String = String(sp.id)
	if _trail_mat_cache.has(key):
		return _trail_mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/flame_trail_quad.gdshader")
	m.set_shader_parameter("strip_tex", load(String(sp.trail_tex)))
	m.set_shader_parameter("hot_color", sp.accent.lerp(Color.WHITE, 0.12))
	m.set_shader_parameter("mid_color", sp.mid.darkened(0.05))
	m.set_shader_parameter("deep_color", sp.deep.darkened(0.12))
	m.set_shader_parameter("scroll_speed", float(sp.trail_speed))
	m.set_shader_parameter("length_repeat", float(sp.trail_repeat) * 0.7)
	m.set_shader_parameter("alpha_mul", 0.92)
	m.set_shader_parameter("seed", float(sp.spin) * 1.7)
	m.set_shader_parameter("flow_dir", -1.0)
	_trail_mat_cache[key] = m
	return m

func _unit_trail_mesh() -> QuadMesh:
	if _trail_mesh == null:
		_trail_mesh = QuadMesh.new()
		_trail_mesh.size = Vector2.ONE
	return _trail_mesh

func acquire_trail(sp: Dictionary, p_power: float) -> Node3D:
	var t: Node3D = null
	for cand in _trail_pool:
		if is_instance_valid(cand) and not cand.visible:
			t = cand
			break
	if t == null:
		t = load("res://scripts/trail_quad.gd").new()
		t.name = "TrailQuad%d" % _trail_pool.size()
		vfx_root.add_child(t)
		_trail_pool.append(t)
	t.setup(_unit_trail_mesh(), get_trail_material(sp),
		float(sp.trail_len) * (0.85 + 0.25 * p_power),
		float(sp.trail_width) * (0.9 + 0.2 * p_power))
	return t

func release_trail(t: Node3D) -> void:
	if is_instance_valid(t):
		t.visible = false

func get_head_material(sp: Dictionary) -> ShaderMaterial:
	var key: String = String(sp.id)
	if _head_mat_cache.has(key):
		return _head_mat_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/flame_head.gdshader")
	mat.set_shader_parameter("hot_color", sp.hot)
	mat.set_shader_parameter("mid_color", sp.mid)
	mat.set_shader_parameter("deep_color", sp.deep)
	mat.set_shader_parameter("intensity", 1.75)
	mat.set_shader_parameter("flow_speed", 1.15 + 0.5 * float(sp.spin))
	mat.set_shader_parameter("noise_scale", 2.4)
	mat.set_shader_parameter("seed", 2.0)
	mat.set_shader_parameter("style", float(sp.head_style))
	mat.set_shader_parameter("noise_tex", load("res://assets/textures/noise.png"))
	_head_mat_cache[key] = mat
	return mat
