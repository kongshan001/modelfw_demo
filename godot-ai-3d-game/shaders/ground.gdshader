shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

// 低模草地：无贴图，用世界坐标低频斑块 + 极淡割草条纹打散大平面。
uniform vec3 grass_dark : source_color = vec3(0.29, 0.64, 0.31);
uniform vec3 grass_light : source_color = vec3(0.46, 0.82, 0.38);
uniform vec3 stripe_color : source_color = vec3(0.38, 0.73, 0.32);

varying vec3 world_pos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float broad = sin(world_pos.x * 0.052 + sin(world_pos.z * 0.038) * 1.4) * 0.5 + 0.5;
	float broad2 = sin(world_pos.z * 0.043 - world_pos.x * 0.017) * 0.5 + 0.5;
	float grain = hash21(floor(world_pos.xz * 1.35)) - 0.5;
	float mixv = clamp(broad * 0.55 + broad2 * 0.35 + grain * 0.10 + 0.08, 0.0, 1.0);
	vec3 col = mix(grass_dark, grass_light, mixv);
	float stripe = abs(fract((world_pos.x * 0.045 + world_pos.z * 0.012) * 2.0) - 1.0);
	col = mix(col, stripe_color, smoothstep(0.86, 1.0, stripe) * 0.11);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
