shader_type canvas_item;
render_mode unshaded, blend_mix;

// 积水合成层：湿草压暗 + 水色 + 水际高光 + 倒影裁切 + 雨点闪光。
// 一帧一层、一次绘制；倒影是离线烘好的镜像图集，不是实时反射。

uniform sampler2D u_field : filter_nearest, repeat_disable;
uniform sampler2D u_reflection : filter_nearest, repeat_disable;
uniform float u_waterline = 0.32;
uniform float u_wet = 0.0;
uniform float u_rain = 0.0;
uniform float u_time = 0.0;
uniform float u_reflection_on = 1.0;
uniform vec3 u_deep : source_color = vec3(0.052, 0.180, 0.196);
uniform vec3 u_shallow : source_color = vec3(0.098, 0.305, 0.310);
uniform vec3 u_rim : source_color = vec3(0.620, 0.870, 0.810);
uniform vec3 u_damp : source_color = vec3(0.060, 0.115, 0.100);

#include "res://shaders/water_mask.gdshaderinc"

float rp_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec4 f = texture(u_field, uv);
	float depth = rp_depth(f, u_waterline);
	float water = rp_water_mask(f, u_waterline);
	float damp = rp_damp_mask(f, u_waterline);
	float d01 = clamp(depth * 7.0, 0.0, 1.0);

	vec3 col = vec3(0.0);
	float alpha = 0.0;

	// 水面本体：深处更蓝，浅处偏青；稳定 texel 噪声避免闪烁。
	vec3 water_col = mix(u_shallow, u_deep, smoothstep(0.02, 0.80, d01));
	vec2 texel = floor(uv * vec2(320.0, 180.0));
	float stipple = rp_hash(texel) - 0.5;
	water_col += vec3(0.014, 0.020, 0.018) * stipple * (0.35 + 0.65 * d01);
	float band = sin(uv.y * 210.0 + sin(uv.x * 64.0 + u_time * 0.7) * 1.4 + u_time * 1.6);
	water_col += vec3(0.010, 0.018, 0.016) * band * (0.30 + 0.70 * d01);

	// 倒影：统一由 puddle mask 裁切；向内收 1 texel，避免干像素漏光。
	if (u_reflection_on > 0.5 && water > 0.001) {
		vec2 ruv = uv;
		float wob = sin(uv.y * 92.0 + u_time * 2.3)
				+ sin(uv.x * 37.0 - u_time * 1.15) * 0.7;
		ruv.x += wob * 0.0030 * (0.30 + 0.70 * d01);
		ruv.y += sin(uv.x * 61.0 + u_time * 1.45) * 0.0016;
		// 吸附到世界像素网格，保持倒影的像素块感。
		ruv = floor(ruv * vec2(640.0, 360.0)) / vec2(640.0, 360.0);
		vec3 refl = texture(u_reflection, ruv).rgb;
		// 压一点饱和度并偏冷：红枫不会变成一团火，松树/暖灯仍然可读。
		float lum = dot(refl, vec3(0.299, 0.587, 0.114));
		refl = mix(vec3(lum), refl, 0.56) * vec3(0.88, 0.98, 1.0);
		float refl_amt = mix(0.18, 0.64, smoothstep(0.0, 0.62, d01));
		water_col = mix(water_col, refl * 0.92 + water_col * 0.42, refl_amt);
	}

	// 极细水际高光：只在贴边的一两像素内。
	float rim = smoothstep(0.020, 0.0, depth) * smoothstep(0.0, 0.0025, depth);
	water_col = mix(water_col, u_rim, rim * 0.64);
	float sheen = sin(uv.y * 320.0 + sin(uv.x * 90.0 + u_time * 0.9) * 2.2 + u_time * 2.1);
	water_col += vec3(0.012, 0.020, 0.018) * sheen * (0.25 + 0.75 * d01);

	// 雨滴落在水面的白点，随雨强增加。
	float sparkle = step(0.9982, rp_hash(texel + floor(u_time * 13.0) * 17.0));
	water_col += vec3(0.52, 0.66, 0.63) * sparkle * u_rain * (0.30 + 0.70 * d01);

	col = water_col;
	alpha = water * (0.74 + 0.20 * d01);

	// 水洼外的湿边：压暗草色，让边缘可读但不产生硬方块。
	float outer = damp * (1.0 - water);
	col = mix(col, u_damp, outer * 0.30);
	alpha = max(alpha, outer * 0.20);
	alpha = max(alpha, u_wet * 0.030 * (1.0 - water));

	COLOR = vec4(col, alpha);
}
