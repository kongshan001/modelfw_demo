extends SceneTree

# 无头验收（无 GPU 依赖）：
#   时间映射 / 日月接力与交班淡入 / 3 个全局向量 /
#   顶点坍缩与并集零叠黑 / R8 高度图与 2.5D 遮挡 / 60% 软膝连续性 /
#   夜景路灯+月影参数 / 调试开关 / 重置 / 时间滑杆。
# 末行：SUN_MOON_SHADOW_SMOKE_OK checks=N
#
# 运行：godot --headless --path godot-sun-moon-shadows -s tools/smoke_sun_moon_shadows.gd

var _fails: Array[String] = []
var _checks := 0
var main
var world
var hud


func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.25).timeout
	main = scene
	world = main.get_world()
	hud = main.get_hud()
	main.set_playing(false)
	main.set_hour(8.0)
	await process_frame
	await _run_all()
	if _fails.is_empty():
		print("SMOKE checks=%d fails=0" % _checks)
		print("SUN_MOON_SHADOW_SMOKE_OK")
		main.queue_free()
		await process_frame
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL: ", f)
		print("SUN_MOON_SHADOW_SMOKE_FAIL fails=%d checks=%d" % [_fails.size(), _checks])
		main.queue_free()
		await process_frame
		quit(1)


func _run_all() -> void:
	await _test_project_config()
	await _test_light_model()
	await _test_time_controls()
	await _test_global_vectors()
	await _test_shadow_geometry()
	await _test_heightmap()
	await _test_soft_knee()
	await _test_night_lamps()
	await _test_debug_and_reset()
	await _test_no_light2d()


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


func _near(a: float, b: float, eps: float, msg: String) -> void:
	_check(absf(a - b) <= eps, "%s (got %.4f expected %.4f)" % [msg, a, b])


func _poly_area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


func _test_project_config() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene")
			== "res://scenes/main.tscn", "main scene path")
	_check(String(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
			== "gl_compatibility", "renderer must be GL Compatibility")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1280,
			"logical width should be 1280")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 720,
			"logical height should be 720")
	_check(int(ProjectSettings.get_setting(
			"rendering/textures/canvas_textures/default_texture_filter")) == 0,
			"default texture filter must be nearest")
	_check(main.get_world_viewport().size == Vector2i(640, 360),
			"pixel world viewport must be 640x360")
	_check(main.display.texture == main.get_world_viewport().get_texture(),
			"world display must show the SubViewport texture")
	_check(ProjectSettings.has_setting("shader_globals/u_light_dir"),
			"u_light_dir must be a project shader global")
	_check(ProjectSettings.has_setting("shader_globals/u_light_color"),
			"u_light_color must be a project shader global")
	_check(ProjectSettings.has_setting("shader_globals/u_ambient_sub"),
			"u_ambient_sub must be a project shader global")
	var d: Dictionary = ProjectSettings.get_setting("shader_globals/u_light_dir")
	_check(String(d.get("type", "")) == "vec4", "u_light_dir must be vec4")
	# 工程里应该只有 3 个 light 全局量，不额外引入逐物灯光。
	var count := 0
	for p in ProjectSettings.get_property_list():
		if String(p["name"]).begins_with("shader_globals/"):
			count += 1
	_check(count == 3, "expected exactly 3 shader globals, got %d" % count)


