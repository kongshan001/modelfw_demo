// 暮色回廊 · 公共全局 uniform 与程序化函数（全部原创）。
global uniform float g_time;
global uniform float g_cloud_x;
global uniform float g_cloud_z;
global uniform float g_cloud_shadow;
global uniform vec4 g_fog_color;
global uniform float g_fog_density;
global uniform float g_night;
global uniform float g_wind;
global uniform vec4 g_sky_top;
global uniform vec4 g_sky_mid;
global uniform vec4 g_sky_horizon;
global uniform vec4 g_light_color;
global uniform vec4 g_lamp_warmth;
global uniform float g_star;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm2(vec2 p) {
	float v = value_noise(p) * 0.62;
	v += value_noise(p * 2.13 + vec2(7.1, 3.7)) * 0.26;
	v += value_noise(p * 4.31 + vec2(1.9, 8.3)) * 0.12;
	return v;
}

float bayer4(vec2 frag) {
	int x = int(mod(frag.x, 4.0));
	int y = int(mod(frag.y, 4.0));
	float m[16] = {
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0
	};
	return m[y * 4 + x] / 16.0 - 0.5;
}

float luma3(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// 手工距离雾：GL Compatibility 下不依赖环境体积雾。
vec3 garden_fog(vec3 c, float dist) {
	float f = 1.0 - exp(-dist * g_fog_density);
	return mix(c, g_fog_color.rgb, clamp(f, 0.0, 0.92));
}
