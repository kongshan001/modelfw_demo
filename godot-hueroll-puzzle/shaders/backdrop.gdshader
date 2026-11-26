shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 top_color : source_color = vec3(0.75, 0.84, 0.94);
uniform vec3 bottom_color : source_color = vec3(0.97, 0.91, 0.84);
uniform vec3 accent_color : source_color = vec3(0.90, 0.50, 0.40);
uniform float grain_amount = 0.010;

void fragment() {
	vec2 p = UV;
	float v = smoothstep(0.0, 1.0, p.y);
	vec3 col = mix(bottom_color, top_color, v);

	// Soft out-of-focus colour blobs.
	float g1 = smoothstep(0.72, 0.0, distance(p, vec2(0.18, 0.80)));
	float g2 = smoothstep(0.52, 0.0, distance(p, vec2(0.85, 0.24)));
	float g3 = smoothstep(0.85, 0.0, distance(p, vec2(0.55, 0.55)));
	col = mix(col, accent_color, g1 * 0.055 + g2 * 0.045);
	col += vec3(0.030) * g3;

	// Lift the saturation a little so the pastel themes stay distinct.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 1.16);

	// Paper-like grain.
	float n = fract(sin(dot(p * 913.0, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain_amount;
	col *= mix(0.95, 1.0, v);

	ALBEDO = col;
}
