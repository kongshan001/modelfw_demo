extends CanvasLayer

# Field-simulator HUD. Everything is drawn in code with a warm paper palette;
# every number comes from app.solver, the same values that move the model.

const INK := Color("#1B1B18")
const MUTED := Color("#7C776A")
const FAINT := Color("#A9A394")
const LINE := Color("#CFC8B6")
const PAPER := Color("#F7F3E8")
const RED := Color("#C33A24")
const GREEN := Color("#2F8F5B")
const AMBER := Color("#C08A34")

var app: Node
var root: Control
var font_mono: Font
var font_sans: Font

var wing_value: Label
var wing_amp: Label
var wave: Control
var power_value: Label
var battery_cells: Array = []
var draw_value: Label
var cell_value: Label
var motor_value: Label
var servo_bars: Array = []
var servo_values: Array = []
var att: Control
var alt_value: Label
var vs_value: Label
var pitch_value: Label
var roll_value: Label
var lift_bar: Control
var lift_value: Label
var status_value: Label
var runtime_value: Label
var mode_value: Label
var mode_hint: Label
var tour_value: Label
var part_value: Label
var log_box: VBoxContainer
var log_lines: Array = []
var assembly_buttons: Array = []
var display_buttons: Dictionary = {}
var sub_rows: Array = []


class Waveform extends Control:
	var phase := 0.0
	var hz := 4.2

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var mid := h * 0.5
		for i in range(1, 4):
			var y := h * float(i) / 4.0
			draw_line(Vector2(0, y), Vector2(w, y), Color(0.45, 0.42, 0.36, 0.10), 1.0)
		draw_line(Vector2(0, mid), Vector2(w, mid), Color(0.45, 0.42, 0.36, 0.28), 1.0)
		var pts := PackedVector2Array()
		var n := 84
		for i in n:
			var u := float(i) / float(n - 1)
			var y := mid - sin(u * TAU * 2.0 + phase) * h * 0.27
			pts.append(Vector2(u * w, y))
		draw_polyline(pts, Color("#C33A24"), 1.4, true)
		var px := w * 0.64
		draw_dashed_line(Vector2(px, 2), Vector2(px, h - 2), Color(0.76, 0.22, 0.14, 0.55), 1.0, 3.0)


class Meter extends Control:
	var value := 0.0
	var color := Color("#C33A24")

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.83, 0.80, 0.72, 0.6))
		draw_rect(Rect2(0, 0, size.x * clampf(value, 0.0, 1.0), size.y), color)


class Attitude extends Control:
	var pitch := 0.0
	var roll := 0.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		draw_arc(c, r, 0, TAU, 48, Color(0.35, 0.33, 0.28, 0.48), 1.0, true)
		draw_arc(c, r * 0.55, 0, TAU, 40, Color(0.35, 0.33, 0.28, 0.22), 1.0, true)
		var a := deg_to_rad(roll)
		var dir := Vector2(cos(a), sin(a))
		draw_line(c - dir * r * 0.85, c + dir * r * 0.85, Color(0.82, 0.20, 0.12, 0.8), 1.2, true)
		var dot := c + Vector2(sin(deg_to_rad(roll)), -sin(deg_to_rad(pitch))) * r * 0.5
		draw_circle(dot, 2.4, Color("#C33A24"))
		draw_line(Vector2(c.x, c.y - 3), Vector2(c.x, c.y + 3), Color(0.2, 0.2, 0.18, 0.6), 1.0)
		draw_line(Vector2(c.x - 3, c.y), Vector2(c.x + 3, c.y), Color(0.2, 0.2, 0.18, 0.6), 1.0)


func _ready() -> void:
	layer = 10
	font_mono = SystemFont.new()
	font_mono.font_names = PackedStringArray(["Menlo", "Monaco", "SF Mono", "Consolas"])
	font_sans = SystemFont.new()
	font_sans.font_names = PackedStringArray(["Helvetica Neue", "Arial", "PingFang SC"])
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top()
	_build_left()
	_build_right()
	_build_center()
	_build_footer()
	push_log("AUTO TOUR ENGAGED")
	push_log("SIM HB7-0412 · FIELD 3")


