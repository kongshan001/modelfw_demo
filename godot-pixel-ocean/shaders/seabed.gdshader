shader_type spatial;

// 海床：透水后能看见的沙底 + 像素焦散。低于水面，不参与倒影。

render_mode unshaded, cull_back, fog_disabled;

uniform vec4 u_sand : source_color = vec4(0.15, 0.28, 0.28, 1.0);
uniform vec4 u_dark : source_color = vec4(0.06, 0.13, 0.16, 1.0);
uniform float u_time = 0.0;

varying vec3 v_world;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz * 0.55;
	vec3 col = u_sand.rgb;

	// 低对比像素焦散：两层交错的细线，不要变成大块方格
	float ca = sin(p.x * 4.0 + u_time * 0.7 + sin(p.y * 3.0 - u_time * 0.5) * 1.4);
	float ca2 = sin(p.y * 5.0 - u_time * 0.6 + sin(p.x * 2.0 + u_time * 0.4) * 1.7);
	float caustic = smoothstep(0.82, 0.99, max(ca, ca2) * 0.5 + 0.5);
	col = mix(col, u_dark.rgb, 0.25 + caustic * 0.10);

	col = floor(col * 20.0 + 0.5) / 20.0;
	ALBEDO = col;
}
