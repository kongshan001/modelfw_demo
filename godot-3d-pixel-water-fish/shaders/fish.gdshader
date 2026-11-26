shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

#include "res://shaders/common.gdshaderinc"

// 原创低模鱼：顶点级身体/尾巴摆动 + 量化受光 + 轻微水下焦散。
// 网格沿本地 -Z 为头、+Z 为尾；每条鱼通过 instance uniform 注入相位/速度/弯曲。
instance uniform float swim_phase = 0.0;
instance uniform float swim_speed = 3.0;
instance uniform float swim_bend = 0.09;
instance uniform float body_len = 0.5;

uniform float fin_sway = 0.045;
uniform float caustic_amount = 0.3;
uniform vec4 belly_tint : source_color = vec4(0.95, 0.92, 0.82, 1.0);

varying vec3 v_world;
varying float v_dist;
varying float v_t;

void vertex() {
	vec3 vpos = VERTEX;
	float t = clamp(vpos.z / max(body_len, 0.001) + 0.5, 0.0, 1.0);
	float wave = sin(g_time * swim_speed - t * 3.4 + swim_phase);
	float bend = swim_bend * (0.04 + t * t);
	float lateral = wave * bend * body_len;
	// 尾巴横向摆 + 轻微偏航，让轮廓在俯视下也能读出来。
	vpos.x += lateral;
	float yaw = wave * swim_bend * 0.65 * t;
	float cy = cos(yaw);
	float sy = sin(yaw);
	vpos.xz = mat2(vec2(cy, -sy), vec2(sy, cy)) * vpos.xz;
	// 胸鳍抖一下
	vpos.y += sin(g_time * swim_speed * 0.7 + swim_phase + vpos.z * 9.0) * fin_sway * (1.0 - t) * 0.35;
	v_t = t;
	v_world = (MODEL_MATRIX * vec4(vpos, 1.0)).xyz;
	vec4 view_pos = VIEW_MATRIX * vec4(v_world, 1.0);
	v_dist = length(view_pos.xyz);
	POSITION = snap_clip(PROJECTION_MATRIX * view_pos);
}

void fragment() {
	vec3 base = COLOR.rgb;
	// 腹部提亮，保留低模分面。
	base = mix(base, belly_tint.rgb, clamp(0.25 - v_t * 0.2, 0.0, 0.25) * 0.5);
	float under = smoothstep(0.02, 0.35, -v_world.y);
	float ca = caustic_pattern(v_world.xz * 1.3, g_time) * caustic_amount * g_caustics * under;
	ca = floor(ca * 2.0) / 2.0;
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.4);
	base = mix(base, base * 0.48, rim * 0.55);
	base = mix(base, vec3(0.045, 0.09, 0.095), smoothstep(0.55, 0.95, rim) * 0.85);
	base += vec3(0.35, 0.55, 0.5) * rim * 0.1;
	base += COLOR.rgb * 0.34;
	EMISSION = ca * vec3(0.65, 0.95, 0.85) * 0.18;
	base = fog_mix(base, v_dist);
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT)) * 0.5 + 0.5;
	float steps = max(g_light_steps, 2.0);
	float band = floor(clamp(ndl, 0.0, 1.0) * steps) / (steps - 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * clamp(band, 0.0, 1.0);
}
