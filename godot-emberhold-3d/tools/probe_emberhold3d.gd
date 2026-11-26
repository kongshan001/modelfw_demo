extends SceneTree
## Real-scene interaction probe: HUD hit rects, build/upgrade/sell, pause, AI,
## speed, map transition, restart, victory overlay and menu flow.
## Run: godot --path godot-emberhold-3d -s tools/probe_emberhold3d.gd

const W := 1280
const H := 720
const FIELD_TOP := 48.0

var vp: SubViewport
var main
var checks := 0
var fails := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	call_deferred("_run")


func _settle(n: int) -> void:
	for i in n:
		await process_frame


func _hud_redraw() -> void:
	main.hud.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _click(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	main.hud._gui_input(ev)


func _wait_transition() -> void:
	for i in 240:
		await process_frame
		if not main.transitioning:
			return


func _find_free_cell() -> Vector2i:
	var free := Vector2i(-1, -1)
	for c in main.model.map.build_cells:
		if main.model.tower_at(c.x, c.y) != null:
			continue
		var wp: Vector3 = main.map_view.to_world_cell(c.x, c.y)
		var sp: Vector2 = main.camera.unproject_position(wp)
		if sp.x > 160 and sp.x < 760 and sp.y > 160 and sp.y < 580:
			free = c
			break
	return free


func _run() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.size_2d_override = Vector2i(W, H)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(vp)
	main = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main)
	await _settle(30)
	check(main.scene_name == "menu", "boots into menu")
	check(main.hud.scene_name == "menu", "HUD in menu mode")

	# start AI game directly (transition-free) then drive through HUD actions
	main.debug_start_game("ashen", true, 1)
	await _settle(10)
	check(main.scene_name == "playing", "starts playing")
	check(main.model.ai_on, "AI commander on")
	main.debug_fast_forward(120.0)
	main.debug_freeze(true)
	await _settle(5)
	check(main.model.towers.size() >= 4, "AI built towers during fast-forward")
	check(main.model.wave >= 3, "fast-forward reached wave 3+")

	# HUD pause button
	await _hud_redraw()
	_click(Vector2(971, 705))
	await _settle(3)
	check(main.scene_name == "paused", "HUD pause button pauses")
	await _hud_redraw()
	_click(Vector2(330, 454))
	await _settle(3)
	check(main.scene_name == "playing", "pause overlay resume button works")

	# HUD AI / speed buttons
	var ai_before: bool = main.model.ai_on
	await _hud_redraw()
	_click(Vector2(810, 24))
	await _settle(2)
	check(main.model.ai_on != ai_before, "top-bar AI toggle works")
	main.debug_set_ai(true)
	await _hud_redraw()
	_click(Vector2(706, 24))
	await _settle(2)
	check(main.speed == 2, "speed button cycles to x2")
	main.debug_set_speed(1)

	# HUD shop card -> field build -> upgrade -> sell
	main.debug_freeze(true)
	main.debug_set_gold(300)
	await _hud_redraw()
	_click(Vector2(1000, 100))
	await _settle(2)
	check(main.build_type == "bolt", "shop card selects bolt")
	var cell := _find_free_cell()
	check(cell.x >= 0, "found free build cell for click test")
	var towers_before: int = main.model.towers.size()
	await _hud_redraw()
	var sp: Vector2 = main.camera.unproject_position(main.map_view.to_world_cell(cell.x, cell.y))
	_click(Vector2(sp.x, sp.y + FIELD_TOP))
	await _settle(3)
	check(main.model.towers.size() == towers_before + 1, "field click builds selected tower")
	check(main.selected_tower != null, "new tower selected")
	var built = main.selected_tower
	check(built != null and built.level == 0, "built tower level 0")
	main.debug_set_gold(300)
	await _hud_redraw()
	_click(Vector2(1000, 430))
	await _settle(2)
	check(built.level == 1, "upgrade button upgrades to Lv2")
	await _hud_redraw()
	_click(Vector2(1200, 430))
	await _settle(2)
	check(main.model.tower_at(cell.x, cell.y) == null, "sell button removes tower")

	# map transition + restart through HUD controls
	main._on_hud_action("switch_map")
	await _settle(2)
	check(main.transitioning, "map switch starts dither transition")
	await _wait_transition()
	check(main.model != null and main.model.map_id == "frost", "switch map -> frost")
	main._on_hud_action("restart")
	await _wait_transition()
	check(main.model != null and main.model.wave == 1 and main.model.gold == 140, "restart resets run")

	# victory overlay -> HUD restart button
	main.debug_force_finish(true)
	await _settle(4)
	check(main.scene_name == "over", "victory overlay state")
	await _hud_redraw()
	_click(Vector2(392, 495))
	await _wait_transition()
	check(main.scene_name == "playing" and main.model.wave == 1, "result restart button starts a new run")

	# back to menu, choose frost card, watch AI
	main._on_hud_action("menu")
	await _wait_transition()
	check(main.scene_name == "menu", "menu button returns to menu")
	await _hud_redraw()
	_click(Vector2(860, 320))
	await _wait_transition()
	check(main.selected_map == "frost", "menu frost card selects map")
	await _hud_redraw()
	_click(Vector2(900, 530))
	await _wait_transition()
	check(main.scene_name == "playing" and main.model.map_id == "frost" and main.model.ai_on,
		"menu watch-AI starts frost with AI on")

	# keyboard pause / speed / AI toggles through the real input path
	main._input(_key(KEY_SPACE))
	await _settle(2)
	check(main.scene_name == "paused", "Space pauses")
	main._input(_key(KEY_SPACE))
	await _settle(2)
	check(main.scene_name == "playing", "Space resumes")
	main._input(_key(KEY_F))
	await _settle(2)
	check(main.speed == 3, "F cycles speed 2->3")
	main._input(_key(KEY_A))
	await _settle(2)
	check(main.model.ai_on == false, "A hands control to player")

	print("PROBE CHECKS: %d, FAILS: %d" % [checks, fails])
	if fails == 0:
		print("EMBERHOLD3D_PROBE_OK")
		quit(0)
	else:
		print("EMBERHOLD3D_PROBE_FAIL")
		quit(1)


func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev
