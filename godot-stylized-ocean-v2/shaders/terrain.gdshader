// 海岛沙地：干沙 → 湿沙 → 水线暗带 → 水下沙底（沙纹/海草/焦散）。
// 岸距场（SDF）驱动湿沙/水线宽度与拍岸涨落，与水面泡沫共用同一张纹理，保证不错位。
shader_type spatial;
render_mode unshaded;

uniform sampler2D foam_tex : filter_linear, repeat_enable;
uniform sampler2D shore_map : filter_linear, repeat_disable;
uniform sampler2D caustic_tex : filter_linear, repeat_enable;
uniform float shore_area = 180.0;
uniform float shore_range = 16.0;
uniform float time = 0.0;
uniform float foam_amount = 0.85;
uniform float rain = 0.0;

uniform vec3 sand_dry : source_color = vec3(0.925, 0.898, 0.827);
uniform vec3 sand_light : source_color = vec3(0.969, 0.941, 0.878);
uniform vec3 sand_damp : source_color = vec3(0.839, 0.804, 0.725);
uniform vec3 sand_wet : source_color = vec3(0.749, 0.714, 0.639);
uniform vec3 sand_edge : source_color = vec3(0.639, 0.647, 0.612);
uniform vec3 sand_under : source_color = vec3(0.824, 0.765, 0.651);
uniform vec3 sand_deep : source_color = vec3(0.431, 0.514, 0.502);
uniform vec3 grass_tint : source_color = vec3(0.52, 0.72, 0.31);
uniform vec3 foam_color : source_color = vec3(0.985, 1.0, 1.0);
uniform vec3 caustic_color : source_color = vec3(0.72, 1.0, 0.96);
uniform vec3 sky_sheen : source_color = vec3(0.80, 0.92, 0.96);
uniform vec3 sun_dir = vec3(-0.45, 0.85, -0.25);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.99, 0.96);
uniform vec3 shade_tint : source_color = vec3(0.82, 0.88, 0.95);
uniform float night_level = 0.0;

