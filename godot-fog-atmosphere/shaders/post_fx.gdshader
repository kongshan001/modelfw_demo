shader_type canvas_item;
// 单 pass 屏幕后处理：径向 god rays（围绕月光/灯光屏幕位置）+ 轻色调 + 暗角 + 抖动。
// GL Compatibility 可用（screen texture 采样）；未使用 depth texture。
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform vec2 light_uv = vec2(0.5, 0.32);
uniform float ray_strength = 0.0;
uniform vec4 ray_color : source_color = vec4(1.0, 0.94, 0.82, 1.0);
uniform float vignette_strength = 0.30;
uniform float grain_amount = 0.010;
uniform float haze_tint = 0.03;
uniform vec2 resolution = vec2(1280.0, 720.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	if (ray_strength > 0.001) {
		vec2 delta = (SCREEN_UV - light_uv) * 0.125;
		vec2 uv = SCREEN_UV;
		vec3 rays = vec3(0.0);
		float weight = 1.0;
		float weight_sum = 0.0;
		for (int i = 0; i < 8; i++) {
			uv -= delta;
			vec3 s = texture(screen_tex, uv).rgb;
			float lum = dot(s, vec3(0.299, 0.587, 0.114));
			rays += s * smoothstep(0.42, 0.95, lum) * weight;
			weight_sum += weight;
			weight *= 0.86;
		}
		rays /= max(weight_sum, 0.001);
		col += rays * ray_strength * ray_color.rgb;
	}

	// 轻微分级：亮部偏暖、暗部偏冷
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, col * vec3(1.055, 1.0, 0.935), 0.60 * smoothstep(0.30, 1.0, lum));
	col = mix(col, col * vec3(0.95, 1.0, 1.045), haze_tint * 3.0 * smoothstep(0.28, 0.0, lum));

	// 暗角
	vec2 q = (SCREEN_UV - 0.5) * vec2(1.15, 1.0);
	float vig = smoothstep(0.82, 0.22, length(q));
	col *= mix(1.0 - vignette_strength, 1.0, vig);

	// 细颗粒 / 抖动，减轻渐变带
	float g = hash12(SCREEN_UV * resolution + fract(TIME) * 53.0) - 0.5;
	col += g * grain_amount;

	COLOR = vec4(col, 1.0);
}
