shader_type canvas_item;

#include "res://shaders/common.gdshaderinc"

// 低分辨率合成后期（CompositeViewport 内）：
// 采样 WorldViewport 的最终 3D 纹理（含水/折射）→ 亮度/色度描边 →
// 调色 → Bayer 抖动 → 色阶/调色板量化；附带调试视图直通。
// 为什么用 canvas_item：GL Compatibility 下 3D 内屏幕纹理后期的 backbuffer
// 拷贝会早于水面绘制；独立合成 viewport 能拿到完整的世界纹理。
uniform sampler2D world_tex : filter_nearest, repeat_disable;

uniform float levels = 12.0;
uniform float dither = 0.2;
uniform float outline = 1.0;
uniform float palette_on = 0.0;
uniform float debug_mode = 0.0;
uniform float exposure = 0.98;
uniform float saturation = 1.06;
uniform float lift = 0.008;
uniform vec4 outline_color : source_color = vec4(0.045, 0.09, 0.1, 1.0);

void fragment() {
	vec2 px = 1.0 / vec2(g_res_x, g_res_y);
	vec2 uv = UV;
	vec3 raw = texture(world_tex, uv).rgb;
	vec3 col = raw;

	// 屏幕颜色边缘：亮度差 + 色度差，1 像素宽。
	float de = 0.0;
	float edge_raw = 0.0;
	if (outline > 0.001) {
		vec3 cl = texture(world_tex, uv - vec2(px.x, 0.0)).rgb;
		vec3 cr = texture(world_tex, uv + vec2(px.x, 0.0)).rgb;
		vec3 cu = texture(world_tex, uv - vec2(0.0, px.y)).rgb;
		vec3 cd = texture(world_tex, uv + vec2(0.0, px.y)).rgb;
		float l0 = luma(raw);
		float lmax = max(abs(luma(cl) - l0), max(abs(luma(cr) - l0), max(abs(luma(cu) - l0), abs(luma(cd) - l0))));
		float cmax = max(length(cl - raw), max(length(cr - raw), max(length(cu - raw), length(cd - raw))));
		edge_raw = max(lmax, cmax * 0.2);
		de = smoothstep(0.11, 0.34, edge_raw);
	}

	if (debug_mode > 0.5 && debug_mode < 1.5) {
		// 1 = 低分辨率 RT 原始像素
		col = raw;
	} else if (debug_mode > 1.5 && debug_mode < 3.5) {
		// 2 = 深度覆盖 / 3 = 法线覆盖：材质已由 GDScript 替换，这里直通。
		col = raw;
	} else if (debug_mode > 3.5 && debug_mode < 4.5) {
		// 4 = 描边 mask
		vec3 edge_col = vec3(0.03, 0.065, 0.08);
		float de_show = smoothstep(0.04, 0.22, edge_raw);
		edge_col = mix(edge_col, vec3(0.92, 0.96, 0.88), clamp(de_show * outline, 0.0, 1.0));
		col = edge_col;
	} else if (debug_mode > 4.5) {
		// 5 = 水面 Mask（水面 shader 输出 mask，后期直通）
		col = raw;
	} else {
		vec3 c = raw;

		// 描边压暗
		c = mix(c, outline_color.rgb, clamp(de * outline, 0.0, 1.0) * 0.7);

		// 调色：提亮、轻微去饱和、柔和高光
		c = clamp(c * exposure + lift, 0.0, 1.0);
		float l = luma(c);
		c = mix(vec3(l), c, saturation);
		c = mix(c, c * c * (3.0 - 2.0 * c), 0.14);

		// 水下整体色罩（场景 shader 已有距离雾，这里补一层统一水色）
		c = mix(c, g_fog_color.rgb, clamp(g_underwater, 0.0, 1.0) * 0.16);

		// 水下光柱：屏幕空间柔光带，叠在 3D 光柱之上。
		if (g_underwater > 0.01) {
			float bands = 0.5 + 0.5 * sin(uv.x * 37.0 + g_time * 0.22);
			bands *= 0.55 + 0.45 * sin(uv.x * 13.0 - g_time * 0.09 + 1.7);
			float rays = smoothstep(0.62, 0.98, bands) * smoothstep(1.02, 0.05, uv.y);
			c += vec3(0.4, 0.72, 0.72) * rays * g_underwater * 0.14;
		}

		// 雨：屏幕空间像素竖线
		if (g_rain > 0.01) {
			float col_id = floor(FRAGCOORD.x);
			float seed = hash12(vec2(col_id, 7.3));
			float fall = fract(uv.y * 1.25 + g_time * 2.4 + seed * 3.7);
			float streak = smoothstep(0.72, 0.96, fall) * step(0.45, seed);
			c += vec3(0.62, 0.78, 0.85) * streak * g_rain * 0.24;
		}

		// 轻微暗角
		vec2 q = uv - vec2(0.5);
		c *= 1.0 - dot(q, q) * 0.16;

		// Bayer 抖动 + 轻噪声，再做色阶或调色板量化
		float th = bayer4(FRAGCOORD.xy) * dither * 0.7 + (hash12(FRAGCOORD.xy * 1.37 + g_time * 0.13) - 0.5) * dither * 0.65;
		if (palette_on > 0.5) {
			// 亮度/色度分离的 36 色量化
			float y = luma(c);
			vec3 chroma = c - vec3(y);
			float lv = 6.0;
			y = floor(clamp(y, 0.0, 1.0) * (lv - 1.0) + th + 0.5) / (lv - 1.0);
			chroma = floor(clamp(chroma, -0.5, 0.5) * 5.0 + th * 0.7 + 0.5) / 5.0;
			c = clamp(vec3(y) + chroma, 0.0, 1.0);
		} else {
			float lv = max(2.0, levels);
			c = floor(clamp(c, 0.0, 1.0) * (lv - 1.0) + th + 0.5) / (lv - 1.0);
			c = clamp(c, 0.0, 1.0);
		}
		col = c;
	}

	COLOR = vec4(col, 1.0);
}
