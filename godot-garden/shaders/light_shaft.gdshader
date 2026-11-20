shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 beam_color : source_color = vec4(1.0, 0.72, 0.42, 0.22);
uniform float intensity = 0.0;
uniform float softness = 0.5;

void fragment() {
	float edge = smoothstep(0.5, 0.5 - softness, abs(UV.x - 0.5));
	float fade = smoothstep(0.0, 0.16, UV.y) * (1.0 - smoothstep(0.72, 1.0, UV.y));
	float flicker = 0.92 + 0.08 * sin(TIME * 0.7 + UV.y * 4.0);
	ALBEDO = beam_color.rgb;
	ALPHA = edge * fade * intensity * beam_color.a * flicker;
}
