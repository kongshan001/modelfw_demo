shader_type canvas_item;

// 所有实体精灵（房屋、树、石柱、路灯、角色、远山）共用这一份材质。
// 只读取 3 个工程级 shader 全局向量：方向 / 光色 / 环境光扣除量。
// 没有任何逐物体灯光参数，也没有 Light2D。

global uniform vec4 u_light_dir;
global uniform vec4 u_light_color;
global uniform vec4 u_ambient_sub;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.02) {
		discard;
	}
	float night = clamp(u_light_dir.w, 0.0, 1.0);
	vec3 day_ambient = vec3(0.70, 0.74, 0.78);
	vec3 night_ambient = vec3(0.15, 0.23, 0.39);
	vec3 ambient = mix(day_ambient, night_ambient, night);
	vec3 light = u_light_color.rgb * u_light_color.a;
	float direct = mix(0.52, 0.44, night);
	vec3 col = tex.rgb * (ambient * mix(1.0, 0.86, night) + light * direct);
	// 环境扣除量也参与夜景的冷色收束，保证 3 个全局量在所有实体上都有意义。
	vec3 removal = mix(vec3(1.0), u_ambient_sub.rgb * 2.2, 0.10 * night);
	col *= removal;
	// 轻微方向感：朝光侧亮一点。
	vec2 nd = normalize(vec2(0.55, 0.35));
	float sheen = dot(nd, -normalize(u_light_dir.xy + vec2(0.0001))) * 0.055;
	col *= 1.0 + sheen;
	col = mix(col, col * vec3(0.86, 0.94, 1.08), night * 0.35);
	COLOR = vec4(col, tex.a);
}
