shader_type spatial;

// 像素海面：
//  · 3 道不同方向/波长/速度的 Gerstner 波，水平位移把浪尖挤尖
//  · 世界坐标沿 x 压缩 → 浪峰拉长；相位被低频 sin 拧弯；振幅按“浪群”包络起伏
//  · 片元里做受限色阶的像素水纹、浪尖白沫、木筏边缘白沫、逆光提亮
//  · 采样镜像相机 SubViewport 得到平面倒影；碎金 sparkle；按 fresnel 混合透明度
// CPU 端 ocean.gd:height_at() 使用同一套波形公式，供木筏 5 点浮力采样。

render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;

uniform float u_time = 0.0;
uniform float u_wave_height = 1.0;
uniform float u_wave_speed = 1.0;
uniform float u_choppiness = 0.85;
uniform float u_stretch = 0.35;
uniform float u_grouping = 0.55;
uniform float u_wave_angle = 0.0;
uniform float u_foam = 0.9;
uniform float u_sparkle = 1.0;
uniform float u_opacity = 0.86;
uniform float u_reflection = 0.85;
uniform float u_reflection_on = 1.0;
uniform float u_refl_tint = 0.9;
uniform sampler2D u_reflection_tex : filter_linear, repeat_disable;

uniform vec4 u_deep_color : source_color = vec4(0.07, 0.22, 0.32, 1.0);
uniform vec4 u_mid_color : source_color = vec4(0.12, 0.40, 0.50, 1.0);
uniform vec4 u_light_color : source_color = vec4(0.26, 0.68, 0.65, 1.0);
uniform vec4 u_crest_color : source_color = vec4(0.58, 0.90, 0.82, 1.0);
uniform vec4 u_foam_color : source_color = vec4(0.95, 0.99, 1.0, 1.0);
uniform vec4 u_sun_color : source_color = vec4(1.0, 0.88, 0.58, 1.0);
uniform vec4 u_horizon_color : source_color = vec4(0.62, 0.80, 0.86, 1.0);
uniform vec3 u_sun_dir = vec3(-0.52, 0.14, -0.84);
uniform vec3 u_raft_pos = vec3(0.0, 0.0, 0.0);
uniform float u_raft_radius = 1.9;
uniform float u_fade_start = 32.0;
uniform float u_fade_end = 58.0;

varying vec3 v_world;
varying vec3 v_normal;
varying float v_height;
varying float v_crest;

const float TWO_PI = 6.28318530718;
const float GRAV = 9.81;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void add_wave(vec2 p, float angle, float wavelength, float amp, float speed, float chop,
		inout float height, inout vec2 horiz, inout vec3 tangent, inout vec3 binormal,
		inout float jxx, inout float jzz, inout float jxz) {
	float k = TWO_PI / wavelength;
	vec2 d = vec2(cos(angle), sin(angle));
	float omega = sqrt(GRAV * k) * speed * u_wave_speed;
	float f = k * dot(d, p) - omega * u_time;
	float s = sin(f);
	float c = cos(f);
	float qa = chop * amp;
	height += amp * s;
	horiz += d * (qa * c);
	jxx += -d.x * d.x * qa * k * s;
	jzz += -d.y * d.y * qa * k * s;
	jxz += -d.x * d.y * qa * k * s;
	tangent += vec3(-d.x * d.x * qa * k * s, amp * k * d.x * c, -d.x * d.y * qa * k * s);
	binormal += vec3(-d.x * d.y * qa * k * s, amp * k * d.y * c, -d.y * d.y * qa * k * s);
}

