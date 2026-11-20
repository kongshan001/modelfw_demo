shader_type canvas_item;
render_mode unshaded;

// Ground snow coverage driven by the same noise mask idea as the dev log:
// a cloud-like mask, thresholded by the coverage slider, with a thin blue
// shadow along the snow edge. The props are drawn above this layer and get
// their own snow-cap overlays.

uniform sampler2D snow_mask : filter_nearest;
uniform float coverage = 0.68;
uniform float snow_on = 1.0;
uniform int debug_mask = 0;
uniform vec3 snow_col = vec3(0.80, 0.88, 0.99);
uniform vec3 snow_shadow = vec3(0.42, 0.52, 0.72);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float m = texture(snow_mask, UV).r;

	if (debug_mask == 1) {
		COLOR = vec4(vec3(m), 1.0);
	} else {
		float t = 1.0 - coverage;
		float s = smoothstep(t - 0.06, t + 0.06, m) * snow_on;
		float edge = smoothstep(t - 0.14, t - 0.02, m)
			* (1.0 - smoothstep(t - 0.02, t + 0.08, m));
		vec3 col = mix(base.rgb, snow_col, s);
		col = mix(col, snow_shadow, edge * 0.32);
		COLOR = vec4(col, base.a);
	}
}
