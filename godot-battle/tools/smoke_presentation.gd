extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var session: BattleSession = scene.get_node("BattleSession")
	session.battle_finished.connect(func(outcome: int) -> void:
		if outcome == BattleTypes.Outcome.NONE:
			printerr("PRESENTATION_SMOKE_FAIL: outcome NONE")
			quit(1)
			return
		var ui_layer: CanvasLayer = scene.get_node_or_null("UILayer")
		if not _has_result_label(ui_layer):
			printerr("PRESENTATION_SMOKE_FAIL: result label missing")
			quit(1)
			return
		print("PRESENTATION_SMOKE_OK")
		quit(0)
	)
	await create_timer(45.0).timeout
	printerr("PRESENTATION_SMOKE_TIMEOUT")
	quit(1)

func _has_result_label(node: Node) -> bool:
	if node == null:
		return false
	for child in node.get_children():
		if child is Label:
			var text := String(child.text).strip_edges()
			if text == "胜利！" or text == "战败…" or text == "逃跑成功":
				return true
		if _has_result_label(child):
			return true
	return false
