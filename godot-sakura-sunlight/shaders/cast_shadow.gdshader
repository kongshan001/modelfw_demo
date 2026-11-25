shader_type canvas_item;

// 地面投影只做一件事：读取剪影 alpha，乘上全局阴影色与强度。
// 影子方向 / 长度 / 分段全部由 GDScript 的节点变换决定，不靠 3D 阴影。

global uniform vec4 u_shadow_color;
global uniform float u_shadow_strength;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = tex.a * u_shadow_color.a * u_shadow_strength * COLOR.a;
	if (a < 0.004) {
		discard;
	}
	COLOR = vec4(u_shadow_color.rgb * COLOR.rgb, a);
}