void vertex() {
	// 拉长 + 拧弯：压缩采样坐标 x 让浪峰沿横向变长，再叠加低频横向弯曲
	vec2 p = VERTEX.xz;
	p.x *= mix(1.0, 0.55, clamp(u_stretch, 0.0, 1.0));
	p.y += sin(p.x * 0.055 + u_time * 0.18) * 2.0 * u_stretch;

	// 浪群：大浪一拨一拨地来
	float group_env = 0.5 + 0.5 * sin(dot(p, vec2(0.055, 0.031)) - u_time * 0.24);
	float gmul = mix(1.0, 0.62 + 0.72 * group_env, clamp(u_grouping, 0.0, 1.0));
	float amp = u_wave_height * gmul;

	float height = 0.0;
	vec2 horiz = vec2(0.0);
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	float jxx = 0.0;
	float jzz = 0.0;
	float jxz = 0.0;

	add_wave(p, u_wave_angle - 0.38, 15.0, 0.62 * amp, 1.00, u_choppiness * 0.90,
			height, horiz, tangent, binormal, jxx, jzz, jxz);
	add_wave(p, u_wave_angle + 0.72, 7.0, 0.30 * amp, 1.25, u_choppiness * 0.80,
			height, horiz, tangent, binormal, jxx, jzz, jxz);
	add_wave(p, u_wave_angle + 1.90, 4.6, 0.16 * amp, 1.50, u_choppiness * 0.70,
			height, horiz, tangent, binormal, jxx, jzz, jxz);

	// 水平方向 Jacobian：< 1 表示水被挤紧，浪尖越紧白沫越多
	float jac = (1.0 + jxx) * (1.0 + jzz) - jxz * jxz;
	v_crest = clamp((1.0 - jac) * 3.0, 0.0, 1.0);

	// 网格边缘把波幅收回 0，避免远处海面切边露出锯齿状“小岛”
	float edge = 1.0 - smoothstep(52.0, 66.0, max(abs(VERTEX.x), abs(VERTEX.z)));
	height *= edge;
	horiz *= edge;
	v_height = height;
	v_normal = normalize(cross(binormal, tangent));
	v_world = vec3(VERTEX.x + horiz.x, height, VERTEX.z + horiz.y);
	VERTEX = v_world;
}

