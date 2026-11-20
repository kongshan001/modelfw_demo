extends SceneTree

const OUT := "/tmp/sea_shots"

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

	var world = _scene.get_node("ViewportContainer/WorldViewport/World")
	var hud = _scene.get_node("HUD")
	var player = world.get_node("Player")
	player.position = Vector2(250, 265)
	world.set_time(12.0)
	hud.slider.value = 12.0
	await create_timer(0.6).timeout
		" submerge=", player.get("_submerge"),
		" shader_sub=", player.get_node("Sprite").material.get_shader_parameter("submerge"),
		" shader_tint=", player.get_node("Sprite").material.get_shader_parameter("tint"))
	await _shot("01_day")

	hud.slider.value = 22.0
	await create_timer(0.5).timeout
	await _shot("02_night")

	hud.slider.value = 12.0
	world.set_debug(1)
	await create_timer(0.3).timeout
	await _shot("03_mask")
	world.set_debug(2)
	await create_timer(0.3).timeout
	await _shot("04_depth")
	world.set_debug(0)

	for p in [Vector2(420, 220), Vector2(470, 240), Vector2(380, 200)]:
		world.spawn_ripple(p, 1.0)
	await create_timer(0.3).timeout
	await _shot("05_ripples")

	print("SEA_SHOTS_OK")
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("SHOT ", name)
