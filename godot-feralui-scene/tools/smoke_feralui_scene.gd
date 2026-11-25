extends SceneTree
## Headless 冒烟：工程设置、程序化世界、微动画参数、4 个轻交互、昼夜/天气/画质、
## 暂停/重置、HUD 与释放泄漏。末行 FERALUI_SCENE_SMOKE_OK。
## 用法：godot --path godot-feralui-scene --headless -s tools/smoke_feralui_scene.gd

var checks := 0
var failures: Array[String] = []
var main
var weak_main: WeakRef
var weak_world: WeakRef


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(24)
	print("— 工程 / 场景 / HUD —")
	_test_scene()
	print("— 程序化资产与微动画节点 —")
	_test_world()
	print("— 微动画时钟 / 水 / 树冠 / 锦鲤 —")
	_test_micro_animation()
	print("— 交互：灯 / 风铃 / 苔猫 —")
	await _test_interactions()
	print("— 昼夜 / 天气 —")
	await _test_phase_weather()
	print("— 画质档 —")
	_test_quality()
	print("— 暂停 / 重置 —")
	await _test_pause_and_reset()
	print("— HUD 切换 —")
	_test_hud()
	print("— 节点释放 —")
	await _test_cleanup()
	print("checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty():
		print("FERALUI_SCENE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL " + failure)
		print("FERALUI_SCENE_SMOKE_FAIL")
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS  " + message)
	else:
		failures.append(message)
		printerr("FAIL  " + message)


func _wait(frames: int) -> void:
	for _i in range(frames):
		await process_frame


func _test_scene() -> void:
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility",
			"渲染器 = GL Compatibility")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1280 \
			and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 720,
			"逻辑视口 1280×720")
	_check(main != null, "主场景可加载")
	_check(main.world != null, "World 已构建")
	_check(main.atmosphere != null and main.atmosphere.env != null, "Atmosphere / Environment 存在")
	_check(main.rig != null and main.rig.camera != null and main.rig.camera.current, "环绕相机 current")
	_check(main.interaction != null and main.interaction.targets.size() == 4, "交互管理器收集 4 个小物")
	_check(main.hud != null and main.hud.title_label.text.length() > 0, "HUD 标题已构建")
	_check(main.hud.phase_button != null and main.hud.weather_button != null
			and main.hud.quality_button != null and main.hud.pause_button != null, "HUD 四枚药丸按钮")
	_check(main.hud.fps_label != null, "HUD 有 FPS 标签")
	_check(main.hud.hint_label.text.contains("环绕") and main.hud.detail_label.text.contains("轻触"),
			"HUD 操作提示存在")
	_check(main.post != null and main.post.material != null and main.post.material.shader != null,
			"屏幕校色材质已挂载")
	_check(main.audio != null and main.audio.get_child_count() >= 3, "程序化音效 3 个播放器")


func _test_world() -> void:
	var w = main.world
	_check(w.ground != null and w.ground.material_override is ShaderMaterial,
			"程序化苔地 Mesh + ground shader")
	_check(w.side_mesh != null and w.path_mesh != null and w.water_mesh != null,
			"岛体 / 砂径 / 池水 Mesh 存在")
	_check(w.water_material != null and w.water_material.shader != null,
			"池水 ShaderMaterial 已加载")
	_check(w.grass_multimesh != null and w.grass_multimesh.multimesh.instance_count >= 2000,
			"草 MultiMesh 实例 ≥2000（实际 %d）" % [w.grass_multimesh.multimesh.instance_count])
	_check(w.grass_multimesh.multimesh.mesh != null, "草 MultiMesh 绑定了网格")
	_check(w.daisy_placed >= 150 and w.lavender_placed >= 100,
			"白花 / 薰衣草实例（%d / %d）" % [w.daisy_placed, w.lavender_placed])
	_check(w.bush_multimesh != null and w.bush_multimesh.multimesh.instance_count >= 20,
			"灌木 MultiMesh 存在")
	_check(w.canopy_pivots.size() >= 12, "月树/背景树共 %d 组可摇曳树冠" % [w.canopy_pivots.size()])
	_check(w.koi_data.size() == 2, "2 条程序化锦鲤")
	_check(w.fireflies != null and w.fireflies.amount >= 80, "萤火粒子存在且 ≥80")
	_check(w.pollen != null and w.falling_petals != null and w.rain != null,
			"浮尘 / 落花 / 雨粒子节点存在")
	_check(w.interactables.size() == 4, "4 个可交互小物")
	var ids: Array[String] = []
	for target in w.interactables:
		ids.append(target.get_display_id())
	for required in ["lantern_path", "lantern_water", "wind_chime", "moss_cat"]:
		_check(ids.has(required), "交互 id 存在：" + required)
	_check(w.water_material.get_shader_parameter("u_time") != null, "水面有可控 time 参数")
	_check(w.canopy_material.get_shader_parameter("u_time") != null, "树冠风摆有 time 参数")
	_check(w.grass_material.get_shader_parameter("sway") != null, "草叶风摆有 sway 参数")


