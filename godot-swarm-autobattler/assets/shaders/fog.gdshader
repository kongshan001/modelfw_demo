shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 tint : source_color = vec4(0.05, 0.13, 0.16, 0.16);
uniform vec2 scroll = vec2(0.006, 0.0015);

void fragment() {
	vec2 uv = UV * vec2(2.4, 1.4) + TIME * scroll;
	vec4 n = texture(TEXTURE, uv);
	COLOR = vec4(tint.rgb, n.a * tint.a);
}
