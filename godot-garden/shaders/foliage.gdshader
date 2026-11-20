shader_type spatial;
render_mode diffuse_burley;

// 树冠：世界噪声让同一材质的叶簇有明暗/色相变化；轻微风摆 + backlight 透光感。
uniform vec3 base_color : source_color = vec3(0.22, 0.38, 0.15);
uniform float sway = 0.015;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float s = sin(TIME * 0.8 + world_pos.x * 0.6 + world_pos.z * 0.4) * sway;
	VERTEX.x += s;
	VERTEX.z += s * 0.5;
}

void fragment() {
	float n = vnoise(world_pos.xz * 1.2 + world_pos.y * 0.8);
	vec3 col = base_color * (0.78 + 0.4 * n);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	BACKLIGHT = col * 0.35;
}
