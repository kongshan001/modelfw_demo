shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque;

#include "res://shaders/garden_common.gdshaderinc"

// 原创浅水池：天空染色 + 菲涅尔反射 + 双频涟漪 + 月光碎闪 + 路灯倒影。
// 不依赖平面反射，保证 Intel/GL Compatibility 的帧率。

uniform vec3 deep_color : source_color = vec3(0.055, 0.13, 0.16);
uniform vec3 shallow_color : source_color = vec3(0.16, 0.30, 0.28);
uniform vec3 stone_rim_color : source_color = vec3(0.24, 0.28, 0.24);
uniform float ripple_strength = 1.0;
uniform float sparkle = 1.0;
uniform float edge_width = 0.10;
uniform vec3 moon_dir = vec3(0.0, 0.7, 0.7);
uniform float moon_strength = 0.0;
uniform vec3 sun_dir = vec3(-0.5, 0.2, -0.8);
uniform float sun_strength = 1.0;
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.62, 0.30);
uniform vec3 lamp_pos[3];
uniform float lamp_energy[3];
uniform int lamp_count = 0;

varying vec3 v_world;
varying vec2 v_uv;
varying float v_dist;

void vertex() {
	vec3 vpos = VERTEX;
	float w1 = sin(vpos.x * 2.2 + g_time * 1.1 + vpos.z * 0.7);
	float w2 = sin(vpos.z * 2.7 - g_time * 0.9 + vpos.x * 0.5);
	vpos.y += (w1 + w2) * 0.006 * ripple_strength;
	v_world = (MODEL_MATRIX * vec4(vpos, 1.0)).xyz;
	v_uv = UV;
	vec4 view_pos = VIEW_MATRIX * vec4(v_world, 1.0);
	v_dist = length(view_pos.xyz);
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	vec2 p = v_world.xz;
	float r = length(v_uv - vec2(0.5)) * 2.0;

	// 双频干涉涟漪，量化为少量台阶，低分辨率下读作手绘波光。
	float a = sin(p.x * 2.3 + g_time * 0.95 + sin(p.y * 1.4) * 1.2);
	float b = sin(p.y * 2.9 - g_time * 0.72 + cos(p.x * 1.6) * 1.1);
	float c = sin((p.x + p.y) * 4.7 - g_time * 1.45);
	float ripple = (a * 0.45 + b * 0.35 + c * 0.20) * 0.5 + 0.5;
	ripple = floor(ripple * 4.0) / 4.0;

	vec3 n = normalize(vec3(
		cos(p.x * 3.7 + g_time * 1.2) * 0.09,
		1.0,
		cos(p.y * 4.1 - g_time * 1.0) * 0.09));
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world);
	float fres = pow(1.0 - clamp(dot(n, view_dir), 0.0, 1.0), 2.2);

	// 深浅水 + 天空反射。
	float shallow_t = smoothstep(0.34, 0.95, r);
	vec3 col = mix(deep_color, shallow_color, shallow_t * 0.72 + ripple * 0.16);
	vec3 sky_ref = mix(g_sky_horizon.rgb, g_sky_mid.rgb, 0.40 + 0.22 * ripple);
	col = mix(col, sky_ref, clamp(0.12 + fres * 0.58, 0.0, 0.74));
	col *= 0.86 + 0.14 * ripple;

	// 天空倒影的波纹断裂。
	float bands = smoothstep(0.55, 0.94, ripple);
	col = mix(col, col * 1.22 + g_sky_mid.rgb * 0.07, bands * 0.65);

	// 日/月倒影：沿反射方向的窄高光，低分辨率下读作一条碎金/碎银光路。
	vec3 refl = reflect(-view_dir, n);
	float moon_spec = pow(max(dot(normalize(refl), normalize(moon_dir)), 0.0), 150.0);
	col += vec3(0.72, 0.84, 1.0) * moon_spec * moon_strength * 1.5;
	float sun_spec = pow(max(dot(normalize(refl), normalize(sun_dir)), 0.0), 110.0);
	col += sun_glow_color.rgb * sun_spec * sun_strength * 1.15;

	// 月光/天光碎闪：稀疏、像素级高光。
	float glint_seed = hash12(floor(p * 22.0) + floor(g_time * 3.0));
	float glint = smoothstep(0.82, 0.99, ripple) * step(0.72, glint_seed);
	glint *= sparkle * (0.25 + 0.75 * g_night);
	col += mix(g_sky_mid.rgb, vec3(0.9, 0.95, 1.0), 0.55) * glint * 0.55;

	// 路灯倒影：柔和椭圆暖斑，路灯点亮时逐盏出现。
	for (int i = 0; i < 3; i++) {
		if (i >= lamp_count) {
			break;
		}
		vec2 d = p - lamp_pos[i].xz;
		d.y *= 0.55;
		float fall = exp(-dot(d, d) * 1.8);
		float ripple_break = 0.65 + 0.35 * sin(d.y * 9.0 + g_time * 2.0);
		col += g_lamp_warmth.rgb * fall * ripple_break * lamp_energy[i] * 0.68;
	}

	// 池沿湿石：内圈压深 + 外圈湿石高光，避免水面像一块平板。
	col = mix(col, deep_color * 0.50, smoothstep(0.93, 1.0, r) * 0.55);
	float edge = smoothstep(1.0 - edge_width, 1.0, r);
	col = mix(col, stone_rim_color * 0.85, edge * 0.55);
	col += g_sky_mid.rgb * smoothstep(0.962, 0.985, r) * 0.22;

	col = garden_fog(col, v_dist);
	ALBEDO = col;
	ALPHA = 0.93;
	ROUGHNESS = 0.18;
	SPECULAR = 0.0;
}
