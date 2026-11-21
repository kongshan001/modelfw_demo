class_name MagicHud
extends Control

# 1280x720 logical HUD, drawn with a single scaled transform so the same code
# renders at 720p, 1080p or a resized window. Monospace data + CJK labels.

const SpellDataScript = preload("res://scripts/spell_data.gd")

const LOGICAL := Vector2(1280, 720)
const BUDGET := 2400

var main: Node
var font_sans: SystemFont
var font_mono: SystemFont
var font_display: SystemFont

var popups: Array[Dictionary] = []
var _aim_mouse := Vector2(-100, -100)
var _aim_dummy: Node = null
var _ui_scale := 1.0
var _ui_offset := Vector2.ZERO
var _charge_pulse := 0.0
var _time_anim := 0.0

var _panel_sb: StyleBoxFlat
var _chip_sb: StyleBoxFlat
var _chip_sel: StyleBoxFlat

func setup(p_main: Node) -> void:
	main = p_main
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	font_sans = SystemFont.new()
	font_sans.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans CJK SC", "Arial Unicode MS", "Arial"])
	font_sans.font_weight = 500
	font_sans.antialiasing = TextServer.FONT_ANTIALIASING_GRAY

	font_mono = SystemFont.new()
	font_mono.font_names = PackedStringArray(["Menlo", "SF Mono", "JetBrains Mono", "Consolas", "DejaVu Sans Mono", "monospace"])
	font_mono.font_weight = 600

	font_display = SystemFont.new()
	font_display.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "PingFang SC", "Arial"])
	font_display.font_weight = 700

	_panel_sb = StyleBoxFlat.new()
	_panel_sb.bg_color = Color(0.028, 0.038, 0.070, 0.82)
	_panel_sb.border_color = Color(1, 1, 1, 0.07)
	_panel_sb.set_border_width_all(1)
	_panel_sb.set_corner_radius_all(3)
	_panel_sb.content_margin_left = 14
	_panel_sb.content_margin_right = 14
	_panel_sb.content_margin_top = 10
	_panel_sb.content_margin_bottom = 10

	_chip_sb = StyleBoxFlat.new()
	_chip_sb.bg_color = Color(0.031, 0.041, 0.075, 0.86)
	_chip_sb.border_color = Color(1, 1, 1, 0.08)
	_chip_sb.set_border_width_all(1)
	_chip_sb.set_corner_radius_all(4)

	_chip_sel = StyleBoxFlat.new()
	_chip_sel.bg_color = Color(0.07, 0.08, 0.14, 0.9)
	_chip_sel.border_color = Color(1, 1, 1, 0.16)
	_chip_sel.set_border_width_all(1)
	_chip_sel.set_corner_radius_all(4)

func add_popup(world_pos: Vector3, text: String, color: Color, life := 0.9) -> void:
	popups.append({"pos": world_pos, "text": text, "color": color, "age": 0.0, "life": life})

func clear_popups() -> void:
	popups.clear()

func pulse_charge() -> void:
	_charge_pulse = 1.0

func set_aim(mouse: Vector2, dummy: Node) -> void:
	_aim_mouse = mouse
	_aim_dummy = dummy

func _process(delta: float) -> void:
	_time_anim += delta
	_charge_pulse = maxf(0.0, _charge_pulse - delta * 2.5)
	for i in range(popups.size() - 1, -1, -1):
		popups[i]["age"] = float(popups[i]["age"]) + delta
		if float(popups[i]["age"]) >= float(popups[i]["life"]):
			popups.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if main == null:
		return
	var vp := size
	_ui_scale = minf(vp.x / LOGICAL.x, vp.y / LOGICAL.y)
	_ui_offset = (vp - LOGICAL * _ui_scale) * 0.5
	draw_set_transform(_ui_offset, 0.0, Vector2(_ui_scale, _ui_scale))

	var accent: Color = main.spell.accent if not main.spell.is_empty() else Color(0.65, 0.5, 1.0)
	_draw_gradients()
	_draw_header(accent)
	_draw_stats(accent)
	_draw_bottom(accent)
	_draw_dummy_markers(accent)
	_draw_crosshair(accent)
	_draw_popups()

# ── panels ───────────────────────────────────────────────────────────────────

