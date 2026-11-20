shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley;

// MultiMesh 十字草叶：UV.x 控制叶片宽度，UV.y 控制根→尖渐变；风摆只作用于顶点。
uniform float wind = 0.09;
uniform vec3 root_color : source_color = vec3(0.06, 0.14, 0.045);
uniform vec3 tip_color : source_color = vec3(0.38, 0.56, 0.22);

varying float v_var;

void vertex() {
	float h = UV.y;
	float phase = INSTANCE_CUSTOM.x * 6.2831;
	float sway = sin(TIME * 1.6 + phase + MODEL_MATRIX[3].x * 0.7 + MODEL_MATRIX[3].z * 0.5);
	sway *= wind * h * h;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.35;
	v_var = INSTANCE_CUSTOM.y;
}

void fragment() {
	float half_width = mix(0.5, 0.035, UV.y);
	if (abs(UV.x - 0.5) > half_width) {
		discard;
	}
	vec3 col = mix(root_color, tip_color, UV.y);
	col *= 0.78 + v_var * 0.38;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.08, 0.14, 0.04);
}
