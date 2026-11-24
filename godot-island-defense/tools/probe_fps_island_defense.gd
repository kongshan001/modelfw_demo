extends SceneTree
## 真实 GPU 帧率探针：在 1280×720 与 1920×1080 的 SubViewport 中跑同一场混战。
## 用法：godot --path godot-island-defense -s tools/probe_fps_island_defense.gd

const OUT := "res://docs/fps.txt"

var vp: SubViewport
var game


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lines: Array[String] = []
	lines.append("Mistbound Watch FPS probe")
	lines.append("Godot: 4.6.stable / renderer: " + str(ProjectSettings.get_setting("rendering/renderer/rendering_method")))
	lines.append("GPU: " + RenderingServer.get_video_adapter_name())
	lines.append("")
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var fps := await _measure(size)
		lines.append("%dx%d: %.1f fps (600 frames, staged wave+combat)" % [size.x, size.y, fps])
		print("FPS %dx%d = %.1f" % [size.x, size.y, fps])
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	print("ISLAND_DEFENSE_FPS_OK")
	quit(0)


func _measure(size: Vector2i) -> float:
	if vp != null and is_instance_valid(vp):
		vp.queue_free()
		await process_frame
	vp = SubViewport.new()
	vp.size = size
	vp.size_2d_override = Vector2i(1280, 720)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(vp)
	game = load("res://scenes/main.tscn").instantiate()
	vp.add_child(game)
	for _i in range(20):
		await process_frame
	game.auto_simulate = true
	game.demo_mode = true
	game.debug_start_playing(0, true)
	game.debug_set_prep(0.0)
	game.debug_move_squad(0, Vector3(-4.0, 0, -1.0))
	game.debug_move_squad(1, Vector3(-8.0, 0, 4.0))
	game.debug_move_squad(2, Vector3(2.0, 0, -2.0))
	game.debug_launch_wave(1)
	for _i in range(30):
		await process_frame
	game.debug_spawn_enemy("chieftain", Vector3(1.0, 0, -1.5))
	game.debug_spawn_enemy("brute", Vector3(0.0, 0, -3.5))
	game.debug_spawn_enemy("brute", Vector3(3.0, 0, -4.0))
	game.debug_spawn_enemy("raider", Vector3(-2.5, 0, -3.0))
	game.debug_spawn_enemy("raider", Vector3(4.0, 0, -2.0))
	game.debug_spawn_enemy("skirmisher", Vector3(7.0, 0, -5.0))
	game.debug_select_squad(2, false)
	game.debug_focus_camera(Vector3(0, 0, 0), 22.0, -38.0, 48.0)
	for _i in range(20):
		await process_frame
	# 预热后计时 600 帧
	var start := Time.get_ticks_usec()
	for _i in range(600):
		await process_frame
	var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
	return 600.0 / maxf(0.001, elapsed)
