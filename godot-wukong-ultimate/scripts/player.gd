extends CharacterBody3D
class_name WukongPlayer

## Third-person hero controller. Model faces local +Z after the import rotation;
## charge gathers energy, release fires a ki wave. Every visual (aura, motes,
## orbiting rocks, ring) is original procedural content.

signal ki_release(origin: Vector3, dir: Vector3, power: float)
signal hurt(amount: int)
signal died
signal charge_started
signal cast_started

const MODEL_PATH := "res://assets/models/wukong_ultimate.glb"
const MAX_HP := 100
const MAX_ENERGY := 100.0
const MOVE_SPEED := 4.6
const ACCEL := 24.0
const DECEL := 20.0
const CHARGE_TIME := 1.15
const MIN_CHARGE_ENERGY := 12.0
const ARENA_LIMIT := 8.2

var hp := MAX_HP
var energy := MAX_ENERGY
var charge := 0.0
var charging := false
var state := "idle"
var controls_enabled := true
var demo_axis := Vector3.ZERO

var model_root: Node3D
var anim: AnimationPlayer
var mesh_instance: MeshInstance3D
var fire_point: Node3D
var aura_mat: ShaderMaterial
var aura_shells: Array[MeshInstance3D] = []
var aura_light: OmniLight3D
var charge_ring: MeshInstance3D
var charge_rig: Node3D
var charge_particles: CPUParticles3D
var charge_core: MeshInstance3D
var rocks: Array[MeshInstance3D] = []

var _action_lock := 0.0
var _pending_power := 0.0
var _pending_timer := 0.0
var _pending_origin := Vector3.ZERO
var _pending_dir := Vector3.ZERO
var _invuln := 0.0
var _aura_target := 0.0
var _aura_value := 0.0
var _orbit_t := 0.0
var _trail_mesh: QuadMesh
var _spark_material: StandardMaterial3D


func _ready() -> void:
	_ensure_input_map()
	collision_layer = 1
	collision_mask = 1 | 2
	floor_snap_length = 0.4
	up_direction = Vector3.UP

	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.85
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = 0.925
	add_child(col)

	_build_model()
	_build_aura()
	play_anim("Idle", 0.0)


func _ensure_input_map() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_forward", KEY_UP)
	_add_key("move_back", KEY_S)
	_add_key("move_back", KEY_DOWN)
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_key("charge", KEY_SPACE)
	_add_key("reset", KEY_R)
	_add_key("toggle_mute", KEY_M)