func _test_light_model() -> void:
	# 时间格式。
	_check(LightModel.format_hour(8.0) == "08:00", "format 08:00")
	_check(LightModel.format_hour(12.0) == "12:00", "format 12:00")
	_check(LightModel.format_hour(18.3333) == "18:20", "format 18:20")
	_check(LightModel.format_hour(0.5) == "00:30", "format 00:30")
	_check(LightModel.format_hour(24.0) == "00:00", "format 24:00 wraps")
	# 太阳模型（视频帧：12:00 68°、17:18 26°、18:20 10°）。
	_near(LightModel.sun_elevation(12.0), 68.0, 0.01, "sun noon elevation")
	_near(LightModel.sun_elevation(8.0), 42.3973, 0.05, "sun 08:00 elevation")
	_near(LightModel.sun_elevation(17.3), 25.4, 1.0, "sun 17:18 elevation ~ video 26")
	_near(LightModel.sun_elevation(18.3333), 10.1852, 0.05, "sun 18:20 elevation")
	_near(LightModel.sun_azimuth(12.0), 90.0, 0.01, "sun noon azimuth")
	_near(LightModel.sun_azimuth(18.3333), 171.36, 0.2, "sun dusk azimuth")
	_check(LightModel.sun_is_up(12.0), "sun up at noon")
	_check(not LightModel.sun_is_up(21.0), "sun down at night")
	_near(LightModel.sun_strength(12.0), 1.0, 0.001, "sun strength noon")
	_near(LightModel.sun_strength(19.0), 0.0, 0.001, "sun strength at sunset")
	# 月亮模型（视频帧：22:00 高度约 41-47°，00:30 52°）。
	_near(LightModel.moon_elevation(18.5), 0.0, 0.01, "moonrise elevation")
	_near(LightModel.moon_elevation(21.0), 31.6556, 0.05, "moon 21:00 elevation")
	_near(LightModel.moon_elevation(0.5), 52.0, 0.01, "moon midnight elevation")
	_near(LightModel.moon_elevation(22.0), 41.3, 1.0, "moon 22:00 elevation ~ video")
	_near(LightModel.moon_elevation(6.5), 0.0, 0.01, "moonset elevation")
	_check(LightModel.moon_is_up(21.0), "moon up at 21:00")
	_check(LightModel.moon_is_up(0.5), "moon up at 00:30")
	_check(not LightModel.moon_is_up(12.0), "moon not main at noon")
	# 主光接力。
	_check(LightModel.main_light(12.0) == "sun", "noon main is sun")
	_check(LightModel.main_light(18.3333) == "sun", "dusk main is sun")
	_check(LightModel.main_light(19.0) == "moon", "sunset handoff to moon")
	_check(LightModel.main_light(21.0) == "moon", "night main is moon")
	_check(LightModel.main_light(0.5) == "moon", "midnight main is moon")
	_check(LightModel.main_light(5.5) == "sun", "dawn handoff to sun")
	_near(LightModel.handoff_weight(19.0, "moon"), 0.0, 0.001, "moon handoff starts at 0")
	_near(LightModel.handoff_weight(20.0, "moon"), 1.0, 0.001, "moon handoff reaches 1")
	_near(LightModel.handoff_weight(5.0, "sun"), 0.0, 0.001, "sun handoff starts at 0")
	_near(LightModel.handoff_weight(6.0, "sun"), 1.0, 0.001, "sun handoff reaches 1")
	var st19 := LightModel.state(19.0)
	_check(String(st19["main_light"]) == "moon", "state 19:00 main moon")
	_near(float(st19["intensity"]), 0.0, 0.001, "state 19:00 intensity fades to 0")
	_near(float(st19["shadow_alpha"]), 0.0, 0.001, "state 19:00 shadow alpha 0")
	var st20 := LightModel.state(20.0)
	_check(float(st20["intensity"]) > 0.2, "state 20:00 moon intensity visible")
	_check(float(st20["shadow_alpha"]) > 0.2, "state 20:00 moon shadow visible")
	var st5 := LightModel.state(5.0)
	_near(float(st5["intensity"]), 0.0, 0.001, "state 05:00 intensity fades to 0")
	_check(String(LightModel.main_light(5.1)) == "sun", "sun takes over just after 05:00")
	var st55 := LightModel.state(5.5)
	_check(String(st55["main_light"]) == "sun", "state 05:30 main sun")
	_check(float(st55["intensity"]) > 0.1, "state 05:30 sun fading in")
	var st6 := LightModel.state(6.0)
	_check(float(st6["intensity"]) > 0.4, "state 06:00 sun intensity visible")
	var st475 := LightModel.state(4.75)
	_check(float(st475["intensity"]) < LightModel.state(4.0)["intensity"],
			"moon light should fade out before sunrise")
	# 同一南天东→西：太阳与月亮的 x 均单调增大。
	var prev := -999.0
	for h in [5.0, 8.0, 12.0, 16.0, 19.0]:
		var p := LightModel.sun_sky_position(h)
		_check(p.x > prev, "sun arc x must increase east->west at %.1f" % h)
		_check(p.x >= 0.0 and p.x <= 640.0 and p.y >= 20.0 and p.y <= 92.0,
				"sun sky position in band at %.1f" % h)
		prev = p.x
	prev = -999.0
	for h in [18.5, 21.0, 0.5, 4.0, 6.5]:
		var p := LightModel.moon_sky_position(h)
		_check(p.x > prev, "moon arc x must increase east->west at %.1f" % h)
		_check(p.x >= 0.0 and p.x <= 640.0 and p.y >= 20.0 and p.y <= 92.0,
				"moon sky position in band at %.1f" % h)
		prev = p.x
	# 影向：晨右、午下、昏左。
	var d8 := LightModel.shadow_direction(8.0)
	var d12 := LightModel.shadow_direction(12.0)
	var d16 := LightModel.shadow_direction(16.0)
	_check(d8.x > 0.2 and d8.y > 0.0, "morning shadow points right/down")
	_check(absf(d12.x) < 0.001 and d12.y > 0.9, "noon shadow points down")
	_check(d16.x < -0.2 and d16.y > 0.0, "evening shadow points left/down")
	_check(absf(d8.length() - 1.0) < 0.001, "shadow dir unit length")
	_check((LightModel.light_direction(8.0) + d8).length() < 0.001,
			"light dir is -shadow dir")
	# 相位 / 色温。
	_check(LightModel.phase_label(12.0) == "正午", "phase noon")
	_check(LightModel.phase_label(18.3333) == "黄昏", "phase dusk")
	_check(LightModel.phase_label(21.0) == "月夜", "phase night")
	var sun_style := LightModel.sun_style(8.0)
	var sun_col: Color = sun_style["color"]
	_check(sun_col.r > sun_col.b, "day light warm (R>B)")
	_check(LightModel.MOON_COLOR.b > LightModel.MOON_COLOR.r, "moon light cool (B>R)")
	_check(LightModel.MOON_SHADOW.b > LightModel.MOON_SHADOW.r, "moon shadow cool (B>R)")


