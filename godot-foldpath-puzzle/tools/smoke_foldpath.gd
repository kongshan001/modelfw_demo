extends SceneTree

# Headless acceptance suite for Foldpath.
#   godot --headless --path godot-foldpath-puzzle -s tools/smoke_foldpath.gd
# Covers level schema, orthographic projection, screen-space fold seams,
# rotation-dependent connectivity, the walk graph, real character movement,
# undo/reset, win state and live scene wiring.
# Prints FOLDPATH_SMOKE_OK checks=<n> on success; exits 1 on failure.

const MAIN_SCENE := "res://scenes/main.tscn"

var fails: Array[String] = []
var checks := 0
var levels: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	levels = FoldLevel.load_all()
	_test_level_files()
	_test_projection()
	_test_l1()
	_test_l2()
	_test_l3()
	await _test_scene()
	if fails.is_empty():
		print("FOLDPATH_SMOKE_OK checks=%d levels=%d" % [checks, levels.size()])
		quit(0)
	else:
		for f in fails:
			printerr("FOLDPATH FAIL: ", f)
		printerr("FOLDPATH_SMOKE_FAILED checks=%d fails=%d" % [checks, fails.size()])
		quit(1)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails.append(msg)


func _near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps


func _wait_until(pred: Callable, timeout := 3.0) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(timeout * 1000.0):
		if bool(pred.call()):
			return true
		await process_frame
	return bool(pred.call())


func _find_level(id: String) -> Dictionary:
	for lvl in levels:
		if String(lvl.get("id", "")) == id:
			return lvl
	return {}


func _focus_of(level: Dictionary) -> Vector3:
	return FoldMath.vec3(level["camera"]["focus"])


func _size_of(level: Dictionary) -> float:
	return float(level["camera"]["size"])


func _angle_map(level: Dictionary, overrides: Dictionary) -> Dictionary:
	var a := FoldLevel.initial_angles(level)
	for k in overrides.keys():
		a[k] = overrides[k]
	return a


func _test_level_files() -> void:
	_check(levels.size() == 3, "expected 3 levels, got %d" % levels.size())
	for lvl in levels:
		var err := FoldLevel.validate(lvl)
		_check(err == "", "level %s schema: %s" % [String(lvl.get("id", "?")), err])
		_check(String(lvl.get("name", "")) != "", "level needs a name")
		_check(not (lvl.get("fold_pairs", []) as Array).is_empty(), "level needs fold_pairs: " + String(lvl.get("id", "?")))
		_check(FoldLevel.initial_angles(lvl).size() == (lvl["platforms"] as Array).size(), "angles per platform")
		var levels_ids := {}
		for p in lvl["platforms"]:
			levels_ids[String(p["id"])] = true
		_check(levels_ids.size() == (lvl["platforms"] as Array).size(), "platform ids unique")
		var start: Dictionary = FoldLevel.node_map(lvl)[String(lvl["start"])]
		var goal: Dictionary = FoldLevel.node_map(lvl)[String(lvl["goal"])]
		_check(String(start["kind"]) == "start", "start kind")
		_check(String(goal["kind"]) == "goal", "goal kind")
	# Intended loose ends only.
	_check(FoldLevel.link_candidates(_find_level("L2")).size() == 4, "L2 has four loose fold ends")
	_check(FoldLevel.link_candidates(_find_level("L3")).size() == 6, "L3 has six loose fold ends")


