extends SceneTree

# Headless smoke test for the Pixel VFX Lab.
#   godot --headless --path . -s tools/smoke_pixel_vfx.gd
# Covers: sheet/JSON load (frames, size, duration, pivot), four effect triggers,
# hit-stop, burn/freeze timers, coin double-count guard, respawn, speed switch,
# and effect/popup cleanup. Last line is PIXEL_VFX_SMOKE_OK on success.

var _fails: Array[String] = []
var main

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await create_timer(0.2).timeout

	_check_assets()
	_check_view()
	_check_slash()
	_check_fireball()
	_check_freeze()
	_check_coins()
	_check_speed()
	_check_input()
	await _check_cleanup()

	if _fails.is_empty():
		print("PIXEL_VFX_SMOKE_OK checks=all")
		quit(0)
	else:
		for f in _fails:
			printerr("PIXEL VFX SMOKE FAIL: ", f)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails.append(message)

func _check_assets() -> void:
	var lib: FxLibrary = main.get_lib()
	_check(lib.errors.is_empty(), "asset loader errors: %s" % str(lib.errors))
	_check(lib.defs.size() == 6, "expected 6 sheets, got %d" % lib.defs.size())

	var slash: Dictionary = lib.get_def("slash")
	_check(slash.get("frame_count", 0) == 25, "slash frame count: %s" % slash.get("frame_count"))
	_check(slash.get("frame_size") == Vector2i(164, 108), "slash frame size")
	_check(absf(float(slash.get("duration", 0.0)) - 25.0 / 30.0) < 0.001, "slash duration")
	_check(slash.get("pivot") == Vector2(44, 92), "slash pivot")

	var fire: Dictionary = lib.get_def("fireball")
	_check(fire.get("frame_count", 0) == 36, "fireball frame count")
	_check(absf(float(fire.get("duration", 0.0)) - 1.2) < 0.001, "fireball duration")
	_check(bool(fire.get("loop", false)), "fireball must loop")

	var freeze: Dictionary = lib.get_def("freeze")
	_check(freeze.get("frame_count", 0) == 121, "freeze frame count")
	_check(freeze.get("frame_size") == Vector2i(176, 128), "freeze frame size")
	_check(absf(float(freeze.get("duration", 0.0)) - 121.0 / 30.0) < 0.01, "freeze duration")

	var coin: Dictionary = lib.get_def("coin")
	_check(coin.get("frame_count", 0) == 48, "coin frame count")
	_check(bool(coin.get("loop", false)), "coin must loop")
	_check(coin.get("frame_size") == Vector2i(56, 56), "coin frame size")

	var burst: Dictionary = lib.get_def("burst")
	_check(burst.get("frame_count", 0) == 42, "collect burst frame count")
	var explosion: Dictionary = lib.get_def("explosion")
	_check(explosion.get("frame_count", 0) == 163, "explosion frame count")
	_check(explosion.get("pivot") == Vector2(150, 196), "explosion pivot")

	# every texture is importable and non-empty
	for key in lib.defs:
		var d: Dictionary = lib.get_def(key)
		var tex: Texture2D = d["texture"]
		_check(tex != null and tex.get_width() > 0, "texture missing for %s" % key)

func _check_view() -> void:
	var vp: SubViewport = main.get_world_viewport()
	_check(vp.size == Vector2i(640, 360), "world viewport size %s" % str(vp.size))
	var display: TextureRect = main.get_display()
	_check(display.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "display is not nearest")
	_check(display.texture == vp.get_texture(), "display does not show world viewport")
	_check(main.get_hud() != null, "HUD missing")
	_check(main.get_world().dummy != null, "dummy missing")
	_check(main.get_world().knight != null, "knight missing")
	_check(main.get_world().coins.size() == 4, "expected 4 coins")
	_check(main.get_world().active_coin_count() == 4, "coins are not active at start")

func _check_slash() -> void:
	main.reset_all()
	main.tick(0.5)
	var ok: bool = main.trigger_slash()
	_check(ok, "slash trigger rejected")
	_check(main.get_active_fx_count() == 1, "slash fx not spawned")
	_check(main.get_fx_count("slash") == 1, "slash fx count")
	var fx: SpriteFX = main.get_last_fx()
	_check(fx != null and fx.frame_count == 25 and fx.loop == false, "slash fx not one-shot")
	main.tick(0.1)
	_check(main.get_hitstop() == 0.0, "hit-stop started before contact")
	main.tick(0.1)
	_check(main.get_dummy().flash > 0.4, "dummy did not flash on slash hit")
	_check(main.get_hitstop() > 0.0, "slash hit-stop missing")
	_check(main.get_fx_count("slash") == 1, "slash fx ended too early")
	main.tick(1.2)
	_check(main.get_active_fx_count() == 0, "slash fx was not cleaned up")
	_check(main.get_world().popups.is_empty(), "slash popup was not cleaned up")
	print("SMOKE slash ok fx=25 frames duration=0.833s cleanup=yes")

func _check_fireball() -> void:
	main.reset_all()
	main.tick(0.2)
	var ok: bool = main.trigger_fireball()
	_check(ok, "fireball trigger rejected")
	_check(main.has_projectile(), "fireball projectile missing")
	main.tick(0.5)
	_check(not main.has_projectile(), "fireball projectile did not hit")
	_check(main.get_fx_count("explosion") == 1, "explosion not spawned")
	_check(main.get_dummy().burn_remaining > 1.0, "burn status not applied")
	_check(main.get_dummy().is_burning(), "dummy not burning")
	main.tick(3.6)
	_check(main.get_fx_count("explosion") == 0, "explosion not cleaned up")
	_check(not main.get_dummy().is_burning(), "burn did not expire")
	print("SMOKE fireball ok projectile=hit explosion=yes burn=3.0s cleanup=yes")