varying vec3 v_world;
varying vec3 v_nrm;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nrm = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	vec3 p = v_world;
	float h = p.y;

	vec4 shore = texture(shore_map, p.xz / shore_area + 0.5);
	float sd = (shore.r - 0.5) * shore_range;    // + 内陆 / − 水下（米）
	float prop = shore.g;
	float wfac = 0.55 + shore.b * 0.9;
	float phase = shore.a;

	vec2 fp = p.xz * 0.08;
	float n1 = texture(foam_tex, fp + vec2(time * 0.002, 0.0)).r;
	float n2 = texture(foam_tex, p.xz * 0.29 - vec2(time * 0.003, 0.0)).r;
	float n3 = texture(foam_tex, p.xz * 0.031 + vec2(0.37, 0.71)).r;
	float n4 = texture(foam_tex, p.xz * 0.012 + vec2(0.11, 0.53)).r;

	// 沙面明度：沙丘脊亮、洼地略暗，加沙纹与风蚀弧线
	float dune = smoothstep(0.35, 2.9, h);
	vec3 col = mix(sand_dry, sand_light, dune * 0.65 + (n3 - 0.5) * 0.4);
	col *= 0.95 + (n2 - 0.5) * 0.07;
	float ripple = sin(p.x * 0.85 + sin(p.z * 0.42 + n3 * 3.4) * 2.2 + n4 * 2.0);
	col *= 0.985 + 0.022 * smoothstep(0.35, 0.95, ripple);
	float dune_shade = smoothstep(0.55, 0.85, n3 * 0.7 + n4 * 0.3);
	col = mix(col, sand_damp * 1.05, dune_shade * 0.10);

	// 极淡草色斑块（主要植被由独立低模草丛承担）
	float grass = smoothstep(0.60, 0.78, n3 * 0.65 + n4 * 0.35) * smoothstep(1.2, 2.4, h);
	col = mix(col, grass_tint, grass * 0.16);

	// ── 湿沙带（SDF 驱动，宽度随岸线变化 2.6–5.0 m，拍岸时上下涨落） ──
	float land = smoothstep(-0.06, 0.12, h);
	float swash = 0.22 * sin(time * 0.85 + phase * 6.2831853)
			+ 0.09 * sin(time * 1.7 + phase * 17.0);
	float warp = (n2 - 0.5) * 0.9 + (n4 - 0.5) * 0.5;
	float d = sd + warp - swash;
	float wet_w = (3.6 + 2.4 * wfac) * (1.0 + rain * 0.6);
	float damp = (1.0 - smoothstep(0.22 * wet_w, 1.08 * wet_w, d)) * land;
	float wet = (1.0 - smoothstep(0.02, 0.30 * wet_w, d)) * land;
	col = mix(col, sand_damp, damp * 0.86);
	col = mix(col, sand_wet, wet * 0.92);

	// 水线暗带：0.3–0.8 m 不均宽，带噪声毛边；湿沙向水面的接触阴影
	float edge_w = 0.30 + 0.50 * (0.5 + 0.5 * sin(phase * 21.0 + 1.3));
	float edge = (1.0 - smoothstep(0.0, edge_w, d + 0.12 * (n2 - 0.5))) * land;
	col = mix(col, sand_edge, edge * 0.62);
	col = mix(col, sand_edge * 0.90, edge * wet * 0.22);

	// 湿沙微高光（unshaded 下用视角菲涅尔伪装水膜反光）
	vec3 V = normalize(CAMERA_POSITION_WORLD - p);
	float sheen = pow(1.0 - clamp(dot(normalize(v_nrm), V), 0.0, 1.0), 3.0);
	col += sky_sheen * sheen * wet * 0.055;

	// 岸线道具（礁石/棕榈）接触湿痕
	col = mix(col, sand_wet * 0.86, prop * damp * 0.30);

	// 潮线泡沫残迹：拍岸水线附近的一条不规则白痕
	float residue = 1.0 - smoothstep(0.0, 0.14 + 0.12 * n2, abs(d - 0.06));
	residue *= smoothstep(0.55, 0.74, n1*0.7 + n2*0.3 + 0.08) * land * (0.4 + 0.6 * foam_amount);
	col = mix(col, foam_color, residue * 0.18);

	// ── 水下沙底：暖沙 → 深水暗青，沙纹 + 海草斑 + 焦散光网（透过透明浅水可见） ──
	if (h < 0.03) {
		float uw = smoothstep(0.0, 0.05, -h);
		float deep = smoothstep(0.0, 6.0, -h);
		vec3 bed = mix(sand_under, sand_deep, deep);
		// 水下的冷色衰减：让浅水明显偏青绿，而不是“湿沙延伸”
		bed = mix(bed, bed * vec3(0.60, 0.82, 0.79), smoothstep(0.35, 3.4, -h));
		float bed_ripple = sin(p.x * 1.35 + sin(p.z * 0.55 + n3 * 2.6) * 2.2 + n4 * 1.5);
		bed *= 0.965 + 0.045 * smoothstep(-0.6, 0.8, bed_ripple);
		bed *= 0.96 + (n2 - 0.5) * 0.08;
		float weed = smoothstep(0.58, 0.74, n3 * 0.6 + n4 * 0.4)
				* smoothstep(0.5, 1.5, -h) * (1.0 - smoothstep(3.4, 4.8, -h));
		bed = mix(bed, vec3(0.30, 0.42, 0.33), weed * 0.30);
		// 礁石周围的藻色/阴影，替代旧的青色平板光晕
		bed = mix(bed, bed * vec3(0.72, 0.80, 0.72), prop * 0.45);
		float cmask = smoothstep(0.25, 0.7, -h) * (1.0 - smoothstep(2.4, 4.0, -h));
		// 远处淡出：广角时焦散细纹不至于变成噪点，近景仍能看到光网
		float cam_dist = distance(p, CAMERA_POSITION_WORLD);
		cmask *= 1.0 - smoothstep(45.0, 95.0, cam_dist);
		vec2 cuv = p.xz * 0.07;
		float ca1 = texture(caustic_tex, cuv + vec2(time * 0.004, -time * 0.003)).r;
		float ca2 = texture(caustic_tex, cuv * 1.13 + vec2(0.37, 0.21) - vec2(time * 0.003, time * 0.005)).r;
		float ca = smoothstep(0.22, 0.78, max(ca1, ca2 * 0.82));
		float breaks = smoothstep(0.36, 0.62, n1);
		bed += caustic_color * ca * cmask * breaks * (0.070 + 0.030 * (1.0 - deep));
		col = mix(col, bed, uw);
	}

	// 手绘式方向光：不依赖引擎灯光，保证卡通色彩与参考一致
	float ndl = clamp(dot(normalize(v_nrm), normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 lit = mix(shade_tint, sun_tint, pow(ndl, 1.7));
	col *= lit * 1.02;
	// 夜间：木屋/瞭望塔的暖色灯光洒在沙地上（手绘光晕）
	float lamp1 = exp(-length(p.xz - vec2(-9.5, 4.5)) / 4.5) * night_level;
	float lamp2 = exp(-length(p.xz - vec2(2.5, -10.5)) / 5.5) * night_level;
	col = mix(col, vec3(1.0, 0.74, 0.46), lamp1 * 0.34);
	col = mix(col, vec3(1.0, 0.66, 0.44), lamp2 * 0.24);
	ALBEDO = col;
}
