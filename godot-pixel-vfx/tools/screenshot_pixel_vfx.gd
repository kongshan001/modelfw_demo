extends SceneTree

# Real-GPU screenshots at 1920x1080. The scene is rendered into an offscreen
# SubViewport (the Mac display is smaller than 1080p), the 640x360 world is
# integer-scaled 3x, and the 1280x720 HUD is scaled 1.5x. Poses are advanced by
# exact 1/60 ticks while the main scene's _process is disabled.
#
#   godot --path . -s tools/screenshot_pixel_vfx.gd

const OUT := "res://docs/shots"
const TICK := 1.0 / 60.0
const SIZE := Vector2i(1920, 1080)
const HUD_SCALE := 1.5
const FPS_OVERRIDE := 41

var vp: SubViewport
var main

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	vp = SubViewport.new()
	vp.name = "ShotViewport"
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_2d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	main = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main)
	await process_frame
	await create_timer(0.4).timeout
	main.set_process(false)
	main.set_hud_ui_scale(HUD_SCALE)
	main.set_fps_override(FPS_OVERRIDE)
	await RenderingServer.frame_post_draw

	main.reset_all()
	_advance(1.2)
	await _shot("00_overview")

	main.reset_all()
	main.trigger_slash()
	_advance(0.30)
	await _shot("01_slash")

	main.reset_all()
	main.trigger_fireball()
	_advance(0.66)
	await _shot("02_fireball")

	main.reset_all()
	main.trigger_freeze()
	_advance(1.5)
	await _shot("03_freeze")

	main.reset_all()
	_advance(0.4)
	main.trigger_coins()
	_advance(0.22)
	await _shot("04_coins")

	main.reset_all()
	main.trigger_freeze()
	_advance(1.8)
	main.trigger_fireball()
	_advance(0.55)
	main.trigger_slash()
	_advance(0.24)
	await _shot("05_combo")

	main.reset_all()
	main.trigger_slash()
	main.tick(0.2)
	main.set_speed(2.0)
	main.trigger_fireball()
	_advance(0.45)
	await _shot("06_speed2x")

	# 07 — burn aftermath: explosion over, orange tint + embers + timer
	main.reset_all()
	main.trigger_fireball()
	_advance(2.8)
	await _shot("07_burn")

	main.reset_all()
	_advance(0.5)
	print("PIXEL_VFX_SHOTS_OK files=8 size=%dx%d" % [SIZE.x, SIZE.y])
	quit(0)

func _advance(seconds: float) -> void:
	var n := int(round(seconds / TICK))
	for i in n:
		main.tick(TICK)

func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path, " ", image.get_width(), "x", image.get_height())
