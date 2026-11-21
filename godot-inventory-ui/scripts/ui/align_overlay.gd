class_name AlignOverlay
extends Control

# F1 alignment checker. Gold dashed = target measured from the 529x356
# reference, mapped to 1280x720 by normalised coordinates. Cyan = current
# implementation. Labels show the maximum position/size deviation in percent.
#
# The reference image itself is never loaded here: only the numeric spec below.
const REF := Vector2(529.0, 356.0)
const OUT := Vector2(1280.0, 720.0)

# All values: ref pixels (x0, y0, x1, y1) in the 529x356 screenshot.
const REF_RECTS := {
	"panel": [7.0, 23.0, 500.0, 349.0],
	"tabs": [269.0, 29.0, 497.0, 56.0],
	"grid": [270.0, 60.0, 497.0, 284.0],
	"nav": [495.0, 43.0, 528.0, 107.0],
	"hp": [92.0, 252.0, 242.0, 267.0],
	"mp": [92.0, 274.0, 242.0, 289.0],
	"coin_gold": [292.0, 299.0, 393.0, 315.0],
	"coin_silver": [292.0, 325.0, 393.0, 340.0],
	"sort": [411.0, 303.0, 486.0, 334.0],
	"cell": [0.0, 0.0, 42.0, 42.0],
	"slot": [0.0, 0.0, 44.0, 44.0],
	"title": [69.0, 2.0, 106.0, 20.0],
	"close": [491.0, 3.0, 528.0, 39.0],
}

# Slot centres in reference pixels (artifact, boots, armor, helmet, necklace,
# ring_left, ring_right, weapon).
const REF_SLOTS := [
	[134.0, 47.0], [65.5, 69.0], [204.5, 69.5], [45.5, 137.5],
	[224.0, 137.5], [65.5, 203.0], [204.0, 203.0], [136.5, 227.0],
]

var entries: Array = []
var _style: StyleBoxFlat


func setup() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	visible = false
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.03, 0.10, 0.16, 0.82)
	_style.border_color = Color(0.95, 0.80, 0.47, 0.75)
	_style.set_border_width_all(1)
	_style.corner_radius_top_left = 6
	_style.corner_radius_top_right = 6
	_style.corner_radius_bottom_left = 6
	_style.corner_radius_bottom_right = 6


static func ref_rect_to_target(r: Array) -> Rect2:
	var x0: float = float(r[0]) / REF.x * OUT.x
	var y0: float = float(r[1]) / REF.y * OUT.y
	var x1: float = float(r[2]) / REF.x * OUT.x
	var y1: float = float(r[3]) / REF.y * OUT.y
	return Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0))


static func ref_slot_target(index: int) -> Rect2:
	var c: Array = REF_SLOTS[clampi(index, 0, REF_SLOTS.size() - 1)]
	var center := Vector2(float(c[0]) / REF.x * OUT.x, float(c[1]) / REF.y * OUT.y)
	var size_px := ref_rect_to_target(REF_RECTS["slot"]).size
	return Rect2(center - size_px * 0.5, size_px)


func set_entries(list: Array) -> void:
	entries = list
	queue_redraw()


func report() -> Dictionary:
	var rows: Array = []
	var max_dev := 0.0
	for e in entries:
		var t: Rect2 = e["target"]
		var a: Rect2 = e["actual"]
		var dev := _deviation(t, a, bool(e.get("anchor", false)))
		if bool(e.get("counted", true)):
			max_dev = maxf(max_dev, dev)
		rows.append({
			"name": e["name"],
			"target": t,
			"actual": a,
			"dev_pct": dev,
			"counted": bool(e.get("counted", true)),
			"added": bool(e.get("added", false)),
		})
	return {"rows": rows, "max_dev_pct": max_dev, "count": rows.size()}


