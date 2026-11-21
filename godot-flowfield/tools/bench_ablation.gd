extends SceneTree

# 审计级消融基准：把 T-009 的三项优化拆成独立开关，做 2×2×2 矩阵 + 独立轮次采样。
#   (a) 拖尾关闭抗锯齿        aa_off
#   (b) >700 大群 10Hz 刷新    large_group_10hz（方向/分离/拖尾）
#   (c) 拖尾半采样            trail_half_sampling
# 默认配置 = 初版行为（AA on / 每 2 拍刷新 / 全部拖尾）；全开 = 当前主场景默认。
# 运行：
#   godot --path . --resolution 1280x720 -s tools/bench_ablation.gd -- \
#     --tag 1280x720 --viewport window --agents 1000,500 --runs 5 --layers
#   godot --path . --resolution 1280x720 -s tools/bench_ablation.gd -- \
#     --tag 1920x1080 --viewport sub --agents 1000 --runs 5
# 说明：本机屏幕 1440×900，macOS 会把 1920×1080 窗口夹到屏幕内；1920 档用 1920×1080
# 离屏 SubViewport 全分辨率渲染（size_2d_override=1280×720，等价 canvas_items 拉伸）。
# 输出：docs/perf/ablation_<tag>.csv + docs/perf/runs_raw.json（合并各分辨率）。

const OUT_DIR := "res://docs/perf"
const JSON_PATH := OUT_DIR + "/runs_raw.json"
const SAMPLE_SEED := 421
const MAP_KEY := "medium"
const VIEW_WARMUP_FRAMES := 60
const VIEW_SAMPLE_FRAMES := 300
const VIEW_SETTLE_FRAMES := 15
const HITCH_33 := 33.3
const HITCH_50 := 50.0
const FIXED_BUDGET_MS := 1000.0 / 30.0

# 1000 档：完整 2×2×2 因子矩阵。
const CONFIGS_1000 := [
	{"id": "baseline", "label": "baseline", "aa_off": false, "hz10": false, "half": false},
	{"id": "aa_off", "label": "AA off", "aa_off": true, "hz10": false, "half": false},
	{"id": "hz10", "label": "10Hz only", "aa_off": false, "hz10": true, "half": false},
	{"id": "half", "label": "half trails only", "aa_off": false, "hz10": false, "half": true},
	{"id": "aa_off_hz10", "label": "AA off + 10Hz", "aa_off": true, "hz10": true, "half": false},
	{"id": "aa_off_half", "label": "AA off + half", "aa_off": true, "hz10": false, "half": true},
	{"id": "hz10_half", "label": "10Hz + half", "aa_off": false, "hz10": true, "half": true},
	{"id": "all", "label": "all on", "aa_off": true, "hz10": true, "half": true},
]

# 500 档：10Hz 阈值 >700 不生效，只测 AA / 半采样四个组合，作为阈值对照。
const CONFIGS_500 := [
	{"id": "baseline", "label": "baseline", "aa_off": false, "hz10": false, "half": false},
	{"id": "aa_off", "label": "AA off", "aa_off": true, "hz10": false, "half": false},
	{"id": "half", "label": "half trails only", "aa_off": false, "hz10": false, "half": true},
	{"id": "aa_off_half", "label": "AA off + half", "aa_off": true, "hz10": false, "half": true},
]

# GPU timer 不可得时的归因替代：逐层开关，看每帧渲染成本差。
const LAYERS := [
	{"id": "layer_full", "label": "all layers"},
	{"id": "layer_no_trails", "label": "trails off"},
	{"id": "layer_no_agents", "label": "agents+trails off"},
	{"id": "layer_no_arrows", "label": "arrows off"},
]
const LAYER_ROUNDS := 3

