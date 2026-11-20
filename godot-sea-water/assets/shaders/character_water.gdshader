shader_type canvas_item;
render_mode unshaded;

// The character is drawn above the water layer. This shader paints the
// waterline on the body: a curved foam edge, a tinted/rippled submerged part,
// and caustics. submerge comes from the depth map at the character's feet.

uniform float submerge = 0.0;
uniform float time = 0.0;
uniform vec3 tint = vec3(1.0);
uniform vec3 water_col = vec3(0.30, 0.75, 0.70);
uniform sampler2D caustic_tex : repeat_enable, filter_nearest;
// The sprite is an AtlasTexture: UV is in the whole sheet. This remaps it to
// the current frame's 0..1 space so the waterline lands on the body.
uniform vec2 u_frame_origin = vec2(0.0);
uniform vec2 u_frame_size = vec2(0.1666667, 0.25);

void fragment() {
	vec2 uv = UV;
	vec2 luv = (uv - u_frame_origin) / u_frame_size;
	vec4 tex = texture(TEXTURE, uv);
	vec3 c = tex.rgb * tint;

	float line = 1.0 - submerge * 0.62;
	line += 0.030 * sin((luv.x - 0.5) * 6.5 + time * 1.7)
		+ 0.010 * sin(luv.x * 25.0 - time * 3.0);

	if (submerge > 0.015 && luv.y > line) {
		vec2 w = uv + vec2(
			sin(luv.y * 48.0 + time * 2.0),
			cos(luv.x * 40.0 + time * 1.5)) * u_frame_size * 0.22;
		vec4 wt = texture(TEXTURE, w);
		c = mix(wt.rgb * tint, water_col, 0.62) * 0.90;
		float ca = texture(caustic_tex, luv * vec2(2.0, 1.4) + time * 0.02).r;
		c += vec3(0.08, 0.20, 0.18) * ca * 0.7;
	}

	float edge = abs(luv.y - line);
	if (submerge > 0.015 && edge < 0.045) {
		float foam = smoothstep(0.045, 0.0, edge);
		c = mix(c, vec3(0.90, 1.0, 0.97), foam * 0.9);
	}

	COLOR = vec4(c, tex.a);
}
