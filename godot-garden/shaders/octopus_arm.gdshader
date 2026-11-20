shader_type spatial;
render_mode diffuse_burley, cull_disabled;

// 触手管：静态网格 + 每帧 arm_points[12] uniform，在顶点着色器里重建曲线和环。
// 比每帧 CPU 重建网格便宜；Catmull-Rom 让 12 个物理点看起来是平滑的触手。
uniform vec3 arm_points[12];
uniform float base_radius = 0.18;
uniform float tip_radius = 0.03;
uniform vec3 base_color : source_color = vec3(0.8, 0.24, 0.16);
uniform vec3 dark_color : source_color = vec3(0.55, 0.12, 0.1);
uniform vec3 accent_color : source_color = vec3(0.98, 0.55, 0.38);
uniform float u_night : hint_range(0.0, 1.0) = 0.0;
uniform float u_sleep : hint_range(0.0, 1.0) = 0.0;

varying vec3 local_pos;
varying vec3 world_normal;

vec3 catmull(vec3 p0, vec3 p1, vec3 p2, vec3 p3, float t) {
	float t2 = t * t;
	float t3 = t2 * t;
	return 0.5 * (
		2.0 * p1
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	);
}

vec3 catmull_tangent(vec3 p0, vec3 p1, vec3 p2, vec3 p3, float t) {
	vec3 d = 0.5 * (
		(-p0 + p2)
		+ 2.0 * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t
		+ 3.0 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t
	);
	if (length(d) < 0.0001) {
		d = p2 - p1;
	}
	return normalize(d);
}

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
	float along = UV.y;
	float angle = UV.x * 6.2831853;
	float scaled = along * 11.0;
	int index = int(floor(scaled));
	index = clamp(index, 0, 10);
	float f = fract(scaled);
	int i0 = max(index - 1, 0);
	int i1 = index;
	int i2 = min(index + 1, 11);
	int i3 = min(index + 2, 11);
	vec3 p0 = arm_points[i0];
	vec3 p1 = arm_points[i1];
	vec3 p2 = arm_points[i2];
	vec3 p3 = arm_points[i3];
	vec3 center = catmull(p0, p1, p2, p3, f);
	vec3 tangent = catmull_tangent(p0, p1, p2, p3, f);
	vec3 up = abs(tangent.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 side = normalize(cross(tangent, up));
	vec3 up2 = normalize(cross(side, tangent));
	float radius = mix(base_radius, tip_radius, along);
	vec3 offset = side * cos(angle) * radius + up2 * sin(angle) * radius;
	VERTEX = center + offset;
	NORMAL = normalize(offset);
	local_pos = VERTEX;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = local_pos.xz * 2.2 + local_pos.y * 1.1;
	float n = vnoise(p) * 0.65 + vnoise(p * 4.0 + 3.0) * 0.35;
	vec3 col = mix(dark_color, base_color, smoothstep(0.22, 0.72, n));
	col = mix(col, accent_color, smoothstep(0.74, 0.95, n) * 0.35);
	float up = world_normal.y * 0.5 + 0.5;
	col *= mix(0.6, 1.05, up);

	float row_a = smoothstep(0.055, 0.0, abs(UV.x - 0.7));
	float row_b = smoothstep(0.055, 0.0, abs(UV.x - 0.8));
	float dots = step(0.5, sin(UV.y * 78.0 + UV.x * 9.0));
	float sucker = max(row_a, row_b) * dots;
	col = mix(col, vec3(0.95, 0.76, 0.56), sucker * 0.72);

	col = mix(col, col * vec3(0.5, 0.38, 0.56) + vec3(0.02, 0.0, 0.03), u_night * 0.7);
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma) * vec3(0.85, 0.7, 0.8), u_sleep * 0.55);
	col = floor(col * 12.0 + 0.5) / 12.0;
	ALBEDO = col;
	ROUGHNESS = 0.82;
	EMISSION = col * 0.025;
}