var _main = null
var _viewport: SubViewport = null
var _mode := "window"
var _tag := ""
var _runs := 5
var _warmup := VIEW_WARMUP_FRAMES
var _frames := VIEW_SAMPLE_FRAMES
var _agent_ratios: Array[int] = []
var _do_layers := false
var _csv_rows: Array[String] = []
var _json_runs: Array = []
var _meta := {}
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	Engine.max_fps = 0
	_make_output_dir()
	_setup_scene()
	await process_frame
	await process_frame
	_collect_meta()
	if _failed:
		quit(1)
		return
	print("ABL meta tag=%s mode=%s window=%s screen=%s adapter=%s api=%s seed=%d map=%s" % [
		_tag, _mode, DisplayServer.window_get_size(), DisplayServer.screen_get_size(),
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version(),
		SAMPLE_SEED, MAP_KEY])
	print("ABL note=%s" % _meta["viewport_note"])

	for agents in _agent_ratios:
		var configs: Array = CONFIGS_1000 if agents > 700 else CONFIGS_500
		await _run_matrix(agents, configs)
	if _do_layers:
		await _run_layers()
	_flush_csv()
	_save_json()
	if _failed:
		print("ABLATION_FAIL")
		quit(1)
		return
	print("ABLATION_DONE tag=%s csv=%s json=%s" % [_tag, _csv_path(), JSON_PATH])
	quit(0)


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var key: String = args[i]
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match key:
			"--tag":
				_tag = value
				i += 1
			"--viewport":
				_mode = value
				i += 1
			"--agents":
				_agent_ratios.clear()
				for part in value.split(",", false):
					_agent_ratios.append(int(part))
				i += 1
			"--runs":
				_runs = maxi(1, int(value))
				i += 1
			"--warmup":
				_warmup = maxi(0, int(value))
				i += 1
			"--frames":
				_frames = maxi(30, int(value))
				i += 1
			"--layers":
				_do_layers = true
			_:
				push_warning("未知参数：" + key)
		i += 1
	if _tag == "":
		push_error("必须提供 --tag（输出文件名）")
		_failed = true
	if _agent_ratios.is_empty():
		_agent_ratios = [1000]
	if _mode != "window" and _mode != "sub":
		push_error("--viewport 只支持 window | sub")
		_failed = true


func _make_output_dir() -> void:
	var dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)


func _setup_scene() -> void:
	var holder: Node = root
	if _mode == "sub":
		_viewport = SubViewport.new()
		_viewport.size = Vector2i(1920, 1080)
		_viewport.size_2d_override = Vector2i(1280, 720)
		_viewport.size_2d_override_stretch = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		root.add_child(_viewport)
		holder = _viewport
	_main = load("res://scenes/main.tscn").instantiate()
	holder.add_child(_main)
	root.title = "Flow Field Ablation %s (%s)" % [_tag, _mode]


func _collect_meta() -> void:
	var window := DisplayServer.window_get_size()
	var screen := DisplayServer.screen_get_size()
	var note := "1280×720 real window"
	if _mode == "sub":
		note = "1920×1080 offscreen SubViewport (macOS clamps %dx%d window to %dx%d screen); present/blit cost excluded" % [
			window.x, window.y, screen.x, screen.y]
	_meta = {
		"generated": Time.get_datetime_string_from_system(false, true),
		"godot": Engine.get_version_info()["string"],
		"os": OS.get_name() + " " + OS.get_version(),
		"cpu": OS.get_processor_name(),
		"cpu_count": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gl_api": RenderingServer.get_video_adapter_api_version(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"vsync": "disabled",
		"engine_max_fps": Engine.max_fps,
		"window_size": [window.x, window.y],
		"screen_size": [screen.x, screen.y],
		"mode": _mode,
		"viewport_note": note,
		"seed": SAMPLE_SEED,
		"map": MAP_KEY,
		"warmup_frames": _warmup,
		"sample_frames": _frames,
		"runs_per_config": _runs,
		"order": "round-major, config order rotated by one each round",
	}


