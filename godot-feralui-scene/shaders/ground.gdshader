shader_type spatial;
// 苔地：程序化色斑 + 细微颗粒，无外部贴图。受方向光阴影与灯笼暖光。
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 moss_deep : source_color = vec3(0.125, 0.230, 0.155);
uniform vec3 moss_mid : source_color = vec3(0.240, 0.385, 0.220);
uniform vec3 moss_light : source_color = vec3(0.430, 0.520, 0.265);
uniform vec3 soil : source_color = vec3(0.295, 0.245, 0.180);
uniform float grain = 1.0;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.02 + vec2(4.1, 9.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	UV = world_pos.xz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float n1 = fbm(p * 0.28 + vec2(1.7, 3.2));
	float n2 = fbm(p * 1.17 + vec2(8.1, -2.4));
	float speck = step(0.91, vnoise(p * 16.0)) * 0.28;
	vec3 col = mix(moss_deep, moss_mid, smoothstep(0.24, 0.72, n1));
	col = mix(col, moss_light, smoothstep(0.57, 0.93, n2) * 0.52);
	col = mix(col, soil, smoothstep(0.80, 0.97, fbm(p * 0.67 + 12.0)) * 0.45);
	col += (n2 - 0.5) * 0.028;
	col += speck * grain * vec3(0.16, 0.18, 0.09);
	ALBEDO = col;
	ROUGHNESS = 0.97;
	SPECULAR = 0.08;
}
