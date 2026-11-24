extends SceneTree
## Headless 冒烟：第三人称角色加载/移动/动画、跟随与自由相机、动态雾驱散
## （局部雾量、雾片 alpha、雾层 shader、近身雾粒子、雾浪）、停下恢复、
## 半径/强度/恢复速度参数、质量档/昼夜不回归、边界与障碍、F1 调试、释放泄漏。
## 用法：godot --path . --headless -s tools/smoke_fog_interaction.gd
## 末行：FOG_INTERACTION_SMOKE_OK

var checks := 0
var failures: Array[String] = []
var main
var weak_main: WeakRef
var weak_player: WeakRef
var weak_interaction: WeakRef


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(16)
	print("— 角色加载 / 第三人称 —")
	_test_character()
	await _test_camera()
	print("— 移动 / 动画 / 局部清雾 —")
	await _test_movement_and_clear()
	print("— 半径 / 强度参数 —")
	await _test_parameters()
	print("— 停下后的平滑恢复 —")
	await _test_recovery()
	print("— 质量档 / 昼夜不回归 —")
	await _test_quality_and_phase()
	print("— 边界 / 障碍 / 深水 —")
	await _test_boundary()
	print("— F1 调试 / HUD 中文 —")
	await _test_debug_hud()
	print("— 释放与泄漏 —")
	await _test_cleanup()
	print("checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty():
		print("FOG_INTERACTION_SMOKE_OK")
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


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _test_character() -> void:
	_check(main.player != null and main.player is CharacterBody3D, "角色 CharacterBody3D 已创建")
	_check(main.player.uses_model, "KayKit Rogue.glb 已加载（CC0）")
	_check(main.player.animation_player != null, "角色 AnimationPlayer 存在")
	if main.player.animation_player != null:
		_check(main.player.animation_player.has_animation("Idle")
			and main.player.animation_player.has_animation("Walking_A")
			and main.player.animation_player.has_animation("Running_A"), "Idle / Walking_A / Running_A 三段动画可用")
	_check(is_equal_approx(main.player.model_root.scale.x, 0.74), "角色缩放 0.74（约 1.73m）")
	_check(not main.player.fallback_root.visible, "程序化人形作为回退保留且当前隐藏")
	var state: Dictionary = main.demo_get_player_state()
	_check(String(state["animation"]) == "Idle" and float(state["speed"]) < 0.01, "初始 Idle / 静止")
	_check(absf(main.player.global_position.y - main.world.terrain_height(main.player.global_position.x, main.player.global_position.z)) < 0.01, "角色贴地（y = terrain_height）")


func _test_camera() -> void:
	_check(main.view_follow and main.rig.follow_enabled, "默认第三人称跟随相机")
	_check(main.player.controls_enabled, "跟随模式启用角色移动输入")
	_check(main.rig.distance >= 3.5 and main.rig.distance <= 12.0, "跟随距离在 3.5–12m")
	var focus_delta: float = Vector2(main.rig.focus.x - main.player.global_position.x, main.rig.focus.z - main.player.global_position.z).length()
	_check(focus_delta < 2.0, "相机焦点跟随角色")
	main.demo_set_view_mode(false)
	_check(not main.view_follow and not main.rig.follow_enabled, "V 切换：自由相机模式")
	_check(not main.player.controls_enabled, "自由相机模式停用角色移动")
	_check(is_equal_approx(main.rig.distance, 15.5) and int(main.rig.pitch_deg) == 36, "自由相机保留原默认视角（15.5m / 36°）")
	main.demo_set_view(123.0, 44.0, 19.0, Vector3(4, 2, 4))
	_check(int(main.rig.yaw_deg) == 123 and int(main.rig.pitch_deg) == 44 and is_equal_approx(main.rig.distance, 19.0), "demo_set_view 自由相机生效")
	main.demo_set_follow_view(26.0, 20.0, 7.2)
	_check(main.view_follow and main.rig.follow_enabled, "demo_set_follow_view 切回第三人称")
	_check(int(main.rig.pitch_deg) == 20 and is_equal_approx(main.rig.distance, 7.2), "第三人称默认 20° / 7.2m")


func _test_movement_and_clear() -> void:
	main.demo_reset()
	await _wait(4)
	var start: Vector3 = main.player.global_position
	var idle_bank: float = main.demo_get_fog_clear_state()["bank_alpha"]
	var idle_mote: float = main.demo_get_fog_clear_state()["mote_alpha"]
	main.demo_set_player_input(0.0, 1.0, false)
	await _seconds(0.9)
	var mid: Vector3 = main.player.global_position
	var moved: float = Vector2(mid.x - start.x, mid.z - start.z).length()
	var pstate: Dictionary = main.demo_get_player_state()
	var clear: Dictionary = main.demo_get_fog_clear_state()
	_check(moved > 0.6, "WASD 前进移动（%.2fm）" % moved)
	_check(float(pstate["speed"]) > 1.4, "行走速度 > 1.4m/s")
	_check(String(pstate["animation"]) == "Walking_A", "行走切到 Walking_A")
	_check(bool(clear["moving"]) and float(clear["amount"]) > 0.85, "移动时清除量升到 >0.85")
	_check(float(clear["local_factor"]) < 0.25, "玩家处局部雾量 < 25%")
	_check(is_equal_approx(float(clear["far_factor"]), 1.0), "20m 远处雾量保持 100%")
	_check(float(clear["fog_system"]["local_factor"]) < 0.25, "雾系统局部系数与角色控制器一致")
	var near_alpha: float = main.fog.puff_alpha_for_distance(0.5)
	var far_alpha: float = main.fog.farthest_puff_clear_alpha(main.player.global_position)
	_check(near_alpha < 0.25, "雾片近距 alpha 被局部压低（%.2f）" % near_alpha)
	_check(is_equal_approx(main.fog.puff_alpha_for_distance(20.0), 1.0), "雾片 20m 处 alpha 保持 1.00")
	_check(is_equal_approx(far_alpha, 1.0), "最远雾片实例 alpha 保持 1.00")
	var layer: ShaderMaterial = main.fog.layer_materials[0]
	_check(float(layer.get_shader_parameter("clear_amount")) > 0.8, "水平雾层 shader 收到 clear_amount")
	_check(float(layer.get_shader_parameter("clear_radius")) > 0.0 and float(layer.get_shader_parameter("clear_strength")) > 0.0, "水平雾层 shader 收到半径/强度")
	var ppos: Vector3 = layer.get_shader_parameter("player_pos")
	_check(Vector2(ppos.x - main.player.global_position.x, ppos.z - main.player.global_position.z).length() < 0.2, "水平雾层遮罩跟随玩家位置")
	_check(float(clear["bank_alpha"]) < idle_bank * 0.75, "近身雾团被推开/减淡（%.3f → %.3f）" % [idle_bank, float(clear["bank_alpha"])])
	_check(float(clear["mote_alpha"]) < idle_mote * 0.6, "近身雾粒子淡出（%.3f → %.3f）" % [idle_mote, float(clear["mote_alpha"])])
	_check(int(clear["wakes"]) > 0, "移动时生成雾浪/足迹（%d 个活跃）" % int(clear["wakes"]))
	_check(main.fog_interaction.footstep != null and main.fog_interaction.footstep.amount >= 4, "足迹雾粒子系统存在")
	main.demo_set_player_input(1.0, 0.0, true)
	await _seconds(0.8)
	pstate = main.demo_get_player_state()
	_check(float(pstate["speed"]) > 3.5, "Shift 奔跑速度 > 3.5m/s")
	_check(String(pstate["animation"]) == "Running_A", "奔跑切到 Running_A")


func _test_parameters() -> void:
	main.demo_set_player_input(0.0, 1.0, false)
	await _seconds(0.5)
	main.demo_set_fog_clear(2.0, 0.9, 1.0)
	await _seconds(0.35)
	var p: Vector3 = main.player.global_position
	var f_player: float = main.fog.visibility_factor_at(p)
	var f_6m: float = main.fog.visibility_factor_at(p + Vector3(0, 0, 6))
	_check(f_player < 0.15, "半径 2m：玩家处雾量 <15%")
	_check(f_6m > 0.9, "半径 2m：6m 处几乎不受影响（%.2f）" % f_6m)
	main.demo_set_fog_clear(10.0, 0.9, 1.0)
	await _seconds(0.35)
	f_6m = main.fog.visibility_factor_at(p + Vector3(0, 0, 6))
	var f_20m: float = main.fog.visibility_factor_at(p + Vector3(0, 0, 20))
	_check(f_6m < 0.35, "半径 10m：6m 处理雾量 <35%%（%.2f）" % f_6m)
	_check(is_equal_approx(f_20m, 1.0), "半径 10m：20m 处仍不受影响")
	main.demo_set_fog_clear(4.5, 0.0, 1.0)
	await _seconds(0.2)
	_check(absf(main.fog.visibility_factor_at(p) - 0.65) < 0.03, "强度 0：只保留近身柔化（65%）")
	main.demo_set_fog_clear(4.5, 0.85, 1.6)
	main.fog_interaction.set_clear_radius(0.1)
	_check(is_equal_approx(main.fog_interaction.clear_radius, 1.5), "半径下限夹到 1.5m")
	main.fog_interaction.set_clear_radius(999.0)
	_check(is_equal_approx(main.fog_interaction.clear_radius, 10.0), "半径上限夹到 10m")
	main.fog_interaction.set_recovery_time(0.1)
	_check(is_equal_approx(main.fog_interaction.recovery_time, 0.6), "恢复下限夹到 0.6s")
	main.fog_interaction.set_recovery_time(99.0)
	_check(is_equal_approx(main.fog_interaction.recovery_time, 4.0), "恢复上限夹到 4.0s")
	main.demo_set_fog_clear(4.5, 0.85, 1.6)


func _test_recovery() -> void:
	# 保持移动直到清除量满，再停止
	main.demo_set_player_input(0.0, 1.0, false)
	await _seconds(0.5)
	main.demo_clear_player_input()
	await _seconds(0.4)
	var early: Dictionary = main.demo_get_fog_clear_state()
	_check(float(early["amount"]) > 0.7, "停下 0.4s 后雾仍未恢复（清除量 %.2f）" % float(early["amount"]))
	_check(float(early["local_factor"]) < 0.3, "停下 0.4s 玩家处仍较清晰")
	await _seconds(2.2)
	var late: Dictionary = main.demo_get_fog_clear_state()
	_check(float(late["amount"]) < 0.05, "默认 1.6s 恢复：2.6s 后清除量 <5%")
	_check(absf(float(late["local_factor"]) - 0.65) < 0.03, "恢复后局部雾量回到 65%（仅保留柔化）")
	_check(float(late["bank_alpha"]) > 0.12, "近身雾团恢复可见")
	_check(float(late["mote_alpha"]) > 0.15, "近身雾粒子恢复")
	_check(int(late["wakes"]) == 0, "雾浪粒子在恢复窗口后消散")
	_check(not bool(late["moving"]) and String(main.demo_get_player_state()["animation"]) == "Idle", "停下后回到 Idle")


func _test_quality_and_phase() -> void:
	var nodes_before: int = main.get_child_count()
	var fog_nodes_before: int = main.fog.get_child_count()
	main.demo_set_quality(false)
	_check(main.fog.get_counts()["puffs"] == 9 and main.fog.get_counts()["layers"] == 1 and main.fog.get_counts()["beams"] == 2, "低质量雾预算 9/1/2 不回归")
	_check(main.fog.get_counts()["particles"] == 104, "低质量粒子 104 不回归")
	_check(main.fog_interaction.bank_multimesh.multimesh.visible_instance_count == 4, "低质量近身雾团降到 4")
	_check(main.fog_interaction.motes.amount == 22, "低质量近身雾粒子 22")
	_check(main.player.uses_model and main.player.animation_player != null, "低质量下角色与动画仍在")
	main.demo_set_quality(true)
	_check(main.fog.get_counts()["puffs"] == 20 and main.fog.get_counts()["particles"] == 248, "高质量预算恢复 20/248")
	_check(main.fog_interaction.bank_multimesh.multimesh.visible_instance_count == 8 and main.fog_interaction.motes.amount == 44, "高质量近身雾团/粒子恢复 8/44")
	_check(main.get_child_count() == nodes_before and main.fog.get_child_count() == fog_nodes_before, "质量档切换未新增节点")
	var day_beam: float = main.fog.beam_materials[0].get_shader_parameter("intensity")
	main.demo_set_phase(true, true)
	_check(main.atmosphere.nightness == 1.0 and main.atmosphere.fog_state()["night"], "N 夜晚切换不回归")
	_check(float(main.fog.beam_materials[0].get_shader_parameter("intensity")) > day_beam, "夜间光束增强不回归")
	_check(main.player.visible, "夜间角色仍可见")
	main.demo_set_phase(false, true)
	main.demo_set_fog(3, 3)
	_check(is_equal_approx(main.atmosphere.env.fog_density, 0.0085) and is_equal_approx(main.atmosphere.env.fog_height, 3.6), "F/G 雾浓度/高度不回归")
	main.demo_set_fog(1, 1)


func _test_boundary() -> void:
	main.demo_teleport_player(200.0, 200.0)
	await _wait(3)
	var flat := Vector2(main.player.global_position.x, main.player.global_position.z)
	_check(flat.length() <= main.world.walk_boundary_radius() + 0.01, "世界边界把角色夹在 %.0fm 内" % main.world.walk_boundary_radius())
	var pool := Vector2(main.world.pool_center().x, main.world.pool_center().z)
	main.demo_teleport_player(pool.x, pool.y)
	await _wait(3)
	var pool_d := Vector2(main.player.global_position.x, main.player.global_position.z).distance_to(pool)
	_check(pool_d >= main.world.pool_radius() + 0.54, "池岸阻挡：角色留在水外（%.2fm）" % pool_d)
	var obstacle: Dictionary = main.world.obstacle_circles[0]
	var op: Vector2 = obstacle["pos"]
	main.demo_teleport_player(op.x, op.y)
	await _wait(3)
	var obs_d := Vector2(main.player.global_position.x, main.player.global_position.z).distance_to(op)
	_check(obs_d >= float(obstacle["radius"]) + 0.37, "树干/石柱圆形障碍推离（%.2fm）" % obs_d)
	main.demo_teleport_player(1.5, 18.5)
	await _wait(3)


func _test_debug_hud() -> void:
	main.demo_set_clear_debug(true)
	main._refresh_hud()
	await _wait(2)
	_check(main.fog_interaction.debug_visible, "F1 调试开关生效")
	_check(main.fog_interaction.ring_main.visible and main.fog_interaction.ring_falloff.visible, "调试半径/淡出环可见")
	_check(main.hud.debug_label.visible, "HUD 调试行可见")
	_check(main.hud.debug_label.text.contains("半径") and main.hud.debug_label.text.contains("局部雾量"), "调试行含半径/局部雾量（中文）")
	_check(main.hud.state_label.text.contains("雾清除"), "HUD 状态行含雾清除参数")
	_check(main.hud.hint_label.text.contains("F1") and main.hud.hint_label.text.contains("Shift"), "快捷键提示含 F1 / Shift")
	main.demo_set_clear_debug(false)
	main._refresh_hud()
	await _wait(2)
	_check(not main.fog_interaction.ring_main.visible and not main.hud.debug_label.visible, "关闭 F1 后调试环/HUD 调试行隐藏")


func _test_cleanup() -> void:
	weak_main = weakref(main)
	weak_player = weakref(main.player)
	weak_interaction = weakref(main.fog_interaction)
	main.queue_free()
	await _wait(6)
	_check(weak_main.get_ref() == null, "整场景释放")
	_check(weak_player.get_ref() == null, "角色节点随场景释放")
	_check(weak_interaction.get_ref() == null, "雾交互节点随场景释放（无泄漏）")