func _test_time_controls() -> void:
	main.set_hour(24.0)
	_near(main.get_hour(), 0.0, 0.0001, "set_hour(24) wraps to 0")
	main.set_hour(-1.0)
	_near(main.get_hour(), 23.0, 0.0001, "set_hour(-1) wraps to 23")
	main.set_hour(8.0)
	main.set_playing(false)
	main.simulate_time(2.0)
	_near(main.get_hour(), 8.0, 0.0001, "paused time must not advance")
	main.set_playing(true)
	main.set_speed(1.0)
	main.set_hour(8.0)
	main.simulate_time(1.0)
	_near(main.get_hour(), 8.02, 0.005, "1x advances 0.02h/s")
	main.set_speed(16.0)
	main.set_hour(8.0)
	main.simulate_time(1.0)
	_near(main.get_hour(), 8.32, 0.03, "16x advances 0.32h/s")
	main.set_speed(100.0)
	_near(main.get_speed(), 64.0, 0.001, "speed clamps to 64")
	main.set_speed(0.0)
	_near(main.get_speed(), 1.0, 0.001, "speed clamps to 1")
	main.set_speed(16.0)
	main.set_playing(false)
	var slider: HSlider = hud.get_time_slider()
	_check(slider != null, "time slider missing")
	_check(absf(slider.min_value) < 0.001 and absf(slider.max_value - 24.0) < 0.001,
			"time slider range must be 0..24")
	slider.value = 12.0
	await create_timer(0.12).timeout
	_near(main.get_hour(), 12.0, 0.01, "slider sets 12:00")
	hud.sync_from_main()
	_check(hud.get_time_label().text == "12:00", "time label updates to 12:00")


