shader_type spatial;
// 草、花、树冠共用：顶点风摆 + 顶点色 + 夜间微自发光。
// 时间由脚本传入（u_time），暂停时冻结；不依赖引擎 TIME，便于暂停/截图可复现。
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float u_time = 0.0;
uniform float sway = 0.045;
uniform float flutter = 0.012;
uniform float wind_gust = 0.0;
uniform float glow_strength = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform bool use_uv_height = true;
uniform float root_bend = 0.0;

varying float v_leaf_height;

void vertex() {
	float h = use_uv_height ? clamp(UV.y, 0.0, 1.0) : 1.0;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = u_time * (1.15 + wind_gust * 0.75) + origin.x * 0.43 + origin.z * 0.27;
	float broad = sin(phase) * 0.66 + sin(phase * 2.13 + 1.7) * 0.34;
	float fine = sin(u_time * 2.7 + origin.x * 1.7 + VERTEX.y * 3.9);
	float bend_mul = 1.0 + h * (0.7 + wind_gust);
	VERTEX.x += broad * sway * bend_mul;
	VERTEX.z += cos(phase * 0.83 + 0.9) * sway * 0.52 * bend_mul;
	VERTEX.y += fine * flutter * h;
	VERTEX.x += sin(u_time * 1.9 + VERTEX.z * 2.3) * flutter * 0.35;
	VERTEX.z += cos(u_time * 1.6 + VERTEX.x * 2.1) * flutter * 0.35;
	if (root_bend > 0.0) {
		VERTEX.x += root_bend * h * h;
	}
	v_leaf_height = h;
}

void fragment() {
	// 注意：本场景的顶点色/实例色按“风格化线性色”使用，呈现明亮、低饱和的苔藓绿。
	vec3 base = COLOR.rgb * tint;
	ALBEDO = base;
	ROUGHNESS = 0.86;
	SPECULAR = 0.22;
	EMISSION = base * glow_strength;
	BACKLIGHT = base * (0.10 + glow_strength * 0.35);
}
