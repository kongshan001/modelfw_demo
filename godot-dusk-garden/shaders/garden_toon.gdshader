shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

#include "res://shaders/garden_common.gdshaderinc"

// 原创低模材质：三阶受光 + 世界空间云影 + 风摆 + 边缘光 + 苔藓 + 手工距离雾。
// 所有石/木/金属/叶片共用，颜色与参数由 GDScript 每类材质注入。

uniform vec4 tint : source_color = vec4(1.0);
uniform float bands = 3.0;
uniform float gain = 1.0;
uniform vec3 rim_color : source_color = vec3(0.62, 0.72, 0.78);
uniform float rim_amount = 0.10;
uniform float moss_amount = 0.0;
uniform vec3 moss_color : source_color = vec3(0.24, 0.34, 0.19);
uniform float sway_amount = 0.0;
uniform float sway_ref = 1.0;
uniform float sway_speed = 1.0;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_amount = 0.0;
uniform float cloud_amount = 1.0;
uniform float grain_amount = 0.10;
uniform float faceted = 0.0;

varying vec3 v_world;
varying vec3 v_normal_world;
varying vec3 v_color;
varying float v_dist;

void vertex() {
	vec3 vpos = VERTEX;
	v_color = COLOR.rgb;
	if (sway_amount > 0.0001) {
		float h = clamp(vpos.y / max(sway_ref, 0.001), 0.0, 1.0);
		vec3 origin = MODEL_MATRIX[3].xyz;
		float ph = g_time * sway_speed * 1.6 + origin.x * 0.7 + origin.z * 0.55;
		vpos.x += sin(ph + vpos.y * 2.1) * sway_amount * h * h;
		vpos.z += cos(ph * 0.83 + vpos.x * 1.7) * sway_amount * 0.62 * h * h;
		vpos.x += sin(g_time * sway_speed * 4.3 + origin.z * 3.1 + vpos.y * 5.0) * sway_amount * 0.16 * h;
	}
	v_world = (MODEL_MATRIX * vec4(vpos, 1.0)).xyz;
	v_normal_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 view_pos = VIEW_MATRIX * vec4(v_world, 1.0);
	v_dist = length(view_pos.xyz);
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	vec3 base = v_color * tint.rgb;

	// 细粒噪声：防止大面积纯色，在低分辨率下更有“手绘低模”感。
	float grain = value_noise(v_world.xz * 5.3 + vec2(v_world.y * 0.9));
	grain += value_noise(v_world.xz * 19.0 + vec2(2.7)) * 0.45;
	base *= 1.0 - grain_amount * 0.5 + grain * grain_amount;

	// 苔藓：只长在朝上的面，噪声斑块。
	if (moss_amount > 0.001) {
		float up = smoothstep(0.35, 0.86, v_normal_world.y);
		float m = value_noise(v_world.xz * 2.7 + v_world.y * 1.3);
		m = smoothstep(0.34, 0.72, m) * up;
		float m2 = value_noise(v_world.xz * 9.0 + vec2(4.2)) * 0.35;
		base = mix(base, moss_color.rgb, clamp(moss_amount * (m + m2 * m), 0.0, 0.85));
	}

	// 可选分面：用屏幕导数求面法线，让低模树冠/岩石出现硬折面。
	if (faceted > 0.5) {
		vec3 wn = normalize(cross(dFdx(v_world), dFdy(v_world)));
		if (dot(wn, v_normal_world) < 0.0) {
			wn = -wn;
		}
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}

	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	vec3 lit_rim = rim_color * rim * rim_amount * (0.55 + 0.45 * g_night);

	base *= gain;
	base = garden_fog(base, v_dist);
	float fog_f = 1.0 - exp(-v_dist * g_fog_density);

	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = lit_rim + emission_color * emission_amount
		+ g_fog_color.rgb * fog_f * 0.45;
}

void light() {
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(LIGHT);
	float ndl = clamp(dot(n, l), 0.0, 1.0);
	float steps = max(bands, 2.0);
	float band = floor(clamp(ndl, 0.0, 1.0) * steps) / (steps - 1.0);
	band = clamp(band, 0.0, 1.0);
	// 半阶柔化，避免低模面片完全断裂。
	band = mix(band, ndl, 0.18);

	float cs = 1.0;
	if (cloud_amount > 0.001) {
		float n1 = fbm2(v_world.xz * 0.062 + vec2(g_cloud_x, g_cloud_z));
		float n2 = fbm2(v_world.xz * 0.023 + vec2(-g_cloud_z, g_cloud_x) * 0.6 + vec2(11.0, 5.0));
		float patch = smoothstep(0.44, 0.72, n1 * 0.62 + n2 * 0.48);
		cs = 1.0 - patch * g_cloud_shadow * cloud_amount;
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band * cs;
}
