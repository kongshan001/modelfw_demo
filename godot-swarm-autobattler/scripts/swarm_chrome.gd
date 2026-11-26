class_name SwarmChrome
extends Control

## 背景装饰：原创造型语言（切角、六角、铸造刻度）。全部线合并成 multiline 降低 draw call。

const ThemeKit = preload("res://scripts/swarm_theme.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var w := 1280.0
	var h := 720.0
	var lines := PackedVector2Array()
	# 顶/底分隔线
	lines.append(Vector2(12, 76)); lines.append(Vector2(1268, 76))
	lines.append(Vector2(12, 472)); lines.append(Vector2(1268, 472))
	# 顶部刻度
	for i in range(0, 64):
		var x := 24.0 + float(i) * 19.5
		if x > 1256.0:
			break
		var ln := 3.0 if i % 4 != 0 else 6.0
		lines.append(Vector2(x, 72)); lines.append(Vector2(x, 72 - ln))
	# 四角切角
	var corners := [Vector2(8, 8), Vector2(w - 8, 8), Vector2(8, h - 8), Vector2(w - 8, h - 8)]
	for c in corners:
		var sx := 1.0 if c.x < w * 0.5 else -1.0
		var sy := 1.0 if c.y < h * 0.5 else -1.0
		lines.append(c); lines.append(c + Vector2(26.0 * sx, 0))
		lines.append(c); lines.append(c + Vector2(0, 26.0 * sy))
	# 左侧刻度
	for i in 10:
		var y := 110.0 + float(i) * 32.0
		lines.append(Vector2(18, y)); lines.append(Vector2(18 + (8 if i % 3 == 0 else 4), y))
	draw_multiline(lines, Color(0.2, 0.38, 0.42, 0.45), 1.0, true)
	# 右下六角
	var hex_lines := PackedVector2Array()
	for i in 3:
		var pts := ThemeKit.hex_points(Vector2(1240 - i * 18, 700), 5.0)
		for k in 6:
			hex_lines.append(pts[k])
			hex_lines.append(pts[(k + 1) % 6])
	draw_multiline(hex_lines, Color(0.45, 0.28, 0.22, 0.45), 0.8, true)
