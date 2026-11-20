// Silver-blue fighting aura shell. Additive, rim-weighted, flickering.
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.60, 0.80, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 0.0;
uniform float speed = 1.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.1);
	float bands = 0.62 + 0.38 * sin(TIME * 8.0 * speed + UV.y * 22.0 + UV.x * 9.0);
	float shimmer = 0.70 + 0.30 * sin(TIME * 17.0 + UV.y * 41.0);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * (0.25 + rim * 1.35) * intensity * shimmer;
	ALPHA = clamp(intensity * (0.010 + rim * 0.24) * bands, 0.0, 0.55);
}
