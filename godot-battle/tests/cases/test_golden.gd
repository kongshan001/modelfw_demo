extends RefCounted

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()
	var dir := DirAccess.open("res://tests/golden")
	t.ok(dir != null, "golden 目录存在")
	if dir == null:
		return
	var count := 0
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		count += 1
		var replay := BattleReplay.load_file("res://tests/golden/" + file_name)
		var result := BattleReplay.verify(replay, content, true)
		t.ok(bool(result["ok"]), "黄金回放通过: %s %s" % [file_name, str(result["errors"])])
	t.eq(count, 3, "存在 3 个黄金回放")
