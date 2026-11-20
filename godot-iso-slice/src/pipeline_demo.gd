extends Control

# 管线演示：同一份 rules.json，两条执行路径。
#   ① Python 离线烘焙 → PNG → 运行时读取
#   ② GDScript 同 seed 生成 → 写 user:// → 重新读取 → 显示
# 两边逐像素比较；R 换 seed 走运行时缓存，L 重新导入缓存。

const MANIFEST := "res://assets/generated/manifest.json"
const CACHE_DIR := "user://pipeline_cache"
const BAKED_DIR := "res://assets/generated/"

const GOLD := Color(1.0, 0.85, 0.56)
const DIM := Color(0.72, 0.75, 0.82)
const FAINT := Color(0.5, 0.53, 0.61)

var _rules: Dictionary
var _manifest: Dictionary
var _baked_seed := 7
var _seed := 7

var _left_tex: TextureRect
var _right_tex: TextureRect
var _left_placeholder: Label
var _left_path: Label
var _left_hash: Label
var _right_path: Label
var _right_hash: Label
var _badge: Label
var _badge_box: PanelContainer
var _badge_style: StyleBoxFlat
var _status: Label

var _offline_hash := ""
var _runtime_hash := ""
var _reload_hash := ""


func _ready() -> void:
	_rules = SigilRules.load_rules()
	_manifest = _read_json(MANIFEST)
	if _manifest.has("baked_seed"):
		_baked_seed = int(_manifest["baked_seed"])
	_seed = _baked_seed
	_build_ui()
	if _rules.is_empty() or _manifest.is_empty():
		_badge.text = "缺少 rules.json 或 manifest.json —— 先跑 tools/bake_pipeline.py"
		_badge_style.bg_color = Color(0.55, 0.2, 0.2)
		_badge_box.queue_redraw()
		return
	_show_seed(_seed)


func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_R:
			next_seed()
		KEY_L:
			_reload_cache()
		KEY_B:
			back_to_baked()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/dungeon.tscn")


# 给截图/录制工具用的公开入口
func next_seed() -> void:
	_seed += 1
	_show_seed(_seed)


func back_to_baked() -> void:
	_show_seed(_baked_seed)


# ── flow ──────────────────────────────────────────────────────────────────
func _show_seed(seed: int) -> void:
	_seed = seed
	_offline_hash = ""
	_runtime_hash = ""
	_reload_hash = ""

	# ① runtime generate
	var runtime_img := SigilRules.generate(_rules, seed)
	_runtime_hash = SigilRules.sha256_rgba(runtime_img)

	# ② save to a real file, then re-import it (cache round-trip)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	var cache_path := "%s/sigil_%d.png" % [CACHE_DIR, seed]
	var save_err := runtime_img.save_png(cache_path)
	var reloaded: Image = Image.load_from_file(cache_path) if save_err == OK else null
	if reloaded == null:
		_right_tex.texture = null
		_right_hash.text = "缓存写入/读取失败"
		_right_path.text = cache_path
	else:
		_reload_hash = SigilRules.sha256_rgba(reloaded)
		_right_tex.texture = ImageTexture.create_from_image(reloaded)
		_right_hash.text = "sha256 " + _short(_reload_hash)
		_right_hash.tooltip_text = _reload_hash
		_right_path.text = cache_path + " · 重新导入"

	# ③ offline baked PNG (only for seeds Python baked)
	var assets: Dictionary = _manifest.get("assets", {})
	var entry: Dictionary = assets.get(str(seed), {})
	var offline_img: Image = null
	if not entry.is_empty():
		var p := BAKED_DIR + str(entry["file"])
		offline_img = Image.load_from_file(p)
		if offline_img != null:
			_offline_hash = SigilRules.sha256_rgba(offline_img)
			_left_tex.texture = ImageTexture.create_from_image(offline_img)
			_left_placeholder.visible = false
			_left_path.text = p + " · Python 烘焙"
			_left_hash.text = "sha256 " + _short(_offline_hash)
			_left_hash.tooltip_text = _offline_hash
		else:
			_left_tex.texture = null
			_left_placeholder.visible = true
			_left_placeholder.text = "离线 PNG 读取失败"
			_left_path.text = p
			_left_hash.text = ""
	else:
		_left_tex.texture = null
		_left_placeholder.visible = true
		_left_placeholder.text = "未离线烘焙\n该 seed 只走运行时缓存"
		_left_path.text = "res://（无此 seed）"
		_left_hash.text = ""

	_update_badge(offline_img, reloaded)
	_update_status()


func _reload_cache() -> void:
	var cache_path := "%s/sigil_%d.png" % [CACHE_DIR, _seed]
	var img: Image = Image.load_from_file(cache_path)
	if img == null:
		_badge.text = "CACHE MISS · " + cache_path
		_badge_style.bg_color = Color(0.55, 0.2, 0.2)
		_badge_box.queue_redraw()
		return
	_reload_hash = SigilRules.sha256_rgba(img)
	var runtime_img := SigilRules.generate(_rules, _seed)
	var runtime_hash := SigilRules.sha256_rgba(runtime_img)
	_right_tex.texture = ImageTexture.create_from_image(img)
	_right_hash.text = "sha256 " + _short(_reload_hash)
	_right_hash.tooltip_text = _reload_hash
	var same := _reload_hash == runtime_hash and _reload_hash == _runtime_hash
	_badge.text = ("CACHE RELOAD OK · 与运行时逐像素一致" if same
		else "CACHE RELOAD · 哈希不一致")
	_badge_style.bg_color = Color(0.16, 0.50, 0.31) if same else Color(0.60, 0.20, 0.20)
	_badge_box.queue_redraw()
	_update_status()


