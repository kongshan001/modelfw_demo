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
		if not _has_text_label(ui_layer):
			printerr("PRESENTATION_SMOKE_FAIL: result label missing")
			quit(1)
			return
		print("PRESENTATION_SMOKE_OK")
		quit(0)
	)
	await create_timer(45.0).timeout
	printerr("PRESENTATION_SMOKE_TIMEOUT")
	quit(1)

func _has_text_label(node: Node) -> bool:
	if node == null:
		return false
	for child in node.get_children():
		if child is Label and not String(child.text).strip_edges().is_empty():
			return true
		if _has_text_label(child):
			return true
	return false
