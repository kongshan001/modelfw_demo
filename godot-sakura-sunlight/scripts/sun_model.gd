class_name SunModel
extends RefCounted

# 纯数学太阳 / 时间模型。没有 Light2D，也没有 3D 场景：
#   刻数：6000 刻 = 24h，250 刻 = 1h，2000 刻 = 08:00。
#   日弧：arc = (hour - 12) / 6（06:00 = -1，12:00 = 0，18:00 = +1）。
#   高度角：70° * cos(|arc| * PI/2)。08:00 = 35.0°，12:00 = 70.0°，
#           09:45 = 58.2°（与参考视频的数值一致）。
#   方位角：屏幕平面角，0° = 屏幕右，90° = 屏幕上；azimuth = 90 + arc*60。
#   平面太阳向量 = (cos az, -sin az)；地面影向 = -太阳向量。
#   影长 = 树高 / tan(clamp(高度角, 1°, 89.5°))，再 clamp 到树高的倍数上限。

const TICKS_PER_DAY := 6000
const TICKS_PER_HOUR := 250
const HOURS_PER_DAY := 24.0
const DAY_START_HOUR := 8.0
const DAY_END_HOUR := 17.0
const NOON_ELEVATION := 70.0
const ARC_HALF_HOURS := 6.0
const AZIMUTH_NOON := 90.0
const AZIMUTH_SWEEP := 60.0
const MIN_TAN_ELEVATION := 1.0
const MAX_TAN_ELEVATION := 89.5
const DEFAULT_MAX_SHADOW_MULTIPLE := 1.8

# 色温关键帧：清晨暖金 → 正午中性 → 傍晚橙红；环境色始终偏冷，
# 阴影色则从冷绿过渡到更蓝的傍晚色。
const LIGHT_KEYS: Array[Dictionary] = [
	{
		"hour": 8.0,
		"sun": Color(1.00, 0.81, 0.58, 1.0),
		"ambient": Color(0.80, 0.83, 0.94, 1.0),
		"shadow": Color(0.13, 0.19, 0.23, 0.60),
		"intensity": 0.90,
	},
	{
		"hour": 10.5,
		"sun": Color(1.00, 0.92, 0.78, 1.0),
		"ambient": Color(0.87, 0.90, 0.95, 1.0),
		"shadow": Color(0.10, 0.19, 0.17, 0.58),
		"intensity": 0.97,
	},
	{
		"hour": 12.0,
		"sun": Color(1.00, 0.98, 0.90, 1.0),
		"ambient": Color(0.92, 0.94, 0.97, 1.0),
		"shadow": Color(0.08, 0.18, 0.15, 0.58),
		"intensity": 1.00,
	},
	{
		"hour": 14.5,
		"sun": Color(1.00, 0.91, 0.75, 1.0),
		"ambient": Color(0.88, 0.87, 0.94, 1.0),
		"shadow": Color(0.11, 0.18, 0.22, 0.59),
		"intensity": 0.96,
	},
	{
		"hour": 16.0,
		"sun": Color(1.00, 0.80, 0.58, 1.0),
		"ambient": Color(0.80, 0.78, 0.92, 1.0),
		"shadow": Color(0.14, 0.17, 0.26, 0.61),
		"intensity": 0.90,
	},
	{
		"hour": 17.0,
		"sun": Color(1.00, 0.63, 0.44, 1.0),
		"ambient": Color(0.74, 0.72, 0.90, 1.0),
		"shadow": Color(0.17, 0.16, 0.29, 0.64),
		"intensity": 0.78,
	},
]


static func hour_to_ticks(hour: float) -> int:
	var wrapped := fposmod(hour, HOURS_PER_DAY)
	return posmod(int(round(wrapped * TICKS_PER_HOUR)), TICKS_PER_DAY)


static func ticks_to_hour(ticks: int) -> float:
	return float(posmod(ticks, TICKS_PER_DAY)) / TICKS_PER_HOUR


static func day_arc(hour: float) -> float:
	return clampf((hour - 12.0) / ARC_HALF_HOURS, -1.0, 1.0)


