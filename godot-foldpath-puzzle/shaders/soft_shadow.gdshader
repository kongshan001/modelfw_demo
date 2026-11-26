shader_type spatial;

// Soft contact/blob shadow. The GL Compatibility shadow map on the target
// Intel driver does not produce visible directional shadows, so the diorama
// uses these cheap radial decals (plus dark platform undersides) instead.

render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 shadow_color : source_color = vec4(0.055, 0.095, 0.080, 0.24);
uniform float softness : hint_range(0.05, 1.0) = 0.55;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float a = 1.0 - smoothstep(softness * 0.35, 1.0, d);
	a = pow(a, 1.35);
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_color.a * a;
}
