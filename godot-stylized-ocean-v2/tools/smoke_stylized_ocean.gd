extends SceneTree

# 无头验收：地形/水深色阶、Gerstner 参数、涟漪源生命周期与上限、鼠标射线与交互、
# 落石水花、天气/昼夜/相机/UI 开关、渲染统计。末行 STYLIZED_OCEAN_SMOKE_OK。
# 用法：godot --headless --path godot-stylized-ocean-v2 -s tools/smoke_stylized_ocean.gd

var _fails: Array[String] = []
var _checks := 0


func _init() -> void:
	_run()


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.35).timeout

	var field: IslandField = scene.get_field()
	var ocean: StylizedOcean = scene.get_ocean()
	var cam: OrbitRig = scene.get_camera_rig()
	var hud: OceanHud = scene.get_hud()
	var builder: OceanScene = scene.get_scene_builder()

	# ── 地形与水深 ────────────────────────────────────────────────
	_check(field.rock_sites.size() >= 20, "rock site count too low")
	var coast := field.coast_radius(0.0)
	_check(coast > 18.0 and coast < 36.0, "coast radius out of range: %.2f" % coast)
	var center_h := field.height(0.0, 0.0)
	_check(center_h > 1.0, "island center should be above water: %.2f" % center_h)
	var d6 := field.water_depth_at(0.0, 40.0)
	var d_land := field.water_depth_at(0.0, 4.0)
	var d_far := field.water_depth_at(0.0, 80.0)
	_check(d6 > 1.0, "shallow shelf too shallow: %.2f" % d6)
	_check(d_land < 0.05, "island should not have water depth")
	_check(d_far > d6, "deep water should be deeper than shelf")

	# ── 岸距场 / 透明浅水构成（T-20261126-021） ─────────────────
	# 岸距场纹理：中心为内陆（R→1），南侧 40 m 为水中（R→0）
	_check(field.shore_texture != null, "shore map not baked")
	if field.shore_texture != null:
		var simg: Image = field.shore_texture.get_image()
		_check(simg.get_width() == IslandField.SHORE_TEX_SIZE, "shore map size wrong")
		_check(simg.get_pixel(512, 512).r > 0.9, "island center should encode inland")
		var sea_py := clampi(int((40.0 / IslandField.AREA + 0.5) * IslandField.SHORE_TEX_SIZE), 0, 1023)
		_check(simg.get_pixel(512, sea_py).r < 0.5, "sea point should encode water")
	_check(field.shore_distance_at(0.0, 0.0) > 4.0, "center signed shore distance")
	_check(field.shore_distance_at(0.0, 40.0) < -2.0, "sea signed shore distance")
	_check(ocean.material.get_shader_parameter("shore_map") != null, "water shore map uniform")
	_check(is_equal_approx(float(ocean.material.get_shader_parameter("shore_range")), 16.0),
			"water shore range uniform")
	_check(ocean.material.shader.code.contains("blend_mix"), "water shader should alpha-blend")
	_check(builder.terrain_material.get_shader_parameter("shore_map") != null,
			"terrain shore map uniform")
	_check(builder.terrain_material.get_shader_parameter("caustic_tex") != null,
			"terrain caustic texture uniform")
	_check(builder.rock_material.get_shader_parameter("foam_tex") != null,
			"rock foam texture uniform")
	var tverts: PackedVector3Array = builder.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(tverts.size() > 40000, "terrain mesh densified and extended: %d verts" % tverts.size())
	_check(hud._debug_captions.size() == 8, "debug captions should include shore layers")
	scene.set_debug_view(6)
	_check(ocean.get_debug_view() == 6 and hud.debug_label.visible, "shore sdf debug view")
	scene.set_debug_view(7)
	_check(ocean.get_debug_view() == 7 and hud.debug_label.visible, "shore layer debug view")
	scene.set_debug_view(0)

	# ── 海面网格 / 波浪参数 ───────────────────────────────────────
	var verts: PackedVector3Array = ocean.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(verts.size() == (StylizedOcean.RING_COUNT + 1) * StylizedOcean.SEGMENT_COUNT,
			"water vertex count wrong: %d" % verts.size())
	_check(ocean.debug_snapshot()["wave_count"] == 6, "wave count should be 6")
	_check(ocean.wave_height > 0.5, "default wave height too low")
	ocean.set_wave_height(1.4)
	_check(is_equal_approx(ocean.wave_height, 1.4), "wave height setter")
	_check(is_equal_approx(float(ocean.material.get_shader_parameter("wave_height")), 1.4),
			"wave height uniform not updated")
	ocean.set_wave_speed(0.5)
	_check(is_equal_approx(ocean.wave_speed, 0.5), "wave speed setter")
	ocean.set_wave_direction(95.0)
	_check(is_equal_approx(ocean.wave_dir_deg, 95.0), "wave direction setter")
	ocean.set_foam_amount(1.2)
	_check(is_equal_approx(ocean.foam_amount, 1.2), "foam setter")
	ocean.set_wave_height(0.72)
	ocean.set_wave_speed(1.0)
	ocean.set_wave_direction(18.0)
	ocean.set_foam_amount(0.85)

	# ── 涟漪源生命周期 ────────────────────────────────────────────
	ocean.clear_ripples()
	_check(ocean.ripples.is_empty(), "clear ripples")
	ocean.spawn_ripple(2.0, 3.0, 1.0)
	ocean.spawn_ripple(6.0, 3.0, 0.6)
	var rc: int = ocean.debug_snapshot()["ripple_count"]
	_check(rc == 2, "expected 2 ripples, got %d" % rc)
	var u = ocean.material.get_shader_parameter("ripples")
	_check(u is Array or u is PackedVector4Array, "ripple uniform type")
	_check(u.size() == 12, "shader ripple uniform array should be 12, got %d" % u.size())
	ocean.set_ripple_decay(1.0)  # fast decay -> life 1.6s
	ocean.tick(2.0)
	_check(ocean.ripples.is_empty(), "ripples should expire after life")
	for i in 20:
		ocean.spawn_ripple(float(i), 0.0, 0.8)
	_check(ocean.ripples.size() == 12, "ripple cap should be 12, got %d" % ocean.ripples.size())
	ocean.clear_ripples()
	ocean.set_ripple_decay(0.35)

	# ── 鼠标射线 / 交互 ──────────────────────────────────────────
	scene.set_camera_target(0.0, 60.0, 0.0)
	scene.set_camera_orbit(90.0, 65.0, 55.0)
	await process_frame
	var center := Vector2(640.0, 360.0)
	var hit: Dictionary = cam.screen_to_water(center)
	_check(hit["valid"], "center ray should hit water when camera targets deep sea")
	if hit["valid"]:
		var depth: float = hit.get("depth", 0.0)
		_check(depth > 0.2, "water hit depth too small: %.2f" % depth)
		scene.ocean.clear_ripples()
		var before: int = scene.ocean.ripples.size()
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = center
		scene._unhandled_input(ev)
		_check(scene.ocean.ripples.size() == before + 1, "left click should spawn a ripple")
		var rel := InputEventMouseButton.new()
		rel.button_index = MOUSE_BUTTON_LEFT
		rel.pressed = false
		rel.position = center
		scene._unhandled_input(rel)
		scene.tick(0.02)
		_check(scene._falling.size() >= 1 or scene._floating.size() >= 1,
				"quick click should drop a rock")
		scene.tick(0.8)
		_check(scene._rings.size() >= 1 or scene._splashes.size() >= 1 or scene._floating.size() >= 1,
				"splash/ring should be created after rock impact")

	scene.set_camera_target(0.0, 0.0, 1.0)
	scene.set_camera_orbit(90.0, 80.0, 60.0)
	await process_frame
	var land: Dictionary = cam.screen_to_water(Vector2(640.0, 360.0))
	_check(not land["valid"], "island center ray should not be treated as water")

	# ── 相机 / 昼夜 / 天气 / UI ──────────────────────────────────
	scene.set_camera_orbit(120.0, 40.0, 80.0)
	_check(is_equal_approx(cam.yaw_deg, 120.0) and is_equal_approx(cam.distance, 80.0),
			"camera orbit setter")
	scene.set_camera_pitch(30.0)
	_check(is_equal_approx(cam.pitch_deg, 30.0), "camera pitch setter")
	scene.set_camera_distance(100.0)
	_check(is_equal_approx(cam.distance, 100.0), "camera distance setter")

	scene.set_hour(20.4)
	_check(builder.night_weight > 0.5, "night weight should be high at 20.4h")
	_check(builder.palette["deep"] != null, "night palette missing")
	scene.set_hour(11.5)
	_check(builder.day_weight > 0.9, "day weight should be ~1 at 11.5h")

	scene.set_rain(true)
	_check(builder.rain.visible and builder.rain.emitting, "rain particles should emit")
	_check(scene.get_ui_state()["rain"] == true, "rain state")
	scene.tick(0.2)
	scene.set_rain(false)
	_check(not builder.rain.emitting, "rain should stop")

	scene.set_auto_orbit(false)
	_check(not cam.auto_orbit, "auto orbit off")
	scene.set_auto_orbit(true)
	_check(cam.auto_orbit, "auto orbit on")

	scene.set_debug_view(5)
	_check(ocean.get_debug_view() == 5, "debug view setter")
	_check(hud.debug_label.visible, "debug label should be visible")
	scene.set_debug_view(0)
	_check(not hud.debug_label.visible, "debug label should hide")

	scene.set_water_style(1)
	_check(scene.get_ui_state()["style"] == 1, "water style setter")
	scene.set_water_style(0)
	scene.set_ripples_enabled(false)
	_check(not scene.ripples_enabled, "ripples toggle")
	scene.set_ripples_enabled(true)
	scene.set_shoreline_visible(true)
	_check(scene._shore_line.visible, "shoreline debug visible")
	scene.set_shoreline_visible(false)
	scene.set_clouds_visible(false)
	_check(not builder.clouds[0].visible, "clouds hidden")
	scene.set_clouds_visible(true)

	scene.set_ui_visible(false)
	_check(not hud.visible, "HUD hide")
	scene.set_ui_visible(true)
	scene.set_panel_open(false)
	_check(not hud.collapse_box.visible, "panel collapse")
	scene.set_panel_open(true)
	scene.set_ui_scale(1.5)
	_check(hud.scale_factor >= 1.4, "HUD scale")
	scene.set_ui_scale(1.0)

	scene.set_paused(true)
	_check(scene.paused, "pause setter")
	scene.set_paused(false)
	scene.reset_params()
	_check(is_equal_approx(scene.time_hour, 11.5), "reset time")
	_check(is_equal_approx(ocean.wave_height, 0.72), "reset wave height")

	var stats: Dictionary = scene.get_stats()
	_check(stats.has("fps") and stats.has("draw_calls"), "stats missing fps/draw calls")
	_check(stats["ripples"] >= 0, "stats ripples")
	_check(scene.get_ui_state().has("hour"), "ui state missing hour")

	if _fails.is_empty():
		print("checks=", _checks)
		print("STYLIZED_OCEAN_SMOKE_OK")
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL: ", f)
		print("STYLIZED_OCEAN_SMOKE_FAILED")
		quit(1)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)
