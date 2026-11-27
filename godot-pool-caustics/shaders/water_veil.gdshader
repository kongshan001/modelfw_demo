shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// 水面微光：只是几层移动很慢的折射高光，叠在池底焦散之上，不参与光网计算。

uniform float u_time = 0.0;
uniform float u_amount = 0.55;
uniform vec3 u_color : source_color = vec3(0.36, 0.86, 0.82);

varying vec3 v_world;

float veil_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	float t = u_time;
	float a = sin(p.x * 0.72 + p.y * 0.30 + t * 0.42);
	float b = sin(p.y * 0.91 - p.x * 0.23 - t * 0.31 + 1.7);
	float c = sin((p.x + p.y) * 0.46 + sin(p.y * 0.35 + t * 0.11) * 2.1 - t * 0.19);
	float wave = (a + b + c) / 3.0;
	float glint = smoothstep(0.78, 0.98, wave);
	float broad = smoothstep(0.46, 0.92, wave) * 0.105;
	float grain = (veil_hash(floor(p * 26.0) + floor(t * 2.0)) - 0.5) * 0.006;

	ALBEDO = u_color * (0.65 + 0.35 * glint);
	ALPHA = clamp((broad + glint * 0.28 + grain) * u_amount, 0.0, 0.30);
}
