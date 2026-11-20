shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform float u_strength : hint_range(0.0, 0.5) = 0.1;
uniform float u_speed = 0.012;
uniform vec3 tint : source_color = vec3(0.015, 0.03, 0.035);

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
	vec2 p = world_pos.xz * 0.07 + vec2(TIME * u_speed, TIME * u_speed * 0.7);
	float n = vnoise(p) * 0.6 + vnoise(p * 2.1 + 3.0) * 0.4;
	float cloud = smoothstep(0.5, 0.78, n);
	ALBEDO = tint;
	ALPHA = cloud * u_strength;
}
