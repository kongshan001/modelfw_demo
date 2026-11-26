shader_type canvas_item;

// 地面共用同一组 3 个全局向量；只多一点点低角度侧光 sheen。
// 地表的路径、苔痕、野花已经烘焙在程序化像素图里。

global uniform vec4 u_light_dir;
global uniform vec4 u_light_color;
global uniform vec4 u_ambient_sub;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.02) {
		discard;
	}
	float night = clamp(u_light_dir.w, 0.0, 1.0);
	float elev01 = clamp(u_light_dir.z, 0.0, 1.0);
	vec3 day_ambient = vec3(0.68, 0.73, 0.66);
	vec3 night_ambient = vec3(0.12, 0.19, 0.32);
	vec3 ambient = mix(day_ambient, night_ambient, night);
	vec3 light = u_light_color.rgb * u_light_color.a;
	vec3 col = tex.rgb * (ambient + light * mix(0.46, 0.72, 1.0 - elev01));
	vec2 ldir = normalize(u_light_dir.xy + vec2(0.0001, 0.0001));
	float sheen = dot((UV - vec2(0.5, 0.56)) * vec2(1.0, 0.55), ldir);
	col *= 1.0 + sheen * mix(0.08, 0.16, 1.0 - elev01);
	col *= mix(vec3(1.0), u_ambient_sub.rgb * 2.4, 0.06 * night);
	COLOR = vec4(col, tex.a);
}
