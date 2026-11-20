shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.028, 0.11, 0.125);
uniform vec3 shallow_color : source_color = vec3(0.11, 0.34, 0.32);
uniform vec3 glint_color : source_color = vec3(1.0, 0.86, 0.55);
uniform float u_night : hint_range(0.0, 1.0) = 0.0;
uniform float u_lamp : hint_range(0.0, 1.0) = 0.0;
uniform float u_sunset : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sun_dir = vec3(0.35, 0.8, 0.2);

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 local_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz * 0.55;
	float t = TIME * 0.25;
	float ripple = vnoise(p * 1.3 + vec2(t, 0.0)) * 0.62;
	ripple += vnoise(p * 2.7 - vec2(0.0, t * 0.8)) * 0.38;

	vec3 view = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fresnel = pow(1.0 - max(dot(normalize(world_normal), view), 0.0), 2.2);
	vec3 col = mix(deep_color, shallow_color, 0.22 + fresnel * 0.4 + ripple * 0.1);
	col += vec3(0.14, 0.22, 0.24) * fresnel * (0.25 + 0.4 * (1.0 - u_night));
	col += vec3(0.4, 0.2, 0.1) * u_sunset * fresnel * 0.55;
	float depth = smoothstep(0.0, 4.2, length(local_pos.xz));
	col = mix(col, deep_color, depth * 0.35);
	col += vec3(0.035, 0.055, 0.05) * (ripple - 0.5);

	float glint = pow(max(dot(reflect(-normalize(sun_dir), world_normal), view), 0.0), 70.0);
	col += glint_color * glint * (1.0 - u_night) * 0.75;
	col += glint_color * pow(ripple, 5.0) * (0.08 + u_night * 0.15);
	col += vec3(1.0, 0.62, 0.28) * pow(ripple, 4.0) * u_lamp * 0.12;
	col *= mix(1.0, 0.58, u_night);

	ALBEDO = col;
	ROUGHNESS = 0.12;
	METALLIC = 0.12;
	EMISSION = vec3(0.01, 0.035, 0.04) * (0.35 + u_night * 0.5);
}
