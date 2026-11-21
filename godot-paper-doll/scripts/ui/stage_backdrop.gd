class_name StageBackdrop
extends Control

# 纸面舞台（G5 · T-20261121-007）：4 层背景 + 2 个主光源。
#   ① 环境渐变：纸色 #f7ecd7 → 暖灰 #e6c9a8 + 左上 5600K 光池 + 太阳（主光）
#   ② 中景剪影：左侧纸丘 / 右侧纸架 + 吊旗（2–3 个，低对比、1px 纸切边）
#   ③ 地面材质：纸/木板地面 + 接缝 + 纸纤维（1× 可见）
#   ④ 前景：10% 暗角 + 18 粒纸尘（12–24 粒子）
# 光源只有 2 个：主光（45° 左上 5600K）+ 轮廓光（2px α0.5 6500K，画在角色上）。
# 环境反弹 8–12% 暖色画在角色下缘与地面光池。纯绘制、无贴图；只在 resize 时重绘。


var draw_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_count += 1
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	var s := minf(w / 1280.0, h / 720.0)
	var horizon := h * 0.80

	# ── ① 环境渐变 ───────────────────────────────────────────────────
	var top := Color("#f7ecd7")
	var bottom := Color("#e6c9a8")
	for i in 26:
		var t := float(i) / 25.0
		draw_rect(Rect2(0, horizon * t / 26.0, w, horizon / 26.0 + 1.0), top.lerp(bottom, t))

	# 左上 5600K 主光池（共 ≈12% 叠加，再补 8% 中心）。
	var key := Vector2(w * 0.30, h * 0.24)
	for i in 14:
		var radius := (300.0 - float(i) * 18.0) * s
		var alpha := 0.008 + 0.006 * float(i) / 13.0
		draw_circle(key, radius, Color(1.0, 0.941, 0.839, alpha))
	draw_circle(key, 38.0 * s, Color(1.0, 0.965, 0.87, 0.08))
	# 太阳：45° 左上，避开头部。
	var sun := Vector2(w * 0.14, h * 0.15)
	draw_circle(sun, 42.0 * s, Color(1.0, 0.84, 0.55, 0.14))
	draw_circle(sun, 29.0 * s, Color(1.0, 0.90, 0.66, 0.12))

	# ── ② 中景剪影（2–3 个）────────────────────────────────────────
	# 左纸丘。
	var hill_l := PackedVector2Array([
		Vector2(0, horizon + 2.0 * s),
		Vector2(w * 0.06, h * 0.72),
		Vector2(w * 0.15, h * 0.665),
		Vector2(w * 0.26, h * 0.725),
		Vector2(w * 0.34, horizon + 2.0 * s),
	])
	draw_colored_polygon(hill_l, Color("#ded0b8"))
	draw_polyline(_closed(hill_l), Color(1.0, 0.972, 0.91, 0.55), 0.9 * s, true)
	draw_line(Vector2(w * 0.02, h * 0.76), Vector2(w * 0.31, h * 0.77),
			Color(0.71, 0.64, 0.52, 0.30), 1.0 * s, true)

	# 右纸架 + 吊旗。
	var shelf := Rect2(w * 0.80, h * 0.50, w * 0.16, horizon - h * 0.50 + 2.0)
	draw_rect(shelf, Color("#dcc7a7"))
	draw_line(Vector2(shelf.position.x, shelf.position.y), Vector2(shelf.end.x, shelf.position.y),
			Color(1.0, 0.97, 0.90, 0.55), 0.9 * s, true)
	for i in 3:
		var y := shelf.position.y + shelf.size.y * (0.24 + float(i) * 0.24)
		draw_line(Vector2(shelf.position.x + 2.0 * s, y), Vector2(shelf.end.x - 2.0 * s, y),
				Color(0.60, 0.52, 0.42, 0.18), 1.0 * s, true)
	# 架上小物：2 本书 + 1 盆纸植物（中景第 3 个剪影，低对比）。
	var book_x := shelf.position.x + shelf.size.x * 0.16
	var book_y := shelf.end.y - 3.0 * s
	for i in 2:
		draw_rect(Rect2(book_x + float(i) * 5.0 * s, book_y - (13.0 + float(i) * 3.0) * s,
				9.0 * s, (13.0 + float(i) * 3.0) * s), Color("#c8ab84"))
		draw_line(Vector2(book_x + float(i) * 5.0 * s, book_y - (13.0 + float(i) * 3.0) * s),
				Vector2(book_x + (9.0 + float(i) * 5.0) * s, book_y - (13.0 + float(i) * 3.0) * s),
				Color(1.0, 0.97, 0.90, 0.45), 0.8 * s, true)
	var pot := Vector2(shelf.position.x + shelf.size.x * 0.66, shelf.end.y - 4.0 * s)
	draw_rect(Rect2(pot.x - 5.0 * s, pot.y - 7.0 * s, 10.0 * s, 7.0 * s), Color("#b99374"))
	for i in 3:
		var ang := -PI * 0.5 + (float(i) - 1.0) * 0.55
		var tip := pot + Vector2(cos(ang), sin(ang)) * 15.0 * s
		draw_line(pot + Vector2(0, -6.0 * s), tip, Color(0.42, 0.52, 0.40, 0.55), 0.9 * s, true)
	# 三条低饱和吊旗，剪影破形但不与角色抢色。
	var flags := [Color("#cfa79b"), Color("#a9c2b3"), Color("#d9c394")]
	var string_y := h * 0.105
	draw_line(Vector2(w * 0.58, string_y), Vector2(w * 0.97, string_y + 6.0 * s),
			Color(0.36, 0.28, 0.25, 0.28), 0.9 * s, true)
	for i in 3:
		var fx := w * (0.64 + 0.10 * float(i))
		var fy := string_y + 4.0 * s + 6.0 * float(i) / 2.0 * s
		draw_colored_polygon(PackedVector2Array([
			Vector2(fx - 9.0 * s, fy), Vector2(fx + 9.0 * s, fy), Vector2(fx, fy + 16.0 * s),
		]), flags[i])
		draw_line(Vector2(fx - 9.0 * s, fy), Vector2(fx + 9.0 * s, fy),
				Color(1.0, 0.97, 0.90, 0.45), 0.7 * s, true)

	# ── ③ 地面材质 ──────────────────────────────────────────────────
	draw_rect(Rect2(0, horizon, w, h - horizon), Color("#e8cead"))
	for i in 9:
		var t := float(i) / 8.0
		draw_rect(Rect2(0, horizon + (h - horizon) * t / 9.0, w, (h - horizon) / 9.0 + 1.0),
				Color("#e8cead").lerp(Color("#dcbd96"), t))
	draw_line(Vector2(0, horizon), Vector2(w, horizon), Color(0.83, 0.74, 0.60, 0.40), 1.2 * s, true)
	# 木板接缝：每 26px（720 口径）一条，2 条断缝。
	var plank := 26.0 * s
	var seam_y := horizon + plank
	while seam_y < h:
		draw_line(Vector2(0, seam_y), Vector2(w, seam_y), Color(0.62, 0.49, 0.36, 0.13), 0.8 * s, true)
		seam_y += plank
	for i in 2:
		var bx := w * (0.34 + 0.33 * float(i))
		draw_line(Vector2(bx, horizon + 2.0 * s), Vector2(bx, h), Color(0.62, 0.49, 0.36, 0.10), 0.8 * s, true)
	# 地面暖反弹（8–10%）：角色脚下的一圈纸面反光。
	draw_set_transform(Vector2(w * 0.5, horizon + (h - horizon) * 0.32), 0.0,
			Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 92.0 * s, Color(1.0, 0.85, 0.69, 0.10))
	draw_circle(Vector2.ZERO, 54.0 * s, Color(1.0, 0.88, 0.73, 0.08))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── 纸纹理（1× 可见）─────────────────────────────────────────────
	var fiber_n := clampi(int(w * h / 9000.0), 28, 140)
	for i in fiber_n:
		var fx := fposmod(float(i) * 71.3 + 13.0, w)
		var fy := fposmod(float(i) * 43.7 + 29.0, h)
		var length := (1.6 + float(i % 4) * 1.1) * maxf(s, 0.7)
		draw_line(Vector2(fx, fy), Vector2(fx + length, fy - length * 0.4),
				Color(0.31, 0.24, 0.20, 0.055), 0.7, true)
	var speck_n := clampi(int(w * h / 6000.0), 40, 220)
	for i in speck_n:
		var px := fposmod(float(i) * 37.9 + 7.0, w)
		var py := fposmod(float(i) * 91.1 + 41.0, h)
		draw_circle(Vector2(px, py), 0.7 * maxf(s, 0.8), Color(0.31, 0.24, 0.20, 0.06))

	# ── ④ 前景：暗角 10% + 纸尘 18 粒 ──────────────────────────────
	for i in 10:
		var inset := float(i) * 6.0 * maxf(s, 0.6)
		var rect := Rect2(inset, inset, w - inset * 2.0, h - inset * 2.0)
		draw_rect(rect, Color(0.22, 0.16, 0.18, 0.010), false, 6.0)
	for i in 18:
		var dx := fposmod(float(i) * 97.7 + 23.0, w)
		var dy := fposmod(float(i) * 61.3 + 17.0, horizon)
		var r := (0.8 + float(i % 4) * 0.45) * maxf(s, 0.75)
		var a := 0.10 + float(i % 3) * 0.045
		draw_circle(Vector2(dx, dy), r, Color(1.0, 0.97, 0.90, a))

	# ── 纸胶带 + 虚线缝边（纸艺身份，保留但压到 12% 墨）─────────────
	draw_set_transform(Vector2(w - 34.0 * s, 16.0 * s), -0.30, Vector2.ONE)
	draw_rect(Rect2(-24 * s, -8 * s, 48 * s, 16 * s), Color(0.95, 0.82, 0.56, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var dashed := Color(0.23, 0.18, 0.26, 0.13)
	var m := 10.0 * maxf(s, 0.5)
	draw_dashed_line(Vector2(m, m), Vector2(w - m, m), dashed, 1.2 * maxf(s, 0.7), 5.0 * maxf(s, 0.6))
	draw_dashed_line(Vector2(w - m, m), Vector2(w - m, h - m), dashed, 1.2 * maxf(s, 0.7), 5.0 * maxf(s, 0.6))
	draw_dashed_line(Vector2(w - m, h - m), Vector2(m, h - m), dashed, 1.2 * maxf(s, 0.7), 5.0 * maxf(s, 0.6))
	draw_dashed_line(Vector2(m, h - m), Vector2(m, m), dashed, 1.2 * maxf(s, 0.7), 5.0 * maxf(s, 0.6))


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out