func _add_key(action: StringName, key: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


# ── model / materials ───────────────────────────────────────────────────────

func _build_model() -> void:
	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		push_error("Wukong Ultimate GLB missing: " + MODEL_PATH)
		return
	model_root = packed.instantiate() as Node3D
	model_root.name = "WukongModel"
	# Blender +X becomes Godot +X; rotate once so the hero faces local +Z.
	model_root.rotation.y = -PI * 0.5
	add_child(model_root)

	mesh_instance = model_root.find_child("WukongUltimate_Body", true, false) as MeshInstance3D
	anim = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if mesh_instance == null or anim == null:
		push_error("GLB structure unexpected: missing mesh or AnimationPlayer")
		return
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_style_materials(mesh_instance)

	for clip in ["Idle", "Run", "Charge"]:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for clip in ["Cast", "Hit", "Victory"]:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_NONE

	fire_point = Node3D.new()
	fire_point.name = "FirePoint"
	fire_point.position = Vector3(0, 1.24, 0.62)
	add_child(fire_point)


func _style_materials(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var mat: Material = mi.get_active_material(i)
		if mat == null or not (mat is StandardMaterial3D):
			continue
		var m: StandardMaterial3D = mat.duplicate()
		var n := String(m.resource_name).to_lower()
		m.vertex_color_use_as_albedo = true
		m.rim_enabled = true
		m.rim = 0.22
		m.rim_tint = 0.45
		if "gold" in n:
			m.metallic = 0.55
			m.roughness = 0.32
			m.emission_enabled = true
			m.emission = Color(0.85, 0.55, 0.15)
			m.emission_energy_multiplier = 0.18
			m.rim = 0.35
		elif "hair" in n:
			m.metallic = 0.25
			m.roughness = 0.30
			m.rim = 0.50
		elif "fur" in n:
			m.roughness = 0.78
			m.rim = 0.30
		elif "skin" in n:
			m.roughness = 0.72
			m.metallic = 0.0
			m.rim = 0.30
			m.albedo_color = Color(0.66, 0.40, 0.22)
		elif n == "face_light":
			m.albedo_color = Color(0.90, 0.72, 0.52)
			m.roughness = 0.62
		elif n == "face_dark":
			m.albedo_color = Color(0.20, 0.12, 0.08)
			m.roughness = 0.70
		elif "face" in n:
			m.albedo_color = Color(0.80, 0.56, 0.38)
			m.roughness = 0.66
		elif "eye" in n:
			m.emission_enabled = true
			m.emission = Color(0.55, 0.82, 1.0)
			m.emission_energy_multiplier = 2.6
			m.roughness = 0.22
		elif "black" in n or "face_dark" in n:
			m.roughness = 0.95
			m.metallic = 0.0
			# keep the eye sockets matte
		elif "cloth" in n:
			m.roughness = 0.88
			m.metallic = 0.0
		elif "leather" in n:
			m.roughness = 0.55
		mi.set_surface_override_material(i, m)


# ── aura / charge VFX ───────────────────────────────────────────────────────

func _soft_particle_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length() / 16.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	return ImageTexture.create_from_image(img)


func _additive_mat(color: Color, energy := 2.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.disable_receive_shadows = true
	return m


func _build_aura() -> void:
	var shader: Shader = load("res://shaders/aura.gdshader")
	aura_mat = ShaderMaterial.new()
	aura_mat.shader = shader
	aura_mat.set_shader_parameter("intensity", 0.0)

	aura_light = OmniLight3D.new()
	aura_light.light_color = Color(0.55, 0.78, 1.0)
	aura_light.light_energy = 0.0
	aura_light.omni_range = 5.0
	aura_light.position = Vector3(0, 1.25, 0)
	aura_light.shadow_enabled = false
	add_child(aura_light)

	var blob := MeshInstance3D.new()
	var blob_mesh := CylinderMesh.new()
	blob_mesh.top_radius = 0.52
	blob_mesh.bottom_radius = 0.62
	blob_mesh.height = 0.012
	blob_mesh.radial_segments = 20
	blob.mesh = blob_mesh
	var blob_mat := StandardMaterial3D.new()
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.42)
	blob_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blob_mat.disable_receive_shadows = true
	blob.material_override = blob_mat
	blob.position = Vector3(0, 0.016, 0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)

	charge_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.02
	tor.outer_radius = 1.20
	tor.rings = 48
	tor.ring_segments = 8
	charge_ring.mesh = tor
	charge_ring.material_override = _additive_mat(Color(0.40, 0.68, 1.0), 1.6, 0.40)
	charge_ring.position.y = 0.035
	charge_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	charge_ring.visible = false
	add_child(charge_ring)

	charge_rig = Node3D.new()
	charge_rig.name = "ChargeRig"
	charge_rig.top_level = true
	add_child(charge_rig)

	var streak_mat := _additive_mat(Color(0.62, 0.84, 1.0), 1.8, 0.50)
	for i in 6:
		var streak := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.018, 0.30, 0.018)
		streak.mesh = bm
		streak.material_override = streak_mat
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streak.visible = false
		charge_rig.add_child(streak)
		rocks.append(streak)

	charge_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 1.0
	core_mesh.height = 2.0
	core_mesh.radial_segments = 20
	core_mesh.rings = 10
	charge_core.mesh = core_mesh
	charge_core.material_override = _additive_mat(Color(0.72, 0.88, 1.0), 2.0, 0.65)
	charge_core.position = Vector3(0, 1.16, 0.32)
	charge_core.scale = Vector3(0.14, 0.14, 0.14)
	charge_core.visible = false
	charge_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(charge_core)

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.16, 0.19, 0.27)
	rock_mat.roughness = 0.8
	rock_mat.metallic = 0.25
	rock_mat.rim_enabled = true
	rock_mat.rim = 0.55
	for i in 6:
		var rock := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := 0.065 + 0.022 * (i % 3)
		bm.size = Vector3(s, s * 0.7, s * 1.2)
		rock.mesh = bm
		rock.material_override = rock_mat
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		charge_rig.add_child(rock)
		rocks.append(rock)

	_trail_mesh = QuadMesh.new()
	_trail_mesh.size = Vector2(0.10, 0.10)
	_spark_material = StandardMaterial3D.new()
	_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_spark_material.vertex_color_use_as_albedo = true
	_spark_material.albedo_texture = _soft_particle_texture()
	_spark_material.disable_receive_shadows = true
	_trail_mesh.material = _spark_material

	charge_particles = CPUParticles3D.new()
	charge_particles.amount = 34
	charge_particles.lifetime = 0.85
	charge_particles.local_coords = false
	charge_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	charge_particles.emission_sphere_radius = 0.72
	charge_particles.direction = Vector3.UP
	charge_particles.spread = 180.0
	charge_particles.gravity = Vector3(0, -0.35, 0)
	charge_particles.initial_velocity_min = 0.15
	charge_particles.initial_velocity_max = 0.9
	charge_particles.scale_amount_min = 0.55
	charge_particles.scale_amount_max = 1.9
	charge_particles.color = Color(0.68, 0.86, 1.0, 0.9)
	charge_particles.mesh = _trail_mesh
	charge_particles.emitting = false
	charge_particles.position.y = 1.1
	charge_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(charge_particles)


