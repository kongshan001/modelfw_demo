shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded, fog_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

// 风格化水面：屏幕采样折射 + 解析深浅色阶 + 岛/岩/涟漪泡沫 + 白色碎光。
// 深度缓冲在 GL Compatibility 的 SubViewport 中不可用，因此水体深浅由
// 解析场（field.r）驱动，泡沫由岸线场 + 岩石位置 + 鱼群涟漪事件驱动。
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D field_tex : filter_linear, repeat_disable;

uniform vec4 shallow_color : source_color = vec4(0.6, 0.93, 0.89, 1.0);
uniform vec4 deep_color : source_color = vec4(0.2, 0.58, 0.7, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.99, 0.97, 1.0);
uniform vec4 sky_color : source_color = vec4(0.68, 0.86, 0.92, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.97, 0.86, 1.0);

uniform float clarity = 0.5;
uniform float depth_dark = 0.35;
uniform float refraction = 0.4;
uniform float foam = 1.0;
uniform float flow = 0.6;
uniform float rain_amount = 0.0;
uniform float debug_mask = 0.0;
uniform vec2 sun_xz = vec2(0.33, 0.47);
uniform vec2 field_origin = vec2(-15.0, -11.0);
uniform vec2 field_size = vec2(30.0, 22.0);

uniform vec2 ripple_pos[8];
uniform float ripple_birth[8];
uniform float ripple_amp[8];

uniform vec2 rock_pos[8];
uniform float rock_radius[8];
uniform float rock_count = 0.0;

uniform vec2 fish_pos[12];
uniform float fish_count = 0.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	POSITION = snap_clip(PROJECTION_MATRIX * VIEW_MATRIX * vec4(v_world, 1.0));
}

