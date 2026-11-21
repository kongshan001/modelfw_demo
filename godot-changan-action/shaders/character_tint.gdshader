shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// 原创角色色键：保留 CC0 KayKit 贴图的明暗/五官细节，只旋转色相到本作角色色。
// 这样 4 个原创角色（沈灯/阿禾/闻九/霍三更）与 3 种敌人有清晰色键，
// 同时不复制任何原作者的贴图/造型。

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform float target_hue = 0.60;
uniform float hue_mix = 0.88;
uniform float saturation = 1.05;
uniform float value_scale = 1.10;
uniform vec4 rim_color : source_color = vec4(1.0, 0.70, 0.30, 1.0);
uniform float rim_strength = 0.38;
uniform float emission_strength = 0.10;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	vec3 hsv = rgb2hsv(tex.rgb);
	float dh = target_hue - hsv.x;
	dh = mod(dh + 1.5, 1.0) - 0.5;
	hsv.x = mod(hsv.x + dh * hue_mix, 1.0);
	hsv.y = clamp(hsv.y * saturation, 0.0, 1.0);
	hsv.z = clamp(hsv.z * value_scale, 0.0, 1.0);
	vec3 col = hsv2rgb(hsv);
	ALBEDO = col;
	ROUGHNESS = 0.80;
	METALLIC = 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	EMISSION = col * emission_strength + rim_color.rgb * rim * rim_strength;
}
