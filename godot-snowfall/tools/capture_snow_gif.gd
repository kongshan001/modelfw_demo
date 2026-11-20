extends SceneTree

const OUT := "/tmp/snow_gif"
const FPS := 15.0
const FRAMES := 150

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
	await create_timer(0.8).timeout

	_world = _scene.get_node("ViewportContainer/WorldViewport/World")
	_player = _world.get_node("World/Player")
	_hud = _scene.get_node("HUD")
	_player.position = Vector2(320, 330)
	_hud.cover_slider.value = 0.74
	_hud.night_slider.value = 21.0
	await create_timer(0.3).timeout

	Input.action_press("move_up")
	for i in FRAMES:
		if i == 42:
			Input.action_release("move_up")
		if i == 52:
			_hud.cover_slider.value = 0.25
		if i == 74:
			_hud.cover_slider.value = 0.82
		if i == 70:
			_hud.wind_slider.value = -0.55
		if i == 96:
			_hud.wind_slider.value = 0.25
		if i == 60:
			_hud.night_slider.value = 18.0
		if i == 118:
			_hud.night_slider.value = 22.5
		if i == 136:
			_hud.night_slider.value = 21.0
		await create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png("%s/frame_%03d.png" % [OUT, i])

	Input.action_release("move_up")
	print("SNOW_GIF_OK frames=", FRAMES)
	quit(0)
