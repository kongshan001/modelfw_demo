extends SceneTree

# 无头验收：
#   1) 瓦片接口/兼容表完整；
#   2) 多种子 × 三种尺寸逐条校验邻接约束与边界；
#   3) 同种子两次生成签名/统计完全一致；
#   4) 回溯路径可观测；关闭回溯时走重开路径；
#   5) 主场景/UI 接口冒烟（单步、切视图、无运行时报错）。
# 用法：godot --headless --path godot-wfc -s tools/smoke_wfc.gd

const Solver = preload("res://scripts/wfc_solver.gd")
const Tiles = preload("res://scripts/wfc_tileset.gd")

var _fails: Array[String] = []
var _maps_checked := 0
var _edges_checked := 0


func _initialize() -> void:
	_test_tileset()
	_test_sizes_and_seeds()
	_test_determinism()
	_test_backtrack_path()
	_test_backtrack_disabled()
	await _test_main_scene_contract()

	if _fails.is_empty():
		print("WFC_SMOKE_OK maps=%d edges=%d" % [_maps_checked, _edges_checked])
		quit(0)
	else:
		for failure in _fails:
			printerr("WFC SMOKE FAIL: ", failure)
		quit(1)


func _test_tileset() -> void:
	_check(Tiles.TILE_COUNT == 14, "expected 14 original tiles")
	_check(Tiles.NAMES.size() == Tiles.TILE_COUNT, "tile names missing")
	_check(Tiles.WEIGHTS.size() == Tiles.TILE_COUNT, "tile weights missing")
	_check(Tiles.SOCKETS.size() == Tiles.TILE_COUNT, "tile sockets missing")
	_check(Tiles.PATHS.size() == 7, "expected seven path pieces")
	var compat := Tiles.build_compat()
	for direction in Tiles.DIRS:
		for tile in Tiles.TILE_COUNT:
			var allowed: int = compat[direction][tile]
			_check(allowed != 0, "tile %d has no compatible neighbour dir %d" % [tile, direction])
			var bits: int = allowed
			while bits != 0:
				var low := bits & -bits
				var other := 0
				var value := low
				while value > 1:
					value >>= 1
					other += 1
				_check(Tiles.socket(tile, direction) == Tiles.socket(other, Tiles.OPPOSITE[direction]),
						"compat table mismatch")
				bits &= bits - 1


func _test_sizes_and_seeds() -> void:
	var sizes := [[12, 8], [16, 10], [18, 10]]
	var seed_texts := ["1", "2", "7", "17", "42", "2718", "8888", "garden-wood"]
	for size in sizes:
		for seed_text in seed_texts:
			var solver = Solver.new()
			solver.setup(seed_text, int(size[0]), int(size[1]), true)
			var ok: bool = solver.generate_full()
			if not ok:
				_fails.append("seed %s size %sx%s failed: %s" % [
					seed_text, size[0], size[1], solver.validation_errors().slice(0, 3)])
				continue
			var independent := _validate_independent(solver)
			if independent.is_empty():
				_maps_checked += 1
			else:
				_fails.append("seed %s size %sx%s independent validation: %s" % [
					seed_text, size[0], size[1], independent.slice(0, 3)])
	print("MAPS_OK maps=%d edges=%d" % [_maps_checked, _edges_checked])


# 不调用 solver.validate_constraints()，独立逐边复核。
func _validate_independent(solver) -> Array[String]:
	var errors: Array[String] = []
	var tiles: PackedInt32Array = solver.get_tiles()
	for y in solver.height:
		for x in solver.width:
			var tile := int(tiles[y * solver.width + x])
			if tile < 0 or tile >= Tiles.TILE_COUNT:
				errors.append("格 (%d,%d) 未坍缩" % [x, y])
				continue
			if x == 0 and Tiles.socket(tile, Tiles.W) != 0:
				errors.append("左边界的石径接口")
			if x == solver.width - 1 and Tiles.socket(tile, Tiles.E) != 0:
				errors.append("右边界的石径接口")
			if y == 0 and Tiles.socket(tile, Tiles.N) != 0:
				errors.append("上边界的石径接口")
			if y == solver.height - 1 and Tiles.socket(tile, Tiles.S) != 0:
				errors.append("下边界的石径接口")
			for direction in [Tiles.E, Tiles.S]:
				var nx: int = x + (1 if direction == Tiles.E else 0)
				var ny: int = y + (1 if direction == Tiles.S else 0)
				if nx >= solver.width or ny >= solver.height:
					continue
				var other: int = int(tiles[ny * solver.width + nx])
				if Tiles.socket(tile, direction) != Tiles.socket(other, Tiles.OPPOSITE[direction]):
					errors.append("(%d,%d)%s ↔ (%d,%d)%s" % [
						x, y, Tiles.NAMES[tile], nx, ny, Tiles.NAMES[other]])
				_edges_checked += 1
	if errors.size() > 60:
		return errors.slice(0, 60)
	return errors


