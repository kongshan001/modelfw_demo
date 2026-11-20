class_name RaftHud
extends CanvasLayer

# 像素风 HUD：目标/资源/三围、建造菜单、锁定标记、飘字与 toast。
signal build_selected(type: String)
signal restart_requested

const W := 1280.0
const H := 720.0
const BG := Color(0.055, 0.10, 0.12, 0.90)
const BG_SOFT := Color(0.07, 0.14, 0.16, 0.84)
const BORDER := Color("#6fc7b3")
const CREAM := Color("#f4ead2")
const MINT := Color("#9fe8d8")
const GOLD := Color("#f3c46f")
const CORAL := Color("#ee8a72")
const BLUE := Color("#8fe0e3")
const GREEN := Color("#9fe8b0")

var world: RaftWorld
var container: SubViewportContainer
var _font: SystemFont
var root_ui: Control
var overlay: Control
var float_root: Control
var toast_box: VBoxContainer
var build_menu: Panel
var end_overlay: Control
var prompt_panel: Panel
var prompt_label: Label
var charge_bar: ProgressBar
var end_title: Label
var end_reason: Label
var end_stats: Label
var build_rows: Array[Dictionary] = []
var gauges: Dictionary = {}
var resources: Dictionary = {}
var labels: Dictionary = {}
var bars: Dictionary = {}
var floaters: Array[Dictionary] = []
var _snapshot: Dictionary = {}
var _build_open := false
var _end_shown := false
var _pulse := 0.0


func setup(world_ref: RaftWorld, container_ref: SubViewportContainer) -> void:
	world = world_ref
	container = container_ref
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
		"Source Han Sans SC", "Microsoft YaHei", "Arial"
	])
	_font.font_weight = 500
	_build_ui()


# ── build ─────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	root_ui = Control.new()
	root_ui.name = "RootUI"
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ui)

	overlay = Control.new()
	overlay.name = "LockOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	root_ui.add_child(overlay)

	_build_goals_panel()
	_build_supply_panel()
	_build_controls_panel()
	_build_prompt()
	_build_build_menu()
	_build_toasts()
	_build_end_overlay()

	float_root = Control.new()
	float_root.name = "Floaters"
	float_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	float_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(float_root)


