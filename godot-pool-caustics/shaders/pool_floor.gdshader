shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// 池底：程序化卵石河床纹理 + 世界坐标焦散光网 + 圆石投影 + 水色衰减。
// 焦散核心来自 caustics.gdshaderinc，与圆石共用同一套 F1/F2 距离场。

#include "res://shaders/caustics.gdshaderinc"

uniform sampler2D u_bed_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 u_floor_extent = vec2(30.0, 22.0);
uniform vec3 u_floor_tint : source_color = vec3(0.78, 0.92, 0.88);
uniform vec3 u_deep_tint : source_color = vec3(0.015, 0.085, 0.092);
uniform vec4 u_rock_shadows[8];
uniform int u_rock_count = 0;
uniform float u_grain = 0.055;

varying vec3 v_world;
varying vec2 v_uv;

void vertex() {
	// 边缘缓慢下沉，形成浅浅的石盆；细分足够所以不用法线照明。
	float rx = VERTEX.x / max(u_floor_extent.x * 0.5, 0.001);
	float rz = VERTEX.z / max(u_floor_extent.y * 0.5, 0.001);
	float r = length(vec2(rx, rz));
	VERTEX.y -= smoothstep(0.42, 1.0, r) * 0.72;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_uv = UV;
}

void fragment() {
	vec3 bed = texture(u_bed_texture, v_uv).rgb * u_floor_tint;

	// 低幅度世界噪声，打散贴图放大后的平整感。
	float fine = caustic_noise(v_world.xz * 4.7);
	float broad = caustic_noise(v_world.xz * 0.83 + vec2(2.7, 9.1));
	bed *= 0.88 + 0.12 * broad;
	bed += vec3(0.018, 0.035, 0.032) * (fine - 0.5);

	// 池边变深，藏住平面边界并让视觉集中在光网。
	vec2 pool_p = v_world.xz / (u_floor_extent * 0.5);
	float edge = smoothstep(0.44, 0.96, length(pool_p));
	bed = mix(bed, u_deep_tint, edge * 0.76);

	// 圆石底部软阴影：用少量世界空间圆盘，避免真实阴影贴图开销。
	for (int i = 0; i < 8; i++) {
		if (i >= u_rock_count) {
			break;
		}
		vec4 s = u_rock_shadows[i];
		vec2 center = s.xy + vec2(0.28, -0.16) * s.z;
		float d = length((v_world.xz - center) / vec2(1.0, 0.82)) - s.z;
		float shade = 1.0 - smoothstep(-s.z * 0.28, s.z * 0.62, d);
		bed *= 1.0 - clamp(shade, 0.0, 1.0) * 0.48 * s.w;
	}

	CausticField c = caustic_fields(v_world.xz, u_time);
	vec3 col = caustic_composite(c, bed);

	// 极轻微的球面感：中心更亮，边缘更暗。
	col *= 0.88 + 0.12 * (1.0 - edge);

	// 8-bit 渐变抖动，避免大面积光晕出现色带。
	float dither = (caustic_hash12(FRAGCOORD.xy + 3.7) - 0.5) * 0.006;
	ALBEDO = max(col + dither * u_grain, vec3(0.0));
}
