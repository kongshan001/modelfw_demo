shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/common.gdshaderinc"

// 水下光柱：竖直方向的加色四边形，水面上几乎不可见，水下渐显。
uniform vec4 beam_color : source_color = vec4(0.68, 0.94, 0.93, 1.0);
uniform float intensity = 0.3;
uniform vec2 shaft_seed = vec2(1.7, 3.1);

varying vec2 v_uv;
varying vec3 v_world;

void vertex() {
	v_uv = UV;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	POSITION = snap_clip(PROJECTION_MATRIX * VIEW_MATRIX * vec4(v_world, 1.0));
}

void fragment() {
	float side = 1.0 - smoothstep(0.15, 0.5, abs(v_uv.x - 0.5));
	float vertical = smoothstep(0.0, 0.35, v_uv.y) * (1.0 - smoothstep(0.75, 1.0, v_uv.y));
	float streak = 0.55 + 0.45 * value_noise(vec2(v_uv.x * 7.0 + shaft_seed.x, v_uv.y * 3.0 - g_time * 0.25 + shaft_seed.y));
	float shimmer = 0.75 + 0.25 * sin(g_time * 0.8 + shaft_seed.x * 4.0 + v_uv.y * 5.0);
	float vis = mix(0.3, 1.5, smoothstep(0.0, 0.6, g_underwater));
	ALBEDO = beam_color.rgb * side * vertical * streak * shimmer * intensity * vis;
	ALPHA = clamp(side * vertical * streak * intensity * vis, 0.0, 1.0);
}
