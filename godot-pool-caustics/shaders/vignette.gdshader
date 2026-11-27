shader_type canvas_item;
render_mode blend_mix;

// 轻量暗角 + 冷色边缘 + 颗粒，放在 3D 画面之上、HUD 之下。
// 不读取屏幕纹理，避免在 Intel / GL Compatibility 上多一次全屏拷贝。

uniform float u_amount = 0.72;
uniform vec4 u_edge_color : source_color = vec4(0.003, 0.026, 0.038, 1.0);
uniform float u_grain = 0.010;

float vig_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 p = SCREEN_UV - 0.5;
	p.x *= 1.05;
	float r = length(p * vec2(1.0, 0.82));
	float vig = smoothstep(0.30, 0.74, r);
	float grain = vig_hash(FRAGCOORD.xy + fract(TIME) * 37.0) - 0.5;
	COLOR = vec4(u_edge_color.rgb, clamp(vig * u_amount + grain * u_grain, 0.0, 1.0));
}
