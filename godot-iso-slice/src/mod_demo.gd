extends Node3D

# Mod 运行时导入演示：
#   res://mods → user://mods（安装）
#   scan manifest → sha256 → GLTFDocument → tris/bounds/pivot 校验
#   通过 → 实例化到 3D 转台；拒绝 → 显示原因
# 3D 材质统一改 unshaded + 顶点色，避开 GL Compatibility 的 3D 灯光限制。

const GOLD := Color(1.0, 0.85, 0.56)
const DIM := Color(0.72, 0.75, 0.82)
const FAINT := Color(0.5, 0.53, 0.61)
const OK_COL := Color(0.55, 0.86, 0.66)
const BAD_COL := Color(0.95, 0.48, 0.42)

var _mods: Array[Dictionary] = []
var _summary: Array[Dictionary] = []
var _selected := -1
var _holder: Node3D
var _current_scene: Node = null

var _rows: Array[Label] = []
var _details: Label
var _badge: Label
var _badge_box: PanelContainer
var _badge_style: StyleBoxFlat


func _ready() -> void:
	_build_world()
	_build_ui()
	ModLoader.install_fixtures()
	_mods = ModLoader.scan()
	_refresh_summaries()
	# 默认选中第一个通过校验的 mod
	var first_ok := -1
	for i in _summary.size():
		if bool(_summary[i]["ok"]):
			first_ok = i
			break
	_select(first_ok if first_ok >= 0 else 0)


func _process(delta: float) -> void:
	if _holder:
		_holder.rotation.y += delta * 0.55


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1:
			_select(0)
		KEY_2:
			_select(1)
		KEY_3:
			_select(2)
		KEY_LEFT:
			_select(posmod(_selected - 1, maxi(_mods.size(), 1)))
		KEY_RIGHT:
			_select(posmod(_selected + 1, maxi(_mods.size(), 1)))
		KEY_R:
			_select(_selected)
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/dungeon.tscn")


# ── mod flow ──────────────────────────────────────────────────────────────
func _refresh_summaries() -> void:
	_summary.clear()
	for entry in _mods:
		var r := ModLoader.validate(entry)
		_summary.append({
			"ok": r["ok"], "reason": r["reason"], "tris": r["tris"],
			"meshes": r["meshes"], "aabb": r["aabb"],
		})
		if r["scene"] != null:
			(r["scene"] as Node).free()


func _select(index: int) -> void:
	if _mods.is_empty():
		return
	index = clampi(index, 0, _mods.size() - 1)
	_selected = index
	if _current_scene != null:
		_holder.remove_child(_current_scene)
		_current_scene.queue_free()
		_current_scene = null

	var entry := _mods[index]
	var r := ModLoader.validate(entry)
	if bool(r["ok"]):
		var scene := r["scene"] as Node3D
		ModLoader.style_unshaded(scene)
		_holder.add_child(scene)
		_current_scene = scene

	_summary[index] = {
		"ok": r["ok"], "reason": r["reason"], "tris": r["tris"],
		"meshes": r["meshes"], "aabb": r["aabb"],
	}
	_update_ui(r)


func _update_ui(r: Dictionary) -> void:
	for i in _rows.size():
		if i >= _mods.size():
			_rows[i].text = ""
			continue
		var m: Dictionary = _mods[i]["manifest"]
		var s: Dictionary = _summary[i]
		var ok := bool(s["ok"])
		var prefix := "› " if i == _selected else "  "
		_rows[i].text = "%s[%d] %s    %s" % [
			prefix, i + 1, str(m.get("name", m.get("id", "?"))),
			"OK" if ok else "REJECTED"]
		_rows[i].add_theme_color_override("font_color",
			GOLD if i == _selected else (OK_COL if ok else BAD_COL))

	var m: Dictionary = _mods[_selected]["manifest"]
	var box: AABB = r["aabb"]
	var db: Dictionary = m.get("bounds", {})
	var dmin: Array = db.get("min", [0, 0, 0])
	var dmax: Array = db.get("max", [0, 0, 0])
	var lines := [
		"id        %s" % str(m.get("id", "?")),
		"file      %s" % str(r["file"]),
		"sha256    %s" % _short(str(r["sha"])),
		"declared  %s" % _short(str(m.get("sha256", ""))),
		"tris      %d / %d     meshes %d" % [
			int(r["tris"]), int(m.get("max_tris", 0)), int(r["meshes"])],
		"bounds    %s" % _vec(box.position),
		"          %s" % _vec(box.end),
		"declared  %s .. %s" % [_vec3(dmin), _vec3(dmax)],
		"footprint %.3f / %.3f     pivot %s" % [
			maxf(box.size.x, box.size.z), float(m.get("footprint", 0.0)),
			str(m.get("pivot", "?"))],
		"",
		"GLTFDocument.append_from_file → generate_scene",
	]
	_details.text = "\n".join(lines)

	if bool(r["ok"]):
		_badge.text = "IMPORT OK · %s" % str(m.get("name", ""))
		_badge_style.bg_color = Color(0.16, 0.50, 0.31)
	else:
		_badge.text = "REJECTED · " + str(r["reason"])
		_badge_style.bg_color = Color(0.60, 0.20, 0.20)
	_badge_box.queue_redraw()


