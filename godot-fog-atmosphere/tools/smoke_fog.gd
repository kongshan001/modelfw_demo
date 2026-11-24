extends SceneTree
## Headless 冒烟：场景加载、程序化资产、环境雾/天空/光照、雾片/粒子/光束预算、
## 质量档、昼夜、雾参数、风、相机重置、粒子清理与节点泄漏。
## 用法：godot --path . --headless -s tools/smoke_fog.gd
## 末行：FOG_SMOKE_OK

var checks := 0
var failures: Array[String] = []
var main
var weak_main: WeakRef
var weak_fog: WeakRef


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(12)
	print("— 场景与程序化资产 —")
	_test_scene()
	print("— 环境雾 / 天空 / 光照 —")
	_test_atmosphere()
	print("— 雾片 / 粒子 / 光束 —")
	_test_fog_layers()
	print("— 质量档与预算 —")
	_test_quality()
	print("— 昼夜 / 雾参数 / 风 / 相机 —")
	_test_controls()
	print("— 粒子清理与泄漏 —")
	await _test_cleanup()
	print("checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty():
		print("FOG_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL " + failure)
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
	_check(main.world != null, "世界构建器存在")
	_check(main.world.get_node_or_null("Ground") != null, "地形 MeshInstance3D 已生成")
	_check(main.world.ground_material != null and main.world.ground_material.albedo_texture != null, "地面材质与细节噪声贴图存在")
	_check(main.world.water_material != null and main.world.water_material.shader != null, "水面 ShaderMaterial 与 water.gdshader 已加载")
	_check(main.world.grass_material != null and main.world.grass_material.shader != null, "草叶 ShaderMaterial 与 grass.gdshader 已加载")
	_check(main.world.grass_multimesh != null and main.world.grass_multimesh.multimesh.instance_count >= 1000, "草叶 MultiMesh 实例数 ≥1000")
	_check(main.world.lantern_orb_positions.size() == 3, "3 座石灯笼（含 ray 锚点）")
	_check(main.world.wisp_node != null and main.world.wisp_material != null, "雾精灵与自发光材质存在")
	_check(main.rig != null and main.rig.camera != null and main.rig.camera.current, "环绕相机已 current")
	_check(main.hud != null and main.hud.title_label.text.length() > 0, "HUD 标题已构建")
	_check(main.post != null and main.post.material != null and main.post.material.shader != null, "屏幕后处理 shader 存在")


func _test_atmosphere() -> void:
	var env: Environment = main.atmosphere.env
	_check(env != null and env.fog_enabled, "WorldEnvironment 雾已启用")
	_check(env.fog_mode == Environment.FOG_MODE_EXPONENTIAL, "雾模式 = 指数雾（深度雾）")
	_check(env.fog_height > 0.0 and env.fog_height_density > 0.0, "高度雾参数 > 0（fog_height=%.2f, density=%.3f）" % [env.fog_height, env.fog_height_density])
	_check(env.fog_light_color.r > 0.5, "雾色为明亮晨雾色")
	_check(env.glow_enabled, "高质量下 Glow 开启")
	_check(env.sky != null and main.atmosphere.sky_material.shader != null, "自定义天空 shader 已挂载")
	_check(main.atmosphere.sun != null and main.atmosphere.sun.shadow_enabled, "太阳/月光 DirectionalLight3D 与阴影开启")
	_check(main.atmosphere.fog_state()["nightness"] == 0.0, "初始为白天（nightness=0）")


func _test_fog_layers() -> void:
	_check(main.fog.puff_multimesh != null and main.fog.puff_multimesh.multimesh.instance_count == 20, "雾片 MultiMesh=20 实例")
	_check(main.fog.puff_material != null and main.fog.puff_material.albedo_texture != null, "雾片使用程序化噪声贴图")
	_check(main.fog.layer_nodes.size() == 2, "2 层水平贴地雾层")
	_check(main.fog.beam_nodes.size() == 4, "4 组伪光束（交叉面片）")
	var beams_ok := true
	for mat in main.fog.beam_materials:
		if mat.shader == null or float(mat.get_shader_parameter("intensity")) <= 0.0:
			beams_ok = false
	_check(beams_ok, "光束材质/强度有效")
	_check(main.fog.pollen != null and main.fog.fireflies != null and main.fog.leaves != null, "浮尘 / 流萤 / 落叶 3 组粒子")
	_check(main.fog.pollen.amount == 190 and main.fog.fireflies.amount == 34 and main.fog.leaves.amount == 24, "高质量粒子预算 190/34/24")
	var counts: Dictionary = main.demo_get_counts()
	_check(int(counts["puffs"]) == 20 and int(counts["beams"]) == 4 and int(counts["particles"]) == 248, "HUD 预算统计一致（20/248/4）")


func _test_quality() -> void:
	var node_before: int = main.fog.get_child_count()
	main.demo_set_quality(false)
	_check(main.fog.get_counts()["puffs"] == 9, "低质量雾片降到 9")
	_check(main.fog.get_counts()["layers"] == 1, "低质量水平雾层降到 1")
	_check(main.fog.get_counts()["beams"] == 2, "低质量光束降到 2")
	_check(main.fog.get_counts()["particles"] == 104, "低质量粒子降到 104")
	_check(main.atmosphere.env.glow_enabled, "低质量保留 Glow（观感优先）")
	_check(main.atmosphere.sun.shadow_enabled == false, "低质量关闭阴影")
	_check(main.post.material.get_shader_parameter("ray_strength") == 0.0, "低质量关闭屏幕 god rays")
	_check(main.world.grass_multimesh.multimesh.visible_instance_count == int(main.world.grass_placed * 0.45), "低质量草叶实例降至 45%")
	main.demo_set_quality(true)
	_check(main.fog.get_counts()["puffs"] == 20 and main.atmosphere.sun.shadow_enabled, "切回高质量恢复预算/阴影")
	_check(main.fog.get_child_count() == node_before, "质量档反复切换未新增节点（无泄漏）")


func _test_controls() -> void:
	# 昼夜
	var day_energy: float = main.atmosphere.sun.light_energy
	var day_beam: float = main.fog.beam_materials[0].get_shader_parameter("intensity")
	main.demo_set_phase(true, true)
	_check(main.atmosphere.nightness == 1.0 and main.atmosphere.fog_state()["night"], "N 切换：瞬时入夜")
	_check(main.atmosphere.sun.light_energy < day_energy, "夜间阳光能量下降")
	_check(float(main.atmosphere.sky_material.get_shader_parameter("moon_amount")) == 1.0, "夜空中 moon_amount=1")
	_check(float(main.atmosphere.sky_material.get_shader_parameter("star_amount")) > 0.5, "星空已开启")
	_check(float(main.fog.beam_materials[0].get_shader_parameter("intensity")) > day_beam, "夜间光束增强")
	_check(main.world.lantern_orb_material.albedo_color.r > 2.0, "夜间灯笼更亮")
	main.demo_set_phase(false, true)
	_check(main.atmosphere.nightness == 0.0, "切回白天")

	# 雾浓度 / 高度 / 颜色
	var d_before: float = main.atmosphere.env.fog_density
	main.demo_set_fog(3, 3)
	_check(main.atmosphere.env.fog_density > d_before, "雾浓度档提高 → fog_density 增大")
	_check(is_equal_approx(main.atmosphere.env.fog_height, 3.6), "雾层高度档 4 → fog_height=3.6")
	_check(main.fog.fog_level_index == 3, "雾片层同步接收浓度档")
	var color_before: String = main.demo_get_fog_state()["fog_color_name"]
	main.demo_cycle_fog_color()
	_check(main.demo_get_fog_state()["fog_color_name"] != color_before, "C 键循环雾色生效")
	main.demo_set_fog(1, 1)
	main.demo_set_fog_color(0)

	# 风
	main.demo_set_wind_level(3)
	_check(is_equal_approx(main.fog.wind_speed, 2.2), "风档 4 → wind_speed=2.2")
	_check(float(main.world.grass_material.get_shader_parameter("wind_speed")) > 2.0, "风写入草叶 shader")
	_check(main.fog.leaves.speed_scale > 1.3, "风影响落叶粒子速度")
	main.demo_set_wind_level(2)

	# 相机
	main.demo_set_view(123.0, 44.0, 19.0, Vector3(4, 2, 4))
	_check(int(main.rig.yaw_deg) == 123 and int(main.rig.pitch_deg) == 44 and is_equal_approx(main.rig.distance, 19.0), "demo 相机视角设置生效")
	main.demo_reset()
	_check(int(main.rig.yaw_deg) == 26 and int(main.rig.pitch_deg) == 36 and is_equal_approx(main.rig.distance, 15.5), "R 重置相机到默认视角")
	_check(main.fog.wind_speed == 1.4 and main.atmosphere.fog_level == 1 and main.atmosphere.fog_color_index == 0, "R 重置雾/风/雾色")

	# HUD 隐藏/显示
	main.demo_set_hud_visible(false)
	_check(main.hud.hidden, "Tab/HUD 隐藏生效")
	main.demo_set_hud_visible(true)
	_check(not main.hud.hidden, "HUD 恢复显示")


func _test_cleanup() -> void:
	weak_main = weakref(main)
	weak_fog = weakref(main.fog)
	for i in range(3):
		main.demo_set_quality(false)
		main.demo_set_quality(true)
	_check(main.fog.pollen.emitting, "粒子发射中（切换质量后仍运行）")
	main.queue_free()
	await _wait(6)
	_check(weak_main.get_ref() == null, "整场景 queue_free 后主节点已释放")
	_check(weak_fog.get_ref() == null, "雾系统与粒子节点随场景释放（无节点泄漏）")
