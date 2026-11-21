extends SceneTree

# 读取 docs/perf/ablation_*.csv，画一张 1000 智能体的消融对比图（中位 FPS + P95，含 min–max 须）。
# 运行：godot --path . --resolution 640x360 -s tools/plot_ablation.gd
# 输出：docs/perf/ablation_chart.png

const CSV_720 := "res://docs/perf/ablation_1280x720.csv"
const CSV_1080 := "res://docs/perf/ablation_1920x1080.csv"
const OUT_PNG := "res://docs/perf/ablation_chart.png"


class Chart extends Node2D:
	const CONFIG_ORDER := ["baseline", "aa_off", "hz10", "half", "aa_off_hz10", "aa_off_half", "hz10_half", "all"]
	const SHORT_LABELS := {
		"baseline": "B",
		"aa_off": "-AA",
		"hz10": "10Hz",
		"half": "1/2",
		"aa_off_hz10": "-AA+10",
		"aa_off_half": "-AA+1/2",
		"hz10_half": "10Hz+1/2",
		"all": "ALL",
	}
	const C_BG := Color(0.102, 0.09, 0.145)
	const C_PANEL := Color(0.145, 0.133, 0.208)
	const C_PANEL2 := Color(0.176, 0.161, 0.259)
	const C_TEXT := Color(0.937, 0.914, 0.969)
	const C_DIM := Color(0.604, 0.569, 0.722)
	const C_GRID := Color(0.663, 0.314, 0.525)
	const C_TEAL := Color(0.329, 1.0, 0.776)
	const C_PINK := Color(0.973, 0.259, 0.553)
	const C_CYAN := Color(0.078, 0.945, 0.976)
	const W := 1500.0
	const H := 1000.0

	var font: SystemFont
	var title_font: SystemFont
	var stats_720: Dictionary = {}
	var stats_1080: Dictionary = {}
	var load_text := ""

	func _draw() -> void:
		draw_rect(Rect2(0, 0, W, H), C_BG)
		draw_string(title_font, Vector2(70, 54), "Flow Field 消融复测 · 1000 智能体 · 5 轮独立运行", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, C_TEXT)
		draw_string(font, Vector2(70, 82), "同地图 medium / 同种子 421 / 关闭垂直同步；柱高 = 5 轮中位数，须 = 最小–最大", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_DIM)
		# 图例
		draw_rect(Rect2(1110, 38, 16, 16), C_TEAL)
		draw_string(font, Vector2(1134, 52), "1280×720 真实窗口", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_TEXT)
		draw_rect(Rect2(1110, 64, 16, 16), C_PINK)
		draw_string(font, Vector2(1134, 78), "1920×1080 离屏 SubViewport", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_TEXT)
		if load_text != "":
			draw_string(font, Vector2(1090, 102), load_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_DIM)
		_draw_fps_panel()
		_draw_p95_panel()
		_draw_footnotes()

	func _axis_max(values: Array[float], step: float, minimum: float) -> float:
		var peak := minimum
		for v in values:
			peak = maxf(peak, v)
		return ceil(peak * 1.12 / step) * step

	func _collect(which: String, field: String) -> Array[float]:
		var out: Array[float] = []
		for cid in CONFIG_ORDER:
			var src: Dictionary = stats_720 if which == "720" else stats_1080
			if src.has(cid) and src[cid].has(field):
				out.append_array(src[cid][field])
		return out

	func _draw_fps_panel() -> void:
		var x0 := 90.0
		var x1 := 1460.0
		var y0 := 130.0
		var y1 := 500.0
		var values := _collect("720", "fps")
		values.append_array(_collect("1080", "fps"))
		var axis := _axis_max(values, 10.0, 60.0)
		draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), C_PANEL)
		draw_string(font, Vector2(x0, y0 - 12), "平均 FPS（中位；越高越好）", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, C_TEXT)
		var tick := 0.0
		while tick <= axis + 0.01:
			var y := y1 - (y1 - y0) * (tick / axis)
			draw_line(Vector2(x0, y), Vector2(x1, y), Color(C_GRID.r, C_GRID.g, C_GRID.b, 0.22), 1.0)
			draw_string(font, Vector2(x0 - 42, y + 5), "%.0f" % tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_DIM)
			tick += 10.0
		_draw_bars(x0, x1, y0, y1, axis, "fps", "%.0f", false)
		# 30 FPS 参考线
		var y30 := y1 - (y1 - y0) * (30.0 / axis)
		draw_dashed_line(Vector2(x0, y30), Vector2(x1, y30), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.55), 1.5, 8.0)
		draw_string(font, Vector2(x0 + 10, y30 - 8), "虚线 = 30 FPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_CYAN)

	func _draw_p95_panel() -> void:
		var x0 := 90.0
		var x1 := 1460.0
		var y0 := 580.0
		var y1 := 900.0
		var values := _collect("720", "p95")
		values.append_array(_collect("1080", "p95"))
		var axis := _axis_max(values, 20.0, 60.0)
		draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), C_PANEL)
		draw_string(font, Vector2(x0, y0 - 12), "P95 帧时间（毫秒；越低越好）", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, C_TEXT)
		var label_step := 50.0 if axis > 200.0 else 20.0
		var tick := 0.0
		while tick <= axis + 0.01:
			var y := y1 - (y1 - y0) * (tick / axis)
			draw_line(Vector2(x0, y), Vector2(x1, y), Color(C_GRID.r, C_GRID.g, C_GRID.b, 0.22), 1.0)
			draw_string(font, Vector2(x0 - 42, y + 5), "%.0f" % tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_DIM)
			tick += label_step
		_draw_bars(x0, x1, y0, y1, axis, "p95", "%.0f", true)
		var y33 := y1 - (y1 - y0) * (33.3 / axis)
		draw_dashed_line(Vector2(x0, y33), Vector2(x1, y33), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.65), 1.6, 8.0)
		draw_string(font, Vector2(x0 + 10, y0 + 20), "虚线 = 33.3 ms（30 FPS 预算）", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_CYAN)

	func _draw_bars(x0: float, x1: float, y0: float, y1: float, axis: float,
			field: String, fmt: String, draw_labels: bool) -> void:
		var group_w := (x1 - x0) / float(CONFIG_ORDER.size())
		var bar_w := group_w * 0.30
		for i in CONFIG_ORDER.size():
			var cid: String = CONFIG_ORDER[i]
			var cx := x0 + group_w * (i + 0.5)
			for which in ["720", "1080"]:
				var src: Dictionary = stats_720 if which == "720" else stats_1080
				if not src.has(cid) or not src[cid].has(field):
					continue
				var vals: Array = src[cid][field]
				var med := _median(vals)
				var lo := _min(vals)
				var hi := _max(vals)
				var offset := -bar_w * 0.55 if which == "720" else bar_w * 0.55
				var color := C_TEAL if which == "720" else C_PINK
				var bar_h := (y1 - y0) * (med / axis)
				var bx := cx + offset - bar_w * 0.5
				draw_rect(Rect2(bx, y1 - bar_h, bar_w, bar_h), Color(color.r, color.g, color.b, 0.88))
				# min–max 须
				var wy_lo := y1 - (y1 - y0) * (lo / axis)
				var wy_hi := y1 - (y1 - y0) * (hi / axis)
				var wx := cx + offset
				draw_line(Vector2(wx, wy_hi), Vector2(wx, wy_lo), Color(0.96, 0.94, 1.0, 0.82), 1.4)
				draw_line(Vector2(wx - 5, wy_hi), Vector2(wx + 5, wy_hi), Color(0.96, 0.94, 1.0, 0.82), 1.4)
				draw_line(Vector2(wx - 5, wy_lo), Vector2(wx + 5, wy_lo), Color(0.96, 0.94, 1.0, 0.82), 1.4)
				draw_string(font, Vector2(wx - 18, y1 - bar_h - 5), fmt % med,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
			if draw_labels:
				draw_string(font, Vector2(cx - group_w * 0.5, y1 + 24), SHORT_LABELS.get(cid, cid),
					HORIZONTAL_ALIGNMENT_CENTER, group_w, 15, C_TEXT)

	func _median(values: Array) -> float:
		var sorted_values := values.duplicate()
		sorted_values.sort()
		var n := sorted_values.size()
		if n == 0:
			return 0.0
		if n % 2 == 1:
			return float(sorted_values[n / 2])
		return (float(sorted_values[n / 2 - 1]) + float(sorted_values[n / 2])) * 0.5

	func _min(values: Array) -> float:
		var best := INF
		for v in values:
			best = minf(best, float(v))
		return best if best != INF else 0.0

	func _max(values: Array) -> float:
		var best := -INF
		for v in values:
			best = maxf(best, float(v))
		return best if best != -INF else 0.0

	func _draw_footnotes() -> void:
		draw_string(font, Vector2(70, 962),
			"B = 初版行为：拖尾 AA 开 / 每 2 拍刷新（15Hz）/ 全部拖尾；-AA = 关拖尾 AA；1/2 = 拖尾半采样；ALL = 当前主场景默认",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_DIM)
		draw_string(font, Vector2(70, 986),
			"1080p 说明：本机屏幕 1440×900，macOS 会夹住更大窗口，故用 1920×1080 离屏 SubViewport；present/blit 成本不计入。数据源：docs/perf/ablation_*.csv",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_DIM)


var _chart: Chart


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stats_720 := _collect(CSV_720)
	var stats_1080 := _collect(CSV_1080)
	if stats_720.is_empty() and stats_1080.is_empty():
		push_error("没有可绘制的 CSV 数据")
		quit(1)
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(1500, 1000)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(vp)
	_chart = Chart.new()
	_chart.font = _make_font(15)
	_chart.title_font = _make_font(28, 600)
	_chart.stats_720 = stats_720
	_chart.stats_1080 = stats_1080
	_chart.load_text = "轮次：%d / %d" % [_run_count(stats_720), _run_count(stats_1080)]
	vp.add_child(_chart)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	if image.is_empty():
		push_error("对比图为空")
		quit(1)
		return
	image.save_png(OUT_PNG)
	print("PLOT_OK %s %s configs_720=%d configs_1080=%d" % [OUT_PNG, image.get_size(), stats_720.size(), stats_1080.size()])
	quit(0)


func _make_font(size: int, weight := 400) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
		"Noto Sans CJK SC", "Arial Unicode MS", "Helvetica Neue",
	])
	font.font_weight = weight
	font.allow_system_fallback = true
	return font


func _read_csv(path: String) -> Array:
	var rows: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("缺少 CSV：" + path)
		return rows
	var header := file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < header.size():
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i]
		rows.append(row)
	return rows


func _collect(path: String) -> Dictionary:
	var out := {}
	for row in _read_csv(path):
		if str(row.get("kind", "")) != "ablation":
			continue
		if int(row.get("agents", "0")) != 1000:
			continue
		var cid := str(row.get("config_id", ""))
		if cid == "":
			continue
		if not out.has(cid):
			out[cid] = {"fps": [], "p95": [], "hitch33": [], "hitch50": []}
		out[cid]["fps"].append(float(row.get("avg_fps", "0")))
		out[cid]["p95"].append(float(row.get("p95_ms", "0")))
		out[cid]["hitch33"].append(int(row.get("hitch_33ms", "0")))
		out[cid]["hitch50"].append(int(row.get("hitch_50ms", "0")))
	return out


func _run_count(stats: Dictionary) -> int:
	for cid in stats:
		return stats[cid]["fps"].size()
	return 0
