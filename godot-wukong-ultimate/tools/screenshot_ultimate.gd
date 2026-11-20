extends SceneTree

## Real-GPU still matrix. Run:
##   godot --path . --resolution 1280x720 -s tools/screenshot_ultimate.gd
## Writes docs/shots/*.png, including the before/after comparison.

const OUT := "res://docs/shots"

var vp: SubViewport
var scene: Node
var font: SystemFont
var extras: Array[Node] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/main.tscn").instantiate()
	vp.add_child(scene)
	await process_frame
	await create_timer(1.2).timeout
	scene.dummy.ai_enabled = false
	scene.set_controls_enabled(false)

	# 01 — hero front
	scene.set_hud_visible(false)
	scene.set_cinematic_camera(Vector3(2.15, 1.12, 0.15), Vector3(-1.2, 1.25, 3.5), 44.0)
	await create_timer(0.6).timeout
	await _shot("01_hero")

	# 02 — charge close-up
	scene.demo_charge(0.9)
	scene.set_cinematic_camera(Vector3(2.0, 1.45, 0.2), Vector3(-1.2, 1.20, 3.5), 44.0)
	await create_timer(0.85).timeout
	await _shot("02_charge")

	# 02b — ki wave in flight (beam tail)
	scene.player.debug_set_charge(0.0)
	scene.player.charging = false
	scene.player.state = "idle"
	scene.player.play_anim("Idle", 0.1)
	var aim: Vector3 = (scene.dummy.global_position - scene.player.global_position)
	aim.y = 0.0
	aim = aim.normalized()
	var origin2: Vector3 = scene.player.global_position + Vector3(0, 1.24, 0) + aim * 0.55
	var target2: Vector3 = scene.dummy.global_position + Vector3(0, 1.2, 0)
	var dir2: Vector3 = (target2 - origin2).normalized()
	var beam = scene.spawn_ki_at(origin2, dir2, 1.0, 120)
	beam.set_physics_process(false)
	beam.global_position = origin2 + dir2 * 3.0
	scene.set_cinematic_camera(Vector3(5.2, 2.3, 3.4), Vector3(0.0, 1.25, 0.4), 46.0)
	await create_timer(0.2).timeout
	await _shot("07_beam")
	beam.queue_free()

	# 03 — impact close-up on the sentinel
	scene.player.debug_set_charge(0.0)
	scene.player.charging = false
	scene.player.state = "idle"
	scene.player.play_anim("Idle", 0.1)
	scene.set_cinematic_camera(Vector3(5.4, 2.2, -0.1), Vector3(1.2, 1.10, -3.3), 46.0)
	await create_timer(0.4).timeout
	scene.demo_impact(1.0)
	await create_timer(0.16).timeout
	await _shot("03_impact")

	# 04 — gameplay / HUD
	scene.demo_reset()
	await create_timer(0.4).timeout
	scene.dummy.ai_enabled = false
	scene.hud.tutorial_muted = true
	scene.set_hud_visible(true)
	scene.set_cinematic_camera(Vector3(2.6, 2.1, 7.6), Vector3(-0.15, 1.15, 0.4), 52.0)
	scene.demo_charge(0.62)
	await create_timer(0.7).timeout
	await _shot("04_gameplay")

	# 05 — victory
	scene.player.debug_set_charge(0.0)
	scene.player.charging = false
	scene.clear_cinematic_camera()
	scene.elapsed = 4.2
	scene.hits = 3
	scene.max_combo = 3
	scene.combo = 3
	scene.combo_timer = 2.4
	scene.demo_victory()
	await create_timer(1.4).timeout
	await _shot("05_victory")

	# 06 — before / after
	scene.set_hud_visible(false)
	await _before_after()
	await _shot("06_before_after")

	print("WUKONG_ULT_SHOTS_OK")
	await _cleanup()
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT) + "/" + name + ".png")
	print("SHOT ", name)


func _before_after() -> void:
	# new hero (reuse the actual styled player, posed in Charge)
	scene.player.visible = true
	scene.player.global_position = Vector3(-1.55, 0.05, 0.0)
	scene.player.rotation.y = 0.0
	scene.player.charging = false
	scene.player.controls_enabled = false
	scene.player.state = "charge"
	scene.player.play_anim("Charge", 0.1)
	scene.player.set_physics_process(false)

	# legacy chibi
	var packed: PackedScene = load("res://assets/legacy/wukong_first.glb")
	var old: Node3D = packed.instantiate()
	old.name = "LegacyWukong"
	old.position = Vector3(1.55, 0.0, 0.0)
	old.rotation.y = -PI * 0.5
	scene.add_child(old)
	extras.append(old)
	var old_anim := old.find_children("*", "AnimationPlayer", true, false)
	if not old_anim.is_empty():
		var ap: AnimationPlayer = old_anim[0]
		ap.play("WukongRigAction")
		ap.seek(2.2, true)
		ap.pause()

	font = SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB",
		"Noto Sans CJK SC", "Microsoft YaHei", "Arial Unicode MS", "sans-serif"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY

	var l_new := Label3D.new()
	l_new.text = "极意 · 终极形态\nAFTER"
	l_new.font = font
	l_new.font_size = 26
	l_new.outline_size = 8
	l_new.outline_modulate = Color(0.01, 0.02, 0.04, 0.95)
	l_new.modulate = Color(0.98, 0.84, 0.52)
	l_new.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l_new.no_depth_test = true
	l_new.fixed_size = true
	l_new.pixel_size = 0.0018
	l_new.position = Vector3(-1.55, 2.75, 0.5)
	l_new.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene.add_child(l_new)
	extras.append(l_new)

	var l_old := Label3D.new()
	l_old.text = "首版 · 斗战形态\nBEFORE"
	l_old.font = font
	l_old.font_size = 26
	l_old.outline_size = 8
	l_old.outline_modulate = Color(0.01, 0.02, 0.04, 0.95)
	l_old.modulate = Color(0.78, 0.84, 0.95)
	l_old.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l_old.no_depth_test = true
	l_old.fixed_size = true
	l_old.pixel_size = 0.0018
	l_old.position = Vector3(1.55, 2.75, 0.5)
	l_old.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene.add_child(l_old)
	extras.append(l_old)

	scene.set_cinematic_camera(Vector3(0.0, 2.35, 8.6), Vector3(0.0, 1.35, 0.0), 42.0)
	await create_timer(0.7).timeout


func _cleanup() -> void:
	for e in extras:
		if is_instance_valid(e):
			e.queue_free()
	scene.queue_free()
	vp.queue_free()
	await process_frame
	await process_frame
