shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/garden_common.gdshaderinc"

// 风格化体积光柱：锥体侧表面的视向柔边 + 纵向衰减 + 缓慢条带。
// 不是物理体积雾；T-008 会再做更强的丁达尔/offset 补偿。

uniform vec4 shaft_color : source_color = vec4(1.0, 0.68, 0.42, 1.0);
uniform float intensity = 0.5;
uniform float streak_scale = 1.0;
uniform float height = 12.0;
uniform float ground_fade = 0.72;

varying vec3 v_world;
varying float v_h;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_h = clamp(VERTEX.y / max(height, 0.001) + 0.5, 0.0, 1.0);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(facing, 1.8);
	float top_fade = smoothstep(0.0, 0.22, v_h);
	float low_fade = smoothstep(0.0, ground_fade, v_h);
	float fade = top_fade * mix(0.35, 1.0, low_fade);
	float streak = 0.72 + 0.28 * sin(v_world.x * 2.6 + v_world.z * 2.1 + g_time * 0.33);
	streak *= 0.8 + 0.2 * sin(v_world.y * 1.4 - g_time * 0.21 + v_world.x * 0.7);
	ALBEDO = shaft_color.rgb * intensity * edge * fade * streak * streak_scale;
	ALPHA = 1.0;
}
