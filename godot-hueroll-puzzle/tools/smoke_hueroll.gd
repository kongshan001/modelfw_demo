extends SceneTree

# Headless acceptance suite for HueRoll.
#   godot --headless --path godot-hueroll-puzzle -s tools/smoke_hueroll.gd
# Covers level parsing, six solutions, face orientation, paint/mixing, stamping,
# locking, undo/reset, blocked moves, stars and scene wiring.
# Prints HUEROLL_SMOKE_OK checks=<n> on success; exits 1 on failure.

const Sim := preload("res://src/hue_sim.gd")
const LEVEL_DIR := "res://levels"
const DIRS := ["north", "east", "south", "west"]
const TEST_SCENE := true

var fails: Array[String] = []
var checks := 0
var levels: Array[Dictionary] = []
var game: Node


func _initialize() -> void:
	_load_levels()
	_test_level_schema()
	_test_solutions()
	_test_face_rotation()
	_test_mixing()
	_test_blocked_and_limits()
	_test_undo_reset()
	_test_wrong_stamp()
	_test_stars()
	# Scene wiring is exercised once the full 3D scene is assembled.
	if TEST_SCENE:
		await _test_scene()
	if fails.is_empty():
		print("HUEROLL_SMOKE_OK checks=%d levels=%d" % [checks, levels.size()])
		quit(0)
	else:
		for f in fails:
			printerr("HUEROLL FAIL: ", f)
		printerr("HUEROLL_SMOKE_FAILED checks=%d fails=%d" % [checks, fails.size()])
		quit(1)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails.append(msg)


func _load_levels() -> void:
	var names := DirAccess.get_files_at(LEVEL_DIR)
	names.sort()
	for n in names:
		if not n.ends_with(".json"):
			continue
		var f := FileAccess.open("%s/%s" % [LEVEL_DIR, n], FileAccess.READ)
		if f == null:
			fails.append("cannot open %s" % n)
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			fails.append("invalid JSON %s" % n)
			continue
		levels.append(parsed)
	_check(levels.size() >= 6, "expected at least 6 levels, got %d" % levels.size())


func _new_sim(data: Dictionary) -> HueSim:
	var s := HueSim.new()
	var ok := s.load_level(data)
	_check(ok, "load_level failed for %s" % data.get("id", "?"))
	return s


func _synthetic(board: Array, extra := {}) -> Dictionary:
	var d := {
		"id": "test",
		"name": "test",
		"board": board,
		"par": 1,
		"solution": "",
		"theme": {},
	}
	d.merge(extra, true)
	return d


func _replay(sim: HueSim, moves: String, expect_ok := true) -> int:
	var applied := 0
	for i in moves.length():
		var dir := _dir_name(moves[i])
		var res := sim.roll(dir)
		if not bool(res.ok):
			if expect_ok:
				fails.append("roll %s blocked at move %d" % [dir, i + 1])
			return applied
		applied += 1
	return applied


func _dir_name(ch: String) -> String:
	match ch:
		"n": return "north"
		"e": return "east"
		"s": return "south"
		"w": return "west"
	return "north"


func _test_level_schema() -> void:
	for data in levels:
		var s := _new_sim(data)
		var lid := str(data.get("id", "?"))
		_check(s.width > 1 and s.height > 1, "%s: bad dimensions" % lid)
		_check(s.walkable.has(s.start_pos), "%s: start not walkable" % lid)
		_check(not s.target_req.is_empty(), "%s: no targets" % lid)
		_check(not s.pools.is_empty(), "%s: no paint pools" % lid)
		_check(s.par > 0, "%s: par must be > 0" % lid)
		_check(s.solution.length() == s.par, "%s: par != solution length" % lid)
		for cell in s.pools:
			_check(s.walkable.has(cell), "%s: pool not walkable %s" % [lid, cell])
			_check(not s.target_req.has(cell), "%s: pool overlaps target %s" % [lid, cell])
		for cell in s.target_req:
			_check(s.walkable.has(cell), "%s: target not walkable %s" % [lid, cell])
		_check(s.moves == 0 and not s.won, "%s: level did not start clean" % lid)
		_check(s.stamp_color(s.targets_sorted()[0]) == "blank", "%s: target pre-stamped" % lid)
		# every walkable tile must be inside the declared bounding box
		for cell in s.walkable:
			_check(cell.x >= 0 and cell.y >= 0 and cell.x < s.width and cell.y < s.height,
				"%s: walkable out of bounds %s" % [lid, cell])