func _test_determinism() -> void:
	for seed_text in ["2718", "42", "garden-wood"]:
		var a = Solver.new()
		a.setup(seed_text, 16, 10, true)
		var ok_a: bool = a.generate_full()
		var b = Solver.new()
		b.setup(seed_text, 16, 10, true)
		var ok_b: bool = b.generate_full()
		_check(ok_a and ok_b, "determinism run failed for %s" % seed_text)
		_check(a.signature() == b.signature(), "same seed produced different maps: %s" % seed_text)
		_check(a.step_count == b.step_count, "same seed produced different step counts: %s" % seed_text)
		_check(a.backtrack_count == b.backtrack_count,
				"same seed produced different backtrack counts: %s" % seed_text)
		_check(a.restart_count == b.restart_count,
				"same seed produced different restart counts: %s" % seed_text)
		_check(a.validate_constraints(), "determinism map invalid: %s" % seed_text)
		print("DETERMINISM_OK seed=%s signature=%s... steps=%d bt=%d rs=%d" % [
			seed_text, a.signature().substr(0, 18), a.step_count,
			a.backtrack_count, a.restart_count])


func _test_backtrack_path() -> void:
	var solver = Solver.new()
	solver.setup("2718", 16, 10, true)
	var first_backtrack := -1
	var guard := 0
	while not solver.finished and guard < 5000:
		var event: Dictionary = solver.step()
		guard += 1
		if String(event["event"]) == "backtrack" and first_backtrack < 0:
			first_backtrack = guard
	_check(first_backtrack > 0, "expected an observable backtrack on seed 2718")
	_check(solver.backtrack_count > 0, "backtrack counter is zero after observed backtrack")
	_check(solver.contradiction_count > 0, "contradiction counter is zero after observed backtrack")
	_check(solver.finished and not solver.failed, "backtrack demo did not finish cleanly")
	_check(solver.validate_constraints(), "backtrack demo map invalid")
	_check(solver.last_conflict_cell.x >= 0, "conflict cell not recorded")
	_check(solver.last_backtrack_cell.x >= 0, "restored cell not recorded")
	print("BACKTRACK_OK seed=2718 first_event=%d backtracks=%d contradictions=%d restarts=%d steps=%d" % [
		first_backtrack, solver.backtrack_count, solver.contradiction_count,
		solver.restart_count, solver.step_count])


func _test_backtrack_disabled() -> void:
	var solver = Solver.new()
	solver.setup("2718", 16, 10, false)
	var ok: bool = solver.generate_full()
	_check(ok, "backtrack-disabled generation failed")
	_check(solver.backtrack_count == 0, "backtrack count non-zero while disabled")
	_check(solver.restart_count > 0, "expected a restart path when backtracking is disabled")
	_check(solver.validate_constraints(), "backtrack-disabled map invalid")
	print("RESTART_OK seed=2718 restarts=%d contradictions=%d steps=%d" % [
		solver.restart_count, solver.contradiction_count, solver.step_count])


func _test_main_scene_contract() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	if scene == null or not scene.has_method("get_solver"):
		_fails.append("main scene script failed to load")
		if scene != null:
			scene.queue_free()
		return
	root.add_child(scene)
	await process_frame
	await process_frame
	_check(scene.get_solver() != null, "main scene did not create a solver")
	if scene.get_solver() == null:
		scene.queue_free()
		return
	scene.new_map("2718", 12, 8, true, false)
	_check(scene.get_solver().width == 12 and scene.get_solver().height == 8,
			"new_map did not apply requested size")
	scene.set_paused(true)
	var before: int = scene.get_solver().collapsed_cells()
	scene.step_once()
	var after: int = scene.get_solver().collapsed_cells()
	_check(after > before, "UI single-step did not collapse a cell")
	scene.set_view_mode("map")
	_check(scene.get_view_mode() == "map", "view switch failed")
	scene.finish_now()
	_check(scene.get_solver().finished, "finish_now did not finish the solver")
	_check(scene.get_solver().validate_constraints(), "UI-generated map invalid")
	scene.set_view_mode("algo")
	_check(scene.get_view_mode() == "algo", "view switch back failed")
	scene.queue_free()
	await process_frame
	print("UI_CONTRACT_OK")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails.append(message)
