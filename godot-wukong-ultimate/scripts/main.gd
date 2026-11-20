extends Node3D

## 齐天大圣 · 极意 — arena, camera, combo, VFX, win/lose and demo hooks.

const SPAWN := Vector3(-1.4, 0.05, 3.6)
const DUMMY_POS := Vector3(1.2, 0.0, -3.4)

var arena: Arena
var player: WukongPlayer
var dummy: StoneSentinel
var hud: UltimateHUD
var camera: Camera3D
var projectile_root: Node3D

var elapsed := 0.0
var combo := 0
var combo_timer := 0.0
var max_combo := 0
var hits := 0
var victory := false
var defeat := false
var victory_reveal := 0.0
var defeat_reveal := 0.0
var warning_timer := 0.0
var trauma := 0.0

var cam_yaw := 0.0
var cam_pitch := -0.23
var cam_distance := 4.9
var cam_target := Vector3.ZERO
var cinematic := false
var cinematic_pos := Vector3.ZERO
var cinematic_look := Vector3.ZERO
var cinematic_fov := 55.0

var _t := 0.0
var _soft_tex: ImageTexture
var _spark_quad: QuadMesh
var _spark_mat: StandardMaterial3D
var _stone_mat: StandardMaterial3D


func _ready() -> void:
	_ensure_reset_action()
	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)

	dummy = StoneSentinel.new()
	dummy.name = "StoneSentinel"
	dummy.position = DUMMY_POS
	dummy.stone_material = arena.stone_dark
	dummy.dark_material = arena.stone_dark
	dummy.gold_material = arena.gold_material
	add_child(dummy)
	dummy.player = null

	player = WukongPlayer.new()
	player.name = "Wukong"
	player.position = SPAWN
	var aim := DUMMY_POS - SPAWN
	player.rotation.y = atan2(aim.x, aim.z)
	add_child(player)
	dummy.player = player

	projectile_root = Node3D.new()
	projectile_root.name = "Projectiles"
	add_child(projectile_root)

	camera = Camera3D.new()
	camera.name = "OrbitCamera"
	camera.fov = cinematic_fov
	camera.near = 0.08
	camera.far = 260.0
	add_child(camera)
	camera.current = true
	var headlight := SpotLight3D.new()
	headlight.name = "CameraKey"
	headlight.light_color = Color(1.0, 0.88, 0.72)
	headlight.light_energy = 4.0
	headlight.spot_range = 20.0
	headlight.spot_angle = 52.0
	headlight.spot_attenuation = 0.8
	headlight.shadow_enabled = false
	camera.add_child(headlight)
	cam_target = SPAWN + Vector3(0, 1.30, 0)
	cam_yaw = 0.0
	_update_camera(0.0, true)

	_build_impact_assets()

	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	layer.layer = 10
	add_child(layer)
	hud = UltimateHUD.new()
	hud.name = "HUD"
	hud.main = self
	hud.player = player
	hud.dummy = dummy
	layer.add_child(hud)

	player.ki_release.connect(_on_ki_release)
	player.hurt.connect(_on_player_hurt)
	player.died.connect(_on_player_died)
	player.cast_started.connect(_on_cast_started)
	dummy.hit_taken.connect(_on_dummy_hit)
	dummy.hp_changed.connect(_on_dummy_hp_changed)
	dummy.defeated.connect(_on_dummy_defeated)
	dummy.pulse_telegraph.connect(_on_pulse_telegraph)
	dummy.pulse_hit.connect(_on_pulse_hit)

	_print_ready()
	_warm_effects.call_deferred()


func _warm_effects() -> void:
	# First-hit shader warm-up: a small silver burst at spawn, then back to idle.
	_spawn_muzzle(player.global_position + Vector3(0, 1.3, 0.35))
	var warm_blast := spawn_ki_at(player.global_position + Vector3(0, 1.3, 0.5), Vector3.UP, 0.1, 1)
	warm_blast.life = 0.12
	player.debug_set_charge(0.12)
	await get_tree().create_timer(0.16).timeout
	if is_instance_valid(player):
		player.charging = false
		player.charge = 0.0
		player.state = "idle"
		player.play_anim("Idle", 0.1)


func _print_ready() -> void:
	var bones := 0
	var clips := PackedStringArray()
	if player != null and player.model_root != null:
		var skels := player.model_root.find_children("*", "Skeleton3D", true, false)
		if not skels.is_empty():
			bones = (skels[0] as Skeleton3D).get_bone_count()
		if player.anim != null:
			clips = PackedStringArray(player.anim.get_animation_list())
	print("WUKONG_ULT_READY bones=%d clips=%s sentinel_hp=%d" % [bones, str(clips), dummy.hp])


