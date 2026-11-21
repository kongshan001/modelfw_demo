extends SceneTree

const BattleCoreScript = preload("res://scripts/battle_core.gd")

# 真实 GPU 截图（1920×1080，SubViewport 离屏渲染）：
# 棋盘 / 手牌悬停与法术目标 / 攻击 / 法术特效 / 胜负 /
# AI 回合状态 / 单位高亮 / 召唤高亮 / 1280 原生悬停与高亮 / 法力不足。
# 用法：godot --path godot-card-tactics -s tools/screenshot_card_tactics.gd

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)

var _vp: SubViewport
var _scene


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = _make_viewport(SIZE)
	_scene = _spawn_scene()
	await _settle()
	await create_timer(0.8).timeout
	print("SHOT viewport=", _vp.size, " scene=", _scene.size, " scale=", _scene.scale)

	var uids: Dictionary = _scene.demo_showcase()
	await create_timer(0.9).timeout
	_scene.demo_hover_tile(Vector2i(4, 2))
	await _settle()
	await _shot("01_board")

	# 手牌扇形 + 悬停放大 + 凤火的可选目标（蓝虚圈）。
	_scene.demo_select_hand(2)
	_scene.demo_hover_card(2, true)
	await create_timer(0.35).timeout
	await _shot("02_hand")

	# 近战攻击：白银侍从 vs 猛虎刺客，捕捉白热闪光与伤害数字。
	uids = _scene.demo_showcase()
	await create_timer(0.85).timeout
	_scene.demo_select_unit(int(uids["f1_silverguardsquire"]))
	await create_timer(0.2).timeout
	_scene.demo_attack(int(uids["f1_silverguardsquire"]), int(uids["f2_onyxjaguar"]))
	await create_timer(0.10).timeout
	await _shot("03_attack")

	# 法术：凤火打敌方将军（0.55s 抓峰值火焰）。
	uids = _scene.demo_showcase()
	await create_timer(0.85).timeout
	_scene.demo_select_hand(2)
	await create_timer(0.2).timeout
	var ai_general: Dictionary = _scene.get_core().general_unit(BattleCoreScript.AI)
	_scene.demo_cast(BattleCoreScript.PLAYER, 2, int(ai_general["uid"]))
	await create_timer(0.55).timeout
	await _shot("04_spell")

	# 胜负覆盖层 + 重开按钮（顶栏状态隐藏）。
	uids = _scene.demo_showcase()
	await create_timer(0.8).timeout
	_scene.demo_win(BattleCoreScript.PLAYER)
	await create_timer(1.0).timeout
	await _shot("05_win")

	# AI 回合：顶栏“对手回合”、状态行、手牌降亮、结束回合禁用。
	uids = _scene.demo_showcase()
	await create_timer(0.7).timeout
	_scene.demo_end_turn()
	await create_timer(0.30).timeout
	await _shot("06_ai_turn")
	await _wait_ai_idle()

	# 单位选中：白环选中 + 青框移动 + 红环攻击。
	uids = _scene.demo_showcase()
	await create_timer(0.7).timeout
	_scene.demo_select_unit(int(uids["f1_sunstonetemplar"]))
	await create_timer(0.25).timeout
	await _shot("07_highlight_unit")

	# 手牌选中：金圈召唤位。
	uids = _scene.demo_showcase()
	await create_timer(0.7).timeout
	_scene.demo_select_hand(0)
	await create_timer(0.25).timeout
	await _shot("08_summon_highlight")

	# 1280×720 原生渲染：检查卡面字号/内衬与高亮在目标设计尺寸下的表现。
	await _switch_viewport(Vector2i(1280, 720))
	uids = _scene.demo_showcase()
	await create_timer(0.7).timeout
	_scene.demo_select_hand(2)
	_scene.demo_hover_card(2, true)
	await create_timer(0.35).timeout
	await _shot("09_native_hover_1280")

	uids = _scene.demo_showcase()
	await create_timer(0.7).timeout
	_scene.demo_select_unit(int(uids["f1_sunstonetemplar"]))
	await create_timer(0.25).timeout
	await _shot("10_native_highlight_1280")

	# 不可出牌状态：法力降到 1，只有 1 费卡费用徽章保持蓝色，其余转红并降亮。
	uids = _scene.demo_showcase()
	await create_timer(0.6).timeout
	_scene.get_core().mana[BattleCoreScript.PLAYER] = 1
	_scene.get_core().log_line("—— 法力 1 / 9 ——")
	_scene.refresh_all()
	_scene.demo_select_hand(0)
	await create_timer(0.2).timeout
	await _shot("11_unaffordable_1280")

	print("CARD_TACTICS_SHOTS_OK")
	quit(0)


func _make_viewport(view_size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = view_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(vp)
	return vp


func _spawn_scene():
	var scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(scene)
	return scene


func _switch_viewport(view_size: Vector2i) -> void:
	_vp.queue_free()
	await process_frame
	await process_frame
	_vp = _make_viewport(view_size)
	_scene = _spawn_scene()
	await _settle()
	await create_timer(0.8).timeout
	print("SHOT viewport=", _vp.size, " scene=", _scene.size, " scale=", _scene.scale)


func _wait_ai_idle() -> void:
	var waited := 0.0
	while waited < 15.0 and _scene.is_ai_turn_active():
		await create_timer(0.15).timeout
		waited += 0.15


func _settle() -> void:
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path, " ", image.get_width(), "x", image.get_height())
