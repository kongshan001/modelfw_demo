shader_type spatial;
// 原创砂径：世界坐标噪声的暖米色细砂，湿边略深；不依赖贴图。
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 sand_light : source_color = vec3(0.78, 0.66, 0.43);
uniform vec3 sand_mid : source_color = vec3(0.59, 0.48, 0.31);
uniform vec3 sand_dark : source_color = vec3(0.36, 0.30, 0.23);

varying vec3 world_pos;

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
}

void fragment() {
	float n = vnoise(world_pos.xz * 2.6) * 0.55 + vnoise(world_pos.xz * 8.3 + 17.0) * 0.45;
	vec3 col = mix(sand_dark, sand_mid, smoothstep(0.18, 0.62, n));
	col = mix(col, sand_light, smoothstep(0.55, 0.92, n) * 0.72);
	float grit = step(0.88, hash21(floor(world_pos.xz * 21.0)));
	col += grit * vec3(0.08, 0.06, 0.035);
	ALBEDO = col;
	EMISSION = col * 0.045;
	ROUGHNESS = 0.96;
	SPECULAR = 0.10;
}
