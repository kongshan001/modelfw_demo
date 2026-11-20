shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// 小花：十字面片，下半段是茎，上半段用极坐标切出五瓣花形。
// 不依赖贴图，640×360 下读作 2–4px 的亮点。

uniform vec3 petal_color : source_color = vec3(0.86, 0.88, 0.78);
uniform vec3 center_color : source_color = vec3(0.92, 0.72, 0.28);
uniform vec3 stem_color : source_color = vec3(0.18, 0.3, 0.12);
uniform float sway = 0.012;

void vertex() {
	float h = UV.y;
	float s = sin(TIME * 1.1 + MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z) * sway * h;
	VERTEX.x += s;
	VERTEX.z += s * 0.4;
}

void fragment() {
	if (UV.y < 0.34) {
		// 茎：中间 6% 宽度
		if (abs(UV.x - 0.5) > 0.06) {
			discard;
		}
		ALBEDO = stem_color;
		ROUGHNESS = 1.0;
	} else {
		vec2 p = (UV - vec2(0.5, 0.72)) / vec2(0.5, 0.28);
		float r = length(p);
		float a = atan(p.y, p.x);
		float petals = 0.5 + 0.5 * cos(a * 5.0);
		float edge = 0.3 + 0.22 * petals;
		if (r > edge) {
			discard;
		}
		vec3 col = mix(center_color, petal_color, smoothstep(0.06, 0.2, r));
		ALBEDO = col;
		ROUGHNESS = 1.0;
		EMISSION = col * 0.05;
	}
}
