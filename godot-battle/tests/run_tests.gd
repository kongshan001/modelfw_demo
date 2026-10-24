extends SceneTree

func _initialize() -> void:
	var total_assertions := 0
	var total_failures := 0
	var cases_dir := DirAccess.open("res://tests/cases")
	if cases_dir == null:
		printerr("TEST_HARNESS_FAIL: cannot open res://tests/cases")
		quit(1)
		return
	var files := cases_dir.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".gd"):
			continue
		var path := "res://tests/cases/" + file_name
		var script: Script = load(path)
		if script == null:
			printerr("FAIL %s: cannot load" % file_name)
			total_failures += 1
			continue
		var test_case: Object = script.new()
		if not test_case.has_method("run"):
			printerr("FAIL %s: missing run(t)" % file_name)
			total_failures += 1
			continue
		var ctx := TestContext.new()
		Callable(test_case, "run").call(ctx)
		total_assertions += ctx.assertions
		total_failures += ctx.failures.size()
		if ctx.assertions == 0:
			printerr("FAIL %s: zero assertions" % file_name)
			total_failures += 1
			continue
		if ctx.failures.is_empty():
			print("PASS %s (%d assertions)" % [file_name, ctx.assertions])
		else:
			printerr("FAIL %s (%d assertions)" % [file_name, ctx.assertions])
			for failure in ctx.failures:
				printerr("  - " + failure)
	print("RESULT: %d assertions, %d failures" % [total_assertions, total_failures])
	quit(0 if total_failures == 0 else 1)
