shader_type sky;
// 原创雾林天空：垂直渐变 + 太阳辉光 + 月盘/月晕 + 星点 + 地平线雾带。
// 所有参数由 Atmosphere 在昼/夜之间插值。

uniform vec3 zenith_color : source_color = vec3(0.42, 0.55, 0.63);
uniform vec3 horizon_color : source_color = vec3(0.80, 0.81, 0.75);
uniform vec3 ground_color : source_color = vec3(0.09, 0.11, 0.09);
uniform vec3 sun_dir = vec3(0.35, 0.55, 0.25);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.76);
uniform float sun_amount = 0.45;
uniform vec3 moon_dir = vec3(-0.35, 0.62, -0.55);
uniform vec3 moon_color : source_color = vec3(0.78, 0.86, 1.0);
uniform float moon_amount = 0.0;
uniform float moon_size = 0.99935;
uniform float star_amount = 0.0;
uniform float haze_amount = 0.55;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void sky() {
	float up = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, zenith_color, pow(up, 0.55));
	float down = clamp(-EYEDIR.y, 0.0, 1.0);
	col = mix(col, ground_color, smoothstep(0.02, 0.4, down));

	// 太阳：宽雾光 + 窄核，白天不抢戏
	vec3 sdir = normalize(sun_dir);
	float sd = max(dot(EYEDIR, sdir), 0.0);
	col += sun_color * sun_amount * (0.45 * pow(sd, 7.0) + 1.2 * pow(sd, 150.0));

	// 月亮：月盘 + 冷色月晕
	vec3 mdir = normalize(moon_dir);
	float md = max(dot(EYEDIR, mdir), 0.0);
	float disc = smoothstep(moon_size - 0.00030, moon_size + 0.00030, md);
	float halo = 0.30 * pow(md, 26.0) + 0.65 * pow(md, 350.0);
	col = mix(col, moon_color, moon_amount * disc * 0.9);
	col += moon_color * moon_amount * halo * 0.5;

	// 星点：方向哈希，稀疏、轻微闪烁
	if (star_amount > 0.001 && EYEDIR.y > 0.015) {
		vec2 sp = EYEDIR.xz / (EYEDIR.y + 0.25) * 5.2;
		vec2 cell = floor(sp * 6.0);
		vec2 f = fract(sp * 6.0);
		float h = hash12(cell);
		float star = step(0.982, h) * smoothstep(0.42, 0.02, length(f - vec2(0.5 + (h - 0.5) * 0.5)));
		float twinkle = 0.55 + 0.45 * sin(TIME * (0.8 + h * 2.4) + h * 41.0);
		col += vec3(0.72, 0.80, 1.0) * star * star_amount * twinkle * smoothstep(0.0, 0.25, EYEDIR.y);
	}

	// 地平线雾带：与场景雾色衔接
	float haze = exp(-abs(EYEDIR.y) * 8.0) * haze_amount;
	col = mix(col, horizon_color, haze * 0.4);
	COLOR = col;
}
