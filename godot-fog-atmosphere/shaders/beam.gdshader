shader_type spatial;
// 伪光束：交叉 billboard 面片 + 程序化噪声 + 叠加混合。
// 不是体积光；用软边、垂直衰减和流动噪声模拟雾中光柱。
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(0.72, 0.82, 1.0, 1.0);
uniform float intensity = 0.5;
uniform float seed = 0.0;
uniform float animation_speed = 1.0;

varying vec2 v_uv;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_uv = UV;
}

void fragment() {
	float edge = smoothstep(0.0, 0.22, v_uv.x) * smoothstep(1.0, 0.78, v_uv.x);
	float vertical = smoothstep(0.0, 0.10, v_uv.y) * smoothstep(1.0, 0.35, v_uv.y);
	float n = value_noise(vec2(v_uv.x * 4.0 + seed, v_uv.y * 2.5 - TIME * 0.10 * animation_speed));
	n = smoothstep(0.30, 0.82, n);
	float a = edge * vertical * (0.30 + 0.70 * n) * intensity;
	ALBEDO = beam_color.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
