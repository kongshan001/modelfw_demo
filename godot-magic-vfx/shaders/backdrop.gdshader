// Night arena backdrop — original gradient + sparse stars, unshaded.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 top_color : source_color = vec4(0.008, 0.012, 0.030, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.045, 0.070, 0.145, 1.0);
uniform vec3 glow_color : source_color = vec3(0.10, 0.20, 0.42);
uniform float star_amount = 0.985;

void fragment() {
	float t = clamp(UV.y, 0.0, 1.0);
	vec3 col = mix(horizon_color.rgb, top_color.rgb, pow(t, 0.65));
	vec2 g = UV * vec2(90.0, 42.0);
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = fract(sin(dot(id, vec2(12.9898, 78.233))) * 43758.5453);
	float star = smoothstep(0.10, 0.0, length(f)) * step(star_amount, h);
	col += vec3(0.55, 0.68, 1.0) * star * 0.55;
	col += glow_color * smoothstep(0.42, 0.0, t) * 0.18;
	ALBEDO = col;
}
