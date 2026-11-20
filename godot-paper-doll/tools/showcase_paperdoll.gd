extends SceneTree

# 展示物料（评审 P1-5，固定选 16 预设，不拍随机阵容）：
#   hero.png        1280×720 干净舞台，单个苔藓骑士，无 UI
#   compass.png     1280×720 8 向罗盘（裁剪清晰）
#   poster_16.png   1280×720 16 人海报，2 行 × 8，角色约 168px 高
#   frames/         6s 640×360 @30fps 动作序列（idle→walk→attack→hit）
# 用法：godot --path godot-paper-doll --resolution 1280x720 -s tools/showcase_paperdoll.gd
# GIF 由 ffmpeg 二次合成（见 tools/record_showcase.sh）。

const OUT := "res://docs/shots/showcase"
const FRAMES := "res://docs/shots/showcase/frames"
const W := 1280
const H := 720

var _vp: SubViewport
var _stage: StageBackdrop
var _dolls: Array[PaperDollRenderer] = []
var _labels: Array[Label] = []
var _lineup: Array


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES))
	_lineup = DollData.load_lineup()
	if _lineup.size() != 16:
		_lineup = DollData.fallback_lineup()

	await _build_stage(W, H)
	await _hero()
	await _compass()
	await _poster()
	await _film()

	print("PAPERDOLL_SHOWCASE_OK")
	quit(0)


func _build_stage(width: int, height: int) -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(width, height)
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_stage = StageBackdrop.new()
	_stage.size = Vector2(width, height)
	_vp.add_child(_stage)
	await _settle()


func _reset(width: int, height: int) -> void:
	for d in _dolls:
		d.queue_free()
	_dolls.clear()
	for l in _labels:
		l.queue_free()
	_labels.clear()
	_vp.size = Vector2i(width, height)
	_stage.size = Vector2(width, height)
	await _settle()


func _add_doll(outfit: Dictionary, direction: int, action: String, scale: float, pos: Vector2, effects := false) -> PaperDollRenderer:
	var doll := PaperDollRenderer.new()
	doll.animate = false
	doll.show_shadow = true
	doll.show_effects = effects
	doll.set_doll(outfit, direction, action)
	doll.set_display_scale(scale)
	doll.position = pos
	doll.set_clock(DollData.showcase_time(0, action))
	_vp.add_child(doll)
	_dolls.append(doll)
	return doll


func _add_label(text: String, size: int, pos: Vector2, color := AtelierTheme.INK, centered := true) -> void:
	var label := AtelierTheme.make_label(text, size, color)
	label.position = pos
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(160, 24)
		label.position -= Vector2(80, 0)
	_vp.add_child(label)
	_labels.append(label)


func _hero() -> void:
	await _reset(W, H)
	var entry: Dictionary = _lineup[0]
	_add_doll(entry["outfit"], 0, "idle", 3.35, Vector2(W * 0.5, H - 58.0), true)
	_add_label("苔藓骑士", 20, Vector2(W * 0.5, H - 40.0))
	await _settle()
	await _shot("hero")

	# 层视 hero：17 层沿右下展开（P1-3 展示物料）。
	_dolls[0].set_explode(1.0)
	_dolls[0].highlight_slot = "hat"
	await _settle()
	await _shot("hero_layers")
	_dolls[0].set_explode(0.0)
	_dolls[0].highlight_slot = ""
	await _settle()


func _compass() -> void:
	await _reset(W, H)
	var outfit: Dictionary = _lineup[0]["outfit"]
	var center := Vector2(W * 0.5, H * 0.50)
	var ring := 230.0
	for i in 8:
		# 方向 0=下 在底部，4=上 在顶部；i 顺时针排（下→左下→左…）。
		var a := deg_to_rad(90.0 + 45.0 * float(i))
		var pos := center + Vector2(cos(a) * ring, sin(a) * ring * 0.82)
		_add_doll(outfit, i, "walk", 1.12, pos + Vector2(0, 86))
		var dir: Dictionary = DollData.DIRS[i]
		_add_label("%s %s" % [dir["label"], dir["name"]], 13, pos + Vector2(0, 94), AtelierTheme.INK)
	_add_label("8 方向罗盘", 22, Vector2(W * 0.5, 26))
	await _settle()
	await _shot("compass")


func _poster() -> void:
	await _reset(W, H)
	for i in 16:
		var entry: Dictionary = _lineup[i]
		var col := i % 8
		var row := i / 8
		var x := 90.0 + float(col) * 157.0
		var y := 342.0 if row == 0 else 668.0
		_add_doll(entry["outfit"], int(entry["direction"]), str(entry["action"]), 1.20,
				Vector2(x, y))
		_add_label(str(entry["name"]), 12, Vector2(x, y + 12.0))
	_add_label("纸偶工坊 · 16 位纸偶", 24, Vector2(W * 0.5, 22))
	await _settle()
	await _shot("poster_16")


func _film() -> void:
	await _reset(640, 360)
	var entry: Dictionary = _lineup[0]
	var doll := _add_doll(entry["outfit"], 0, "idle", 2.05, Vector2(320, 330), true)
	var segments := [
		{"action": "idle", "duration": 1.4, "clock": 0.9},
		{"action": "walk", "duration": 1.4, "clock": 0.0},
		{"action": "attack", "duration": 1.4, "clock": 0.0},
		{"action": "hit", "duration": 1.4, "clock": 0.0},
		{"action": "idle", "duration": 0.4, "clock": 0.0},
	]
	var fps := 30.0
	var frame := 0
	for seg in segments:
		var count := int(round(float(seg["duration"]) * fps))
		for i in count:
			doll.action = str(seg["action"])
			doll.set_clock(float(seg["clock"]) + float(i) / fps)
			await _settle()
			var image := _vp.get_texture().get_image()
			image.save_png(FRAMES + "/frame_%03d.png" % frame)
			frame += 1
	print("FRAMES ", frame)


func _settle() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _settle()
	var image := _vp.get_texture().get_image()
	var path := OUT + "/" + name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOWCASE ", path)