func _panel_style(bg := Color(0.985, 0.975, 0.945, 0.94),
		border := Color(0.80, 0.77, 0.68, 0.9)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	return sb


func _label(text: String, size: int, color: Color, mono := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_mono if mono else font_sans)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _panel(rect: Rect2, bg := Color(0.985, 0.975, 0.945, 0.94)) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.position = rect.position
	pc.size = rect.size
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.add_theme_stylebox_override("panel", _panel_style(bg))
	root.add_child(pc)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 7)
	pc.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	margin.add_child(vb)
	return vb


func _card(rect: Rect2, title: String, num: String) -> VBoxContainer:
	var vb := _panel(rect)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var t := _label(title, 9, MUTED)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label(num, 8, FAINT))
	var rule := ColorRect.new()
	rule.color = Color(0.55, 0.52, 0.44, 0.18)
	rule.custom_minimum_size = Vector2(0, 1)
	vb.add_child(rule)
	return vb


func _row(parent: Node, key: String, value: String, key_size := 8, value_size := 9) -> Label:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var k := _label(key, key_size, MUTED)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	var v := _label(value, value_size, INK)
	h.add_child(v)
	return v


func _build_top() -> void:
	var top := PanelContainer.new()
	top.position = Vector2(0, 0)
	top.size = Vector2(1280, 54)
	var sb := _panel_style(Color(0.985, 0.975, 0.945, 0.97), Color(0.78, 0.75, 0.66, 0.9))
	sb.set_corner_radius_all(0)
	sb.border_width_bottom = 1
	sb.border_width_top = 0
	sb.border_width_left = 0
	sb.border_width_right = 0
	top.add_theme_stylebox_override("panel", sb)
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(top)

	var logo := PanelContainer.new()
	logo.position = Vector2(16, 9)
	logo.size = Vector2(40, 36)
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = RED
	lsb.set_corner_radius_all(2)
	logo.add_theme_stylebox_override("panel", lsb)
	root.add_child(logo)
	var ll := _label("HB-7", 10, Color.WHITE)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.add_child(ll)

	var title := _label("Mellis HB-7 /", 24, INK, false)
	title.position = Vector2(68, 4)
	root.add_child(title)
	var sub := _label("FLAPPING-WING DRONE / FIELD SIMULATOR", 8, MUTED)
	sub.position = Vector2(69, 34)
	root.add_child(sub)

	var lift_lab := _label("LIFT LOAD", 8, MUTED)
	lift_lab.position = Vector2(430, 9)
	root.add_child(lift_lab)
	lift_bar = Meter.new()
	lift_bar.position = Vector2(430, 21)
	lift_bar.size = Vector2(150, 5)
	lift_bar.color = RED
	root.add_child(lift_bar)
	lift_value = _label("62%", 8, INK)
	lift_value.position = Vector2(586, 17)
	root.add_child(lift_value)

	var sim := _label("SIM ID", 7, FAINT)
	sim.position = Vector2(660, 8)
	root.add_child(sim)
	var simv := _label("HB7-0412", 10, INK)
	simv.position = Vector2(660, 20)
	root.add_child(simv)

	var run := _label("RUNTIME", 7, FAINT)
	run.position = Vector2(780, 8)
	root.add_child(run)
	runtime_value = _label("00:00:00", 10, INK)
	runtime_value.position = Vector2(780, 20)
	root.add_child(runtime_value)

	var st := _label("STATUS", 7, FAINT)
	st.position = Vector2(930, 8)
	root.add_child(st)
	status_value = _label("● HOVER", 10, RED)
	status_value.position = Vector2(930, 20)
	root.add_child(status_value)

	var op := _label("OPERATOR", 7, FAINT)
	op.position = Vector2(1100, 8)
	root.add_child(op)
	var opv := _label("LAB 3 · R.K.", 10, INK)
	opv.position = Vector2(1100, 20)
	root.add_child(opv)