func _run_matrix(agents: int, configs: Array) -> void:
	print("ABL matrix_begin agents=%d configs=%d runs=%d" % [agents, configs.size(), _runs])
	for round_idx in _runs:
		var order: Array = []
		for i in configs.size():
			order.append(configs[(i + round_idx) % configs.size()])
		for order_idx in order.size():
			var cfg: Dictionary = order[order_idx]
			await _prepare(agents, cfg.aa_off, cfg.hz10, cfg.half)
			await _measure("ablation" if agents > 700 else "ablation_500", agents, cfg.id, cfg.label,
				cfg.aa_off, cfg.hz10, cfg.half, round_idx + 1, order_idx + 1)
	print("ABL matrix_done agents=%d" % agents)


func _run_layers() -> void:
	print("ABL layers_begin agents=1000 variants=%d runs=%d" % [LAYERS.size(), LAYER_ROUNDS])
	for round_idx in LAYER_ROUNDS:
		for order_idx in LAYERS.size():
			var layer: Dictionary = LAYERS[(order_idx + round_idx) % LAYERS.size()]
			await _prepare(1000, true, true, true)
			_apply_layer(layer.id)
			await _measure("layer", 1000, layer.id, layer.label, true, true, true, round_idx + 1, order_idx + 1)
	_reset_layers()
	print("ABL layers_done")


func _prepare(agents: int, aa_off: bool, hz10: bool, half: bool) -> void:
	_main.sim.set_large_group_10hz(hz10)
	_main.view.set_trail_options(not aa_off, half)
	_reset_layers()
	_main.set_view_mode("flow")
	_main.set_show("numbers", false)
	_main.set_show("arrows", true)
	_main.set_show("grid", true)
	_main.set_show("trails", true)
	_main.set_show("agents", true)
	_main.load_sample_map()
	_main.set_agent_count(agents)
	for i in VIEW_SETTLE_FRAMES:
		await process_frame


func _apply_layer(id: String) -> void:
	_reset_layers()
	match id:
		"layer_no_trails":
			_main.set_show("trails", false)
		"layer_no_agents":
			_main.set_show("agents", false)
		"layer_no_arrows":
			_main.set_show("arrows", false)


func _reset_layers() -> void:
	if _main == null:
		return
	_main.set_show("grid", true)
	_main.set_show("numbers", false)
	_main.set_show("arrows", true)
	_main.set_show("trails", true)
	_main.set_show("agents", true)


