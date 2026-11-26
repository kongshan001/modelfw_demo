class_name EmberHUD
extends Control
## Chinese HUD / menu / pause / result, drawn procedurally at 1280x720 logical.
## Handles its own hit rects; game actions are emitted as signals.

signal action(id: String)
signal field_pressed(local_pos: Vector2, button: int)
signal field_moved(local_pos: Vector2)
signal field_exited

const GData = preload("res://scripts/game_data.gd")
const EMath = preload("res://scripts/ember_math.gd")
const MData = preload("res://scripts/map_data.gd")
const Fonts = preload("res://scripts/font_lib.gd")

const W := 1280.0
const H := 720.0
const TOP_H := 48.0
const FIELD := Rect2(0, 48, 928, 672)
const PANEL := Rect2(928, 48, 352, 672)

var model = null
var scene_name := "menu"
var selected_tower = null
var build_type := ""
var menu_map := "ashen"
var game_speed := 1
var fps := 60
var draw_calls := 0
var hover_enemy = null
var real_time := 0.0
var mouse_pos := Vector2(-999, -999)
var toast_title := ""
var toast_sub := ""
var toast_t := 0.0
var life_flash := 0.0
var skill_flash := 0.0
var hits: Array[Dictionary] = []
var previews: Dictionary = {}
var _font: Font
var _bold: Font
var _mono: Font
var _pal: Dictionary = {}
var _vignette: ImageTexture
var _shade: ImageTexture
var _hover_id := ""
var _hover_shop := ""
var debug_skip_text := false
var hide_perf := false
var _hud_accum := 0.0
var _wcache: Dictionary = {}
var hud_interval := 1.0 / 10.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = Fonts.regular()
	_bold = Fonts.bold()
	_mono = Fonts.mono()
	for k in GData.PAL.keys():
		_pal[k] = Color(GData.PAL[k])
	previews["ashen"] = MData.prepare("ashen")
	previews["frost"] = MData.prepare("frost")
	_vignette = _make_vignette()
	_shade = _make_shade()


func _c(key: String) -> Color:
	return _pal[key]


func show_toast(title: String, sub: String) -> void:
	toast_title = title
	toast_sub = sub
	toast_t = 2.2


func flash_life() -> void:
	life_flash = 0.8


func flash_skill() -> void:
	skill_flash = 1.0


func _make_vignette() -> ImageTexture:
	var w := 232
	var h := 168
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var nx := (float(x) / float(w - 1) - 0.5) * 2.0
			var ny := (float(y) / float(h - 1) - 0.5) * 2.0
			var d := sqrt(nx * nx + ny * ny)
			var a := clampf((d - 0.55) / 0.85, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.02, 0.015, 0.03, a * 0.30))
	return ImageTexture.create_from_image(img)


func _make_shade() -> ImageTexture:
	var img := Image.create(1, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var t := float(y) / 63.0
		var a := 0.0
		if t < 0.32:
			a = lerpf(0.62, 0.0, t / 0.32)
		elif t > 0.72:
			a = lerpf(0.0, 0.62, (t - 0.72) / 0.28)
		img.set_pixel(0, y, Color(0.02, 0.015, 0.03, a))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	real_time += delta
	if toast_t > 0.0:
		toast_t = maxf(0.0, toast_t - delta)
	if life_flash > 0.0:
		life_flash = maxf(0.0, life_flash - delta * 1.8)
	if skill_flash > 0.0:
		skill_flash = maxf(0.0, skill_flash - delta * 2.2)
	# cursor feedback
	var over_hit := false
	for h in hits:
		if h["rect"].has_point(mouse_pos) and h["enabled"]:
			over_hit = true
			break
	var field_ok := FIELD.has_point(mouse_pos) and (scene_name == "playing" or scene_name == "paused")
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over_hit else
		(Input.CURSOR_CROSS if field_ok else Input.CURSOR_ARROW))
	_hud_accum += delta
	if _hud_accum >= hud_interval:
		_hud_accum = fmod(_hud_accum, hud_interval)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_pos = event.position
		if FIELD.has_point(mouse_pos) and (scene_name == "playing" or scene_name == "paused"):
			field_moved.emit(mouse_pos - FIELD.position)
		elif scene_name == "playing" or scene_name == "paused":
			field_exited.emit()
	elif event is InputEventMouseButton and event.pressed:
		mouse_pos = event.position
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if FIELD.has_point(mouse_pos):
				field_pressed.emit(mouse_pos - FIELD.position, 2)
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		for i in range(hits.size() - 1, -1, -1):
			var h: Dictionary = hits[i]
			if h["rect"].has_point(mouse_pos) and h["enabled"]:
				var id: String = h["id"]
				if id != "":
					action.emit(id)
				accept_event()
				return
		if FIELD.has_point(mouse_pos) and (scene_name == "playing" or scene_name == "paused"):
			field_pressed.emit(mouse_pos - FIELD.position, 1)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		mouse_pos = Vector2(-999, -999)
		field_exited.emit()