func _test_micro_animation() -> void:
	var w = main.world
	var t0: float = w.anim_time
	var water0: float = float(w.water_material.get_shader_parameter("u_time"))
	var canopy0: Vector3 = w.canopy_pivots[0]["pivot"].rotation
	var fish0: Vector3 = w.koi_data[0]["root"].position
	w.tick(0.75, 1.0, 0.0, true)
	_check(w.anim_time > t0, "动画时钟推进")
	_check(float(w.water_material.get_shader_parameter("u_time")) > water0, "水面 time uniform 随动画推进")
	_check(w.canopy_pivots[0]["pivot"].rotation != canopy0, "树冠产生摇曳旋转")
	_check(w.koi_data[0]["root"].position != fish0, "锦鲤沿池内路径游动")
	_check(w.fireflies.emitting and w.fireflies.amount_ratio > 0.5, "夜间萤火在发射")
	_check(w.flower_material.get_shader_parameter("glow_strength") != null, "花朵微光参数存在")
	# 微动画后恢复到一个明确状态，便于后续交互测试。
	w.tick(0.0, 1.0, 0.0, true)


func _test_interactions() -> void:
	var lantern = _target("lantern_path")
	var chime = _target("wind_chime")
	var cat = _target("moss_cat")
	_check(lantern != null and chime != null and cat != null, "灯具/风铃/苔猫均可寻址")
	var lit_before: bool = lantern.lit
	_check(main.demo_interact("lantern_path"), "苔灯可被轻触")
	_check(lantern.lit != lit_before, "苔灯交互切换点亮状态")
	_check(main.demo_interact("lantern_path"), "苔灯再次轻触")
	_check(lantern.lit == lit_before, "苔灯回到原状态")
	var struck: int = chime.struck_count
	_check(main.demo_interact("wind_chime"), "风铃可被轻触")
	_check(chime.struck_count == struck + 1, "风铃碰撞计数 +1")
	_check(chime.impulse > 0.0 and chime.sparks.emitting, "风铃摇动并产生星屑")
	var pets: int = cat.pet_count
	_check(main.demo_interact("moss_cat"), "苔猫可被轻触")
	_check(cat.pet_count == pets + 1 and cat.joy > 0.0, "苔猫抬头/摆尾 joy 生效")
	_check(main.hud.toast_label.text.length() > 0, "交互反馈 toast 已显示")
	# 强制悬停：投影标记与 HUD 标签。
	main.interaction.set_forced_hover("moss_cat")
	await _wait(3)
	_check(main.interaction.last_markers.size() == 4, "4 个交互投影标记")
	var hovered_found := false
	for marker in main.interaction.last_markers:
		if bool(marker.get("hovered", false)):
			hovered_found = true
	_check(hovered_found, "苔猫标记处于悬停高亮")
	_check(cat.focused, "苔猫被设为 focused")
	main.demo_clear_focus()