func _test_solutions() -> void:
	for data in levels:
		var s := _new_sim(data)
		var lid := str(data.get("id", "?"))
		var applied := _replay(s, s.solution)
		_check(applied == s.solution.length(), "%s: solution incomplete (%d/%d)" % [lid, applied, s.solution.length()])
		_check(s.won, "%s: solution did not win" % lid)
		_check(s.moves == s.solution.length(), "%s: move count mismatch" % lid)
		for cell in s.target_req:
			_check(s.is_locked(cell), "%s: target %s not locked after solution" % [lid, cell])
			_check(s.stamp_color(cell) == s.target_color(cell),
				"%s: wrong final stamp %s (%s != %s)" % [lid, cell, s.stamp_color(cell), s.target_color(cell)])
		var p := s.target_progress()
		_check(int(p[0]) == int(p[1]), "%s: progress not full" % lid)


func _test_face_rotation() -> void:
	# Keep the cube in an empty open room so no pools/targets interfere.
	var rows := [
		".........", ".........", ".........", ".........", "....S....",
		".........", ".........", ".........", ".........",
	]
	var s := _new_sim(_synthetic(rows))
	var palette := {
		"up": "red", "down": "blue", "north": "green",
		"south": "orange", "east": "purple", "west": "yellow",
	}
	var expected := {
		"east": {"up": "west", "east": "up", "down": "east", "west": "down"},
		"west": {"up": "east", "west": "up", "down": "west", "east": "down"},
		"south": {"up": "north", "south": "up", "down": "south", "north": "down"},
		"north": {"up": "south", "north": "up", "down": "north", "south": "down"},
	}
	for dir in DIRS:
		s.reset()
		s.faces = palette.duplicate()
		var before := s.faces.duplicate()
		var res := s.roll(dir)
		_check(bool(res.ok), "face rotation: roll %s blocked" % dir)
		var map: Dictionary = expected[dir]
		for target_dir in map:
			var source: String = map[target_dir]
			_check(s.faces[target_dir] == before[source],
				"%s roll: %s should come from %s" % [dir, target_dir, source])
		# the four untouched/rotated faces must be a permutation of the palette
		var got: Array = s.faces.values()
		got.sort()
		var want: Array = palette.values()
		want.sort()
		_check(got == want, "%s roll: face colours not preserved" % dir)

	# Four rolls in one direction travel four cells but restore all six faces.
	for dir in DIRS:
		s.reset()
		s.faces = palette.duplicate()
		var expected_pos: Vector2i = s.start_pos + HueSim.DIR_VECTORS[dir] * 4
		for i in 4:
			var res := s.roll(dir)
			_check(bool(res.ok), "four-roll %s failed at %d" % [dir, i])
		_check(s.pos == expected_pos, "%s x4 should end four cells away" % dir)
		_check(s.faces == palette, "%s x4 should restore faces" % dir)
		_check(s.moves == 4, "%s x4 should count four moves" % dir)


func _test_mixing() -> void:
	_check(HueSim.mix_color("blank", "red") == "red", "blank+red")
	_check(HueSim.mix_color("red", "red") == "red", "red+red")
	_check(HueSim.mix_color("red", "yellow") == "orange", "red+yellow")
	_check(HueSim.mix_color("yellow", "red") == "orange", "yellow+red (order free)")
	_check(HueSim.mix_color("yellow", "blue") == "green", "yellow+blue")
	_check(HueSim.mix_color("blue", "yellow") == "green", "blue+yellow (order free)")
	_check(HueSim.mix_color("blue", "red") == "purple", "blue+red")
	_check(HueSim.mix_color("orange", "blue") == "blue", "fresh base covers dried secondary")
	_check(HueSim.mix_color("green", "red") == "red", "fresh red covers dried green")
	_check(HueSim.mix_color("blank", "blank") == "blank", "blank+blank")

	# A painted face must arrive as the leading face; the yellow pool then mixes it orange.
	var s := _new_sim(_synthetic([
		"S..",
		".y.",
		"...",
	]))
	var r1 := s.roll("east")
	_check(r1.ok, "mixing: setup roll")
	s.faces["south"] = "red"
	s.faces["down"] = "blank"
	var r2 := s.roll("south")
	_check(r2.ok, "mixing: roll into pool")
	_check(s.faces["down"] == "orange", "red leading face + yellow pool should be orange")
	_check(str(r2.painted) == "orange", "roll result should report orange paint")
	# blue leading face + yellow pool -> green
	var r3 := s.roll("north")
	_check(r3.ok, "mixing: leave pool")
	s.faces["south"] = "blue"
	var r4 := s.roll("south")
	_check(r4.ok and s.faces["down"] == "green", "blue + yellow should be green")
	# blank leading face simply picks up the pool colour
	var r5 := s.roll("north")
	s.faces["south"] = "blank"
	var r6 := s.roll("south")
	_check(r6.ok and s.faces["down"] == "yellow", "blank face should take pool yellow")


