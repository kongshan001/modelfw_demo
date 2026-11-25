shader_type canvas_item;
render_mode unshaded;

// 轻量屏幕覆盖：晨光暖晕 + 四角暗角 + 夜色冷调。位于世界之上、移轴之下。

uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float warmth : hint_range(-1.0, 1.0) = 0.4;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 warm_tint = mix(vec3(0.74, 0.84, 0.92), vec3(1.0, 0.78, 0.46),
			clamp(0.5 + warmth * 0.5, 0.0, 1.0));
	vec3 tint = mix(warm_tint, vec3(0.28, 0.38, 0.62), night);
	float sun_glow = exp(-distance(uv, vec2(0.16, 0.08)) * 4.4)
			* (0.12 * (1.0 - night * 0.6));
	float edge = smoothstep(0.42, 0.92, distance(uv, vec2(0.5, 0.48)));
	float vignette = edge * (0.16 + 0.10 * night);
	float grain = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	float dither = (grain - 0.5) * 0.012;
	vec3 col = tint * (sun_glow * 0.9) + vec3(0.02, 0.03, 0.02) * edge;
	COLOR = vec4(col, clamp(sun_glow + vignette + dither, 0.0, 1.0));
}