func _test_projection() -> void:
	var focus := Vector3(0.3, 0.9, 0.2)
	var size := 7.2
	var p := Vector3(-0.4, 0.5, 0.8)
	var s := FoldMath.project(p, focus, size)
	var center := FoldMath.project(focus, focus, size)
	_check(_near(center.x, 640.0) and _near(center.y, 360.0), "focus projects to screen centre")
	var up := FoldMath.project(focus + Vector3(0, 1, 0), focus, size)
	_check(_near(up.y, 360.0 - FoldMath.basis().y.y * 720.0 / size, 0.01), "orthographic vertical scale")
	# Any shift along the camera's back vector leaves the screen position unchanged.
	for k in [0.35, 1.0, 2.8]:
		var q: Vector3 = p + FoldMath.BACK * float(k)
		_check(FoldMath.project(q, focus, size).distance_to(s) < 0.01, "screen-invariant depth shift %.2f" % float(k))
		_check(_near(FoldMath.project_depth(q, focus) - FoldMath.project_depth(p, focus), float(k), 0.01), "depth increases with back shift")
	# Fixed camera orientation.
	_check(_near(rad_to_deg(asin(FoldMath.BACK.y)), 35.264, 0.01), "camera elevation")
	_check(_near(rad_to_deg(atan2(FoldMath.BACK.x, FoldMath.BACK.z)), 45.0, 0.01), "camera yaw")
	_check(_near(FoldMath.snap_angle(92.0, 15.0), 90.0), "angle snapping")
	# Ray/box pick helper.
	var ray := FoldMath.screen_ray(Vector2(640, 360), focus, size)
	var hit := FoldMath.ray_yaw_box(ray[0], ray[1], Vector3.ZERO, 0.0, Vector3.ZERO, Vector3(2, 2, 2))
	_check(hit > 0.0, "ray hits box at screen centre")
	var miss := FoldMath.ray_yaw_box(ray[0], ray[1], Vector3(100, 0, 0), 0.0, Vector3.ZERO, Vector3(2, 2, 2))
	_check(miss < 0.0, "ray misses far box")


func _assert_links(level: Dictionary, overrides: Dictionary, expected: Array, label: String) -> Array[Dictionary]:
	var angles := _angle_map(level, overrides)
	var links := FoldLevel.active_links(level, angles, _focus_of(level), _size_of(level))
	var got: Array[String] = []
	for link in links:
		got.append("%s+%s" % [String(link["a"]), String(link["b"])])
		_check(float(link["dist"]) < 0.02 or float(link["dist"]) < float(level.get("link_px", 18.0)), "%s alignment within threshold" % label)
		_check(float(link["depth"]) >= float(level.get("link_depth", 0.35)), "%s depth separation" % label)
	var want: Array[String] = []
	for e in expected:
		want.append(String(e))
	got.sort()
	want.sort()
	_check(got == want, "%s links expected %s got %s" % [label, str(want), str(got)])
	return links


func _test_l1() -> void:
	var lvl := _find_level("L1")
	if lvl.is_empty():
		return
	var links := _assert_links(lvl, {}, ["u+a"], "L1 start")
	_check(links.size() == 1, "L1 one fold seam")
	if links.size() == 1:
		_check(_near(float(links[0]["dist"]), 0.0, 0.05), "L1 seam is screen-exact")
		_check(float(links[0]["depth"]) > 1.0, "L1 seam crosses depth")
		_check(FoldLevel.find_route(lvl, "s", "a", links) == ["s", "u", "a"], "L1 route crosses the seam")
	var route := FoldLevel.find_route(lvl, "s", "g", links)
	_check(route == ["s", "u", "a", "b", "g"], "L1 full teaching route")
	var no_rot := true
	for p in lvl["platforms"]:
		if bool(p.get("rotatable", false)):
			no_rot = false
	_check(no_rot, "L1 is a walking lesson with no rotating platform")
	var u := FoldLevel.node_world(lvl, _angle_map(lvl, {}), "u")
	var a := FoldLevel.node_world(lvl, _angle_map(lvl, {}), "a")
	_check(_near(u.y, a.y + 1.6 * FoldMath.BACK.y, 0.01), "L1 upper terrace height")
	_check(_near(FoldMath.project(u, _focus_of(lvl), _size_of(lvl)).x, FoldMath.project(a, _focus_of(lvl), _size_of(lvl)).x, 0.01), "L1 projected x exact")
	_check(_near(FoldMath.project(u, _focus_of(lvl), _size_of(lvl)).y, FoldMath.project(a, _focus_of(lvl), _size_of(lvl)).y, 0.01), "L1 projected y exact")


