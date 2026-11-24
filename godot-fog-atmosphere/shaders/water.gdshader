shader_type spatial;
// 原创雾林浅潭：程序化波法线 + 菲涅耳 + 太阳高光 + 精灵微光 + 环境雾。
// 渲染方式沿用 GL Compatibility；环境深度/高度雾由 WorldEnvironment 自动叠在本材质上。
render_mode diffuse_lambert, specular_disabled;

uniform vec4 deep_color : source_color = vec4(0.020, 0.055, 0.055, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.055, 0.13, 0.115, 1.0);
uniform vec4 sky_color : source_color = vec4(0.17, 0.27, 0.29, 1.0);
uniform vec4 sky_top_color : source_color = vec4(0.40, 0.53, 0.62, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.82, 0.80, 0.70, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.92, 0.78, 1.0);
uniform vec3 sun_dir = vec3(0.35, 0.7, 0.25);
uniform float sun_energy = 0.8;
uniform vec3 camera_pos = vec3(0.0, 10.0, 15.0);
uniform vec3 wisp_pos = vec3(10.0, 1.4, 6.0);
uniform vec4 wisp_color : source_color = vec4(0.42, 0.85, 0.90, 1.0);
uniform float wisp_strength = 0.3;
uniform float wave_strength = 0.22;
uniform float wave_speed = 1.0;

varying vec3 v_world;

float wave_height(vec2 p, float t) {
	float h = sin(p.x * 0.85 + t * 0.9) * 0.5;
	h += sin(p.y * 1.35 - t * 0.7) * 0.35;
	h += sin((p.x + p.y) * 1.9 + t * 1.3) * 0.18;
	h += sin((p.x - p.y * 0.7) * 3.3 - t * 1.7) * 0.08;
	return h;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = v_world.xz;
	float h0 = wave_height(p, t);
	float hx = wave_height(p + vec2(0.18, 0.0), t);
	float hz = wave_height(p + vec2(0.0, 0.18), t);
	vec3 n = normalize(vec3((h0 - hx) * wave_strength * 5.0, 1.0, (h0 - hz) * wave_strength * 5.0));

	vec3 view_dir = normalize(camera_pos - v_world);
	float facing = clamp(dot(view_dir, n), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(0.5 + h0 * 0.35, 0.0, 1.0));
	vec3 rdir = reflect(-view_dir, n);
	vec3 sky_refl = mix(sky_horizon_color.rgb, sky_top_color.rgb, smoothstep(0.0, 0.55, rdir.y));
	sky_refl = mix(sky_refl, sky_color.rgb, 0.35);
	col = mix(col, sky_refl, fresnel * 0.55);

	// 太阳镜面高光
	vec3 r = reflect(-view_dir, n);
	float spec = pow(max(dot(r, normalize(sun_dir)), 0.0), 140.0);
	col += sun_color.rgb * spec * sun_energy * 0.45;

	// 精灵在雾潭上的微光（位置由主控每帧写入）
	float wdist = distance(v_world, wisp_pos);
	float wglow = exp(-wdist * 0.85) * wisp_strength;
	col += wisp_color.rgb * wglow * (0.25 + 0.18 * sin(TIME * 1.7 + wdist * 2.0));
	float ripple = sin(wdist * 5.0 - TIME * 1.8) * exp(-wdist * 0.30) * 0.035;
	col += vec3(0.30, 0.44, 0.42) * ripple;

	// 细碎波光
	float sparkle = step(0.996, hash12(floor(p * 9.0) + floor(t * 2.0)));
	col += vec3(0.65, 0.82, 0.78) * sparkle * 0.16 * fresnel;

	ALBEDO = col;
	ROUGHNESS = 0.35;
	EMISSION = sun_color.rgb * spec * sun_energy * 0.35 + wisp_color.rgb * wglow * 0.25;
}