func _deviation(t: Rect2, a: Rect2, anchor: bool = false) -> float:
	if anchor:
		var dc := a.get_center() - t.get_center()
		return maxf(absf(dc.x) / OUT.x, absf(dc.y) / OUT.y) * 100.0
	var pos_dev := maxf(
		absf(a.position.x - t.position.x) / OUT.x,
		absf(a.position.y - t.position.y) / OUT.y)
	var size_dev := maxf(
		absf(a.size.x - t.size.x) / maxf(1.0, t.size.x),
		absf(a.size.y - t.size.y) / maxf(1.0, t.size.y))
	return maxf(pos_dev, size_dev) * 100.0


func _draw() -> void:
	draw_style_box(_style, Rect2(300, 5, 680, 24))
	var body := ThemeKit.body_font()
	draw_string_outline(body, Vector2(314, 22), "F1 对齐检查  ·  金虚线 = 参考目标  ·  青框 = 当前实现  ·  百分比 = 最大位置/尺寸偏差",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0.02, 0.05, 0.08, 0.9))
	draw_string(body, Vector2(314, 22), "F1 对齐检查  ·  金虚线 = 参考目标  ·  青框 = 当前实现  ·  百分比 = 最大位置/尺寸偏差",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.94, 0.99, 1.0))

	for e in entries:
		var t: Rect2 = e["target"]
		var a: Rect2 = e["actual"]
		var added: bool = bool(e.get("added", false))
		var counted: bool = bool(e.get("counted", true))
		var dev := _deviation(t, a, bool(e.get("anchor", false)))
		var tcol := Color(0.98, 0.82, 0.45, 0.95) if not added else Color(1.0, 0.45, 0.85, 0.9)
		var acol := Color(0.42, 0.95, 1.0, 0.95)
		_draw_dashed_rect(t, tcol, 1.4, 6.0, 4.0)
		if not bool(e.get("anchor", false)):
			draw_rect(a, acol, false, 1.2)
		else:
			var c := a.get_center()
			draw_line(c - Vector2(7, 0), c + Vector2(7, 0), acol, 1.4)
			draw_line(c - Vector2(0, 7), c + Vector2(0, 7), acol, 1.4)
			draw_circle(c, 2.2, acol)
		if e.get("label", true):
			var col := Color(0.60, 1.0, 0.68)
			if added:
				col = Color(1.0, 0.55, 0.9)
			elif not counted:
				col = Color(0.85, 0.92, 1.0, 0.8)
			elif dev > 6.0:
				col = Color(1.0, 0.55, 0.45)
			elif dev > 3.0:
				col = Color(1.0, 0.88, 0.45)
			var text := ("＋" if added else "") + str(e["name"]) + ("  Δ%.1f%%" % dev if counted else "")
			var lp := Vector2(t.position.x, maxf(32.0, t.position.y - 4.0))
			draw_string_outline(body, lp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 2,
				Color(0.01, 0.04, 0.07, 0.9))
			draw_string(body, lp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)

	# legend swatches at the bottom-left
	draw_rect(Rect2(18, 690, 10, 8), Color(0.98, 0.82, 0.45, 0.95), false, 1.4)
	draw_rect(Rect2(32, 690, 10, 8), Color(0.42, 0.95, 1.0, 0.95), false, 1.2)
	draw_string(body, Vector2(48, 699), "参考目标 / 当前元素框 · 仅测量层，不进入正式截图", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.85, 0.95, 1.0, 0.9))


func _draw_dashed_rect(r: Rect2, col: Color, width: float, dash: float, gap: float) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	var x := x0
	while x < x1:
		var x2: float = minf(x + dash, x1)
		draw_line(Vector2(x, y0), Vector2(x2, y0), col, width)
		draw_line(Vector2(x, y1), Vector2(x2, y1), col, width)
		x += dash + gap
	var y := y0
	while y < y1:
		var y2: float = minf(y + dash, y1)
		draw_line(Vector2(x0, y), Vector2(x0, y2), col, width)
		draw_line(Vector2(x1, y), Vector2(x1, y2), col, width)
		y += dash + gap
