shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

#include "res://shaders/common.gdshaderinc"

// 地形 / 草岛 / 石头 / 水生植物的统一量化受光材质。
// 顶点色来自程序化网格；光照用两段到多段色阶；水下加焦散与雾。
uniform vec4 tint : source_color = vec4(1.0);
uniform float caustic_amount = 0.0;
uniform float rim_amount = 0.08;
uniform vec4 rim_color : source_color = vec4(0.72, 0.92, 0.86, 1.0);
uniform float sway_amount = 0.0;
uniform float sway_ref = 1.0;
uniform float sway_speed = 1.0;
uniform float shore_band = 0.0;
uniform vec4 foam_color : source_color = vec4(0.95, 0.99, 0.97, 1.0);
uniform float wet_darken = 0.0;

varying vec3 v_world;
varying float v_dist;

void vertex() {
	vec3 vpos = VERTEX;
	if (sway_amount > 0.0001) {
		float h = clamp(vpos.y / max(sway_ref, 0.001), 0.0, 1.0);
		vec3 origin = MODEL_MATRIX[3].xyz;
		float ph = g_time * sway_speed * 1.15 + origin.x * 0.8 + origin.z * 0.6;
		vpos.x += sin(ph + vpos.y * 1.7) * sway_amount * h * h;
		vpos.z += cos(ph * 0.77 + vpos.x * 1.3) * sway_amount * 0.55 * h * h;
	}
	v_world = (MODEL_MATRIX * vec4(vpos, 1.0)).xyz;
	vec4 view_pos = VIEW_MATRIX * vec4(v_world, 1.0);
	v_dist = length(view_pos.xyz);
	POSITION = snap_clip(PROJECTION_MATRIX * view_pos);
}

void fragment() {
	vec3 base = COLOR.rgb * tint.rgb;
	// 世界空间细粒噪声，避免大片纯色和扇形顶点色条纹。
	float grain = value_noise(v_world.xz * 6.0 + vec2(v_world.y * 0.7)) * 0.16;
	grain += value_noise(v_world.xz * 21.0 + vec2(3.1)) * 0.06;
	base *= 0.9 + grain;

	// 水下焦散：只在水面以下生效，越深越弱。
	float under = smoothstep(0.02, 0.4, -v_world.y);
	float ca = caustic_pattern(v_world.xz * 0.95, g_time) * caustic_amount * g_caustics * under;
	ca = floor(ca * 3.0) / 3.0;
	EMISSION = ca * vec3(0.68, 1.0, 0.88) * 0.3;

	// 细边缘光，补低分辨率下的轮廓辨识度。
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	EMISSION += rim_color.rgb * rim * rim_amount;

	// 岛岸白线：世界坐标贴近水面的一圈虚线泡沫带。
	if (shore_band > 0.5) {
		float band = 1.0 - smoothstep(0.02, 0.13, abs(v_world.y - 0.01));
		float dash = 0.5 + 0.5 * sin((v_world.x + v_world.z) * 15.0 + sin(v_world.x * 5.0) * 1.4);
		dash = smoothstep(0.08, 0.5, dash + (hash12(floor(v_world.xz * 24.0)) - 0.5) * 0.22);
		band *= (0.5 + 0.5 * dash);
		base = mix(base, foam_color.rgb, clamp(band * 1.15, 0.0, 1.0));
		EMISSION += foam_color.rgb * band * 0.08;
	}

	base = mix(base, base * 0.72, wet_darken);
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