func _check_freeze() -> void:
	main.reset_all()
	main.tick(0.2)
	var ok: bool = main.trigger_freeze()
	_check(ok, "freeze trigger rejected")
	_check(main.get_fx_count("freeze") == 1, "freeze fx missing")
	var before: float = main.get_dummy().frozen_remaining
	_check(absf(before - 2.9) < 0.05, "freeze timer not 2.9s: %.2f" % before)
	main.tick(1.0)
	var mid: float = main.get_dummy().frozen_remaining
	_check(mid < before and mid > 1.5, "freeze timer did not tick: %.2f" % mid)
	_check(main.get_fx_count("freeze") == 1, "freeze fx ended before status")
	main.tick(2.2)
	_check(not main.get_dummy().is_frozen(), "freeze status did not expire")
	_check(main.get_fx_count("freeze") == 1, "freeze thaw was cut short")
	main.tick(1.2)
	_check(main.get_fx_count("freeze") == 0, "freeze fx not cleaned up")
	print("SMOKE freeze ok timer=2.9s fx=4.03s thaw=yes cleanup=yes")

func _check_coins() -> void:
	main.reset_all()
	main.tick(0.4)
	_check(main.get_score() == 0, "score not zero at reset")
	var n: int = main.collect_all_coins()
	_check(n == 4, "expected 4 coins collected, got %d" % n)
	_check(main.get_score() == 40, "score after 4 coins: %d" % main.get_score())
	_check(main.get_world().active_coin_count() == 0, "coins not marked collected")
	var n2: int = main.collect_all_coins()
	_check(n2 == 0, "coins counted twice (second collect returned %d)" % n2)
	_check(main.get_score() == 40, "coin double-count: score %d" % main.get_score())
	main.tick(0.4)
	_check(main.get_fx_count("burst") == 4, "expected 4 collect bursts, got %d" % main.get_fx_count("burst"))
	_check(main.get_world().popups.size() == 4, "expected 4 +10 popups")
	main.tick(2.6)
	_check(main.get_world().active_coin_count() == 4, "coins did not respawn")
	_check(main.get_fx_count("burst") == 0, "collect bursts not cleaned up")
	_check(main.get_world().popups.is_empty(), "coin popups not cleaned up")
	print("SMOKE coins ok +40 once=yes bursts=4 respawn=2.6s cleanup=yes")

func _check_speed() -> void:
	main.reset_all()
	main.tick(0.3)
	main.set_speed(2.0)
	_check(absf(main.get_speed() - 2.0) < 0.001, "speed not set to 2x")
	_check(main.trigger_slash(), "slash trigger failed at 2x")
	var fx: SpriteFX = main.get_last_fx()
	var t0: float = fx.time
	main.tick(0.05)
	var t1: float = fx.time
	_check(absf((t1 - t0) - 0.10) < 0.002, "2x playback advanced %.3f (want 0.10)" % (t1 - t0))
	main.set_speed(0.5)
	main.tick(0.2)
	var t2: float = fx.time
	_check(t2 > t1 and absf((t2 - t1) - 0.10) < 0.002, "0.5x playback advanced %.3f (want 0.10)" % (t2 - t1))
	_check(absf(main.get_hud().speed - 0.5) < 0.01, "HUD speed state not updated")
	main.set_speed(1.0)
	main.tick(2.0)
	print("SMOKE speed ok 2x=0.10s/tick 0.5x=0.10s/tick 1x=restored")

func _check_input() -> void:
	main.reset_all()
	main.tick(0.4)
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	main._unhandled_input(key)
	main.tick(0.05)
	_check(main.get_fx_count("slash") == 1, "keyboard 1 did not trigger slash")
	main.reset_all()
	main.tick(0.4)
	var key5 := InputEventKey.new()
	key5.keycode = KEY_5
	key5.pressed = true
	main._unhandled_input(key5)
	_check(absf(main.get_speed() - 0.5) < 0.01, "keyboard 5 did not select 0.5x")
	var hud: PixelVfxHud = main.get_hud()
	_check(hud._button_at(Vector2(140, 645)) == 0, "slash button hit rect")
	_check(hud._button_at(Vector2(362, 645)) == 1, "fire button hit rect")
	_check(hud._button_at(Vector2(578, 645)) == 2, "freeze button hit rect")
	_check(hud._button_at(Vector2(794, 645)) == 3, "coin button hit rect")
	_check(hud._speed_at(Vector2(1040, 645)) == 0, "0.5x button hit rect")
	_check(hud._speed_at(Vector2(1120, 645)) == 1, "1x button hit rect")
	_check(hud._speed_at(Vector2(1200, 645)) == 2, "2x button hit rect")
	main.reset_all()
	print("SMOKE input ok keyboard=1/5 buttons=4+3 hit-rects")

func _check_cleanup() -> void:
	main.reset_all()
	main.tick(10.0)
	await process_frame
	await process_frame
	_check(main.get_active_fx_count() == 0, "effects remain after 10s")
	_check(main.get_world().popups.is_empty(), "popups remain after 10s")
	_check(not main.has_projectile(), "projectile remains after reset")
	_check(not main.get_dummy().is_frozen(), "freeze status remains after reset")
	_check(not main.get_dummy().is_burning(), "burn status remains after reset")
	_check(main.get_world().fx_layer.get_child_count() == 0, "fx layer still has children")
	_check(main.get_world().active_coin_count() == 4, "coins not restored after reset")
	print("SMOKE cleanup ok active_fx=0 popups=0 projectile=none statuses=clear")