func _test_global_vectors() -> void:
	main.set_hour(8.0)
	await process_frame
	var d8: Vector4 = main.get_global_uniform("u_light_dir")
	var c8: Color = main.get_global_uniform("u_light_color")
	var a8: Color = main.get_global_uniform("u_ambient_sub")
	_check(d8 is Vector4, "u_light_dir must be mirrored as Vector4")
	_check(absf(Vector2(d8.x, d8.y).length() - 1.0) < 0.002,
			"u_light_dir xy must be unit")
	_check(d8.z > 0.1 and d8.z < 0.6, "u_light_dir.z elevation01 at 08:00")
	_check(d8.w < 0.05, "u_light_dir.w night=0 at 08:00")
	_check(c8.r > c8.b, "day light color warm")
	_check(a8.a > 0.35 and a8.a <= 0.5, "day ambient removal alpha")
	_check(a8.b >= a8.r, "day shadow tint cool")
	main.set_hour(21.0)
	await process_frame
	var d21: Vector4 = main.get_global_uniform("u_light_dir")
	var c21: Color = main.get_global_uniform("u_light_color")
	var a21: Color = main.get_global_uniform("u_ambient_sub")
	_check(d21.w > 0.99, "u_light_dir.w night=1 at 21:00")
	_check(c21.b > c21.r, "moon light color cool")
	_check(a21.b > a21.r, "moon ambient removal cool")
	_check(a21.a <= 0.5, "night removes about half ambient (<=0.5)")
	_check((d8 - d21).length() > 0.5, "global direction changes day/night")
	_check(c8.r != c21.r, "global light color changes day/night")
	# 材质只读全局量，没有逐物体 light 参数。
	var lit: ShaderMaterial = world.lit_material
	var ground: ShaderMaterial = world.ground_material
	var shadow: ShaderMaterial = world.shadow_material
	var sky: ShaderMaterial = world.sky_material
	for mat in [lit, ground, shadow, sky]:
		_check(mat != null and mat.shader != null, "shared material/shader missing")
		_check(mat.get_shader_parameter("u_light_dir") == null,
				"u_light_dir must not be per-object")
		_check(mat.get_shader_parameter("u_light_color") == null,
				"u_light_color must not be per-object")
		_check(mat.get_shader_parameter("u_ambient_sub") == null,
				"u_ambient_sub must not be per-object")
	_check(lit.shader.code.contains("global uniform vec4 u_light_dir"),
			"lit_sprite declares global u_light_dir")
	_check(lit.shader.code.contains("global uniform vec4 u_light_color"),
			"lit_sprite declares global u_light_color")
	_check(lit.shader.code.contains("global uniform vec4 u_ambient_sub"),
			"lit_sprite declares global u_ambient_sub")
	_check(ground.shader.code.contains("global uniform vec4 u_light_dir"),
			"ground declares global u_light_dir")
	_check(sky.shader.code.contains("global uniform vec4 u_light_dir"),
			"sky declares global u_light_dir")
	_check(shadow.shader.code.contains("global uniform vec4 u_ambient_sub"),
			"shadow declares global u_ambient_sub")
	var house: Sprite2D = world.get_node("House")
	var oak: Sprite2D = world.get_node("Oak")
	_check(house.material == lit and oak.material == lit,
			"house and oak must share the single lit material")
	var ground_sprite: Sprite2D = world.get_node("Ground")
	_check(ground_sprite.material == ground, "ground must share ground material")
	_check(world.get_shadow_mesh_node().material == shadow,
			"shadow mesh must use the shared shadow material")
	_check((world.get_height_texture() as Texture2D) != null,
			"shadow height map texture missing")
	_check(shadow.get_shader_parameter("height_map") is Texture2D,
			"shadow shader height_map parameter missing")
	_check(shadow.get_shader_parameter("height_map") == world.get_height_texture(),
			"shadow shader must sample the R8 height map")


