extends SceneTree

# 无头验收：网格规模、三道波参数、shader uniform 链路、五点浮力、
# 昼夜调色、倒影相机/视口、参数面板开关。
# 用法：godot --headless --path godot-pixel-ocean -s tools/smoke_pixel_ocean.gd

var _fails: Array[String] = []


func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.2).timeout

	var world_vp: SubViewport = scene.get_world_viewport()
	var ocean = scene.get_ocean()
	var raft = scene.get_raft()
	var material: ShaderMaterial = ocean.water_material
	var sky_mat: ShaderMaterial = scene.get_sky_material()
	var seabed_mat: ShaderMaterial = scene.get_seabed_material()
	var preview: TextureRect = scene.get_node("WorldDisplay")

	# ── 网格 ──────────────────────────────────────────────────────────
	_check(world_vp.size == Vector2i(640, 360), "world viewport must be 640x360, got %s" % world_vp.size)
	_check(world_vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "world viewport not updating always")
	_check(preview.texture == world_vp.get_texture(), "TextureRect not showing the pixel viewport")
	_check(preview.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "display is not nearest-neighbour")
	_check(ocean.mesh is PlaneMesh, "ocean mesh missing")
	var plane: PlaneMesh = ocean.mesh
	_check(plane.subdivide_width >= 200, "ocean grid too coarse: %d" % plane.subdivide_width)
	_check(ocean.get_mesh_vertex_count() >= 40000,
			"ocean vertex count too small: %d" % ocean.get_mesh_vertex_count())

	# ── 三道波 ────────────────────────────────────────────────────────
	var waves: Array = ocean.get_wave_config()
	_check(waves.size() == 3, "expected 3 waves, got %d" % waves.size())
	if waves.size() == 3:
		_check(waves[0]["wavelength"] != waves[1]["wavelength"], "waves must differ in wavelength")
		_check(waves[0]["angle_offset"] != waves[1]["angle_offset"], "waves must differ in direction")
		_check(waves[2]["wavelength"] < waves[0]["wavelength"], "third wave should be the shortest")

	# ── shader uniform 链路 ───────────────────────────────────────────
	_check(material != null, "water ShaderMaterial missing")
	_check(material.shader != null, "water shader missing")
	_check(material.shader.code.contains("add_wave"), "water shader has no wave code")
	_check(material.shader.code.contains("u_reflection_tex"), "water shader has no reflection sampler")
	_check(material.get_shader_parameter("u_reflection_tex") != null, "reflection texture not bound")
	_check(float(material.get_shader_parameter("u_reflection")) > 0.0, "reflection strength uniform not set")

	scene.set_wave_height(1.5)
	_check(absf(float(material.get_shader_parameter("u_wave_height")) - 1.5) < 0.001, "wave height uniform not updated")
	scene.set_wave_direction(45.0)
	_check(absf(float(material.get_shader_parameter("u_wave_angle")) - deg_to_rad(45.0)) < 0.001,
			"wave direction uniform not updated")
	scene.set_foam_amount(1.3)
	_check(absf(float(material.get_shader_parameter("u_foam")) - 1.3) < 0.001, "foam uniform not updated")
	scene.set_sparkle_amount(0.4)
	_check(absf(float(material.get_shader_parameter("u_sparkle")) - 0.4) < 0.001, "sparkle uniform not updated")
	scene.set_transparency(0.5)
	_check(absf(float(material.get_shader_parameter("u_opacity")) - 0.74) < 0.01, "opacity mapping wrong")
	scene.set_reflection_strength(0.0)
	_check(absf(float(material.get_shader_parameter("u_reflection_on"))) < 0.001, "reflection off flag wrong")
	scene.set_reflection_strength(0.9)

	# ── CPU 波形与五点浮力 ────────────────────────────────────────────
	ocean.wave_height = 1.2
	scene.set_wave_clock(2.3)
	var samples: Array[float] = ocean.sample_five(0.0, 0.0)
	_check(samples.size() == 5, "sample_five must return 5 heights")
	var spread := 0.0
	for h in samples:
		spread = maxf(spread, absf(h - samples[0]))
	_check(spread > 0.005, "five sample heights are all identical (%.4f)" % spread)
	var repeat: float = ocean.height_at(0.0, 0.0)
	_check(absf(repeat - samples[0]) < 0.0001, "height_at is not deterministic")

	for i in 40:
		raft.update_buoyancy(0.5)
	_check(raft.position.y > -1.0 and raft.position.y < 2.5, "raft y out of range: %.3f" % raft.position.y)
	_check(absf(raft.position.y) > 0.01 or absf(raft.rotation.x) > 0.001 or absf(raft.rotation.z) > 0.001,
			"raft did not react to waves")
	_check(raft.get_mark_positions().size() == 5, "five buoyancy markers missing")
	scene.set_debug_points(true)
	_check(scene.is_debug_points(), "debug point flag not set")
	var marks: Node3D = raft.get_node("BuoyancyPoints")
	_check(marks.visible, "buoyancy markers not visible when enabled")
	scene.set_debug_points(false)

	# ── 昼夜 ──────────────────────────────────────────────────────────
	scene.set_time_of_day(12.5)
	var day_sun: Color = scene.get_sun().light_color
	var day_water: Color = material.get_shader_parameter("u_deep_color")
	var day_stars := float(sky_mat.get_shader_parameter("u_stars"))
	scene.set_time_of_day(18.4)
	var sunset_sun: Color = scene.get_sun().light_color
	var sunset_water: Color = material.get_shader_parameter("u_deep_color")
	scene.set_time_of_day(22.5)
	var night_stars := float(sky_mat.get_shader_parameter("u_stars"))
	var night_sun: Color = scene.get_sun().light_color
	_check(day_stars < 0.01, "day sky has stars")
	_check(night_stars > 0.9, "night sky has no stars")
	_check(day_sun != sunset_sun and sunset_sun != night_sun, "sun colour does not change with time")
	_check(day_water != sunset_water, "water palette does not change with time")
	_check(scene.get_palette().has("sun_elev"), "palette missing sun elevation")
	_check(seabed_mat.get_shader_parameter("u_sand") != null, "seabed palette not set")

	# ── 预设 / 倒影视口 / 面板 ────────────────────────────────────────
	scene.set_preset(1)
	var params: Dictionary = scene.get_params()
	_check(absf(float(params["time"]) - 18.4) < 0.01, "sunset preset time wrong")
	_check(float(params["reflection"]) > 0.5, "sunset preset reflection too low")

	var refl_vp: SubViewport = scene.get_reflection_viewport()
	var refl_cam: Camera3D = scene.get_reflection_camera()
	_check(refl_vp.size == Vector2i(320, 180), "reflection viewport size wrong")
	_check(refl_vp.world_3d == world_vp.world_3d, "reflection viewport does not share world")
	_check(refl_cam.cull_mask == 1, "reflection camera must only see layer 1")
	await process_frame
	await process_frame
	var main_cam: Camera3D = scene.get_camera()
	_check(refl_cam.global_position.y < 0.0, "reflection camera is not under the water")
	_check(absf(refl_cam.global_position.x - main_cam.global_position.x) < 0.01,
			"reflection camera x not mirrored around water plane")
	_check(ocean.layers == (1 << 1), "ocean layer wrong (should be excluded from reflection)")

	# ── 贴水 / 镜像平面 ───────────────────────────────────────────────
	# 木筏根节点低于平均水位（吃水），浮木底部必须没入当地水面
	var local: Array[float] = ocean.sample_five(
			raft.global_position.x, raft.global_position.z)
	var local_avg := (local[0] + local[1] + local[2] + local[3] + local[4]) / 5.0
	_check(raft.global_position.y < local_avg, "raft must sit below average water level (draft)")
	# 浮木中心 +0.06、半径 0.17 → 底部在根节点下方 0.11
	_check(raft.global_position.y - 0.11 < local[0], "hull logs must be below the local water surface")
	# 倒影镜像平面跟随木筏水线，反射相机严格镜像于该平面
	_check(absf(scene.get_mirror_plane_y() - raft.get_waterline_y()) < 0.02,
			"mirror plane does not follow the raft waterline")
	_check(absf(refl_cam.global_position.y - (2.0 * scene.get_mirror_plane_y()
			- main_cam.global_position.y)) < 0.02,
			"reflection camera not mirrored around the waterline plane")

	scene.set_ui_visible(false)
	var hud_root: Control = scene.get_node("HUD").get_node("HUDRoot")
	_check(not hud_root.visible, "HUD did not hide")
	scene.set_ui_visible(true)

	# 暂停
	scene.set_paused(true)
	var t0: float = ocean.wave_time
	await create_timer(0.1).timeout
	_check(absf(ocean.wave_time - t0) < 0.0001, "paused ocean still advancing")
	scene.set_paused(false)

	if _fails.is_empty():
		print("PIXEL_OCEAN_SMOKE_OK")
		quit(0)
	else:
		for f in _fails:
			printerr("PIXEL OCEAN SMOKE FAIL: ", f)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails.append(message)
