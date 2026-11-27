shader_type canvas_item;

#include "res://shaders/garden_common.gdshaderinc"

// 低分辨率合成后期（在独立 Canvas Viewport 内）：
// 饱和度/曝光 → 夜色色罩 → 柔和暗角 → Bayer 抖动 + 色阶量化。
// T-008 再补像素偏移补偿/稳定化、描边与更完整的光束。

uniform sampler2D world_tex : filter_nearest, repeat_disable;
uniform float levels = 20.0;
uniform float dither = 0.20;
uniform float exposure = 1.0;
uniform float saturation = 1.06;
uniform float vignette = 0.20;
uniform float tint_strength = 0.0;
uniform vec4 tint_color : source_color = vec4(0.32, 0.42, 0.72, 1.0);
uniform float clarity = 0.05;
uniform vec2 godray_pos = vec2(0.5, 0.5);
uniform float godray_strength = 0.0;
uniform vec4 godray_color : source_color = vec4(1.0, 0.70, 0.40, 1.0);

void fragment() {
	vec2 uv = UV;
	vec3 c = texture(world_tex, uv).rgb;
	c *= exposure;
	float l = luma3(c);
	c = mix(vec3(l), c, saturation);
	c = mix(c, tint_color.rgb, tint_strength);
	c = mix(c, c * c * (3.0 - 2.0 * c), clarity);
	// 屏幕空间丁达尔：朝日/月盘方向 14 次径向采样，只取高光，低分辨率下自然颗粒化。
	if (godray_strength > 0.001) {
		vec2 stepv = (uv - godray_pos) * 0.062;
		vec2 suv = uv;
		float decay = 1.0;
		float gr = 0.0;
		for (int i = 0; i < 14; i++) {
			suv -= stepv;
			vec3 s = texture(world_tex, clamp(suv, vec2(0.002), vec2(0.998))).rgb;
			gr += max(0.0, luma3(s) - 0.60) * decay;
			decay *= 0.93;
		}
		c += godray_color.rgb * (gr / 7.0) * godray_strength;
	}
	vec2 q = uv - vec2(0.5);
	c *= 1.0 - dot(q, q) * vignette;
	// 细碎噪声打散色带，再由色阶量化统一。
	float th = bayer4(FRAGCOORD.xy) * dither
		+ (hash12(FRAGCOORD.xy * 0.73 + g_time * 0.11) - 0.5) * dither * 0.55;
	float lv = max(levels, 4.0);
	c = floor(clamp(c, 0.0, 1.0) * lv + th + 0.5) / lv;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
