shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float softness = 0.22;

void fragment() {
	// UV.y is radial (0 = inner rim, 1 = outer rim).
	float edge = smoothstep(0.0, softness, UV.y) * (1.0 - smoothstep(1.0 - softness, 1.0, UV.y));
	ALBEDO = tint.rgb;
	ALPHA = tint.a * (0.55 + 0.45 * edge);
}