# ---------- drawing helpers ----------

func _measure(s: String, size: int, bold: bool) -> float:
	var key := ("b" if bold else "r") + str(size) + "|" + s
	if _wcache.has(key):
		return _wcache[key]
	var f: Font = _bold if bold else _font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if _wcache.size() > 2500:
		_wcache.clear()
	_wcache[key] = w
	return w


func text(s: String, x: float, y: float, size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = false) -> void:
	if debug_skip_text:
		return
	var f: Font = _bold if bold else _font
	var w := _measure(s, size, bold)
	var px := x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		px = x - w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		px = x - w
	draw_string(f, Vector2(round(px), round(y + size * 0.34)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func clip_text(s: String, x: float, y: float, size: int, color: Color, max_w: float,
		bold: bool = false) -> void:
	if debug_skip_text:
		return
	var f: Font = _bold if bold else _font
	var t := s
	if _measure(t, size, bold) > max_w:
		while t.length() > 1 and _measure(t + "…", size, bold) > max_w:
			t = t.substr(0, t.length() - 1)
		t += "…"
	draw_string(f, Vector2(round(x), round(y + size * 0.34)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func spaced(s: String, x: float, y: float, spacing: float, size: int, color: Color) -> void:
	if debug_skip_text:
		return
	var f := _bold
	var widths: Array[float] = []
	var total := 0.0
	for i in s.length():
		var ch := s.substr(i, 1)
		var w := _measure(ch, size, true)
		widths.append(w)
		total += w
	total += spacing * (s.length() - 1)
	var px := x - total * 0.5
	for i in s.length():
		var ch := s.substr(i, 1)
		draw_string(f, Vector2(round(px), round(y + size * 0.34)), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		px += widths[i] + spacing


func panel(rect: Rect2, fill: Color, border: Color, border_w: int = 1) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, border, false, border_w)


func separator(y: float) -> void:
	draw_rect(Rect2(PANEL.position.x, y, PANEL.size.x, 1), _c("line"))


func add_hit(id: String, rect: Rect2, enabled: bool = true) -> void:
	hits.append({"id": id, "rect": rect, "enabled": enabled})


func hovered(rect: Rect2) -> bool:
	return rect.has_point(mouse_pos)


func button(id: String, rect: Rect2, label: String, enabled: bool = true,
		primary: bool = false, active: bool = false, size: int = 14) -> void:
	var hov := hovered(rect) and enabled
	var fill := Color(0.10, 0.08, 0.14)
	var border := _c("line")
	if primary or active:
		fill = Color(0.24, 0.12, 0.08)
		border = _c("ember")
	if hov:
		fill = fill.lightened(0.08)
		border = _c("ember_hi") if (primary or active or hov) else _c("bone_dim")
	if not enabled:
		fill = Color(0.08, 0.07, 0.10)
		border = _c("line")
	panel(rect, fill, border)
	var color := _c("bone") if enabled else _c("dim")
	if primary or active:
		color = _c("ember_hi") if enabled else _c("dim")
	text(label, rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5,
		size, color, HORIZONTAL_ALIGNMENT_CENTER, true)
	add_hit(id, rect, enabled)


func coin_icon(x: float, y: float, r: float = 6.0) -> void:
	draw_circle(Vector2(x, y), r, _c("gold"))
	draw_circle(Vector2(x, y), r * 0.55, _c("gold_hi"))
	draw_circle(Vector2(x, y), r * 0.22, _c("ink"))


func life_icon(x: float, y: float, s: float = 7.0) -> void:
	var pts := PackedVector2Array([
		Vector2(x, y - s), Vector2(x + s * 0.8, y + s * 0.6),
		Vector2(x, y + s * 0.3), Vector2(x - s * 0.8, y + s * 0.6),
	])
	draw_colored_polygon(pts, _c("life"))
	draw_circle(Vector2(x, y + s * 0.15), s * 0.28, _c("gold_hi"))


func tower_icon(type: String, x: float, y: float, s: float) -> void:
	draw_rect(Rect2(x - s * 0.55, y + s * 0.1, s * 1.1, s * 0.35), Color(0.28, 0.25, 0.30))
	draw_rect(Rect2(x - s * 0.7, y + s * 0.42, s * 1.4, s * 0.12), Color(0.16, 0.14, 0.19))
	match type:
		"bolt":
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y - s * 0.65), Vector2(x + s * 0.20, y + s * 0.1),
				Vector2(x, y - s * 0.02), Vector2(x - s * 0.20, y + s * 0.1)]), _c("ember"))
			draw_line(Vector2(x - s * 0.45, y - s * 0.15), Vector2(x + s * 0.45, y - s * 0.15), _c("bone_dim"), 2.0)
		"flame":
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y - s * 0.75), Vector2(x + s * 0.34, y + s * 0.12),
				Vector2(x, y + s * 0.42), Vector2(x - s * 0.34, y + s * 0.12)]), Color("#ff6b3a"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y - s * 0.35), Vector2(x + s * 0.16, y + s * 0.10),
				Vector2(x, y + s * 0.28), Vector2(x - s * 0.16, y + s * 0.10)]), _c("ember_hi"))
		"frost":
			var pts := PackedVector2Array([
				Vector2(x, y - s * 0.7), Vector2(x + s * 0.28, y + s * 0.02),
				Vector2(x, y + s * 0.48), Vector2(x - s * 0.28, y + s * 0.02)])
			draw_colored_polygon(pts, _c("frost"))
			draw_line(Vector2(x, y - s * 0.55), Vector2(x, y + s * 0.35), _c("frost_hi"), 1.5)
			draw_line(Vector2(x - s * 0.2, y + s * 0.02), Vector2(x + s * 0.2, y + s * 0.02), _c("frost_hi"), 1.5)
		"mint":
			draw_circle(Vector2(x, y - s * 0.25), s * 0.38, _c("gold"))
			draw_circle(Vector2(x, y - s * 0.25), s * 0.22, _c("gold_hi"))
			draw_line(Vector2(x, y - s * 0.4), Vector2(x, y - s * 0.1), _c("ink"), 2.0)