void fragment() {
	vec3 N = normalize(v_normal);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_world);

	// ── 像素水纹：世界网格里的短横线，两层不同尺度，随水面位移滚动 ───
	vec2 wuv = v_world.xz * 5.0 + vec2(u_time * 0.45, u_time * 0.18);
	vec2 cell = floor(wuv);
	vec2 f = fract(wuv);
	float h1 = hash12(cell);
	float dash1 = step(0.28, f.y) * (1.0 - step(0.58, f.y))
			* step(0.20, h1) * (1.0 - step(0.68, f.x));
	vec2 wuv2 = v_world.xz * 2.3 + vec2(-u_time * 0.20, u_time * 0.28);
	vec2 cell2 = floor(wuv2);
	vec2 f2 = fract(wuv2);
	float h2 = hash12(cell2 + 31.0);
	float dash2 = step(0.45, f2.x) * (1.0 - step(0.56, f2.x)) * step(0.55, h2);
	float pattern = clamp(dash1 * 0.8 + dash2 * 0.45, 0.0, 1.0);

	// ── 4 色受光阶梯（受限调色板） ───────────────────────────────────
	float ndl = dot(N, u_sun_dir) * 0.5 + 0.5;
	float band = clamp(ndl * 0.72 + v_height * 0.12 + 0.08, 0.0, 1.0);
	// 少量像素抖动，避免整片亮部变成一块平滑的塑料膜
	band += (hash12(floor(v_world.xz * 7.4) + 5.0) - 0.5) * 0.035;
	vec3 col = u_deep_color.rgb;
	if (band > 0.42) { col = u_mid_color.rgb; }
	if (band > 0.64) { col = u_light_color.rgb; }
	if (band > 0.86) { col = u_crest_color.rgb; }
	if (pattern > 0.60) {
		vec3 swatch = band > 0.62 ? u_deep_color.rgb : u_light_color.rgb;
		col = mix(col, swatch, 0.28);
	}

	// 逆光：浪背面朝太阳时，浪脊透亮
	float backlit = pow(max(dot(-V, u_sun_dir), 0.0), 3.0);
	col += u_sun_color.rgb * backlit * 0.10 * smoothstep(0.0, 0.4, v_height);

	// ── 平面倒影（镜像相机，x 方向采样翻转，只在大掠射角明显） ────────
	float fres = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 3.0);
	vec2 ruv = vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y);
	ruv += N.xz * 0.012;
	ruv += vec2(sin(v_world.z * 0.8 + u_time * 0.9),
			cos(v_world.x * 0.7 - u_time * 0.7)) * 0.002;
	vec3 refl = texture(u_reflection_tex, clamp(ruv, vec2(0.002), vec2(0.998))).rgb;
	// 基础反射 + 掠射增强：低机位也能看到木筏/帆的倒影
	float refl_amt = clamp(fres * 1.15 + 0.24, 0.0, 1.0) * u_reflection * u_reflection_on;
	vec3 refl_tint = mix(vec3(1.0), u_sun_color.rgb, 0.22) * u_refl_tint;
	col = mix(col, refl * refl_tint, refl_amt);

	// ── 太阳碎金：细窄高光带 + 稀疏金色 sparkle ──────────────────────
	vec3 R = reflect(-V, N);
	float sun_path = pow(max(dot(R, u_sun_dir), 0.0), 64.0);
	col += u_sun_color.rgb * sun_path * 0.16;
	vec2 spark_cell = floor(v_world.xz * 20.0 + vec2(u_time * 2.3, -u_time * 1.7));
	float sp = hash12(spark_cell);
	float sparkle = step(0.975, sp)
			* smoothstep(0.28, 0.75, sun_path + fres * 0.20) * u_sparkle;
	col = mix(col, u_sun_color.rgb * 1.45, clamp(sparkle, 0.0, 1.0));

	// ── 白沫：只在强挤压的浪尖，加低频斑块把大片泡沫切成碎块 ─────────
	float slope = 1.0 - clamp(N.y, 0.0, 1.0);
	float crest = smoothstep(0.78, 1.0, v_crest)
			* mix(1.0, smoothstep(0.0, 0.08, slope), 0.5) * u_foam;
	float patch_a = hash12(floor(v_world.xz * 0.55 + vec2(u_time * 0.10, -u_time * 0.07)));
	float patch_b = hash12(floor(v_world.xz * 1.9 - u_time * 0.14));
	crest *= smoothstep(0.52, 0.80, patch_a) * smoothstep(0.40, 0.72, patch_b);
	float crest_noise = hash12(floor(v_world.xz * 6.0 + vec2(u_time * 0.8, -u_time * 0.6)))
			* 0.7 + hash12(floor(v_world.xz * 13.0 - u_time * 0.3)) * 0.3;
	crest *= smoothstep(0.34, 0.64, crest_noise + v_crest * 0.18);

	vec2 rel = v_world.xz - u_raft_pos.xz;
	float ang = atan(rel.y, rel.x);
	vec2 q = abs(rel) - vec2(1.22, 1.62);
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	sd += sin(ang * 9.0 + u_time * 1.1) * 0.05 + sin(ang * 17.0 - u_time * 0.7) * 0.02;
	float ring = smoothstep(-0.01, 0.03, sd) * smoothstep(0.20, 0.06, sd);
	float ring_noise = smoothstep(0.25, 0.60,
			hash12(floor(v_world.xz * 2.2 + u_time * 0.25)));
	ring *= ring_noise * u_foam * 0.45;
	float foam = clamp(crest + ring, 0.0, 1.0);
	vec3 foam_col = mix(u_foam_color.rgb, u_sun_color.rgb, backlit * 0.35);
	foam_col = mix(foam_col, u_light_color.rgb, 0.15)
			* (0.86 + 0.14 * hash12(floor(v_world.xz * 24.0 + u_time)));
	col = mix(col, foam_col, foam * 0.92);

	// 远处融入天际
	float dist = length(CAMERA_POSITION_WORLD - v_world);
	col = mix(col, u_horizon_color.rgb, smoothstep(u_fade_start, u_fade_end, dist));

	// 受限色阶，收出像素调色板感
	col = floor(col * 20.0 + 0.5) / 20.0;
	ALBEDO = col;
	ALPHA = clamp(mix(0.68, 1.0, fres) * u_opacity, 0.25, 1.0);
}
