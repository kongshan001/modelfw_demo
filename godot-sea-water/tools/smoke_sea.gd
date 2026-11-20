extends SceneTree

var _fails: Array[String] = []

func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.3).timeout

	var world = scene.get_node("ViewportContainer/WorldViewport/World")
	var player = world.get_node("Player")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")

	_check(world.mask_img != null, "mask image missing")
	_check(world.depth_img != null, "depth image missing")
	_check(world.is_water(Vector2(300, 250)), "centre should be water")
	_check(not world.is_water(Vector2(20, 20)), "corner should be land")
	var d: float = world.depth_at(Vector2(300, 250))
	_check(d > 0.15, "centre depth too small: %f" % d)
	var shallow: float = world.depth_at(Vector2(140, 300))
	_check(shallow < d, "shore should be shallower than centre")

	world.set_time(22.0)
	_check(world.day < 0.05, "night day factor wrong: %f" % world.day)
	world.set_time(12.0)
	_check(world.day > 0.95, "day day factor wrong: %f" % world.day)

	world.spawn_ripple(Vector2(320, 250), 1.0)
	var has_ripple := false
	for r in world._ripples:
		if r.w > 0.0:
			has_ripple = true
	_check(has_ripple, "ripple slot not written")
	world.toggle_caustic()
	_check(world._caustic_on == false, "caustic did not turn off")
	world.toggle_caustic()
	_check(world._caustic_on == true, "caustic did not turn back on")

	_check(sprite.sprite_frames != null, "sprite frames missing")
	_check(sprite.sprite_frames.has_animation("idle_0"), "idle_0 missing")
	_check(sprite.sprite_frames.has_animation("walk_3"), "walk_3 missing")
	_check(sprite.sprite_frames.get_frame_count("walk_3") == 4, "walk frames != 4")

	player.position = Vector2(300, 250)
	for i in 20:
		await physics_frame
	_check(player.get("_submerge") > 0.1, "submerge not applied in water")

	player.position = Vector2(350, 350)
	await physics_frame
	var x0: float = player.position.x
	Input.action_press("move_left")
	for i in 15:
		await physics_frame
	Input.action_release("move_left")
	_check(player.position.x < x0 - 5.0, "player did not move")

	world.set_debug(1)
	world.set_debug(0)
	world.toggle_refract()
	world.toggle_refract()
	world.toggle_foam()
	world.toggle_foam()

	if _fails.is_empty():
		print("SEA_SMOKE_OK")
		quit(0)
	else:
		for f in _fails:
			printerr("SEA SMOKE FAIL: ", f)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
