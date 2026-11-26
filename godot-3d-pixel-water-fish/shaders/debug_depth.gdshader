shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/common.gdshaderinc"

// 深度调试：材质覆盖后输出 view-space 距离热力图。
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	POSITION = snap_clip(PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
	float t = clamp(-VERTEX.z / 26.0, 0.0, 1.0);
	vec3 col = mix(vec3(0.98, 0.86, 0.32), vec3(0.07, 0.18, 0.45), t);
	col = mix(col, vec3(0.02, 0.05, 0.08), smoothstep(0.82, 1.0, t) * 0.35);
	col *= 0.9 + 0.1 * step(0.5, fract(-VERTEX.z * 1.2));
	ALBEDO = col;
}
