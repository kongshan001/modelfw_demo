extends SceneTree

# G1 材质 / G5 舞台光照 / VFX 证据台（T-20261121-007）。
# 同一机位 before/after：苔藓骑士 + 余烬法师 + 云朵面包师
#   stage_1280 / stage_1920          舞台 alone（ΔL*、4 层背景）
#   <slug>_studio_1280.png           1× 目标尺寸（试衣镜 2.1×，角色≈317px）
#   <slug>_hero_1920.png             1920×1080（3.15×，角色≈475px）
#   <slug>_transparent.png           透明底，墨色族 / L* 分箱
#   slash_frames/                    640×360 @30fps：idle 0.3s → attack 1.2s → hit 0.4s
#   slash_impact_640.png             命中帧（attack p=0.52）
# 用法：PD_PHASE=before|after godot --path . --resolution 1280x720 -s tools/material_vfx_rig.gd

const OUT := "res://docs/shots/material-vfx"
const CHARS := [
	{"index": 0, "slug": "moss_knight"},
	{"index": 1, "slug": "ember_mage"},
	{"index": 4, "slug": "cloud_baker"},
]

var _phase := "after"
var _vp: SubViewport
var _stage: StageBackdrop
var _lineup: Array
var _node: Node2D


func _initialize() -> void:
	var phase := OS.get_environment("PD_PHASE")
	if not phase.is_empty():
		_phase = phase
	var base := OUT + "/" + _phase
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base + "/slash_frames"))
	_lineup = DollData.load_lineup()
	if _lineup.size() != 16:
		_lineup = DollData.fallback_lineup()

	_vp = SubViewport.new()
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)

	await _stage_shots()
	await _character_shots()
	await _transparent_shots()
	await _slash_film()

	print("MATERIAL_VFX_RIG_OK phase=%s" % _phase)
	quit(0)


func _reset(width: int, height: int, transparent := false) -> void:
	if _node != null:
		_node.queue_free()
		_node = null
	_stage = null
	for child in _vp.get_children():
		child.queue_free()
	_vp.transparent_bg = transparent
	_vp.size = Vector2i(width, height)
	_node = Node2D.new()
	_vp.add_child(_node)
	await _settle()


func _make_stage(width: int, height: int) -> void:
	_stage = StageBackdrop.new()
	_stage.size = Vector2(width, height)
	_node.add_child(_stage)


func _add_doll(outfit: Dictionary, direction: int, action: String, scale: float, pos: Vector2, effects := false) -> PaperDollRenderer:
	var doll := PaperDollRenderer.new()
	doll.animate = false
	doll.show_shadow = true
	doll.show_effects = effects
	doll.set_doll(outfit, direction, action)
	doll.set_display_scale(scale)
	doll.position = pos
	doll.set_clock(DollData.showcase_time(0, action))
	_node.add_child(doll)
	return doll


func _stage_shots() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _reset(size.x, size.y)
		_make_stage(size.x, size.y)
		await _settle()
		await _shot("stage_%d" % size.x)


func _character_shots() -> void:
	for entry in CHARS:
		var role: Dictionary = _lineup[int(entry["index"])]
		# 1× 目标：1280×720，试衣镜 2.1×（角色 ≈317px）。
		await _reset(1280, 720)
		_make_stage(1280, 720)
		_add_doll(role["outfit"], 0, "idle", 2.10, Vector2(640, 702))
		await _settle()
		await _shot("%s_studio_1280" % entry["slug"])
		# 1080p：3.15×（角色 ≈475px）。
		await _reset(1920, 1080)
		_make_stage(1920, 1080)
		_add_doll(role["outfit"], 0, "idle", 3.15, Vector2(960, 1058))
		await _settle()
		await _shot("%s_hero_1920" % entry["slug"])


func _transparent_shots() -> void:
	for entry in CHARS:
		var role: Dictionary = _lineup[int(entry["index"])]
		await _reset(500, 700, true)
		var doll := _add_doll(role["outfit"], 0, "idle", 2.10, Vector2(250, 680))
		doll.show_shadow = false
		await _settle()
		await _shot("%s_transparent" % entry["slug"])


func _slash_film() -> void:
	await _reset(640, 360)
	_make_stage(640, 360)
	var role: Dictionary = _lineup[10]
	var doll := _add_doll(role["outfit"], 6, "idle", 2.05, Vector2(320, 330), true)
	var fps := 30.0
	var frame := 0
	var segments := [
		{"action": "idle", "duration": 0.3, "clock": 0.6},
		{"action": "attack", "duration": 1.2, "clock": 0.0},
		{"action": "hit", "duration": 0.4, "clock": 0.0},
	]
	for seg in segments:
		var count := int(round(float(seg["duration"]) * fps))
		for i in count:
			doll.action = str(seg["action"])
			doll.set_clock(float(seg["clock"]) + float(i) / fps)
			await _settle()
			var image := _vp.get_texture().get_image()
			image.save_png(OUT + "/" + _phase + "/slash_frames/frame_%03d.png" % frame)
			frame += 1
	# 命中帧：attack p=0.52 → t=0.546s。
	doll.action = "attack"
	doll.set_clock(0.546)
	await _settle()
	await _shot("slash_impact_640")
	var pose := doll.current_pose()
	var meta := {
		"scale": 2.05,
		"xscale": 1.0 - 0.38 * float(DollData.DIRS[6]["yaw"]),
		"origin": [320.0, 330.0],
		"hand_local": [pose["hand_r"].x, pose["hand_r"].y],
		"arm_angle": pose["weapon_angle"],
		"radius_local": 52.0,
		"vfx_t": pose["vfx_t"],
		"slash": pose["slash"],
		"core_hex": "#8f5f1f",
		"edge_hex": "#8f3030",
	}
	var hold_a := DollPose.compute(0.546, "attack", 6)
	var hold_b := DollPose.compute(0.546 + 1.0 / 30.0, "attack", 6)
	meta["impact_hold_same_pose"] = (
		(hold_a["hand_r"] as Vector2).is_equal_approx(hold_b["hand_r"])
		and is_equal_approx(float(hold_a["slash"]), float(hold_b["slash"]))
		and is_equal_approx(float(hold_a["weapon_angle"]), float(hold_b["weapon_angle"])))
	meta["impact_hold_frames"] = 2
	var file := FileAccess.open(OUT + "/" + _phase + "/slash_meta.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(meta, "\t"))
	file.close()
	print("MATERIAL_VFX_FRAMES %d" % frame)


func _settle() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _settle()
	var image := _vp.get_texture().get_image()
	var path := OUT + "/" + _phase + "/" + name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("MATERIAL_VFX_SHOT ", path)