# ── input / movement ────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _action_lock > 0.0:
		_action_lock -= delta
	if _invuln > 0.0:
		_invuln -= delta
	if _pending_power > 0.0:
		_pending_timer -= delta
		if _pending_timer <= 0.0:
			var p := _pending_power
			_pending_power = 0.0
			ki_release.emit(_pending_origin, _pending_dir, p)
			cast_started.emit()

	if controls_enabled:
		if Input.is_action_just_pressed("charge") and state in ["idle", "run"]:
			begin_charge()
		if charging and Input.is_action_just_released("charge"):
			release_charge()

	var wish := Vector3.ZERO
	if controls_enabled and state not in ["cast", "hit", "victory", "dead"]:
		var cam := get_viewport().get_camera_3d()
		var right := Vector3.RIGHT
		var forward := Vector3.FORWARD
		if cam != null:
			right = cam.global_basis.x
			right.y = 0.0
			right = right.normalized()
			forward = -cam.global_basis.z
			forward.y = 0.0
			forward = forward.normalized()
		var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		wish = right * input.x + forward * input.y
	if demo_axis.length_squared() > 0.001 and state not in ["cast", "hit", "victory", "dead"]:
		wish = demo_axis.normalized()
	if charging:
		wish *= 0.26

	var target := wish * MOVE_SPEED
	var rate := ACCEL if wish.length_squared() > 0.01 else DECEL
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()

	var flat := Vector2(position.x, position.z)
	if flat.length() > ARENA_LIMIT:
		flat = flat.normalized() * ARENA_LIMIT
		position.x = flat.x
		position.z = flat.y
	if position.y < -3.0:
		position = Vector3(0, 0.1, 3.4)
		velocity = Vector3.ZERO

	if wish.length_squared() > 0.02 and state not in ["charge", "cast", "hit", "victory", "dead"]:
		var desired_yaw := atan2(wish.x, wish.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw,
			1.0 - exp(-11.0 * delta))

	if charging:
		charge = clampf(charge + delta / CHARGE_TIME, 0.0, 1.0)

	if _action_lock <= 0.0:
		if state == "cast" or state == "hit":
			state = "idle"
			play_locomotion()
		elif state in ["idle", "run"]:
			play_locomotion()


func play_locomotion() -> void:
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > 0.35:
		state = "run"
		play_anim("Run", 0.16)
		if anim != null:
			anim.speed_scale = clampf(spd / MOVE_SPEED, 0.7, 1.35)
	else:
		state = "idle"
		play_anim("Idle", 0.22)
		if anim != null:
			anim.speed_scale = 1.0


func play_anim(name: String, blend := 0.18) -> void:
	if anim == null or not anim.has_animation(name):
		return
	if anim.current_animation == name and anim.is_playing():
		return
	anim.play(name, blend)


# ── actions ─────────────────────────────────────────────────────────────────

func begin_charge() -> bool:
	if state in ["cast", "hit", "victory", "dead"] or energy < MIN_CHARGE_ENERGY:
		return false
	charging = true
	charge = 0.0
	state = "charge"
	play_anim("Charge", 0.16)
	charge_started.emit()
	return true


func release_charge() -> float:
	if not charging:
		return 0.0
	charging = false
	var power := clampf(charge, 0.25, 1.0)
	var cost := 22.0 + 28.0 * power
	if energy < 10.0 or state == "hit" or state == "dead":
		state = "idle"
		play_locomotion()
		return 0.0
	energy = maxf(0.0, energy - minf(cost, energy))
	state = "cast"
	_action_lock = 0.55
	charge = 0.0
	play_anim("Cast", 0.10)
	_pending_power = power
	_pending_timer = 0.17
	_pending_origin = fire_point.global_position if fire_point != null else global_position + Vector3(0, 1.2, 0.5)
	_pending_dir = global_basis.z.normalized()
	return power


