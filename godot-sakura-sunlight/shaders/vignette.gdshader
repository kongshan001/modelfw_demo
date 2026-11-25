shader_type canvas_item;

// 固定机位的轻微暗角：压住四角、把视线收进庭院中心。
// 与太阳模型无关，放在世界层最上方（调试叠加层之下）。

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p * vec2(0.86, 1.04));
	float edge = smoothstep(0.58, 1.18, d);
	COLOR = vec4(0.020, 0.055, 0.035, edge * 0.32);
}
