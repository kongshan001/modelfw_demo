extends Control

# 输入接线：鼠标在世界视口里映射成格子，空格/左键抛钩，B 建造，Q/E 环视。
@onready var container: SubViewportContainer = $ViewportContainer
@onready var world: RaftWorld = $ViewportContainer/WorldViewport/World
@onready var hud: RaftHud = $HUD


func _ready() -> void:
	_setup_input()
	hud.setup(world, container)
	world.toast.connect(hud.show_toast)
	world.float_text.connect(hud.show_float)
	hud.build_selected.connect(_on_build_selected)
	hud.restart_requested.connect(restart_game)
	print("RAFT_READY")


func _setup_input() -> void:
	_action("move_left", [KEY_A, KEY_LEFT])
	_action("move_right", [KEY_D, KEY_RIGHT])
	_action("move_up", [KEY_W, KEY_UP])
	_action("move_down", [KEY_S, KEY_DOWN])
	_action("sprint", [KEY_SHIFT])
	_action("orbit_left", [KEY_Q])
	_action("orbit_right", [KEY_E])
	_action("cast", [KEY_SPACE])
	_action("build", [KEY_B])
	_action("interact", [KEY_F])
	_action("drink", [KEY_1])
	_action("eat_cooked", [KEY_2])
	_action("eat_raw", [KEY_3])
	_action("restart", [KEY_R])


func _action(name: String, keys: Array) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = int(key)
		InputMap.action_add_event(name, ev)


func _process(delta: float) -> void:
	if world == null:
		return
	var axis := Input.get_axis("orbit_left", "orbit_right")
	if absf(axis) > 0.01 and world.is_playing():
		world.orbit(axis * 1.45 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if world == null:
		return
	if event is InputEventMouseMotion:
		if world.placement_mode:
			var cell := world.cell_from_viewport(_vp_from_screen(event.position))
			world.update_ghost(cell)
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			world.zoom_by(-1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			world.zoom_by(1.0)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if world.placement_mode:
				world.cancel_placement()
			if hud.is_build_open():
				hud.close_build()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if world.placement_mode:
					var cell := world.cell_from_viewport(_vp_from_screen(event.position))
					world.try_place(cell)
				elif not hud.is_build_open() and world.is_playing():
					world.begin_charge()
			else:
				if world.hook_state == "charging":
					world.release_cast()
		return

	if event is InputEventKey:
		if event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_B:
					if world.is_playing():
						if world.placement_mode:
							world.cancel_placement()
						else:
							hud.toggle_build()
				KEY_ESCAPE:
					if world.placement_mode:
						world.cancel_placement()
					elif hud.is_build_open():
						hud.close_build()
				KEY_F:
					world.try_interact()
				KEY_1:
					world.drink_water()
				KEY_2:
					world.eat_cooked()
				KEY_3:
					world.eat_raw()
				KEY_R:
					if not world.is_playing():
						restart_game()
		if event.is_action_pressed("cast"):
			if not hud.is_build_open() and not world.placement_mode:
				world.begin_charge()
		elif event.is_action_released("cast"):
			if world.hook_state == "charging":
				world.release_cast()
		return


func _vp_from_screen(pos: Vector2) -> Vector2:
	if container == null or container.size.x <= 1.0 or container.size.y <= 1.0:
		return Vector2(-1, -1)
	var rect := container.get_global_rect()
	var local := pos - rect.position
	return local * Vector2(640.0, 360.0) / rect.size


func _on_build_selected(type: String) -> void:
	world.begin_place(type)


func restart_game() -> void:
	if get_tree().current_scene != null:
		get_tree().reload_current_scene()
	else:
		# 截图工具里没有 current_scene：手动重建本场景
		var parent := get_parent()
		var fresh: Node = load("res://scenes/main.tscn").instantiate()
		parent.add_child(fresh)
		queue_free()