func _update_badge(offline_img: Image, reloaded: Image) -> void:
	if offline_img != null and reloaded != null:
		var diff := _pixel_diff(offline_img, reloaded)
		var same := diff == 0 and _offline_hash == _runtime_hash and _offline_hash == _reload_hash
		if same:
			_badge.text = "MATCH · offline = runtime = cache reload · 0 px diff"
			_badge_style.bg_color = Color(0.16, 0.50, 0.31)
		else:
			_badge.text = "MISMATCH · " + ("%d px diff" % diff if diff >= 0 else "size/format mismatch")
			_badge_style.bg_color = Color(0.60, 0.20, 0.20)
	else:
		_badge.text = "RUNTIME ONLY · 生成 → user:// → 重新导入（该 seed 未离线烘焙）"
		_badge_style.bg_color = Color(0.56, 0.38, 0.14)
	_badge_box.queue_redraw()


func _pixel_diff(a: Image, b: Image) -> int:
	if a == null or b == null:
		return -1
	if a.get_size() != b.get_size() or a.get_format() != b.get_format():
		return -1
	var da := a.get_data()
	var db := b.get_data()
	if da.size() != db.size():
		return -1
	var diff := 0
	for i in range(0, da.size(), 4):
		if (da[i] != db[i] or da[i + 1] != db[i + 1]
				or da[i + 2] != db[i + 2] or da[i + 3] != db[i + 3]):
			diff += 1
	return diff


func _short(h: String) -> String:
	if h.length() <= 26:
		return h
	return h.substr(0, 12) + "…" + h.substr(h.length() - 10)


func _update_status() -> void:
	_status.text = "rules v%d · seed %d · runtime %s · cache %s" % [
		int(_manifest.get("rules_version", 0)), _seed,
		_short(_runtime_hash), _short(_reload_hash)]


# ── ui ────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.04, 0.055)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	_add(_mk("PIPELINE PROOF", 34, GOLD), Vector2(80, 28))
	_add(_mk("rules.json 是唯一规则源：左侧 Python 离线烘焙，右侧 GDScript 同 seed 运行时生成。", 15, DIM),
		Vector2(80, 76))
	var seed_list: Array[String] = []
	for s in _manifest.get("seeds", []):
		seed_list.append(str(int(s)))
	_add(_mk("rule=%s   size=%d×%d   seeds=%s" % [
		str(_manifest.get("rule", "?")), int(_manifest.get("size", 0)),
		int(_manifest.get("size", 0)), ", ".join(seed_list)], 13, FAINT),
		Vector2(80, 102))

	_build_panel(Vector2(80, 140), "① OFFLINE BAKE · Python", true)
	_build_panel(Vector2(700, 140), "② RUNTIME · GDScript", false)

	_badge_style = _style(Color(0.16, 0.50, 0.31), Color(1.0, 0.85, 0.56, 0.25))
	_badge_box = PanelContainer.new()
	_badge_box.position = Vector2(80, 600)
	_badge_box.size = Vector2(1120, 48)
	_badge_box.add_theme_stylebox_override("panel", _badge_style)
	add_child(_badge_box)
	_badge = _mk("", 16, Color(0.97, 0.97, 0.94))
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_box.add_child(_badge)

	_add(_mk("R  新 seed（运行时生成 → user:// → 重新导入）      L  重新载入缓存      B  回到已烘焙 seed      Esc  返回地牢",
		14, DIM), Vector2(80, 662))
	_status = _mk("", 12, FAINT)
	_add(_status, Vector2(80, 690))


func _build_panel(pos: Vector2, title: String, left: bool) -> void:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = Vector2(500, 440)
	panel.add_theme_stylebox_override("panel",
		_style(Color(0.075, 0.085, 0.105), Color(0.85, 0.72, 0.45, 0.22)))
	add_child(panel)

	var inner := Control.new()
	inner.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	panel.add_child(inner)

	_add_to(inner, _mk(title, 18, GOLD), Vector2(24, 18))

	var slot := ColorRect.new()
	slot.color = Color(0.02, 0.025, 0.035)
	slot.position = Vector2(116, 58)
	slot.size = Vector2(268, 268)
	inner.add_child(slot)

	var frame := PanelContainer.new()
	frame.position = Vector2(112, 54)
	frame.size = Vector2(276, 276)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0, 0, 0, 0)
	fs.border_color = Color(0.85, 0.72, 0.45, 0.18)
	fs.set_border_width_all(1)
	fs.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", fs)
	inner.add_child(frame)

	var tex := TextureRect.new()
	tex.position = Vector2(122, 60)
	tex.size = Vector2(256, 256)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	inner.add_child(tex)

	var path := _mk("", 12, FAINT)
	_add_to(inner, path, Vector2(24, 336))
	var hash := _mk("", 13, DIM)
	_add_to(inner, hash, Vector2(24, 362))
	var flow := _mk("Python bake → PNG → 运行时 Image.load_from_file" if left
		else "generate → save_png → load_from_file → ImageTexture", 12, FAINT)
	_add_to(inner, flow, Vector2(24, 390))

	if left:
		_left_tex = tex
		_left_path = path
		_left_hash = hash
		_left_placeholder = _mk("未离线烘焙", 14, FAINT)
		_left_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_left_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_left_placeholder.position = Vector2(122, 60)
		_left_placeholder.size = Vector2(256, 256)
		_left_placeholder.visible = false
		inner.add_child(_left_placeholder)
	else:
		_right_tex = tex
		_right_path = path
		_right_hash = hash


func _mk(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _add(node: Control, pos: Vector2) -> void:
	node.position = pos
	add_child(node)


func _add_to(parent: Control, node: Control, pos: Vector2) -> void:
	node.position = pos
	parent.add_child(node)


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	return s
