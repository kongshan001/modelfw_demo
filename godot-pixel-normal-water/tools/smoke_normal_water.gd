extends SceneTree

# 无头验收：
#   单 Camera2D / 无 SubViewport / 11 个物件都有 albedo+normal+roughness /
#   法线不是纯平面、粗糙度有变化、自发光只标记灯窗 /
#   单个倒影 Mesh（1 surface、6 quads、共享 atlas+mask）/
#   round() 量化步长可被整除、随时间和参数变化 /
#   光方向/强度/光色、暖灯/倒影/法线开关、暂停/时间冻结/重置 / HUD 基本接线。
# 用法：godot --headless --path godot-pixel-normal-water -s tools/smoke_normal_water.gd
# 末行：NORMAL_WATER_SMOKE_OK checks=N

var _fails: Array[String] = []
var _checks := 0


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fails.append(message)
		printerr("FAIL: " + message)


func _approx(a: float, b: float, eps := 0.002) -> bool:
	return absf(a - b) <= eps


func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.20).timeout

	# ── 单相机 / 零额外 Viewport ──────────────────────────────────────
	var cameras: Array = scene.find_children("*", "Camera2D", true, false)
	_check(cameras.size() == 1, "expected exactly 1 Camera2D, got %d" % cameras.size())
	_check(scene.find_children("*", "SubViewport", true, false).is_empty(),
			"SubViewport found in demo scene")
	_check(scene.find_children("*", "Viewport", true, false).is_empty(),
			"nested Viewport found in demo scene")
	if cameras.size() == 1:
		_check(scene.get_camera() == cameras[0], "scene camera getter mismatch")
	_check(scene.get_viewport().get_camera_2d() == scene.get_camera(),
			"root viewport current camera is not the scene Camera2D")

	# ── 程序化美术 / 法线 / 粗糙度 ────────────────────────────────────
	var art: Dictionary = scene.get_art()
	_check(art.has("mask") and art.has("water") and art.has("sky"), "background art missing")
	var mask: Image = scene.get_mask_image()
	_check(mask.get_width() == 320 and mask.get_height() == 180,
			"water mask must be 320x180")
	var above := 0
	var below := 0
	for x in range(0, 320, 5):
		if mask.get_pixel(x, 110).a > 0.5:
			above += 1
		if mask.get_pixel(x, 150).a > 0.5:
			below += 1
	_check(above == 0, "water mask leaks above waterline")
	_check(below == 64, "water mask missing below waterline (%d/64)" % below)

	var lit: Array = scene.get_lit_objects()
	_check(lit.size() == 11, "expected 11 lit objects, got %d" % lit.size())
	_check(scene.get_lit_materials().size() == lit.size(), "material count mismatch")
	var normal_min = 999
	var rough_min = 999
	var emissive_objects: Array[String] = []
	var lit_shader_code := ""
	for obj in lit:
		var id := String(obj["id"])
		var albedo: Image = obj["albedo"]
		var normal: Image = obj["normal"]
		var rough: Image = obj["roughness"]
		_check(albedo != null and normal != null and rough != null, id + " missing a map")
		if albedo == null or normal == null or rough == null:
			continue
		_check(normal.get_size() == albedo.get_size(), id + " normal size mismatch")
		_check(rough.get_size() == albedo.get_size(), id + " roughness size mismatch")
		var colors := {}
		var roughtones := {}
		var emit_pixels := 0
		for y in range(0, albedo.get_height(), 2):
			for x in range(0, albedo.get_width(), 2):
				if albedo.get_pixel(x, y).a < 0.5:
					continue
				var n := normal.get_pixel(x, y)
				var r := rough.get_pixel(x, y)
				colors[n.to_rgba32()] = true
				roughtones[r.to_rgba32()] = true
				if n.a > 0.5:
					emit_pixels += 1
		normal_min = mini(normal_min, colors.size())
		rough_min = mini(rough_min, roughtones.size())
		_check(colors.size() >= 8, "%s normal map looks flat (%d colors)" % [id, colors.size()])
		_check(roughtones.size() >= 2, "%s roughness map is constant" % id)
		if id in ["tavern", "townhouse", "lamp_a", "lamp_b"]:
			_check(emit_pixels > 5, "%s emission mask is empty" % id)
			emissive_objects.append(id)
		else:
			_check(emit_pixels == 0, "%s unexpected emission pixels" % id)
		var mat: ShaderMaterial = obj["material"]
		_check(mat != null and mat.shader != null, id + " material/shader missing")
		if mat != null and mat.shader != null and lit_shader_code == "":
			lit_shader_code = mat.shader.code
	_check(normal_min >= 8, "smallest normal variation below 8 colors")
	_check(rough_min >= 2, "smallest roughness variation below 2 tones")
	_check(emissive_objects.size() == 4, "unexpected emissive object count")
	_check(lit_shader_code.contains("ortho_detail_normal"),
			"lit shader does not use orthogonal normal decomposition")
	_check(lit_shader_code.contains("u_rough_tex"), "lit shader ignores roughness texture")
	_check(lit_shader_code.contains("u_lamp_a") and lit_shader_code.contains("u_lamp_b"),
			"lit shader missing two warm point lights")
	_check(lit_shader_code.contains("u_emission_strength"),
			"lit shader missing emission control")

	# ── 倒影：单 Mesh / 单 surface / 共享 atlas & mask ────────────────
	var refl: NormalWaterReflection = scene.get_reflection()
	_check(refl != null, "reflection field missing")
	var mesh_instance: MeshInstance2D = refl.get_mesh_instance()
	_check(mesh_instance != null, "reflection MeshInstance2D missing")
	_check(refl.get_surface_count() == 1, "reflection must be one surface, got %d"
			% refl.get_surface_count())
	_check(refl.get_quad_count() == 6, "expected 6 reflected quads, got %d"
			% refl.get_quad_count())
	var atlas: Image = refl.get_atlas_image()
	_check(atlas.get_width() == 512 and atlas.get_height() == 128,
			"reflection atlas must be 512x128")
	var opaque := 0
	for y in range(0, atlas.get_height(), 3):
		for x in range(0, atlas.get_width(), 3):
			if atlas.get_pixel(x, y).a > 0.5:
				opaque += 1
	_check(opaque > 300, "reflection atlas looks empty (%d sampled)" % opaque)
	_check(refl.shader_mat != null and refl.shader_mat.shader != null,
			"reflection shader missing")
	if refl.shader_mat != null and refl.shader_mat.shader != null:
		var code := refl.shader_mat.shader.code
		_check(code.contains("round("), "reflection shader lacks round() quantization")
		_check(code.contains("u_wave_step"), "reflection shader lacks wave step")
		_check(code.contains("texture(u_mask"), "reflection shader ignores water mask")
		_check(code.contains("discard"), "reflection shader lacks mask discard")
		_check(code.contains("u_lamp_uv_a"), "reflection shader lacks lamp-region masking")
		_check(refl.shader_mat.get_shader_parameter("u_mask") != null,
				"reflection mask sampler not bound")
		_check(refl.shader_mat.get_shader_parameter("u_atlas") != null,
				"reflection atlas sampler not bound")
		_check(refl.lamp_uv_a.z > 0.0 and refl.lamp_uv_b.z > 0.0,
				"lamp atlas rectangles missing")
	var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
	_check((arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array).size() == 36,
			"reflection mesh must contain 6*6 vertices")
	_check((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == 36,
			"reflection mesh UV count wrong")

	# 量化波：步长整除、随时间变化、幅度 0 时归零。
	refl.set_wave_params(1.0, 3.0, 2.0)
	var distinct := {}
	var offstep := 0
	for row in range(120, 180):
		var sv: int = refl.quantized_shift(row, 1.7)
		distinct[sv] = true
		if sv % 2 != 0:
			offstep += 1
	_check(offstep == 0, "quantized shift is not a multiple of step 2")
	_check(distinct.size() >= 3, "wave quantization too static (%d levels)" % distinct.size())
	var over_time := {}
	for i in 60:
		over_time[refl.quantized_shift(140, float(i) * 0.1)] = true
	_check(over_time.size() >= 2, "quantized wave never advances in time")
	var nonzero := 0
	for sv in over_time.keys():
		if int(sv) != 0:
			nonzero += 1
	_check(nonzero >= 1, "quantized wave is always zero")
	refl.set_wave_params(1.0, 0.0, 1.0)
	var all_zero := true
	for row in range(120, 180):
		if refl.quantized_shift(row, 2.0) != 0:
			all_zero = false
			break
	_check(all_zero, "zero amplitude still shifts the reflection")
	refl.set_wave_params(1.0, 2.0, 1.0)

	# ── 光照参数 / 开关 ──────────────────────────────────────────────
	var mat0: ShaderMaterial = lit[0]["material"]
	scene.set_light_angle(300.0)
	scene.set_light_energy(1.40)
	var dir_expected := Vector2(sin(deg_to_rad(300.0)), -cos(deg_to_rad(300.0)))
	var dir_got: Vector2 = mat0.get_shader_parameter("u_light_dir")
	_check(dir_got.is_equal_approx(dir_expected), "light direction uniform not applied")
	_check(_approx(float(mat0.get_shader_parameter("u_light_energy")), 1.40),
			"light energy uniform not applied")
	scene.set_light_preset(1)
	var preset: Dictionary = NormalWaterLayout.LIGHT_PRESETS[1]
	_check(scene.get_light_state()["name"] == String(preset["name"]),
			"light preset name not applied")
	_check(_approx(scene.get_params()["angle"], float(preset["angle"])),
			"light preset angle not applied")
	scene.set_light_preset(0)
	scene.set_light_angle(NormalWaterLayout.DEFAULT_LIGHT_ANGLE_DEG)
	scene.set_light_energy(NormalWaterLayout.DEFAULT_LIGHT_ENERGY)

	scene.set_lamps_enabled(false)
	_check(not bool(scene.get_params()["lamps"]), "lamps toggle failed")
	_check(not bool(mat0.get_shader_parameter("u_lamps_on")), "lamp shader uniform not off")
	for glow in scene.get_lamp_glows():
		_check(not glow.visible, "lamp glow still visible when lamps off")
	scene.set_lamps_enabled(true)
	_check(bool(mat0.get_shader_parameter("u_lamps_on")), "lamp shader uniform not back on")

	scene.set_reflection_enabled(false)
	_check(not bool(scene.get_params()["reflection"]), "reflection toggle failed")
	_check(not refl.is_reflection_enabled(), "reflection mesh still visible when off")
	scene.set_reflection_enabled(true)
	_check(refl.is_reflection_enabled(), "reflection mesh did not come back")

	scene.set_normals_enabled(false)
	_check(not bool(scene.get_params()["normals"]), "normal lighting toggle failed")
	_check(not bool(mat0.get_shader_parameter("u_normals_on")),
			"normal lighting uniform still on")
	scene.set_normals_enabled(true)
	_check(bool(mat0.get_shader_parameter("u_normals_on")), "normal lighting did not resume")

	scene.set_debug_enabled(true)
	_check(bool(scene.get_params()["debug"]), "debug toggle failed")
	_check(scene.get_debug_overlay().visible, "debug overlay not visible")
	scene.set_normal_view(true)
	_check(int(mat0.get_shader_parameter("u_debug_mode")) == 1,
			"normal debug view uniform not applied")
	scene.set_normal_view(false)
	scene.set_debug_enabled(false)
	_check(int(mat0.get_shader_parameter("u_debug_mode")) == 0,
			"normal debug view did not turn off")

	# ── 暂停 / 时间 / 重置 ───────────────────────────────────────────
	scene.set_paused(false)
	scene.set_time_scale(1.0)
	await create_timer(0.15).timeout
	var t1: float = scene.get_time()
	await create_timer(0.12).timeout
	var t2: float = scene.get_time()
	_check(t2 > t1, "time does not advance while running")
	scene.set_paused(true)
	await create_timer(0.15).timeout
	var t3: float = scene.get_time()
	await create_timer(0.15).timeout
	_check(_approx(scene.get_time(), t3, 0.0001), "scene time advances while paused")
	scene.set_paused(false)
	scene.set_time_scale(0.0)
	await create_timer(0.12).timeout
	var t4: float = scene.get_time()
	await create_timer(0.12).timeout
	_check(_approx(scene.get_time(), t4, 0.0001), "time scale 0 does not freeze time")
	scene.set_time_scale(1.0)
	scene.set_time_value(0.0)
	_check(_approx(scene.get_time(), 0.0), "set_time_value failed")

	scene.set_lamps_enabled(false)
	scene.set_reflection_enabled(false)
	scene.set_normals_enabled(false)
	scene.set_debug_enabled(true)
	scene.set_normal_view(true)
	scene.set_light_angle(180.0)
	scene.set_light_energy(2.2)
	scene.set_wave_speed(2.0)
	scene.set_wave_amplitude(4.0)
	scene.set_wave_step(3.0)
	scene.set_time_scale(0.4)
	scene.reset_scene()
	var p: Dictionary = scene.get_params()
	_check(bool(p["lamps"]) and bool(p["reflection"]) and bool(p["normals"]),
			"reset did not restore toggles")
	_check(not bool(p["debug"]) and not bool(p["normal_view"]), "reset left debug modes on")
	_check(not bool(p["paused"]), "reset left scene paused")
	_check(_approx(float(p["angle"]), NormalWaterLayout.DEFAULT_LIGHT_ANGLE_DEG),
			"reset angle wrong")
	_check(_approx(float(p["energy"]), NormalWaterLayout.DEFAULT_LIGHT_ENERGY),
			"reset energy wrong")
	_check(_approx(float(p["wave_speed"]), NormalWaterLayout.DEFAULT_WAVE_SPEED),
			"reset wave speed wrong")
	_check(_approx(float(p["wave_amp"]), NormalWaterLayout.DEFAULT_WAVE_AMPLITUDE),
			"reset wave amplitude wrong")
	_check(_approx(float(p["wave_step"]), NormalWaterLayout.DEFAULT_WAVE_STEP),
			"reset wave step wrong")
	_check(_approx(float(p["time_scale"]), 1.0), "reset time scale wrong")
	_check(_approx(scene.get_time(), 0.0), "reset did not rewind time")
	_check(not scene.get_debug_overlay().visible, "reset left debug overlay visible")
	_check(refl.is_reflection_enabled(), "reset left reflection hidden")

	# ── HUD / 展示接口 ───────────────────────────────────────────────
	scene.set_paused(true)
	scene.get_node("HUD").sync_from_main()
	await process_frame
	var labels: Array = scene.find_children("*", "Label", true, false)
	var text_all := ""
	for l in labels:
		text_all += String(l.text) + "\n"
	_check(text_all.contains("静水回廊"), "HUD missing title")
	_check(text_all.contains("FPS") and text_all.contains("DRAW"), "HUD missing FPS/draw")
	_check(text_all.contains("1 CAMERA"), "HUD missing single-camera readout")
	_check(text_all.contains("倒影") and text_all.contains("法线"), "HUD missing reflection/normal info")
	var sliders: Array = scene.find_children("*", "HSlider", true, false)
	_check(sliders.size() >= 6, "HUD has too few sliders (%d)" % sliders.size())
	_check(scene.get_fps() >= 0, "FPS accessor returned negative")
	_check(scene.get_draw_calls() >= 0, "draw call accessor returned negative")
	_check(scene.get_wave_shift_at_row(140) is int, "wave shift accessor wrong type")

	scene.set_paused(true)
	if _fails.is_empty():
		print("NORMAL_WATER_SMOKE_OK checks=%d" % _checks)
		quit(0)
	else:
		print("NORMAL_WATER_SMOKE_FAIL checks=%d fails=%d" % [_checks, _fails.size()])
		for f in _fails:
			print(" - ", f)
		quit(1)
