extends SceneTree

# 录 9 秒演示：锁定 → 追踪 → 命中 → 建造 → 设施 → 夜晚。
# Frames 输出到 /tmp/driftwood_frames，由 ffmpeg 转 GIF/MP4。
const OUT := "/tmp/driftwood_frames"
const FPS := 15.0
const FRAMES := 135

var _vp: SubViewport
var _scene: Node
var _world: RaftWorld
var _hud: RaftHud
var _flags := {}


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
	_hud = _scene.get_node("HUD")
	_world.intro_enabled = false
	_world.spawn_enabled = false
	_world.clear_loot()
	_world.debug_spawn_loot("barrel", Vector3(5.2, 0.0, -2.0))
	_world.debug_spawn_loot("crate", Vector3(-4.2, 0.0, 4.2))
	_world.debug_spawn_loot("fish", Vector3(2.2, 0.0, -5.5))
	_hud.clear_toasts()
	await create_timer(0.3).timeout

	for i in FRAMES:
		var t := float(i) / FPS
		_drive(t)
		await create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png("%s/frame_%03d.png" % [OUT, i])
		if i % 30 == 0:
			print("CAPTURE ", i, "/", FRAMES, " t=", "%.2f" % t)

	Input.action_release("move_down")
	print("RAFT_GIF_FRAMES_OK frames=", FRAMES)
	quit(0)


func _once(key: String) -> bool:
	if _flags.has(key):
		return false
	_flags[key] = true
	return true


func _drive(t: float) -> void:
	if t >= 0.15 and _once("walk"):
		Input.action_press("move_down")
	if t >= 0.65 and _once("stop_walk"):
		Input.action_release("move_down")
	if t >= 0.9 and _once("charge"):
		_hud.clear_toasts()
		_world.begin_charge()
	if t >= 1.7 and _once("release"):
		_world.release_cast()
	if t >= 2.9 and _once("materials"):
		_world.inventory["planks"] = 24
		_world.inventory["wood"] = 24
		_world.build("expand", Vector2i(2, 0))
	if t >= 3.45 and _once("expand2"):
		_world.build("expand", Vector2i(2, 1))
	if t >= 4.05 and _once("menu_open"):
		_hud.clear_toasts()
		_hud.toggle_build(true)
	if t >= 4.85 and _once("menu_close"):
		_hud.toggle_build(false)
		_world.build("crate", Vector2i(2, 0))
		_world.build("purifier", Vector2i(2, 1))
		_world.build("grill", Vector2i(0, 1))
	if t >= 5.05 and _once("zoom_stations"):
		_world.cam_size = 10.8
	if t >= 5.05 and _once("prep_outputs"):
		_world.inventory["wood"] = 12
		_world.inventory["fish"] = 5
		_world.debug_tick_stations(20.0)
	if t >= 5.25 and _once("move_near"):
		_world.player.global_position = _world.cell_center(Vector2i(1, 1))
		_hud.clear_toasts()
		_hud.clear_floaters()
	if t >= 5.4 and _once("collect"):
		_world.debug_collect_stations()
	if t >= 6.1 and _once("consume"):
		_world.thirst = 28.0
		_world.drink_water()
	if t >= 6.45 and _once("night"):
		_world.debug_set_day_phase(0.90)
		_world.cam_size = 12.0
		_hud.clear_toasts()
		_hud.clear_floaters()
	if t >= 6.5 and t < 8.2:
		_world.orbit(0.55 / FPS)
	if t >= 8.2 and _once("dawn"):
		_world.debug_set_day_phase(0.10)
		_world.cam_size = 12.6
	if t >= 8.2:
		_world.orbit(-0.55 / FPS)
