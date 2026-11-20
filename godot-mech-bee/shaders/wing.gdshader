shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D wing_tex : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(0.96, 0.94, 0.86, 1.0);
uniform float opacity = 0.92;
uniform float ghost = 0.0;

void fragment() {
	vec4 t = texture(wing_tex, UV);
	float ink = smoothstep(0.35, 0.8, t.a);
	ALBEDO = mix(tint.rgb, vec3(0.10, 0.09, 0.07), ink);
	ALPHA = t.a * opacity * (1.0 - ghost * 0.72);
}
