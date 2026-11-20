extends SceneTree

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
	await create_timer(1.0).timeout

	_scene.auto_tour = false
	_scene.set_state("HOVER", false)
	await create_timer(0.8).timeout
	await _shot("01_hover")

	_scene.set_state("TEARDOWN", false)
	await create_timer(2.2).timeout
	await _shot("02_teardown")

	_scene.set_state("HOVER", false)
	await create_timer(2.2).timeout
	_scene.select_part("optics")
	_scene.toggle_isolate()
	await create_timer(1.2).timeout
	await _shot("03_isolate")

	_scene.toggle_isolate()
	_scene.selected_id = ""
	_scene.model.clear_highlight()
	_scene.motion_blur = true
	_scene.set_state("BANKING", false)
	await create_timer(1.2).timeout
	await _shot("04_banking")

	_scene.set_state("THORAX OPEN", false)
	await create_timer(1.4).timeout
	await _shot("05_thorax_open")

	print("MECH_SHOTS_OK")
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(OUT) + "/" + name + ".png")
	print("SHOT ", name)