func wave_icon(x: float, y: float, color: Color) -> void:
	for i in 3:
		var yy := y - 5 + i * 4
		draw_line(Vector2(x - 6, yy), Vector2(x, yy + 2), color, 2.0)
		draw_line(Vector2(x, yy + 2), Vector2(x + 6, yy), color, 2.0)


# ---------- state reads ----------

func _phase_line() -> String:
	if model == null:
		return ""
	if model.phase == "prep":
		return "布防 · %ds" % int(ceil(model.prep))
	if model.phase == "wave":
		return "交战 · 剩余 %d" % model.remaining_enemies()
	return "战斗结束"


func _log_color(kind: String) -> Color:
	match kind:
		"build":
			return _c("green")
		"upgrade":
			return _c("gold")
		"skill":
			return _c("ember")
		"save":
			return _c("frost")
		"sell":
			return _c("red")
		_:
			return _c("muted")


# ---------- main draw ----------

func _draw() -> void:
	hits.clear()
	_hover_shop = ""
	if scene_name == "menu":
		_draw_menu()
		return
	if model == null:
		return
	_draw_field()
	_draw_top_bar()
	_draw_side_panel()
	if scene_name == "paused":
		_draw_pause()
	elif scene_name == "over":
		hits.clear()
		_draw_result()
	# flashes are drawn over the field but under menus/overlays? result covers them
	if scene_name == "playing" or scene_name == "paused":
		if skill_flash > 0.0:
			draw_rect(FIELD, Color(1.0, 0.78, 0.4, skill_flash * 0.14))
		if life_flash > 0.0:
			var a := minf(0.5, life_flash * 0.55)
			draw_rect(FIELD, Color(_c("life").r, _c("life").g, _c("life").b, a), false, 4.0)
	if model.lives <= 6 and scene_name != "over":
		var pulse := 0.18 + absf(sin(real_time * 4.0)) * 0.3
		draw_rect(Rect2(FIELD.position.x, FIELD.position.y, 3, FIELD.size.y),
			Color(_c("life").r, _c("life").g, _c("life").b, pulse))


