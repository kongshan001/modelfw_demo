// 低模礁石：顶点色 + 手绘方向光（不依赖引擎灯光），保持参考里的白灰岩面与青苔块。
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 sun_dir = vec3(-0.45, 0.85, -0.25);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.99, 0.96);
uniform vec3 shade_tint : source_color = vec3(0.62, 0.72, 0.84);
uniform float light_level = 1.0;

varying vec3 v_col;
varying vec3 v_nrm;

void vertex() {
	v_col = COLOR.rgb;
	v_nrm = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	float ndl = clamp(dot(normalize(v_nrm), normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 tint = mix(shade_tint, sun_tint, pow(ndl, 1.15));
	ALBEDO = v_col * tint * light_level;
}