func _build_left() -> void:
	var wing := _card(Rect2(16, 64, 236, 150), "WING BEAT", "01")
	var top := HBoxContainer.new()
	wing.add_child(top)
	wing_value = _label("4.2", 26, INK, false)
	top.add_child(wing_value)
	var unit := _label("Hz", 10, MUTED)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(unit)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	wing_amp = _label("±32°", 12, INK)
	top.add_child(wing_amp)
	var desc := _label("STROKE FREQUENCY / AMPLITUDE", 7, FAINT)
	wing.add_child(desc)
	wave = Waveform.new()
	wave.custom_minimum_size = Vector2(0, 58)
	wave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wing.add_child(wave)
	var foot := HBoxContainer.new()
	wing.add_child(foot)
	var play := _label("PLAYBACK 1.0×", 7, MUTED)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(play)
	foot.add_child(_label("SHUTTER 1/60", 7, MUTED))

	var power := _card(Rect2(16, 222, 236, 116), "POWER", "02")
	var prow := HBoxContainer.new()
	power.add_child(prow)
	power_value = _label("83%", 24, INK, false)
	prow.add_child(power_value)
	var batt := _label("BATTERY", 8, MUTED)
	batt.size_flags_vertical = Control.SIZE_SHRINK_END
	prow.add_child(batt)
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 2)
	power.add_child(cells)
	for i in 6:
		var c := ColorRect.new()
		c.custom_minimum_size = Vector2(13, 11)
		c.color = GREEN
		cells.add_child(c)
		battery_cells.append(c)
	var kv := HBoxContainer.new()
	kv.add_theme_constant_override("separation", 14)
	power.add_child(kv)
	draw_value = _metric(kv, "DRAW", "35.2 W")
	cell_value = _metric(kv, "CELL", "3.70 V")
	motor_value = _metric(kv, "MOTOR", "38 °C")

	var servos := _card(Rect2(16, 346, 236, 176), "LEG SERVOS", "03")
	var load := _label("LOAD PER LEG · KNEE TORQUE", 7, FAINT)
	servos.add_child(load)
	for i in 6:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		servos.add_child(row)
		var name := _label(["L1", "L2", "L3", "R1", "R2", "R3"][i], 8, INK)
		name.custom_minimum_size = Vector2(16, 0)
		row.add_child(name)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 5)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", _bar_bg())
		bar.add_theme_stylebox_override("fill", _bar_fill(GREEN))
		row.add_child(bar)
		var val := _label("48%", 7, MUTED)
		val.custom_minimum_size = Vector2(28, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		servo_bars.append(bar)
		servo_values.append(val)
	var badge := _label("HOLDING", 8, GREEN)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	servos.add_child(badge)

	mode_value = _label("HOVER", 30, RED, false)
	mode_value.position = Vector2(16, 536)
	root.add_child(mode_value)
	mode_hint = _label("AUTO HOLD · FIELD 3", 8, MUTED)
	mode_hint.position = Vector2(18, 572)
	root.add_child(mode_hint)

	var log := _card(Rect2(16, 600, 236, 92), "FLIGHT LOG", "08")
	log_box = VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 1)
	log.add_child(log_box)


func _metric(parent: Node, key: String, value: String) -> Label:
	var v := VBoxContainer.new()
	parent.add_child(v)
	v.add_child(_label(key, 7, FAINT))
	var l := _label(value, 9, INK)
	v.add_child(l)
	return l


