shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

#include "res://shaders/garden_common.gdshaderinc"

// 原创程序化天穹：黄昏渐变、低空太阳、月盘、星点、两层流动云。
// 放在半径 90m 的翻转球上，不依赖 Sky 资源与环境雾。

uniform vec3 sun_dir = vec3(0.3, 0.25, -0.9);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.62, 0.32);
uniform float sun_strength = 1.0;
uniform vec3 moon_dir = vec3(-0.4, 0.55, 0.7);
uniform float moon_strength = 0.0;
uniform vec3 cloud_highlight : source_color = vec3(0.95, 0.7, 0.55);
uniform float cloud_density = 0.7;
uniform vec3 sky_ground : source_color = vec3(0.05, 0.06, 0.08);

varying vec3 v_dir;

void vertex() {
	v_dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(v_dir);
	float h = clamp(d.y, -1.0, 1.0);

	// 三层天光渐变：地平线 → 中层 → 天顶。
	vec3 sky = mix(g_sky_horizon.rgb, g_sky_mid.rgb, smoothstep(0.0, 0.42, h));
	sky = mix(sky, g_sky_top.rgb, smoothstep(0.26, 0.88, h));
	sky = mix(sky_ground.rgb, sky, smoothstep(-0.22, 0.06, h));

	// 低空暖霾，让黄昏的过渡更厚。
	float haze = smoothstep(0.34, 0.0, abs(h)) * 0.22;
	sky = mix(sky, g_sky_horizon.rgb * 1.08, haze);

	// 太阳：低角度大光晕 + 小亮盘。
	float sd = max(dot(d, normalize(sun_dir)), 0.0);
	vec3 sun_col = sun_glow_color * sun_strength;
	sky += sun_col * pow(sd, 3.0) * 0.10;
	sky += sun_col * pow(sd, 18.0) * 0.30;
	sky += sun_col * pow(sd, 180.0) * 0.85;
	float sun_disc = smoothstep(0.99970, 0.99986, sd);
	sky += sun_col * sun_disc * 1.8;

	// 月亮：冷色亮盘 + 环形柔光；强度由时间驱动。
	float md = max(dot(d, normalize(moon_dir)), 0.0);
	vec3 moon_col = vec3(0.82, 0.88, 1.0);
	float moon_disc = smoothstep(0.99972, 0.99986, md);
	vec3 moon_up = normalize(cross(vec3(0.0, 1.0, 0.0), normalize(moon_dir)));
	vec3 moon_right = normalize(cross(normalize(moon_dir), moon_up));
	vec2 mp = vec2(dot(d, moon_up), dot(d, moon_right)) * 95.0;
	float craters = value_noise(mp * 1.7) * 0.35 + value_noise(mp * 4.3) * 0.18;
	sky += moon_col * moon_disc * (0.85 + craters) * moon_strength * 2.2;
	sky += moon_col * pow(md, 42.0) * moon_strength * 0.22;

	// 星星：球面哈希网格 + 独立闪烁，仅夜空可见。
	vec2 sph = vec2(atan(d.z, d.x) * 0.1591549, asin(clamp(d.y, -1.0, 1.0)) * 0.3183099);
	vec2 star_grid = sph * vec2(150.0, 96.0) * 2.0;
	vec2 cell = floor(star_grid);
	vec2 sf = fract(star_grid) - 0.5;
	float sh = hash12(cell + vec2(7.0, 3.0));
	float star = step(0.9855, sh) * smoothstep(0.16, 0.015, length(sf));
	float tw = 0.62 + 0.38 * sin(g_time * (0.7 + sh * 2.6) + sh * 41.0);
	float star_vis = g_star * smoothstep(0.015, 0.22, d.y) * (1.0 - smoothstep(0.2, 0.62, haze));
	sky += mix(vec3(0.72, 0.84, 1.0), vec3(1.0, 0.9, 0.76), sh) * star * tw * star_vis * 1.1;

	// 两层流动云：近地平线拉伸，夜间变暗并让星月透过稀薄处。
	vec2 cuv = d.xz / (0.30 + max(d.y, 0.012)) * 0.80
		+ vec2(g_cloud_x, g_cloud_z) * 0.05;
	float n1 = fbm2(cuv * 1.55 + vec2(2.3, 7.1));
	float n2 = fbm2(cuv * 2.9 + vec2(11.0, -4.0) - vec2(g_cloud_x, g_cloud_z) * 0.028);
	float cl = smoothstep(0.48, 0.76, n1 * 0.72 + n2 * 0.38);
	float cloud_band = smoothstep(0.055, 0.22, d.y) * (1.0 - smoothstep(0.62, 0.98, d.y));
	cl *= cloud_band * cloud_density;

	vec3 cloud_col = mix(g_sky_horizon.rgb * 1.10, cloud_highlight.rgb * (0.75 + 0.35 * g_night), 0.55);
	cloud_col = mix(cloud_col, g_sky_top.rgb * 0.55, smoothstep(0.35, 0.9, h) * 0.65);
	// 云边受落日/月光染色。
	cloud_col += sun_col * pow(sd, 6.0) * 0.22;
	cloud_col += moon_col * moon_strength * pow(md, 20.0) * 0.12;
	sky = mix(sky, cloud_col, clamp(cl * 0.78, 0.0, 0.85));

	// 月/星/日的高光在云后再轻微补一层，表现散射。
	sky += sun_col * pow(sd, 8.0) * (1.0 - cl * 0.65) * 0.12;
	sky += moon_col * pow(md, 30.0) * moon_strength * (1.0 - cl * 0.8) * 0.10;

	ALBEDO = sky;
}
