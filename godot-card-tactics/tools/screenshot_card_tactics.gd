extends SceneTree

const BattleCoreScript = preload("res://scripts/battle_core.gd")

# 真实 GPU 截图（1920×1080，SubViewport 离屏渲染）：
# 棋盘 / 手牌悬停与法术目标 / 攻击 / 法术特效 / 胜负。
# 用法：godot --path godot-card-tactics -s tools/screenshot_card_tactics.gd

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)

var _vp: SubViewport
var _scene


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await _settle()
	await create_timer(0.8).timeout
	print("SHOT viewport=", _vp.size, " scene=", _scene.size, " scale=", _scene.scale)

	var uids: Dictionary = _scene.demo_showcase()
	await create_timer(0.9).timeout
	_scene.demo_hover_tile(Vector2i(4, 2))
	await _settle()
	await _shot("01_board")

	# 手牌扇形 + 悬停放大 + 凤火的可选目标（蓝圈）。
	_scene.demo_select_hand(2)
	_scene.demo_hover_card(2, true)
	await create_timer(0.35).timeout
	await _shot("02_hand")

	# 近战攻击：白银侍从 vs 猛虎刺客，捕捉挥击/伤害数字。
	uids = _scene.demo_showcase()
	await create_timer(0.85).timeout
	_scene.demo_select_unit(int(uids["f1_silverguardsquire"]))
	await create_timer(0.2).timeout
	_scene.demo_attack(int(uids["f1_silverguardsquire"]), int(uids["f2_onyxjaguar"]))
	await create_timer(0.18).timeout
	await _shot("03_attack")

	# 法术：凤火打敌方将军。
	uids = _scene.demo_showcase()
	await create_timer(0.85).timeout
	_scene.demo_select_hand(2)
	await create_timer(0.2).timeout
	var ai_general: Dictionary = _scene.get_core().general_unit(BattleCoreScript.AI)
	_scene.demo_cast(BattleCoreScript.PLAYER, 2, int(ai_general["uid"]))
	await create_timer(0.8).timeout
	await _shot("04_spell")

	# 胜负覆盖层 + 重开按钮。
	uids = _scene.demo_showcase()
	await create_timer(0.8).timeout
	_scene.demo_win(BattleCoreScript.PLAYER)
	await create_timer(1.0).timeout
	await _shot("05_win")

	print("CARD_TACTICS_SHOTS_OK")
	quit(0)


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
