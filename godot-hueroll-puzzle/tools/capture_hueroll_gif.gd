extends SceneTree

# 10-second scripted tour (200 frames @ 20 fps) for the GIF / MP4.
# Run: godot --path godot-hueroll-puzzle --resolution 1280x720 -s tools/capture_hueroll_gif.gd
# Final media:
#   ffmpeg -framerate 20 -i /tmp/hueroll_gif/frame_%03d.png ... docs/hueroll.gif / .mp4

const OUT := "/tmp/hueroll_gif"
const FPS := 20.0
const FRAMES := 200

var vp: SubViewport
var game: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	game = load("res://scenes/main.tscn").instantiate()
	vp.add_child(game)
	await process_frame
	await create_timer(0.8).timeout
	game.ui.set_perf_visible(false)

	for i in FRAMES:
		_schedule(i)
		await create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/frame_%03d.png" % [OUT, i])
	print("HUEROLL_GIF_OK frames=", FRAMES)
	quit(0)


func _schedule(i: int) -> void:
	match i:
		2:
			game.debug_load_level(3)     # three-colour garden
		16:
			game.debug_load_level(0)     # tutorial
		24:
			game.try_roll("north")       # dip into the red pool
		32:
			game.try_roll("north")
		40:
			game.try_roll("north")
		48:
			game.try_roll("north")
		56:
			game.try_roll("north")       # stamp + win
		94:
			game.debug_load_level(3)
			var sol4: String = str(game.levels[3].get("solution", ""))
			game.debug_apply_moves(sol4.substr(0, 15), true)
		108:
			game.request_rotate(1)       # show the 3D room from another quarter
		124:
			game.debug_open_select()
		152:
			game.request_load_level(5)   # rainbow finale
			var sol6: String = str(game.levels[5].get("solution", ""))
			game.debug_apply_moves(sol6.substr(0, 10), true)
