extends SceneTree

# Scripted 10-second tour (200 frames @ 20fps) for the GIF / MP4.
# Beats: idle -> spin -> wave action -> shop -> boss -> victory.
# Run: godot --path godot-slot-defense --resolution 1280x720 -s tools/capture_slot_gif.gd

const OUT := "/tmp/slot_gif"
const FPS := 20.0
const FRAMES := 200

var _vp: SubViewport
var _scene: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(0.8).timeout
	_scene.start_run(20261119)
	await create_timer(0.4).timeout

	for i in FRAMES:
		if i == 10:
			_scene.request_spin()
		elif i == 30:
			# clean deterministic showcase board
			_scene.start_run(20261119)
			_scene.debug_add_gold(30)
			for t in ["blade", "bow", "shield", "steed", "orb"]:
				_scene.debug_summon(t)
			_scene.debug_summon("blade")
			_scene.debug_summon("bow")
			_scene.debug_start_wave(5)
		elif i == 66:
			# stage a readable skirmish after the wave banner
			_scene.spawn_queue.clear()
			_scene.enemies.clear()
			_scene._clear_present_fx()
			for entry in [["grunt", 1150.0], ["brute", 1182.0], ["grunt", 1214.0], ["runner", 1244.0]]:
				_scene.debug_spawn(entry[0])
				_scene.enemies[_scene.enemies.size() - 1].x = entry[1]
		elif i == 90:
			_scene.debug_open_shop()
		elif i == 110:
			_scene.debug_start_boss()
		elif i == 136:
			_scene.debug_kill_all_enemies()
		await create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png("%s/frame_%03d.png" % [OUT, i])

	print("SLOT_GIF_OK frames=", FRAMES)
	quit(0)
