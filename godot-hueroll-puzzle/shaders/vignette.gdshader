shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.32;
uniform vec3 tint : source_color = vec3(0.16, 0.12, 0.22);

void fragment() {
	vec2 p = SCREEN_UV * 2.0 - 1.0;
	p.x *= 0.92;
	float v = smoothstep(0.62, 1.28, length(p));
	COLOR = vec4(tint, v * strength);
}
