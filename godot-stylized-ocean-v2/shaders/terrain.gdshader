// 海岛沙地：干沙 → 湿沙 → 水下沙的明度层级，动画潮线、浅滩泡沫线、沙纹与细碎草色。
shader_type spatial;
render_mode unshaded;

uniform sampler2D foam_tex : filter_linear, repeat_enable;
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform float height_area = 180.0;
uniform float max_depth = 12.0;
uniform float time = 0.0;
uniform float foam_amount = 0.85;

uniform vec3 sand_dry : source_color = vec3(0.945, 0.90, 0.80);
uniform vec3 sand_light : source_color = vec3(0.99, 0.96, 0.87);
uniform vec3 sand_wet : source_color = vec3(0.74, 0.64, 0.49);
uniform vec3 sand_under : source_color = vec3(0.66, 0.76, 0.66);
uniform vec3 grass_tint : source_color = vec3(0.52, 0.72, 0.31);
uniform vec3 foam_color : source_color = vec3(0.985, 1.0, 1.0);
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
	col = mix(col, sand_wet * 1.08, dune_shade * 0.10);

	// 极淡草色斑块（主要植被由独立低模草丛承担）
	float grass = smoothstep(0.60, 0.78, n3 * 0.65 + n4 * 0.35) * smoothstep(1.2, 2.4, h);
	col = mix(col, grass_tint, grass * 0.16);

	// 湿沙：随潮线上下浮动，边缘用噪声打碎
	float tide = sin(time * 0.55 + n4 * 7.0) * 0.055;
	float wet = 1.0 - smoothstep(0.04, 1.3, h - tide + (n2 - 0.5) * 0.24);
	wet = clamp(wet, 0.0, 1.0);
	col = mix(col, sand_wet, wet * 0.92);
	// 湿润区高光：湿沙反光更强
	ROUGHNESS = mix(0.94, 0.42, wet);
	SPECULAR = mix(0.15, 0.55, wet);

	// 潮线泡沫：薄白线 + 随浪进退的第二道细线
	float swash = sin(h * 26.0 + n2 * 8.0 - time * 1.15);
	float line = (1.0 - smoothstep(0.0, 0.05 + 0.035 * n2, abs(h - tide - 0.015)));
	line *= smoothstep(0.18, 0.4, n1 + 0.12) * (0.3 + 0.3 * foam_amount);
	float line2 = (1.0 - smoothstep(0.0, 0.03 + 0.035 * n2, abs(h - tide - 0.22 + 0.05 * swash)));
	line2 *= smoothstep(0.46, 0.66, n1) * 0.16 * foam_amount;

	// 水下沙：偏青绿，被水体覆盖前的一圈过渡
	if (h < 0.0) {
		col = mix(col, sand_under, clamp(-h * 0.35, 0.0, 0.85));
	}

	col = mix(col, foam_color, clamp(line + line2, 0.0, 1.0) * 0.7);

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
