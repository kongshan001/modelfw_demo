extends SceneTree

const OUT := "/tmp/snow_shots"

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

	var world = _scene.get_node("ViewportContainer/WorldViewport/World")
	var hud = _scene.get_node("HUD")
	var player = world.get_node("World/Player")
	player.position = Vector2(320, 250)
	hud.cover_slider.value = 0.74
	hud.night_slider.value = 21.0
	await create_timer(0.6).timeout
	await _shot("01_night")

	hud.cover_slider.value = 0.15
	await create_timer(0.5).timeout
	await _shot("02_light_snow")
	hud.cover_slider.value = 0.74

	hud.night_slider.value = 18.0
	await create_timer(0.4).timeout
	await _shot("03_dusk")
	hud.night_slider.value = 21.0

	world.toggle_mask_debug()
	await create_timer(0.3).timeout
	await _shot("04_mask")
	world.toggle_mask_debug()

	player.position = Vector2(320, 330)
	Input.action_press("move_up")
	for i in 80:
		await physics_frame
	Input.action_release("move_up")
	await create_timer(0.3).timeout
	await _shot("05_footprints")

	print("SNOW_SHOTS_OK")
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("SHOT ", name)
