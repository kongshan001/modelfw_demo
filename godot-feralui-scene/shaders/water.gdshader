shader_type spatial;
// 原创池水（unshaded 风格化）：固定调和色、慢波、月光碎银与岸边暖灯倒影。
// 不参与实时光照，可避免在低端显卡上出现大面积高光带状伪影，也更贴合参考的绘本质感。
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float u_time = 0.0;
uniform float rain_amount = 0.0;
uniform float wave_scale = 0.72;
uniform vec3 deep_color : source_color = vec3(0.028, 0.120, 0.125);
uniform vec3 shallow_color : source_color = vec3(0.08, 0.36, 0.32);
uniform vec3 sky_color : source_color = vec3(0.10, 0.28, 0.36);
uniform vec3 glint_color : source_color = vec3(1.0, 0.84, 0.55);
uniform vec3 warm_light_pos = vec3(6.8, 1.0, 0.15);
uniform vec3 warm_color : source_color = vec3(1.0, 0.38, 0.08);
uniform float warm_strength = 0.7;
uniform float glint_strength = 0.65;

varying vec3 world_pos;
varying vec2 pond_uv;

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
	for (int i = 0; i < 3; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + vec2(13.7, 7.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pond_uv = UV;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = u_time * 0.52;
	float n1 = fbm(p * wave_scale + vec2(t * 0.18, -t * 0.14));
	float n2 = fbm(p * (wave_scale * 2.15) + vec2(-t * 0.09, t * 0.23));
	float n = n1 * 0.72 + n2 * 0.28;

	vec2 eps = vec2(0.06, 0.0);
	float nx = fbm((p + eps.xy) * wave_scale + vec2(t * 0.18, -t * 0.14)) - n1;
	float nz = fbm((p + eps.yx) * wave_scale + vec2(t * 0.18, -t * 0.14)) - n1;
	vec3 nrm = normalize(vec3(nx * 3.1, 1.0, nz * 3.1));

	float ribbons = sin(p.x * 0.95 + p.y * 0.36 + t * 0.50 + n * 3.4) * 0.5 + 0.5;
	ribbons = pow(ribbons, 4.0) * 0.08;

	// 雨环
	vec2 rp = p * 1.35;
	vec2 cell = floor(rp);
	vec2 rf = fract(rp) - 0.5;
	float rr = hash21(cell);
	float rphase = fract(u_time * (0.33 + rr * 0.25) + rr);
	float ring = smoothstep(0.042, 0.0, abs(length(rf) - rphase * 0.44));
	ring *= (1.0 - rphase) * rain_amount;

	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fres = pow(1.0 - clamp(dot(view_dir, nrm), 0.0, 1.0), 2.0);
	vec3 col = mix(deep_color, shallow_color, smoothstep(0.20, 0.82, n));
	col = mix(col, sky_color, fres * 0.30);
	col += shallow_color * ribbons;

	// 月光/暮光的碎银。
	float spec = pow(max(dot(nrm, normalize(view_dir + vec3(-0.25, 0.72, -0.44))), 0.0), 64.0)
			* glint_strength;
	col += glint_color * spec * 0.60;
	float stars = step(0.992, hash21(floor(p * vec2(13.0, 12.0)) + floor(t * 2.0)));
	col += glint_color * stars * (0.10 + 0.28 * n2) * glint_strength;

	// 岸边苔灯的暖倒影。
	vec3 to_lamp = warm_light_pos - world_pos;
	float lamp_dist = length(to_lamp.xz);
	float warm_fall = exp(-lamp_dist * 0.52) * warm_strength;
	vec3 lamp_dir = normalize(to_lamp);
	vec3 half_dir = normalize(view_dir + lamp_dir);
	float warm_glint = pow(max(dot(nrm, half_dir), 0.0), 28.0) * warm_fall;
	col += warm_color * (warm_fall * 0.12 + warm_glint * 0.55);

	col += glint_color * ring * 0.26;

	float edge = smoothstep(1.0, 0.62, length(pond_uv - vec2(0.5)) * 2.0);
	float foam = smoothstep(0.78, 0.98, length(pond_uv - vec2(0.5)) * 2.0);
	col += vec3(0.50, 0.58, 0.48) * foam * 0.045;
	ALBEDO = col;
	ALPHA = clamp(0.83 + rain_amount * 0.05, 0.0, 0.94) * mix(1.0, edge, 0.30);
}
