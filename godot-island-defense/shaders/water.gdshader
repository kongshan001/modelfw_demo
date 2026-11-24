shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.10, 0.29, 0.33, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.28, 0.54, 0.54, 1.0);
uniform vec4 foam_color : source_color = vec4(0.78, 0.90, 0.85, 1.0);
uniform float shore_radius = 32.0;
uniform vec3 island_center = vec3(0.0, 0.0, 0.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = length(world_pos.xz - island_center.xz);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, smoothstep(shore_radius, shore_radius * 2.6, d));
	float ribbon_a = sin(world_pos.x * 0.28 + world_pos.z * 0.11 + TIME * 0.8) * 0.5 + 0.5;
	float ribbon_b = sin(world_pos.z * 0.36 - TIME * 0.55 + world_pos.x * 0.09) * 0.5 + 0.5;
	col = mix(col, col * 1.09, ribbon_a * 0.20 + ribbon_b * 0.14);
	float foam = 1.0 - smoothstep(0.0, 5.5, abs(d - shore_radius));
	foam *= 0.62 + 0.38 * sin(world_pos.x * 0.5 + world_pos.z * 0.28 + TIME * 1.4);
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 0.9) * 0.55);
	ALBEDO = col;
	ROUGHNESS = 0.30;
	SPECULAR = 0.30;
	ALPHA = 0.96;
}
