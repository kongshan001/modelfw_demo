// Stylised arena floor — original shader. Lit (so the fireball OmniLight3D
// actually pools on the floor), grid lines fade with distance, soft rune pool
// under the caster.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.055, 0.068, 0.105);
uniform vec3 line_color : source_color = vec3(0.20, 0.27, 0.48);
uniform vec3 glow_color : source_color = vec3(0.20, 0.36, 0.62);
uniform vec3 pool_center = vec3(0.0, 0.0, 0.0);
uniform sampler2D noise_tex : repeat_enable, filter_linear;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 minor_cell = abs(fract(p) - 0.5);
	float minor = smoothstep(0.478, 0.5, max(minor_cell.x, minor_cell.y));
	vec2 major_cell = abs(fract(p * 0.25) - 0.5);
	float major = smoothstep(0.49, 0.5, max(major_cell.x, major_cell.y));

	float d = length(p - pool_center.xz);
	float fade = smoothstep(24.0, 7.0, d);
	float pool = smoothstep(10.0, 0.0, d) * 0.45 + smoothstep(3.0, 0.0, d) * 0.45;

	float n = texture(noise_tex, p * 0.11).r;
	vec3 col = base_color * (0.75 + 0.5 * n);
	col = mix(col, line_color, minor * 0.14 * fade + major * 0.20 * fade);
	col += glow_color * pool * 0.18;
	col = mix(col, vec3(0.020, 0.027, 0.050), smoothstep(20.0, 36.0, d));

	ALBEDO = col;
	ROUGHNESS = 0.55 + 0.35 * n;
	METALLIC = 0.05;
}
