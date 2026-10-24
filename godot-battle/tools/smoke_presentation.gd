extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var session: BattleSession = scene.get_node("BattleSession")
	session.battle_finished.connect(func(_outcome: int) -> void:
		print("PRESENTATION_SMOKE_OK")
		quit(0)
	)
	await create_timer(45.0).timeout
	printerr("PRESENTATION_SMOKE_TIMEOUT")
	quit(1)
