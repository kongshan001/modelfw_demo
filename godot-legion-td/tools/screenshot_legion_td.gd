extends SceneTree

## T-20261127-020 real-GPU art screenshots after the production art pass.
## Run: godot --path godot-legion-td -s tools/screenshot_legion_td.gd
## Output: docs/shots/after/*.png ; last line LEGION_TD_SHOTS_OK

const D := preload("res://scripts/legion_data.gd")
const Art := preload("res://scripts/legion_art.gd")
const Tower := preload("res://scripts/legion_tower.gd")
const OUT_DIR := "res://docs/shots/after/"
const SIZE := Vector2i(1920, 1080)
const UI_SCALE := 1.5

var sv: SubViewport
var game
var captured: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	sv = SubViewport.new()
	sv.size = SIZE
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(sv)
	game = load("res://scenes/main.tscn").instantiate()
	sv.add_child(game)
	for i in 12:
		await process_frame
	game.ui.scale = Vector2(UI_SCALE, UI_SCALE)
	game.debug_lock_camera = true
	game.set_process(false)

	# A0 — wide establishing: core + 3 portals + all lanes (for 25% thumbnail).
	game.restart_run(20261127)
	game.set_process(false)
	game.banner_t = 0.0
	game.clear_selection()
	game.ui.visible = false
	game.world.set_camera(Vector3(0, 0, 2), 98.0)
	await _warm()
	await _shot("00_wide_1920.png")
	game.ui.visible = true

	# A1 — default gameplay: core + squad + build pads + roads.
	game.world.set_camera(Vector3(0, 0, 18), 54.0)
	game.banner_t = 0.0
	game.select_all_units()
	await _warm()
	await _shot("01_overview_1920.png")

	# A2 — wave 4 melee: 6 towers + squad + mixed enemies.
	game.clear_selection()
	game.debug_add_resources(900, 90)
	for i in 6:
		game.select_pad(i)
		game.build_tower_at_selected(D.TOWER_ORDER[i % 3])
	game.debug_start_wave(4)
	game.units[0].global_position = Vector3(-4, 0, 13)
	game.units[1].global_position = Vector3(1, 0, 14)
	game.units[2].global_position = Vector3(4, 0, 11)
	game.units[3].global_position = Vector3(-1, 0, 10)
	for i in 7:
		var p: Vector3 = Vector3(-7 + i * 2.4, 0, 5 + (i % 3) * 2.5)
		game.debug_spawn_enemy("crawler" if i % 3 else "spitter", i % 3, p, 2.0, 0.2, 0.0)
	game.simulate(1.6)
	game.select_all_units()
	game.banner_t = 0.0
	game.world.set_camera(Vector3(0, 0, 12), 42.0)
	await _warm()
	await _shot("02_battle_1920.png")

	# A3 — hero Q: 3 rings + embers, damage numbers, no white flash.
	game.debug_add_resources(200, 20)
	for i in 5:
		var p: Vector3 = game.hero.global_position + Vector3(-6 + i * 3, 0, -4 - (i % 2) * 2)
		game.debug_spawn_enemy("crawler" if i % 2 == 0 else "spitter", i % 3, p, 2.2, 0.15, 0.0)
	game.simulate(0.4)
	game.world.set_camera(game.hero.global_position, 30.0)
	game.banner_t = 0.0
	game.hero_skill()
	game.simulate(0.26)
	await _warm(0.5)
	await _shot("03_hero_skill_1920.png")

	# A4 — build menu on an empty fixed pad.
	game.restart_run(777001)
	game.set_process(false)
	game.debug_add_resources(600, 60)
	for i in [0, 1, 3, 4]:
		game.select_pad(i)
		game.build_tower_at_selected(D.TOWER_ORDER[i % 3])
	game.clear_selection()
	game.select_pad(6)
	game.banner_t = 0.0
	game.world.set_camera(Vector3(-20, 0, -6), 42.0)
	await _warm()
	await _shot("04_build_1920.png")

	# A5 — upgrade draft.
	game.clear_selection()
	game.banner_t = 0.0
	game.debug_force_upgrade()
	await _warm()
	await _shot("05_upgrade_1920.png")

	# A7/A8 — win & lose (staged end screens, disclosed in after/README.md).
	game.pick_upgrade(0)
	game.wave_index = 6
	game.wave_def = D.wave_def(5)
	game.kills = 131
	game.gold_earned = 1024
	game.essence_earned = 86
	game.run_time = 129.8
	game.debug_win()
	await _warm()
	await _shot("07_win_1920.png")

	game.wave_index = 4
	game.wave_def = D.wave_def(3)
	game.kills = 68
	game.gold_earned = 540
	game.essence_earned = 41
	game.run_time = 96.4
	game.debug_lose()
	await _warm()
	await _shot("08_lose_1920.png")

	# A8 — three portals + emerging swarm.
	game.restart_run(424242)
	game.set_process(false)
	game.debug_add_resources(500, 50)
	game.debug_start_wave(2)
	game.simulate(3.0)
	game.clear_selection()
	game.banner_t = 0.0
	game.world.portal_pulse(0)
	game.world.portal_pulse(1)
	game.world.set_camera(Vector3(0, 0, -25), 58.0)
	await _warm()
	await _shot("09_portals_1920.png")

	# A9 — maximum zoom out on the same battle.
	game.world.set_camera(Vector3(0, 0, 4), 96.0)
	await _warm()
	await _shot("10_zoom96_1920.png")

	# P1 — core damage state (66% cracks / 33% darkening are implemented).
	game.restart_run(515151)
	game.set_process(false)
	game.ui.visible = false
	game.core_hp = 30
	game.world.set_core_ratio(0.30)
	game.world.set_camera(game.world.CORE_POS + Vector3(0, 0, -6), 38.0)
	await _warm(0.6)
	await _shot("15_core_damaged_1920.png")
	game.ui.visible = true

	# A10 — pure black silhouettes, no world, no HUD (four professions + enemies).
	await _silhouette_shot()

	# A11 — 3 tower types x Lv1/2/3 on a clean stage.
	await _tower_grid_shot()

	# A6/A13 — true 1280x720 HUD pass (UI at 1x).
	sv.size = Vector2i(1280, 720)
	game.ui.scale = Vector2.ONE
	game.ui.visible = true
	game.restart_run(720720)
	game.set_process(false)
	game.debug_add_resources(900, 90)
	for i in 5:
		game.select_pad(i)
		game.build_tower_at_selected(D.TOWER_ORDER[i % 3])
	game.debug_start_wave(4)
	game.simulate(1.2)
	game.banner_t = 0.0
	game.select_all_units()
	game.world.set_camera(Vector3(0, 0, 18), 46.0)
	await _warm(0.6)
	await _shot("13_battle_720.png")
	game.clear_selection()
	game.ui.set_help_visible(true)
	await _warm(0.5)
	await _shot("06_help_720.png")
	game.ui.set_help_visible(false)

	print("LEGION_SHOT_COUNT=", captured.size())
	for p in captured:
		print("LEGION_SHOT_FILE=", p)
	print("LEGION_TD_SHOTS_OK")
	game.queue_free()
	await process_frame
	sv.queue_free()
	quit(0)


