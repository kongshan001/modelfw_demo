// 风格化海面：Gerstner 波 + 深度色阶 + 岸距场泡沫 + 焦散 + 卡通日光 + 鼠标/雨滴涟漪。
// 浅水使用真透明（alpha 随水深上升），沙底由地形真实透出；岸线泡沫/湿沙/接触带共用
// 同一张 1024² 岸距场（SDF）纹理，保证交界不错位。颜色按参考帧逐帧对照调参（见 docs/TECH.md）。
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled, specular_disabled;

uniform sampler2D height_map : filter_linear, repeat_disable;
uniform float height_area = 180.0;
uniform float max_depth = 12.0;

// R = 有符号岸距（0.5 = 水线，±8 m），G = 道具接触掩码，B = 泡沫宽度系数，A = 拍岸相位
uniform sampler2D shore_map : filter_linear, repeat_disable;
uniform float shore_area = 180.0;
uniform float shore_range = 16.0;

uniform sampler2D foam_tex : filter_linear, repeat_enable;
uniform sampler2D detail_tex : filter_linear, repeat_enable;
uniform sampler2D caustic_tex : filter_linear, repeat_enable;

uniform float time = 0.0;

// x,z = 方向, z(第三分量)=振幅, w=波长
uniform vec4 waves[6];
uniform int wave_count = 5;
uniform float wave_height = 0.72;
uniform float wave_speed = 1.0;
uniform float wave_dir = 0.0;

uniform vec4 ripples[12];
uniform int ripple_count = 0;
uniform float ripple_speed = 2.8;
uniform float ripple_life = 4.2;
uniform float ripple_amp = 1.0;

uniform vec3 deep_color : source_color = vec3(0.05, 0.35, 0.57);
uniform vec3 mid_color : source_color = vec3(0.09, 0.435, 0.647);
uniform vec3 shelf_color : source_color = vec3(0.11, 0.56, 0.69);
uniform vec3 lagoon_color : source_color = vec3(0.16, 0.66, 0.7);
uniform vec3 sandwater_color : source_color = vec3(0.52, 0.78, 0.68);
uniform vec3 foam_color : source_color = vec3(0.98, 0.995, 1.0);
uniform vec3 caustic_color : source_color = vec3(0.72, 1.0, 0.96);
uniform vec3 sky_reflect : source_color = vec3(0.75, 0.9, 0.96);
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.86);
uniform vec3 sun_dir = vec3(0.35, 0.8, 0.25);
uniform vec3 fog_color : source_color = vec3(0.72, 0.87, 0.93);

uniform float foam_amount = 0.85;
uniform float sun_glint = 0.5;
uniform float night = 0.0;
uniform float rain = 0.0;
uniform int debug_view = 0;

varying vec3 v_world;
varying vec3 v_nrm;
varying float v_crest;
varying float v_ripple_field;

float decode_depth(float e) {
	return e * e * max_depth;
}

vec3 gerstner_normal(vec2 p, float t, out float crest_out) {
	vec3 n = vec3(0.0, 1.0, 0.0);
	float rise = 0.0;
	float amp_sum = 0.0;
	float ca = cos(wave_dir);
	float sa = sin(wave_dir);
	for (int i = 0; i < 6; i++) {
		if (i >= wave_count) {
			break;
		}
		vec4 w = waves[i];
		vec2 dir = vec2(w.x * ca - w.y * sa, w.x * sa + w.y * ca);
		float amp = w.z * wave_height;
		if (wave_count <= 0) {
			break;
		}
		float k = 6.2831853 / max(w.w, 0.5);
		float c = sqrt(9.8 / k) * 0.42 * wave_speed;
		float f = k * (dot(dir, p) - c * t) + float(i) * 1.7;
		n.x -= dir.x * amp * k * cos(f);
		n.z -= dir.y * amp * k * cos(f);
		rise += amp * sin(f);
		amp_sum += amp;
	}
	crest_out = rise / max(amp_sum, 0.22);
	return normalize(n);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = wp.xz;
	vec2 uv = p / height_area + 0.5;
	float depth = decode_depth(texture(height_map, uv).r);
	float shore_damp = smoothstep(0.0, 2.2, depth);

	vec3 disp = vec3(0.0);
	float crest = 0.0;
	vec3 n = gerstner_normal(p, time, crest);

	float ca = cos(wave_dir);
	float sa = sin(wave_dir);
	for (int i = 0; i < 6; i++) {
		if (i >= wave_count) {
			break;
		}
		vec4 w = waves[i];
		vec2 dir = vec2(w.x * ca - w.y * sa, w.x * sa + w.y * ca);
		float amp = w.z * wave_height * shore_damp;
		float k = 6.2831853 / max(w.w, 0.5);
		float c = sqrt(9.8 / k) * 0.42 * wave_speed;
		float f = k * (dot(dir, p) - c * time) + float(i) * 1.7;
		disp.xz += dir * (amp * 0.34 * cos(f));
		disp.y += amp * sin(f);
	}

	// 涟漪：多源环波，叠加高度与法线（屏幕空间交互的主体）
	float ripple_field = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= ripple_count) {
			break;
		}
		vec4 rp = ripples[i];
		float age = time - rp.z;
		if (age < 0.0 || age > ripple_life) {
			continue;
		}
		vec2 d2 = p - rp.xy;
		float dist = length(d2);
		float radius = age * ripple_speed;
		float band = exp(-pow((dist - radius) / 0.62, 2.0));
		float fade = pow(1.0 - age / ripple_life, 2.0);
		float s = rp.w * fade * ripple_amp;
		float wave_s = sin((dist - radius) * 6.0);
		disp.y += wave_s * band * 0.045 * s;
		vec2 g = (d2 / max(dist, 0.001)) * cos((dist - radius) * 6.0) * 6.0 * band * 0.045 * s;
		n.xz += g * 4.0 * shore_damp;
		ripple_field = max(ripple_field, band * fade * rp.w);
	}

	VERTEX = wp + disp;
	v_world = VERTEX;
	v_nrm = normalize(n);
	v_crest = crest;
	v_ripple_field = ripple_field;
}