func _test_l2() -> void:
	var lvl := _find_level("L2")
	if lvl.is_empty():
		return
	var links0 := _assert_links(lvl, {}, ["a+i"], "L2 initial")
	_check(FoldLevel.find_route(lvl, "s", "o", links0) == ["s", "a", "i", "m", "o"], "L2 can board the bridge")
	_check(FoldLevel.find_route(lvl, "s", "g", links0).is_empty(), "L2 goal unreachable before rotation")
	var links45 := FoldLevel.active_links(lvl, _angle_map(lvl, {"bridge": 45.0}), _focus_of(lvl), _size_of(lvl))
	_check(links45.is_empty(), "L2 no seam mid-rotation")
	var links90 := _assert_links(lvl, {"bridge": 90.0}, ["o+b"], "L2 rotated")
	_check(FoldLevel.find_route(lvl, "o", "g", links90) == ["o", "b", "g"], "L2 goal reachable after rotation")
	var links180 := FoldLevel.active_links(lvl, _angle_map(lvl, {"bridge": 180.0}), _focus_of(lvl), _size_of(lvl))
	_check(links180.is_empty(), "L2 180-degree pose is not a shortcut")
	var o90 := FoldLevel.node_world(lvl, _angle_map(lvl, {"bridge": 90.0}), "o")
	_check(o90.distance_to(Vector3(0.0, 1.1, 1.55)) < 0.01, "L2 bridge end lands on its target")
	_check(_is_finite(o90), "L2 rotated endpoint finite")
	# Zoom extremes keep the solved seams exact.
	for zoom in [float(lvl["camera"].get("zoom_min", 0.82)), 1.0, float(lvl["camera"].get("zoom_max", 1.22))]:
		var lx := FoldLevel.active_links(lvl, _angle_map(lvl, {"bridge": 90.0}), _focus_of(lvl), _size_of(lvl) * zoom)
		_check(lx.size() == 1, "L2 rotated seam at zoom %.2f" % zoom)
		_check(float(lx[0]["dist"]) < 0.02, "L2 exact seam at zoom %.2f" % zoom)


func _is_finite(v: Vector3) -> bool:
	return not (is_nan(v.x) or is_nan(v.y) or is_nan(v.z) or is_inf(v.x) or is_inf(v.y) or is_inf(v.z))


func _test_l3() -> void:
	var lvl := _find_level("L3")
	if lvl.is_empty():
		return
	var links0 := _assert_links(lvl, {}, ["l+r1"], "L3 base")
	_check(FoldLevel.find_route(lvl, "s", "r2", links0) == ["s", "l", "r1", "rm1", "rm2", "r2"], "L3 can board the ring")
	_check(FoldLevel.find_route(lvl, "s", "t2", links0).is_empty(), "L3 spire unreachable before ring rotation")
	var links90 := _assert_links(lvl, {"ring": 90.0}, ["r2+t1"], "L3 ring turned")
	_check(FoldLevel.find_route(lvl, "r2", "t2", links90) == ["r2", "t1", "tm", "t2"], "L3 can board the spire")
	var linksBoth := _assert_links(lvl, {"ring": 90.0, "spire": 90.0}, ["t2+c"], "L3 both turned")
	_check(FoldLevel.find_route(lvl, "t2", "g", linksBoth) == ["t2", "c", "g"], "L3 crown route after the spire turn")
	_check(FoldLevel.find_route(lvl, "r2", "g", linksBoth).is_empty(), "L3 ring end is detached after the spire turn")
	_check(FoldLevel.find_route(lvl, "s", "g", linksBoth).is_empty(), "L3 base cannot jump straight to the crown")
	# Spire turned early must not create a shortcut from the base.
	_assert_links(lvl, {"spire": 90.0}, ["l+r1", "t2+c"], "L3 spire early")
	var linksOdd := FoldLevel.active_links(lvl, _angle_map(lvl, {"ring": 180.0}), _focus_of(lvl), _size_of(lvl))
	_check(linksOdd.is_empty(), "L3 ring 180 has no seam")
	# Exact projected positions at the solved poses.
	var a0 := _angle_map(lvl, {"ring": 90.0})
	var r2 := FoldLevel.node_world(lvl, a0, "r2")
	var t1 := FoldLevel.node_world(lvl, a0, "t1")
	_check(_near(FoldMath.project(r2, _focus_of(lvl), _size_of(lvl)).distance_to(FoldMath.project(t1, _focus_of(lvl), _size_of(lvl))), 0.0, 0.02), "L3 ring/spire screen-exact")
	var a1 := _angle_map(lvl, {"ring": 90.0, "spire": 90.0})
	var t2 := FoldLevel.node_world(lvl, a1, "t2")
	var c := FoldLevel.node_world(lvl, a1, "c")
	_check(_near(FoldMath.project(t2, _focus_of(lvl), _size_of(lvl)).distance_to(FoldMath.project(c, _focus_of(lvl), _size_of(lvl))), 0.0, 0.02), "L3 spire/crown screen-exact")
	_check(_is_finite(t2) and _is_finite(c), "L3 solved endpoints finite")
	for zoom in [float(lvl["camera"].get("zoom_min", 0.82)), 1.0, float(lvl["camera"].get("zoom_max", 1.22))]:
		var lx := FoldLevel.active_links(lvl, a1, _focus_of(lvl), _size_of(lvl) * zoom)
		_check(lx.size() == 1 and String(lx[0]["a"]) + "+" + String(lx[0]["b"]) == "t2+c", "L3 crown seam at zoom %.2f" % zoom)
		var lr := FoldLevel.active_links(lvl, _angle_map(lvl, {"ring": 90.0}), _focus_of(lvl), _size_of(lvl) * zoom)
		_check(lr.size() == 1 and String(lr[0]["a"]) + "+" + String(lr[0]["b"]) == "r2+t1", "L3 ring/spire seam at zoom %.2f" % zoom)


