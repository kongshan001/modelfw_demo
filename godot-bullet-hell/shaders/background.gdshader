shader_type canvas_item;

// 原创紫黑舞台：垂直渐变 + 中央柔光 + 暗角 + 极淡横向扫描线。
uniform vec3 top_color : source_color = vec3(0.115, 0.055, 0.205);
uniform vec3 bottom_color : source_color = vec3(0.012, 0.016, 0.042);
uniform vec3 haze_color : source_color = vec3(0.19, 0.05, 0.28);

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color, bottom_color, smoothstep(0.0, 1.0, uv.y));
	vec2 p = (uv - vec2(0.5, 0.34)) * vec2(1.0, 0.82);
	float haze = 1.0 - smoothstep(0.04, 0.72, length(p));
	col += haze_color * haze * 0.24;
	float r = length((uv - vec2(0.5)) * vec2(1.0, 0.9));
	col *= 1.0 - smoothstep(0.34, 0.88, r) * 0.58;
	float scan = 0.5 + 0.5 * sin(uv.y * 900.0);
	col += vec3(0.012, 0.008, 0.022) * scan;
	COLOR = vec4(col, 1.0);
}