func _measure(kind: String, agents: int, config_id: String, label: String,
		aa_off: bool, hz10: bool, half: bool, round_idx: int, order_idx: int) -> void:
	var sim = _main.sim
	for i in _warmup:
		await process_frame
	sim.reset_step_stats()
	var frame_ms: Array[float] = []
	var draw_calls: Array[int] = []
	var objects: Array[int] = []
	var primitives: Array[int] = []
	var perf_draw: Array[int] = []
	var perf_objects: Array[int] = []
	var perf_primitives: Array[int] = []
	var load_start := _load_avg()
	var t_start := Time.get_ticks_usec()
	var last := t_start
	for i in _frames:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - last) / 1000.0)
		last = now
		draw_calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		objects.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		primitives.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		perf_draw.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		perf_objects.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		perf_primitives.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	var load_end := _load_avg()

	var stats := _frame_stats(frame_ms)
	var d_count: int = sim.step_count
	var d_total: int = sim.step_total_usec
	var d_max: int = sim.step_max_usec
	var step_mean_ms := float(d_total) / float(maxi(d_count, 1)) / 1000.0
	var step_max_ms := float(d_max) / 1000.0
	var budget_pct := step_mean_ms / FIXED_BUDGET_MS * 100.0
	var build_ms: float = sim.build_ms()
	var elapsed_s := 0.0
	for t in frame_ms:
		elapsed_s += t / 1000.0
	var avg_fps := float(_frames) / maxf(elapsed_s, 0.0001)
	var mem := {
		"video_mem_mb": _bytes_to_mb(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)),
		"texture_mem_mb": _bytes_to_mb(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)),
		"buffer_mem_mb": _bytes_to_mb(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)),
	}

	var record := {
		"kind": kind,
		"agents": agents,
		"config_id": config_id,
		"config_label": label,
		"aa_off": aa_off,
		"large_group_10hz": hz10,
		"trail_half_sampling": half,
		"round": round_idx,
		"order_in_round": order_idx,
		"warmup_frames": _warmup,
		"sample_frames": _frames,
		"avg_fps": avg_fps,
		"p50_ms": stats["p50"],
		"p95_ms": stats["p95"],
		"p99_ms": stats["p99"],
		"worst_ms": stats["worst"],
		"hitch_33ms": stats["hitch33"],
		"hitch_50ms": stats["hitch50"],
		"logic_steps": d_count,
		"logic_step_mean_ms": step_mean_ms,
		"logic_step_max_ms": step_max_ms,
		"logic_budget_pct": budget_pct,
		"build_ms": build_ms,
		"engine": {
			"draw_calls_median": _int_median(draw_calls),
			"draw_calls_max": _int_max(draw_calls),
			"objects_median": _int_median(objects),
			"primitives_median": _int_median(primitives),
			"perf_draw_calls_median": _int_median(perf_draw),
			"perf_objects_median": _int_median(perf_objects),
			"perf_primitives_median": _int_median(perf_primitives),
		},
		"mem": mem,
		"load": {"load1_start": load_start[0], "load5_start": load_start[1],
			"load1_end": load_end[0], "load5_end": load_end[1]},
		"cpu_speed_limit": _cpu_speed_limit(),
	}
	if agents >= 1000 and kind != "layer":
		record["frame_ms"] = _rounded(frame_ms, 3)
	if kind == "layer":
		record["frame_ms"] = _rounded(frame_ms, 3)
	_json_runs.append(record)
	_append_csv_row(kind, agents, config_id, label, aa_off, hz10, half, round_idx, order_idx,
		avg_fps, stats, step_mean_ms, step_max_ms, budget_pct, build_ms, record)
	_flush_csv()
	_save_json()
	print("ABL %s agents=%d config=%s round=%d fps=%.1f p50=%.1f p95=%.1f p99=%.1f worst=%.1f hitch33=%d hitch50=%d logic=%.2fms max_step=%.2fms budget=%.0f%% build=%.2fms draw=%d load1=%.2f/%.2f" % [
		kind, agents, config_id, round_idx, avg_fps, stats["p50"], stats["p95"], stats["p99"],
		stats["worst"], stats["hitch33"], stats["hitch50"], step_mean_ms, step_max_ms,
		budget_pct, build_ms, record["engine"]["draw_calls_median"],
		load_start[0], load_end[0]])


func _frame_stats(times: Array[float]) -> Dictionary:
	var sorted_times := times.duplicate()
	sorted_times.sort()
	var hitch33 := 0
	var hitch50 := 0
	for t in sorted_times:
		if t > HITCH_33:
			hitch33 += 1
		if t > HITCH_50:
			hitch50 += 1
	return {
		"p50": _float_pct(sorted_times, 0.50),
		"p95": _float_pct(sorted_times, 0.95),
		"p99": _float_pct(sorted_times, 0.99),
		"worst": sorted_times[sorted_times.size() - 1] if sorted_times.size() > 0 else 0.0,
		"hitch33": hitch33,
		"hitch50": hitch50,
	}


