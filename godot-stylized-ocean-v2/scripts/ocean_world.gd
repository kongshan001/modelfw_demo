extends Node3D

# 主控：搭建场景、鼠标交互（涟漪尾迹/落石水花）、相机、GUI、调试统计。
# 视觉层文件；不包含玩法逻辑。所有资产均程序化原创。

var field: IslandField
var ocean: StylizedOcean
var scene: OceanScene
var cam: OrbitRig
var hud: OceanHud

var paused := false
var ripples_enabled := true
var rain_on := false
var time_hour := 11.5
var water_style := 0
var debug_view := 0
var virtual_cursor := Vector2(-99999, -99999)

var _cursor_ring: MeshInstance3D
var _cursor_mat: StandardMaterial3D
var _cursor_visible := false
var _shore_line: MeshInstance3D

var _paint_down := false
var _paint_last_pos := Vector2.ZERO
var _paint_accum := 0.0
var _press_ms := 0
var _press_move := 0.0
var _press_screen := Vector2.ZERO

var _rock_mesh: ArrayMesh
var _rock_mat: Material
var _falling: Array[Dictionary] = []
var _floating: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []

var _wake_accum := 0.0
var _rain_accum := 0.0
var _stats_accum := 0.0
var _rng := RandomNumberGenerator.new()

var _lightning_timer := 8.0


func _ready() -> void:
	_rng.seed = 90210
	_build()


func _build() -> void:
	field = IslandField.new(20261126)
	print("[ocean] baking island field…")
	ocean = StylizedOcean.new()
	add_child(ocean)
	ocean.setup(field)
	scene = OceanScene.new()
	scene.build(self, field, ocean)
	print("[ocean] scene built")

	cam = OrbitRig.new()
	cam.name = "OrbitCamera"
	cam.field = field
	add_child(cam)
	cam.setup(field)
	cam.set_orbit(90.0, 58.0, 108.0)
	cam.set_target_height(1.6)

	hud = OceanHud.new()
	add_child(hud)
	hud.setup(self, 1.0)

	_build_cursor()
	_build_shore_line()
	_rock_mesh = OceanProps.make_rock_mesh(5150, 1, true)
	_rock_mat = scene.rock_material
	scene.set_time(time_hour)
	_update_stats_label()


func _build_cursor() -> void:
	_cursor_mat = StandardMaterial3D.new()
	_cursor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cursor_mat.albedo_color = Color(0.92, 1.0, 0.99, 0.95)
	_cursor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cursor_mat.no_depth_test = false
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	torus.rings = 32
	torus.ring_segments = 4
	_cursor_ring = MeshInstance3D.new()
	_cursor_ring.name = "CursorRing"
	_cursor_ring.mesh = torus
	_cursor_ring.material_override = _cursor_mat
	_cursor_ring.rotation_degrees.x = 90.0
	_cursor_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor_ring.visible = false
	add_child(_cursor_ring)


func _build_shore_line() -> void:
	var pts: Array[Vector3] = []
	var n := 260
	for i in n:
		var theta := TAU * float(i) / float(n)
		var r := field.coast_radius(theta)
		var x := cos(theta) * r
		var z := sin(theta) * r
		var y := maxf(field.height(x, z) + 0.32, 0.34) + sin(theta * 6.0) * 0.04
		pts.append(Vector3(x, y, z))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv2 := PackedVector2Array()
	var w := 0.14
	var col := Color("#ff7a3d")
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var dir := (b - a).normalized()
		var side := dir.cross(Vector3.UP).normalized() * w
		var a0 := a - side
		var a1 := a + side
		var b0 := b - side
		var b1 := b + side
		# 两个三角形（朝上）
		for tri in [[a0, a1, b1], [a0, b1, b0]]:
			var v0: Vector3 = tri[0]
			var v1: Vector3 = tri[1]
			var v2: Vector3 = tri[2]
			var nrm := (v1 - v0).cross(v2 - v0).normalized()
			if nrm.y < 0:
				nrm = -nrm
			verts.append(v0)
			verts.append(v1)
			verts.append(v2)
			normals.append(nrm)
			normals.append(nrm)
			normals.append(nrm)
			colors.append(col)
			colors.append(col)
			colors.append(col)
			uv2.append(Vector2.ZERO)
			uv2.append(Vector2.ZERO)
			uv2.append(Vector2.ZERO)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.emission_enabled = true
	mat.emission = Color("#ff5a22")
	mat.emission_energy_multiplier = 0.8
	mesh.surface_set_material(0, mat)
	_shore_line = MeshInstance3D.new()
	_shore_line.name = "ShorelineAuthoring"
	_shore_line.mesh = mesh
	_shore_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shore_line.visible = false
	add_child(_shore_line)


