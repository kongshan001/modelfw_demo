shader_type canvas_item;
render_mode blend_mix, unshaded;

// 单张倒影 Mesh / 单张图集纹理。
// 顶点已经沿水线做镜像；这里只做三件事：
//   1) 用共享水面 mask 硬裁切；
//   2) 用 round() 把正弦波幅量化到整数像素，水波按整格跳动；
//   3) 压暗树影，同时保留暖窗/灯芯像素（红蓝差 + 亮度）。
// 不依赖 TIME，时间由 GDScript 的 u_time 注入，暂停时真正冻结。

uniform sampler2D u_atlas : filter_nearest, repeat_disable;
uniform sampler2D u_mask : filter_nearest, repeat_disable;
uniform vec2 u_atlas_size = vec2(512.0, 128.0);
uniform vec2 u_world_size = vec2(320.0, 180.0);
uniform float u_waterline = 120.0;
uniform float u_time = 0.0;
uniform float u_wave_speed = 1.0;
uniform float u_wave_amplitude = 2.0;
uniform float u_wave_step = 1.0;
uniform bool u_lamps_on = true;
uniform vec4 u_lamp_uv_a = vec4(0.0);
uniform vec4 u_lamp_uv_b = vec4(0.0);

varying vec2 v_world;

bool inside_rect(vec4 r, vec2 p) {
	return p.x >= r.x && p.x <= r.x + r.z && p.y >= r.y && p.y <= r.y + r.w;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 world_uv = v_world / u_world_size;
	if (v_world.y < u_waterline || texture(u_mask, world_uv).a < 0.5) {
		discard;
	}

	// ── 整格水波 ───────────────────────────────────────────────────────
	// 以世界像素行计算相位，再 round() 到 u_wave_step 的整数倍。
	// 整行偏移，不做平滑缩放；1 像素 = 屏幕上 4/6 个硬边像素。
	float row = floor(v_world.y);
	float phase = sin(row * 0.86 + u_time * u_wave_speed * 1.6) * 0.68
			+ sin(row * 0.31 - u_time * u_wave_speed * 0.90) * 0.32;
	float step_px = max(u_wave_step, 1.0);
	float shift_px = round(phase * u_wave_amplitude / step_px) * step_px;
	vec2 uv = UV + vec2(shift_px / u_atlas_size.x, 0.0);

	// 关灯时，灯本体在倒影图集里的矩形区域一并消失。
	if (!u_lamps_on && (inside_rect(u_lamp_uv_a, UV) || inside_rect(u_lamp_uv_b, UV))) {
		discard;
	}

	vec4 src = texture(u_atlas, uv);
	if (src.a < 0.5) {
		discard;
	}

	float depth = clamp((v_world.y - u_waterline) / (u_world_size.y - u_waterline), 0.0, 1.0);
	float lum = max(src.r, max(src.g, src.b));
	float warm = clamp((src.r - src.b) * 2.2, 0.0, 1.0)
			* smoothstep(0.22, 0.82, lum);

	// 冷色倒影压暗、偏蓝；暖窗/灯笼保留更高透明度与暖调。
	vec3 cool = src.rgb * vec3(0.45, 0.64, 0.78);
	vec3 hot = src.rgb * vec3(1.05, 0.78, 0.50);
	vec3 col = mix(cool, hot, warm);
	col += vec3(0.015, 0.035, 0.045) * (1.0 - warm);
	float alpha = src.a * mix(0.38, 0.68, warm) * (1.0 - 0.30 * depth);

	// 偶发的 1px 断纹，避免整块倒影像镜面贴纸。
	float h = fract(sin(dot(vec2(floor(v_world.x * 0.5), row), vec2(12.9898, 78.233))) * 43758.5453);
	if (h > 0.981) {
		alpha *= 0.78;
	}
	COLOR = vec4(col, alpha);
}
