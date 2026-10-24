extends SceneTree

func _initialize() -> void:
	var file := ""
	var strict := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--strict-content":
			strict = true
		elif argument.begins_with("--file="):
			file = argument.substr("--file=".length())
		elif not argument.begins_with("--"):
			file = argument
	if file.is_empty():
		printerr("usage: godot --headless --path godot-battle -s tools/replay.gd -- --file <path> [--strict-content]")
		quit(2)
		return
	var replay := BattleReplay.load_file(file)
	if replay.is_empty():
		printerr("REPLAY_FAIL cannot load " + file)
		quit(2)
		return
	var content := ContentDB.load_all()
	var result := BattleReplay.verify(replay, content, strict)
	for warning in result["warnings"]:
		print("REPLAY_WARN " + warning)
	if bool(result["ok"]):
		print("REPLAY_OK " + file)
		quit(0)
	else:
		for error in result["errors"]:
			printerr("REPLAY_FAIL " + error)
		var divergence: Dictionary = result["first_divergence"]
		if not divergence.is_empty():
			printerr("REPLAY_DIVERGENCE " + JSON.stringify(divergence, "  ", true))
		quit(1)