func _process(delta: float) -> void:
	if not paused:
		tick(delta)
	_update_cursor_from_mouse()


func tick(delta: float) -> void:
	ocean.tick(delta)
	scene.tick(delta, ocean.sim_time)
	scene.set_waves_time(ocean.sim_time)
	cam.tick(delta)
	_update_falling(delta)
	_update_floating(delta)
	_update_rings(delta)
	_update_splashes(delta)
	_update_painting(delta)
	_update_rain(delta)
	_update_boat_wake(delta)
	_stats_accum += delta
	if _stats_accum > 0.25:
		_stats_accum = 0.0
		_update_stats_label()


func _update_cursor_from_mouse() -> void:
	if cam == null:
		return
	var mp := get_viewport().get_mouse_position()
	var hit := cam.screen_to_water(mp)
	var over_ui := false
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and hovered != hud.root:
		over_ui = true
	var valid: bool = hit["valid"] and not over_ui and ripples_enabled
	if virtual_cursor.x > -9000:
		var vhit := cam.screen_to_water(virtual_cursor)
		hit = vhit
		valid = vhit["valid"]
	if valid:
		var xz: Vector2 = hit["pos"]
		var wy := ocean.get_wave_height_at(xz.x, xz.y)
		_cursor_ring.visible = true
		_cursor_ring.position = Vector3(xz.x, wy + 0.26, xz.y)
		var s := 1.0 + sin(ocean.sim_time * 4.2) * 0.07
		_cursor_ring.scale = Vector3(s, s, s)
		_cursor_visible = true
	else:
		_cursor_ring.visible = false
		_cursor_visible = false


func _update_painting(delta: float) -> void:
	if not _paint_down:
		return
	_paint_accum += delta
	if _paint_accum < 0.09:
		return
	_paint_accum = 0.0
	var mp := get_viewport().get_mouse_position()
	var hit := cam.screen_to_water(mp)
	if not hit["valid"]:
		return
	var xz: Vector2 = hit["pos"]
	if xz.distance_to(_paint_last_pos) < 0.28:
		return
	_paint_last_pos = xz
	ocean.spawn_ripple(xz.x, xz.y, 0.62)


func _update_rain(delta: float) -> void:
	if not rain_on:
		return
	_rain_accum += delta
	_lightning_timer -= delta
	if _rain_accum > 0.19:
		_rain_accum = 0.0
		for attempt in 8:
			var ang := _rng.randf_range(0.0, TAU)
			var r := _rng.randf_range(32.0, 62.0)
			var x := cos(ang) * r
			var z := sin(ang) * r
			if field.water_depth_at(x, z) > 0.4:
				ocean.spawn_ripple(x, z, _rng.randf_range(0.25, 0.45))
				break
	if _lightning_timer <= 0.0:
		_lightning_timer = _rng.randf_range(9.0, 18.0)
		_flash_lightning()


func _flash_lightning() -> void:
	if scene == null or scene.sun == null:
		return
	var tween := create_tween()
	tween.tween_property(scene.env, "background_color", Color("#dfe9ff"), 0.06)
	tween.tween_property(scene.env, "background_color", scene.palette["sky_horizon"], 0.5)


func _update_boat_wake(delta: float) -> void:
	_wake_accum += delta
	if _wake_accum < 0.42:
		return
	_wake_accum = 0.0
	if scene == null or scene.boat == null:
		return
	var bp := scene.boat.position
	var back := -scene.boat.global_transform.basis.z
	var x := bp.x - back.x * 2.0
	var z := bp.z - back.z * 2.0
	if field.water_depth_at(x, z) > 0.5:
		ocean.spawn_ripple(x, z, 0.38, 0.15)


