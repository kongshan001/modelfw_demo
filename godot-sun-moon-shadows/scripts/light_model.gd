class_name LightModel
extends RefCounted

# 纯数学的「日月主光」模型。没有 Light2D、没有 3D 灯：
#   太阳 05:00 东升 → 12:00 正午 68° → 19:00 西落；
#   月亮 18:30 东升 → 00:30 最高 52° → 06:30 西落。
#   两者都沿南天同向东→西，共用同一个主光通道。
#   影向：x = -arc（晨右 / 昏左），y = +0.55 的 3/4 俯视压缩；
#   影长：H / tan(elev)，腿点 = 0.60 × (3H)，之后指数饱和逼近 3H。
#   3 个 shader 全局量 = 方向 / 光色 / 环境光扣除量（见 TECH.md）。

const HOURS_PER_DAY := 24.0
const SUNRISE := 5.0
const SUNSET := 19.0
const SUN_NOON := 12.0
const SUN_ARC_HOURS := 7.0
const SUN_MAX_ELEVATION := 68.0
const MOON_RISE := 18.5
const MOON_SET := 30.5
const MOON_NOON := 24.5
const MOON_ARC_HOURS := 6.0
const MOON_MAX_ELEVATION := 52.0
const AZIMUTH_SWEEP_DEG := 48.0
const SHADOW_CAP_MULTIPLE := 3.0
const SHADOW_KNEE_FRACTION := 0.60
const MIN_ELEVATION := 1.0
const MAX_ELEVATION := 89.5
const HEIGHT_MAX := 160.0
const OCCLUSION_BIAS_PX := 2.0
const SKY_CENTER_X := 320.0
const SKY_SWEEP_X := 180.0
const SKY_HORIZON_Y := 92.0
const SUN_SKY_RISE := 58.0
const MOON_SKY_RISE := 56.0

# 日间色温关键帧。阴影 alpha 是「环境光扣除量」，不是叠黑层数。
const SUN_KEYS: Array[Dictionary] = [
	{
		"hour": 5.0,
		"color": Color(1.00, 0.50, 0.34, 1.0),
		"ambient": Color(0.40, 0.34, 0.44, 1.0),
		"shadow": Color(0.16, 0.12, 0.28, 1.0),
		"shadow_alpha": 0.44,
	},
	{
		"hour": 6.5,
		"color": Color(1.00, 0.72, 0.48, 1.0),
		"ambient": Color(0.60, 0.56, 0.64, 1.0),
		"shadow": Color(0.11, 0.15, 0.30, 1.0),
		"shadow_alpha": 0.45,
	},
	{
		"hour": 9.0,
		"color": Color(1.00, 0.87, 0.68, 1.0),
		"ambient": Color(0.78, 0.80, 0.86, 1.0),
		"shadow": Color(0.07, 0.14, 0.27, 1.0),
		"shadow_alpha": 0.44,
	},
	{
		"hour": 12.0,
		"color": Color(1.00, 0.97, 0.88, 1.0),
		"ambient": Color(0.86, 0.89, 0.94, 1.0),
		"shadow": Color(0.05, 0.12, 0.25, 1.0),
		"shadow_alpha": 0.42,
	},
	{
		"hour": 15.5,
		"color": Color(1.00, 0.88, 0.64, 1.0),
		"ambient": Color(0.82, 0.78, 0.82, 1.0),
		"shadow": Color(0.08, 0.12, 0.27, 1.0),
		"shadow_alpha": 0.44,
	},
	{
		"hour": 17.5,
		"color": Color(1.00, 0.70, 0.44, 1.0),
		"ambient": Color(0.66, 0.55, 0.60, 1.0),
		"shadow": Color(0.14, 0.10, 0.28, 1.0),
		"shadow_alpha": 0.46,
	},
	{
		"hour": 19.0,
		"color": Color(1.00, 0.50, 0.40, 1.0),
		"ambient": Color(0.46, 0.38, 0.50, 1.0),
		"shadow": Color(0.18, 0.11, 0.32, 1.0),
		"shadow_alpha": 0.44,
	},
]

const MOON_COLOR := Color(0.62, 0.75, 1.00, 1.0)
const MOON_AMBIENT := Color(0.34, 0.42, 0.60, 1.0)
const MOON_SHADOW := Color(0.05, 0.10, 0.28, 1.0)
const MOON_SHADOW_ALPHA := 0.46
const MOON_INTENSITY := 0.55


static func sun_raw_arc(hour: float) -> float:
	var h := fposmod(hour, HOURS_PER_DAY)
	return (h - SUN_NOON) / SUN_ARC_HOURS


static func sun_arc(hour: float) -> float:
	return clampf(sun_raw_arc(hour), -1.0, 1.0)


static func sun_is_up(hour: float) -> bool:
	var h := fposmod(hour, HOURS_PER_DAY)
	return h >= SUNRISE and h <= SUNSET


# 活动区间外继续用余弦外推，得到负高度角，方便 UI 显示「已落山」。
static func sun_elevation(hour: float) -> float:
	var arc := clampf(sun_raw_arc(hour), -1.35, 1.35)
	return SUN_MAX_ELEVATION * cos(arc * PI * 0.5)


