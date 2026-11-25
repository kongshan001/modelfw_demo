extends SceneTree

# 无头验收：
#   雨丝动态网格数量 / 无粒子节点 / 22s 积水与 75s 渗干 /
#   灯柱 1×1 放行规则 / 72 双环涟漪生命周期与雨强频率 /
#   倒影开关与统一裁切 / 暂停与重置 / 中文 HUD。
# 用法：godot --headless --path godot-rain-puddles -s tools/smoke_rain_puddles.gd

var _fails: Array[String] = []
var _checks := 0


func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.15).timeout

	var field: PuddleField = scene.get_field()
	var rain: RainField = scene.get_rain()
	var ripples: RippleField = scene.get_ripples()
	var water_mat: ShaderMaterial = scene.get_water_material()
	var ripple_mat: ShaderMaterial = scene.get_ripple_material()

	# ── 无粒子节点 ────────────────────────────────────────────────────
	_check(scene.find_children("*", "GPUParticles2D", true, false).is_empty(),
			"GPUParticles2D found (particles are forbidden)")
	_check(scene.find_children("*", "CPUParticles2D", true, false).is_empty(),
			"CPUParticles2D found (particles are forbidden)")

	# ── 雨丝：数量 / 顶点 / 运动 / 参数 ───────────────────────────────
	_check(rain.get_active_count() == 360, "default rain count != 360: %d" % rain.get_active_count())
	_check(rain.get_vertex_count() == 360 * 4,
			"rain vertex count != 1440: %d" % rain.get_vertex_count())
	_check(rain.get_draw_call_hint() == 1, "rain should be a single mesh batch")
	var before: Dictionary = rain.debug_first_drop()
	scene.simulate_effects(0.2)
	var after: Dictionary = rain.debug_first_drop()
	_check(before["pos"] != after["pos"], "rain drops do not advance")
	_check(rain.debug_drift_per_second() > 0.0, "positive wind should drift drops to the right")
	rain.set_density(120)
	_check(rain.get_active_count() == 120, "density setter did not update count")
	_check(rain.get_vertex_count() == 480, "density vertex count mismatch")
	rain.set_density(360)
	rain.set_length_scale(1.5)
	_check(absf(rain.get_length_scale() - 1.5) < 0.001, "rain length setter failed")
	rain.set_length_scale(1.0)
	rain.set_wind(0.26)

	# ── 低洼场 / 22s 积水 / 75s 渗干 ──────────────────────────────────
	_check(field.get_field_texture() != null, "field texture missing")
	_check(field.get_field_texture().get_width() == 320, "field texture width wrong")
	var f_dry: float = field.water_fraction(0.0)
	var f_mid: float = field.water_fraction(0.5)
	var f_full: float = field.water_fraction(1.0)
	_check(f_dry <= 0.0001, "dry field should have no water, got %.4f" % f_dry)
	_check(f_mid > f_dry, "half-full field not wetter than dry")
	_check(f_full > f_mid, "full field not wetter than half-full")
	_check(f_full > 0.10 and f_full < 0.45,
			"full puddle coverage out of range: %.3f" % f_full)

	scene.set_paused(false)
	scene.set_rain_intensity(1.0)
	scene.set_wet_level(0.0)
	scene.set_fill_speed(1.0)
	scene.simulate_water(11.0)
	_check(absf(scene.get_wet() - 0.5) < 0.02,
			"after 11s at full rain expected ~50%%, got %.3f" % scene.get_wet())
	scene.simulate_water(11.0)
	_check(scene.get_wet() >= 0.999, "after 22s expected full puddles, got %.3f" % scene.get_wet())
	_check(scene.get_state_label() == "满水", "state label should be 满水, got %s" % scene.get_state_label())
	scene.set_fill_speed(2.0)
	scene.set_wet_level(0.0)
	scene.simulate_water(2.0)
	_check(absf(scene.get_wet() - 4.0 / 22.0) < 0.02,
			"fill speed multiplier wrong: %.3f" % scene.get_wet())
	scene.set_fill_speed(1.0)

	# ── 灯柱 1×1 放行规则 ────────────────────────────────────────────
	_check(field.lamp_cells.size() == 2, "expected 2 thin lamp cells")
	_check(field.blocked_cells.size() > 0, "large props should stamp blocked cells")
	var report: Array = field.lamp_rule_report()
	_check(report.size() == 2, "lamp rule report size wrong")
	for r in report:
		_check(r["width"] == 1, "lamp rule must be 1x1")
		_check(r["emits_light"], "lamp rule requires EmitsLight")
		_check(r["permeable"], "lamp cell should allow water")
	for cell in field.lamp_cells:
		_check(not field.is_blocked(cell), "lamp cell must not be blocked: %s" % cell)
	_check(field.percent_covered_by_lamps_at_full() == 2,
			"both 1x1 lamp footprints should be inside puddles at full wet")
	var left_lamp: Vector2 = RainLayout.LAMPS[0]["pos"]
	_check(field.mask_at_world(left_lamp, 1.0) > 0.5,
			"left lamp footprint is not in the puddle at full wet")
	_check(field.mask_at_world(left_lamp, 0.0) < 0.01,
			"left lamp footprint should be dry at wet 0")

	# ── 涟漪：72 池 / 双环 / 生命周期 / 雨强频率 ─────────────────────
	_check(ripples.get_pool_size() == 72, "ripple pool must be 72")
	_check(ripples.get_draw_call_hint() == 1, "ripples should be one MultiMesh batch")
	var ring: Image = PixelArt.build_ring()
	var radii: Dictionary = {}
	for y in ring.get_height():
		for x in ring.get_width():
			if ring.get_pixel(x, y).a > 0.0:
				var d := Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length()
				radii[roundi(d)] = true
	_check(radii.size() >= 2, "ring texture is not double-ring: %s" % str(radii.keys()))
	scene.set_wet_level(1.0)
	scene.set_rain_intensity(0.9)
	ripples.reset()
	scene.simulate_effects(2.5)
	var active: int = ripples.get_active_count()
	_check(active > 30, "ripple spawn too sparse at 0.9 rain: %d" % active)
	var life: Vector2 = ripples.get_life_span()
	_check(life.x >= 1.0 and life.y <= 2.15 and life.x < life.y,
			"ripple lifetime range odd: %s" % str(life))
	_check(ripples.get_phase_spread() > 0.25,
			"ripple phases are not spread: %.2f" % ripples.get_phase_spread())
	scene.set_rain_intensity(0.0)
	scene.simulate_effects(3.2)
	_check(ripples.get_active_count() == 0,
			"ripples should expire after rain stops, got %d" % ripples.get_active_count())
	scene.set_ripples_enabled(false)
	_check(not ripples.visible, "ripple layer should hide when disabled")
	scene.set_rain_intensity(1.0)
	scene.simulate_effects(1.0)
	_check(ripples.get_active_count() == 0, "disabled ripples still spawned")
	scene.set_ripples_enabled(true)
	scene.simulate_effects(1.2)
	_check(ripples.get_active_count() > 0, "ripples did not resume after re-enable")
	# 雨强 → 涟漪频率：0.3 的稳定数量应明显少于 0.9。
	ripples.reset()
	scene.set_rain_intensity(0.3)
	scene.simulate_effects(3.0)
	var low_count: int = ripples.get_active_count()
	ripples.reset()
	scene.set_rain_intensity(0.9)
	scene.simulate_effects(3.0)
	var high_count: int = ripples.get_active_count()
	_check(low_count > 0 and high_count > low_count * 1.5,
			"ripple frequency does not scale with rain (%d vs %d)" % [low_count, high_count])

	# ── 倒影：开关 / 图集内容 / 统一裁切 ─────────────────────────────
	_check(water_mat.get_shader_parameter("u_reflection") != null,
			"reflection atlas not bound")
	var refl_tex: Texture2D = water_mat.get_shader_parameter("u_reflection")
	var refl_img := refl_tex.get_image()
	var refl_px := 0
	var data := refl_img.get_data()
	for i in range(0, data.size(), 16):
		if data[i + 3] > 0:
			refl_px += 1
	_check(refl_px > 200, "reflection atlas looks empty (%d sampled pixels)" % refl_px)
	scene.set_reflection_enabled(false)
	_check(float(water_mat.get_shader_parameter("u_reflection_on")) < 0.01,
			"reflection off uniform not applied")
	scene.set_reflection_enabled(true)
	_check(float(water_mat.get_shader_parameter("u_reflection_on")) > 0.99,
			"reflection on uniform not applied")
	_check(field.mask_at_world(RainLayout.MAPLE["pos"] + Vector2(0, 52), 1.0) > 0.5,
			"maple reflection area is not inside a puddle")
	_check(water_mat.shader.code.contains("rp_water_mask"),
			"water shader does not use the shared puddle mask")
	_check(ripple_mat.shader.code.contains("rp_water_mask"),
			"ripple shader does not use the shared puddle mask")

	# ── 渗干 / 暂停 / 状态文案 ───────────────────────────────────────
	scene.set_rain_intensity(0.0)
	scene.set_drain_speed(2.0)
	scene.set_wet_level(1.0)
	scene.simulate_water(2.0)
	_check(absf(scene.get_wet() - (1.0 - 4.0 / 75.0)) < 0.01,
			"drain speed multiplier wrong: %.3f" % scene.get_wet())
	scene.set_drain_speed(1.0)
	scene.set_wet_level(1.0)
	scene.simulate_water(75.0)
	_check(scene.get_wet() <= 0.001, "after 75s of dry weather expected empty, got %.3f" % scene.get_wet())
	scene.set_wet_level(0.5)
	_check(scene.get_state_label() == "渗干中",
			"state label should be 渗干中, got %s" % scene.get_state_label())
	scene.set_rain_intensity(0.8)
	_check(scene.get_state_label() == "积水中",
			"state label should be 积水中, got %s" % scene.get_state_label())
	scene.set_wet_level(0.0)
	_check(scene.get_state_label() == "干燥",
			"state label should be 干燥, got %s" % scene.get_state_label())
	scene.set_wet_level(0.2)
	scene.set_paused(true)
	var wet_before: float = scene.get_wet()
	await create_timer(0.2).timeout
	_check(absf(scene.get_wet() - wet_before) < 0.0001, "paused scene still filled puddles")
	scene.set_paused(false)

	# ── 调试网格 / 重置 ──────────────────────────────────────────────
	scene.set_debug_grid(true)
	_check(scene.is_debug_grid(), "debug grid flag not set")
	var grid_node: Node = scene.get_node("WorldViewport/World").get_node_or_null("DebugGrid")
	_check(grid_node != null and grid_node.visible, "debug grid node not visible")
	scene.set_wet_level(1.0)
	scene.set_reflection_enabled(false)
	scene.set_ripples_enabled(false)
	scene.set_paused(true)
	scene.reset()
	await process_frame
	var params: Dictionary = scene.get_params()
	_check(absf(scene.get_wet()) < 0.0001, "reset did not clear water")
	_check(not scene.is_paused(), "reset did not unpause")
	_check(absf(float(params["rain"]) - 0.85) < 0.001, "reset rain intensity wrong")
	_check(int(params["density"]) == 360, "reset density wrong")
	_check(absf(float(params["wind"]) - 0.26) < 0.001, "reset wind wrong")
	_check(bool(params["ripples"]) and bool(params["reflection"]), "reset toggles wrong")
	_check(not bool(params["debug"]), "reset debug grid wrong")
	_check(scene.get_ripple_count() == 0, "reset left ripples alive")

	# ── HUD / 查询接口 ───────────────────────────────────────────────
	var labels: Array = scene.find_children("*", "Label", true, false)
	var chinese := 0
	for l in labels:
		if l.text.contains("雨") or l.text.contains("水") or l.text.contains("涟漪"):
			chinese += 1
	_check(chinese >= 3, "Chinese HUD labels missing (%d)" % chinese)
	_check(scene.get_draw_calls() >= 0, "draw-call query failed")
	_check(scene.get_fps() >= 0, "fps query failed")
	_check(scene.get_rain().get_active_count() == 360, "rain count not restored after reset")
	# HUD 滑杆接线：改变 UI 值应写回主控。
	var hud = scene.get_node("HUD")
	var rain_slider: HSlider = hud._sliders["rain"]
	rain_slider.value = 0.40
	_check(absf(scene.rain_intensity - 0.40) < 0.001, "HUD rain slider is not wired")
	hud.sync_from_main()

	if _fails.is_empty():
		print("RAIN_PUDDLES_SMOKE_OK checks=%d" % _checks)
		quit(0)
	else:
		for f in _fails:
			printerr("RAIN PUDDLES SMOKE FAIL: ", f)
		quit(1)


func _check(cond: bool, message: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(message)