func _test_blocked_and_limits() -> void:
	var rows := [".#.", "#S#", ".#."]
	var s := _new_sim(_synthetic(rows))
	_check(s.start_pos == Vector2i(1, 1), "synthetic start")
	for dir in DIRS:
		_check(not s.can_roll(dir), "prop block: %s should be blocked" % dir)
		var res := s.roll(dir)
		_check(not bool(res.ok), "prop block: %s roll should fail" % dir)
		_check(s.moves == 0, "blocked roll must not count a move")
		_check(s.pos == Vector2i(1, 1), "blocked roll must not move")
	# boundary
	var s2 := _new_sim(_synthetic(["S..", "...", "..."]))
	_check(not s2.can_roll("north"), "boundary roll should be blocked")
	var r := s2.roll("north")
	_check(not bool(r.ok) and s2.moves == 0, "boundary roll must be a no-op")
	# undo with no history
	_check(not s2.undo(), "undo on empty history should report false")


func _test_undo_reset() -> void:
	var data: Dictionary = levels[0]
	var s := _new_sim(data)
	var initial_pos := s.pos
	var initial_faces := s.faces.duplicate()
	var initial_history := s.history.size()
	var applied := 0
	while applied < s.solution.length():
		var ch := s.solution[applied]
		var res := s.roll(_dir_name(ch))
		_check(bool(res.ok), "undo test roll failed")
		applied += 1
		if s.won:
			break
	_check(s.won, "undo test: should be won")
	_check(s.undo(), "undo after win should work")
	_check(not s.won, "undo after win must clear won")
	_check(s.moves == applied - 1, "undo should restore move count")
	# undo to the very beginning
	var guard := 0
	while s.undo() and guard < 200:
		guard += 1
	_check(s.pos == initial_pos, "undo all should restore position")
	_check(s.faces == initial_faces, "undo all should restore faces")
	_check(s.moves == 0 and not s.won, "undo all should restore counters")
	_check(s.stamps.is_empty() and s.locked.is_empty(), "undo all should clear stamps")
	_check(s.history.size() == initial_history, "undo all should empty history")
	# reset after some state
	_check(_replay(s, "nn", false) >= 1, "reset test should apply at least one move")
	s.reset()
	_check(s.pos == s.start_pos and s.moves == 0 and not s.won, "reset must restore start")
	_check(s.stamps.is_empty() and not s.is_locked(s.targets_sorted()[0]), "reset must clear stamps")
	_check(s.history.is_empty(), "reset must clear history")


func _test_wrong_stamp() -> void:
	# Level 06 intentionally walks over the green target with a yellow bottom at move 13.
	var data: Dictionary = levels[5]
	var s := _new_sim(data)
	var prefix := s.solution.substr(0, 13)
	_replay(s, prefix)
	var green_cell := Vector2i(3, 0)
	_check(s.target_color(green_cell) == "green", "L6 green target cell")
	_check(s.stamp_color(green_cell) == "yellow", "L6 should be stamped wrong yellow")
	_check(not s.is_locked(green_cell), "wrong stamp must not lock")
	_check(not s.won, "wrong stamp must not win")
	var rest := s.solution.substr(13)
	_replay(s, rest)
	_check(s.won, "L6 should win after correcting the target")
	_check(s.is_locked(green_cell) and s.stamp_color(green_cell) == "green", "L6 green should be corrected")
	# undo from a locked state must unlock it again
	_check(s.undo(), "L6 undo should work")
	_check(not s.won, "L6 undo must clear win")
	_check(not s.is_locked(green_cell), "L6 undo must unlock the green target")
	_check(s.stamp_color(green_cell) == "yellow", "L6 undo must restore the old wrong stamp")


