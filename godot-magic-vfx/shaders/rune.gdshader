// Magic circle / rune quad — original shader, additive.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D rune_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.6, 0.35, 1.0, 1.0);
uniform float alpha = 0.55;
uniform float spin = 0.0;
uniform float phase = 0.0;
uniform float pulse_amount = 0.18;

varying vec2 ruv;

void vertex() {
	float a = spin;
	vec2 c = UV - 0.5;
	ruv = vec2(c.x * cos(a) - c.y * sin(a), c.x * sin(a) + c.y * cos(a)) + 0.5;
}

void fragment() {
	float a = texture(rune_tex, ruv).a;
	float p = 1.0 - pulse_amount + pulse_amount * sin(TIME * 3.0 + phase);
	ALBEDO = tint.rgb * (0.8 + 0.6 * a) * p;
	ALPHA = clamp(a * alpha, 0.0, 1.0);
}
