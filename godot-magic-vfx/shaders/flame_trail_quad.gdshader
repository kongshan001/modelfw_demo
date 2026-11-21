// Scrolling flame sheet attached to the projectile — original shader.
// A single flat quad (cached geometry) replaces per-frame CPU ribbon rebuilds,
// which were the main stall source on the Intel GL Compatibility driver.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D strip_tex : source_color, repeat_enable, filter_linear;
uniform vec4 hot_color : source_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.58, 0.18, 1.0);
uniform vec4 deep_color : source_color = vec4(0.85, 0.09, 0.02, 1.0);
uniform float scroll_speed = 1.1;
uniform float length_repeat = 1.3;
uniform float width_scale = 0.62;
uniform float alpha_mul = 0.95;
uniform float seed = 0.0;
uniform float flow_dir = -1.0;

varying vec2 tuv;

void vertex() {
	tuv = UV;
}

void fragment() {
	// UV.x = 0 at the head, 1 at the tail (geometry is offset behind the head)
	float headness = 1.0 - clamp(tuv.x, 0.0, 1.0);
	vec2 uvv;
	uvv.x = tuv.x * length_repeat + TIME * scroll_speed * flow_dir + seed;
	uvv.y = 0.5 + (tuv.y - 0.5) * width_scale;
	uvv.y += sin(tuv.x * 10.0 + TIME * 2.1 + seed) * 0.028
		+ sin(tuv.x * 3.2 - TIME * 1.3 + seed * 0.7) * 0.02;
	vec4 strip = texture(strip_tex, uvv);
	float across = abs(tuv.y - 0.5) * 2.0;
	float core = smoothstep(1.0, 0.05, across);
	float fade = smoothstep(0.0, 0.22, headness) * smoothstep(1.02, 0.86, headness);
	float mask = strip.a * fade * alpha_mul * (0.32 + 0.8 * core);

	vec3 col = mix(deep_color.rgb, mid_color.rgb, smoothstep(0.15, 0.75, headness));
	col = mix(col, hot_color.rgb, smoothstep(0.55, 0.98, headness) * (0.3 + 0.7 * core));
	col = mix(col, deep_color.rgb, smoothstep(0.45, 1.0, across) * 0.55);
	col *= 0.9 + strip.g * 0.5;

	ALBEDO = col;
	ALPHA = clamp(mask, 0.0, 1.0);
}