func _test_shadow_geometry() -> void:
	main.set_playing(false)
	main.set_hour(8.0)
	main.set_soft_knee(true)
	main.set_shadows_enabled(true)
	await process_frame
	var stats: Dictionary = world.get_shadow_stats()
	_check(int(stats.get("casters", 0)) == 12, "expected 12 shadow casters")
	_check(int(stats.get("raw_hulls", 0)) == 12, "expected 12 raw shadow hulls")
	_check(int(stats.get("union_polygons", 99)) < 12, "overlapping shadows must merge")
	_check(int(stats.get("vertices", 0)) > 0, "shadow mesh needs vertices")
	_check(int(stats.get("draw_layers", 0)) == 1, "all shadows must be one draw layer")
	_check(bool(stats.get("single_mesh", false)), "single shadow mesh expected")
	_check(float(stats.get("raw_area", 0.0)) > float(stats.get("area", 0.0)),
			"union area must be smaller than raw hull area")
	var reports: Array[Dictionary] = world.get_shadow_reports()
	_check(reports.size() == 12, "shadow reports count")
	var oak: Dictionary = {}
	for r in reports:
		if String(r["name"]) == "oak":
			oak = r
	_check(not oak.is_empty(), "oak shadow report missing")
	if not oak.is_empty():
		var offsets: Array = oak["band_offsets"]
		_check(offsets.size() == 3, "oak needs three height bands")
		if offsets.size() == 3:
			_check(float(offsets[0]) < float(offsets[1])
					and float(offsets[1]) < float(offsets[2]),
					"higher vertices must offset farther")
			_check(float(offsets[2]) <= float(oak["length"]) + 0.01,
					"top band offset must not exceed total length")
		var dir: Vector2 = oak["direction"]
		_check(absf(dir.length() - 1.0) < 0.001, "oak shadow dir unit")
		var oak_base: Vector2 = oak["base"]
		var oak_tip: Vector2 = oak["tip"]
		var expected_tip: Vector2 = oak_base + dir * float(oak["length"])
		_check((expected_tip - oak_tip).length() < 0.01,
				"oak shadow tip math")
	var mesh = world.get_shadow_mesh_node().mesh
	_check(mesh != null and mesh.get_surface_count() == 1,
			"shadow mesh must have one surface")
	_check(world.get_shadow_mesh_node().z_index == SunMoonWorld.SHADOW_Z,
			"shadow mesh z index")
	var occluder: Sprite2D = world.get_foreground_occluder()
	_check(occluder != null and occluder.z_index > world.get_shadow_mesh_node().z_index,
			"foreground grass fringe must occlude shadows")
	var merged: Array = world.shadow_rig.get_merged()
	for i in merged.size():
		for j in range(i + 1, merged.size()):
			var inter := Geometry2D.intersect_polygons(merged[i]["poly"], merged[j]["poly"])
			var area := 0.0
			for p in inter:
				area += absf(_poly_area(p))
			_check(area < 0.25, "union polygons must not overlap (area %.3f)" % area)
	# 重叠树影：08:00 的 oak + pine。
	var probe: Dictionary = world.refresh_overlap_probe()
	_check(bool(probe.get("found", false)), "tree shadow overlap probe must exist at 08:00")
	if bool(probe.get("found", false)):
		var pair: Array = probe["pair"]
		_check(pair.has("oak") and pair.has("pine"), "overlap must be oak+pine")
		_check(int(probe["overlap_coverage"]) == 1, "overlap point must be one union layer")
		_check(int(probe["single_coverage"]) == 1, "single point must be one union layer")
		var a_single: float = world.get_shadow_alpha_at(probe["single_point"])
		var a_overlap: float = world.get_shadow_alpha_at(probe["overlap_point"])
		_near(a_overlap, a_single, 0.0001, "overlap and single shadow alpha must match")
		_check(a_single > 0.2, "probe shadow alpha must be visible")
	# 合成测试：两个重叠 caster 只产生一块并集。
	var sb := ShadowBuilder.new()
	var spec_a := {
		"name": "a", "base": Vector2(300, 200), "height": 50.0,
		"footprint": ShadowBuilder.ellipse_poly(0, 0, 18, 10, 12),
		"bands": [{"h": 48.0, "poly": ShadowBuilder.ellipse_poly(0, -2, 16, 8, 12)}],
	}
	var spec_b := {
		"name": "b", "base": Vector2(312, 202), "height": 50.0,
		"footprint": ShadowBuilder.ellipse_poly(0, 0, 18, 10, 12),
		"bands": [{"h": 48.0, "poly": ShadowBuilder.ellipse_poly(0, -2, 16, 8, 12)}],
	}
	var synth_specs: Array[Dictionary] = [spec_a, spec_b]
	sb.setup(synth_specs)
	sb.update(LightModel.state(12.0, true), true)
	var synth_stats: Dictionary = sb.get_stats()
	_check(int(synth_stats["raw_hulls"]) == 2, "synthetic raw hulls")
	_check(int(synth_stats["union_polygons"]) == 1, "synthetic overlap must merge to one")
	_check(bool(synth_stats["overlap_merged"]), "synthetic overlap flag")
	var synth_merged: Array = sb.get_merged()
	if synth_merged.size() == 1:
		_check(absf(_poly_area(synth_merged[0]["poly"])) < float(synth_stats["raw_area"]),
				"synthetic union must not double count area")
	var bad := 0
	for y in range(190, 240, 2):
		for x in range(280, 345, 2):
			if sb.coverage_count(Vector2(x, y)) > 1:
				bad += 1
	_check(bad == 0, "synthetic coverage must never exceed 1 layer")