# ───────────────────────── 输入 ─────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit := cam.screen_to_water(mb.position)
				if hit["valid"] and ripples_enabled:
					var xz: Vector2 = hit["pos"]
					_paint_down = true
					_paint_accum = 1.0
					_paint_last_pos = xz
					_press_ms = Time.get_ticks_msec()
					_press_move = 0.0
					_press_screen = mb.position
					ocean.spawn_ripple(xz.x, xz.y, 0.95)
			else:
				if _paint_down:
					_paint_down = false
					var elapsed := Time.get_ticks_msec() - _press_ms
					if elapsed < 240 and _press_move < 9.0:
						var hit := cam.screen_to_water(mb.position)
						if hit["valid"] and ripples_enabled:
							_drop_rock(hit["point"], hit["pos"])
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _paint_down:
			_press_move += mm.relative.length()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_H:
				hud.set_ui_visible(not hud.visible)
			KEY_SPACE:
				paused = not paused
				hud.set_caption("已暂停" if paused else "")
			KEY_R:
				set_rain(not rain_on)
			KEY_C:
				set_auto_orbit(not cam.auto_orbit)
			KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7:
				set_debug_view(key.keycode - KEY_F1)


# ───────────────────────── 落石 / 水花 ─────────────────────────
func _drop_rock(impact_point: Vector3, xz: Vector2) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _rock_mesh
	mi.material_override = _rock_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var s := _rng.randf_range(0.22, 0.36)
	mi.scale = Vector3.ONE * s
	mi.position = Vector3(xz.x, impact_point.y + 11.0, xz.y)
	mi.rotation = Vector3(_rng.randf() * 3.0, _rng.randf() * 3.0, _rng.randf() * 3.0)
	add_child(mi)
	_falling.append({"node": mi, "target": Vector3(xz.x, 0.0, xz.y), "vy": 0.0, "spin": Vector3(2.5, 3.0, 1.5)})


func _update_falling(delta: float) -> void:
	var done: Array[Dictionary] = []
	for f in _falling:
		var node: MeshInstance3D = f["node"]
		f["vy"] -= 26.0 * delta
		node.position.y += f["vy"] * delta
		var spin: Vector3 = f["spin"]
		node.rotation += spin * delta
		if node.position.y <= 0.18:
			var target: Vector3 = f["target"]
			_spawn_splash(Vector3(target.x, 0.0, target.z), 1.8)
			ocean.spawn_ripple(target.x, target.z, 1.8)
			var keep := node
			keep.position.y = 0.08
			keep.scale = Vector3.ONE * _rng.randf_range(0.2, 0.3)
			_floating.append({"node": keep, "born": ocean.sim_time, "phase": _rng.randf() * TAU})
			done.append(f)
	_falling = _falling.filter(func(f): return not done.has(f))


func _update_floating(delta: float) -> void:
	for f in _floating:
		var node: MeshInstance3D = f["node"]
		var age: float = ocean.sim_time - float(f["born"])
		if not is_instance_valid(node):
			continue
		var x := node.position.x
		var z := node.position.z
		var wy := ocean.get_wave_height_at(x, z)
		node.position.y = wy + 0.02 + sin(age * 1.7 + float(f["phase"])) * 0.05
		node.rotation.y += delta * 0.25
		if age > 6.0:
			node.position.y -= delta * 0.35
			node.scale *= (1.0 - delta * 0.5)
		if age > 9.0:
			node.queue_free()
			f["dead"] = true
	_floating = _floating.filter(func(f): return not f.get("dead", false))


func _spawn_splash(pos: Vector3, strength: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 22
	p.lifetime = 0.65
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 42.0
	p.initial_velocity_min = 2.2 * strength
	p.initial_velocity_max = 5.0 * strength
	p.gravity = Vector3(0, -13.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var droplet := SphereMesh.new()
	droplet.radius = 0.055
	droplet.height = 0.11
	droplet.radial_segments = 5
	droplet.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.94, 1.0, 1.0, 0.95)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	droplet.material = m
	p.mesh = droplet
	p.position = Vector3(pos.x, ocean.get_wave_height_at(pos.x, pos.z) + 0.05, pos.z)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	_splashes.append({"node": p, "age": 0.0, "life": 1.2})
	_spawn_ring(pos, strength)

	# 白色扩散环
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.8
	torus.rings = 36
	torus.ring_segments = 4
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.96, 1.0, 1.0, 0.75)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	ring.position = Vector3(pos.x, ocean.get_wave_height_at(pos.x, pos.z) + 0.08, pos.z)
	ring.scale = Vector3.ONE * 0.35
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_rings.append({"node": ring, "t": 0.0, "life": 0.55, "mat": mat, "start_scale": 0.35, "end_scale": 3.2})


