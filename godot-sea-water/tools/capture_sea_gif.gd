extends SceneTree

const OUT := "/tmp/sea_gif"
const FPS := 15.0
const FRAMES := 112

var _vp: SubViewport
var _scene: Node
var _world: Node
var _player: Node
var _hud: CanvasLayer


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(0.6).timeout

	_world = _scene.get_node("ViewportContainer/WorldViewport/World")
	_player = _world.get_node("Player")
	_hud = _scene.get_node("HUD")
	_player.position = Vector2(85, 295)
	_hud.slider.value = 12.0
	await create_timer(0.3).timeout

	Input.action_press("move_right")
	for i in FRAMES:
		if i == 30:
			Input.action_release("move_right")
		if i == 36:
			_world.spawn_ripple(Vector2(225, 272), 1.2)
		if i == 44:
			_world.spawn_ripple(Vector2(260, 290), 1.0)
		if i == 56:
			_hud.slider.value = 18.0
		if i == 72:
			_hud.slider.value = 22.0
		if i == 88:
			_hud.slider.value = 12.0
		if i == 94:
			_world.spawn_ripple(Vector2(300, 260), 1.2)
		await create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png("%s/frame_%03d.png" % [OUT, i])

	Input.action_release("move_right")
	print("SEA_GIF_OK frames=", FRAMES)
	quit(0)