static func sun_azimuth(hour: float) -> float:
	return 90.0 + sun_arc(hour) * 90.0


static func sun_strength(hour: float) -> float:
	if not sun_is_up(hour):
		return 0.0
	return smoothstep(0.0, 10.0, maxf(sun_elevation(hour), 0.0))


static func moon_progress(hour: float) -> float:
	var h := fposmod(hour, HOURS_PER_DAY)
	return fposmod(h - MOON_RISE, HOURS_PER_DAY) / (MOON_ARC_HOURS * 2.0)


static func moon_is_up(hour: float) -> bool:
	return moon_progress(hour) <= 1.0


static func moon_arc(hour: float) -> float:
	return moon_progress(hour) * 2.0 - 1.0


static func moon_elevation(hour: float) -> float:
	return MOON_MAX_ELEVATION * cos(moon_arc(hour) * PI * 0.5)


static func moon_azimuth(hour: float) -> float:
	return 90.0 + moon_arc(hour) * 90.0


static func moon_strength(hour: float) -> float:
	if not moon_is_up(hour):
		return 0.0
	return smoothstep(0.0, 10.0, maxf(moon_elevation(hour), 0.0))


static func night_mix(hour: float) -> float:
	var elev := sun_elevation(hour)
	return clampf(1.0 - smoothstep(-10.0, 10.0, elev), 0.0, 1.0)


static func main_light(hour: float) -> String:
	if sun_strength(hour) > 0.0001:
		return "sun"
	if moon_strength(hour) > 0.0001:
		return "moon"
	# 理论上不存在：日落后 / 日出前月亮都在天上。
	return "sun" if sun_is_up(hour) else "moon"


# 交班软淡入：19:00 主光切到月亮，但强度从 0 起；05:00 主光切回太阳，同样从 0 起。
# 这样影向在交班瞬间虽然跳变，但可见影子的 alpha 为 0，不会出现方向突跳。
static func handoff_weight(hour: float, main: String) -> float:
	var h := fposmod(hour, HOURS_PER_DAY)
	if main == "moon":
		if h >= 19.0 and h < 20.0:
			return smoothstep(19.0, 20.0, h)
		return 1.0
	if h >= 5.0 and h < 6.0:
		return smoothstep(5.0, 6.0, h)
	return 1.0


static func active_arc(hour: float) -> float:
	return sun_arc(hour) if main_light(hour) == "sun" else moon_arc(hour)


static func active_elevation(hour: float) -> float:
	return sun_elevation(hour) if main_light(hour) == "sun" else moon_elevation(hour)


# 影向：晨右、午下、昏左；y 分量 0.55 是 3/4 俯视的地面压缩。
static func shadow_direction(hour: float) -> Vector2:
	var arc := active_arc(hour)
	return Vector2(-arc, 0.55).normalized()


static func light_direction(hour: float) -> Vector2:
	return -shadow_direction(hour)


static func sky_position(arc: float, elevation: float, max_elevation: float,
		rise_px: float) -> Vector2:
	var t := clampf(elevation / maxf(max_elevation, 0.001), 0.0, 1.0)
	return Vector2(SKY_CENTER_X + SKY_SWEEP_X * arc,
			SKY_HORIZON_Y - rise_px * t)


static func sun_sky_position(hour: float) -> Vector2:
	return sky_position(sun_arc(hour), sun_elevation(hour),
			SUN_MAX_ELEVATION, SUN_SKY_RISE)


static func moon_sky_position(hour: float) -> Vector2:
	return sky_position(moon_arc(hour), moon_elevation(hour),
			MOON_MAX_ELEVATION, MOON_SKY_RISE)


static func raw_shadow_length(height_px: float, elevation_deg: float) -> float:
	var elev := clampf(elevation_deg, MIN_ELEVATION, MAX_ELEVATION)
	return height_px / tan(deg_to_rad(elev))


static func shadow_cap(height_px: float) -> float:
	return height_px * SHADOW_CAP_MULTIPLE


static func shadow_knee(height_px: float) -> float:
	return shadow_cap(height_px) * SHADOW_KNEE_FRACTION


# 软膝：膝点前保持 H/tan，膝点后指数饱和，C1 连续并渐近 3H。
static func shadow_length(height_px: float, elevation_deg: float,
		soft_knee: bool = true) -> float:
	if height_px <= 0.0:
		return 0.0
	var raw := raw_shadow_length(height_px, elevation_deg)
	var cap := shadow_cap(height_px)
	var knee := shadow_knee(height_px)
	if not soft_knee:
		return minf(raw, cap)
	if raw <= knee:
		return raw
	var span := maxf(cap - knee, 0.0001)
	var t := (raw - knee) / span
	return knee + span * (1.0 - exp(-t))


# 2.5D：同一物体上高度 h 的顶点按总影长线性缩放；顶上顶点得到完整影长。
static func band_offset(total_length: float, band_height_px: float,
		object_height_px: float) -> float:
	if object_height_px <= 0.0:
		return 0.0
	return total_length * clampf(band_height_px / object_height_px, 0.0, 1.0)


