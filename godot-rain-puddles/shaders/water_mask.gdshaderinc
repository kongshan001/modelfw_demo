#ifndef RAIN_PUDDLE_MASK
#define RAIN_PUDDLE_MASK

// 统一水洼裁切：水面、涟漪、倒影都走这一份同构函数。
// field: R=高度, G=大占地遮挡, B=灯柱格, A=边缘噪声。
// 与 scripts/puddle_field.gd 的 mask_from_texel() 参数保持一致。
const float RP_EDGE_SOFT = 0.010;
const float RP_EDGE_JITTER = 0.010;

float rp_depth(vec4 f, float waterline) {
	return waterline - f.r + (f.a - 0.5) * RP_EDGE_JITTER;
}

float rp_water_mask(vec4 f, float waterline) {
	float d = rp_depth(f, waterline);
	return smoothstep(0.0, RP_EDGE_SOFT, d) * (1.0 - f.g);
}

float rp_damp_mask(vec4 f, float waterline) {
	return smoothstep(0.080, 0.0, abs(rp_depth(f, waterline))) * (1.0 - f.g);
}

#endif