func _draw_field() -> void:
	draw_texture_rect(_vignette, FIELD, false)
	# wave bar
	var bar := Rect2(12, 682, 904, 28)
	draw_rect(bar, Color(0.03, 0.025, 0.05, 0.86))
	draw_rect(bar, _c("line_hot"), false, 1.0)
	wave_icon(28, 696, _c("ember_hi"))
	if model.phase == "prep":
		text("第 %d 波 · %ds" % [model.wave, int(maxf(0.0, ceil(model.prep)))], 44, 694, 14, _c("ember_hi"), HORIZONTAL_ALIGNMENT_LEFT, true)
		clip_text(GData.wave_composition(model.wave - 1), 200, 694, 12, _c("bone_dim"), 610)
	elif model.phase == "wave":
		text("第 %d 波 · 剩余 %d" % [model.wave, model.remaining_enemies()], 44, 694, 14, _c("ember_hi"), HORIZONTAL_ALIGNMENT_LEFT, true)
		clip_text("击杀 %d/%d · %s" % [model.wave_kills, model.wave_total, GData.WAVES[model.wave - 1]["name"]],
			250, 694, 12, _c("bone_dim"), 560)
	else:
		text("战斗结束", 44, 694, 14, _c("bone_dim"))
	text("AI" if model.ai_on else "手动", 900, 695, 12,
		_c("green") if model.ai_on else _c("muted"), HORIZONTAL_ALIGNMENT_RIGHT, true)

	# boss bar
	if model.boss != null and model.boss.alive and model.phase == "wave":
		var bw := 400.0
		var bx := 464.0 - bw * 0.5
		var by := 104.0
		draw_rect(Rect2(bx - 10, by - 12, bw + 20, 48), Color(0.03, 0.025, 0.05, 0.9))
		draw_rect(Rect2(bx - 10, by - 12, bw + 20, 48), _c("ember_red"), false, 1.0)
		text("无光巨像", bx, by + 2, 13, _c("ember_hi"), HORIZONTAL_ALIGNMENT_LEFT, true)
		text("%d" % int(maxf(0, ceil(model.boss.hp))), bx + bw, by + 2, 12, _c("bone_dim"), HORIZONTAL_ALIGNMENT_RIGHT)
		draw_rect(Rect2(bx, by + 14, bw, 8), _c("ink"))
		var ratio: float = clampf(model.boss.hp / model.boss.max_hp, 0.0, 1.0)
		draw_rect(Rect2(bx, by + 14, bw * ratio, 8), _c("ember_red"))
		draw_rect(Rect2(bx, by + 14, bw * ratio, 2), _c("ember_hi"))

	# toast
	if toast_t > 0.0:
		var alpha := minf(1.0, toast_t / 0.3)
		var w := 340.0
		var tsize := _bold.get_string_size(toast_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 48
		var ssize := _font.get_string_size(toast_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 40
		w = clampf(maxf(tsize, ssize), 260.0, 760.0)
		var r := Rect2(464.0 - w * 0.5, 60, w, 62)
		draw_rect(r, Color(0.04, 0.03, 0.06, 0.92 * alpha))
		draw_rect(r, Color(_c("line_hot").r, _c("line_hot").g, _c("line_hot").b, alpha), false, 1.0)
		draw_rect(Rect2(r.position.x + 3, r.position.y, 4, 1), Color(_c("ember").r, _c("ember").g, _c("ember").b, alpha))
		text(toast_title, 464, r.position.y + 24, 18, Color(_c("ember_hi").r, _c("ember_hi").g, _c("ember_hi").b, alpha),
			HORIZONTAL_ALIGNMENT_CENTER, true)
		clip_text(toast_sub, 464 - (w - 40) * 0.5, r.position.y + 45, 12,
			Color(_c("bone_dim").r, _c("bone_dim").g, _c("bone_dim").b, alpha), w - 40)


func _draw_top_bar() -> void:
	draw_rect(Rect2(0, 0, W, TOP_H), Color(0.035, 0.028, 0.05, 0.97))
	draw_rect(Rect2(0, TOP_H - 1, W, 1), _c("line_hot"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(24, 30), Vector2(30, 18), Vector2(34, 27), Vector2(40, 14),
		Vector2(42, 27), Vector2(36, 35), Vector2(28, 34)]), _c("ember"))
	draw_circle(Vector2(33, 27), 3.0, _c("gold_hi"))
	text("余烬堡", 52, 24, 24, _c("bone"), HORIZONTAL_ALIGNMENT_LEFT, true)
	text("第 %d/%d 波" % [model.wave, GData.MAX_WAVE], 178, 16, 17, _c("ember_hi"), HORIZONTAL_ALIGNMENT_LEFT, true)
	clip_text(_phase_line(), 178, 35, 12, _c("muted"), 170)
	coin_icon(370, 24, 7)
	text("%d" % model.gold, 383, 23, 17, _c("gold"), HORIZONTAL_ALIGNMENT_LEFT, true)
	life_icon(466, 24, 7)
	text("%d" % model.lives, 480, 23, 17, _c("life") if model.lives <= 6 else _c("bone"), HORIZONTAL_ALIGNMENT_LEFT, true)
	# skill button
	var ready: bool = model.skill_cd <= 0.0 and scene_name == "playing"
	var srect := Rect2(552, 7, 112, 34)
	var hov := hovered(srect)
	draw_rect(srect, Color(0.20, 0.10, 0.07) if ready else Color(0.09, 0.07, 0.11))
	draw_rect(srect, _c("ember") if ready else _c("line_hot"), false, 1.0)
	tower_icon("flame", srect.position.x + 18, srect.position.y + 18, 11)
	text("烬雨 Q", srect.position.x + 34, srect.position.y + 12, 13,
		_c("ember_hi") if ready else _c("bone_dim"), HORIZONTAL_ALIGNMENT_LEFT, true)
	text("就绪" if ready else ("%ds" % int(ceil(model.skill_cd))), srect.position.x + 34,
		srect.position.y + 27, 10, _c("ember_hi") if ready else _c("muted"))
	add_hit("skill", srect, scene_name == "playing")
	# speed
	var sprect := Rect2(676, 7, 64, 34)
	button("speed", sprect, "x%d F" % game_speed, scene_name != "over", false, false, 12)
	# ai
	var aire := Rect2(752, 7, 120, 34)
	var fill := Color(0.10, 0.17, 0.09) if model.ai_on else Color(0.09, 0.07, 0.11)
	draw_rect(aire, fill)
	draw_rect(aire, _c("green") if model.ai_on else _c("line_hot"), false, 1.0)
	text("AI 托管" if model.ai_on else "AI 手动", aire.position.x + aire.size.x * 0.5,
		aire.position.y + aire.size.y * 0.5, 13,
		Color("#c6e39c") if model.ai_on else _c("bone_dim"), HORIZONTAL_ALIGNMENT_CENTER, true)
	add_hit("ai_toggle", aire)
	# map + perf
	var map_def: Dictionary = MData.MAP_DEFS[model.map_id]
	text(map_def["name"], 900, 16, 14, _c("bone_dim"), HORIZONTAL_ALIGNMENT_LEFT, true)
	text(map_def["latin"], 900, 32, 9, _c("dim"))
	if not hide_perf:
		text("%d FPS · DC %d" % [int(fps), draw_calls], 1268, 24, 11, _c("dim"), HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_side_panel() -> void:
	draw_rect(PANEL, Color("#14101a"))
	draw_rect(Rect2(PANEL.position.x, PANEL.position.y, 1, PANEL.size.y), _c("line"))
	for y in range(52, 720, 4):
		draw_rect(Rect2(PANEL.position.x + 2, y, 1, 1), Color(1, 1, 1, 0.02))
	text("建造", 940, 64, 16, _c("bone"), HORIZONTAL_ALIGNMENT_LEFT, true)
	text("点击空地放置", 1268, 64, 10, _c("dim"), HORIZONTAL_ALIGNMENT_RIGHT)
	for i in GData.TOWER_ORDER.size():
		_draw_shop_card(GData.TOWER_ORDER[i], i)
	_draw_selection()
	_draw_ai_panel()
	_draw_enemy_panel()
	_draw_controls()


func _draw_shop_card(type: String, idx: int) -> void:
	var d: Dictionary = GData.TOWERS[type]
	var r := Rect2(940, 80 + idx * 60, 328, 54)
	var hov := hovered(r)
	if hov:
		_hover_shop = type
	var active := build_type == type
	var fill := Color(0.10, 0.08, 0.13)
	if active:
		fill = Color(0.20, 0.13, 0.09)
	elif hov:
		fill = Color(0.14, 0.11, 0.17)
	draw_rect(r, fill)
	draw_rect(r, _c("ember") if active else (_c("bone_dim") if hov else _c("line")), false, 1.0)
	if active:
		draw_rect(Rect2(r.position.x + 1, r.position.y + 2, 3, r.size.y - 4), _c("ember"))
	tower_icon(type, r.position.x + 22, r.position.y + 26, 16)
	text(d["name"], r.position.x + 46, r.position.y + 17, 15, _c("ember_hi") if active else _c("bone"),
		HORIZONTAL_ALIGNMENT_LEFT, true)
	text("%s · %s" % [d["tag"], d["hotkey"]], r.position.x + 46, r.position.y + 38, 10, _c("muted"))
	coin_icon(r.position.x + r.size.x - 48, r.position.y + 18, 5.5)
	text("%d" % d["cost"], r.position.x + r.size.x - 12, r.position.y + 17, 15,
		_c("gold") if model.gold >= d["cost"] else _c("red"), HORIZONTAL_ALIGNMENT_RIGHT, true)
	add_hit("shop_" + type, r)


func _draw_selection() -> void:
	separator(344)
	var info_type := ""
	var lvl := 0
	var selected = selected_tower
	if selected != null:
		info_type = selected.type
		lvl = selected.level
	elif build_type != "":
		info_type = build_type
	elif _hover_shop != "":
		info_type = _hover_shop
	if info_type == "":
		text("选中 / 建造", 940, 360, 15, _c("bone"), HORIZONTAL_ALIGNMENT_LEFT, true)
		text("点击空地建造 · 点击塔查看", 940, 382, 11, _c("muted"))
		text("1–4 选塔 · U 升级 · S 出售", 940, 400, 11, _c("muted"))
		text("Esc / 右键取消当前选择", 940, 418, 10, _c("dim"))
		return
	var d: Dictionary = GData.TOWERS[info_type]
	var title: String = ("%s · Lv%d" % [d["name"], lvl + 1]) if selected != null else str(d["name"])
	text(title, 940, 360, 15, _c("ember_hi") if selected != null else _c("bone"), HORIZONTAL_ALIGNMENT_LEFT, true)
	text(d["tag"], 1268, 360, 10, _c("muted"), HORIZONTAL_ALIGNMENT_RIGHT)
	var lines := GData.tower_stat_lines(info_type, lvl)
	text(lines[0], 940, 384, 11, _c("bone_dim"))
	text(lines[1], 940, 402, 11, _c("bone_dim"))
	if selected != null:
		var up_cost: int = d["upgrades"][lvl] if lvl < 2 else -1
		var up_label := "已满级" if up_cost < 0 else "升级 %d金 [U]" % up_cost
		button("upgrade", Rect2(940, 416, 206, 28), up_label,
			up_cost >= 0 and model.gold >= up_cost, false, false, 12)
		button("sell", Rect2(1152, 416, 116, 28), "出售 +%d" % int(floor(selected.invested * GData.SELL_RATIO)),
			true, false, false, 11)
		clip_text(d["desc"], 940, 458, 10, _c("dim"), 328)
	elif build_type != "":
		text("造价 %d 金 · 点击空地放置" % d["cost"], 940, 428, 11,
			_c("gold") if model.gold >= d["cost"] else _c("red"))
		button("cancel_build", Rect2(940, 440, 90, 24), "取消 [Esc]", true, false, false, 10)
		clip_text(d["desc"], 1040, 452, 10, _c("dim"), 228)
	else:
		clip_text(d["desc"], 940, 428, 10, _c("dim"), 328)
		text("点击卡片选择建造", 940, 448, 10, _c("muted"))


func _draw_ai_panel() -> void:
	separator(484)
	text("AI 指挥官", 940, 499, 15, _c("bone"), HORIZONTAL_ALIGNMENT_LEFT, true)
	var chip := Rect2(1160, 487, 108, 24)
	draw_rect(chip, Color(0.14, 0.21, 0.12) if model.ai_on else Color(0.12, 0.10, 0.16))
	draw_rect(chip, _c("green") if model.ai_on else _c("line_hot"), false, 1.0)
	text("托管中" if model.ai_on else "手动", chip.position.x + 54, chip.position.y + 12, 11,
		Color("#c6e39c") if model.ai_on else _c("bone_dim"), HORIZONTAL_ALIGNMENT_CENTER, true)
	add_hit("ai_toggle", chip)
	text("共用金币/冷却 · 不作弊" if model.ai_on else "手动指挥 · 按 A 交还 AI",
		940, 518, 10, _c("green_dim") if model.ai_on else _c("dim"))
	var logs: Array = model.ai_logs.slice(maxi(0, model.ai_logs.size() - 3))
	if logs.is_empty():
		text("等待 AI 决策…" if model.ai_on else "尚无指挥记录", 940, 540, 11, _c("dim"))
	else:
		for i in range(logs.size() - 1, -1, -1):
			var log: Dictionary = logs[i]
			var ly := 542 + (logs.size() - 1 - i) * 17
			draw_rect(Rect2(940, ly - 6, 3, 12), _log_color(log["kind"]))
			clip_text(log["text"], 948, ly, 11, _c("bone") if i == logs.size() - 1 else _c("bone_dim"), 316)


func _draw_enemy_panel() -> void:
	separator(600)
	text("敌情 · 第 %d 波" % model.wave, 940, 614, 14, _c("bone"), HORIZONTAL_ALIGNMENT_LEFT, true)
	var wave_idx: int = model.wave - 1
	if model.phase == "prep" and model.wave > 1:
		text("下一波 " + GData.WAVES[wave_idx]["name"], 1268, 614, 10, _c("muted"), HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		text(GData.WAVES[wave_idx]["name"], 1268, 614, 10, _c("muted"), HORIZONTAL_ALIGNMENT_RIGHT)
	clip_text(GData.wave_composition(wave_idx), 940, 632, 10, _c("bone_dim"), 328)
	text("剩余 %d · 击杀 %d/%d · 漏怪 %d" % [model.remaining_enemies(), model.wave_kills, model.wave_total, model.leaks],
		940, 648, 10, _c("muted"))
	if hover_enemy != null:
		var ed: Dictionary = GData.ENEMIES[hover_enemy.type]
		text("%s · HP %d/%d" % [ed["name"], int(ceil(hover_enemy.hp)), int(hover_enemy.max_hp)],
			940, 664, 11, _c("ember_hi"), HORIZONTAL_ALIGNMENT_LEFT, true)
		text("护甲 %d · 速度 %d · 赏金 %d" % [ed["armor"], int(ed["speed"]), ed["reward"]],
			940, 680, 10, _c("bone_dim"))
	else:
		text("悬停敌人查看属性 · 共 5 种", 940, 670, 10, _c("dim"))


func _draw_controls() -> void:
	separator(686)
	var y := 714
	var w := 62.0
	var gap := 6.0
	button("pause", Rect2(940, y - 24, w, 30), "继续" if scene_name == "paused" else "暂停",
		true, false, scene_name == "paused", 11)
	button("speed", Rect2(940 + (w + gap), y - 24, w, 30), "x%d" % game_speed, true, false, false, 11)
	button("restart", Rect2(940 + (w + gap) * 2, y - 24, w, 30), "重开", true, false, false, 11)
	button("switch_map", Rect2(940 + (w + gap) * 3, y - 24, w, 30), "换图", true, false, false, 11)
	button("menu", Rect2(940 + (w + gap) * 4, y - 24, w, 30), "菜单", true, false, false, 11)


func _draw_pause() -> void:
	draw_rect(FIELD, Color(0.02, 0.015, 0.035, 0.5))
	var r := Rect2(184, 288, 560, 224)
	panel(r, Color(0.06, 0.05, 0.09, 0.96), _c("ember"), 1)
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 1), Color(1, 1, 1, 0.05))
	text("已暂停", 464, r.position.y + 44, 36, _c("ember_hi"), HORIZONTAL_ALIGNMENT_CENTER, true)
	text("Space 继续 · 暂停时仍可建造与升级", 464, r.position.y + 84, 14, _c("bone_dim"), HORIZONTAL_ALIGNMENT_CENTER)
	text("AI 托管暂停 · 玩家操作将自动接管" if model.ai_on else "手动指挥 · 点击侧栏按钮可交还 AI",
		464, r.position.y + 108, 12, _c("green_dim") if model.ai_on else _c("dim"), HORIZONTAL_ALIGNMENT_CENTER)
	add_hit("", r)
	button("resume", Rect2(r.position.x + 28, r.position.y + 144, 236, 44), "继续 [Space]", true, true, false, 15)
	button("pause_restart", Rect2(r.position.x + 280, r.position.y + 144, 118, 44), "重开", true, false, false, 13)
	button("pause_menu", Rect2(r.position.x + 414, r.position.y + 144, 118, 44), "菜单", true, false, false, 13)


func _draw_result() -> void:
	var over: Dictionary = model.over
	if over.is_empty():
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.015, 0.03, 0.68))
	draw_texture_rect(_shade, Rect2(0, 0, W, H), false)
	var r := Rect2(208, 96, 864, 528)
	panel(r, Color(0.055, 0.045, 0.075, 0.98), _c("ember") if over["win"] else _c("red"), 2)
	var title := "余烬未熄" if over["win"] else "灯塔熄灭"
	text(title, 640, r.position.y + 64, 52, _c("ember_hi") if over["win"] else _c("life"),
		HORIZONTAL_ALIGNMENT_CENTER, true)
	var subtitle := ""
	if over["win"]:
		subtitle = "十二波暗潮尽数退去，灯塔仍在燃烧"
	else:
		subtitle = "暗潮漫过防线 · 止步于第 %d 波" % over["wave"]
	text(subtitle, 640, r.position.y + 112, 16, _c("bone_dim"), HORIZONTAL_ALIGNMENT_CENTER)
	var rows := [
		["击杀", str(over["kills"]), "剩余生命", str(over["lives"]), "建成塔", str(over["towers"])],
		["AI 决策", str(over["ai_actions"]), "用时", EMath.fmt_time(over["time"]), "总收入", str(over["earned"])],
	]
	for row in 2:
		for col in 3:
			var cx := r.position.x + 100 + col * 230
			var cy := r.position.y + 172 + row * 74
			text(rows[row][col * 2], cx, cy, 12, _c("muted"))
			var val_color: Color = _c("bone")
			if row == 0 and col == 1 and over["win"]:
				val_color = _c("ember_hi")
			text(rows[row][col * 2 + 1], cx, cy + 30, 26, val_color, HORIZONTAL_ALIGNMENT_LEFT, true)
	var ai_line := "AI 全程托管 · 未使用额外金币或冷却" if over["ai"] else (
		"玩家接管 · AI 曾参与指挥" if over["ai_actions"] > 0 else "手动指挥完成")
	text(ai_line, 640, r.position.y + 330, 13, _c("green") if over["ai"] else _c("muted"), HORIZONTAL_ALIGNMENT_CENTER)
	button("over_restart", Rect2(r.position.x + 80, r.position.y + 372, 208, 54), "再来一局", true, true, false, 17)
	button("over_switch", Rect2(r.position.x + 308, r.position.y + 372, 208, 54), "换张地图", true, false, false, 17)
	button("over_menu", Rect2(r.position.x + 536, r.position.y + 372, 208, 54), "返回菜单", true, false, false, 17)
	text("R 重开 · M 换图 · 全部规则对 AI 与玩家一致", 640, r.position.y + 460, 12, _c("dim"),
		HORIZONTAL_ALIGNMENT_CENTER)


