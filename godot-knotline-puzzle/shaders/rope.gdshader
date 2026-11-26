shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Candy-striped toy rope. The stripes come purely from the tube UVs.
uniform vec3 color_a : source_color = vec3(0.972, 0.898, 0.784);
uniform vec3 color_b : source_color = vec3(0.788, 0.282, 0.208);
uniform float bands = 30.0;
uniform float twist = 1.35;
uniform float rim_strength = 0.55;

void fragment() {
	float s = UV.x * bands + UV.y * twist;
	float f = fract(s);
	float tri = abs(f - 0.5);
	float aa = max(fwidth(s), 0.0001) * 1.3;
	float stripe = smoothstep(0.245 - aa, 0.245 + aa, tri);
	vec3 col = mix(color_a, color_b, stripe);
	// Faint fibre shading around the circumference.
	col *= 0.95 + 0.05 * sin(UV.y * 6.2831853 * 2.0);
	ALBEDO = col;
	ROUGHNESS = 0.52;
	SPECULAR = 0.5;
	EMISSION = col * 0.055;
	// Dark fresnel edge reads as a toy outline against pale ground.
	RIM = rim_strength;
	RIM_TINT = 0.18;
}
