shader_type canvas_item;

// 屏幕空间风格化后处理。参考 B 站《Shader 如何改变画面的风格》的“同一场景五种风格”：
// 不重做模型/贴图，只对已渲染画面做“降信息 + 改边缘 + 加纹理”。
// 本 shader 只提供两种适合本项目的风格：
//   1 = 卡通渲染：亮度色阶 + 冷色阴影 + 墨线描边
//   2 = 水墨：明暗分层 + 宣纸颗粒 + 朱砂高光 + 墨线
// 像素风/低多边形按既定美术方向不引入；油画 Kuwahara 采样成本高，留作后续。

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform int style_mode : hint_range(0, 2) = 0;
uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;
// canvas_item 着色器没有 SCREEN_PIXEL_SIZE，由脚本按视口尺寸注入。
uniform vec2 screen_pixel_size = vec2(0.000520833, 0.000925926);

// 卡通渲染
uniform float toon_bands : hint_range(2.0, 12.0) = 5.0;
uniform float toon_edge_width : hint_range(0.5, 3.0) = 1.15;
uniform float toon_edge_strength : hint_range(0.0, 1.0) = 0.44;
uniform vec4 toon_outline : source_color = vec4(0.07, 0.05, 0.09, 1.0);
uniform vec4 cool_shadow : source_color = vec4(0.44, 0.60, 0.84, 1.0);

// 水墨
uniform float ink_edge_width : hint_range(0.5, 4.0) = 1.25;
uniform float ink_edge_strength : hint_range(0.0, 1.0) = 0.78;
uniform vec4 ink_paper : source_color = vec4(0.95, 0.92, 0.84, 1.0);
uniform vec4 ink_light : source_color = vec4(0.76, 0.77, 0.72, 1.0);
uniform vec4 ink_mid : source_color = vec4(0.46, 0.48, 0.46, 1.0);
uniform vec4 ink_deep : source_color = vec4(0.10, 0.11, 0.12, 1.0);
uniform vec4 ink_tint : source_color = vec4(0.72, 0.86, 0.88, 1.0);
uniform vec4 cinnabar : source_color = vec4(0.78, 0.17, 0.10, 1.0);
uniform float accent_amount : hint_range(0.0, 1.0) = 0.80;
uniform float grain_amount : hint_range(0.0, 1.0) = 0.06;

// 边缘阈值两种风格共用；水墨会在内部再放宽一点。
uniform float edge_threshold : hint_range(0.0, 0.5) = 0.095;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float sample_luma(vec2 uv) {
	return luma(texture(screen_texture, uv).rgb);
}

float sobel_edge(vec2 uv, vec2 px) {
	float tl = sample_luma(uv + px * vec2(-1.0, -1.0));
	float t = sample_luma(uv + px * vec2(0.0, -1.0));
	float tr = sample_luma(uv + px * vec2(1.0, -1.0));
	float l = sample_luma(uv + px * vec2(-1.0, 0.0));
	float r = sample_luma(uv + px * vec2(1.0, 0.0));
	float bl = sample_luma(uv + px * vec2(-1.0, 1.0));
	float b = sample_luma(uv + px * vec2(0.0, 1.0));
	float br = sample_luma(uv + px * vec2(1.0, 1.0));
	float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
	float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
	return sqrt(gx * gx + gy * gy);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 toon_style(vec3 src, vec2 uv) {
	float l = luma(src);
	// 只量化亮度，保留原色相：给三个通道加同一个偏移。
	float quantized = floor(l * toon_bands + 0.5) / toon_bands;
	vec3 col = src + (quantized - l);

	float l2 = luma(col);
	// 轻微提高饱和度，让色阶边界更像手绘赛璐璐。
	col = mix(vec3(l2), col, 1.06);

	// 暗部偏冷，亮部偏暖。
	float shadow = smoothstep(0.60, 0.10, l2);
	col = mix(col, col * cool_shadow.rgb * 1.45, shadow * 0.26);
	float highlight = smoothstep(0.72, 1.0, l2);
	col = mix(col, col * vec3(1.08, 1.03, 0.94), highlight * 0.40);

	// 亮度 Sobel 描边。阈值抬高，避免草地细节被描成噪点。
	float e = sobel_edge(uv, screen_pixel_size * toon_edge_width);
	float edge = smoothstep(edge_threshold + 0.02, edge_threshold + 0.22, e);
	col = mix(col, toon_outline.rgb, edge * toon_edge_strength);
	return col;
}

// 五档墨色：纸白 → 淡墨 → 中墨 → 重墨。
vec3 ink_tone(float l) {
	if (l < 0.28) {
		return mix(ink_paper.rgb, ink_light.rgb, smoothstep(0.0, 0.28, l));
	}
	if (l < 0.58) {
		return mix(ink_light.rgb, ink_mid.rgb, smoothstep(0.28, 0.58, l));
	}
	return mix(ink_mid.rgb, ink_deep.rgb, smoothstep(0.58, 1.0, l));
}

vec3 ink_style(vec3 src, vec2 uv) {
	// 提亮中间调，避免整张画压成灰泥；再量化成五档，保留“墨分五色”的分层。
	float l = pow(clamp(luma(src), 0.0, 1.0), 0.85);
	float tone = floor(l * 5.0 + 0.5) / 5.0;
	vec3 col = ink_tone(tone);

	// 暗部/远处压一点冷青，模拟“远山淡、近山浓”。
	col = mix(col, col * ink_tint.rgb, (1.0 - l) * 0.30);

	// 朱砂点：只取画面上方“极亮且偏暖”的太阳本体，避免整条天空变红。
	float warmth = smoothstep(0.12, 0.22, src.r - src.b);
	float bright = smoothstep(0.86, 0.96, luma(src));
	float sky = smoothstep(0.62, 0.30, uv.y);
	float accent = warmth * bright * sky;
	col = mix(col, cinnabar.rgb, accent * accent_amount);

	// 墨线：比卡通更宽、更重。
	float e = sobel_edge(uv, screen_pixel_size * ink_edge_width);
	float edge = smoothstep(edge_threshold * 0.90, edge_threshold + 0.18, e);
	col = mix(col, ink_deep.rgb * 0.55, edge * ink_edge_strength);

	// 宣纸颗粒 + 纤维：静态噪声，避免逐帧闪烁。
	float grain = hash12(uv * vec2(1920.0, 1080.0));
	float fiber = sin((uv.x * 1920.0 + uv.y * 6.0) * 0.35) * 0.5 + 0.5;
	col *= 1.0 - grain_amount * (grain - 0.5) * 2.0;
	col += (fiber - 0.5) * grain_amount * 0.06;

	// 轻微暗角，收住画面边缘。
	float vig = smoothstep(1.10, 0.35, length(uv - vec2(0.5)));
	col *= mix(0.90, 1.0, vig);
	return col;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 src = texture(screen_texture, uv).rgb;
	vec3 styled = src;

	if (style_mode == 1) {
		styled = toon_style(src, uv);
	} else if (style_mode == 2) {
		styled = ink_style(src, uv);
	}

	float strength = style_mode == 0 ? 0.0 : clamp(effect_strength, 0.0, 1.0);
	vec3 out_col = mix(src, styled, strength);
	COLOR = vec4(clamp(out_col, vec3(0.0), vec3(1.0)), 1.0);
}