# ------------------------------------------------------------------ silhouettes

func _silhouette_shot() -> void:
	game.restart_run(999001)
	game.set_process(false)
	game.clear_selection()
	game.banner_t = 0.0
	game.ui.visible = false
	# white env, no fog, no world geometry (keep camera + environment nodes)
	game.world.env.background_mode = Environment.BG_COLOR
	game.world.env.background_color = Color(0.93, 0.92, 0.88)
	game.world.env.fog_enabled = false
	game.world.env.ambient_light_color = Color(0.95, 0.95, 0.92)
	game.world.env.ambient_light_energy = 1.0
	game.world.env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	for child in game.world.get_children():
		if child is Camera3D or child is WorldEnvironment:
			continue
		if child is Node3D:
			child.visible = false
	# One of each player profession: hide the second starting guard, add an adept.
	var adept: LegionActor = game.debug_spawn_unit("adept", Vector3(2.2, 0, 2.0))
	game.units[1].visible = false
	var lineup: Array = [game.units[0], game.units[2], adept, game.units[3]]
	for i in 4:
		var u: LegionActor = lineup[i]
		u.visible = true
		u.global_position = Vector3(-6.6 + i * 4.4, 0, 2.0)
		u.rotation.y = 0.0
		u.model.rotation_degrees.z = 0.0
		u.model.position.y = 0.0
	for i in 4:
		var k: String = ["crawler", "spitter", "colossus", "crawler"][i]
		var e = game.debug_spawn_enemy(k, 0, Vector3(-6.6 + i * 4.4, 0, 8.0), 1.0, 0.0, 0.0)
		e.rotation.y = 0.0
		e.model.position.y = 0.0
		e.set_process(false)
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.02, 0.02, 0.02)
	for a in game.units:
		if a == null or not is_instance_valid(a):
			continue
		_blackout(a.model, black)
	for a in game.enemies:
		if a == null or not is_instance_valid(a):
			continue
		_blackout(a.model, black)
	game.world.set_camera(Vector3(0, 0, 5.5), 22.0)
	await _warm(0.5)
	await _shot("11_silhouette_1920.png")
	game.world.set_camera(Vector3(0, 0, 5), 96.0)
	await _warm(0.4)
	await _shot("11b_silhouette_96m_1920.png")
	# restore for later shots
	game.world.env.background_mode = Environment.BG_SKY
	game.world.env.fog_enabled = true
	game.world.env.ambient_light_color = Color("#A08C7A")
	for child in game.world.get_children():
		if child is Node3D:
			child.visible = true
	game.ui.visible = true


