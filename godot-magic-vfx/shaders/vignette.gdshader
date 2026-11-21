// Soft cinematic vignette + cool grade — original canvas shader.
shader_type canvas_item;

uniform float strength = 0.72;
uniform vec3 tint : source_color = vec3(0.010, 0.014, 0.030);
uniform float top_grade = 0.16;

void fragment() {
	vec2 uv = UV;
	float d = length((uv - 0.5) * vec2(1.18, 1.0));
	float v = smoothstep(0.34, 0.92, d) * strength;
	v = max(v, smoothstep(0.55, 0.0, uv.y) * top_grade);
	COLOR = vec4(tint, v);
}
