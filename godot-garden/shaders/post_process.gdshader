shader_type canvas_item;

// 高清场景输出后的轻量后处理：柔光、冷暖分级、暗角。
// 内部 1280×720、线性放大；不做像素对齐/抖动。

uniform float u_night : hint_range(0.0, 1.0) = 0.0;
uniform float u_warm : hint_range(0.0, 1.0) = 0.0;
uniform float u_vignette : hint_range(0.0, 1.0) = 0.2;
uniform float u_bloom : hint_range(0.0, 1.0) = 0.1;
uniform vec2 u_texel = vec2(0.00078125, 0.0013888889);

void fragment() {
	vec3 base = texture(TEXTURE, UV).rgb;

	// 8 邻域亮部柔光
	vec3 bloom = vec3(0.0);
	bloom += max(texture(TEXTURE, UV + vec2(1.6, 0.0) * u_texel).rgb - 0.64, 0.0);
	bloom += max(texture(TEXTURE, UV + vec2(-1.6, 0.0) * u_texel).rgb - 0.64, 0.0);
	bloom += max(texture(TEXTURE, UV + vec2(0.0, 1.6) * u_texel).rgb - 0.64, 0.0);
	bloom += max(texture(TEXTURE, UV + vec2(0.0, -1.6) * u_texel).rgb - 0.64, 0.0);
	bloom += max(texture(TEXTURE, UV + vec2(1.2, 1.2) * u_texel).rgb - 0.64, 0.0);
	bloom += max(texture(TEXTURE, UV + vec2(-1.2, 1.2) * u_texel).rgb - 0.64, 0.0);
	bloom += max(texture(TEXTURE, UV + vec2(1.2, -1.2) * u_texel).rgb - 0.64, 0.0);
	bloom += max(texture(TEXTURE, UV + vec2(-1.2, -1.2) * u_texel).rgb - 0.64, 0.0);
	base += bloom * u_bloom * 0.55;

	// 轻微分级：暖高光/冷阴影交给灯光与环境；这里只做很轻的倾向。
	base = mix(base, base * vec3(1.04, 0.99, 0.92) + vec3(0.006, 0.003, 0.0), u_warm * 0.16);
	base = mix(base, base * vec3(0.9, 0.96, 1.05) + vec3(0.0, 0.002, 0.006), u_night * 0.3);

	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(vec3(luma), base, 1.05);

	vec2 centered = UV - 0.5;
	float edge = smoothstep(0.82, 0.22, length(centered));
	base *= mix(1.0 - u_vignette, 1.0, edge);

	COLOR = vec4(base, 1.0);
}
