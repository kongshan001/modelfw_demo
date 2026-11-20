class_name StageBackdrop
extends Control

# 试衣镜里的纸舞台（评审 P0-5）：
#   - 底色 #f4ddc0 → #e4c7a5 纵向渐变（比纸面暗 6–8 L*）
#   - 左上 35% 暖光池 #fff3d6；四周 10% 暗角；纸纤维 σ2.2
#   - 太阳移到左上偏侧、15% 不透明度，不再压在头后
#   - 接触影/环境影由 PaperDollRenderer 统一绘制，这里不再叠第二层
# 纯绘制、无贴图；只在 resize 时重绘。


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	var top := Color("#f4ddc0")
	var bottom := Color("#e4c7a5")
	for i in 24:
		var t := float(i) / 23.0
		draw_rect(Rect2(0, h * t / 24.0, w, h / 24.0 + 1.0), top.lerp(bottom, t))

	# 左上暖光池：同心圆近似径向渐变（总 α ≈ 0.12，再加 0.08 中心）。
	var pool := Vector2(w * 0.30, h * 0.26)
	for i in 12:
		var radius := 240.0 - float(i) * 17.0
		var alpha := 0.010 + 0.006 * float(i) / 11.0
		draw_circle(pool, radius, Color(1.0, 0.953, 0.839, alpha))
	draw_circle(pool, 34.0, Color(1.0, 0.965, 0.86, 0.10))

	# 太阳：偏左上、15% 不透明，避开头部；两层柔边。
	var sun := Vector2(w * 0.16, h * 0.17)
	draw_circle(sun, 41.0, Color(1.0, 0.84, 0.55, 0.15))
	draw_circle(sun, 29.0, Color(1.0, 0.90, 0.66, 0.12))

	# 纸纤维：确定性短线 + 微点（σ≈2.2，低对比，不干扰 95px 缩略图）。
	for i in 64:
		var fx := fposmod(float(i) * 71.3 + 13.0, w)
		var fy := fposmod(float(i) * 43.7 + 29.0, h)
		var length := 1.4 + float(i % 4) * 0.9
		draw_line(Vector2(fx, fy), Vector2(fx + length, fy - length * 0.4),
				Color(0.31, 0.24, 0.20, 0.045), 0.7, true)
	for i in 96:
		var px := fposmod(float(i) * 37.9 + 7.0, w)
		var py := fposmod(float(i) * 91.1 + 41.0, h)
		draw_circle(Vector2(px, py), 0.7, Color(0.31, 0.24, 0.20, 0.05))

	# 四周 10% 暗角：6px 一圈、叠加 9 层。
	for i in 9:
		var inset := float(i) * 6.0
		var alpha := 0.012
		var rect := Rect2(inset, inset, w - inset * 2.0, h - inset * 2.0)
		draw_rect(rect, Color(0.22, 0.16, 0.18, alpha), false, 6.0)

	# 纸胶带 + 虚线缝边（12% 墨）。
	draw_set_transform(Vector2(w - 34.0, 16.0), -0.30, Vector2.ONE)
	draw_rect(Rect2(-24, -8, 48, 16), Color(0.95, 0.82, 0.56, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var dashed := Color(0.23, 0.18, 0.26, 0.14)
	draw_dashed_line(Vector2(10, 10), Vector2(w - 10, 10), dashed, 1.2, 5.0)
	draw_dashed_line(Vector2(w - 10, 10), Vector2(w - 10, h - 10), dashed, 1.2, 5.0)
	draw_dashed_line(Vector2(w - 10, h - 10), Vector2(10, h - 10), dashed, 1.2, 5.0)
	draw_dashed_line(Vector2(10, h - 10), Vector2(10, 10), dashed, 1.2, 5.0)