func _build_right() -> void:
	var flight := _card(Rect2(1028, 64, 236, 166), "FLIGHT", "04")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	flight.add_child(h)
	att = Attitude.new()
	att.custom_minimum_size = Vector2(88, 88)
	h.add_child(att)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 2)
	h.add_child(rows)
	alt_value = _row(rows, "ALT AGL", "150.0 MM")
	vs_value = _row(rows, "V/S", "+0.0 MM/S")
	pitch_value = _row(rows, "PITCH", "-0.95°")
	roll_value = _row(rows, "ROLL", "+1.65°")
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 3)
	flight.add_child(pills)
	for t in ["HOLD", "POSITION", "AIRSPEED 0.00 M/S"]:
		var l := _label(t, 6, MUTED)
		l.add_theme_stylebox_override("normal", _panel_style(Color(0.96, 0.95, 0.90, 0.9),
			Color(0.82, 0.79, 0.70, 0.9)))
		l.custom_minimum_size = Vector2(0, 13)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pills.add_child(l)

	var assemb := _card(Rect2(1028, 238, 236, 110), "ASSEMBLIES", "05")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	assemb.add_child(grid)
	var assemblies := {
		"HERO": "head", "OPTICS": "optics", "WING": "wing_lf",
		"LEG L2": "leg_l2", "THORAX": "thorax", "ABDOMEN": "abdomen_a",
	}
	for key in assemblies:
		var b := _small_button(key)
		b.pressed.connect(_on_assembly.bind(assemblies[key]))
		grid.add_child(b)
		assembly_buttons.append({"button": b, "id": assemblies[key]})
	var hint := _label("CLICK A PART IN THE MODEL TO ISOLATE", 6, FAINT)
	assemb.add_child(hint)

	var disp := _card(Rect2(1028, 356, 236, 116), "DISPLAY", "06")
	var dgrid := GridContainer.new()
	dgrid.columns = 2
	dgrid.add_theme_constant_override("h_separation", 4)
	dgrid.add_theme_constant_override("v_separation", 4)
	disp.add_child(dgrid)
	for key in ["LABELS", "EXPLODED", "MOTION BLUR", "TURNTABLE"]:
		var b := _small_button(key)
		b.pressed.connect(_on_display.bind(key))
		dgrid.add_child(b)
		display_buttons[key] = b

	var subs := _card(Rect2(1028, 480, 236, 194), "SUBSYSTEMS", "07")
	for i in 6:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		subs.add_child(row)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		row.add_child(v)
		var name := _label("—", 8, INK)
		v.add_child(name)
		var detail := _label("—", 6, FAINT)
		v.add_child(detail)
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(52, 14)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		var chip_label := _label("—", 6, Color.WHITE)
		chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(chip_label)
		sub_rows.append({"name": name, "detail": detail, "chip": chip, "label": chip_label})


func _build_center() -> void:
	var banner := PanelContainer.new()
	banner.position = Vector2(430, 64)
	banner.size = Vector2(430, 20)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _panel_style(Color(0.98, 0.97, 0.93, 0.86), Color(0.80, 0.77, 0.68, 0.7))
	sb.set_corner_radius_all(2)
	banner.add_theme_stylebox_override("panel", sb)
	root.add_child(banner)
	tour_value = _label("AUTO TOUR · CLICK TO TAKE OVER", 7, MUTED)
	tour_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(tour_value)

	var part_panel := PanelContainer.new()
	part_panel.position = Vector2(430, 664)
	part_panel.size = Vector2(430, 22)
	part_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(part_panel)
	part_value = _label("SELECTED · —", 7, MUTED)
	part_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	part_panel.add_child(part_value)


func _build_footer() -> void:
	var rule := ColorRect.new()
	rule.color = Color(0.55, 0.52, 0.44, 0.25)
	rule.position = Vector2(16, 696)
	rule.size = Vector2(1248, 1)
	root.add_child(rule)
	var left := _label("FIELD SIMULATOR · PROCEDURAL MODEL · 6 LEGS · 4 WINGS · 2 OPTICS", 7, FAINT)
	left.position = Vector2(16, 700)
	root.add_child(left)
	var right := _label("MELLIS ROBOTICS · POLLINATION LAB ////", 7, FAINT)
	right.position = Vector2(960, 700)
	root.add_child(right)


func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(62, 20)
	b.add_theme_font_override("font", font_mono)
	b.add_theme_font_size_override("font_size", 7)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", RED)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	_style_button(b, false)
	return b


func _style_button(b: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = RED if active else Color(0.97, 0.96, 0.91, 0.95)
	sb.border_color = RED if active else Color(0.80, 0.77, 0.68, 0.95)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate()
	hov.border_color = RED
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color.WHITE if active else INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE if active else RED)


func _bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.78, 0.75, 0.66, 0.55)
	sb.set_corner_radius_all(0)
	return sb


func _bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(0)
	return sb


func _on_assembly(id: String) -> void:
	app.focus_assembly(id)


