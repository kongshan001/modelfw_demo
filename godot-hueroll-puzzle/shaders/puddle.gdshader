shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec3 paint_color : source_color = vec3(0.9, 0.3, 0.25);
uniform float ripple_speed = 1.0;
uniform float surface_alpha = 0.94;

void vertex() {
	// A very slight wobble on the puddle rim, baked into the plane vertices.
	VERTEX.y += sin(VERTEX.x * 18.0 + TIME * 0.9) * 0.0015;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ang = atan(p.y, p.x);
	float wobble = sin(ang * 5.0 + TIME * 0.55) * 0.022 + sin(ang * 8.0 - TIME * 0.35) * 0.012;
	vec2 q = abs(p) - vec2(0.80 - wobble);
	float d = max(q.x, q.y) + 0.13 * length(max(q, vec2(0.0))) - 0.11;
	float inside = smoothstep(0.025, -0.025, d);

	float r = length(p);
	float wave = sin(r * 24.0 - TIME * 2.6 * ripple_speed) * 0.5 + 0.5;
	float ring_fade = smoothstep(0.95, 0.15, r);

	vec3 col = paint_color * 0.93;
	col += paint_color * wave * 0.12 * ring_fade;
	col = mix(col, paint_color * 0.62, smoothstep(0.015, -0.05, d) * 0.55);

	vec2 hp = p - vec2(-0.24 + sin(TIME * 0.4) * 0.05, 0.20);
	float h = smoothstep(0.26, 0.0, length(hp));
	col += vec3(1.0, 0.97, 0.9) * h * 0.16;

	ALBEDO = col;
	ALPHA = inside * (surface_alpha - 0.06 + wave * 0.06);
}