func _style(bg: Color, border: Color, width := 2, margin := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.corner_radius_top_left = 0
	s.corner_radius_top_right = 0
	s.corner_radius_bottom_left = 0
	s.corner_radius_bottom_right = 0
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 0
	return s


func _panel(pos: Vector2, size: Vector2, border := BORDER, bg := BG, mouse := Control.MOUSE_FILTER_IGNORE) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.mouse_filter = mouse
	p.add_theme_stylebox_override("panel", _style(bg, border, 2, 10.0))
	root_ui.add_child(p)
	return p


func _label(parent: Node, text: String, size: int, color: Color, pos: Vector2, width := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.06, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		l.size = Vector2(width, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _bar(parent: Node, pos: Vector2, size: Vector2, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = size
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.05, 0.06, 0.9)
	bg.border_color = Color(0.35, 0.55, 0.55, 0.7)
	bg.set_border_width_all(1)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill_style)
	if parent is Control:
		parent.add_child(bar)
		bar.position = pos
	return bar


func _build_goals_panel() -> void:
	var p := _panel(Vector2(16, 14), Vector2(384, 150))
	labels["title"] = _label(p, "浮木湾", 30, CREAM, Vector2(14, 4))
	labels["subtitle"] = _label(p, "D R I F T W O O D   C O V E", 10, MINT, Vector2(16, 46))
	labels["objective"] = _label(p, "目标：扩建到 12 格，或撑到第 4 天", 13, CREAM, Vector2(14, 68))
	labels["tiles"] = _label(p, "木筏 4 / 12 格", 12, GOLD, Vector2(14, 90))
	bars["tiles"] = _bar(p, Vector2(152, 93), Vector2(214, 9), MINT)
	labels["day"] = _label(p, "第 1 天 · 清晨", 12, BLUE, Vector2(14, 114))
	bars["day"] = _bar(p, Vector2(152, 117), Vector2(214, 9), BLUE)
	# 四角铆钉
	for corner in [Vector2(4, 4), Vector2(378, 4), Vector2(4, 144), Vector2(378, 144)]:
		var dot := ColorRect.new()
		dot.color = MINT
		dot.position = corner
		dot.size = Vector2(3, 3)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(dot)


func _build_supply_panel() -> void:
	var p := _panel(Vector2(846, 14), Vector2(418, 206))
	_label(p, "船上物资  /  SUPPLIES", 12, MINT, Vector2(12, 6))
	var rows := [
		["thirst", "水分", BLUE],
		["hunger", "食物", GOLD],
		["stamina", "体力", GREEN],
	]
	var y := 30.0
	for row in rows:
		var key: String = row[0]
		_label(p, row[1], 12, row[2], Vector2(12, y))
		var bar := _bar(p, Vector2(70, y + 2), Vector2(212, 12), row[2])
		bars[key] = bar
		gauges[key] = _label(p, "100", 12, CREAM, Vector2(292, y - 1))
		y += 27.0

	# 资源行
	var res_row := [
		["wood", "wood", "木材"],
		["planks", "plank", "木板"],
		["fish", "fish", "银鱼"],
		["water", "water", "净水"],
		["cooked", "cooked", "烤鱼"],
	]
	var x := 12.0
	for item in res_row:
		var key: String = item[0]
		var icon := TextureRect.new()
		icon.texture = Art.icon(item[1])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(x, 124)
		icon.size = Vector2(26, 26)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(icon)
		var l := _label(p, "0", 15, CREAM, Vector2(x + 28, 127))
		resources[key] = l
		x += 78.0
	labels["storage"] = _label(p, "木箱 0 木材 / 0 木板 · 自动存取", 11, Color(0.75, 0.9, 0.86), Vector2(12, 166))
	labels["supply_hint"] = _label(p, "1 喝净水   2 吃烤鱼   3 生吃银鱼", 11, Color(0.7, 0.85, 0.82), Vector2(12, 184))


func _build_controls_panel() -> void:
	var p := _panel(Vector2(16, 596), Vector2(486, 108), Color(0.44, 0.66, 0.61), BG_SOFT)
	_label(p, "操 作  /  CONTROLS", 11, MINT, Vector2(12, 4))
	_label(p, "WASD 移动 · Shift 冲刺 · Q / E 环视 · 滚轮 缩放", 12, CREAM, Vector2(12, 25))
	_label(p, "按住 空格 / 左键 自动锁定并抛钩 · 松手追踪", 12, CREAM, Vector2(12, 46))
	_label(p, "B 建造 · F 收取/整理 · R 结束后重开", 12, CREAM, Vector2(12, 67))
	_label(p, "手感提示：钩子会自动追，不用瞄准。", 11, GOLD, Vector2(12, 88))


func _build_prompt() -> void:
	prompt_panel = _panel(Vector2(398, 536), Vector2(664, 48), BORDER, BG)
	prompt_label = _label(prompt_panel, "", 14, CREAM, Vector2(12, 11), 640.0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	charge_bar = _bar(prompt_panel, Vector2(16, 34), Vector2(632, 7), GOLD)
	charge_bar.visible = false


func _build_build_menu() -> void:
	build_menu = _panel(Vector2(846, 232), Vector2(418, 360), GOLD, BG, Control.MOUSE_FILTER_STOP)
	build_menu.visible = false
	build_menu.z_index = 5
	_label(build_menu, "建 造  /  BUILD", 16, GOLD, Vector2(14, 8))
	_label(build_menu, "选一项，然后点甲板放置", 11, MINT, Vector2(14, 32))
	var y := 54.0
	for entry in world.get_build_entries():
		var btn := Button.new()
		btn.name = "Build_" + entry["type"]
		btn.position = Vector2(12, y)
		btn.size = Vector2(394, 62)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_stylebox_override("normal", _style(Color(0.10, 0.18, 0.20, 0.95), Color(0.4, 0.65, 0.6), 1, 0.0))
		btn.add_theme_stylebox_override("hover", _style(Color(0.13, 0.25, 0.26, 0.98), MINT, 2, 0.0))
		btn.add_theme_stylebox_override("pressed", _style(Color(0.10, 0.20, 0.21, 1.0), GOLD, 2, 0.0))
		btn.add_theme_stylebox_override("disabled", _style(Color(0.07, 0.10, 0.11, 0.8), Color(0.25, 0.35, 0.34), 1, 0.0))
		btn.pressed.connect(_on_build_pressed.bind(entry["type"]))
		build_menu.add_child(btn)

		var icon := TextureRect.new()
		icon.texture = Art.icon(entry["icon"])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(10, 15)
		icon.size = Vector2(32, 32)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
		var name_l := _label(btn, entry["name"], 15, CREAM, Vector2(52, 8))
		var cost_l := _label(btn, "需要 " + entry["cost"], 12, GOLD, Vector2(52, 33))
		build_rows.append({"type": entry["type"], "button": btn, "cost": cost_l, "cost_map": RaftWorld.COSTS[entry["type"]]})
		y += 68.0
	_label(build_menu, "B 或 ESC 关闭", 10, Color(0.7, 0.85, 0.82), Vector2(14, 332))


func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	toast_box.name = "Toasts"
	toast_box.position = Vector2(336, 172)
	toast_box.size = Vector2(490, 170)
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.add_theme_constant_override("separation", 5)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.z_index = 4
	root_ui.add_child(toast_box)


func _build_end_overlay() -> void:
	end_overlay = Control.new()
	end_overlay.name = "EndOverlay"
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	end_overlay.visible = false
	end_overlay.z_index = 10
	root_ui.add_child(end_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.07, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_overlay.add_child(dim)
	var card := Panel.new()
	card.position = Vector2(390, 208)
	card.size = Vector2(500, 304)
	card.add_theme_stylebox_override("panel", _style(BG, GOLD, 3, 18.0))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	end_overlay.add_child(card)
	end_title = _label(card, "", 30, CREAM, Vector2(24, 22))
	end_reason = _label(card, "", 14, MINT, Vector2(24, 76), 452.0)
	end_stats = _label(card, "", 13, Color(0.8, 0.92, 0.88), Vector2(24, 136))
	var restart := Button.new()
	restart.text = "重开一局  [R]"
	restart.position = Vector2(24, 214)
	restart.size = Vector2(452, 56)
	restart.focus_mode = Control.FOCUS_NONE
	restart.add_theme_font_override("font", _font)
	restart.add_theme_font_size_override("font_size", 18)
	restart.add_theme_color_override("font_color", CREAM)
	restart.add_theme_color_override("font_hover_color", Color.WHITE)
	restart.add_theme_stylebox_override("normal", _style(Color(0.12, 0.26, 0.25), MINT, 2, 0.0))
	restart.add_theme_stylebox_override("hover", _style(Color(0.16, 0.34, 0.32), GOLD, 2, 0.0))
	restart.add_theme_stylebox_override("pressed", _style(Color(0.09, 0.2, 0.19), MINT, 2, 0.0))
	restart.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	restart.pressed.connect(func() -> void: restart_requested.emit())
	card.add_child(restart)


# ── runtime ───────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if world == null:
		return
	_pulse += delta
	_snapshot = world.get_ui_snapshot()
	_update_panels(_snapshot)
	_update_floaters(delta)
	_update_build_costs()
	_update_end(_snapshot)
	overlay.queue_redraw()


func _update_panels(s: Dictionary) -> void:
	labels["objective"].text = "目标：扩建到 %d 格，或撑到第 %d 天" % [s["target_tiles"], s["win_day"]]
	labels["tiles"].text = "木筏 %d / %d 格" % [s["tiles"], s["target_tiles"]]
	bars["tiles"].value = minf(100.0, 100.0 * float(s["tiles"]) / float(s["target_tiles"]))
	var f: float = s["day_fraction"]
	var phase := "清晨"
	if f >= 0.22 and f < 0.62:
		phase = "白天"
	elif f >= 0.62 and f < 0.78:
		phase = "黄昏"
	elif f >= 0.78:
		phase = "夜晚"
	labels["day"].text = "第 %d 天 · %s" % [s["day"], phase]
	bars["day"].value = f * 100.0

	for key in ["thirst", "hunger", "stamina"]:
		var v: float = s[key]
		bars[key].value = v
		gauges[key].text = str(int(round(v)))
		gauges[key].modulate = Color(1, 0.65, 0.55) if v < 25.0 else Color.WHITE
		bars[key].modulate = Color(1, 0.65, 0.55) if v < 25.0 else Color.WHITE

	var inv: Dictionary = s["inv"]
	for key in resources:
		resources[key].text = "x%d" % int(inv.get(key, 0))
	labels["storage"].text = "木箱 %d 木材 / %d 木板 · 自动存取" % [s["storage_wood"], s["storage_planks"]]
	prompt_label.text = s["prompt"]
	prompt_panel.visible = s["prompt"] != "" and not _build_open
	var charging: bool = s["hook_state"] == "charging"
	charge_bar.visible = charging
	if charging:
		charge_bar.value = float(s["charge"]) * 100.0
		charge_bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END


func _project(p: Vector3) -> Vector2:
	if world == null or world.camera == null or container == null:
		return Vector2(-2000, -2000)
	var vp := world.world_to_viewport(p)
	var scale := container.size / Vector2(640.0, 360.0)
	return vp * scale


func _draw_overlay() -> void:
	if world == null or _snapshot.is_empty():
		return
	if world.state != RaftWorld.STATE_PLAYING:
		return
	if not _snapshot.get("lock_visible", false):
		return
	var target := _project(_snapshot["lock_world"])
	var player := _project(_snapshot["player_world"] + Vector3(0.0, 1.1, 0.0))
	var pulse := 0.72 + 0.28 * sin(_pulse * 7.0)
	var teal := Color(0.62, 0.98, 0.86, 0.9)
	var dark := Color(0.03, 0.08, 0.08, 0.7)
	# 自瞄虚线
	overlay.draw_dashed_line(player, target, Color(0.62, 0.98, 0.86, 0.35), 2.0, 6.0)
	# 四角框
	var r := 26.0 + (1.0 - pulse) * 8.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := target + Vector2(sx * r, sy * r)
			overlay.draw_line(corner, corner + Vector2(-sx * 10.0, 0.0), teal, 2.5)
			overlay.draw_line(corner, corner + Vector2(0.0, -sy * 10.0), teal, 2.5)
	overlay.draw_circle(target, 3.0, teal)
	overlay.draw_circle(target, 8.0 + pulse * 4.0, Color(0.62, 0.98, 0.86, 0.12))
	# 蓄力环
	if _snapshot["hook_state"] == "charging":
		overlay.draw_arc(target, r + 8.0, -PI / 2.0, -PI / 2.0 + TAU * float(_snapshot["charge"]),
			32, GOLD, 3.5, true)
	var dist: float = _snapshot["target_dist"]
	var text := "自动锁定 · %s · %.1fm" % [_snapshot["target_name"], dist]
	overlay.draw_string(_font, target + Vector2(-120.0, -r - 15.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, 240.0, 15, Color(0.94, 1.0, 0.92))
	# 钩子回线时在屏幕边缘画小提示点
	if _snapshot.get("hook_visible", false):
		var hp := _project(_snapshot["hook_world"])
		overlay.draw_circle(hp, 2.5, Color(0.95, 0.85, 0.55, 0.75))


func show_toast(text: String, color := MINT) -> void:
	if toast_box == null:
		return
	var pc := PanelContainer.new()
	var sb := _style(Color(0.04, 0.09, 0.10, 0.94), Color(color, 0.75), 1, 8.0)
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(450, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(l)
	toast_box.add_child(pc)
	while toast_box.get_child_count() > 3:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	pc.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(pc, "modulate:a", 1.0, 0.16)
	tw.tween_interval(2.0)
	tw.tween_property(pc, "modulate:a", 0.0, 0.35)
	tw.tween_callback(pc.queue_free)


func clear_toasts() -> void:
	if toast_box == null:
		return
	for child in toast_box.get_children():
		child.queue_free()


func clear_floaters() -> void:
	for f in floaters:
		if is_instance_valid(f["label"]):
			f["label"].queue_free()
	floaters.clear()


func show_float(text: String, color: Color, world_pos: Vector3) -> void:
	if float_root == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.06, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(280, 26)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_root.add_child(l)
	floaters.append({"label": l, "pos": world_pos, "t": 0.0, "life": 1.35})


func _update_floaters(delta: float) -> void:
	for i in range(floaters.size() - 1, -1, -1):
		var f: Dictionary = floaters[i]
		var l: Label = f["label"]
		if not is_instance_valid(l):
			floaters.remove_at(i)
			continue
		f["t"] = float(f["t"]) + delta
		var t: float = f["t"]
		var p := _project(f["pos"]) + Vector2(0.0, -18.0 - t * 26.0)
		l.position = p - Vector2(140.0, 13.0)
		l.modulate.a = clampf(1.0 - maxf(0.0, t - 0.65) / 0.7, 0.0, 1.0)
		if t >= 1.35:
			l.queue_free()
			floaters.remove_at(i)


func _update_build_costs() -> void:
	if world == null:
		return
	for row in build_rows:
		var cost_map: Dictionary = row["cost_map"]
		var ok := true
		for res in cost_map:
			if world.total_resource(res) < int(cost_map[res]):
				ok = false
				break
		var l: Label = row["cost"]
		l.add_theme_color_override("font_color", GOLD if ok else CORAL)
		var btn: Button = row["button"]
		btn.modulate = Color(1, 1, 1, 1) if ok else Color(0.85, 0.75, 0.72, 1.0)


func _update_end(s: Dictionary) -> void:
	if s["state"] == RaftWorld.STATE_PLAYING:
		return
	if _end_shown:
		return
	_end_shown = true
	end_overlay.visible = true
	if toast_box != null:
		toast_box.visible = false
	var won: bool = s["state"] == RaftWorld.STATE_WON
	end_title.text = "靠 岸 了" if won else "漂 流 结 束"
	end_title.add_theme_color_override("font_color", GOLD if won else CORAL)
	end_reason.text = s["end_reason"]
	end_stats.text = "木筏 %d / %d 格 · 第 %d 天 · 木箱 %d 木材" % [
		s["tiles"], s["target_tiles"], s["day"], s["storage_wood"]]
	_build_open = false
	build_menu.visible = false


# ── external ──────────────────────────────────────────────────────────────
func toggle_build(force: Variant = null) -> bool:
	if force is bool:
		_build_open = force
	else:
		_build_open = not _build_open
	build_menu.visible = _build_open
	return _build_open


func close_build() -> void:
	_build_open = false
	if build_menu != null:
		build_menu.visible = false


func is_build_open() -> bool:
	return _build_open


func _on_build_pressed(type: String) -> void:
	close_build()
	build_selected.emit(type)
