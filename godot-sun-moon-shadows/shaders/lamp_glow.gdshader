shader_type canvas_item;
render_mode blend_add;

// 局部路灯 / 窗光的加法层。它在阴影网格之后绘制：
// 暖灯只往画面里加暖色，不会乘到冷蓝月影上；月影也不会改变灯光的色相。
// 灯的位置/半径属于局部光源参数，与日月主光通道分开。

uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.32, 1.0);
uniform float intensity : hint_range(0.0, 1.5) = 0.55;
uniform float flicker : hint_range(0.0, 0.3) = 0.05;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float f = 1.0 + flicker * sin(TIME * 6.3 + UV.x * 17.0 + UV.y * 9.0);
	float a = tex.a * intensity * clamp(f, 0.0, 1.5);
	COLOR = vec4(glow_color.rgb * a, a);
}
