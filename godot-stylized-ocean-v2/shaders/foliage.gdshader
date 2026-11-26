// 卡通植被：UV2.x 色调 + 手绘方向光 + 轻风摆动。
shader_type spatial;
render_mode cull_disabled, unshaded;

uniform float sway = 0.07;
uniform float sway_speed = 1.25;
uniform vec3 color_dark : source_color = vec3(0.1, 0.42, 0.23);
uniform vec3 color_light : source_color = vec3(0.5, 0.86, 0.42);
uniform vec3 sun_dir = vec3(-0.45, 0.85, -0.25);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.99, 0.94);
uniform vec3 shade_tint : source_color = vec3(0.68, 0.8, 0.88);
uniform float light_level = 1.0;

varying vec3 v_col;
varying vec3 v_nrm;

void vertex() {
	float phase = INSTANCE_CUSTOM.x * 6.2831;
	float w = clamp(VERTEX.y * 0.55, 0.0, 1.0);
	float s = sin(TIME * sway_speed + phase + VERTEX.x * 0.3);
	float s2 = cos(TIME * sway_speed * 0.83 + phase * 1.7 + VERTEX.z * 0.4);
	VERTEX.x += s * sway * w;
	VERTEX.z += s2 * sway * 0.65 * w;
	float tone = clamp(UV2.x, 0.0, 1.0);
	v_col = mix(color_dark, color_light, pow(tone, 0.9));
	v_nrm = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	float ndl = clamp(dot(normalize(v_nrm), normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 tint = mix(shade_tint, sun_tint, pow(ndl, 1.1));
	ALBEDO = v_col * tint * light_level;
}
