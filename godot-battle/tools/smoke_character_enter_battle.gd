extends SceneTree

# 验证主流程：主角选择确认 -> 自动切换到现有战斗场景。

func _initialize() -> void:
	var previous := HeroRoster.load_saved_id()
	change_scene_to_file("res://scenes/character_select.tscn")
	await process_frame
	await process_frame
	var select := current_scene as CharacterSelect
	if select == null:
		printerr("ENTER_BATTLE_FAIL: character select is not current scene")
		quit(1)
		return
	select.auto_enter_battle = true
	select.select_hero(&"swordsman_lingxiao", false)
	select.confirm()
	await create_timer(1.6).timeout
	var battle := current_scene
	var ok := battle != null and battle.scene_file_path == "res://scenes/battle_scene.tscn"
	if previous.is_empty():
		HeroRoster.clear_saved_id()
	else:
		HeroRoster.save_id(previous)
	if ok:
		print("ENTER_BATTLE_OK")
		quit(0)
	else:
		printerr("ENTER_BATTLE_FAIL: current scene is %s" % ("null" if battle == null else battle.scene_file_path))
		quit(1)
