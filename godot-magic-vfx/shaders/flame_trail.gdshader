// Wavy flame ribbon tail — original shader for Magic Projectile Lab.
// The ribbon geometry is built from projectile history in trail_ribbon.gd;
// this shader scrolls an original flame strip texture along it and ramps
// white-hot -> orange -> deep red, with torn organic holes.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D strip_tex : source_color, repeat_enable, filter_linear;
uniform vec4 hot_color : source_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.58, 0.18, 1.0);
uniform vec4 deep_color : source_color = vec4(0.85, 0.09, 0.02, 1.0);
uniform float scroll_speed = 1.1;
uniform float length_repeat = 1.7;
uniform float width_scale = 0.62;
uniform float alpha_mul = 0.95;
uniform float seed = 0.0;
uniform float flow_dir = -1.0;

varying vec2 trail_uv;

void vertex() {
	trail_uv = UV;
}

void fragment() {
	float age = clamp(trail_uv.x, 0.0, 1.0); // 0 = tail tip, 1 = head
	vec2 uvv;
	uvv.x = age * length_repeat + TIME * scroll_speed * flow_dir + seed;
	uvv.y = 0.5 + (trail_uv.y - 0.5) * width_scale;
	uvv.y += sin(age * 11.0 + TIME * 2.1 + seed) * 0.022;
	vec4 strip = texture(strip_tex, uvv);
	float across = abs(trail_uv.y - 0.5) * 2.0;
	float core = smoothstep(1.0, 0.05, across);
	float fade = smoothstep(0.0, 0.2, age) * smoothstep(1.02, 0.86, age);
	float mask = strip.a * fade * alpha_mul * (0.35 + 0.8 * core);

	vec3 col = mix(deep_color.rgb, mid_color.rgb, smoothstep(0.12, 0.7, age));
	col = mix(col, hot_color.rgb, smoothstep(0.55, 0.95, age) * (0.3 + 0.7 * core));
	col = mix(col, deep_color.rgb, smoothstep(0.45, 1.0, across) * 0.55);
	col *= 0.9 + strip.g * 0.5;

	ALBEDO = col;
	ALPHA = clamp(mask, 0.0, 1.0);
}
