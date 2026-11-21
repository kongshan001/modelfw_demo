extends SceneTree

# Fast 1280x720 visual probe (iterating on look/perf, not a deliverable).
#   godot --path . -s tools/probe_magic_vfx.gd

const OUT := "/tmp/magicprobe"
const SIZE := Vector2i(1280, 720)

var vp: SubViewport
var main

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	vp = SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	main = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main)
	await process_frame
	await create_timer(0.6).timeout
	main.capture_mode = true
	main.capture_badge = ""
	main.display_still = true
	main.auto_demo = false
	main.reset_all()
	await create_timer(0.5).timeout
	await _shot("overview")
	main.switch_spell(0)
	main.aim_at_dummy(0)
	main.begin_charge(true)
	await create_timer(0.8).timeout
	await _shot("charge")
	main.release_charge()
	await create_timer(0.12).timeout
	await _shot("flight")
	_await_impact()
	await create_timer(0.06).timeout
	await _shot("impact")
	await create_timer(0.8).timeout
	main.switch_spell(1)
	main.fire_at_dummy(1, 1.0)
	await create_timer(0.12).timeout
	await _shot("arcane_flight")
	_await_impact()
	await create_timer(0.1).timeout
	await _shot("arcane_impact")
	await create_timer(0.8).timeout
	main.switch_spell(2)
	main.fire_at_dummy(2, 1.1)
	_await_impact()
	await create_timer(0.1).timeout
	await _shot("frost_impact")
	print("MAGIC_VFX_PROBE_OK fps=%.1f" % main.fps_current)
	quit(0)

func _await_impact() -> void:
	var t := 0.0
	while main.impacts.is_empty() and t < 3.0:
		await create_timer(0.02).timeout
		t += 0.02
	await create_timer(0.03).timeout

func _shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(OUT + "/" + n + ".png")
	print("PROBE ", n, " fps=", snappedf(main.fps_current, 0.1))
