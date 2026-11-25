shader_type spatial;
// 原创天幕：程序化星野、淡紫星云、月晕、日晕与轻云带；昼夜共用一层。
// 用 if 分支跳过不活跃的夜间/日间细节，控制 Intel 集显的 fill-rate。
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform float nightness = 1.0;
uniform float rain_amount = 0.0;
uniform float u_time = 0.0;
uniform vec3 moon_dir = vec3(-0.34, 0.68, -0.66);
uniform vec3 night_zenith : source_color = vec3(0.048, 0.048, 0.115);
uniform vec3 night_horizon : source_color = vec3(0.15, 0.15, 0.28);
uniform vec3 day_zenith : source_color = vec3(0.22, 0.41, 0.50);
uniform vec3 day_horizon : source_color = vec3(0.61, 0.74, 0.75);

varying vec3 sky_dir;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.02 + vec2(9.3, 17.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	sky_dir = normalize(VERTEX);
}

void fragment() {
	float h = clamp(sky_dir.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 night_sky = mix(night_horizon, night_zenith, smoothstep(0.40, 0.88, h));
	vec3 day_sky = mix(day_horizon, day_zenith, smoothstep(0.42, 0.93, h));
	vec3 col = mix(day_sky, night_sky, nightness);

	float dayness = 1.0 - nightness;
	float lon = atan(sky_dir.z, sky_dir.x) / 6.2831853 + 0.5;
	float lat = acos(clamp(sky_dir.y, -1.0, 1.0)) / 3.1415926;
	vec2 sp = vec2(lon, lat);

	if (nightness > 0.005) {
		// 淡紫/青绿星云，带缓慢呼吸。
		float neb_a = fbm(sp * vec2(6.2, 3.4) + vec2(u_time * 0.007, 1.8));
		float neb_b = fbm(sp * vec2(3.0, 6.8) + vec2(4.2, -u_time * 0.006));
		float aurora = smoothstep(0.57, 0.83, neb_a * 0.76 + neb_b * 0.42);
		aurora *= smoothstep(0.28, 0.72, h) * (1.0 - smoothstep(0.78, 1.0, h));
		col += vec3(0.19, 0.14, 0.39) * aurora * nightness * 0.46;
		col += vec3(0.06, 0.17, 0.18) * smoothstep(0.62, 0.90, neb_b) * nightness * 0.20;

		// 星野：网格点星 + 柔光。
		vec3 p = sky_dir * 250.0;
		vec3 cell = floor(p);
		vec3 f = fract(p) - 0.5;
		float seed = hash13(cell);
		float star = smoothstep(0.12, 0.006, length(f)) * step(0.976, seed);
		float twinkle = 0.74 + 0.26 * sin(u_time * (1.2 + seed * 2.5) + seed * 28.0);
		star *= (1.0 - rain_amount) * nightness * twinkle;
		vec3 star_col = mix(vec3(0.72, 0.84, 1.0), vec3(1.0, 0.83, 0.60), step(0.70, seed));
		col += star_col * star * 1.7;

		// 月：柔晕 + 清晰弦月。
		float md = dot(sky_dir, normalize(moon_dir));
		float halo = pow(max(md, 0.0), 52.0);
		float disc = smoothstep(0.99935, 0.99972, md);
		float cres = smoothstep(0.9990, 0.99940,
				dot(sky_dir, normalize(moon_dir + vec3(0.026, 0.014, 0.006))));
		disc = max(0.0, disc - cres * 0.82);
		col += vec3(1.0, 0.79, 0.50) * halo * nightness * (1.0 - rain_amount * 0.70) * 0.55;
		col += vec3(1.0, 0.89, 0.68) * disc * nightness * (1.0 - rain_amount * 0.75) * 1.8;
	}

	if (dayness > 0.005) {
		// 白日的暖阳晕。
		vec3 sun_dir = normalize(vec3(0.18, 0.34, -0.92));
		float sd = max(dot(sky_dir, sun_dir), 0.0);
		float sun_halo = pow(sd, 30.0) * 0.34 + pow(sd, 280.0) * 1.9;
		col += vec3(1.0, 0.73, 0.43) * sun_halo * dayness * (1.0 - rain_amount * 0.80);

		// 轻云带。
		float band = smoothstep(0.43, 0.70, fbm(sp * vec2(5.2, 10.0) + vec2(u_time * 0.004, 2.3)));
		band *= smoothstep(0.10, 0.42, h) * (1.0 - smoothstep(0.62, 0.92, h));
		col = mix(col, vec3(0.92, 0.90, 0.81), band * dayness * (1.0 - rain_amount) * 0.18);
	}

	col = mix(col, vec3(0.35, 0.38, 0.44), rain_amount * 0.58);
	if (rain_amount > 0.01) {
		float overcast = smoothstep(0.42, 0.72, fbm(sp * vec2(4.0, 3.0) + u_time * 0.004));
		col = mix(col, col * 0.74 + vec3(0.11, 0.12, 0.16), rain_amount * overcast * 0.42);
	}

	ALBEDO = col;
	ROUGHNESS = 1.0;
}