func _test_heightmap() -> void:
	var img: Image = world.get_height_image()
	_check(img != null and img.get_format() == Image.FORMAT_R8,
			"height map must be single-channel R8")
	_check(img.get_size() == Vector2i(640, 360), "height map size")
	var info: Dictionary = world.get_height_info()
	_check(String(info["format"]) == "R8", "height info format")
	_check(int(info["channels"]) == 1, "height info single channel")
	_check(String(info["gl_compatibility_note"]).contains("R8"),
			"R16F GL fallback note")
	var roof: float = world.sample_height_px(Vector2(178, 150))
	var wall: float = world.sample_height_px(Vector2(178, 230))
	var open_ground: float = world.sample_height_px(Vector2(270, 220))
	var grass: float = world.sample_height_px(Vector2(10, 330))
	var max_grass := 0.0
	for yy in range(300, 360, 2):
		for xx in range(0, 640, 4):
			max_grass = maxf(max_grass, world.sample_height_px(Vector2(xx, yy)))
	_check(roof > 100.0, "house roof height should be >100px, got %.1f" % roof)
	_check(wall > 10.0 and wall < roof, "wall should be lower than roof")
	_near(open_ground, 0.0, 0.01, "open ground height must be 0")
	_check(grass > 10.0, "foreground grass should encode height, got %.1f" % grass)
	_check(max_grass > 35.0, "foreground tall grass max height, got %.1f" % max_grass)
	_check(LightModel.occlusion_allows(140.0, roof, 2.0),
			"tall tree shadow may land on lower housetop")
	_check(not LightModel.occlusion_allows(32.0, roof, 2.0),
			"low barrel shadow must not darken roof")
	_check(not LightModel.occlusion_allows(32.0, max_grass, 2.0),
			"low barrel shadow must be blocked by tall grass")
	_check(LightModel.occlusion_allows(140.0, max_grass, 2.0),
			"tall tree shadow may project onto grass")
	_check(LightModel.occlusion_allows(140.0, 0.0, 2.0), "tree shadow on ground")
	_check((world.get_height_texture() as Texture2D) != null, "height texture")
	var occlusion: Dictionary = world.get_occlusion_debug()
	_check(bool(occlusion["barrel_vs_roof"]) == false, "occlusion debug barrel vs roof")
	_check(bool(occlusion["tree_vs_ground"]), "occlusion debug tree vs ground")
	world.set_debug_flag("heightmap", true)
	_check(world.get_height_view().visible, "height map debug view should be visible")
	_check(world.get_height_view().texture.get_size() == Vector2(640, 360),
			"height debug view texture size")
	world.set_debug_flag("heightmap", false)
	_check(not world.get_height_view().visible, "height map debug view should hide")
	world.set_debug_flag("occlusion", true)
	_check(int(world.shadow_material.get_shader_parameter("debug_mode")) == 1,
			"occlusion debug should switch shadow shader debug_mode")
	world.set_debug_flag("occlusion", false)
	_check(int(world.shadow_material.get_shader_parameter("debug_mode")) == 0,
			"shadow shader should return to normal mode")
	var shader_code: String = world.shadow_material.shader.code
	_check(shader_code.contains("texture(height_map, SCREEN_UV)"),
			"shadow shader must sample height map at SCREEN_UV")
	_check(shader_code.contains("smoothstep(receiver_h"), "shader soft height knee")


