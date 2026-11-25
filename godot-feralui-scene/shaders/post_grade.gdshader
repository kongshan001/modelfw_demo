shader_type canvas_item;
// 极轻的屏幕校色：抬冷阴影、暖高光、暗角与细颗粒。UI 在其上，不受影响。
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float nightness = 1.0;
uniform float rain_amount = 0.0;
uniform float u_time = 0.0;
uniform float vignette_strength = 0.28;
uniform float grain_strength = 0.008;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));

	// 夜色：阴影偏靛，高光偏蜜色；雨色略降饱和。
	vec3 cool_lift = vec3(0.006, 0.010, 0.024) * nightness;
	vec3 warm_highlight = vec3(0.016, 0.010, 0.002) * (1.0 - rain_amount * 0.4);
	c += cool_lift * (1.0 - luma) + warm_highlight * luma;

	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(grey), 0.025 + rain_amount * 0.055);
	c = (c - vec3(0.5)) * 1.035 + vec3(0.5);

	vec2 q = SCREEN_UV - vec2(0.5);
	q.x *= 1.12;
	float vig = smoothstep(0.94, 0.24, length(q) * 1.22);
	c *= mix(1.0, vig, vignette_strength);

	float g = hash(SCREEN_UV * vec2(1920.0, 1080.0) + fract(u_time) * 31.0) - 0.5;
	c += g * grain_strength;

	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