# ------------------------------------------------------------------ tower grid

func _tower_grid_shot() -> void:
	game.restart_run(888001)
	game.set_process(false)
	game.clear_selection()
	game.ui.visible = false
	game.debug_add_resources(99999, 9999)
	var grid_nodes: Array[Node] = []
	var x := -9.0
	for kind in D.TOWER_ORDER:
		for lv in 3:
			var t: LegionTower = Tower.new()
			t.position = Vector3(x, game.world.height_at(x, 4.0), 4.0 + lv * 5.0)
			game.add_child(t)
			grid_nodes.append(t)
			t.setup(game, 0, kind)
			for u in lv:
				game.debug_add_resources(9999, 999)
				t.upgrade()
			t.set_process(false)
			var lbl := Label3D.new()
			lbl.text = "%s L%d" % [D.tower_def(kind).name, lv + 1]
			lbl.font_size = 42
			lbl.pixel_size = 0.011
			lbl.outline_size = 8
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			lbl.modulate = Color(0.95, 0.92, 0.82)
			lbl.outline_modulate = Color(0.05, 0.06, 0.06, 0.9)
			lbl.position = Vector3(x, 5.5, 4.0 + lv * 5.0)
			game.add_child(lbl)
			grid_nodes.append(lbl)
		x += 9.0
	for f in game.fx:
		if is_instance_valid(f.node):
			f.node.queue_free()
	game.fx.clear()
	game.world.set_camera(Vector3(0, 0, 10), 44.0)
	await _warm(0.6)
	await _shot("12_towers_L1_L3_1920.png")
	for n in grid_nodes:
		if is_instance_valid(n):
			n.queue_free()
	await process_frame
	game.ui.visible = true


# ------------------------------------------------------------------ helpers

func _blackout(root: Node3D, black: Material) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh is PlaneMesh:
			mi.visible = false
		else:
			mi.material_override = black
	# hide the ground shadow quads too (they live directly under the model root)
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi2 := n as MeshInstance3D
		if mi2 != null and mi2.mesh is PlaneMesh:
			mi2.visible = false


func _warm(seconds: float = 0.8) -> void:
	await create_timer(seconds).timeout
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR + name)
	var img: Image = sv.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("LEGION_SHOT_FAIL empty ", name)
		return
	img.save_png(path)
	print("LEGION_SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])
	captured.append(path)
	await process_frame