func _test_soft_knee() -> void:
	var h := 100.0
	var cap := LightModel.shadow_cap(h)
	var knee := LightModel.shadow_knee(h)
	_near(cap, 300.0, 0.001, "cap = 3H")
	_near(knee, 180.0, 0.001, "knee = 0.6 cap = 1.8H")
	var e_knee := rad_to_deg(atan(h / knee))
	_near(LightModel.shadow_length(h, e_knee, true), knee, 0.15,
			"soft knee length at 60%")
	_near(LightModel.shadow_length(h, e_knee, false), knee, 0.15,
			"hard clamp length at knee")
	var raw_lo := knee - 0.5
	var raw_hi := knee + 0.5
	var e_lo := rad_to_deg(atan(h / raw_lo))
	var e_hi := rad_to_deg(atan(h / raw_hi))
	var l_lo := LightModel.shadow_length(h, e_lo, true)
	var l_hi := LightModel.shadow_length(h, e_hi, true)
	_check(l_hi >= l_lo, "soft knee must be monotonic around the knee")
	_check(absf(l_hi - l_lo) < 1.0, "soft knee must be continuous (no jump)")
	var l_knee_plus := LightModel.shadow_length(h, e_hi, true)
	var l_knee := LightModel.shadow_length(h, e_knee, true)
	var slope := (l_knee_plus - l_knee) / (raw_hi - knee)
	_check(slope > 0.85 and slope < 1.15,
			"soft knee slope at entry should be ~1 (C1), got %.3f" % slope)
	var raw_600 := 600.0
	var e600 := rad_to_deg(atan(h / raw_600))
	var soft600 := LightModel.shadow_length(h, e600, true)
	var hard600 := LightModel.shadow_length(h, e600, false)
	_near(hard600, cap, 0.001, "hard clamp at 3H")
	_check(soft600 < cap and soft600 > knee + 100.0,
			"soft tail should approach but not hit 3H (%.2f)" % soft600)
	var raw_2000 := 2000.0
	var e2000 := rad_to_deg(atan(h / raw_2000))
	var soft2000 := LightModel.shadow_length(h, e2000, true)
	_check(soft2000 > soft600 and soft2000 < cap,
			"soft tail must keep approaching cap")
	_near(LightModel.shadow_length(0.0, 45.0, true), 0.0, 0.0001, "zero height shadow")
	# 场景里的 toggle：18:20 软膝 412.7 < 3H 420；关掉后硬截 420。
	main.set_hour(18.3333)
	main.set_soft_knee(true)
	await process_frame
	var oak: Dictionary = {}
	for r in world.get_shadow_reports():
		if String(r["name"]) == "oak":
			oak = r
	_check(not oak.is_empty(), "oak report for knee toggle")
	if not oak.is_empty():
		_check(bool(oak["compressed"]), "18:20 oak shadow should be knee-compressed")
		var soft_len := float(oak["length"])
		_check(soft_len < float(oak["cap"]) - 1.0, "soft knee should stay under 3H")
		main.set_soft_knee(false)
		await process_frame
		var oak_hard: Dictionary = {}
		for r in world.get_shadow_reports():
			if String(r["name"]) == "oak":
				oak_hard = r
		_near(float(oak_hard["length"]), float(oak_hard["cap"]), 0.01,
				"soft knee off should hard clamp at 3H")
		_check(not main.is_soft_knee(), "main soft knee flag off")
		main.set_soft_knee(true)
		await process_frame
		_check(main.is_soft_knee(), "main soft knee flag back on")
	var curve = hud.get_curve_plot()
	_check(curve != null, "knee curve plot missing")
	_check(curve.main == main, "knee curve must read main")


func _test_night_lamps() -> void:
	main.set_hour(21.0)
	main.set_shadows_enabled(true)
	main.set_lamps_enabled(true)
	await process_frame
	var solar: Dictionary = main.get_solar()
	_check(String(solar["main_light"]) == "moon", "21:00 main light moon")
	_near(float(solar["moon_elevation"]), 31.6556, 0.05, "21:00 moon elevation")
	_check(float(solar["night"]) > 0.99, "21:00 night mix")
	var amb: Color = main.get_global_uniform("u_ambient_sub")
	_check(amb.a <= 0.5, "night ambient removal <= 0.5")
	_check(amb.b > amb.r, "night moon shadow cool")
	_check(world.are_lamps_on(), "lamps should be on at 21:00")
	_check(world.get_lamps().size() == 2, "two lamps")
	for lamp in world.get_lamps():
		var pool: Sprite2D = lamp["pool"]
		var halo: Sprite2D = lamp["halo"]
		_check(pool.visible and halo.visible, "lamp glow layers visible at night")
		_check(pool.z_index > world.get_shadow_mesh_node().z_index,
				"lamp glow must draw after the shadow mesh")
	var glow: Color = world.lamp_pool_material.get_shader_parameter("glow_color")
	_check(glow.r > glow.g and glow.g > glow.b, "lamp color must be warm")
	_check(float(world.lamp_pool_material.get_shader_parameter("intensity")) > 0.0,
			"lamp pool intensity")
	_check(float(world.get_state()["shadow_alpha"]) > 0.2,
			"moon shadow alpha must remain visible")
	_check(world.get_moon_sprite().visible, "moon sprite should be visible at 21:00")
	_check(not world.get_sun_sprite().visible, "sun sprite should be below horizon")
	for w in world.get_windows():
		_check(w.visible, "window glow should be visible at night")
	main.set_lamps_enabled(false)
	await process_frame
	_check(not world.are_lamps_on(), "lamps must switch off")
	_check(not (world.get_lamps()[0]["pool"] as Sprite2D).visible,
			"lamp pool hidden when off")
	main.set_lamps_enabled(true)
	await process_frame
	_check(world.are_lamps_on(), "lamps back on")
	main.set_hour(12.0)
	await process_frame
	_check(not world.are_lamps_on(), "lamps auto-off in daylight")


