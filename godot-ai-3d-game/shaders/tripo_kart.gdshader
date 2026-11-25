shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Tripo 卡丁车共用同一张图生贴图；用贴图的色块做蒙版，把奶油/青色/深海军蓝
// 替换成每辆车的 body/accent/dark 三色，保留 Tripo 几何与少量烘焙明暗。
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 body_color : source_color = vec3(1.0, 0.94, 0.82);
uniform vec3 accent_color : source_color = vec3(0.14, 0.83, 0.82);
uniform vec3 dark_color : source_color = vec3(0.125, 0.20, 0.27);

void fragment() {
	vec3 tex = texture(albedo_tex, UV).rgb;
	float lum = dot(tex, vec3(0.299, 0.587, 0.114));
	float teal = smoothstep(0.10, 0.28, tex.b - tex.r);
	float dark = 1.0 - smoothstep(0.26, 0.40, lum);
	vec3 painted = mix(body_color, accent_color, teal);
	painted = mix(painted, dark_color, dark);
	float shade = clamp(lum * 1.12, 0.72, 1.06);
	ALBEDO = painted * shade;
	ROUGHNESS = 0.74;
	METALLIC = 0.0;
}
