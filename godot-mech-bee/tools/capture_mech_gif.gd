extends SceneTree

# Scripted 9-second tour for the GIF / MP4.
# Run: godot --path godot-mech-bee --resolution 1280x720 -s tools/capture_mech_gif.gd

const OUT := "/tmp/mech_gif"
const FPS := 20.0
const FRAMES := 180

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
	await create_timer(1.0).timeout

	_scene.auto_tour = false
	_scene.paused = false
	_scene.turntable = true
	_scene.motion_blur = true
	_scene.labels_on = true
	_scene.set_state("HOVER", false)
	_scene.selected_id = ""
	_scene.model.clear_highlight()
	await create_timer(0.5).timeout

	for i in FRAMES:
		var t := float(i) / FPS
		if i == 20:
			_scene.set_state("BANKING", false)
		elif i == 50:
			_scene.set_state("WING OFF", false)
		elif i == 75:
			_scene.set_state("ABDOMEN OPEN", false)
			_scene.select_part("abdomen_a")
		elif i == 100:
			_scene.model.clear_highlight()
			_scene.selected_id = ""
			_scene.set_state("TEARDOWN", false)
		elif i == 135:
			_scene.set_state("REASSEMBLY", false)
		elif i == 165:
			_scene.set_state("HOVER", false)
		await create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png("%s/frame_%03d.png" % [OUT, i])

	print("MECH_GIF_OK frames=", FRAMES)
	quit(0)