func _test_debug_and_reset() -> void:
	main.set_hour(8.0)
	main.set_playing(false)
	main.set_debug_enabled(true)
	_check(hud.is_debug_visible(), "debug panel should open")
	main.set_debug_flag("heightmap", true)
	main.set_debug_flag("occlusion", true)
	main.set_debug_flag("mesh", true)
	main.set_debug_flag("overlap", true)
	await process_frame
	_check(world.get_height_view().visible, "debug height view")
	_check(int(world.shadow_material.get_shader_parameter("debug_mode")) == 1,
			"debug occlusion heat")
	_check(world.is_debug_flag("mesh"), "debug mesh flag")
	_check(bool(world.get_overlap_probe().get("found", false)), "debug overlap probe")
	main.set_debug_enabled(false)
	await process_frame
	_check(not hud.is_debug_visible(), "debug panel should close")
	for flag in ["heightmap", "occlusion", "mesh", "overlap"]:
		_check(not world.is_debug_flag(flag), "debug flag %s must clear" % flag)
	_check(not world.get_height_view().visible, "height view cleared")
	_check(int(world.shadow_material.get_shader_parameter("debug_mode")) == 0,
			"shadow debug cleared")
	# UI 显示开关。
	main.set_ui_visible(false)
	_check(not hud.is_ui_visible(), "H must hide UI")
	_check(not hud.get_root_control().visible, "HUD root hidden")
	main.set_ui_visible(true)
	_check(hud.is_ui_visible(), "H restores UI")
	# 重置。
	main.set_hour(21.0)
	main.set_speed(64.0)
	main.set_shadows_enabled(false)
	main.set_soft_knee(false)
	main.set_lamps_enabled(false)
	main.set_debug_enabled(true)
	main.reset()
	_near(main.get_hour(), 8.0, 0.001, "reset hour 08:00")
	_check(main.is_playing(), "reset should play")
	main.set_playing(false)
	await process_frame
	_near(main.get_speed(), 16.0, 0.001, "reset speed 16x")
	_check(main.are_shadows_enabled(), "reset shadows on")
	_check(main.is_soft_knee(), "reset soft knee on")
	_check(main.are_lamps_enabled(), "reset lamps enabled")
	_check(not main.is_debug_enabled(), "reset debug off")
	_check(not hud.is_debug_visible(), "reset debug panel hidden")
	_check(not world.are_lamps_on(), "reset at 08:00 lamps auto-off")
	var slider: HSlider = hud.get_time_slider()
	_near(slider.value, 8.0, 0.01, "reset slider 08:00")
	_check(hud.get_time_label().text == "08:00", "reset time label")
	_check(main.get_fps() >= 0, "FPS readable")
	_check(main.get_draw_calls() >= 0, "draw calls readable")


func _test_no_light2d() -> void:
	_check(world.find_children("*", "Light2D", true, false).is_empty(),
			"must not use Light2D nodes")
	_check(world.find_children("*", "LightOccluder2D", true, false).is_empty(),
			"must not use LightOccluder2D")
	_check(world.find_children("*", "MeshInstance2D", true, false).size() == 1,
			"exactly one shadow mesh in the scene")
	_check(world.get_shadow_stats().get("draw_layers", 0) == 1,
			"shadow draw layers must be 1")