static func elevation_deg(hour: float) -> float:
	var arc := day_arc(hour)
	return maxf(0.0, NOON_ELEVATION * cos(absf(arc) * PI * 0.5))


static func azimuth_deg(hour: float) -> float:
	return AZIMUTH_NOON + day_arc(hour) * AZIMUTH_SWEEP


# 从场景指向太阳的平面单位向量。屏幕坐标 y 向下，所以 sin 取负。
static func sun_plane_dir(hour: float) -> Vector2:
	var az := deg_to_rad(azimuth_deg(hour))
	return Vector2(cos(az), -sin(az)).normalized()


# 地面影向：太阳平面向量取反（与参考 GroundSunShadows 的取反一致）。
static func shadow_direction(hour: float) -> Vector2:
	return -sun_plane_dir(hour)


static func raw_shadow_length(visual_height: float, hour: float) -> float:
	var elev := clampf(elevation_deg(hour), MIN_TAN_ELEVATION, MAX_TAN_ELEVATION)
	return visual_height / tan(deg_to_rad(elev))


static func shadow_length(visual_height: float, hour: float,
		maximum_multiple: float = DEFAULT_MAX_SHADOW_MULTIPLE) -> float:
	var raw := raw_shadow_length(visual_height, hour)
	return minf(raw, visual_height * maximum_multiple)


static func shadow_info(visual_height: float, hour: float,
		maximum_multiple: float = DEFAULT_MAX_SHADOW_MULTIPLE) -> Dictionary:
	var raw := raw_shadow_length(visual_height, hour)
	var cap := visual_height * maximum_multiple
	return {
		"raw": raw,
		"cap": cap,
		"length": minf(raw, cap),
		"ratio": minf(raw, cap) / maxf(visual_height, 0.001),
		"capped": raw > cap,
		"elevation": elevation_deg(hour),
	}


static func phase_label(hour: float) -> String:
	if hour < 10.0:
		return "晨光"
	if hour < 14.0:
		return "正午"
	if hour < 16.0:
		return "午后"
	return "夕照"


static func light_style(hour: float) -> Dictionary:
	var h := clampf(hour, DAY_START_HOUR, DAY_END_HOUR)
	var a: Dictionary = LIGHT_KEYS[0]
	var b: Dictionary = LIGHT_KEYS[LIGHT_KEYS.size() - 1]
	for i in range(LIGHT_KEYS.size() - 1):
		var k0: Dictionary = LIGHT_KEYS[i]
		var k1: Dictionary = LIGHT_KEYS[i + 1]
		if h >= float(k0["hour"]) and h <= float(k1["hour"]):
			a = k0
			b = k1
			break
	var span := maxf(float(b["hour"]) - float(a["hour"]), 0.001)
	var t := clampf((h - float(a["hour"])) / span, 0.0, 1.0)
	# 平滑一下，避免关键帧处出现折线。
	t = t * t * (3.0 - 2.0 * t)
	return {
		"sun_color": (a["sun"] as Color).lerp(b["sun"] as Color, t),
		"ambient_color": (a["ambient"] as Color).lerp(b["ambient"] as Color, t),
		"shadow_color": (a["shadow"] as Color).lerp(b["shadow"] as Color, t),
		"intensity": lerpf(float(a["intensity"]), float(b["intensity"]), t),
	}


static func state(hour: float,
		maximum_multiple: float = DEFAULT_MAX_SHADOW_MULTIPLE) -> Dictionary:
	var h := clampf(hour, DAY_START_HOUR, DAY_END_HOUR)
	var style := light_style(h)
	return {
		"hour": h,
		"ticks": hour_to_ticks(h),
		"arc": day_arc(h),
		"azimuth": azimuth_deg(h),
		"elevation": elevation_deg(h),
		"sun_dir": sun_plane_dir(h),
		"shadow_dir": shadow_direction(h),
		"shadow": shadow_info(1.0, h, maximum_multiple),
		"phase": phase_label(h),
		"sun_color": style["sun_color"],
		"ambient_color": style["ambient_color"],
		"shadow_color": style["shadow_color"],
		"sun_intensity": style["intensity"],
	}
