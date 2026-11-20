extends SceneTree

# Real-GPU frame-rate probe. Disables vsync, runs a busy wave-5 fight for
# 360 frames and reports average / 1% style low FPS.
# Run: godot --path godot-slot-defense --resolution 1280x720 -s tools/perf_slot.gd

const WARMUP := 40
const SAMPLES := 360

var _scene: Node
var _frames := 0
var _total := 0.0
var _worst := 0.0
var _measuring := false


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	_scene.set_process(false)
	_scene.start_run(20261119)
	_scene.debug_add_gold(30)
	for t in ["blade", "bow", "shield", "steed", "orb"]:
		_scene.debug_summon(t)
	_scene.debug_summon("blade")
	_scene.debug_summon("bow")
	_scene.debug_start_wave(5)
	_scene.spawn_queue.clear()
	for i in 14:
		_scene.debug_spawn("grunt" if i % 3 else "brute")
		_scene.enemies[_scene.enemies.size() - 1].x = 780.0 + i * 34.0
	_scene.set_process(true)
	await create_timer(0.7).timeout
	# stage busy VFX so the probe measures the busy path, not the quiet intro
	for i in 6:
		_scene._burst(Vector2(800 + i * 60, 480), Color("#ffd9a0"), 18)
	_scene._coin_burst(Vector2(940, 470), 10)
	_scene._confetti(30)
	_measuring = true


func _process(delta: float) -> bool:
	if not _measuring:
		return false
	_frames += 1
	if _frames <= WARMUP:
		return false
	_total += delta
	_worst = maxf(_worst, delta)
	if _frames >= WARMUP + SAMPLES:
		var avg := float(SAMPLES) / maxf(0.0001, _total)
		var low := 1.0 / maxf(0.0001, _worst)
		print("SLOT_FPS avg=%.1f low=%.1f frames=%d" % [avg, low, SAMPLES])
		var ok := avg >= 30.0
		print("SLOT_FPS_OK" if ok else "SLOT_FPS_LOW")
		quit(0 if ok else 1)
	return false