func _float_pct(sorted_values: Array, p: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var idx := clampi(ceili(p * sorted_values.size()) - 1, 0, sorted_values.size() - 1)
	return sorted_values[idx]


func _int_median(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	return sorted_values[sorted_values.size() / 2]


func _int_max(values: Array[int]) -> int:
	var best := 0
	for v in values:
		best = maxi(best, v)
	return best


func _bytes_to_mb(value: int) -> float:
	return float(value) / (1024.0 * 1024.0)


func _rounded(values: Array[float], digits: int) -> Array:
	var out: Array = []
	var factor := pow(10.0, digits)
	for v in values:
		out.append(roundf(v * factor) / factor)
	return out


func _load_avg() -> Array:
	var out: Array = []
	var code := OS.execute("sysctl", ["-n", "vm.loadavg"], out, true)
	if code != 0 or out.is_empty():
		return [0.0, 0.0, 0.0]
	var text := str(out[0]).replace("{", " ").replace("}", " ")
	var parts := text.split(" ", false)
	var vals: Array = []
	for p in parts:
		vals.append(float(p))
	while vals.size() < 3:
		vals.append(0.0)
	return vals


func _cpu_speed_limit() -> int:
	var out: Array = []
	var code := OS.execute("pmset", ["-g", "therm"], out, true)
	if code != 0:
		return -1
	for line in out:
		var s := str(line)
		if s.find("CPU_Speed_Limit") >= 0:
			var eq := s.find("=")
			if eq >= 0:
				var raw := s.substr(eq + 1).strip_edges()
				var digits := ""
				for ch in raw:
					if ch >= "0" and ch <= "9":
						digits += ch
					else:
						break
				if digits != "":
					return int(digits)
	return -1


func _csv_path() -> String:
	return OUT_DIR + "/ablation_" + _tag + ".csv"


func _append_csv_row(kind: String, agents: int, config_id: String, label: String,
		aa_off: bool, hz10: bool, half: bool, round_idx: int, order_idx: int,
		avg_fps: float, stats: Dictionary, step_mean_ms: float, step_max_ms: float,
		budget_pct: float, build_ms: float, record: Dictionary) -> void:
	var engine: Dictionary = record["engine"]
	var mem: Dictionary = record["mem"]
	var load: Dictionary = record["load"]
	_csv_rows.append(",".join([
		kind, _tag, _mode, str(agents), config_id, label,
		"1" if aa_off else "0", "1" if hz10 else "0", "1" if half else "0",
		str(round_idx), str(order_idx), str(_frames), str(_warmup),
		"%.2f" % avg_fps, "%.2f" % stats["p50"], "%.2f" % stats["p95"],
		"%.2f" % stats["p99"], "%.2f" % stats["worst"],
		str(stats["hitch33"]), str(stats["hitch50"]),
		str(record["logic_steps"]), "%.3f" % step_mean_ms, "%.3f" % step_max_ms,
		"%.1f" % budget_pct, "%.3f" % build_ms,
		str(engine["draw_calls_median"]), str(engine["objects_median"]),
		str(engine["primitives_median"]),
		str(engine["perf_draw_calls_median"]), str(engine["perf_objects_median"]),
		str(engine["perf_primitives_median"]),
		"%.2f" % mem["video_mem_mb"], "%.2f" % mem["texture_mem_mb"], "%.2f" % mem["buffer_mem_mb"],
		"%.2f" % load["load1_start"], "%.2f" % load["load1_end"],
		str(record["cpu_speed_limit"]),
	]))


const CSV_HEADER := "kind,resolution,viewport_mode,agents,config_id,config_label,aa_off,large_group_10hz,trail_half_sampling,round,order_in_round,frames,warmup_frames,avg_fps,p50_ms,p95_ms,p99_ms,worst_ms,hitch_33ms,hitch_50ms,logic_steps,logic_step_mean_ms,logic_step_max_ms,logic_budget_pct,build_ms,draw_calls_median,objects_median,primitives_median,perf_draw_calls_median,perf_objects_median,perf_primitives_median,video_mem_mb,texture_mem_mb,buffer_mem_mb,load1_start,load1_end,cpu_speed_limit"


func _flush_csv() -> void:
	var file := FileAccess.open(_csv_path(), FileAccess.WRITE)
	if file == null:
		push_error("无法写入 CSV：" + _csv_path())
		_failed = true
		return
	file.store_string(CSV_HEADER + "\n")
	for row in _csv_rows:
		file.store_string(row + "\n")
	file.close()


func _save_json() -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(JSON_PATH):
		var text := FileAccess.get_file_as_string(JSON_PATH)
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			data = parsed
	data["meta"] = _meta
	var resolutions: Dictionary = data.get("resolutions", {})
	resolutions[_tag] = {"viewport_mode": _mode, "runs": _json_runs}
	data["resolutions"] = resolutions
	var file := FileAccess.open(JSON_PATH, FileAccess.WRITE)
	if file == null:
		push_error("无法写入 JSON：" + JSON_PATH)
		_failed = true
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
