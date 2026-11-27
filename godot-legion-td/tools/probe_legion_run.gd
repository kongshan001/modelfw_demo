extends SceneTree

## Full-run probe: 8 towers Lv3 + auto recruit + auto pick upgrades, through all six waves.
## Run: godot --headless --path godot-legion-td -s tools/probe_legion_run.gd
## Last line: LEGION_TD_RUN_OK (or exit 1 with diagnostics)

const D := preload("res://scripts/legion_data.gd")

var game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 3:
		await process_frame
	game.start_run(90210)
	game.debug_add_resources(100000, 10000)
	for i in game.world.pads.size():
		game.select_pad(i)
		game.build_tower_at_selected(D.TOWER_ORDER[i % 3])
		game.upgrade_selected_tower()
		game.upgrade_selected_tower()
	game.clear_selection()
	for i in 3:
		game.pop_cap = 20
		game.cooldowns.guard = 0.0
		game.recruit("guard")
		game.cooldowns.bolt = 0.0
		game.recruit("bolt")
	print("RUN towers=%d units=%d pop=%d/%d" % [
		game.towers.size(), game.units.size(), game.pop_used, game.pop_cap])

	for wave in range(1, D.WAVES.size() + 1):
		game.debug_start_wave(wave)
		var t := 0.0
		while t < 70.0 and game.ui_state == "wave":
			game.advance(0.1)
			t += 0.1
		print("RUN wave=%d state=%s t=%.1f core=%.0f enemies=%d towers=%d kills=%d" % [
			wave, game.ui_state, t, game.core_hp, game.enemies.size(),
			game.towers.size(), game.kills])
		if game.ui_state == "lose":
			printerr("RUN_FAIL lost at wave ", wave)
			quit(1)
			return
		if game.ui_state == "upgrade":
			if not game.pick_upgrade(0):
				printerr("RUN_FAIL upgrade pick failed at wave ", wave)
				quit(1)
				return
		if wave < D.WAVES.size():
			game.debug_add_resources(2000, 200)
			for i in 4:
				game.cooldowns.guard = 0.0
				game.cooldowns.bolt = 0.0
				game.pop_cap = 20
				game.recruit("guard")
				game.recruit("bolt")
		await process_frame

	if game.ui_state == "win":
		print("RUN_RESULT=WIN kills=%d gold=%d essence=%d time=%.1f" % [
			game.kills, game.gold_earned, game.essence_earned, game.run_time])
		print("LEGION_TD_RUN_OK")
		quit(0)
	else:
		printerr("RUN_FAIL final state=", game.ui_state, " core=", game.core_hp)
		quit(1)
