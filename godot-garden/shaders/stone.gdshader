shader_type spatial;
render_mode diffuse_burley;

// 通用石材：世界噪声混色 + 朝上苔藓 + 靠水池的湿石 + 简单的上/侧面假 AO。
// 通过三套 ShaderMaterial（light/mid/dark）复用，避免每个石板单独写材质。

uniform vec3 base_color : source_color = vec3(0.5, 0.47, 0.4);
uniform vec3 dark_color : source_color = vec3(0.28, 0.27, 0.24);
uniform vec3 moss_color : source_color = vec3(0.18, 0.3, 0.12);
uniform vec3 pond_center = vec3(-5.0, 0.0, 3.0);
uniform float pond_radius = 4.2;

varying vec3 world_pos;
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
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = vnoise(p * 1.7) * 0.6 + vnoise(p * 6.0) * 0.4;
	vec3 col = mix(dark_color, base_color, n);

	float up = clamp(world_normal.y, 0.0, 1.0);
	col *= mix(0.72, 1.06, up);

	float moss = smoothstep(0.6, 0.9, up) * smoothstep(0.55, 0.78, vnoise(p * 2.5 + 7.0));
	col = mix(col, moss_color, moss * 0.65);

	float d = length(world_pos.xz - pond_center.xz);
	float wet = 1.0 - smoothstep(pond_radius + 0.3, pond_radius + 1.8, d);
	col = mix(col, col * 0.55, wet * 0.55);

	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.32, wet * 0.7);
	METALLIC = 0.0;
}
