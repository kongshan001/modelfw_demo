shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform vec4 bg_color : source_color = vec4(0.949, 0.933, 0.890, 1.0);
uniform vec4 line_color : source_color = vec4(0.72, 0.69, 0.60, 0.55);
uniform float cells = 26.0;
uniform float fade = 1.6;

void fragment() {
	vec2 p = UV * cells;
	vec2 g = abs(fract(p - 0.5) - 0.5) / max(fwidth(p), vec2(0.0001));
	float line = 1.0 - min(min(g.x, g.y), 1.0);
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.35, d);
	ALBEDO = mix(bg_color.rgb, line_color.rgb, line * 0.55);
	ALPHA = a;
}
