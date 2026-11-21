extends SceneTree

# Headless smoke test for Magic Projectile Lab.
#   godot --headless --path . -s tools/smoke_magic_vfx.gd
# Covers: spell table, charge/release, projectile spawn, impact creation,
# dummy damage/break/respawn, switching, slow-mo, reset and FX cleanup.
# Last line is MAGIC_VFX_SMOKE_OK on success.

var _fails: Array[String] = []
var main

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await create_timer(0.4).timeout
	main.capture_mode = true
	main.auto_demo = false
	main.demo_charging = false

	_check_setup()
	await _check_charge_and_flight()
	await _check_break_and_respawn()
	_check_switching()
	await _check_cleanup_and_reset()
	await _check_slowmo()

	if _fails.is_empty():
		print("MAGIC_VFX_SMOKE_OK checks=all")
		main.queue_free()
		await process_frame
		await create_timer(1.6).timeout
		quit(0)
	else:
		for f in _fails:
			printerr("MAGIC VFX SMOKE FAIL: ", f)
		main.queue_free()
		await process_frame
		await create_timer(1.6).timeout
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _check_setup() -> void:
	_check(main.spell.size() > 0, "no active spell")
	_check(main.dummies.size() == 3, "expected 3 dummies, got %d" % main.dummies.size())
	_check(main.caster != null, "caster missing")
	_check(main.hud != null, "hud missing")
	for d in main.dummies:
		_check(d.alive and d.hp == 3, "dummy not initialised")
	_check(main.get_vfx_root() != null, "fx root missing")
	_check(main.BUDGET == 2400, "unexpected particle budget")

func _check_charge_and_flight() -> void:
	main.switch_spell(0)
	main.aim_at_dummy(0)
	main.begin_charge(true)
	await create_timer(0.35).timeout
	_check(main.charging, "begin_charge did not start charging")
	_check(main.charge > 0.15, "charge did not accumulate (%.2f)" % main.charge)
	_check(main.caster.charging, "caster not in charging state")
	var before_hp: int = main.dummies[0].hp
	main.release_charge()
	await process_frame
	_check(not main.charging, "release did not stop charging")
	_check(main.projectiles.size() >= 1, "release did not spawn a projectile")
	var proj = main.projectiles.back()
	_check(proj.spell.id == "ember", "projectile spell mismatch")
	_check(proj.sparks != null and proj.puffs != null, "projectile particles missing")
	_check(proj.trail != null, "projectile trail missing")
	var waited := 0.0
	while main.impacts.is_empty() and waited < 3.0:
		await create_timer(0.03).timeout
		waited += 0.03
	_check(not main.impacts.is_empty(), "projectile never impacted")
	_check(main.dummies[0].hp == before_hp - 1, "dummy did not take damage (%d -> %d)" % [before_hp, main.dummies[0].hp])
	_check(main.hits >= 1, "hit counter not incremented")
	_check(main.particles_now > 0 or main._estimate_particles() > 0, "particle count empty during impact")

func _check_break_and_respawn() -> void:
	var d = main.dummies[1]
	main.switch_spell(1)
	main.aim_at_dummy(1)
	while d.hp > 0 and d.alive:
		main.fire_at_dummy(1, 1.0)
		var waited := 0.0
		while main.impacts.is_empty() and waited < 2.0:
			await create_timer(0.03).timeout
			waited += 0.03
		await create_timer(0.35).timeout
	_check(not d.alive, "dummy should be broken after 3 hits")
	_check(d.hp <= 0, "broken dummy hp=%d" % d.hp)
	_check(main.breaks >= 1, "break counter not incremented")
	# respawn after ~3.4 s
	await create_timer(3.8).timeout
	_check(d.alive, "dummy did not respawn")
	_check(d.hp == 3, "respawned dummy hp=%d" % d.hp)

func _check_switching() -> void:
	main.switch_spell(0)
	main.begin_charge(true)
	await create_timer(0.15).timeout
	main.switch_spell(2)
	_check(not main.charging, "switching spells should cancel charge")
	_check(main.spell.id == "frost", "switch to frost failed")
	_check(main.caster.spell.id == "frost", "caster spell not updated")
	main.switch_spell(1)
	_check(main.spell.id == "arcane", "switch to arcane failed")
	_check(main.spell_index == 1, "spell index not tracked")

func _check_cleanup_and_reset() -> void:
	# fire a few and let all transient FX expire
	main.switch_spell(0)
	for i in 3:
		main.fire_at_dummy(i, 1.2)
		await create_timer(0.12).timeout
	var waited := 0.0
	while not main.projectiles.is_empty() and waited < 6.0:
		await create_timer(0.05).timeout
		waited += 0.05
	waited = 0.0
	while not main.impacts.is_empty() and waited < 6.0:
		await create_timer(0.05).timeout
		waited += 0.05
	await create_timer(5.0).timeout
	var leftovers := 0
	var names := []
	for child in main.get_vfx_root().get_children():
		if is_instance_valid(child):
			leftovers += 1
			names.append("%s(%s)" % [child.name, child.get_class()])
	_check(leftovers == 0, "fx root leaked %d nodes after expiry: %s" % [leftovers, str(names)])
	_check(main.projectiles.is_empty(), "projectile array not pruned")

	# reset restores arena and clears runtime state
	main.set_slowmo(true)
	main.fire_at_ground(0.0, 0.0, 1.0)
	await create_timer(0.2).timeout
	main.reset_all()
	await process_frame
	await process_frame
	_check(main.projectiles.is_empty(), "reset left projectiles")
	_check(main.impacts.is_empty(), "reset left impacts")
	_check(not main.charging, "reset left charging")
	_check(not main.slowmo, "reset left slow-motion")
	for d in main.dummies:
		_check(d.alive and d.hp == 3, "reset did not restore dummy %d" % d.index)
	var leftover2 := 0
	for child in main.get_vfx_root().get_children():
		if is_instance_valid(child):
			leftover2 += 1
	_check(leftover2 == 0, "reset left %d fx nodes" % leftover2)

func _check_slowmo() -> void:
	main.set_slowmo(true)
	_check(main.slowmo and absf(Engine.time_scale - 0.25) < 0.001, "slow-mo not applied")
	await create_timer(0.1).timeout
	main.set_slowmo(false)
	_check(not main.slowmo and absf(Engine.time_scale - 1.0) < 0.001, "slow-mo not restored")
