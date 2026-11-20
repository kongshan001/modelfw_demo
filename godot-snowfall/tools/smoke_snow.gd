extends SceneTree

var _fails: Array[String] = []


func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.4).timeout

	var world = scene.get_node("ViewportContainer/WorldViewport/World")
	var player = world.get_node("World/Player")
	var hud = scene.get_node("HUD")
	var ground_mat: ShaderMaterial = world.ground.material

	_check(world.caps.size() >= 20, "snow caps count %d" % world.caps.size())
	_check(world._snow_layers.size() == 2, "snow layers != 2")
	for layer in world._snow_layers:
		var p: GPUParticles2D = layer["node"]
		_check(p.amount > 0, "snow layer empty")
	_check(ground_mat != null, "ground material missing")
	_check(ground_mat.get_shader_parameter("snow_mask") != null, "snow mask missing")

	world.set_coverage(0.2)
	_check(absf(ground_mat.get_shader_parameter("coverage") - 0.2) < 0.001, "coverage not set")
	var cap_alpha := (world.caps[0]["cap"] as Sprite2D).modulate.a
	_check(cap_alpha >= 0.0 and cap_alpha <= 1.0, "cap alpha out of range")
	world.set_coverage(0.74)
	_check((world.caps[0]["cap"] as Sprite2D).modulate.a >= 0.0, "cap alpha after reset")

	world.set_snow_amount(0.5)
	for layer in world._snow_layers:
		var p: GPUParticles2D = layer["node"]
		_check(p.amount > 0 and p.amount < 200, "snow amount wrong")
	world.set_wind(-0.5)
	for layer in world._snow_layers:
		var pm: ParticleProcessMaterial = layer["pm"]
		_check(pm.gravity.x < 0.0, "wind not applied")

	world.set_night(23.0)
	_check(world.canvas_mod.color.r < 0.35, "night colour not dark")
	world.set_night(18.0)
	_check(world.canvas_mod.color.r > 0.4, "dusk colour wrong")

	world.clear_footprints()
	world.set_footprints(true)
	world.add_footprint(Vector2(320, 250), 0, 1)
	await process_frame
	_check(world.footprints.get_child_count() > 0, "footprint not added")
	world.clear_footprints()
	await process_frame
	_check(world.footprints.get_child_count() == 0, "footprints not cleared")

	_check(player.sprite.sprite_frames != null, "hero frames missing")
	_check(player.sprite.sprite_frames.has_animation("walk_2"), "walk_2 missing")
	Input.action_press("move_left")
	for i in 20:
		await physics_frame
	Input.action_release("move_left")
	_check(player.position.x < 320.0, "player did not move")
	await process_frame
	_check(world.footprints.get_child_count() > 0, "walking left no footprints")

	world.set_ground_snow(false)
	_check(absf(ground_mat.get_shader_parameter("snow_on")) < 0.001, "ground snow off failed")
	world.set_ground_snow(true)
	world.set_caps(false)
	world.set_caps(true)
	world.set_snow_enabled(false)
	world.set_snow_enabled(true)
	world.toggle_mask_debug()
	world.toggle_mask_debug()

	_check(hud != null, "hud missing")

	if _fails.is_empty():
		print("SNOW_SMOKE_OK")
		quit(0)
	else:
		for f in _fails:
			printerr("SNOW SMOKE FAIL: ", f)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