func _spawn_ring(_pos: Vector3, _strength: float) -> void:
	pass


func _update_rings(delta: float) -> void:
	for r in _rings:
		r["t"] = float(r["t"]) + delta
		var t: float = r["t"]
		var life: float = r["life"]
		var node: MeshInstance3D = r["node"]
		if not is_instance_valid(node):
			continue
		var k := clampf(t / life, 0.0, 1.0)
		var sc: float = lerpf(float(r["start_scale"]), float(r["end_scale"]), 1.0 - pow(1.0 - k, 2.0))
		node.scale = Vector3(sc, sc, sc)
		var mat: StandardMaterial3D = r["mat"]
		mat.albedo_color.a = (1.0 - k) * 0.75
		if t >= life:
			node.queue_free()
			r["dead"] = true
	_rings = _rings.filter(func(r): return not r.get("dead", false))


func _update_splashes(delta: float) -> void:
	for s in _splashes:
		s["age"] = float(s["age"]) + delta
		if float(s["age"]) > float(s["life"]):
			var node: CPUParticles3D = s["node"]
			if is_instance_valid(node):
				node.queue_free()
			s["dead"] = true
	_splashes = _splashes.filter(func(s): return not s.get("dead", false))


func _spawn_splash_at(cam_screen: Vector2) -> bool:
	var hit := cam.screen_to_water(cam_screen)
	if not hit["valid"]:
		return false
	_drop_rock(hit["point"], hit["pos"])
	return true


# ───────────────────────── 参数 API（HUD / 测试） ─────────────────────────
func set_hour(h: float) -> void:
	time_hour = clampf(h, 5.0, 21.5)
	scene.set_time(time_hour)
	hud.refresh_from_world()


func set_time_preset(name: String) -> void:
	match name:
		"noon":
			set_hour(11.5)
		"dusk":
			set_hour(17.9)
		"night":
			set_hour(20.4)


func set_wave_height(v: float) -> void:
	ocean.set_wave_height(v)


func set_wave_speed(v: float) -> void:
	ocean.set_wave_speed(v)


func set_wave_dir(v: float) -> void:
	ocean.set_wave_direction(v)


func set_foam(v: float) -> void:
	ocean.set_foam_amount(v)


func set_sun_glint(v: float) -> void:
	ocean.set_sun_glint(v)


func set_ripple_strength(v: float) -> void:
	ocean.set_ripple_strength(v)


func set_ripple_decay(v: float) -> void:
	ocean.set_ripple_decay(v)


func set_ripples_enabled(v: bool) -> void:
	ripples_enabled = v


func set_shoreline_visible(v: bool) -> void:
	_shore_line.visible = v


func set_clouds_visible(v: bool) -> void:
	scene.set_clouds_visible(v)


func set_rain(v: bool) -> void:
	rain_on = v
	scene.set_rain(v)
	ocean.set_rain(0.75 if v else 0.0)
	if v:
		hud.set_caption("")
	else:
		_lightning_timer = 8.0


func set_auto_orbit(v: bool) -> void:
	cam.auto_orbit = v


func set_water_style(idx: int) -> void:
	water_style = idx
	ocean.set_water_style(idx)
	scene.set_time(time_hour)


func set_debug_view(i: int) -> void:
	debug_view = i
	ocean.set_debug_view(i)
	hud.set_debug_view_caption(i)


func set_camera_pitch(v: float) -> void:
	cam.set_orbit(cam.yaw_deg, v, cam.distance)
	hud.refresh_from_world()


func set_camera_distance(v: float) -> void:
	cam.set_orbit(cam.yaw_deg, cam.pitch_deg, v)
	hud.refresh_from_world()


