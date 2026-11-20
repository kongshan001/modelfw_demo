extends SceneTree

## Headless acceptance: GLB skeleton/clips, locomotion, charge, projectile hit,
## sentinel counter, victory and reset. Run:
##   godot --headless --path . -s tools/smoke_ultimate.gd

var fails: Array[String] = []
var _scene: Node


func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	_scene = scene
	root.add_child(scene)
	await process_frame
	await create_timer(0.5).timeout

	var player = scene.player
	var dummy = scene.dummy
	var hud = scene.hud
	var anim: AnimationPlayer = player.anim
	if player == null or dummy == null or hud == null or anim == null:
		_fail("scene actors/HUD missing")
		await _finish()
		return

	# ── GLB structure + clips ──
	var skel: Skeleton3D = player.model_root.find_children("*", "Skeleton3D", true, false)[0]
	if skel.get_bone_count() < 25:
		_fail("skeleton bones %d < 25" % skel.get_bone_count())
	var clips := anim.get_animation_list()
	for need in ["Idle", "Run", "Charge", "Cast", "Hit", "Victory"]:
		if not clips.has(need):
			_fail("missing clip " + need)
	if anim.get_animation("Idle").get_track_count() < 10:
		_fail("Idle has too few tracks")
	if anim.current_animation != "Idle":
		_fail("did not start on Idle: " + str(anim.current_animation))

	dummy.ai_enabled = false

	# ── locomotion (real InputMap) ──
	var p0: Vector3 = player.global_position
	Input.action_press("move_forward")
	await create_timer(0.6).timeout
	var moved := p0.distance_to(player.global_position)
	if moved < 0.35:
		_fail("player moved only %.2f m" % moved)
	if player.state != "run" or anim.current_animation != "Run":
		_fail("locomotion did not enter Run (state=%s clip=%s)" % [player.state, anim.current_animation])
	Input.action_release("move_forward")
	await create_timer(0.65).timeout
	if anim.current_animation != "Idle":
		_fail("locomotion did not return to Idle: " + str(anim.current_animation))

	# ── charge / release / projectile hit ──
	player.controls_enabled = false
	player.reset_state(Vector3(-1.4, 0.05, 3.6), atan2((Vector3(1.2, 0, -3.4) - Vector3(-1.4, 0, 3.6)).x, (Vector3(1.2, 0, -3.4) - Vector3(-1.4, 0, 3.6)).z))
	await process_frame
	var started: bool = player.begin_charge()
	if not started:
		_fail("begin_charge refused")
	await create_timer(0.7).timeout
	if player.charge < 0.35:
		_fail("charge %.2f < 0.35" % player.charge)
	if anim.current_animation != "Charge":
		_fail("charge clip not playing: " + str(anim.current_animation))
	player.release_charge()
	await create_timer(0.15).timeout
	if anim.current_animation != "Cast":
		_fail("cast clip not playing: " + str(anim.current_animation))

	var hp0: int = dummy.hp
	await create_timer(0.9).timeout
	if dummy.hp >= hp0:
		_fail("charged release did not hit the sentinel (hp %d)" % dummy.hp)
	var hp1: int = dummy.hp
	scene.demo_set_dummy_hp(240)
	scene.demo_fire_at_dummy(1.0, 120)
	await create_timer(0.9).timeout
	if dummy.hp != 240 - 120:
		_fail("scripted projectile damage %d != 120 (hp %d)" % [240 - dummy.hp, dummy.hp])
	if scene.hits < 2:
		_fail("hit counter not incremented")
	if scene.get("combo") < 1:
		_fail("combo not incremented")
	print("SMOKE_COMBAT hp=%d hits=%d combo=%d" % [dummy.hp, scene.hits, scene.combo])

	# ── sentinel pulse damages a nearby player ──
	player.global_position = dummy.global_position + Vector3(0, 0.05, 2.6)
	player.hp = 100
	player._invuln = 0.0
	dummy.trigger_pulse_now()
	await create_timer(0.25).timeout
	if player.hp >= 100:
		_fail("sentinel pulse did not damage player (hp %d)" % player.hp)
	if anim.current_animation != "Hit":
		_fail("hit reaction clip not playing: " + str(anim.current_animation))
	if scene.trauma <= 0.0:
		_fail("screen-shake trauma was not triggered by the pulse")
	print("SMOKE_PULSE player_hp=%d clip=%s trauma=%.2f" % [player.hp, anim.current_animation, scene.trauma])

	# ── victory + reset ──
	scene.demo_set_dummy_hp(10)
	scene.demo_impact(1.0)
	await create_timer(1.2).timeout
	if not scene.victory:
		_fail("victory flag not set after defeat")
	if not dummy.is_defeated:
		_fail("dummy not defeated")
	if anim.current_animation != "Victory":
		_fail("victory clip not playing: " + str(anim.current_animation))
	print("SMOKE_VICTORY victory=%s max_combo=%d" % [str(scene.victory), scene.max_combo])

	scene.demo_reset()
	await create_timer(0.3).timeout
	if scene.victory or scene.defeat:
		_fail("reset did not clear state")
	if dummy.hp != dummy.max_hp or dummy.is_defeated:
		_fail("reset did not heal the sentinel")
	if player.hp != player.MAX_HP:
		_fail("reset did not heal the player")
	if anim.current_animation != "Idle":
		_fail("reset did not return to Idle: " + str(anim.current_animation))

	await _finish()


func _fail(msg: String) -> void:
	fails.append(msg)
	printerr("WUKONG FAIL: ", msg)


func _finish() -> void:
	await create_timer(1.6).timeout
	if is_instance_valid(_scene):
		_scene.queue_free()
	await process_frame
	await process_frame
	if fails.is_empty():
		print("WUKONG_ULT_SMOKE_OK")
		quit(0)
	else:
		for f in fails:
			printerr("FAIL: ", f)
		print("WUKONG_ULT_SMOKE_FAIL count=%d" % fails.size())
		quit(1)
