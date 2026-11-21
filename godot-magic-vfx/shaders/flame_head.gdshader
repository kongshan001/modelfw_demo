// Procedural flame head — original shader for Magic Projectile Lab.
// Additive, unshaded, double sided; the head mesh itself gives the silhouette,
// the shader adds scrolling plasma, a white-hot leading edge and hot rim.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 hot_color : source_color = vec4(1.0, 0.95, 0.78, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.56, 0.16, 1.0);
uniform vec4 deep_color : source_color = vec4(0.82, 0.08, 0.02, 1.0);
uniform float intensity = 1.5;
uniform float flow_speed = 1.35;
uniform float noise_scale = 2.6;
uniform float seed = 0.0;
uniform float style = 0.0; // 0 ember, 1 arcane, 2 frost
uniform sampler2D noise_tex : repeat_enable, filter_linear;

varying vec3 local_pos;
varying vec2 head_uv;

void vertex() {
	local_pos = VERTEX;
	head_uv = UV;
}

void fragment() {
	float t = clamp(head_uv.x, 0.0, 1.0); // 0 = tail side, 1 = leading edge
	float flow = TIME * flow_speed;
	vec2 nuv = vec2(local_pos.z * 0.9 + flow * 0.18 + seed, local_pos.y * 1.4 - flow * 0.05) * noise_scale;
	float n1 = texture(noise_tex, nuv * 0.35).r;
	float n2 = texture(noise_tex, nuv * 0.8 + vec2(-flow * 0.22, 0.31)).g;
	float turb = clamp(n1 * 0.6 + n2 * 0.6, 0.0, 1.0);

	// tongue mask: vertical flame streaks travelling backwards
	float streaks = smoothstep(0.34, 0.72, turb);
	float front = smoothstep(0.18, 0.92, t + (turb - 0.5) * 0.18);

	vec3 col = mix(deep_color.rgb, mid_color.rgb, smoothstep(0.02, 0.55, t));
	col = mix(col, hot_color.rgb, smoothstep(0.58, 0.97, t) * (0.65 + 0.35 * streaks));
	col *= 0.75 + turb * 0.85;

	if (style > 1.5) {
		// frost: whiter, sharper, less turbulent
		col = mix(deep_color.rgb, mid_color.rgb, smoothstep(0.15, 0.55, t));
		col = mix(col, hot_color.rgb, smoothstep(0.6, 0.98, t));
		col *= 0.85 + 0.25 * sin(TIME * 9.0 + seed);
	} else if (style > 0.5) {
		// arcane: cooler core pulse
		col *= 0.9 + 0.2 * sin(TIME * 12.0 + seed + t * 4.0);
	}

	float edge_fade = smoothstep(0.0, 0.1, t) * smoothstep(1.02, 0.9, t);
	float flicker = 0.85 + 0.15 * sin(TIME * 24.0 + seed * 3.0);
	ALBEDO = col * intensity * flicker;
	ALPHA = clamp((0.45 + 0.55 * front) * (0.5 + 0.5 * streaks) * edge_fade, 0.0, 1.0);
}