func _draw_gradients() -> void:
	var top := Color(0.0, 0.004, 0.012, 0.55)
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 118), Vector2(0, 118)]),
		PackedColorArray([top, top, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, 560), Vector2(1280, 560), Vector2(1280, 720), Vector2(0, 720)]),
		PackedColorArray([clear, clear, top, top]))

func _draw_header(accent: Color) -> void:
	draw_rect(Rect2(36, 40, 4, 40), accent)
	draw_string(font_mono, Vector2(52, 60), "MAGIC PROJECTILE LAB", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.92, 0.95, 1.0))
	draw_string(font_sans, Vector2(52, 79), "魔法发射实验室 · 蓄力 / 发射 / 拖尾 / 命中", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.62, 0.71, 0.9))
	draw_string(font_mono, Vector2(52, 97), "GODOT 4.6 · GPUPARTICLES3D · GL COMPATIBILITY · ORIGINAL VFX", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.42, 0.5, 0.68))

func _draw_stats(accent: Color) -> void:
	var showing: bool = main.stats_visible
	var h := 66.0 if not showing else 66.0 + 5 * 17.0 + 10.0
	var panel := Rect2(1002, 26, 242, h)
	draw_style_box(_panel_sb, panel)
	# FPS (screenshots show STILL; movie shows its fixed 30 fps; live shows real)
	var fps_text := "%d" % int(round(main.fps_current))
	var fps_label := "FPS"
	if main.display_still:
		fps_text = "—"
		fps_label = "STILL"
	elif main.fps_override > 0.0:
		fps_text = "%d" % int(round(main.fps_override))
		fps_label = "FPS · REC"
	draw_string(font_mono, Vector2(1018, 62), fps_text, HORIZONTAL_ALIGNMENT_RIGHT, 150, 30, Color(0.94, 0.97, 1.0))
	draw_string(font_mono, Vector2(1178, 62), fps_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.63, 0.8))
	if main.display_still:
		draw_string(font_mono, Vector2(1018, 79), "REAL GPU · %d×%d" % [int(size.x), int(size.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.48, 0.56, 0.72))
	else:
		draw_string(font_mono, Vector2(1018, 79), "FRAME %.1f MS" % (1000.0 / maxf(main.fps_current, 1.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.48, 0.56, 0.72))
	if not showing:
		draw_string(font_mono, Vector2(1018, 82), "F · STATS", HORIZONTAL_ALIGNMENT_RIGHT, 210, 8, Color(0.4, 0.47, 0.62))
		return
	draw_line(Vector2(1018, 90), Vector2(1228, 90), Color(1, 1, 1, 0.08), 1.0)
	var rows := [
		["DRAW CALLS", "%d" % main.draw_calls],
		["PARTICLES", "%d / %d" % [main.particles_now, BUDGET]],
		["PROJECTILES", "%d" % main.projectiles.size()],
		["IMPACTS", "%d" % main.impacts.size()],
		["TIME SCALE", "STILL" if main.display_still else "%.2f×" % (0.25 if main.slowmo else 1.0)],
	]
	var y := 108.0
	for r in rows:
		draw_string(font_mono, Vector2(1018, y), String(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.46, 0.55, 0.72))
		var val_col := Color(0.8, 0.86, 1.0)
		if String(r[0]) == "TIME SCALE" and main.slowmo:
			val_col = accent
		draw_string(font_mono, Vector2(1088, y), String(r[1]), HORIZONTAL_ALIGNMENT_RIGHT, 140, 9, val_col)
		y += 17.0
	# budget bar
	var frac := clampf(float(main.particles_now) / float(BUDGET), 0.0, 1.0)
	draw_rect(Rect2(1018, y - 4, 210, 3), Color(1, 1, 1, 0.08))
	var bar_col := accent.lerp(Color(1.0, 0.3, 0.25), clampf(frac * 1.4 - 0.4, 0.0, 1.0))
	draw_rect(Rect2(1018, y - 4, 210 * frac, 3), bar_col)

func _draw_bottom(accent: Color) -> void:
	# spell chips
	var spells := SpellDataScript.all()
	var chip_w := 202.0
	var gap := 14.0
	var total := chip_w * 3.0 + gap * 2.0
	var x0 := (1280.0 - total) * 0.5
	for i in spells.size():
		var s: Dictionary = spells[i]
		var x := x0 + float(i) * (chip_w + gap)
		var rect := Rect2(x, 598, chip_w, 58)
		var selected: bool = int(i) == int(main.spell_index)
		draw_style_box(_chip_sel if selected else _chip_sb, rect)
		var col: Color = s.accent
		if selected:
			draw_rect(Rect2(x, 598, chip_w, 2), col)
			draw_rect(Rect2(x, 598, 3, 58), col)
		else:
			draw_rect(Rect2(x, 598, chip_w, 2), Color(col.r, col.g, col.b, 0.35))
		# key box
		draw_rect(Rect2(x + 14, 614, 26, 26), Color(col.r, col.g, col.b, 0.16 if selected else 0.08))
		draw_string(font_mono, Vector2(x + 14, 632), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 26, 12, col)
		draw_string(font_sans, Vector2(x + 52, 626), String(s.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.92, 0.95, 1.0))
		draw_string(font_mono, Vector2(x + 52, 644), String(s.en), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.64, 0.82))
	draw_string(font_sans, Vector2(x0, 676), String(spells[main.spell_index].desc), HORIZONTAL_ALIGNMENT_CENTER, total, 9, Color(0.5, 0.58, 0.75).lerp(accent, 0.3))

	# charge meter / hint
	var mid_x := 640.0
	if main.charging:
		var charge: float = clampf(main.charge, 0.0, 1.0)
		var pw := 0.6 + 0.75 * pow(charge, 0.75)
		var bar_w := 420.0
		var by := 574.0
		draw_string(font_mono, Vector2(mid_x - bar_w * 0.5, by - 8), "CHARGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.62, 0.7, 0.88))
		draw_string(font_mono, Vector2(mid_x - bar_w * 0.5 + 60, by - 8), "%d%%" % int(charge * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, accent)
		draw_string(font_mono, Vector2(mid_x + bar_w * 0.5 - 200, by - 8), "POWER %.2f×" % pw, HORIZONTAL_ALIGNMENT_RIGHT, 200, 10, Color(0.8, 0.86, 1.0))
		draw_rect(Rect2(mid_x - bar_w * 0.5, by, bar_w, 4), Color(1, 1, 1, 0.10))
		draw_rect(Rect2(mid_x - bar_w * 0.5, by, bar_w * charge, 4), accent)
		draw_rect(Rect2(mid_x + bar_w * 0.5 * (charge * 2.0 - 1.0) - 2, by - 2, 4, 8), Color(1, 1, 1, 0.9))
		if _charge_pulse > 0.0:
			draw_arc(Vector2(mid_x, by + 2), 34 + (1.0 - _charge_pulse) * 24, 0, TAU, 40, Color(accent.r, accent.g, accent.b, _charge_pulse * 0.4), 1.5, true)
	else:
		draw_string(font_sans, Vector2(0, 580), "按住 空格 / 左键 蓄力 · 松开 发射", HORIZONTAL_ALIGNMENT_CENTER, 1280, 10, Color(0.52, 0.6, 0.78))

	# controls
	draw_string(font_sans, Vector2(36, 688), "空格 / 左键 蓄力发射   ·   1 / 2 / 3 切换魔法   ·   T 慢放   ·   R 重置   ·   F 统计   ·   A 自动演示", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.44, 0.52, 0.68))
	draw_string(font_mono, Vector2(36, 702), "HOLD TO CHARGE · RELEASE TO FIRE · ORIGINAL PROCEDURAL TEXTURES & MESHES", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.3, 0.37, 0.52))

	# auto demo / capture badge
	if main.capture_badge != "":
		_draw_badge(Vector2(640, 30), main.capture_badge, Color(1.0, 0.38, 0.34))
	elif main.auto_demo:
		var a := 0.55 + 0.35 * sin(_time_anim * 2.4)
		_draw_badge(Vector2(640, 30), "● AUTO DEMO", Color(accent.r, accent.g, accent.b, a))
	# slow-mo badge
	if main.slowmo:
		_draw_badge(Vector2(640, 48), "SLOW-MO 0.25× · T", accent)

func _draw_badge(center: Vector2, text: String, col: Color) -> void:
	var w := 150.0
	var r := Rect2(center.x - w * 0.5, center.y - 9, w, 17)
	draw_rect(r, Color(0.02, 0.03, 0.06, 0.7))
	draw_string(font_mono, Vector2(r.position.x, r.position.y + 12), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, col)

func _draw_dummy_markers(accent: Color) -> void:
	if main.camera == null:
		return
	for d in main.dummies:
		if not d.alive:
			continue
		var chest: Vector3 = d.get_chest_position()
		var sp: Vector2 = main.camera.unproject_position(chest)
		var lp := (sp - _ui_offset) / _ui_scale
		if lp.x < 0 or lp.y < 0 or lp.x > 1280 or lp.y > 720:
			continue
		# health pips above the head
		var head_sp: Vector2 = main.camera.unproject_position(d.get_head_position() + Vector3(0, 0.35, 0))
		var hp_pos := (head_sp - _ui_offset) / _ui_scale
		var hovered: bool = d == main.hover_dummy or d == main.aim_dummy
		for i in 3:
			var pip_col := Color(1, 1, 1, 0.16)
			if i < d.hp:
				pip_col = accent if hovered else Color(accent.r, accent.g, accent.b, 0.75)
			draw_rect(Rect2(hp_pos.x - 14 + i * 10, hp_pos.y - 14, 7, 3), pip_col)
		if hovered:
			var w := 34.0
			var h := 46.0
			var col := Color(accent.r, accent.g, accent.b, 0.85)
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var cx: float = lp.x + float(sx) * w
					var cy: float = lp.y + float(sy) * h
					draw_line(Vector2(cx, cy), Vector2(cx - float(sx) * 10.0, cy), col, 1.5)
					draw_line(Vector2(cx, cy), Vector2(cx, cy - float(sy) * 10.0), col, 1.5)
			draw_string(font_mono, Vector2(lp.x - 20, lp.y + h + 14), "TARGET", HORIZONTAL_ALIGNMENT_CENTER, 40, 7, col)
		# broken targets show rebuild hint
	for d in main.dummies:
		if d.alive:
			continue
		var sp2: Vector2 = main.camera.unproject_position(d.global_position + Vector3(0, 0.6, 0))
		var lp2 := (sp2 - _ui_offset) / _ui_scale
		if lp2.x < 0 or lp2.y < 0 or lp2.x > 1280 or lp2.y > 720:
			continue
		draw_string(font_mono, Vector2(lp2.x - 40, lp2.y), "REBUILDING", HORIZONTAL_ALIGNMENT_CENTER, 80, 7, Color(0.5, 0.57, 0.72, 0.7))

func _draw_crosshair(accent: Color) -> void:
	if main.capture_mode or not main.mouse_seen:
		return
	var lp := (_aim_mouse - _ui_offset) / _ui_scale
	if lp.x < 0 or lp.y < 0 or lp.x > 1280 or lp.y > 720:
		return
	var col := Color(accent.r, accent.g, accent.b, 0.85)
	var r := 11.0 + (2.0 if _aim_dummy != null else 0.0)
	draw_arc(lp, r, 0.0, TAU, 28, col, 1.2, true)
	for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
		var dir: Vector2 = Vector2(cos(float(ang)), sin(float(ang)))
		draw_line(lp + dir * (r + 2.0), lp + dir * (r + 6.0), col, 1.2)
	draw_circle(lp, 1.4, Color(1, 1, 1, 0.9))
	if main.charging:
		draw_arc(lp, r + 7.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(main.charge, 0.0, 1.0), 32, Color(accent.r, accent.g, accent.b, 0.9), 2.0, true)

func _draw_popups() -> void:
	if main.camera == null:
		return
	for p in popups:
		var age: float = p.age
		var life: float = p.life
		var sp: Vector2 = main.camera.unproject_position(p.pos)
		var lp := (sp - _ui_offset) / _ui_scale
		var rise := 26.0 * (1.0 - exp(-age * 5.0))
		var alpha := 1.0 - smoothstep(life * 0.55, life, age)
		var col: Color = p.color
		var size_px := 12.0 + 3.0 * clampf(1.0 - age * 3.0, 0.0, 1.0)
		var pos := Vector2(lp.x - 60, lp.y - rise)
		draw_string(font_mono, pos + Vector2(1, 1), String(p.text), HORIZONTAL_ALIGNMENT_CENTER, 120, size_px, Color(0, 0, 0, alpha * 0.6))
		draw_string(font_mono, pos, String(p.text), HORIZONTAL_ALIGNMENT_CENTER, 120, size_px, Color(col.r, col.g, col.b, alpha))
