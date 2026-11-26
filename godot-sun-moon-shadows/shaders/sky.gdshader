shader_type canvas_item;

// 南天穹顶：白天蓝、黄昏橙紫、夜里深蓝星点。
// 昼夜权重、主光方向/高度、光色全部来自同一组 3 个全局向量。

global uniform vec4 u_light_dir;
global uniform vec4 u_light_color;
global uniform vec4 u_ambient_sub;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float night = clamp(u_light_dir.w, 0.0, 1.0);
	float elev01 = clamp(u_light_dir.z, 0.0, 1.0);
	float day = 1.0 - night;
	float dusk = day * (1.0 - smoothstep(0.08, 0.55, elev01));
	float g = smoothstep(0.0, 0.245, UV.y);

	vec3 day_top = vec3(0.30, 0.53, 0.72);
	vec3 day_hor = vec3(0.76, 0.82, 0.76);
	vec3 dusk_top = vec3(0.19, 0.20, 0.35);
	vec3 dusk_hor = vec3(0.96, 0.53, 0.34);
	vec3 night_top = vec3(0.020, 0.035, 0.085);
	vec3 night_hor = vec3(0.065, 0.105, 0.21);

	vec3 top = mix(mix(day_top, dusk_top, dusk), night_top, night);
	vec3 hor = mix(mix(day_hor, dusk_hor, dusk), night_hor, night);
	vec3 col = mix(top, hor, g);

	// 地平线光晕：主光色（日光暖 / 月光冷）在低空扩散。
	float glow_band = exp(-pow((UV.y - 0.225) / 0.075, 2.0));
	col += u_light_color.rgb * u_light_color.a * glow_band
			* mix(0.18, 0.55, dusk) * (1.0 - night * 0.45);

	// 星点只在深夜最明显；用 TIME 做很慢的闪烁。
	vec2 cell = floor(FRAGCOORD.xy / vec2(2.0, 2.0));
	float h = hash12(cell);
	float star = step(0.9975, h) * smoothstep(0.13, 0.0, UV.y);
	float twinkle = 0.68 + 0.32 * sin(TIME * 1.7 + h * 41.0);
	col += vec3(0.78, 0.86, 1.0) * star * night * (1.0 - dusk) * twinkle;

	// 环境扣除量给夜空一点紫蓝底。
	col = mix(col, col * u_ambient_sub.rgb * 2.6, 0.10 * night);
	COLOR = vec4(col, 1.0);
}