func _test_scene() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		return
	var game := packed.instantiate() as FoldGame
	_check(game != null, "main scene is FoldGame")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await process_frame
	_check(game.levels.size() == 3, "live scene has 3 valid levels")
	_check(game.cam != null and game.world != null and game.player != null and game.hud != null, "live scene wired")
	_check(game.level_index == 0 and game.current_node == "s", "starts on L1 at s")
	_check(game.screen_nodes.has("g"), "L1 nodes projected for the HUD")
	var proj := FoldMath.project(game.player.position - FoldGame.FOOT, game.cam.focus, game.cam.effective_size())
	_check(proj.distance_to(game.screen_nodes["s"]) < 0.5, "camera projection agrees with screen nodes")

	# Keyboard one-hop movement, then undo.
	_check(game.keyboard_step(Vector2.RIGHT), "keyboard RIGHT starts a hop toward u")
	var kb_done: bool = await _wait_until(func() -> bool: return not game.moving, 2.0)
	_check(kb_done and game.current_node == "u", "keyboard hop reaches u")
	game.undo()
	await process_frame
	_check(game.current_node == "s", "keyboard hop undo returns to s")
	_check(not game.keyboard_step(Vector2.DOWN), "keyboard DOWN has no backward neighbour")

	# Real click + real walk (no teleports).
	var u_screen: Vector2 = game.debug_node_screen("u")
	_check(u_screen.distance_to(Vector2.ZERO) > 1.0, "L1 u has a screen position")
	game.debug_screen_click(u_screen)
	_check(game.moving, "click on u starts a walk")
	var reached: bool = await _wait_until(func() -> bool: return not game.moving, 2.0)
	_check(reached and game.current_node == "u", "character walks from s to u")
	_check(game.moves == 1 and game.actions.size() == 1, "walk recorded for undo")
	game.undo()
	await process_frame
	_check(game.current_node == "s" and game.actions.is_empty(), "undo returns to s")
	_check(game.moves == 0, "undo decrements moves")

	# Walk across the pre-aligned fold seam and win L1.
	var g_screen: Vector2 = game.debug_node_screen("g")
	game.debug_screen_click(g_screen)
	_check(game.moving, "click on goal starts the fold route")
	var won: bool = await _wait_until(func() -> bool: return game.win, 4.0)
	_check(won, "L1 reachable goal wins after the fold walk")
	_check(game.current_node == "g", "L1 ends on the goal")
	_check(game.hud.win_layer.visible, "win card is shown")
	_check(game.actions.size() == 1, "L1 move recorded once")

	# Level 2: board, rotate, undo the rotation, rotate, then win.
	game.debug_load_level(1)
	await process_frame
	_check(game.level_index == 1 and game.current_node == "s", "L2 loads at its start")
	_check(game.debug_instant_move("o"), "L2 instant board to bridge end")
	_check(game.current_node == "o", "L2 player on bridge end")
	var before_angle := float(game.angles["bridge"])
	game.select_platform("bridge")
	game.rotate_selected(1)
	_check(game.rotating, "L2 Q/E starts a rotation tween")
	var settled: bool = await _wait_until(func() -> bool: return not game.rotating, 1.0)
	_check(settled, "L2 rotation settles")
	_check(_near(float(game.angles["bridge"]), before_angle + 15.0, 0.01), "L2 rotation is 15 degrees")
	_check(game.actions.size() == 2 and game.rotations == 1, "L2 rotation recorded")
	game.undo()
	var undone: bool = await _wait_until(func() -> bool: return not game.rotating, 1.0)
	_check(undone and _near(float(game.angles["bridge"]), before_angle, 0.01), "L2 undo restores angle")
	_check(game.rotations == 0, "L2 undo decrements rotations")
	game.debug_set_angle("bridge", 90.0)
	await process_frame
	_check(game.links.size() == 1 and String(game.links[0]["a"]) in ["o", "b"], "L2 linked after final rotation")
	_check(game.debug_route("g") == ["o", "b", "g"], "L2 route to goal after final rotation")
	_check(game.debug_instant_move("g"), "L2 instant move wins")
	_check(game.win and game.current_node == "g", "L2 win state")
	game.reset_level()
	await process_frame
	_check(not game.win and game.current_node == "s" and game.actions.is_empty(), "L2 reset clears state")
	_check(_near(float(game.angles["bridge"]), 0.0, 0.01), "L2 reset restores bridge angle")

	# Level 3: three-stage impossible loop, using a real rotation for the ride.
	game.debug_load_level(2)
	await process_frame
	_check(game.level_index == 2 and game.current_node == "s", "L3 loads")
	_check(game.debug_instant_move("r2"), "L3 instant board the ring end")
	var rider_before: Vector3 = game.player.position
	game.select_platform("ring")
	for i in 6:
		game.rotate_selected(1)
		var ok: bool = await _wait_until(func() -> bool: return not game.rotating, 1.0)
		_check(ok, "L3 ring step %d settles" % i)
	_check(_near(float(game.angles["ring"]), 90.0, 0.01), "L3 ring reaches 90")
	_check(game.player.position.distance_to(rider_before) > 0.2, "L3 rider moves with the rotating ring")
	_check(game.debug_route("t2") == ["r2", "t1", "tm", "t2"], "L3 route crosses the ring seam")
	_check(game.debug_instant_move("t2"), "L3 instant move to spire end")
	game.debug_set_angle("spire", 90.0)
	await process_frame
	var pairs: Array[String] = []
	for l in game.links:
		pairs.append("%s+%s" % [String(l["a"]), String(l["b"])])
	pairs.sort()
	_check(pairs == ["t2+c"], "L3 crown seam opens after the spire turn")
	_check(game.debug_route("g") == ["t2", "c", "g"], "L3 crown route")
	_check(game.debug_instant_move("g"), "L3 instant move wins")
	_check(game.win, "L3 win")
	game.debug_set_debug(true)
	await process_frame
	await process_frame
	_check(game.hud.debug_card.visible, "debug overlay toggles")
	var state: Dictionary = game.debug_state()
	_check(int(state.get("link_count", 0)) >= 0 and state.has("fps"), "debug state snapshot")
	_check(int(state.get("draws", 0)) >= 0, "draw call counter available")

	game.queue_free()
	await process_frame
