extends SceneTree

# 美术指标采集（真实 GPU 渲染，无 UI）：
#   metric_doll.png      苔藓骑士 2.1× 透明底（墨色族 / 色数 / L*）
#   stage_only.png       纸面舞台（舞台 L* / 斩击对比背景）
#   stage_doll.png       舞台 + 角色（ΔL*）
#   sil_00..15.png       16 预设剪影（0.56×，与阵容卡同尺寸）
#   dir_00..07.png       8 向剪影（0.80×，与罗盘同尺寸）
#   slash.png            挥击斩击帧（对比度）
# 用法：godot --path godot-paper-doll --resolution 1280x720 -s tools/metric_rig.gd

const OUT := "res://docs/metrics"
const W := 500
const H := 700

var _vp: SubViewport
var _doll: PaperDollRenderer
var _stage: StageBackdrop
var _lineup: Array


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_lineup = DollData.load_lineup()
	if _lineup.size() != 16:
		_lineup = DollData.fallback_lineup()

	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)

	_doll = PaperDollRenderer.new()
	_doll.animate = false
	_doll.show_shadow = false
	_doll.set_display_scale(2.1)
	_doll.position = Vector2(W * 0.5, H - 20.0)
	_vp.add_child(_doll)

	# 1) 基准角色透明底（苔藓骑士，2.1×，idle）。
	var base_outfit: Dictionary = _lineup[0]["outfit"]
	_doll.mini = false
	_doll.silhouette = false
	_doll.set_doll(base_outfit, 0, "idle")
	_doll.set_clock(0.9)
	await _settle()
	_save("metric_doll")

	# 2) 舞台 alone / stage + doll。
	_vp.transparent_bg = false
	_stage = StageBackdrop.new()
	_stage.size = Vector2(W, H)
	_vp.add_child(_stage)
	_vp.move_child(_stage, 0)
	_doll.visible = false
	await _settle()
	_save("stage_only")
	_doll.visible = true
	await _settle()
	_save("stage_doll")

	# 3) 16 预设剪影（与阵容卡同尺寸 0.56×，脚底同一基线）。
	_stage.visible = false
	_vp.transparent_bg = true
	_vp.size = Vector2i(240, 240)
	_doll.mini = true
	_doll.silhouette = true
	_doll.show_shadow = false
	_doll.set_display_scale(0.56)
	_doll.position = Vector2(120, 230)
	for i in 16:
		var entry: Dictionary = _lineup[i]
		_doll.set_doll(entry["outfit"], int(entry["direction"]), str(entry["action"]))
		_doll.time_offset = DollData.showcase_time(i, str(entry["action"]))
		_doll.set_clock(0.0)
		await _settle()
		_save("sil_%02d" % i)

	# 4) 8 向剪影（苔藓骑士，0.80×，行走相位一致）。
	_doll.set_display_scale(0.80)
	for d in 8:
		_doll.set_doll(base_outfit, d, "walk")
		_doll.set_clock(0.35)
		await _settle()
		_save("dir_%02d" % d)

	# 5) 斩击帧：纸灯剑客（preset 10），攻击中段。
	_vp.size = Vector2i(W, H)
	_stage.visible = true
	_vp.transparent_bg = false
	_doll.mini = false
	_doll.silhouette = false
	_doll.show_shadow = true
	_doll.set_display_scale(2.1)
	_doll.position = Vector2(W * 0.5, H - 20.0)
	var slash_entry: Dictionary = _lineup[10]
	_doll.set_doll(slash_entry["outfit"], 6, "attack")
	_doll.set_clock(0.52)
	await _settle()
	_save("slash")

	# 6) 随机色彩纪律：10 次和声随机的 17 槽颜色，供 Python 检查。
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	var samples: Array = []
	for i in 10:
		var outfit := DollData.random_outfit(rng)
		var encoded := {}
		for slot in DollData.SLOTS:
			encoded[slot["id"]] = (outfit[slot["id"]]["color"] as Color).to_html(false)
		samples.append(encoded)
	var file := FileAccess.open(OUT + "/random_outfits.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(samples, "\t"))
	file.close()

	print("PAPERDOLL_METRICS_OK")
	quit(0)


func _settle() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _save(name: String) -> void:
	var image := _vp.get_texture().get_image()
	var path := OUT + "/" + name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("METRIC ", path)
