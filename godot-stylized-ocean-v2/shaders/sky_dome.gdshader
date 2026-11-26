// 程序化天空穹顶：渐变 + 太阳圆盘/光晕 + 夜空星星。相机俯视时几乎不可见，低机位/海平线时成立。
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 zenith_color : source_color = vec3(0.16, 0.47, 0.76);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.92, 0.96);
uniform vec3 ground_color : source_color = vec3(0.36, 0.63, 0.72);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.83);
uniform vec3 sun_dir = vec3(0.35, 0.8, 0.25);
uniform float sun_strength = 1.0;
uniform float sun_disc_size = 0.9993;
uniform float night = 0.0;

varying vec3 v_dir;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	v_dir = normalize((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec3 d = normalize(v_dir);
	float up = clamp(d.y, -1.0, 1.0);
	vec3 col = mix(horizon_color, zenith_color, pow(clamp(up, 0.0, 1.0), 0.52));
	col = mix(col, ground_color, smoothstep(0.0, -0.22, up));

	vec3 sd = normalize(sun_dir);
	float sdot = clamp(dot(d, sd), 0.0, 1.0);
	float disc = smoothstep(sun_disc_size - 0.0005, sun_disc_size + 0.0004, sdot);
	col += sun_color * disc * 2.2 * sun_strength;
	col += sun_color * pow(sdot, 24.0) * 0.28 * sun_strength;
	col += sun_color * pow(sdot, 3.0) * 0.06 * sun_strength;

	// 夜星：只在天空上半球、晴朗时出现
	if (night > 0.02) {
		vec3 sp = floor(d * 240.0);
		float star = step(0.9975, hash13(sp));
		col += vec3(0.8, 0.9, 1.0) * star * smoothstep(0.02, 0.25, d.y) * night * 0.8;
	}

	ALBEDO = col;
}