void fragment() {
	vec3 p = v_world;
	vec3 V = normalize(CAMERA_POSITION_WORLD - p);
	vec2 duv = p.xz / height_area + 0.5;
	float depth = decode_depth(texture(height_map, duv).r);

	vec4 shore = texture(shore_map, p.xz / shore_area + 0.5);
	float sd = (shore.r - 0.5) * shore_range;     // + 内陆 / − 水中（米）
	float prop = shore.g;                          // 岸线道具接触/泡沫环
	float wfac = 0.55 + shore.b * 0.9;             // 泡沫宽度 0.55–1.45
	float phase = shore.a;                         // 沿岸拍岸相位
	float sea = max(-sd, 0.0);                     // 离水线距离（水中为正）

	// ── 水体色阶（浅水为透明水膜，沙底由地形透出） ─────────────────
	vec3 col = mix(lagoon_color, shelf_color, smoothstep(0.4, 2.8, depth));
	col = mix(col, mid_color, smoothstep(2.8, 5.2, depth));
	col = mix(col, deep_color, smoothstep(5.2, 9.0, depth));
	float film = 1.0 - smoothstep(0.0, 0.9, depth);
	col = mix(col, sandwater_color, film * 0.62);
	// 水线暗带：交界处的接触阴影，避免水像贴片
	float contact = (1.0 - smoothstep(0.0, 0.55, sea)) * (1.0 - smoothstep(0.7, 1.6, depth));
	col *= 1.0 - 0.20 * contact;
	// 深海低对比大尺度纹理（避免纯色平面）
	float deep_var = texture(foam_tex, p.xz * 0.012 + vec2(time * 0.0015, 0.0)).r;
	col *= 0.965 + deep_var * 0.07;

	// ── 泡沫噪声 ─────────────────────────────────────────────────────
	vec2 fp = p.xz * 0.055;
	float fn1 = texture(foam_tex, fp + vec2(time * 0.0035, -time * 0.0022)).r;
	fn1 = fn1 * 0.7 + texture(foam_tex, p.xz * 0.11 + vec2(time * 0.005, -time * 0.004)).r * 0.3;
	float fn2 = texture(foam_tex, p.xz * 0.37 + vec2(-time * 0.012, time * 0.008)).r;
	float fn3 = texture(foam_tex, p.xz * 1.15 + vec2(time * 0.02, -time * 0.015)).r;
	float fn4 = texture(foam_tex, p.xz * 0.75 - vec2(0.41, 0.13) + vec2(-time * 0.008, time * 0.006)).r;
	float fnoise = fn1 * 0.52 + fn2 * 0.26 + fn3 * 0.12 + fn4 * 0.10;

	// ── 岸线泡沫：2–3 条不规则带 + 礁石泡沫环（SDF 驱动，随岸线变化） ──
	// 拍岸相位：沿岸不同段落相位/宽度不同，叠加涨落
	float swash = 0.20 * sin(time * 0.85 + phase * 6.2831853)
			+ 0.08 * sin(time * 1.7 + phase * 17.0);
	float run = 0.16 + 0.12 * wfac + swash * 0.5;
	float lace = smoothstep(0.26, 0.60, fn1 * 0.50 + fn2 * 0.32 + fn3 * 0.18);
	float lobe = smoothstep(0.30, 0.66, texture(foam_tex, p.xz * 0.17 + vec2(0.31, 0.07)).r
			* 0.6 + fn1 * 0.4);
	// 主泡沫带：水线外侧 0.3–1.6 m，宽度随岸线/低噪声成团变化，内部有蕾丝孔洞
	float c0 = 0.32 + 0.45 * wfac + run;
	float h0 = 0.26 + 0.28 * wfac + 0.16 * lace;
	float bwarp = (fn1 - 0.5) * 0.55 + (fn2 - 0.5) * 0.22;
	float b0 = 1.0 - smoothstep(0.0, h0, abs(sea - c0 + bwarp));
	b0 *= (0.62 + 0.38 * lace) * (0.55 + 0.45 * lobe);
	// 泡沫成团 + 蕾丝孔洞：低频团块决定哪里有一坨白沫，高频孔洞把白沫打穿
	float clump = smoothstep(0.36, 0.54, texture(foam_tex, p.xz * 0.10 + vec2(0.17, 0.63) - vec2(time * 0.003, 0.0)).r);
	float clump2 = smoothstep(0.34, 0.56, texture(foam_tex, p.xz * 0.26 - vec2(0.51, 0.29)).r);
	float clumpM = clamp(clump * 0.62 + clump2 * 0.38 + 0.12, 0.0, 1.0);
	float holehi = smoothstep(0.38, 0.62, fn4);
	b0 *= 0.16 + 0.84 * clumpM * (0.55 + 0.45 * holehi);
	// 岸线泛白水膜：主带两侧淡淡的洗白（平滑，不要变成白点）
	float wash = (1.0 - smoothstep(0.0, 1.4 + 0.8 * wfac, sea - run * 0.4))
			* 0.07 * (0.65 + 0.35 * fn1) * (0.5 + 0.5 * foam_amount);
	b0 = max(b0, wash);
	// 第二条：离岸 1.5–2.8 m 的断续细线（参考帧里的“第二道白线”）
	float c1 = 1.55 + 1.20 * wfac + 0.35 * sin(time * 0.55 + phase * 11.0);
	float h1 = 0.08 + 0.14 * fn2;
	float b1 = 1.0 - smoothstep(0.0, h1, abs(sea - c1 + (fn4 - 0.5) * 0.30));
	b1 *= smoothstep(0.46, 0.66, fn1 * 0.7 + fn2 * 0.4) * 0.50;
	// 第三条：更远的稀疏泡沫弧
	float c2 = 3.1 + 1.8 * wfac + 0.30 * sin(time * 0.33 + phase * 7.0);
	float h2 = 0.08 + 0.14 * fn2;
	float b2 = 1.0 - smoothstep(0.0, h2, abs(sea - c2));
	b2 *= smoothstep(0.60, 0.72, fn2 * 0.8 + fn1 * 0.3) * 0.28;
	// 礁石/岸线道具泡沫环：掩码外缘 + 噪声刻蚀，随水深淡出
	float ring = smoothstep(0.30, 0.70, prop) * (1.0 - smoothstep(0.75, 0.97, prop));
	float collar = ring * (0.30 + 0.70 * smoothstep(0.22, 0.54, fn2 * 0.5 + fn3 * 0.35 + lobe * 0.15 + 0.12))
			* smoothstep(0.04, 0.20, depth) * (1.0 - smoothstep(2.8, 4.4, depth));
	float dolly = smoothstep(0.70, 0.82, texture(foam_tex, p.xz * 0.33 + vec2(0.61, 0.23) - vec2(time * 0.006, time * 0.004)).r)
			* smoothstep(0.15, 0.55, fn1) * smoothstep(3.6, 0.9, sea) * 0.55;
	float shore_foam = max(max(b0, b1), max(b2, max(collar * 0.62, dolly))) * (0.62 + 0.42 * foam_amount);
	shore_foam = max(shore_foam, collar * 0.75 * foam_amount);

	// 浪尖泡沫（浪高滑条拉高时才出现，贴近参考的“平静海面”默认值）
	float crest_foam = smoothstep(0.22, 0.78, v_crest) * smoothstep(0.85, 1.5, wave_height);
	crest_foam *= 0.7 * foam_amount;

	// 涟漪泡沫环
	float ring_a = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= ripple_count) {
			break;
		}
		vec4 rp = ripples[i];
		float age = time - rp.z;
		if (age < 0.0 || age > ripple_life) {
			continue;
		}
		float radius = age * ripple_speed;
		float dist = length(p.xz - rp.xy);
		float fade = pow(1.0 - age / ripple_life, 2.0);
		float w1 = 0.16 + 0.13 * age;
		float w2 = 0.26 + 0.16 * age;
		float r1 = 1.0 - smoothstep(0.0, w1, abs(dist - radius));
		float r2 = (1.0 - smoothstep(0.0, w2, abs(dist - radius * 0.55))) * 0.38;
		float m = 1.0 - smoothstep(0.3, 0.85, fnoise);
		ring_a += (r1 + r2) * fade * rp.w * (0.35 + 0.65 * m);
	}
	float foam = max(shore_foam, crest_foam);
	foam = max(foam, ring_a * 1.15 * ripple_amp);
	foam *= smoothstep(0.10, 0.40, fnoise + 0.22);
	foam = clamp(foam, 0.0, 1.25);

	// ── 浅水焦散（沙底光网由地形负责，这里只留很淡的水体光感） ──────
	float caustic = 0.0;
	if (depth < 4.2) {
		vec2 cuv = p.xz * 0.085;
		float ca1 = texture(caustic_tex, cuv + vec2(time * 0.005, -time * 0.004)).r;
		float ca2 = texture(caustic_tex, cuv * 1.57 - vec2(time * 0.0035, time * 0.006)).r;
		caustic = max(ca1, ca2 * 0.8);
		caustic = smoothstep(0.15, 0.85, caustic);
		float mask = (1.0 - smoothstep(0.4, 2.6, depth)) * smoothstep(0.10, 0.5, depth);
		col += caustic_color * caustic * mask * 0.03;
	}

	// ── 水面法线：几何法线 + 细节法线 ──────────────────────────────
	vec3 n = normalize(v_nrm);
	vec3 dn = texture(detail_tex, p.xz * 0.9 + vec2(time * 0.02, time * 0.012)).rgb * 2.0 - 1.0;
	vec3 dn2 = texture(detail_tex, p.xz * 2.7 - vec2(time * 0.03, -time * 0.02)).rgb * 2.0 - 1.0;
	vec3 detail_n = dn * 0.55 + dn2 * 0.45;
	n = normalize(vec3(n.x + detail_n.x * 0.055, n.y, n.z + detail_n.y * 0.055));
	// 大尺度波面明暗 + 天空反射，让俯视也有体积
	float wave_facing = clamp(dot(normalize(v_nrm), normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
	col *= 0.9 + 0.16 * pow(wave_facing, 1.4);
	float slope_fres = pow(1.0 - clamp(dot(n, V), 0.0, 1.0), 5.0);
	col = mix(col, sky_reflect, slope_fres * 0.28);
	col *= 1.0 + v_crest * 0.045;

	float ndv = clamp(dot(n, V), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 4.0);
	col = mix(col, sky_reflect, clamp(fres * 0.45, 0.0, 0.35));

	// 次表面：浪尖偏亮青
	float crest_tint = smoothstep(0.25, 0.9, v_crest) * smoothstep(0.4, 1.2, wave_height);
	col = mix(col, caustic_color * 0.86, crest_tint * 0.16);

	// ── 卡通日光/月光高光 + 闪点 ───────────────────────────────────
	vec3 H = normalize(normalize(sun_dir) + V);
	float ndh = max(dot(n, H), 0.0);
	float sun_tight = pow(ndh, 900.0) * 0.4;
	float sun_sheen = pow(ndh, 36.0) * 0.06;
	float glit_mask = texture(foam_tex, p.xz * 6.0 + vec2(time * 0.08, -time * 0.06)).r;
	float glit = smoothstep(0.84, 0.97, glit_mask);
	col += sun_color * (sun_tight * (0.25 + 0.75 * glit) + sun_sheen) * sun_glint * (1.0 - foam * 0.85);
	// 细碎阳光闪点：与法线/泡沫纹理无关，保证俯视也有参考帧里的闪烁
	float sp1 = smoothstep(0.90, 0.985, texture(foam_tex, p.xz * 9.0 + vec2(time * 0.03, -time * 0.021)).r);
	float sp2 = smoothstep(0.93, 0.995, texture(foam_tex, p.xz * 14.0 - vec2(time * 0.045, time * 0.033)).r);
	float gf = texture(foam_tex, p.xz * 0.6 + vec2(time * 0.008, -time * 0.006)).r;
	float gf2 = texture(foam_tex, p.xz * 1.7 - vec2(time * 0.014, time * 0.01)).r;
	float glitter = smoothstep(0.72, 0.92, gf * 0.6 + gf2 * 0.5);
	float sun_facing = smoothstep(-0.1, 0.5, dot(n, normalize(sun_dir)));
	col += sun_color * (sp1 * 0.9 + sp2 * 0.6 + glitter * 0.04) * sun_facing * sun_glint * (1.0 - foam * 0.7);
	col += sun_color * ring_a * 0.10 * ripple_amp;

	// 雨天：细微噪点环 + 整体压暗
	if (rain > 0.01) {
		float drops = texture(foam_tex, p.xz * 0.6 + vec2(time * 0.05, time * 0.037)).r;
		float rings = smoothstep(0.72, 0.95, drops) * rain;
		col = mix(col, foam_color, rings * 0.18);
		col *= 1.0 - 0.08 * rain;
	}

	vec3 foam_tint = mix(foam_color, foam_color * vec3(0.86, 0.94, 0.95), 0.35 * (1.0 - fn3));
	float foam_key = smoothstep(0.10, 0.55, foam);
	col = mix(col, foam_tint * (0.95 + 0.05 * fnoise), foam_key * 0.96);

	// 夜晚整体压暗并偏冷（颜色 uniform 已由脚本按时间插值）
	col = mix(col, col * vec3(0.72, 0.82, 1.0), night * 0.35);

	// 远处空气透视
	float dist_cam = distance(p, CAMERA_POSITION_WORLD);
	float fog = 1.0 - exp(-max(dist_cam - 110.0, 0.0) * 0.0022);
	col = mix(col, fog_color, clamp(fog, 0.0, 0.55));

	// ── 透明度：浅水透出沙底/礁石，岸边一层薄水膜 ─────────────────
	float water_a = 0.14 + 0.86 * smoothstep(0.06, 3.9, depth);
	water_a = max(water_a, 0.18 * (1.0 - smoothstep(0.0, 0.30, sea)));
	water_a *= 0.96 + 0.08 * detail_n.x;   // 细微折射抖动
	float foam_a = foam_key * 0.98;
	float alpha = max(water_a, foam_a);
	alpha = max(alpha, clamp(ring_a * 0.55 * ripple_amp, 0.0, 0.9));
	alpha = clamp(alpha, 0.0, 1.0);

	// ── 调试视图 ───────────────────────────────────────────────────
	if (debug_view == 1) {
		float hh = clamp(v_crest * 0.5 + 0.5, 0.0, 1.0);
		col = vec3(pow(hh, 1.6));
		alpha = 1.0;
	} else if (debug_view == 2) {
		col = n * 0.5 + 0.5;
		alpha = 1.0;
	} else if (debug_view == 3) {
		col = vec3(clamp(foam, 0.0, 1.0));
		alpha = 1.0;
	} else if (debug_view == 4) {
		col = vec3(0.02, 0.05, 0.08) + vec3(0.2, 0.9, 1.0) * (ring_a * 1.2 + v_ripple_field * 0.35);
		alpha = 1.0;
	} else if (debug_view == 5) {
		float dn2v = clamp(depth / max_depth, 0.0, 1.0);
		vec3 heat = mix(vec3(0.05, 0.25, 0.55), vec3(0.2, 0.85, 0.7), smoothstep(0.0, 0.4, dn2v));
		heat = mix(heat, vec3(1.0, 0.85, 0.3), smoothstep(0.4, 0.75, dn2v));
		col = heat;
		alpha = 1.0;
	} else if (debug_view == 6) {
		// 岸距场：白色为水线，陆侧暖沙色，海侧按离岸距离分层
		vec3 sc = vec3(0.10, 0.20, 0.24);
		if (sd >= 0.0) {
			sc = mix(vec3(0.95, 0.90, 0.78), vec3(0.66, 0.60, 0.48),
					smoothstep(0.0, 6.0, sd));
			sc *= 0.9 + 0.1 * sin(sd * 8.0);
		} else {
			sc = mix(vec3(0.92, 0.98, 0.96), vec3(0.06, 0.34, 0.50),
					smoothstep(0.0, 5.0, sea));
			sc += vec3(0.1, 0.25, 0.2) * b0;
		}
		float line = 1.0 - smoothstep(0.0, 0.10, abs(sd));
		col = mix(sc, vec3(1.0), line * 0.9);
		alpha = 1.0;
	} else if (debug_view == 7) {
		col = vec3(clamp(b0, 0.0, 1.0), clamp(b1 + collar, 0.0, 1.0), clamp(b2, 0.0, 1.0));
		alpha = 1.0;
	}

	ALBEDO = col;
	ALPHA = alpha;
}
