extends SceneTree

# Deterministic 10 s / 30 fps capture at 1280x720 for the GIF/MP4.
# The scene runs in an offscreen SubViewport with its _process disabled; each
# frame is advanced by exactly 1/30 s and saved to /tmp/pixel_vfx_frames.
#
#   godot --path . -s tools/capture_pixel_vfx.gd

const OUT := "/tmp/pixel_vfx_frames"
const FPS := 30
const FRAMES := 300
const SIZE := Vector2i(1280, 720)
const TICK := 1.0 / 30.0

var vp: SubViewport
var main

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_clear_dir()
	vp = SubViewport.new()
	vp.name = "CaptureViewport"
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_2d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	main = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main)
	await process_frame
	await create_timer(0.4).timeout
	main.enable_capture_mode()
	main.reset_all()
	await process_frame

	for frame in FRAMES:
		_timeline(frame)
		main.tick(TICK)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := vp.get_texture().get_image()
		var path := "%s/frame_%03d.png" % [OUT, frame]
		var err := image.save_png(path)
		if err != OK:
			printerr("failed to save ", path, ": ", err)
		if frame % 30 == 0:
			print("FRAME ", frame, " t=", "%.1f" % (float(frame) / FPS))
	print("PIXEL_VFX_FRAMES_OK frames=%d size=%dx%d fps=%d" % [FRAMES, SIZE.x, SIZE.y, FPS])
	quit(0)

func _timeline(frame: int) -> void:
	if frame == 30:
		main.trigger_slash()          # 1.0 s — slash
	elif frame == 60:
		main.trigger_fireball()       # 2.0 s — projectile + explosion + burn
	elif frame == 90:
		main.trigger_freeze()         # 3.0 s — ice block + status timer
	elif frame == 120:
		main.trigger_coins()          # 4.0 s — four-coin collect cascade
	elif frame == 150:
		main.trigger_slash()          # 5.0 s — combo: slash
	elif frame == 162:
		main.trigger_fireball()       # 5.4 s — combo: fireball
	elif frame == 174:
		main.trigger_freeze()         # 5.8 s — combo: freeze
	elif frame == 212:
		main.trigger_coins()          # 7.1 s — respawned coins (2nd cascade)
	elif frame == 240:
		main.set_speed(2.0)           # 8.0 s — 2x speed demo
	elif frame == 242:
		main.trigger_slash()
	elif frame == 252:
		main.trigger_fireball()
	elif frame == 270:
		main.set_speed(1.0)           # 9.0 s — back to 1x

func _clear_dir() -> void:
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for file in dir.get_files():
		if file.begins_with("frame_") and file.ends_with(".png"):
			DirAccess.remove_absolute(OUT + "/" + file)
