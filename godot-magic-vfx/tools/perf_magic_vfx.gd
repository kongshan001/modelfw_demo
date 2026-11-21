extends SceneTree

# Real-GPU FPS benchmark with an in-process minimal-3D baseline.
#   godot --path . -s tools/perf_magic_vfx.gd            # 1280x720 window
#   godot --path . -s tools/perf_magic_vfx.gd -- --1080  # 1920x1080 offscreen
# Prints PERF lines (avg/min FPS, slow frames, draw calls, particles).
# The baseline makes the machine's OS/GPU load visible, so the demo cost can
# be read relative to the same machine instead of as an absolute number.

var host: Node
var vp: SubViewport
var main
var is_1080 := false

func _initialize() -> void:
	is_1080 = "--1080" in OS.get_cmdline_user_args()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	if is_1080:
		vp = SubViewport.new()
		vp.size = Vector2i(1920, 1080)
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		host = vp
	else:
		host = root

	main = load("res://scenes/main.tscn").instantiate()
	host.add_child(main)
	await _frames(6)
	await _wait(4.0) # shader/font warm-up
	main.capture_mode = true
	main.display_still = true
	main.auto_demo = false
	main.stats_visible = true

	# warm every material family + impacts
	main.switch_spell(0)
	main.fire_at_ground(-1.0, 1.0, 1.0)
	await _wait(0.9)
	main.switch_spell(1)
	main.fire_at_ground(0.0, 0.0, 1.0)
	await _wait(0.6)
	main.switch_spell(2)
	main.fire_at_ground(2.0, -1.0, 1.0)
	await _wait(1.5)
	main.reset_all()
	main.auto_demo = false
	main.capture_mode = true
	main.switch_spell(0)
	await _wait(0.6)

	await _measure("IDLE_%d" % _res(), 4.0, false, 0.0)
	await _measure("NORMAL_%d" % _res(), 8.0, true, 2.2)
	await _measure("STRESS_%d" % _res(), 8.0, true, 0.85)

	main.queue_free()
	await _frames(3)
	await _wait(0.5)
	_build_baseline()
	await _wait(1.5)
	await _measure("BASELINE_%d" % _res(), 3.0, false, 0.0)
	print("PERF_DONE viewport=%s" % ("1920x1080 SubViewport" if is_1080 else "1280x720 window"))
	quit(0)

func _res() -> int:
	return 1080 if is_1080 else 720

func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _measure(label: String, seconds: float, combat: bool, interval: float) -> void:
	var start := Time.get_ticks_msec()
	var last := start
	var frames := 0
	var slow := 0
	var max_dt := 0.0
	var next_cast := start
	var cast_i := 0
	while true:
		var now := Time.get_ticks_msec()
		var elapsed := float(now - start) / 1000.0
		if elapsed >= seconds:
			break
		if combat and now >= next_cast:
			main.switch_spell(cast_i % 3)
			main.fire_at_dummy(cast_i % 3, 1.0)
			cast_i += 1
			next_cast = now + int(interval * 1000.0)
		await process_frame
		frames += 1
		var now2 := Time.get_ticks_msec()
		var dt := float(now2 - last)
		last = now2
		if dt > 100.0:
			slow += 1
		max_dt = maxf(max_dt, dt)
	var total := float(Time.get_ticks_msec() - start) / 1000.0
	var avg := float(frames) / maxf(total, 0.001)
	var min_fps := 1000.0 / maxf(max_dt, 0.001)
	var draw := 0
	var parts := 0
	if is_instance_valid(main) and main.is_inside_tree():
		draw = main.draw_calls
		parts = main.particles_now
	print("PERF %s avg=%.2f min=%.2f slow=%d frames=%d draw=%d particles=%d" % [
		label, avg, min_fps, slow, frames, draw, parts])

func _build_baseline() -> void:
	var n := Node3D.new()
	n.name = "Baseline"
	host.add_child(n)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.4, 4.0)
	n.add_child(cam)
	cam.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.5
	n.add_child(light)
	var cube := MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	n.add_child(cube)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_mi.mesh = pm
	floor_mi.position.y = -0.5
	n.add_child(floor_mi)
