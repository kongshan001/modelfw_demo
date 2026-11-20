shader_type spatial;

// 天穹：一个从内部观看的大球。程序化晚霞渐变 + 太阳盘/光晕 + 云带 + 星点。
// 刻意做色阶量化，和低分辨率主画面一起形成像素画感。

render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;

uniform vec4 u_zenith : source_color = vec4(0.20, 0.42, 0.66, 1.0);
uniform vec4 u_horizon : source_color = vec4(0.72, 0.84, 0.86, 1.0);
uniform vec4 u_sun_color : source_color = vec4(1.0, 0.85, 0.60, 1.0);
uniform vec4 u_cloud_color : source_color = vec4(0.95, 0.90, 0.86, 1.0);
uniform vec3 u_sun_dir = vec3(-0.52, 0.14, -0.84);
uniform float u_stars = 0.0;
uniform float u_clouds = 0.65;
uniform float u_time = 0.0;

varying vec3 v_dir;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_dir = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD;
}

void fragment() {
	vec3 d = normalize(v_dir);
	float h = d.y;
	vec3 col = mix(u_horizon.rgb, u_zenith.rgb, smoothstep(0.0, 0.60, h));
	if (h < 0.0) {
		col = mix(u_horizon.rgb, u_horizon.rgb * 0.93, smoothstep(0.0, -0.30, h));
	}

	// 太阳光晕 + 像素太阳盘
	float sd = max(dot(d, u_sun_dir), 0.0);
	col += u_sun_color.rgb * (pow(sd, 180.0) * 0.26 + pow(sd, 16.0) * 0.07);
	float disc = smoothstep(0.99962, 0.99982, sd);
	col = mix(col, u_sun_color.rgb * 1.8, disc);

	// 晚霞云带
	float az = atan(d.z, d.x);
	float band = sin(h * 22.0 + sin(az * 2.5 + u_time * 0.02) * 2.0 + az * 0.8);
	float cloud = smoothstep(0.62, 0.98, band)
			* smoothstep(0.30, 0.05, abs(h - 0.12)) * u_clouds;
	col = mix(col, u_cloud_color.rgb, cloud * 0.38);

	// 星点
	vec2 sp = floor(vec2(az * 90.0, h * 160.0));
	float star = step(0.9955, hash12(sp)) * smoothstep(0.04, 0.40, h) * u_stars;
	col += vec3(star) * (0.7 + 0.3 * sin(u_time * 2.0 + hash12(sp) * 6.283));

	// 像素色阶
	col = floor(col * 28.0 + 0.5) / 28.0;
	ALBEDO = col;
}
