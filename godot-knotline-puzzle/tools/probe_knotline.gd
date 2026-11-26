extends SceneTree

# Real-GPU performance probe at the shipping 1280×720 resolution.
#   godot --path godot-knotline-puzzle --resolution 1280x720 -s tools/probe_knotline.gd
# Measures idle, full-rope and debug-marker FPS by wall clock.

const MAIN_SCENE := "res://scenes/main.tscn"
const Paths := preload("res://tools/demo_paths.gd")

var game: KnotGame


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(30, 30))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game = (load(MAIN_SCENE) as PackedScene).instantiate() as KnotGame
	root.add_child(game)
	await _frames(45)
	game.debug_set_capture_mode(true)
	game.debug_clear_toast()
	await _frames(30)

	var idle: Dictionary = await _measure(4.0)
	print("PROBE idle fps=%.1f draws=%d" % [idle["fps"], idle["draws"]])

	var p2: Array[Vector3] = Paths.for_level(game.levels[1])
	game.debug_load_level(1)
	game.debug_clear_toast()
	game.debug_set_path(p2, false)
	await _frames(20)
	var rope: Dictionary = await _measure(4.0)
	print("PROBE rope fps=%.1f draws=%d" % [rope["fps"], rope["draws"]])

	game.debug_set_debug(true)
	await _frames(20)
	var dbg: Dictionary = await _measure(3.0)
	print("PROBE debug fps=%.1f draws=%d" % [dbg["fps"], dbg["draws"]])
	game.debug_set_debug(false)

	# Isolate the expensive bits.
	game.camera_rig.camera.get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	await _frames(20)
	var nomsaa: Dictionary = await _measure(3.0)
	print("PROBE no_msaa fps=%.1f draws=%d" % [nomsaa["fps"], nomsaa["draws"]])

	var sun := game.world.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.shadow_enabled = false
	await _frames(20)
	var noshadow: Dictionary = await _measure(3.0)
	print("PROBE no_shadow fps=%.1f draws=%d" % [noshadow["fps"], noshadow["draws"]])

	game.debug_hide_hud(true)
	await _frames(20)
	var nohud: Dictionary = await _measure(3.0)
	print("PROBE no_hud fps=%.1f draws=%d" % [nohud["fps"], nohud["draws"]])

	print("KNOTLINE_PROBE_OK adapter=", RenderingServer.get_video_adapter_name())
	game.queue_free()
	await _frames(2)
	quit(0)


func _measure(seconds: float) -> Dictionary:
	var start := Time.get_ticks_usec()
	var frames := 0
	while float(Time.get_ticks_usec() - start) / 1_000_000.0 < seconds:
		await process_frame
		frames += 1
	var elapsed := float(Time.get_ticks_usec() - start) / 1_000_000.0
	return {
		"fps": float(frames) / maxf(0.001, elapsed),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
	}


func _frames(n: int) -> void:
	for i in n:
		await process_frame
