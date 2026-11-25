shader_type canvas_item;
render_mode unshaded, blend_mix;

// 72 组双环涟漪：一张 32×32 双环贴图 + MultiMesh（1 draw call）。
// 每个实例由 CPU 更新年龄/尺寸/透明度；shader 只负责用统一 puddle mask 裁切。

uniform sampler2D u_field : filter_nearest, repeat_disable;
uniform float u_waterline = 0.32;
uniform float u_on = 1.0;

#include "res://shaders/water_mask.gdshaderinc"

void fragment() {
	vec4 f = texture(u_field, SCREEN_UV);
	float water = rp_water_mask(f, u_waterline);
	vec4 tex = texture(TEXTURE, UV);
	float a = tex.a * COLOR.a * water * u_on;
	COLOR = vec4(tex.rgb * COLOR.rgb, a);
}
