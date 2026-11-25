shader_type canvas_item;

// 地面只靠全局太阳参数上色：没有 Light2D / 3D 灯光。
// 光色、环境色、强度、方向都由 RenderingServer.global_shader_parameter_set 同步。

global uniform vec2 u_sun_dir;
global uniform float u_sun_elevation;
global uniform vec4 u_sun_color;
global uniform vec4 u_ambient_color;
global uniform float u_sun_intensity;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.02) {
		discard;
	}

	float elev01 = clamp(u_sun_elevation / 90.0, 0.0, 1.0);
	// 低角度侧光让地面有一点点方向感；正午更均匀。
	float sheen = dot(vec2(UV.x - 0.5, (0.5 - UV.y) * 0.35), normalize(u_sun_dir));
	float light = clamp(0.80 + 0.20 * elev01 + 0.05 * sheen, 0.0, 1.08);

	vec3 ambient = u_ambient_color.rgb * 0.36;
	vec3 direct = u_sun_color.rgb * u_sun_intensity * 0.70 * light;
	vec3 col = tex.rgb * (ambient + direct);
	// 低太阳角时给草地一点点暖金，正午回到中性。
	col *= mix(vec3(1.0), u_sun_color.rgb, 0.06 * (1.0 - elev01));
	COLOR = vec4(col, tex.a);
}
