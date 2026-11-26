extends SceneTree

# Real-GPU screenshot tour for docs/shots (1920x1080).
# Run: godot --path godot-hueroll-puzzle --resolution 1280x720 -s tools/screenshot_hueroll.gd

const OUT := "res://docs/shots"

var _vp: SubViewport
var _game: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1920, 1080)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_game = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_game)
	await process_frame
	await create_timer(0.2).timeout
	_game.ui.set_perf_visible(false)
	_game.debug_load_level(3)
	await create_timer(0.9).timeout
	await _shot("01_overview")

	# 02 dip: level 4's start is directly below a blue pool.
	_game.debug_load_level(3)
	await create_timer(0.5).timeout
	_game.try_roll("north")
	await create_timer(0.30).timeout
	await _shot("02_dip")

	# 03 stamp: level 1, four rolls staged, capture the last red stamp.
	_game.debug_load_level(0)
	await create_timer(0.4).timeout
	_game.debug_apply_moves("nnnn", true)
	_game.ui.hide_hint()
	await create_timer(0.15).timeout
	_game.try_roll("north")
	await create_timer(0.30).timeout
	await _shot("03_stamp")

	# 04 win panel (same run; the win card slides in after 0.55 s).
	await create_timer(1.1).timeout
	await _shot("04_win")

	# 05 level picker.
	_game.debug_load_level(3)
	await create_timer(0.3).timeout
	_game.debug_open_select()
	await create_timer(0.5).timeout
	await _shot("05_select")

	# 06 debug overlay on the three-colour garden with two stamps done.
	_game.debug_load_level(3)
	await create_timer(0.35).timeout
	var sol4 := str(_game.levels[3].get("solution", ""))
	_game.debug_apply_moves(sol4.substr(0, 15), true)
	_game.debug_set_debug(true)
	_game.ui.hide_hint()
	await create_timer(0.5).timeout
	await _shot("06_debug")

	# 07 mixing: just before the orange stamp in level 5.
	_game.debug_set_debug(false)
	_game.debug_load_level(4)
	await create_timer(0.35).timeout
	var sol5 := str(_game.levels[4].get("solution", ""))
	_game.debug_apply_moves(sol5.substr(0, 12), true)
	_game.ui.hide_hint()
	await create_timer(0.18).timeout
	var ch := sol5.substr(12, 1)
	var dir: String = {"n": "north", "e": "east", "s": "south", "w": "west"}.get(ch, "north")
	_game.try_roll(dir)
	await create_timer(0.30).timeout
	await _shot("07_mix")

	print("HUEROLL_SHOTS_OK")
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	var path := "%s/%s.png" % [OUT, name]
	var err := img.save_png(path)
	if err != OK:
		printerr("screenshot failed: ", path)
	print("shot ", path, " ", img.get_width(), "x", img.get_height())
