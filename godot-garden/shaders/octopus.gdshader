shader_type spatial;
render_mode diffuse_burley, cull_disabled;

// 章鱼皮肤：本地坐标噪声做色斑；夜间/睡眠时整体偏冷、去饱和；最后轻微量化成像素色块。
uniform vec3 base_color : source_color = vec3(0.8, 0.24, 0.16);
uniform vec3 dark_color : source_color = vec3(0.55, 0.12, 0.1);
uniform vec3 accent_color : source_color = vec3(0.98, 0.55, 0.38);
uniform float u_night : hint_range(0.0, 1.0) = 0.0;
uniform float u_sleep : hint_range(0.0, 1.0) = 0.0;
uniform float u_arm : hint_range(0.0, 1.0) = 0.0;

varying vec3 local_pos;
varying vec3 world_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	local_pos = VERTEX;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = local_pos.xz * 2.2 + local_pos.y * 1.1;
	float n = vnoise(p) * 0.65 + vnoise(p * 4.0 + 3.0) * 0.35;
	vec3 col = mix(dark_color, base_color, smoothstep(0.22, 0.72, n));
	col = mix(col, accent_color, smoothstep(0.74, 0.95, n) * 0.35);

	float up = world_normal.y * 0.5 + 0.5;
	col *= mix(0.6, 1.05, up);

	// 触手腹面两排吸盘：UV.x 约 0.7/0.8，沿 UV.y 重复；身体不使用。
	if (u_arm > 0.5) {
		float row_a = smoothstep(0.055, 0.0, abs(UV.x - 0.7));
		float row_b = smoothstep(0.055, 0.0, abs(UV.x - 0.8));
		float dots = step(0.5, sin(UV.y * 78.0 + UV.x * 9.0));
		float sucker = max(row_a, row_b) * dots;
		col = mix(col, vec3(0.95, 0.76, 0.56), sucker * 0.72);
	}

	col = mix(col, col * vec3(0.5, 0.38, 0.56) + vec3(0.02, 0.0, 0.03), u_night * 0.7);
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma) * vec3(0.85, 0.7, 0.8), u_sleep * 0.55);

	col = floor(col * 12.0 + 0.5) / 12.0;
	ALBEDO = col;
	ROUGHNESS = 0.82;
	EMISSION = col * 0.025;
}