static func height_norm(height_px: float) -> float:
	return clampf(height_px / HEIGHT_MAX, 0.0, 1.0)


# 2.5D 遮挡：投影高度（caster）高于接收面（receiver）才落影。
static func occlusion_allows(caster_height_px: float, receiver_height_px: float,
		bias_px: float = OCCLUSION_BIAS_PX) -> bool:
	return caster_height_px + bias_px >= receiver_height_px


static func phase_label(hour: float) -> String:
	var h := fposmod(hour, HOURS_PER_DAY)
	if h < 5.0:
		return "黎明前"
	if h < 6.5:
		return "黎明"
	if h < 10.0:
		return "晨光"
	if h < 14.0:
		return "正午"
	if h < 17.0:
		return "午后"
	if h < 19.0:
		return "黄昏"
	if h < 21.0:
		return "暮色"
	if h < 24.0:
		return "月夜"
	return "深夜"


static func format_hour(hour: float) -> String:
	var h := fposmod(hour, HOURS_PER_DAY)
	var total_minutes := int(round(h * 60.0)) % (24 * 60)
	return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]


static func sun_style(hour: float) -> Dictionary:
	var h := clampf(hour, SUNRISE, SUNSET)
	var a: Dictionary = SUN_KEYS[0]
	var b: Dictionary = SUN_KEYS[SUN_KEYS.size() - 1]
	for i in range(SUN_KEYS.size() - 1):
		var k0: Dictionary = SUN_KEYS[i]
		var k1: Dictionary = SUN_KEYS[i + 1]
		if h >= float(k0["hour"]) and h <= float(k1["hour"]):
			a = k0
			b = k1
			break
	var span := maxf(float(b["hour"]) - float(a["hour"]), 0.001)
	var t := clampf((h - float(a["hour"])) / span, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return {
		"color": (a["color"] as Color).lerp(b["color"] as Color, t),
		"ambient": (a["ambient"] as Color).lerp(b["ambient"] as Color, t),
		"shadow": (a["shadow"] as Color).lerp(b["shadow"] as Color, t),
		"shadow_alpha": lerpf(float(a["shadow_alpha"]),
				float(b["shadow_alpha"]), t),
	}


static func state(hour: float, soft_knee: bool = true) -> Dictionary:
	var h := fposmod(hour, HOURS_PER_DAY)
	var main := main_light(h)
	var arc := active_arc(h)
	var elev := active_elevation(h)
	var sun_str := sun_strength(h)
	var moon_str := moon_strength(h)
	var handoff := handoff_weight(h, main)
	# 黎明前 04:30–05:00 先把月影淡出，05:00 交班时两边强度都为 0。
	var moon_fade_out := 1.0
	if main == "moon" and h >= 4.5 and h <= 5.0:
		moon_fade_out = 1.0 - smoothstep(4.5, 5.0, h)
	handoff *= moon_fade_out
	var sun_style_data := sun_style(h)
	var night := night_mix(h)
	var light_color: Color
	var ambient: Color
	var shadow_color: Color
	var shadow_alpha: float
	var intensity: float
	var strength: float
	if main == "sun":
		light_color = sun_style_data["color"]
		ambient = sun_style_data["ambient"]
		shadow_color = sun_style_data["shadow"]
		shadow_alpha = float(sun_style_data["shadow_alpha"])
		strength = sun_str
		intensity = sun_str
	else:
		light_color = MOON_COLOR
		ambient = MOON_AMBIENT
		shadow_color = MOON_SHADOW
		shadow_alpha = MOON_SHADOW_ALPHA
		strength = moon_str
		intensity = MOON_INTENSITY * moon_str
	# 交班淡入：19:00 / 05:00 强度与影子 alpha 从 0 开始，避免影向突跳。
	intensity *= handoff
	strength *= handoff
	shadow_alpha *= strength
	var light_dir := -Vector2(-arc, 0.55).normalized()
	return {
		"hour": h,
		"main_light": main,
		"strength": strength,
		"intensity": intensity,
		"handoff": handoff,
		"moon_fade_out": moon_fade_out,
		"light_color": light_color,
		"ambient_color": ambient,
		"shadow_color": shadow_color,
		"shadow_alpha": shadow_alpha,
		"night": night,
		"arc": arc,
		"elevation": elev,
		"azimuth": 90.0 + arc * 90.0,
		"light_dir": light_dir,
		"shadow_dir": -light_dir,
		"sun_elevation": sun_elevation(h),
		"sun_azimuth": sun_azimuth(h),
		"sun_strength": sun_str,
		"sun_sky": sun_sky_position(h),
		"sun_up": sun_is_up(h),
		"moon_elevation": moon_elevation(h),
		"moon_azimuth": moon_azimuth(h),
		"moon_strength": moon_str,
		"moon_sky": moon_sky_position(h),
		"moon_up": moon_is_up(h),
		"soft_knee": soft_knee,
		"shadow_length": shadow_length(HEIGHT_MAX, elev, soft_knee),
		"shadow_cap": shadow_cap(HEIGHT_MAX),
		"shadow_knee": shadow_knee(HEIGHT_MAX),
		"phase": phase_label(h),
	}
