shader_type spatial;
render_mode unshaded, cull_disabled;

// 草叶/花茎摆动：顶点颜色提供色相，UV.y 作为根部权重（0=根，1=梢）。
uniform float sway_amount : hint_range(0.0, 0.3) = 0.055;
uniform float sway_speed = 1.7;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.43 + world.z * 0.31;
	float sway = sin(TIME * sway_speed + phase)
		+ 0.35 * sin(TIME * sway_speed * 2.3 + phase * 1.7);
	float bend = UV.y * UV.y;
	VERTEX.x += sway * sway_amount * bend;
	VERTEX.z += sway * sway_amount * 0.55 * bend;
}

void fragment() {
	ALBEDO = COLOR.rgb;
}
