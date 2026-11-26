// 项目共用全局 uniform 与程序化函数。
// 所有颜色/图案均为本项目原创公式，不复制参考视频或 t3ssel8r 的 shader。

global uniform float g_time;
global uniform float g_light_steps;
global uniform float g_pixel_snap;
global uniform float g_res_x;
global uniform float g_res_y;
global uniform float g_underwater;
global uniform float g_rain;
global uniform float g_caustics;
global uniform float g_sun_dir_x;
global uniform float g_sun_dir_y;
global uniform float g_sun_dir_z;
global uniform vec4 g_sun_color;
global uniform vec4 g_sky_color;
global uniform vec4 g_fog_color;
global uniform float g_fog_density;

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

// 廉价水焦散：两套互相干涉的正弦网，用幂次收窄成亮线。
float caustic_pattern(vec2 p, float t) {
	vec2 q = p * 1.15;
	float a = sin(q.x * 2.1 + t * 0.9 + sin(q.y * 1.3) * 1.1);
	float b = sin(q.y * 2.4 - t * 0.7 + cos(q.x * 1.7) * 1.1);
	float web = pow(1.0 - clamp(abs(a + b) * 0.5, 0.0, 1.0), 4.0);
	float a2 = sin((q.x - q.y) * 3.2 - t * 1.25);
	float b2 = sin((q.x + q.y) * 2.7 + t * 0.8);
	float web2 = pow(1.0 - clamp(abs(a2 + b2) * 0.5, 0.0, 1.0), 6.0);
	return clamp(web * 0.65 + web2 * 0.5, 0.0, 1.0);
}

// 顶点吸附到虚拟像素网格（t3ssel8r 风格像素稳定的自写实现）。
vec4 snap_clip(vec4 clip) {
	if (g_pixel_snap > 0.5) {
		vec2 grid = vec2(g_res_x, g_res_y) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	return clip;
}

// 4×4 Bayer，返回 -0.5..0.5。
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

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 fog_mix(vec3 c, float dist) {
	float density = mix(0.005, g_fog_density, clamp(g_underwater, 0.0, 1.0));
	float f = 1.0 - exp(-dist * density);
	return mix(c, g_fog_color.rgb, clamp(f, 0.0, 0.9));
}