# ---------- menu ----------

func _draw_menu() -> void:
	draw_texture_rect(_shade, Rect2(0, 0, W, H), false)
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.015, 0.03, 0.18))
	draw_texture_rect(_vignette, FIELD, false)
	spaced("余烬堡", 640, 96, 10.0, 76, _c("ember_hi"))
	spaced("E M B E R H O L D  3 D", 640, 150, 4.0, 16, _c("bone_dim"))
	text("3D 低模塔防 · 一位不会疲倦的 AI 指挥官", 640, 184, 15, _c("muted"), HORIZONTAL_ALIGNMENT_CENTER)
	var cards := {"ashen": Rect2(200, 224, 380, 252), "frost": Rect2(700, 224, 380, 252)}
	for id in ["ashen", "frost"]:
		_draw_menu_card(id, cards[id])
	button("menu_manual", Rect2(200, 500, 380, 62), "开始守塔 · 手动", true, false, false, 20)
	button("menu_ai", Rect2(700, 500, 380, 62), "▶  看 AI 打一局", true, true, false, 20)
	text("AI 与玩家共用金币与冷却，不作弊 · 按 A 可随时接管", 640, 590, 12, _c("bone_dim"), HORIZONTAL_ALIGNMENT_CENTER)
	text("1–4 建塔 · U 升级 · S 出售 · Space 暂停 · F 倍速 · M 换图 · R 重开", 640, 614, 11, _c("muted"), HORIZONTAL_ALIGNMENT_CENTER)
	text("Enter 手动开局 · W 看 AI · ←/→ 选图", 640, 636, 11, _c("dim"), HORIZONTAL_ALIGNMENT_CENTER)
	text("v1.0 · EMBERHOLD 3D · 原创程序化低模", 1268, 700, 10, _c("dim"), HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_menu_card(id: String, r: Rect2) -> void:
	var mdef: Dictionary = MData.MAP_DEFS[id]
	var sel := menu_map == id
	var hov := hovered(r)
	var fill := Color(0.07, 0.06, 0.10, 0.92)
	if hov:
		fill = Color(0.10, 0.08, 0.13, 0.94)
	draw_rect(r, fill)
	draw_rect(r, _c("ember") if sel else (_c("bone_dim") if hov else _c("line")), false, 2.0 if sel else 1.0)
	var preview := Rect2(r.position.x + 10, r.position.y + 10, r.size.x - 20, r.size.y - 70)
	draw_rect(preview, Color(0.035, 0.03, 0.05))
	var info = previews[id]
	var s := minf((preview.size.x - 16) / 464.0, (preview.size.y - 16) / 336.0)
	var ox := preview.position.x + (preview.size.x - 464.0 * s) * 0.5
	var oy := preview.position.y + (preview.size.y - 336.0 * s) * 0.5
	var art: Dictionary = mdef["art"]
	var pts := PackedVector2Array()
	for p in info.points:
		pts.append(Vector2(ox + p.x * s, oy + p.y * s))
	if pts.size() > 1:
		draw_polyline(pts, Color(art["path_edge"]), maxf(5.0, 22.0 * s))
		draw_polyline(pts, Color(art["path_mid"]), maxf(2.0, 12.0 * s))
	for prop in info.props:
		var p: Vector2 = info.cell_center(prop["cx"], prop["cy"])
		var c := Color(art["grass"]).lightened(0.2)
		draw_circle(Vector2(ox + p.x * s, oy + p.y * s), 2.0, c)
	draw_circle(Vector2(ox + info.portal.x * s, oy + info.portal.y * s), 4.0, Color(art["accent"]))
	draw_circle(Vector2(ox + info.beacon.x * s, oy + info.beacon.y * s), 4.0, Color(art["accent2"]))
	draw_rect(preview, Color(0.2, 0.18, 0.24, 0.7), false, 1.0)
	text(mdef["name"], r.position.x + 14, r.position.y + r.size.y - 46, 24,
		_c("ember_hi") if sel else _c("bone"), HORIZONTAL_ALIGNMENT_LEFT, true)
	text(mdef["diff"], r.position.x + r.size.x - 14, r.position.y + r.size.y - 46, 14,
		_c("green") if id == "ashen" else _c("red"), HORIZONTAL_ALIGNMENT_RIGHT, true)
	text(mdef["desc"], r.position.x + 14, r.position.y + r.size.y - 22, 12, _c("muted"))
	if sel:
		var badge := Rect2(r.position.x + r.size.x - 78, r.position.y + 18, 58, 24)
		draw_rect(badge, Color(0.24, 0.12, 0.08, 0.95))
		draw_rect(badge, _c("ember"), false, 1.0)
		text("已选", badge.position.x + 29, badge.position.y + 12, 11, _c("ember_hi"), HORIZONTAL_ALIGNMENT_CENTER, true)
	add_hit("menu_map_" + id, r)
