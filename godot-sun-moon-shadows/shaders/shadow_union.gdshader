shader_type canvas_item;

// 单一网格的并集阴影：
//   * 所有物体的影子在 CPU 端做成不相交多边形并集，一次 draw；
//   * 同一像素只会被写一次 alpha，重叠树影不会叠黑；
//   * 顶点色 = 投影体高度（0..1），用单通道 R8 高度图做接收面遮挡：
//     低矮物体的影子不会盖到更高物体的屋顶上。
// GL Compatibility 不支持稳定的 R16F 采样，这里使用等价 R8 单通道。

global uniform vec4 u_ambient_sub;

uniform sampler2D height_map : filter_linear, repeat_disable;
uniform float softness : hint_range(0.0, 0.2) = 0.028;
uniform float bias : hint_range(0.0, 0.1) = 0.008;
uniform int debug_mode = 0; // 0 正常；1 高度热力；2 遮挡通过/截断

vec3 heat_color(float h) {
	if (h < 0.25) {
		return mix(vec3(0.10, 0.22, 0.55), vec3(0.10, 0.70, 0.75), h / 0.25);
	}
	if (h < 0.55) {
		return mix(vec3(0.10, 0.70, 0.75), vec3(0.95, 0.88, 0.30), (h - 0.25) / 0.30);
	}
	return mix(vec3(0.95, 0.88, 0.30), vec3(0.95, 0.28, 0.24), (h - 0.55) / 0.45);
}

void fragment() {
	float receiver_h = texture(height_map, SCREEN_UV).r;
	float caster_h = COLOR.r;
	// 接收面越低，越容易被投影覆盖；高屋顶 / 高草丛会截断矮影。
	float pass_mask = smoothstep(receiver_h + bias - softness,
			receiver_h + bias + softness, caster_h);
	if (pass_mask <= 0.001) {
		discard;
	}
	float a = u_ambient_sub.a * pass_mask;
	if (debug_mode == 1) {
		COLOR = vec4(heat_color(caster_h), 0.88 * pass_mask);
	} else if (debug_mode == 2) {
		COLOR = vec4(heat_color(receiver_h), 0.78 * pass_mask);
	} else {
		COLOR = vec4(u_ambient_sub.rgb, a);
	}
}
