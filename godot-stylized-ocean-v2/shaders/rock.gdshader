// 低模礁石：顶点色 + 手绘方向光；水线附近湿岩暗带 + 泡沫环，水下部分偏青，
// 让水中礁石有真实的接触关系而不是一块悬浮的青色贴片。
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D foam_tex : filter_linear, repeat_enable;
uniform vec3 sun_dir = vec3(-0.45, 0.85, -0.25);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.99, 0.96);
uniform vec3 shade_tint : source_color = vec3(0.62, 0.72, 0.84);
uniform vec3 foam_color : source_color = vec3(0.985, 1.0, 1.0);
uniform float light_level = 1.0;
uniform float time = 0.0;
uniform float night_level = 0.0;

varying vec3 v_col;
varying vec3 v_nrm;
varying vec3 v_world;

void vertex() {
	v_col = COLOR.rgb;
	v_nrm = normalize((MODEL_NORMAL_MATRIX * NORMAL));
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float ndl = clamp(dot(normalize(v_nrm), normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 tint = mix(shade_tint, sun_tint, pow(ndl, 1.15));
	vec3 col = v_col * tint * light_level;

	float y = v_world.y;
	float n = texture(foam_tex, v_world.xz * 0.55 + vec2(time * 0.02, 0.0)).r;
	// 湿岩基座：水线以上 0.55 m 内压暗（内陆岩石 y 较高，自然不受影响）
	float wet = 1.0 - smoothstep(-0.10, 0.62, y);
	col *= mix(1.0, 0.58, wet);
	// 水线泡沫环：贴在 y≈0 的岩面上，噪声打断，随浪轻微上下
	float wob = 0.035 * sin(time * 0.9 + v_world.x * 0.6 + v_world.z * 0.4);
	float foam_band = 1.0 - smoothstep(0.015, 0.13, abs(y - 0.03 + wob));
	foam_band *= smoothstep(0.42, 0.66, n + 0.10);
	col = mix(col, foam_color * 0.97, foam_band * 0.62);
	// 水下岩面偏青（透过透明浅水看到）
	float under = smoothstep(0.02, -0.18, y);
	col = mix(col, col * vec3(0.58, 0.80, 0.76), under * 0.55);
	col = mix(col, col * vec3(0.72, 0.82, 1.0), night_level * 0.3);
	ALBEDO = col;
}
