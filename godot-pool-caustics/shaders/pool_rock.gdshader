shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// 圆石：手绘式三阶明暗 + 湿面高光 + 苔痕；焦散直接投影到世界 XZ，
// 因此同一张光网会自然地爬上石面。池底与圆石共用 caustics.gdshaderinc。

#include "res://shaders/caustics.gdshaderinc"

uniform vec3 u_rock_light : source_color = vec3(0.29, 0.43, 0.39);
uniform vec3 u_rock_dark : source_color = vec3(0.035, 0.085, 0.082);
uniform vec3 u_moss_color : source_color = vec3(0.25, 0.38, 0.24);
uniform float u_moss_amount = 0.65;
uniform float u_caustic_amount = 1.0;
uniform float u_wet_spec = 0.28;
uniform float u_rim = 0.20;
uniform float u_light_wrap = 0.10;

varying vec3 v_world;
varying vec3 v_normal_world;
varying float v_local_y;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	v_local_y = VERTEX.y;
}

void fragment() {
	vec3 N = normalize(v_normal_world);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_world);
	vec3 L = normalize(vec3(-0.46, 0.80, 0.34));

	float ndl = clamp(dot(N, L), 0.0, 1.0);
	float wrap = clamp((dot(N, L) + u_light_wrap) / (1.0 + u_light_wrap), 0.0, 1.0);
	float sky = clamp(N.y * 0.5 + 0.5, 0.0, 1.0);
	float contact = smoothstep(-1.0, 0.28, v_local_y);

	// 低频色斑 + 苔藓只长在上表面；石缝保留深色。
	float mott = caustic_noise(v_world.xz * 1.55 + vec2(3.1, -1.7));
	float mott2 = caustic_noise(v_world.xz * 4.3 - vec2(6.2, 2.4));
	float moss_mask = smoothstep(0.44, 0.76, 0.58 * mott + 0.42 * mott2)
			* smoothstep(0.10, 0.78, N.y) * u_moss_amount;

	vec3 base = mix(u_rock_dark, u_rock_light, 0.10 + 0.90 * wrap);
	base *= 0.34 + 0.66 * sky;
	base *= mix(0.66, 1.12, mott);
	base = mix(base, u_moss_color, moss_mask * 0.78);
	base *= 0.42 + 0.58 * contact;
	base += u_rock_light * pow(clamp(N.y, 0.0, 1.0), 1.5) * 0.24;
	base += vec3(0.10, 0.16, 0.145) * pow(ndl, 1.5) * 0.30;

	// 湿石高光：略偏蓝绿，避免变成塑料。
	vec3 H = normalize(L + V);
	float spec = pow(clamp(dot(N, H), 0.0, 1.0), 24.0);
	base += vec3(0.44, 0.66, 0.61) * spec * u_wet_spec * (0.4 + 0.6 * contact);

	// 焦散投影：沿法线稍微偏移，让光网在侧面也有连续感。
	vec2 caustic_p = v_world.xz + N.xz * 0.56 + vec2(v_world.y * 0.09, 0.0);
	CausticField c = caustic_fields(caustic_p, u_time);

	float caustic_gain = u_caustic_amount * (0.18 + 0.82 * sky) * (0.34 + 0.66 * contact);
	vec3 lit = caustic_light(c) * caustic_gain;

	// 轮廓光 + 上缘微光。用视线方向而不是物理光，保持低多边形风格。
	float rim = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 3.0);
	vec3 rim_col = mix(vec3(0.18, 0.42, 0.39), u_line_color.rgb * 0.55, 0.45);
	base += rim_col * rim * u_rim;

	vec3 col;
	if (u_debug == 0) {
		col = base + lit;
	} else {
		col = caustic_composite(c, base);
	}

	float dither = (caustic_hash12(FRAGCOORD.xy + 7.1) - 0.5) * 0.006;
	ALBEDO = max(col + dither, vec3(0.0));
}
