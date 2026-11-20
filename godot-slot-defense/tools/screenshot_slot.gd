extends SceneTree

# Real-GPU screenshots for docs/shots.
# Run: godot --path godot-slot-defense --resolution 1280x720 -s tools/screenshot_slot.gd

const OUT := "res://docs/shots"

var _vp: SubViewport
var _scene: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(0.8).timeout
	_scene.start_run(20261119)
	await create_timer(0.5).timeout
	await _shot("01_idle")

	_scene.request_spin()
	await create_timer(0.35).timeout
	await _shot("02_spin")
	await create_timer(0.9).timeout

	# fresh deterministic board for the action shot: all five archetypes + upgrades
	_scene.start_run(20261119)
	_scene.debug_add_gold(30)
	for t in ["blade", "bow", "shield", "steed", "orb"]:
		_scene.debug_summon(t)
	_scene.debug_summon("blade")
	_scene.debug_summon("bow")
	_scene.debug_start_wave(5)
	await create_timer(1.9).timeout
	# clear the natural wave and stage a readable line-up
	_scene.spawn_queue.clear()
	_scene.enemies.clear()
	_scene._clear_present_fx()
	for entry in [["grunt", 1148.0], ["brute", 1180.0], ["grunt", 1214.0], ["runner", 1244.0]]:
		_scene.debug_spawn(entry[0])
		_scene.enemies[_scene.enemies.size() - 1].x = entry[1]
	await create_timer(0.30).timeout
	await _shot("03_battle")

	_scene.debug_open_shop()
	await create_timer(0.6).timeout
	await _shot("04_shop")

	# boss: hold it at a readable framing, with the intro stamp still fading
	_scene.debug_start_wave(6)
	await create_timer(2.35).timeout
	for e in _scene.enemies:
		if e.type == "boss":
			e.x = 1163.0
	_scene.spawn_queue.clear()
	for i in 3:
		_scene.debug_spawn("grunt")
		_scene.enemies[_scene.enemies.size() - 1].x = 1210.0 + i * 18.0
	await create_timer(0.25).timeout
	await _shot("05_boss")

	_scene.debug_kill_all_enemies()
	await create_timer(2.2).timeout
	await _shot("06_win")

	# defeat card (a plausible mid-run board behind it)
	_scene.start_run(20261119)
	_scene.debug_add_gold(24)
	for t in ["blade", "bow", "shield", "steed"]:
		_scene.debug_summon(t)
	_scene.request_spin()
	await create_timer(1.2).timeout
	_scene.debug_start_wave(4)
	_scene.debug_set_hearts(0)
	_scene.debug_force_lose()
	await create_timer(1.0).timeout
	await _shot("07_lose")

	print("SLOT_SHOTS_OK")
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(OUT) + "/" + name + ".png")
	print("SHOT ", name)