func _on_display(kind: String) -> void:
	match kind:
		"LABELS":
			app.labels_on = not app.labels_on
		"EXPLODED":
			if app.explode_target > 0.5:
				app.set_state("REASSEMBLY")
			else:
				app.set_state("TEARDOWN")
		"MOTION BLUR":
			app.motion_blur = not app.motion_blur
		"TURNTABLE":
			app.turntable = not app.turntable
	app._take_over()


func push_log(text: String) -> void:
	if log_box == null:
		return
	var line := "T+%s  %s" % [app.solver.runtime_text() if app and app.solver else "00:00:00", text]
	log_lines.append(line)
	while log_lines.size() > 5:
		log_lines.pop_front()
	for c in log_box.get_children():
		c.queue_free()
	for l in log_lines:
		log_box.add_child(_label(l, 6, MUTED))


func update_view() -> void:
	if app == null or app.solver == null:
		return
	var s = app.solver
	wing_value.text = "%.1f" % s.beat_hz()
	wing_amp.text = "±%d°" % int(s.wing_amplitude_deg())
	wave.phase = fmod(s.t * TAU * s.beat_hz(), TAU * 2.0)
	wave.hz = s.beat_hz()
	wave.queue_redraw()

	var pct := int(round(s.battery() * 100.0))
	power_value.text = "%d%%" % pct
	for i in 6:
		var on := pct >= (i + 1) * 16
		battery_cells[i].color = GREEN if on else Color(0.80, 0.77, 0.68, 0.5)
	draw_value.text = "%.1f W" % s.power_draw()
	cell_value.text = "%.2f V" % s.cell_v()
	motor_value.text = "%d °C" % int(round(s.motor_temp()))

	for i in 6:
		var v: float = s.servo_load(i)
		servo_bars[i].value = v * 100.0
		servo_values[i].text = "%d%%" % int(round(v * 100.0))

	att.pitch = s.pitch_deg()
	att.roll = s.roll_deg()
	att.queue_redraw()
	alt_value.text = "%.1f MM" % s.alt_agl()
	vs_value.text = "%+.1f MM/S" % s.vertical_speed()
	pitch_value.text = "%+.2f°" % s.pitch_deg()
	roll_value.text = "%+.2f°" % s.roll_deg()

	lift_bar.value = s.lift_load()
	lift_bar.queue_redraw()
	lift_value.text = "%d%%" % int(round(s.lift_load() * 100.0))
	runtime_value.text = s.runtime_text()
	status_value.text = "● " + s.status_text()
	status_value.add_theme_color_override("font_color", RED)
	mode_value.text = s.flight_mode_text()
	mode_hint.text = s.mode_hint()

	var subs: Array = s.subsystem_rows()
	for i in sub_rows.size():
		if i >= subs.size():
			continue
		var row: Dictionary = sub_rows[i]
		var data: Dictionary = subs[i]
		row["name"].text = "%02d  %s" % [i + 1, data["name"]]
		row["detail"].text = data["detail"]
		row["label"].text = data["status"]
		var col := GREEN
		if data["color"] == "amber":
			col = AMBER
		elif data["color"] == "red":
			col = RED
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(1)
		row["chip"].add_theme_stylebox_override("panel", sb)
		row["label"].add_theme_color_override("font_color", Color.WHITE)

	for entry in assembly_buttons:
		_style_button(entry["button"], app.selected_id == entry["id"])
	_style_button(display_buttons["LABELS"], app.labels_on)
	_style_button(display_buttons["EXPLODED"], app.explode_t > 0.5)
	_style_button(display_buttons["MOTION BLUR"], app.motion_blur)
	_style_button(display_buttons["TURNTABLE"], app.turntable)

	tour_value.text = "AUTO TOUR · CLICK TO TAKE OVER" if app.auto_tour else \
		"MANUAL CONTROL · IDLE 15S RESUMES TOUR"
	part_value.text = "SELECTED · —" if app.selected_id.is_empty() else \
		"SELECTED · %s%s" % [app.model.part_label(app.selected_id),
			" · ISOLATED" if app.isolated else ""]