func _test_stars() -> void:
	var s := _new_sim(levels[0])
	_replay(s, s.solution)
	_check(s.stars() == 3, "finishing at par should give 3 stars")
	s.moves = s.par + 1
	_check(s.stars() == 2, "par+1 should give 2 stars")
	s.moves = int(ceil(s.par * 1.5)) + 1
	_check(s.stars() == 1, "beyond 1.5x par should give 1 star")
	var fresh := _new_sim(levels[0])
	_check(fresh.stars() == 0, "unfinished level should give 0 stars")


func _test_scene() -> void:
	var packed := load("res://scenes/main.tscn")
	_check(packed != null, "main scene must load")
	if packed == null:
		return
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_check(game.has_method("debug_state"), "game should expose debug_state")
	if not game.has_method("debug_state"):
		return
	var st: Dictionary = game.debug_state()
	_check(int(st.get("level_count", 0)) >= 6, "game should load six levels")
	_check(int(st.get("level_index", -1)) == 0, "game should boot on level 0")
	_check(game.has_method("debug_apply_moves"), "game should expose debug_apply_moves")
	game.debug_apply_moves("nn", true)
	st = game.debug_state()
	_check(int(st.get("moves", 0)) == 2, "debug_apply_moves should advance two moves")
	game.debug_undo()
	st = game.debug_state()
	_check(int(st.get("moves", 0)) == 1, "debug undo should step back")
	game.debug_reset()
	st = game.debug_state()
	_check(int(st.get("moves", 0)) == 0, "debug reset should clear moves")
	game.debug_load_level(4)
	st = game.debug_state()
	_check(int(st.get("level_index", -1)) == 4, "debug load should switch levels")
	game.debug_load_level(0)
	st = game.debug_state()
	_check(int(st.get("level_index", -1)) == 0, "debug load should return to level 0")
	game.debug_apply_moves(str(levels[0].solution), true)
	st = game.debug_state()
	_check(bool(st.get("won", false)), "replaying level 1 via the scene should win")

	# Pointer input: project the pool north of the start and click it.
	game.debug_load_level(0)
	await process_frame
	var screen: Vector2 = game.camera.unproject_position(Vector3(3.5, 0.04, 4.5))
	game._on_pointer(screen)
	await process_frame
	_check(game.sim.pos == Vector2i(3, 4), "clicking an adjacent tile should roll into it")
	_check(int(game.sim.moves) == 1, "click roll should count one move")
	await create_timer(0.35).timeout
	game.debug_reset()
	await process_frame
	_check(int(game.sim.moves) == 0, "reset after click should clear moves")

	# Camera rotation updates the screen-relative key map.
	var yaw0: float = game.yaw_target
	game.request_rotate(1)
	await create_timer(0.5).timeout
	_check(absf(game.yaw_target - yaw0) > 0.1, "Q/E camera rotation should change yaw")
	_check(game.cam_rot_t < 0.0, "camera rotation should finish")
	game.debug_load_level(0)
	await process_frame

	# Win -> next level and level-select flow.
	game.debug_apply_moves(str(levels[0].solution), true)
	await create_timer(0.15).timeout
	game.request_next_level()
	await process_frame
	_check(int(game.debug_state().get("level_index", -1)) == 1, "next level should advance")
	game.debug_load_level(0)
	game.debug_apply_moves(str(levels[0].solution), true)
	await create_timer(0.15).timeout
	game.request_level_select()
	await process_frame
	_check(str(game.debug_state().get("overlay", "")) == "select", "level select should open")
	game.request_load_level(2)
	await process_frame
	_check(int(game.debug_state().get("level_index", -1)) == 2, "level card should load its level")
	_check(str(game.debug_state().get("overlay", "")) == "", "loading a level should close overlays")

	game.queue_free()
	await process_frame
	await process_frame
	HueArt.clear_cache()
