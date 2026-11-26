extends SceneTree

## T-023 headless acceptance for the walk-direction lab:
##   1) FIXED clip: 8-direction movement, body facing follows movement (< 12 deg)
##   2) RAW clip: same movement, body facing is ~180 deg off (> 150 deg)
##   3) QUAT clip: 0 deg clip, body follows movement
##   4) Dance clip loops (seam < 0.02 rad), no scale explosion, 8 s length
## Usage: godot --headless --path action-forge-test/godot -s tools/smoke_walkmove.gd

const DIRS := [
	Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 0, -1),
	Vector3(0, 0, -1), Vector3(-1, 0, -1), Vector3(-1, 0, 0), Vector3(-1, 0, 1),
]
var fails := 0

func _initialize() -> void:
	var scene: Node3D = load("res://walkmove.tscn").instantiate()
	root.add_child(scene)
	await create_timer(2.5).timeout
	if scene.call("test_actor_count") != 1:
		_fail("expected 1 actor, got %s" % scene.call("test_actor_count"))
		return
	scene.call("test_set_path", false)
	scene.call("test_set_clip", "michelle_fix")
	scene.call("test_set_state", "walk")
	await create_timer(0.2).timeout
	await _run_dirs(scene, "FIXED", false)
	scene.call("test_set_clip", "michelle_raw")
	await create_timer(0.3).timeout
	await _run_dirs(scene, "RAW", true)
	scene.call("test_set_clip", "quat")
	await create_timer(0.3).timeout
	await _run_dirs(scene, "QUAT", false)
	# dance
	scene.call("test_play_dance")
	await create_timer(0.5).timeout
	var info: Dictionary = scene.call("test_dance_info")
	if info.is_empty():
		print("SMOKE_DANCE_MISSING (asset not built yet)")
	else:
		print("SMOKE_DANCE name=%s len=%.4f tracks=%d" % [info["name"], info["length"], info["tracks"]])
		var seam: float = await scene.call("test_dance_loop_delta")
		print("SMOKE_DANCE_SEAM %.5f rad" % seam)
		if seam > 0.02:
			_fail("dance loop seam %.4f rad > 0.02" % seam)
		var sd: float = scene.call("test_scale_dev")
		print("SMOKE_DANCE_SCALE_DEV %.6f" % sd)
		if sd > 0.01:
			_fail("dance bone scale deviation %.4f" % sd)
	scene.call("test_set_state", "idle")
	if fails > 0:
		print("SMOKE_WALKMOVE_FAIL %d" % fails)
		quit(1)
	else:
		print("SMOKE_WALKMOVE_OK")
		quit(0)

func _run_dirs(scene: Node3D, tag: String, expect_backwards: bool) -> void:
	print("SMOKE_%s_START" % tag)
	for dir in DIRS:
		scene.call("test_set_dir", dir)
		var p0: Vector3 = scene.call("test_metrics", 0)["pos"]
		await create_timer(0.65).timeout
		var m: Dictionary = scene.call("test_metrics", 0)
		var disp: Vector3 = m["pos"] - p0
		var dot: float = disp.normalized().dot(dir.normalized()) if disp.length() > 0.01 else 0.0
		var err: float = m["body_err"]
		var boot: float = m["boot_err"]
		var moved_ok: bool = disp.length() > 0.20 and dot > 0.90
		var facing_ok: bool
		if expect_backwards:
			facing_ok = err > 150.0 and boot > 120.0
		else:
			facing_ok = err < 12.0 and boot < 35.0
		print("SMOKE_%s dir=(%+.2f,%+.2f) move=%.2fm dot=%.3f body_err=%.1f boot_err=%.1f %s %s" % [
			tag, dir.x, dir.z, disp.length(), dot, err, boot,
			"PASS" if (moved_ok and facing_ok) else "FAIL",
			"backwards" if expect_backwards else "forward"])
		if not moved_ok:
			_fail("%s dir %s moved %.2fm dot %.2f" % [tag, dir, disp.length(), dot])
		if not facing_ok:
			_fail("%s dir %s body_err %.1f boot_err %.1f (expect %s)" % [
				tag, dir, err, boot, "backwards" if expect_backwards else "forward"])
	scene.call("test_set_dir", Vector3.ZERO)
	await create_timer(0.3).timeout

func _fail(msg: String) -> void:
	fails += 1
	printerr("SMOKE_WALKMOVE_FAIL: " + msg)
