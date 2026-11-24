shader_type spatial;
// 原创雾林草叶：低模三角叶片簇 + 顶点风摆 + 实例颜色。
// 环境深度/高度雾自动叠加（WorldEnvironment）。
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.15, 0.23, 0.085, 1.0);
uniform vec4 tip_color : source_color = vec4(0.46, 0.55, 0.23, 1.0);
uniform float sway_amount = 0.12;
uniform float wind_speed = 1.0;

varying vec3 v_inst_color;

void vertex() {
	v_inst_color = COLOR.rgb;
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = wpos.x * 0.8 + wpos.z * 0.63;
	float sway = sin(TIME * wind_speed * 1.7 + phase) + 0.4 * sin(TIME * wind_speed * 2.9 + phase * 1.7);
	float bend = UV.y * UV.y;
	VERTEX.x += sway * sway_amount * bend;
	VERTEX.z += cos(TIME * wind_speed * 1.3 + phase) * sway_amount * 0.55 * bend;
}

void fragment() {
	vec3 col = mix(base_color.rgb, tip_color.rgb, pow(UV.y, 1.2)) * mix(vec3(1.0), v_inst_color, 0.5);
	ALBEDO = col;
	EMISSION = col * 0.14;
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.04, 0.06, 0.02);
}
