shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 foam_color : source_color = vec4(0.5, 0.65, 0.6, 0.32);
uniform float u_intensity = 1.0;

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
	// 用噪声打断整圈岸线，避免“霓虹光环”。
	float n = vnoise(world_pos.xz * 2.4 + vec2(TIME * 0.02, 0.0));
	float mask = smoothstep(0.42, 0.72, n);
	ALBEDO = foam_color.rgb;
	ALPHA = foam_color.a * u_intensity * (0.2 + 0.8 * mask);
}
