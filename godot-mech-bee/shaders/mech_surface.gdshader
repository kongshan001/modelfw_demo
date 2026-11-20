shader_type spatial;
render_mode unshaded, cull_back, blend_mix;

// Fake studio shading for GL Compatibility: no engine lights, no shadows.
// Keeps the same look on Intel iGPU / MoltenVK / any renderer.

uniform vec4 base_color : source_color = vec4(0.85, 0.83, 0.78, 1.0);
uniform float specular_amount = 0.35;
uniform float rim_amount = 0.35;
uniform vec4 rim_color : source_color = vec4(0.85, 0.18, 0.10, 1.0);
uniform float alpha = 1.0;
uniform float shade_bias = 0.0;

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	vec3 L = normalize(vec3(0.55, 0.9, 0.65));

	float diff = clamp(dot(N, L), 0.0, 1.0);
	float fres = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 2.4);
	vec3 H = normalize(L + V);
	float sp = pow(clamp(dot(N, H), 0.0, 1.0), 44.0) * specular_amount;
	float ao = clamp(0.92 + N.y * 0.05, 0.0, 1.0);

	vec3 col = base_color.rgb * (0.86 + 0.18 * diff) * ao;
	col += vec3(1.0) * sp * 0.35;
	col += rim_color.rgb * fres * rim_amount;
	col = mix(col, base_color.rgb, shade_bias);

	ALBEDO = col;
	ALPHA = alpha;
}