func _ensure_reset_action() -> void:
	if not InputMap.has_action("reset"):
		InputMap.add_action("reset")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	InputMap.action_add_event("reset", ev)


func _process(delta: float) -> void:
	_t += delta
	if not victory and not defeat:
		elapsed += delta
	elif victory_reveal > 0.0:
		victory_reveal = maxf(0.0, victory_reveal - delta)
	elif defeat_reveal > 0.0:
		defeat_reveal = maxf(0.0, defeat_reveal - delta)
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
		warning_timer = maxf(0.0, warning_timer - delta)
	else:
		warning_timer = maxf(0.0, warning_timer - delta)
	trauma = maxf(0.0, trauma - delta * 1.5)
	if Input.is_action_just_pressed("reset"):
		reset_arena()
	_update_camera(delta, false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_distance = clampf(cam_distance - 0.45, 3.2, 8.6)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_distance = clampf(cam_distance + 0.45, 3.2, 8.6)
	elif event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		var mm := event as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.004
		cam_pitch = clampf(cam_pitch - mm.relative.y * 0.003, -0.88, 0.32)


func _update_camera(delta: float, snap: bool) -> void:
	if camera == null:
		return
	if cinematic:
		camera.global_position = cinematic_pos
		camera.look_at(cinematic_look, Vector3.UP)
		camera.fov = cinematic_fov
		return
	if victory:
		cam_yaw += delta * 0.18
		cam_distance = lerpf(cam_distance, 6.0, 1.0 - exp(-2.0 * delta))
	var target := player.global_position + Vector3(0, 1.30, 0)
	if snap:
		cam_target = target
	else:
		cam_target = cam_target.lerp(target, 1.0 - exp(-8.0 * delta))
	var cp := cos(cam_pitch)
	var offset := Vector3(sin(cam_yaw) * cp, -sin(cam_pitch), cos(cam_yaw) * cp) * cam_distance
	var pos := cam_target + offset
	var shake := trauma * trauma
	var jitter := Vector3(
		sin(_t * 53.0) * 0.6 + sin(_t * 31.0 + 1.2) * 0.4,
		sin(_t * 47.0 + 0.4) * 0.6,
		sin(_t * 61.0 + 2.1) * 0.5) * shake * 0.24
	pos += jitter
	camera.global_position = pos
	camera.look_at(cam_target + Vector3(0, 0.12, 0) + jitter * 0.25, Vector3.UP)
	camera.rotate_object_local(Vector3(0, 0, 1), sin(_t * 37.0) * shake * 0.035)
	camera.fov = cinematic_fov


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


# ── impacts / damage numbers ────────────────────────────────────────────────

func _build_impact_assets() -> void:
	_soft_tex = _make_soft_texture()
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mat.albedo_texture = _soft_tex
	_spark_mat.disable_receive_shadows = true
	_spark_quad = QuadMesh.new()
	_spark_quad.size = Vector2(0.16, 0.16)
	_spark_quad.material = _spark_mat

	_stone_mat = StandardMaterial3D.new()
	_stone_mat.albedo_color = Color(0.14, 0.17, 0.25)
	_stone_mat.roughness = 0.85
	_stone_mat.metallic = 0.15


func _make_soft_texture() -> ImageTexture:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y in 48:
		for x in 48:
			var d := Vector2(x + 0.5 - 24.0, y + 0.5 - 24.0).length() / 24.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _additive(color: Color, energy: float, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.disable_receive_shadows = true
	m.vertex_color_use_as_albedo = true
	return m


func _spawn_impact(pos: Vector3, color: Color, scale: float) -> void:
	# hot flash
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.20 * scale
	sm.height = 0.52 * scale
	sm.radial_segments = 16
	sm.rings = 8
	flash.mesh = sm
	var flash_mat := _additive(color, 2.4, 0.55)
	flash.material_override = flash_mat
	flash.position = pos
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * (1.7 + scale * 0.6), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash_mat, "albedo_color:a", 0.0, 0.34)
	tw.chain().tween_callback(flash.queue_free)

	# ground shock ring
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.30
	tm.outer_radius = 0.42
	tm.rings = 48
	tm.ring_segments = 8
	ring.mesh = tm
	var rm := _additive(color, 3.0, 0.65)
	ring.material_override = rm
	ring.position = Vector3(pos.x, 0.05, pos.z)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var tw2 := create_tween().set_parallel(true)
	var ring_scale := 1.6 + 1.5 * scale
	tw2.tween_property(ring, "scale", Vector3(ring_scale, 1.0, ring_scale), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(rm, "albedo_color:a", 0.0, 0.45)
	tw2.chain().tween_callback(ring.queue_free)

	# sparks
	var sparks := CPUParticles3D.new()
	sparks.amount = 24
	sparks.lifetime = 0.55
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.local_coords = false
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.18 * scale
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.gravity = Vector3(0, -7.0, 0)
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 7.0 * scale
	sparks.scale_amount_min = 0.45
	sparks.scale_amount_max = 1.6
	sparks.color = Color(color.r, color.g, color.b, 0.95)
	sparks.mesh = _spark_quad
	sparks.position = pos
	sparks.emitting = true
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sparks)
	_free_later(sparks, 1.2)

	# stone debris
	var debris := CPUParticles3D.new()
	debris.amount = 14
	debris.lifetime = 0.9
	debris.one_shot = true
	debris.explosiveness = 0.9
	debris.local_coords = false
	debris.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	debris.emission_sphere_radius = 0.20
	debris.direction = Vector3.UP
	debris.spread = 80.0
	debris.gravity = Vector3(0, -14.0, 0)
	debris.initial_velocity_min = 2.0
	debris.initial_velocity_max = 5.5
	debris.angular_velocity_min = -300.0
	debris.angular_velocity_max = 300.0
	debris.scale_amount_min = 0.4
	debris.scale_amount_max = 1.2
	var dbm := BoxMesh.new()
	dbm.size = Vector3(0.07, 0.055, 0.09)
	dbm.material = _stone_mat
	debris.mesh = dbm
	debris.position = pos
	debris.emitting = true
	debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(debris)
	_free_later(debris, 1.3)

	# point light flash
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0 * scale + 1.0
	light.omni_range = 5.0 * scale
	light.shadow_enabled = false
	light.position = pos
	add_child(light)
	var tw3 := create_tween()
	tw3.tween_property(light, "light_energy", 0.0, 0.35)
	tw3.tween_callback(light.queue_free)

	add_trauma(0.22 + 0.16 * scale)
	_free_later(flash, 0.5)
	_free_later(ring, 0.8)
	_free_later(light, 0.6)


func _spawn_muzzle(pos: Vector3) -> void:
	_spawn_impact(pos, Color(0.60, 0.84, 1.0), 0.45)


func spawn_damage_number(pos: Vector3, amount: int, color := Color(1.0, 0.84, 0.48)) -> void:
	var label := Label3D.new()
	label.text = str(amount)
	label.font = hud.font
	label.font_size = 54
	label.outline_size = 12
	label.outline_modulate = Color(0.02, 0.03, 0.06, 0.9)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.render_priority = 20
	label.pixel_size = 0.0009
	label.position = pos + Vector3(randf_range(-0.28, 0.28), randf_range(0.15, 0.4), randf_range(-0.2, 0.2))
	add_child(label)
	label.scale = Vector3.ONE * 1.4
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.15, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.85)
	tw.tween_property(label, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(label.queue_free)


func _free_later(node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(node):
		node.queue_free()


# ── combat signals ──────────────────────────────────────────────────────────

func _on_ki_release(origin: Vector3, dir: Vector3, power: float) -> void:
	var dmg := int(30 + 90 * power)
	spawn_ki_at(origin, dir, power, dmg)
	_spawn_muzzle(origin)
	add_trauma(0.16 + 0.10 * power)


func spawn_ki_at(origin: Vector3, dir: Vector3, power: float, damage: int) -> KiBlast:
	var blast := KiBlast.new()
	blast.name = "KiBlast"
	projectile_root.add_child(blast)
	blast.setup(origin, dir, power, damage, player, Callable(self, "_on_ki_impact"))
	return blast


func _on_ki_impact(pos: Vector3, dir: Vector3, collider: Object, damage: int, power: float) -> void:
	var sentinel_hit := collider != null and collider.has_method("take_hit")
	if sentinel_hit:
		collider.take_hit(damage, dir, pos)
	_spawn_impact(pos, Color(1.0, 0.76, 0.40), 0.75 + 0.65 * power)
	add_trauma(0.28 + 0.20 * power)


func _on_cast_started() -> void:
	add_trauma(0.14)


func _on_dummy_hit(amount: int, world_pos: Vector3, _dir: Vector3) -> void:
	hits += 1
	combo = combo + 1 if combo_timer > 0.0 else 1
	combo_timer = 2.4
	max_combo = maxi(max_combo, combo)
	spawn_damage_number(world_pos, amount)


func _on_dummy_hp_changed(_hp: int, _max_hp: int) -> void:
	pass


func _on_dummy_defeated() -> void:
	if victory:
		return
	victory = true
	victory_reveal = 0.85
	warning_timer = 0.0
	player.play_victory()
	dummy.ai_enabled = false
	add_trauma(0.75)
	var p: Vector3 = dummy.global_position + Vector3(0, 1.15, 0.2)
	_spawn_impact(p, Color(1.0, 0.78, 0.36), 2.2)
	_spawn_impact(p + Vector3(0, 1.0, 0), Color(0.65, 0.85, 1.0), 1.6)
	for n in get_tree().get_nodes_in_group("projectiles"):
		n.queue_free()
	print("ULT_VICTORY time=%.2f hits=%d max_combo=%d" % [elapsed, hits, max_combo])


func _on_player_hurt(amount: int) -> void:
	hud.flash_red = 0.8
	add_trauma(0.55)
	spawn_damage_number(player.global_position + Vector3(0, 2.1, 0), amount, Color(1.0, 0.42, 0.34))


func _on_player_died() -> void:
	if defeat or victory:
		return
	defeat = true
	defeat_reveal = 0.8
	warning_timer = 0.0
	dummy.ai_enabled = false
	add_trauma(0.9)
	print("ULT_DEFEAT time=%.2f" % elapsed)


func _on_pulse_telegraph() -> void:
	warning_timer = 1.15
	add_trauma(0.10)


func _on_pulse_hit() -> void:
	hud.flash_red = 0.65
	add_trauma(0.72)


# ── reset / demo API ────────────────────────────────────────────────────────

func reset_arena() -> void:
	for n in get_tree().get_nodes_in_group("projectiles"):
		n.queue_free()
	player.reset_state(SPAWN, atan2((DUMMY_POS - SPAWN).x, (DUMMY_POS - SPAWN).z))
	dummy.reset_state()
	dummy.player = player
	victory = false
	defeat = false
	victory_reveal = 0.0
	defeat_reveal = 0.0
	combo = 0
	combo_timer = 0.0
	max_combo = 0
	hits = 0
	elapsed = 0.0
	warning_timer = 0.0
	trauma = 0.0
	cam_yaw = 0.0
	cam_pitch = -0.23
	cam_distance = 4.9
	cam_target = SPAWN + Vector3(0, 1.30, 0)
	cinematic = false
	if hud != null:
		hud.flash_red = 0.0
	print("ULT_RESET OK")


func set_cinematic_camera(pos: Vector3, look: Vector3, fov := 55.0) -> void:
	cinematic = true
	cinematic_pos = pos
	cinematic_look = look
	cinematic_fov = fov
	_update_camera(0.0, true)


func clear_cinematic_camera() -> void:
	cinematic = false
	cinematic_fov = 55.0
	camera.fov = 55.0


func set_hud_visible(v: bool) -> void:
	if hud != null:
		hud.visible = v


func set_controls_enabled(v: bool) -> void:
	player.controls_enabled = v


func demo_charge(power: float) -> void:
	player.controls_enabled = false
	player.debug_set_charge(power)


func demo_run() -> void:
	player.set_demo_move(Vector3(0, 0, -1))


func demo_stop() -> void:
	player.set_demo_move(Vector3.ZERO)


func demo_fire_at_dummy(power: float, damage := -1) -> void:
	player.aim_at(dummy.global_position)
	var chest: Vector3 = dummy.global_position + Vector3(0, 1.20, 0)
	var origin: Vector3 = player.global_position + Vector3(0, 1.24, 0) + (chest - (player.global_position + Vector3(0, 1.24, 0))).normalized() * 0.55
	var dir: Vector3 = (chest - origin).normalized()
	var dmg := damage if damage > 0 else int(30 + 90 * power)
	spawn_ki_at(origin, dir, power, dmg)
	player.play_anim("Cast", 0.08)
	player.state = "cast"
	player._action_lock = 0.55
	_spawn_muzzle(origin)
	add_trauma(0.2)


func demo_impact(power := 1.0) -> void:
	var chest: Vector3 = dummy.global_position + Vector3(0, 1.20, 0.45)
	var dir: Vector3 = (player.global_position - dummy.global_position).normalized()
	dummy.take_hit(int(30 + 90 * power), dir, chest)
	_spawn_impact(chest, Color(1.0, 0.72, 0.36), 1.0)


func demo_set_dummy_hp(value: int) -> void:
	dummy.hp = clampi(value, 0, dummy.max_hp)
	dummy.hp_changed.emit(dummy.hp, dummy.max_hp)


func demo_victory() -> void:
	dummy.force_defeat()


func demo_damage_player(amount := 14) -> void:
	player.take_damage(amount)
	hud.flash_red = 0.7


func demo_reset() -> void:
	reset_arena()


func get_stats() -> Dictionary:
	return {
		"elapsed": elapsed, "combo": combo, "max_combo": max_combo,
		"hits": hits, "victory": victory, "defeat": defeat,
		"player_hp": player.hp, "dummy_hp": dummy.hp,
	}
