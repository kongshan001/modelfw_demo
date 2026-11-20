extends SceneTree

# Balance probe: drives a full run headlessly with a simple policy.
# Run: godot --headless --path godot-slot-defense -s tools/playtest_slot.gd

const SEEDS := [11, 22, 33, 44, 55, 66, 77, 88]


func _initialize() -> void:
	var wins := 0
	var summary: Array[String] = []
	for s in SEEDS:
		var scene: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(scene)
		await process_frame
		scene.set_process(false)
		scene.start_run(s)
		var t := 0.0
		var spins := 0
		var last_wave := 0
		while t < 240.0 and scene.state != "win" and scene.state != "lose":
			if scene.wave != last_wave:
				print("  seed=%d wave=%d t=%.1f" % [s, scene.wave, t])
				last_wave = scene.wave
			if scene.state == "idle" or scene.state == "wave":
				if not scene.spinning and scene.gold >= scene.spin_cost:
					if scene.request_spin():
						spins += 1
			elif scene.state == "shop":
				if scene.gold >= 14:
					for i in 3:
						if scene.debug_buy(i):
							break
				scene.continue_shop()
			scene.debug_tick(0.1)
			t += 0.1
		if scene.state == "win":
			wins += 1
		summary.append("seed=%d state=%s t=%.1fs wave=%d hearts=%d units=%d spins=%d gold=%d" % [
			s, scene.state, t, scene.wave, scene.hearts, scene.units.size(), scene.stats.spins, scene.gold,
		])
		scene.queue_free()
		await process_frame
	for line in summary:
		print("PLAYTEST ", line)
	print("PLAYTEST_DONE wins=%d/%d" % [wins, SEEDS.size()])
	quit(0)
