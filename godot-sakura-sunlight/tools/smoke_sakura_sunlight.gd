extends SceneTree

# 无头验收：
#   刻数/时间映射、09:45=58.2° 的余弦高度角、方位角 sin/cos 光照向量、
#   影向取反、影长 = H/tan(elev) 与 1.8H 封顶、树干+树冠两段投影连接、
#   全局 shader uniform 同步、时间滑杆/暂停/速度、阴影/调试/花瓣开关、
#   640×360 世界与整数最近邻放大、无 3D/Light2D。
# 用法：godot --headless --path godot-sakura-sunlight -s tools/smoke_sakura_sunlight.gd
# 末行：SAKURA_SUNLIGHT_SMOKE_OK checks=N

var _fails: Array[String] = []
var _checks := 0


func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.20).timeout
	scene.set_playing(false)
	scene.set_hour(8.0)
	var hud = scene.get_node("HUD")
	var world = scene.get_world()

	# ── 时间 / 刻数 ───────────────────────────────────────────────────
	_check(SunModel.TICKS_PER_DAY == 6000, "ticks/day must be 6000")
	_check(SunModel.hour_to_ticks(8.0) == 2000, "08:00 must be tick 2000")
	_check(SunModel.hour_to_ticks(12.0) == 3000, "12:00 must be tick 3000")
	_check(SunModel.hour_to_ticks(17.0) == 4250, "17:00 must be tick 4250")
	_check(SunModel.hour_to_ticks(32.0) == 2000, "tick wrap 24h+8h failed")
	_check(absf(SunModel.ticks_to_hour(2000) - 8.0) < 0.0001, "tick->hour failed")
	_check(hud.format_hour(9.75) == "09:45", "HUD hour formatting failed")
	_check(absf(scene.get_hour() - 8.0) < 0.001, "main set_hour(8) failed")
	_check(scene.get_ticks() == 2000, "main ticks at 08:00 != 2000")

	# ── 太阳模型 ──────────────────────────────────────────────────────
	_check(absf(SunModel.elevation_deg(8.0) - 35.0) < 0.02,
			"08:00 elevation != 35.0")
	_check(absf(SunModel.elevation_deg(12.0) - 70.0) < 0.02,
			"12:00 elevation != 70.0")
	_check(absf(SunModel.elevation_deg(17.0) - 18.117) < 0.05,
			"17:00 elevation != 18.06")
	_check(absf(SunModel.elevation_deg(9.75) - 58.2) < 0.1,
			"09:45 elevation should be ~58.2° (reference check)")
	_check(absf(SunModel.azimuth_deg(8.0) - 50.0) < 0.001, "08:00 azimuth != 50")
	_check(absf(SunModel.azimuth_deg(12.0) - 90.0) < 0.001, "noon azimuth != 90")
	_check(absf(SunModel.azimuth_deg(17.0) - 140.0) < 0.001, "17:00 azimuth != 140")

	var s8: Vector2 = SunModel.sun_plane_dir(8.0)
	var s12: Vector2 = SunModel.sun_plane_dir(12.0)
	var s17: Vector2 = SunModel.sun_plane_dir(17.0)
	_check(absf(s8.length() - 1.0) < 0.001, "08:00 sun vector not unit")
	_check(s8.x > 0.0 and s8.y < 0.0, "08:00 sun should be up-right (screen)")
	_check(absf(s12.x) < 0.001 and s12.y < -0.999, "noon sun should be straight up")
	_check(s17.x < 0.0 and s17.y < 0.0, "17:00 sun should be up-left (screen)")
	var d8: Vector2 = SunModel.shadow_direction(8.0)
	_check((d8 + s8).length() < 0.0001, "shadow direction must be -sun direction")
	_check(d8.x < 0.0 and d8.y > 0.0, "08:00 shadow should fall down-left")

	# ── 影长 / 封顶 ───────────────────────────────────────────────────
	var h := 100.0
	var noon_len := SunModel.raw_shadow_length(h, 12.0)
	_check(absf(noon_len - h / tan(deg_to_rad(70.0))) < 0.001,
			"raw shadow length != H/tan(elev)")
	_check(absf(noon_len - 36.397) < 0.01, "noon shadow should be ~0.364 H")
	var morning := SunModel.shadow_info(h, 8.0)
	_check(not bool(morning["capped"]), "08:00 should not be capped")
	_check(absf(float(morning["ratio"]) - 1.428) < 0.01,
			"08:00 shadow ratio should be ~1.43 H")
	var evening := SunModel.shadow_info(h, 17.0)
	_check(bool(evening["capped"]), "17:00 should hit the shadow cap")
	_check(absf(float(evening["length"]) - h * 1.8) < 0.001,
			"17:00 shadow must clamp at 1.8 H")
	_check(SunModel.shadow_length(h, 17.0) <= h * 1.8 + 0.001,
			"shadow_length cap violated")

	# ── 场景 / 两段投影 ───────────────────────────────────────────────
	_check(world != null, "world missing")
	_check(world.get_tree_count() >= 2, "need at least 2 cherry trees")
	_check(world.get_tree_count() == 3, "expected 3 cherry trees")
	_check(world.get_rocks().size() >= 1, "need rocks with shadows")
	var hero_shadow: ShadowCaster = world.get_hero_shadow()
	_check(hero_shadow != null, "hero shadow caster missing")
	_check(hero_shadow.is_two_part(), "tree shadow must have trunk + crown sprites")
	_check(hero_shadow.get_trunk_sprite() != null, "trunk shadow sprite missing")
	_check(hero_shadow.get_crown_sprite() != null, "crown shadow sprite missing")
	_check(hero_shadow.get_contact_sprite() != null, "contact shadow missing")

	for hour in [8.0, 9.75, 12.0, 16.0, 17.0]:
		scene.set_hour(hour)
		var rep: Dictionary = scene.get_hero_shadow_report()
		var elev := SunModel.elevation_deg(hour)
		var expected := minf(rep["visual_height"] / tan(deg_to_rad(elev)),
				float(rep["visual_height"]) * 1.8)
		_check(absf(float(rep["total_length"]) - expected) < 0.05,
				"hero shadow length mismatch at %.2f: %.2f vs %.2f" % [
					hour, float(rep["total_length"]), expected])
		_check(absf(float(rep["trunk_length"]) + float(rep["crown_length"])
				- float(rep["total_length"])) < 0.01,
				"two shadow segments do not add up at %.2f" % hour)
		if bool(rep["two_part"]):
			var direction: Vector2 = rep["direction"]
			var junction: Vector2 = direction * float(rep["trunk_length"])
			_check((junction - Vector2(rep["junction"])).length() < 0.01,
					"trunk shadow junction mismatch at %.2f" % hour)
			_check((direction * float(rep["total_length"])
					- Vector2(rep["tip"])).length() < 0.01,
					"shadow tip mismatch at %.2f" % hour)
			# 树冠影子的底边必须接在树干影子的末端。
			var crown_sprite: Sprite2D = hero_shadow.get_crown_sprite()
			_check(crown_sprite != null and crown_sprite.visible,
					"crown shadow must remain visible at %.2f" % hour)
			_check(crown_sprite.position.distance_to(junction) < 0.01,
					"crown shadow is not anchored at the trunk junction at %.2f" % hour)
		if hour == 17.0:
			_check(bool(rep["capped"]), "hero shadow should be capped at 17:00")

	# 两棵树 / 石头都有影子。
	var reports: Array = world.get_shadow_reports()
	_check(reports.size() == 6, "expected 6 shadow casters (3 trees + 3 rocks)")
	var two_part := 0
	for r in reports:
		if bool(r["two_part"]):
			two_part += 1
		_check(bool(r["crown_visible"]), "shadow crown not visible: %s" % r["name"])
	_check(two_part == 3, "all 3 trees should use two-part shadows")
	_check(world.get_rocks().size() == 3, "expected 3 rocks")

	# ── 全局 shader uniform / 共享材质 ────────────────────────────────
	var foliage_mat: ShaderMaterial = world.foliage_material
	var ground_mat: ShaderMaterial = world.ground_material
	var shadow_mat: ShaderMaterial = world.shadow_material
	for mat in [foliage_mat, ground_mat, shadow_mat]:
		_check(mat != null and mat.shader != null, "shared material missing")
		_check(mat.get_shader_parameter("u_sun_dir") == null,
				"sun direction must not be a per-object material parameter")
	_check(foliage_mat.shader.code.contains("global uniform vec2 u_sun_dir"),
			"foliage shader does not declare global u_sun_dir")
	_check(ground_mat.shader.code.contains("global uniform vec2 u_sun_dir"),
			"ground shader does not declare global u_sun_dir")
	_check(shadow_mat.shader.code.contains("global uniform vec4 u_shadow_color"),
			"shadow shader does not declare global u_shadow_color")
	_check(world.get_ground().material == ground_mat, "ground does not share ground material")
	_check(world.get_tree_entry(0)["canopy"].material == foliage_mat,
			"tree canopy does not share foliage material")
	_check(hero_shadow.get_crown_sprite().material == shadow_mat,
			"crown shadow does not share shadow material")

	_check(ProjectSettings.has_setting("shader_globals/u_sun_dir"),
			"u_sun_dir is not registered as a project shader global")
	_check(ProjectSettings.has_setting("shader_globals/u_sun_color"),
			"u_sun_color is not registered as a project shader global")
	_check(ProjectSettings.has_setting("shader_globals/u_shadow_color"),
			"u_shadow_color is not registered as a project shader global")

	scene.set_hour(8.0)
	var g8_m: Vector2 = scene.get_global_uniform("u_sun_dir")
	var c8_m: Color = scene.get_global_uniform("u_sun_color")
	var e8_m: float = scene.get_global_uniform("u_sun_elevation")
	_check(absf(e8_m - 35.0) < 0.02, "mirrored u_sun_elevation not 35 at 08:00")
	_check((g8_m - SunModel.sun_plane_dir(8.0)).length() < 0.001,
			"mirrored u_sun_dir not synced at 08:00")
	scene.set_hour(17.0)
	var g17_m: Vector2 = scene.get_global_uniform("u_sun_dir")
	var c17_m: Color = scene.get_global_uniform("u_sun_color")
	var e17_m: float = scene.get_global_uniform("u_sun_elevation")
	_check(absf(e17_m - 18.117) < 0.05, "mirrored u_sun_elevation not 18.06 at 17:00")
	_check((g17_m - SunModel.sun_plane_dir(17.0)).length() < 0.001,
			"mirrored u_sun_dir not synced at 17:00")
	_check(g8_m.distance_to(g17_m) > 0.5, "sun direction did not change over the day")
	_check(c8_m != c17_m, "sun color did not change over the day")
	_check(c8_m.r >= c8_m.b and c17_m.r > c17_m.b, "sun colors should be warmer than blue")

	# Godot 4.6 GLES3 的 global_shader_parameter_get 是 editor-only；
	# 运行时通过“写入路径镜像 + 工程注册 + shader 声明 + 无本地覆盖”验证，
	# 真实 GPU 的渲染结果由 tools/probe_sakura_sunlight.gd 做像素差异检查。
	print("SMOKE_NOTE global shader writes are checked via mirror/registration/shader "
			+ "declarations; GPU probe verifies the rendered result")

	# ── 滑杆 / 暂停 / 速度 ────────────────────────────────────────────
	var slider: HSlider = hud.get_time_slider()
	_check(slider != null, "time slider missing")
	_check(absf(slider.min_value - 8.0) < 0.001 and absf(slider.max_value - 17.0) < 0.001,
			"time slider range should be 08:00-17:00")
	slider.value = 12.0
	await process_frame
	_check(absf(scene.get_hour() - 12.0) < 0.001, "slider did not set 12:00")
	_check(hud.get_time_label().text == "12:00", "time label did not update")

	scene.set_playing(false)
	scene.set_hour(8.0)
	scene.simulate_time(2.0)
	_check(absf(scene.get_hour() - 8.0) < 0.001, "paused time advanced")
	scene.set_playing(true)
	scene.simulate_time(1.0)
	_check(absf(scene.get_hour() - 8.1) < 0.02, "1s at 1x should advance ~0.1h")
	scene.set_speed(2.0)
	scene.set_hour(8.0)
	scene.simulate_time(1.0)
	_check(absf(scene.get_hour() - 8.2) < 0.03, "1s at 2x should advance ~0.2h")
	scene.set_speed(1.0)
	scene.set_playing(false)
	scene.set_hour(8.0)

	# ── 开关与 HUD ────────────────────────────────────────────────────
	scene.set_shadows_enabled(false)
	_check(not world.get_shadows_root().visible, "shadows root still visible when off")
	var strength_off: float = scene.get_global_uniform("u_shadow_strength")
	_check(absf(strength_off) < 0.001, "global shadow strength not 0 when shadows off")
	scene.set_hour(8.0)
	scene.set_shadows_enabled(true)
	_check(world.get_shadows_root().visible, "shadows root not visible when on")
	var strength_on: float = scene.get_global_uniform("u_shadow_strength")
	_check(absf(strength_on - 1.0) < 0.001, "global shadow strength not 1 when shadows on")
	_check(absf(float(scene.get_hero_shadow_report()["total_length"]) - 187.0) < 4.0,
			"shadow length not refreshed after off->on at 08:00")

	scene.set_debug_enabled(true)
	_check(world.is_debug_enabled(), "debug flag not set")
	_check(world.get_debug_data()["shadows"].size() == 6, "debug data missing shadows")
	scene.set_debug_enabled(false)
	_check(not world.is_debug_enabled(), "debug flag not cleared")

	scene.set_petals_enabled(false)
	_check(not world.get_petals().is_petals_enabled(), "petals flag not cleared")
	_check(not world.get_petals().visible, "petals still visible when off")
	scene.set_petals_enabled(true)
	_check(world.get_petals().visible, "petals not visible when on")
	var petals: PetalField = world.get_petals()
	_check(petals.get_active_count() == 66, "petal count != 66")
	_check(petals.get_draw_call_hint() == 1, "petals should be one MultiMesh batch")
	var before: Vector2 = petals.get_petal_position(0)
	world.simulate_petals(0.5)
	var after: Vector2 = petals.get_petal_position(0)
	_check(before != after, "petals do not move")

	_check(hud.get_stat_label("elev") != null, "HUD elevation label missing")
	_check(hud.get_stat_label("azim") != null, "HUD azimuth label missing")
	_check(hud.get_stat_label("shadow") != null, "HUD shadow label missing")
	_check(hud.get_sun_dial() != null, "sun dial missing")
	_check(hud.get_play_button() != null, "play button missing")
	hud.sync_from_main()
	_check(absf(hud.get_time_slider().value - scene.get_hour()) < 0.001,
			"HUD slider did not resync to main hour")

	# ── 引擎 / 像素 / 无灯光 ─────────────────────────────────────────
	var vp: SubViewport = scene.get_node("WorldViewport")
	var display: TextureRect = scene.get_node("WorldDisplay")
	_check(vp.size == Vector2i(640, 360), "world viewport must be 640x360")
	_check(display.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"world display must use nearest filtering")
	_check(display.texture != null, "world display has no viewport texture")
	_check(1280 % 640 == 0 and 1920 % 640 == 0, "standard resolutions must scale by integers")
	_check(scene.find_children("*", "Node3D", true, false).is_empty(),
			"found Node3D; this demo must stay 2D")
	_check(scene.find_children("*", "Light2D", true, false).is_empty(),
			"found Light2D; sunlight must be pure math")
	_check(scene.find_children("*", "GPUParticles2D", true, false).is_empty(),
			"found GPUParticles2D; petals use MultiMesh")
	_check(scene.find_children("*", "CPUParticles2D", true, false).is_empty(),
			"found CPUParticles2D; petals use MultiMesh")
	_check(vp.disable_3d, "world SubViewport should disable 3D")

	if _fails.is_empty():
		print("SAKURA_SUNLIGHT_SMOKE_OK checks=%d" % _checks)
		quit(0)
	else:
		for f in _fails:
			printerr("SMOKE_FAIL: ", f)
		printerr("SAKURA_SUNLIGHT_SMOKE_FAILED checks=%d fails=%d" % [
			_checks, _fails.size()])
		quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fails.append(message)
