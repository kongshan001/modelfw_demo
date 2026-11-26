// 低模云团：不受光，按法线做柔和向阳/背阳渐变，保持参考里的奶白体积感。
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

uniform vec3 light_color : source_color = vec3(0.99, 0.985, 0.97);
uniform vec3 shade_color : source_color = vec3(0.68, 0.79, 0.9);
uniform vec3 sun_dir = vec3(0.35, 0.8, 0.25);

varying vec3 v_n;
varying float v_up;

void vertex() {
	v_n = normalize((MODEL_NORMAL_MATRIX * NORMAL));
	v_up = clamp(VERTEX.y, -1.0, 1.0);
}

void fragment() {
	float d = dot(normalize(v_n), normalize(sun_dir)) * 0.5 + 0.5;
	vec3 col = mix(shade_color, light_color, smoothstep(0.15, 1.0, d));
	col = mix(col, light_color, smoothstep(-0.2, 1.4, v_up) * 0.3);
	ALBEDO = col;
}
