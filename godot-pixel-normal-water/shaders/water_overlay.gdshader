shader_type canvas_item;
render_mode blend_add, unshaded;

// 水面叠加层：不画倒影本体，只叠加碎光、月影、暖灯倒影闪烁与整格波纹。
// 所有闪烁点都落在 1×1 世界像素网格上；与倒影共用同一份 water mask。

uniform sampler2D u_mask : filter_nearest, repeat_disable;
uniform vec2 u_world_size = vec2(320.0, 180.0);
uniform float u_waterline = 120.0;
uniform float u_time = 0.0;
uniform float u_wave_speed = 1.0;
uniform float u_wave_amplitude = 2.0;
uniform float u_wave_step = 1.0;
uniform float u_lamp_a_x = 113.0;
uniform float u_lamp_b_x = 185.0;
uniform bool u_lamps_on = true;
uniform float u_moon_x = 252.0;

varying vec2 v_world;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 world_uv = v_world / u_world_size;
	if (v_world.y < u_waterline || texture(u_mask, world_uv).a < 0.5) {
		discard;
	}
	float depth = clamp((v_world.y - u_waterline) / (u_world_size.y - u_waterline), 0.0, 1.0);
	float row = floor(v_world.y);
	float step_px = max(u_wave_step, 1.0);
	float phase = sin(row * 0.86 + u_time * u_wave_speed * 1.6) * 0.68
			+ sin(row * 0.31 - u_time * u_wave_speed * 0.90) * 0.32;
	float shift = round(phase * u_wave_amplitude / step_px) * step_px;
	float sx = floor(v_world.x + shift);
	vec3 col = vec3(0.0);

	// 稀疏水面碎光：2px 宽的方格，静止时也在同一像素格内。
	float cell_x = floor(v_world.x * 0.5);
	float sparkle = step(0.995, hash21(vec2(cell_x, row)))
			* (0.35 + 0.65 * depth);
	col += vec3(0.06, 0.15, 0.15) * sparkle;

	// 横向波纹：整行亮带被 quantized shift 平移，像素级一格一格跳动。
	float crest = step(0.947, sin(row * 1.13 + u_time * u_wave_speed * 1.25
			+ floor(sx / 13.0) * 0.80));
	crest *= step(0.58, hash21(vec2(floor(sx / 3.0), row + 11.0)));
	col += vec3(0.022, 0.070, 0.064) * crest * (0.35 + 0.65 * depth);

	// 月光倒影：蓝色月盘在 x=252，水面碎成短横条。
	float moon_center = u_moon_x + shift * 2.0;
	float moon_band = exp(-pow((v_world.x - moon_center) / (5.0 + depth * 13.0), 2.0));
	float moon_gap = step(0.52, hash21(vec2(floor(v_world.x), row + floor(u_time * 1.7))));
	col += vec3(0.56, 0.55, 0.32) * moon_band * moon_gap * 0.11;

	// 暖灯倒影的碎金：两列灯位，按整行断开。
	if (u_lamps_on) {
		for (int i = 0; i < 2; i++) {
			float lamp_x = (i == 0) ? u_lamp_a_x : u_lamp_b_x;
			float dx = v_world.x - lamp_x + shift * 1.2;
			float column = exp(-dx * dx / (9.0 + 20.0 * depth));
			float broken = step(0.61, hash21(vec2(floor(v_world.x), row + float(i) * 7.0)));
			float flick = 0.72 + 0.28 * sin(u_time * 2.5 + row * 0.63 + float(i) * 2.1);
			col += vec3(0.58, 0.25, 0.075) * column * broken * flick * 0.13;
		}
	}

	// 水线附近的一线浅色浪花，只在少数像素出现。
	float edge_row = step(abs(v_world.y - u_waterline), 1.0);
	float edge_gap = step(0.70, hash21(vec2(floor(v_world.x), row + 19.0)));
	col += vec3(0.13, 0.24, 0.22) * edge_row * edge_gap * 0.13;

	COLOR = vec4(col, 1.0);
}
