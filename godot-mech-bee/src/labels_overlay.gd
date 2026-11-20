extends Control

# Projected leader-line labels. Kept in 2D so text stays crisp and can be
# toggled without touching the 3D scene.

const RED := Color("#C33A24")
const INK := Color("#1B1B18")

var app: Node


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if app == null or app.camera == null or app.model == null:
		return
	var cam: Camera3D = app.camera
	var font: Font = app.hud.font_mono

	# schematic crosses floating in the field
	var marks := [
		Vector3(-2.5, 2.5, 0.2), Vector3(2.4, 2.7, -0.1),
		Vector3(-2.2, 0.7, 2.0), Vector3(2.2, 0.6, -2.0),
	]
	for p in marks:
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p)
		var col := Color(0.76, 0.22, 0.14, 0.45)
		draw_line(sp + Vector2(-4, 0), sp + Vector2(4, 0), col, 1.0)
		draw_line(sp + Vector2(0, -4), sp + Vector2(0, 4), col, 1.0)

	if not app.labels_on:
		return

	var entries: Array = []
	for id in app.visible_label_parts():
		var part = app.model.get_part(id)
		if part == null or not part.visible:
			continue
		var wp: Vector3 = part.label_point()
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		entries.append({"sp": sp, "text": part.label,
			"side": -1.0 if sp.x < 640.0 else 1.0})
	entries.sort_custom(func(a, b): return a["sp"].y < b["sp"].y)

	var last_y := {"l": 84.0, "r": 84.0}
	for e in entries:
		var sp: Vector2 = e["sp"]
		var side: float = e["side"]
		var key := "l" if side < 0.0 else "r"
		var ly: float = maxf(sp.y - 14.0, float(last_y[key]) + 15.0)
		last_y[key] = ly
		var label_x := 272.0 if side < 0.0 else 1008.0

		draw_circle(sp, 2.0, RED)
		var bend := Vector2(sp.x + side * 18.0, ly)
		var line_end := label_x - 5.0 if side < 0.0 else label_x + 5.0
		draw_line(sp, bend, Color(0.76, 0.22, 0.14, 0.55), 1.0)
		draw_line(bend, Vector2(line_end, ly),
			Color(0.76, 0.22, 0.14, 0.55), 1.0)

		var text: String = e["text"]
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var tx := label_x if side < 0.0 else label_x - ts.x
		draw_rect(Rect2(tx - 3, ly - 9, ts.x + 6, 13), Color(0.98, 0.97, 0.93, 0.85))
		draw_string(font, Vector2(tx, ly + 1), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)

	if not app.selected_id.is_empty():
		var part = app.model.get_part(app.selected_id)
		if part != null and part.visible:
			var wp: Vector3 = part.label_point()
			if not cam.is_position_behind(wp):
				var sp := cam.unproject_position(wp)
				var s := 9.0
				var col := Color(0.82, 0.20, 0.12, 0.9)
				draw_line(sp + Vector2(-s, -s), sp + Vector2(-s, -s * 0.4), col, 1.6)
				draw_line(sp + Vector2(-s, -s), sp + Vector2(-s * 0.4, -s), col, 1.6)
				draw_line(sp + Vector2(s, -s), sp + Vector2(s, -s * 0.4), col, 1.6)
				draw_line(sp + Vector2(s, -s), sp + Vector2(s * 0.4, -s), col, 1.6)
				draw_line(sp + Vector2(-s, s), sp + Vector2(-s, s * 0.4), col, 1.6)
				draw_line(sp + Vector2(-s, s), sp + Vector2(-s * 0.4, s), col, 1.6)
				draw_line(sp + Vector2(s, s), sp + Vector2(s, s * 0.4), col, 1.6)
				draw_line(sp + Vector2(s, s), sp + Vector2(s * 0.4, s), col, 1.6)
