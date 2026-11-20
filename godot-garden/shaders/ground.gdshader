shader_type spatial;
render_mode diffuse_burley;

uniform vec3 color_a : source_color = vec3(0.1, 0.19, 0.08);
uniform vec3 color_b : source_color = vec3(0.22, 0.35, 0.13);
uniform vec3 color_c : source_color = vec3(0.27, 0.27, 0.16);

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
	vec2 p = world_pos.xz;
	float n = vnoise(p * 0.55) * 0.6 + vnoise(p * 2.4) * 0.4;
	float patch = vnoise(p * 0.16 + 7.0);
	vec3 col = mix(color_a, color_b, n);
	col = mix(col, color_c, smoothstep(0.55, 0.86, patch) * 0.28);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
