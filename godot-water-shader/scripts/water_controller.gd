class_name WaterController
extends RefCounted

# 参数与预设（不依赖场景树，便于无头测试）：
#   海 / 河 / 湖三套基础预设 × 全局倍率（潮汐 / 流速 / 浪幅 / 泡沫 / 焦散）。
#   内陆湖预设的浪幅接近 0、焦散为 0，对应 BFS 的“不贴边 → 内陆湖”。
#   u_focus 只做观察高亮，不改变水体分类；u_rain 同时驱动积水和雨纹。

const CAT_ALL := 0
const CAT_SEA := 1
const CAT_RIVER := 2
const CAT_LAKE := 3
const CAT_PUDDLE := 4

const DEVICE_DEFAULTS := {
	"tide": 0.5,
	"flow": 1.0,
	"wave": 1.0,
	"foam": 1.0,
	"caustic": 1.0,
	"rain": 0.0,
}

const BASE_PRESETS := {
	CAT_SEA: {"wave": 1.0, "flow": 0.55, "foam": 1.0, "caustic": 1.0},
	CAT_RIVER: {"wave": 0.32, "flow": 1.35, "foam": 0.50, "caustic": 0.60},
	CAT_LAKE: {"wave": 0.05, "flow": 0.0, "foam": 0.07, "caustic": 0.0},
	CAT_PUDDLE: {"wave": 0.02, "flow": 0.0, "foam": 0.10, "caustic": 0.0},
}

const DEEP_COLORS := {
	CAT_SEA: Color(0.16, 0.42, 0.46),
	CAT_RIVER: Color(0.12, 0.34, 0.32),
	CAT_LAKE: Color(0.10, 0.26, 0.24),
}

var tide := 0.5
var flow_scale := 1.0
var wave_scale := 1.0
var foam_scale := 1.0
var caustic_scale := 1.0
var rain := 0.0
var focus := CAT_ALL
var debug_view := 0
var paused := false
var time_seconds := 0.0

var _rain_prev := 0.0


func set_focus(cat: int) -> void:
	focus = clampi(cat, CAT_ALL, CAT_LAKE)


func set_param(param: String, value: float) -> void:
	match param:
		"tide":
			tide = clampf(value, 0.0, 1.0)
		"flow":
			flow_scale = clampf(value, 0.0, 2.0)
		"wave":
			wave_scale = clampf(value, 0.0, 2.0)
		"foam":
			foam_scale = clampf(value, 0.0, 2.0)
		"caustic":
			caustic_scale = clampf(value, 0.0, 2.0)
		"rain":
			rain = clampf(value, 0.0, 1.0)
		_:
			push_warning("unknown water parameter: %s" % param)


func get_param(param: String) -> float:
	match param:
		"tide":
			return tide
		"flow":
			return flow_scale
		"wave":
			return wave_scale
		"foam":
			return foam_scale
		"caustic":
			return caustic_scale
		"rain":
			return rain
	return 0.0


func toggle_rain() -> bool:
	if rain > 0.01:
		_rain_prev = rain
		rain = 0.0
		return false
	rain = _rain_prev if _rain_prev > 0.01 else 0.85
	return true


func set_paused(value: bool) -> void:
	paused = value


func cycle_debug() -> int:
	debug_view = (debug_view + 1) % 5
	return debug_view


func set_debug_view(view: int) -> void:
	debug_view = clampi(view, 0, 4)


func advance(delta: float) -> void:
	if not paused:
		time_seconds += delta


func set_time_seconds(seconds: float) -> void:
	time_seconds = maxf(0.0, seconds)


func effective(cat: int) -> Dictionary:
	var base: Dictionary = BASE_PRESETS.get(cat, BASE_PRESETS[CAT_PUDDLE])
	var tide_wave := 0.85 + 0.30 * tide
	var tide_foam := 0.55 + 0.90 * tide
	return {
		"wave": float(base["wave"]) * wave_scale * tide_wave,
		"flow": float(base["flow"]) * flow_scale,
		"foam": float(base["foam"]) * foam_scale * tide_foam,
		"caustic": float(base["caustic"]) * caustic_scale * (0.80 + 0.20 * tide),
	}


func vectors() -> Dictionary:
	var sea := effective(CAT_SEA)
	var river := effective(CAT_RIVER)
	var lake := effective(CAT_LAKE)
	return {
		"wave": Vector3(sea["wave"], river["wave"], lake["wave"]),
		"flow": Vector3(sea["flow"], river["flow"], lake["flow"]),
		"foam": Vector3(sea["foam"], river["foam"], lake["foam"]),
		"caustic": Vector3(sea["caustic"], river["caustic"], lake["caustic"]),
	}


func apply_to(material: ShaderMaterial) -> void:
	if material == null:
		return
	var v := vectors()
	material.set_shader_parameter("u_time", time_seconds)
	material.set_shader_parameter("u_tide", tide)
	material.set_shader_parameter("u_rain", rain)
	material.set_shader_parameter("u_focus", float(focus))
	material.set_shader_parameter("u_debug", debug_view)
	material.set_shader_parameter("u_wave", v["wave"])
	material.set_shader_parameter("u_flow_speed", v["flow"])
	material.set_shader_parameter("u_foam", v["foam"])
	material.set_shader_parameter("u_caustic", v["caustic"])
	material.set_shader_parameter("u_sea_deep", DEEP_COLORS[CAT_SEA])
	material.set_shader_parameter("u_river_deep", DEEP_COLORS[CAT_RIVER])
	material.set_shader_parameter("u_lake_deep", DEEP_COLORS[CAT_LAKE])
	material.set_shader_parameter("u_shallow", Color(0.67, 0.83, 0.71))


func focus_label() -> String:
	match focus:
		CAT_SEA:
			return "海域"
		CAT_RIVER:
			return "河流"
		CAT_LAKE:
			return "内陆湖"
	return "全部水体"


func debug_label() -> String:
	match debug_view:
		1:
			return "水体掩码"
		2:
			return "水深场"
		3:
			return "水体类别"
		4:
			return "岸线"
	return "关闭"


func get_params() -> Dictionary:
	return {
		"tide": tide, "flow": flow_scale, "wave": wave_scale, "foam": foam_scale,
		"caustic": caustic_scale, "rain": rain, "focus": focus,
		"debug": debug_view, "paused": paused, "time": time_seconds,
		"focus_label": focus_label(), "debug_label": debug_label(),
	}


func reset() -> void:
	tide = DEVICE_DEFAULTS["tide"]
	flow_scale = DEVICE_DEFAULTS["flow"]
	wave_scale = DEVICE_DEFAULTS["wave"]
	foam_scale = DEVICE_DEFAULTS["foam"]
	caustic_scale = DEVICE_DEFAULTS["caustic"]
	rain = DEVICE_DEFAULTS["rain"]
	focus = CAT_ALL
	debug_view = 0
	paused = false
	time_seconds = 0.0
	_rain_prev = 0.0