func set_camera_orbit(yaw: float, pitch: float, dist: float) -> void:
	cam.set_orbit(yaw, pitch, dist)
	cam.auto_orbit = false
	hud.refresh_from_world()


func set_camera_target(x: float, z: float, y := 1.2) -> void:
	cam.set_target_xz(x, z, y)


func set_camera_fov(v: float) -> void:
	cam.fov = clampf(v, 20.0, 70.0)


func reset_params() -> void:
	set_hour(11.5)
	ocean.set_wave_height(0.72)
	ocean.set_wave_speed(1.0)
	ocean.set_wave_direction(18.0)
	ocean.set_foam_amount(0.85)
	ocean.set_sun_glint(1.0)
	ocean.set_ripple_strength(1.0)
	ocean.set_ripple_decay(0.35)
	set_rain(false)
	set_auto_orbit(true)
	set_debug_view(0)
	set_water_style(0)
	cam.set_orbit(90.0, 58.0, 108.0)
	ocean.clear_ripples()
	hud.refresh_from_world()


func set_paused(v: bool) -> void:
	paused = v
	hud.set_caption("已暂停" if paused else "")


func set_ui_visible(v: bool) -> void:
	hud.set_ui_visible(v)


func set_ui_scale(s: float) -> void:
	hud.set_display_scale(s)
	hud.set_debug_view_caption(debug_view)
	_update_stats_label()


func set_panel_open(v: bool) -> void:
	hud.set_panel_open(v)


func set_virtual_cursor(screen_pos: Vector2) -> void:
	virtual_cursor = screen_pos


func clear_virtual_cursor() -> void:
	virtual_cursor = Vector2(-99999, -99999)


func debug_spawn_ripple_world(x: float, z: float, strength := 1.0, age := 0.0) -> Dictionary:
	return ocean.spawn_ripple(x, z, strength, age)


func debug_paint_arc(center: Vector2, radius: float, count: int, strength := 0.9) -> void:
	for i in count:
		var a := -0.9 + 2.2 * float(i) / maxf(1.0, float(count - 1))
		ocean.spawn_ripple(center.x + cos(a) * radius, center.y + sin(a) * radius, strength, 0.04 * float(count - 1 - i))


func debug_advance(seconds: float, steps := 30) -> void:
	var dt := seconds / float(steps)
	for i in steps:
		tick(dt)


func get_ui_state() -> Dictionary:
	return {
		"hour": time_hour,
		"sun_glint": ocean.sun_glint,
		"wave_height": ocean.wave_height,
		"wave_speed": ocean.wave_speed,
		"wave_dir": ocean.wave_dir_deg,
		"foam": ocean.foam_amount,
		"ripple_amp": ocean.ripple_amp,
		"ripple_decay": clampf(inverse_lerp(5.0, 1.6, ocean.ripple_life), 0.0, 1.0),
		"pitch": cam.pitch_deg,
		"distance": cam.distance,
		"rain": rain_on,
		"auto_orbit": cam.auto_orbit,
		"style": water_style,
		"debug": debug_view,
	}


func get_ocean() -> StylizedOcean:
	return ocean


func get_field() -> IslandField:
	return field


func get_camera_rig() -> OrbitRig:
	return cam


func get_hud() -> OceanHud:
	return hud


func get_scene_builder() -> OceanScene:
	return scene


func get_stats() -> Dictionary:
	var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	return {
		"fps": Engine.get_frames_per_second(),
		"draw_calls": dc,
		"objects": objects,
		"ripples": ocean.ripples.size(),
		"vertices": (StylizedOcean.RING_COUNT + 1) * StylizedOcean.SEGMENT_COUNT,
		"wave_height": ocean.wave_height,
		"hour": time_hour,
		"debug": debug_view,
		"rain": rain_on,
		"paused": paused,
	}


func _update_stats_label() -> void:
	if hud == null:
		return
	var s := get_stats()
	hud.set_stats("FPS %d  ·  DC %d\n涟漪 %d/12 · 浪高 %.2f m · %.1f h" % [
		s["fps"], s["draw_calls"], s["ripples"], s["wave_height"], s["hour"]])
