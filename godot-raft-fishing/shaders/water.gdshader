shader_type spatial;

// 低分辨率下的分块像素水面：色阶、浪带、木筏泡沫圈、水花涟漪。
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec3 deep_color : source_color = vec3(0.075, 0.32, 0.36);
uniform vec3 shallow_color : source_color = vec3(0.22, 0.62, 0.56);
uniform vec3 foam_color : source_color = vec3(0.90, 0.97, 0.88);
uniform vec3 raft_center = vec3(0.0, 0.0, 0.0);
uniform vec2 raft_half = vec2(2.0, 2.0);
uniform float time = 0.0;
uniform float light_level = 1.0;
uniform float night_mix = 0.0;
uniform vec4 ripples[8];

varying vec3 wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = floor(time * 4.0) / 4.0;
	// 世界空间分块，让波纹呈像素颗粒
	vec2 cell = floor(p * 2.1);
	float h = hash21(cell);
	float band = sin(p.x * 0.62 + p.y * 0.85 - t * 1.7 + h * 1.4);
	float band2 = sin(p.x * 0.31 - p.y * 0.47 + t * 0.9 + h * 2.0);
	float sparkle = step(0.90, h) * (0.5 + 0.5 * sin(t * 2.4 + h * 24.0));

	vec3 col = mix(deep_color, shallow_color, 0.34 + 0.13 * band + 0.08 * band2);

	// 木筏外沿浅水
	vec2 q = abs(p - raft_center.xz) - raft_half;
	float d = max(q.x, q.y);
	col = mix(col, shallow_color, smoothstep(5.0, 0.0, d) * 0.42);

	// 分块泡沫环
	float ang = atan(p.y - raft_center.z, p.x - raft_center.x);
	float wobble = 0.22 * sin(ang * 9.0 + t * 1.6) + 0.10 * sin(ang * 17.0 - t);
	float ring = smoothstep(0.38, 0.0, abs(d - 0.22 + wobble));
	float flecks = step(0.42, hash21(floor(p * 3.6) + floor(t * 2.0)));
	float foam = ring * (0.42 + 0.58 * flecks) * smoothstep(2.6, -0.4, d);
	col = mix(col, foam_color, clamp(foam, 0.0, 0.68));

	// 浪花亮点
	col += vec3(0.75, 0.95, 0.95) * sparkle * 0.16;

	// 水花涟漪，x/z 圆心、z 为起始时间、w 为强度
	for (int i = 0; i < 8; i++) {
		float age = time - ripples[i].z;
		if (age > 0.0 && age < 1.7) {
			float r = age * 2.1;
			float dist = length(p - ripples[i].xy);
			float fade = 1.0 - age / 1.7;
			float w = smoothstep(0.16, 0.0, abs(dist - r)) * fade * ripples[i].w;
			col = mix(col, foam_color, clamp(w, 0.0, 0.55));
		}
	}

	float far_fade = smoothstep(24.0, 70.0, length(p - raft_center.xz));
	col = mix(col, deep_color * 0.82, far_fade);
	col *= light_level;
	col = mix(col, col * vec3(0.58, 0.72, 1.05), night_mix * 0.55);

	ALBEDO = col;
	EMISSION = col * 0.12;
}
