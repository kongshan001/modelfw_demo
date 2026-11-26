extends SceneTree
## Real-GPU 1920x1080 screenshots.
## Run: godot --path godot-emberhold-3d -s tools/screenshot_emberhold3d.gd
## Output: captures/01..09 (1920x1080).

const OUT := "res://captures"
const SIZE := Vector2i(1920, 1080)

var vp: SubViewport
var main


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	call_deferred("_run")


func _settle(n: int) -> void:
	for i in n:
		await process_frame


func _wait_transition() -> void:
	for i in 240:
		await process_frame
		if not main.transitioning:
			return


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, name])
	var st: Dictionary = main.get_state()
	print("SHOT %s %dx%d scene=%s map=%s wave=%d towers=%d enemies=%d dc=%d" % [
		name, img.get_width(), img.get_height(), st["scene"], st["map"], st["wave"],
		st["towers"], st["enemies"], st["draw_calls"]])


func _free_cell_center() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1e9
	var field_center := Vector2(232.0, 168.0)
	for c in main.model.map.build_cells:
		if main.model.tower_at(c.x, c.y) != null:
			continue
		var p: Vector2 = main.model.map.cell_center(c.x, c.y)
		var d: float = p.distance_to(field_center)
		var wp: Vector3 = main.map_view.to_world_cell(c.x, c.y)
		var sp: Vector2 = main.camera.unproject_position(wp)
		if sp.x < 120.0 or sp.x > 800.0 or sp.y < 140.0 or sp.y > 520.0:
			continue
		if d < best_d:
			best_d = d
			best = c
	return best


func _run() -> void:
	vp = SubViewport.new()
	vp.size = SIZE
	vp.size_2d_override = Vector2i(1280, 720)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(vp)
	main = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main)
	await _settle(30)
	main.debug_set_field_highres(true, 1.5)
	main.debug_set_hud_rate(10.0)
	await _settle(25)
	print("FIELD VIEWPORT ", main.field_view.size)
	check_field_resolution()

	# 01 menu, ashen
	main.debug_menu("ashen")
	await _settle(25)
	await _shot("01-menu-ashen")

	# 02 menu, frost
	main.debug_menu("frost")
	await _settle(25)
	await _shot("02-menu-frost")

	# busy wave 11 combat on ashen
	main.debug_start_game("ashen", true, 1)
	await _settle(10)
	main.debug_fast_forward(470.0)
	main.debug_freeze(false)
	await _settle(24)
	main.debug_freeze(true)
	await _settle(10)
	await _shot("05-wave-combat")

	# build preview with range/ghost
	main.debug_set_gold(320)
	main.debug_pick("flame")
	var cell := _free_cell_center()
	main.debug_hover_cell(cell.x, cell.y)
	await _settle(18)
	await _shot("04-build-preview")

	# pause + selected tower
	main.debug_clear_hover()
	main.debug_select_tower(1)
	main.debug_pause(true)
	await _settle(18)
	await _shot("08-pause")
	main.debug_pause(false)
	main.build_type = ""
	main.debug_select_tower(1)

	# boss wave on ashen
	main.debug_start_game("ashen", true, 1)
	await _settle(8)
	main.debug_advance_until_boss(620.0)
	main.debug_advance_boss_visible(110.0)
	main.debug_freeze(false)
	await _settle(20)
	main.debug_freeze(true)
	await _settle(10)
	await _shot("07-boss-wave")

	# genuine ashen -> frost transition, held mid-way
	main.debug_freeze(false)
	main._on_hud_action("switch_map")
	await _settle(2)
	main.debug_hold_current_transition(0.45)
	await _settle(18)
	await _shot("03-map-transition")
	main.debug_clear_transition()
	await _settle(6)

	# frost combat
	main.debug_advance_until_combat(18, 12, 400.0)
	main.debug_freeze(false)
	await _settle(22)
	main.debug_freeze(true)
	await _settle(10)
	await _shot("06-frost-assault")

	# victory result (real AI run)
	main.debug_start_game("ashen", true, 1)
	await _settle(8)
	main.debug_fast_forward(620.0)
	main.debug_freeze(true)
	await _settle(25)
	await _shot("09-victory")

	print("SCREENSHOTS DONE")
	quit()


func check_field_resolution() -> void:
	var s: Vector2i = main.field_view.size
	if s.x < 1300:
		print("WARN: field viewport is only ", s, " (expected ~1392x1008)")