void fragment() {
	vec2 fuv = (v_world.xz - field_origin) / field_size;
	vec4 field = texture(field_tex, fuv);
	if (field.a < 0.45) {
		discard;
	}

	vec3 out_col = vec3(0.08, 0.42, 0.62);
	if (debug_mask > 0.5) {
		out_col = field.a > 0.5 ? vec3(0.08, 0.42, 0.62) : vec3(0.2);
	} else {
		vec2 p = v_world.xz;
		float t = g_time * (0.7 + flow);
		float depth01 = clamp(field.r + (value_noise(p * 0.33) - 0.5) * 0.06, 0.0, 1.0);
		float shore_dist = (1.0 - field.g) * 4.0;
		float shore_shallow = 1.0 - smoothstep(0.0, 1.5, shore_dist);

		// 规则波纹 + 鱼/雨点扩散环
		vec2 rip = vec2(
			sin(p.x * 1.9 + t * 1.15) * cos(p.y * 1.45 - t * 0.7),
			sin(p.y * 2.25 + t * 0.85) * cos(p.x * 1.6 + t * 0.55));
		rip += vec2(sin((p.x + p.y) * 3.1 + t * 1.4), cos((p.x - p.y) * 2.7 - t * 1.1)) * 0.35;
		float ring_foam = 0.0;
		for (int i = 0; i < 8; i++) {
			float age = g_time - ripple_birth[i];
			if (age > 0.0 && age < 2.8 && ripple_amp[i] > 0.001) {
				vec2 dp = p - ripple_pos[i];
				float r = length(dp);
				float wavefront = age * 1.05;
				float ring = sin((r - wavefront) * 28.0) * exp(-abs(r - wavefront) * 7.0) * exp(-age * 1.35);
				rip += normalize(dp + vec2(0.001)) * ring * 0.22 * ripple_amp[i];
				ring_foam = max(ring_foam, ring * 0.3);
			}
		}
		if (rain_amount > 0.01) {
			vec2 cell_p = floor(p * 2.0);
			float h = hash12(cell_p + 3.7);
			float phase = fract(g_time * 0.55 + h);
			vec2 c = (cell_p + vec2(hash12(cell_p + 1.3), hash12(cell_p + 8.1))) / 2.0;
			float r = length(p - c);
			float wf = phase * 0.5;
			float ring = sin((r - wf) * 34.0) * exp(-abs(r - wf) * 20.0) * (1.0 - phase);
			rip += normalize(p - c + vec2(0.001)) * ring * 0.16 * rain_amount;
			ring_foam = max(ring_foam, ring * 0.45 * rain_amount);
		}

		vec2 suv = SCREEN_UV + rip * refraction * 0.0042 * (0.55 + depth01);
		vec3 behind = texture(screen_tex, suv).rgb;

		vec3 deep = deep_color.rgb * mix(1.0, 0.72, depth_dark);
		vec3 water_col = mix(shallow_color.rgb, deep, smoothstep(0.02, 0.95, depth01) * (1.0 - shore_shallow * 0.6));
		water_col = mix(water_col, sky_color.rgb, 0.08);
		water_col *= 0.91 + 0.18 * value_noise(p * 0.42 + vec2(g_time * 0.01));
		// 水面焦散光网（轻量、量化后形成色块）
		float ca = caustic_pattern(p * 1.25, g_time) * (0.35 + depth01 * 0.65);
		ca = floor(ca * 3.0) / 3.0;
		water_col += vec3(0.35, 0.6, 0.55) * ca * 0.12;
		// 近岸更清、深水更乳浊；清澈度越高越能看见水底/鱼。
		float tint = mix(0.34, 0.62, smoothstep(0.02, 0.95, depth01));
		tint *= mix(1.05, 0.84, clarity);
		tint *= (1.0 - shore_shallow * 0.28);
		// 鱼身附近水更清，形成通透的小窗口（风格化）。
		float fish_clear = 0.0;
		for (int i = 0; i < 12; i++) {
			if (float(i) < fish_count) {
				float fd = length(p - fish_pos[i]);
				fish_clear = max(fish_clear, 1.0 - smoothstep(0.12, 0.7, fd));
			}
		}
		tint *= 1.0 - fish_clear * 0.4;
		vec3 col = mix(behind, water_col, clamp(tint, 0.0, 0.92));
		col += vec3(0.05, 0.12, 0.11) * fish_clear;

		// 菲涅尔天空色
		float fres = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 3.0);
		col = mix(col, sky_color.rgb, fres * 0.28);

		// 岛影：将陆地 mask 沿太阳反方向偏移。
		vec2 sun_len = normalize(sun_xz + vec2(0.0001));
		vec4 shadow_field = texture(field_tex, ((p - sun_len * 1.15) - field_origin) / field_size);
		col *= 1.0 - shadow_field.b * 0.15;

		// 白色碎光：非常稀疏的短划线
		vec2 sc = floor(p * vec2(9.0, 15.0));
		float sh = hash12(sc + floor(g_time * 1.1));
		float spark = step(0.985, sh);
		spark *= smoothstep(0.35, 0.8, sin(p.x * 58.0 + g_time * 2.4 + sc.y * 2.3));
		col += sun_color.rgb * spark * 0.3;

		// 泡沫：岸线 + 岩石 + 涟漪，虚线化。
		float shore_ring = 1.0 - smoothstep(0.0, 0.1, field.g);
		float f = clamp(shore_ring * 0.75 + ring_foam * 0.35, 0.0, 1.0);
		for (int i = 0; i < 8; i++) {
			if (float(i) < rock_count) {
				float d = length(p - rock_pos[i]) - rock_radius[i];
				float ring = 1.0 - smoothstep(0.01, 0.16, d);
				f = max(f, ring * 0.9);
			}
		}
		float dash = 0.5 + 0.5 * sin((p.x + p.y) * 16.0 + sin(p.x * 4.0) * 1.7 + t * 0.25);
		float foam_mask = f * (0.55 + 0.45 * smoothstep(0.18, 0.6, dash));
		foam_mask += step(0.94, hash12(floor(p * 26.0) + floor(g_time * 0.3))) * f * 0.25;
		foam_mask = floor(clamp(foam_mask * foam, 0.0, 1.0) * 2.0 + bayer4(FRAGCOORD.xy) * 0.5 + 0.5) / 2.0;
		col = mix(col, foam_color.rgb, clamp(foam_mask, 0.0, 1.0));

		// 水下仰视：明亮顶棚
		float uw = smoothstep(0.0, 0.4, g_underwater);
		if (uw > 0.001) {
			float look = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
			vec3 ceiling = mix(vec3(0.22, 0.62, 0.68), vec3(0.9, 1.0, 0.98), smoothstep(0.45, 0.98, look));
			ceiling += sun_color.rgb * pow(look, 6.0) * 0.4;
			col = mix(col, ceiling, 0.5 * uw);
		}

		out_col = col;
	}
	ALBEDO = out_col;
	ALPHA = 1.0;
}
