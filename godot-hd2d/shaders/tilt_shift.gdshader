shader_type canvas_item;
render_mode unshaded;

// Screen-space tilt-shift, no depth buffer.
// 17 taps = 1 center (weight 4) + 8 inner ring (weight 2) + 8 outer ring (weight 1).
// The sharp band early-returns with a point sample, so in-band pixels stay 1:1.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float focus_y : hint_range(0.0, 1.0) = 0.60;
uniform float band_half : hint_range(0.0, 0.5) = 0.16;
uniform float feather : hint_range(0.001, 0.5) = 0.20;
uniform float strength : hint_range(0.0, 1.5) = 1.0;
uniform float radius_px : hint_range(0.0, 48.0) = 14.0;
uniform bool post_enabled = true;
uniform vec2 screen_size = vec2(1280.0, 720.0);

const float PI2 = 6.28318530718;

// 0 inside the focal band, ramps to 1 outside with a smooth shoulder.
float band_weight(float y) {
	float d = abs(y - focus_y) - band_half;
	return smoothstep(0.0, feather, max(d, 0.0));
}

// 17-point dual-ring bokeh. Weights sum to 28.
vec4 bokeh_sample(vec2 uv, float radius) {
	vec4 sum = texture(screen_tex, uv) * 4.0;
	vec2 texel = 1.0 / screen_size;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * (PI2 / 8.0) + 0.1963495;
		vec2 dir = vec2(cos(a), sin(a));
		sum += texture(screen_tex, uv + dir * texel * radius * 0.5) * 2.0;
		sum += texture(screen_tex, uv + dir * texel * radius) * 1.0;
	}
	return sum / 28.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 center = texture(screen_tex, uv);
	if (!post_enabled) {
		COLOR = center;
	} else {
		float w = band_weight(uv.y);
		float r = w * strength * radius_px;
		if (r < 0.5) {
			// Point sample / early return: no filtering inside the sharp band.
			COLOR = center;
		} else {
			COLOR = bokeh_sample(uv, r);
		}
	}
}