func _short(h: String) -> String:
	if h.length() <= 24:
		return h
	return h.substr(0, 10) + "…" + h.substr(h.length() - 8)


func _vec(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]


func _vec3(a: Array) -> String:
	return "(%.3f, %.3f, %.3f)" % [float(a[0]), float(a[1]), float(a[2])]


# ── 3d world ──────────────────────────────────────────────────────────────
func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.03, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.60, 0.78)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var cam := Camera3D.new()
	cam.position = Vector3(2.25, 1.55, 2.75)
	cam.fov = 45.0
	cam.current = true
	add_child(cam)
	cam.look_at(Vector3(0, 0.68, 0), Vector3.UP)

	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.95
	cyl.bottom_radius = 1.05
	cyl.height = 0.10
	cyl.radial_segments = 64
	disc.mesh = cyl
	disc.position.y = -0.05
	disc.material_override = _unshaded(Color(0.10, 0.11, 0.16))
	add_child(disc)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 0.86
	torus.rings = 64
	torus.ring_segments = 8
	ring.mesh = torus
	ring.position.y = 0.012
	ring.material_override = _unshaded(Color(0.86, 0.68, 0.36))
	add_child(ring)

	var floor_disc := MeshInstance3D.new()
	var cyl2 := CylinderMesh.new()
	cyl2.top_radius = 1.65
	cyl2.bottom_radius = 1.75
	cyl2.height = 0.06
	cyl2.radial_segments = 64
	floor_disc.mesh = cyl2
	floor_disc.position.y = -0.13
	floor_disc.material_override = _unshaded(Color(0.055, 0.06, 0.085))
	add_child(floor_disc)

	_holder = Node3D.new()
	add_child(_holder)


func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# ── ui ────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var vignette := TextureRect.new()
	vignette.texture = preload("res://assets/ui/vignette.png")
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vignette)

	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	_add(ui, _mk("MOD IMPORT · runtime GLB", 30, GOLD), Vector2(60, 32))
	_add(ui, _mk("res://mods → user://mods → manifest 校验 → GLTFDocument 运行时导入", 14, DIM),
		Vector2(60, 74))
	_add(ui, _mk("sha256 · tris · bounds · pivot · footprint 全部通过才实例化", 12, FAINT),
		Vector2(60, 98))

	# list panel
	var list_panel := _panel(ui, Vector2(60, 150), Vector2(380, 330))
	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 10)
	list_panel.add_child(list_box)
	list_box.add_child(_mk("MODS", 14, FAINT))
	for i in 3:
		var row := _mk("", 15, DIM)
		_rows.append(row)
		list_box.add_child(row)
	list_box.add_child(_mk("", 8, FAINT))
	list_box.add_child(_mk("1/2/3 选择    ←/→ 切换    R 重新导入", 12, FAINT))

	# detail panel
	var detail_panel := _panel(ui, Vector2(840, 150), Vector2(380, 330))
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 8)
	detail_panel.add_child(detail_box)
	detail_box.add_child(_mk("IMPORT DETAILS", 14, FAINT))
	_details = _mk("", 12, DIM)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_details)

	# badge
	_badge_style = _style(Color(0.16, 0.50, 0.31), Color(1.0, 0.85, 0.56, 0.25))
	_badge_box = PanelContainer.new()
	_badge_box.position = Vector2(60, 600)
	_badge_box.size = Vector2(1160, 46)
	_badge_box.add_theme_stylebox_override("panel", _badge_style)
	ui.add_child(_badge_box)
	_badge = _mk("", 16, Color(0.97, 0.97, 0.94))
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_box.add_child(_badge)

	_add(ui, _mk("Esc 返回地牢    导入失败不会实例化；坏 hash / 坏 bounds 都会被拦截", 13, FAINT),
		Vector2(60, 662))


func _panel(parent: Control, pos: Vector2, sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.size = sz
	var s := _style(Color(0.06, 0.07, 0.095, 0.88), Color(0.85, 0.72, 0.45, 0.22))
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	return p


func _mk(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _add(parent: Control, node: Control, pos: Vector2) -> void:
	node.position = pos
	parent.add_child(node)


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	return s