func _test_phase_weather() -> void:
	main.demo_reset()
	await _wait(2)
	_check(main.night_mode and main.atmosphere.nightness == 1.0, "默认月夜")
	main.demo_set_phase(false, true)
	_check(not main.night_mode and main.atmosphere.nightness == 0.0, "切到昼：nightness=0")
	_check(float(main.atmosphere.sky_material.get_shader_parameter("nightness")) == 0.0,
			"天空 shader 接收昼间参数")
	main.world.tick(0.0, main.atmosphere.nightness, main.atmosphere.rain_amount, true)
	_check(not main.world.fireflies.emitting, "昼间萤火停发")
	main.demo_set_phase(true, true)
	main.world.tick(0.0, 1.0, 0.0, true)
	_check(main.world.fireflies.emitting, "切回夜间萤火复燃")

	main.demo_set_weather(true, true)
	_check(main.rain_mode and is_equal_approx(main.atmosphere.rain_amount, 1.0), "天气 = 雨")
	_check(main.world.rain.visible and main.world.rain.emitting, "雨粒子已显示并发射")
	_check(is_equal_approx(float(main.world.water_material.get_shader_parameter("rain_amount")), 1.0),
			"水面 shader 接收 rain_amount")
	_check(main.hud.weather_button.text.contains("雨"), "HUD 天气按钮显示雨")
	main.demo_set_weather(false, true)
	_check(not main.rain_mode and not main.world.rain.visible, "天气回到晴")
	main.demo_set_phase(true, true)


func _test_quality() -> void:
	main.demo_set_quality(false)
	var grass_now: int = main.world.grass_multimesh.multimesh.visible_instance_count
	_check(grass_now < main.world.grass_placed, "低画质减少草实例（%d < %d）" % [grass_now, main.world.grass_placed])
	_check(main.world.canopy_pivots[0]["mesh"].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"低画质关闭树冠投影")
	_check(main.hud.quality_button.text.contains("低"), "HUD 画质按钮显示低")
	main.demo_set_quality(true)
	_check(main.world.grass_multimesh.multimesh.visible_instance_count == main.world.grass_placed,
			"高画质恢复全部草实例")
	_check(main.world.canopy_pivots[0]["mesh"].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
			"高画质恢复树冠投影")


func _test_pause_and_reset() -> void:
	main.demo_set_phase(false, true)
	main.demo_set_weather(true, true)
	main.demo_set_quality(false)
	main.demo_set_paused(true)
	_check(main.paused and paused, "暂停：主控与 SceneTree 均暂停")
	_check(main.hud.pause_badge.visible and main.hud.pause_button.text.contains("继续"),
			"暂停徽标与按钮状态")
	var t_pause: float = main.world.anim_time
	await _wait(5)
	_check(is_equal_approx(main.world.anim_time, t_pause), "暂停期间世界时钟冻结")
	main.demo_set_paused(false)
	_check(not main.paused and not paused, "继续：恢复运行")
	var t_resume: float = main.world.anim_time
	await _wait(4)
	_check(main.world.anim_time > t_resume, "继续后世界时钟推进")

	main.demo_interact("moss_cat")
	main.demo_interact("wind_chime")
	main.demo_reset()
	await _wait(2)
	_check(main.night_mode and not main.rain_mode and main.quality_high, "重置回默认夜/晴/高")
	_check(not main.paused and not paused, "重置解除暂停")
	_check(absf(main.rig.yaw_deg - main.rig.DEFAULT_YAW) < 1.0, "重置相机 yaw")
	_check(_target("lantern_path").lit, "重置苔灯为亮")
	_check(_target("moss_cat").pet_count == 0 and _target("wind_chime").struck_count == 0,
			"重置交互状态")
	_check(main.world.anim_time < 0.2, "重置动画时钟归零")
	_check(main.hud.pause_badge.visible == false, "重置隐藏暂停徽标")
	_check(main.hud_visible, "重置恢复 HUD")


func _test_hud() -> void:
	main.demo_set_hud_visible(false)
	_check(main.hud.hidden, "HUD 隐藏生效")
	main.demo_set_hud_visible(true)
	_check(not main.hud.hidden, "HUD 显示恢复")
	main.demo_apply_ui_scale()
	_check(main.hud.scale.x > 0.5, "HUD 视口缩放已应用")
	main.get_state()
	main.get_target_info()


func _test_cleanup() -> void:
	weak_main = weakref(main)
	weak_world = weakref(main.world)
	main.queue_free()
	await _wait(8)
	_check(weak_main.get_ref() == null, "主场景 queue_free 后释放")
	_check(weak_world.get_ref() == null, "世界与粒子/交互节点随场景释放")
	main = null


func _target(id: String):
	for target in main.world.get_interaction_targets():
		if target.get_display_id() == id:
			return target
	return null