func take_damage(amount: int, _from: Vector3 = Vector3.ZERO) -> void:
	if state in ["victory", "dead"] or _invuln > 0.0:
		return
	_invuln = 0.55
	hp = maxi(0, hp - amount)
	charging = false
	charge = 0.0
	state = "hit"
	_action_lock = 0.48
	play_anim("Hit", 0.08)
	hurt.emit(amount)
	if hp <= 0:
		state = "dead"
		_action_lock = 999.0
		died.emit()


func play_victory() -> void:
	state = "victory"
	charging = false
	_action_lock = 999.0
	play_anim("Victory", 0.20)


func aim_at(world_pos: Vector3) -> void:
	var d := world_pos - global_position
	d.y = 0.0
	if d.length_squared() > 0.001:
		rotation.y = atan2(d.x, d.z)


func set_demo_move(dir: Vector3) -> void:
	demo_axis = dir


func reset_state(spawn: Vector3, facing: float) -> void:
	position = spawn
	velocity = Vector3.ZERO
	rotation.y = facing
	hp = MAX_HP
	energy = MAX_ENERGY
	charge = 0.0
	charging = false
	state = "idle"
	_action_lock = 0.0
	_invuln = 0.0
	_pending_power = 0.0
	_action_lock = 0.0
	demo_axis = Vector3.ZERO
	visible = true
	play_anim("Idle", 0.2)
	_aura_target = 0.0
	_aura_value = 0.0
	_update_aura_visuals(0.0)


func debug_set_charge(p: float) -> void:
	charging = p > 0.01
	charge = clampf(p, 0.0, 1.0)
	if charging:
		state = "charge"
		play_anim("Charge", 0.1)
	_update_aura_visuals(0.0)


# ── per-frame aura / rocks ──────────────────────────────────────────────────

func _process(delta: float) -> void:
	_orbit_t += delta
	_aura_target = 0.0
	if charging:
		_aura_target = 0.30 + charge * 0.50
	elif state == "cast":
		_aura_target = 0.45
	_aura_value = lerpf(_aura_value, _aura_target, 1.0 - exp(-9.0 * delta))
	_update_aura_visuals(delta)


func _update_aura_visuals(delta: float) -> void:
	if aura_mat != null:
		aura_mat.set_shader_parameter("intensity", _aura_value)
	if aura_light != null:
		aura_light.light_energy = _aura_value * 1.5
	if charge_ring != null:
		var show := charging or _aura_value > 0.2
		charge_ring.visible = show
		if show:
			var sc := 0.55 + charge * 0.85 + 0.04 * sin(_orbit_t * 6.0)
			charge_ring.scale = Vector3(sc, 1.0, sc)
			charge_ring.rotation.y += delta * (0.7 + charge * 2.0)
	if charge_particles != null:
		charge_particles.emitting = charging and charge > 0.03
	if charge_core != null:
		charge_core.visible = charging or state == "cast"
		var cs := 0.060 + charge * 0.11 + 0.006 * sin(_orbit_t * 9.0)
		charge_core.scale = Vector3(cs, cs, cs)
	if charge_rig != null:
		charge_rig.global_position = global_position
		var show_rocks := charging and charge > 0.05
		for i in rocks.size():
			var rock := rocks[i]
			rock.visible = show_rocks
			if show_rocks:
				var a := _orbit_t * (0.6 + i * 0.07) + TAU * float(i) / float(rocks.size())
				if i < 6:
					var radius := 1.25 + charge * 0.35
					var yy := 0.30 + float(i) * 0.25 + sin(_orbit_t * 2.3 + i) * 0.06 + charge * 0.55
					rock.position = Vector3(cos(a) * radius, yy, sin(a) * radius)
					rock.rotation = Vector3(_orbit_t * 0.9 + i, _orbit_t * 1.3 + i * 0.7, i)
					var s := 0.4 + charge * 0.85
					rock.scale = Vector3.ONE * s
				else:
					var k := i - 6
					var radius := 1.35 + charge * 0.25
					var yy := 0.25 + float(k) * 0.26 + charge * 0.50 + sin(_orbit_t * 3.0 + k) * 0.05
					rock.position = Vector3(cos(a * 1.4) * radius, yy, sin(a * 1.4) * radius)
					rock.rotation = Vector3(0.0, -a * 1.4, 0.15)
					var s2 := 0.45 + charge * 0.65
					rock.scale = Vector3(s2, s2, s2)
