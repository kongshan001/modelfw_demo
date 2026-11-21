extends SceneTree

# Real-GPU 1920x1080 screenshots (offscreen SubViewport, own World3D).
#   godot --path . -s tools/screenshot_magic_vfx.gd
# Each pose is staged through the demo's public/debug API; waits are real-time
# because GPUParticles3D simulate on the GPU.

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)

var vp: SubViewport
var main

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	vp = SubViewport.new()
	vp.name = "ShotViewport"
	vp.size = SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	main = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main)
	await process_frame
	await create_timer(1.2).timeout
	main.capture_mode = true
	main.display_still = true
	main.auto_demo = false
	main.stats_visible = true
	main.hud.queue_redraw()

	main.reset_all()
	main.auto_demo = false
	await _wait(0.8)
	await _shot("01_overview")

	# 02 — ember charge
	main.switch_spell(0)
	main.aim_at_dummy(0)
	main.begin_charge(true)
	await _wait(0.9)
	await _shot("02_charge_ember")

	# 03 — ember mid-flight, frozen so the trail is readable in a still
	main.reset_all()
	main.auto_demo = false
	main.switch_spell(0)
	main.aim_dummy = null
	main.hover_dummy = null
	main.hud.clear_popups()
	main.fire_at_ground(7.5, -3.0, 1.2)
	await _wait(0.20)
	main.still_freeze = true
	await _wait(0.06)
	await _shot("03_flight_ember")
	main.still_freeze = false
	await _wait(1.2)

	# 04 — ember impact, frozen just after the flash starts
	main.reset_all()
	main.auto_demo = false
	main.switch_spell(0)
	main.aim_at_dummy(0)
	main.fire_at_dummy(0, 1.2)
	await _await_impact(3.0)
	main.still_freeze = true
	await _wait(0.45)
	await _shot("04_impact_ember")
	main.still_freeze = false
	await _wait(1.2)

	# 05 — arcane mid-flight
	main.reset_all()
	main.auto_demo = false
	main.switch_spell(1)
	main.fire_at_ground(7.0, 2.0, 1.0)
	await _wait(0.18)
	main.still_freeze = true
	await _wait(0.06)
	await _shot("05_flight_arcane")
	main.still_freeze = false
	await _wait(1.2)

	# 06 — arcane impact
	main.reset_all()
	main.auto_demo = false
	main.switch_spell(1)
	main.aim_at_dummy(1)
	main.fire_at_dummy(1, 1.0)
	await _await_impact(3.0)
	main.still_freeze = true
	await _wait(0.4)
	await _shot("06_impact_arcane")
	main.still_freeze = false
	await _wait(1.2)

	# 07 — frost impact
	main.reset_all()
	main.auto_demo = false
	main.switch_spell(2)
	main.aim_at_dummy(2)
	main.fire_at_dummy(2, 1.15)
	await _await_impact(3.0)
	main.still_freeze = true
	await _wait(0.4)
	await _shot("07_impact_frost")
	main.still_freeze = false
	await _wait(1.2)

	# 08 — slow-mo ember impact (live slow-mo)
	main.reset_all()
	main.auto_demo = false
	main.switch_spell(0)
	main.set_slowmo(true)
	main.aim_at_dummy(0)
	main.fire_at_dummy(0, 1.25)
	await _await_impact(4.0)
	main.still_freeze = true
	await _wait(0.5)
	await _shot("08_slowmo_ember")
	main.still_freeze = false
	main.set_slowmo(false)
	await _wait(1.0)

	# 09 — three spells converging (frozen)
	main.reset_all()
	main.auto_demo = false
	main.switch_spell(0)
	main.fire_at_dummy(0, 1.2)
	await _wait(0.05)
	main.switch_spell(1)
	main.fire_at_dummy(1, 1.0)
	await _wait(0.05)
	main.switch_spell(2)
	main.fire_at_dummy(2, 1.1)
	await _wait(0.12)
	main.still_freeze = true
	await _wait(0.06)
	await _shot("09_three_spells")
	main.still_freeze = false
	await _await_impact(3.0)
	main.still_freeze = true
	await _wait(0.4)
	await _shot("10_combo_impacts")
	main.still_freeze = false

	print("MAGIC_VFX_SHOTS_OK files=10 size=%dx%d" % [SIZE.x, SIZE.y])
	quit(0)

func _await_impact(timeout: float) -> void:
	var t := 0.0
	while main.impacts.is_empty() and t < timeout:
		await _wait(0.02)
		t += 0.02
	await _wait(0.02)

# wall-clock wait that ignores Engine.time_scale (required while frozen)
func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", shot_name, " ", image.get_width(), "x", image.get_height())
