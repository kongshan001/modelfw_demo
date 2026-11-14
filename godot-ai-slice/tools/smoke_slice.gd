extends SceneTree

# Headless acceptance for the slice: title -> play -> collect 3 -> win -> restart.
# Run: godot --headless --path godot-ai-slice -s tools/smoke_slice.gd
# This script is launched with -s, so it resolves the autoload by path instead
# of relying on the global identifier.

var _game: Node

func _initialize() -> void:
	_game = root.get_node_or_null("Game")
	if _game == null:
		_fail("Game autoload missing")

	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.2).timeout

	if not bool(_game.call("is_title")):
		_fail("initial state is not TITLE")

	scene.call("start_game")
	await process_frame
	if not bool(_game.call("is_playing")):
		_fail("start_game did not enter PLAYING")

	var player: Node = scene.get_node_or_null("Player")
	if player == null:
		_fail("Player missing")

	var pins := get_nodes_in_group("pins")
	if pins.size() != 3:
		_fail("pin count mismatch: %d" % pins.size())
	player.call("throw_head")
	await process_frame
	var projectiles := get_nodes_in_group("head_projectiles")
	if projectiles.size() != 1:
		_fail("head projectile did not spawn")
	for pin in pins:
		pin.call("hit")
	await process_frame
	if int(scene.get("pins_knocked")) != 3:
		_fail("pins_knocked mismatch: %d" % int(scene.get("pins_knocked")))

	var coins := get_nodes_in_group("cores")
	if coins.size() != int(_game.call("total_cores")):
		_fail("core count mismatch: %d" % coins.size())

	var portal: Node = scene.get_node_or_null("Portal")
	if portal == null:
		_fail("Portal missing")
	if bool(portal.get("active")):
		_fail("portal should start inactive")

	for coin in coins:
		coin.call("collect")
	await process_frame
	if int(_game.get("collected")) != int(_game.call("total_cores")):
		_fail("collected count mismatch: %d" % int(_game.get("collected")))
	if not bool(portal.get("active")):
		_fail("portal did not activate after all cores")

	portal.call("trigger")
	await process_frame
	if not bool(_game.call("is_won")):
		_fail("portal trigger did not win")

	scene.call("restart_level")
	await process_frame
	if not bool(_game.call("is_playing")):
		_fail("restart did not return to PLAYING")
	if int(_game.get("collected")) != 0:
		_fail("restart did not clear cores")
	for coin in get_nodes_in_group("cores"):
		if not coin.visible:
			_fail("restart did not restore a coin")
	if int(scene.get("pins_knocked")) != 0:
		_fail("restart did not clear pins")
	for pin in get_nodes_in_group("pins"):
		if bool(pin.get("down")):
			_fail("restart did not restore a pin")

	print("AI_SLICE_SMOKE_OK")
	scene.queue_free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	printerr("AI_SLICE_SMOKE_FAIL: " + message)
	quit(1)
