extends SceneTree

const BattleCoreScript = preload("res://scripts/battle_core.gd")

# 约 12 秒的演示：展示棋盘 → 召唤 → 走位 → 近战 → 法术 → AI 回合 → 胜利。
# 用法：godot --path godot-card-tactics --resolution 1280x720 --fixed-fps 30 \
#         --write-movie docs/card_tactics.avi -s tools/demo_card_tactics.gd

var _scene


func _initialize() -> void:
	await process_frame
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame

	var uids: Dictionary = _scene.demo_showcase()
	await create_timer(1.4).timeout

	# 铁崖守卫：5 费，召唤到将军上方。
	_scene.demo_summon(0, Vector2i(4, 3))
	await create_timer(1.0).timeout

	# 日石骑士前进一格，贴到敌方将军面前。
	_scene.demo_move(int(uids["f1_sunstonetemplar"]), Vector2i(4, 1))
	await create_timer(0.9).timeout

	# 近战攻击敌方将军。
	var core: BattleCoreScript = _scene.get_core()
	var ai_general: Dictionary = core.general_unit(BattleCoreScript.AI)
	_scene.demo_attack(int(uids["f1_sunstonetemplar"]), int(ai_general["uid"]))
	await create_timer(1.0).timeout

	# 凤火收尾。
	core = _scene.get_core()
	var phoenix_index: int = int(core.hands[BattleCoreScript.PLAYER].find("f2_phoenixfire"))
	if phoenix_index >= 0:
		_scene.demo_cast(BattleCoreScript.PLAYER, phoenix_index, int(ai_general["uid"]))
	await create_timer(1.7).timeout

	# 交出回合，让 AI 行动一段。
	_scene.demo_ai_turn()
	await _scene.ai_turn_finished
	await create_timer(1.0).timeout

	# 演示胜利覆盖层。
	_scene.demo_win(BattleCoreScript.PLAYER)
	await create_timer(2.8).timeout

	print("CARD_TACTICS_DEMO_OK")
	quit(0)
