shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/common.gdshaderinc"

// 法线调试：用材质覆盖输出 view-space normal 的 RGB。
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	POSITION = snap_clip(PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
	ALBEDO = normalize(NORMAL) * 0.5 + 0.5;
}
