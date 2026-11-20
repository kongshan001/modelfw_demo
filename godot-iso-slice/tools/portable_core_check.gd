extends SceneTree

# 跨语言 golden 校验：GDScript 核心实现必须与 Python/JS 参考实现逐值一致。
# Run: godot --headless --path godot-iso-slice -s tools/portable_core_check.gd

const Core := preload("res://src/core/portable_core.gd")
const GOLDEN := "res://tests/portable_golden.json"


func _initialize() -> void:
	var text := FileAccess.get_file_as_string(GOLDEN)
	if text.is_empty():
		printerr("PORTABLE FAIL: ", GOLDEN, " missing (run portable-core/sync.py)")
		quit(1)
		return
	var golden: Variant = JSON.parse_string(text)
	if typeof(golden) != TYPE_DICTIONARY:
		printerr("PORTABLE FAIL: golden json invalid")
		quit(1)
		return

	var fails: Array[String] = []
	for case: Dictionary in golden["iso"]:
		var inp: Array = case["in"]
		var x := float(inp[0])
		var y := float(inp[1])
		var motion: Array = Core.screen_motion(x, y)
		var exp: Array = case["motion"]
		if absf(float(motion[0]) - float(exp[0])) > 1e-9 \
				or absf(float(motion[1]) - float(exp[1])) > 1e-9:
			fails.append("motion %s -> %s != %s" % [str(inp), str(motion), str(exp)])
		var d := Core.dir_index(x, y)
		if d != int(case["dir"]):
			fails.append("dir %s -> %d != %d" % [str(inp), d, int(case["dir"])])

	for case: Dictionary in golden["hash"]:
		var got := Core.hash32(int(case["x"]), int(case["y"]), int(case["seed"]))
		if got != int(case["out"]):
			fails.append("hash (%d,%d,%d) -> %d != %d" % [
				int(case["x"]), int(case["y"]), int(case["seed"]),
				got, int(case["out"])])

	if fails.is_empty():
		print("PORTABLE_GD_OK iso=%d hash=%d" % [
			golden["iso"].size(), golden["hash"].size()])
		quit(0)
	else:
		for f in fails:
			printerr("PORTABLE FAIL: ", f)
		quit(1)
