shader_type canvas_item;

// 树冠 / 树干 / 草 / 花 / 石头 / 花瓣共用同一个 shader。
// 每个物体不需要任何专属光照参数：受光面由全局 u_sun_dir 与 UV 决定的
// 伪法线算出，颜色从全局 u_sun_color / u_ambient_color 取得。

global uniform vec2 u_sun_dir;
global uniform float u_sun_elevation;
global uniform vec4 u_sun_color;
global uniform vec4 u_ambient_color;
global uniform float u_sun_intensity;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.03) {
		discard;
	}

	// 顶点色 × 贴图：MultiMesh 的 instance color 也会在这里乘进来。
	vec3 base = tex.rgb * COLOR.rgb;
	float alpha = tex.a * COLOR.a;

	// 用精灵内部方向当伪法线：右上/左上侧的边缘分别接住上午/下午的面光。
	vec2 n2 = UV * 2.0 - 1.0;
	float ndl = dot(normalize(n2 + vec2(0.0001, 0.0001)), normalize(u_sun_dir));
	float facing = clamp(0.5 + 0.5 * ndl, 0.0, 1.0);

	float elev01 = clamp(u_sun_elevation / 90.0, 0.0, 1.0);
	vec3 ambient = u_ambient_color.rgb * (0.33 + 0.05 * elev01);
	float direct_power = u_sun_intensity * (0.44 + 0.26 * elev01)
			* mix(0.54, 1.0, facing);
	vec3 direct = u_sun_color.rgb * direct_power;
	vec3 col = base * (ambient + direct);

	// 背光面压向冷色，和暖色受光面对比。
	col = mix(col, col * vec3(0.86, 0.92, 1.10), (1.0 - facing) * 0.30);
	// 受光边缘一点暖色轮廓。
	col += u_sun_color.rgb * pow(facing, 5.0) * 0.035 * (0.35 + elev01);
	// 白色樱花 / 花瓣高光：让亮部在阴影侧也保持“发光”的观感。
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float high = smoothstep(0.62, 0.90, lum);
	col += u_sun_color.rgb * high * 0.10;

	COLOR = vec4(col, alpha);
}
