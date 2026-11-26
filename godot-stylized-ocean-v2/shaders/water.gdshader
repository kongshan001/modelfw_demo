// 风格化海面：Gerstner 波 + 深度色阶 + 岸线泡沫 + 焦散 + 卡通日光 + 鼠标/雨滴涟漪。
// 原创实现；颜色与层级按参考帧逐帧对照调参（见 docs/TECH.md）。
shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_back, shadows_disabled, fog_disabled, specular_disabled;

uniform sampler2D height_map : filter_linear, repeat_disable;
uniform float height_area = 180.0;
uniform float max_depth = 12.0;

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
varying float v_depth;
varying vec2 v_shore_grad;
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

	// 岸线法线 ≈ 深度梯度，泡沫带沿它向岸推进
	float texel = 1.2 / height_area;
	float dx = decode_depth(texture(height_map, uv + vec2(texel, 0.0)).r)
			- decode_depth(texture(height_map, uv - vec2(texel, 0.0)).r);
	float dz = decode_depth(texture(height_map, uv + vec2(0.0, texel)).r)
			- decode_depth(texture(height_map, uv - vec2(0.0, texel)).r);
	v_shore_grad = vec2(dx, dz);

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
	v_depth = depth;
	v_crest = crest;
	v_ripple_field = ripple_field;
}

void fragment() {
	vec3 p = v_world;
	float depth = v_depth;
	vec3 V = normalize(CAMERA_POSITION_WORLD - p);

	// ── 深度色阶（参考帧：浅水青绿 → 礁盘青蓝 → 深海蔚蓝） ───────────
	vec3 col = mix(lagoon_color, shelf_color, smoothstep(0.2, 2.4, depth));
	col = mix(col, mid_color, smoothstep(2.4, 5.0, depth));
	col = mix(col, deep_color, smoothstep(5.0, 8.6, depth));
	float sand_glow = 1.0 - smoothstep(0.0, 0.9, depth);
	col = mix(col, sandwater_color, sand_glow * 0.2);
	// 深海低对比大尺度纹理（避免纯色平面）
	float deep_var = texture(foam_tex, p.xz * 0.012 + vec2(time * 0.0015, 0.0)).r;
	col *= 0.965 + deep_var * 0.07;

	// ── 泡沫噪声 ─────────────────────────────────────────────────────
	vec2 fp = p.xz * 0.055;
	float fn1 = texture(foam_tex, fp + vec2(time * 0.0035, -time * 0.0022)).r;
	fn1 = fn1 * 0.7 + texture(foam_tex, p.xz * 0.11 + vec2(time * 0.005, -time * 0.004)).r * 0.3;
	float fn2 = texture(foam_tex, p.xz * 0.37 + vec2(-time * 0.012, time * 0.008)).r;
	float fnoise = fn1 * 0.66 + fn2 * 0.34;

	float shore_phase = sin(depth * 5.2 - time * 1.0 + fnoise * 6.0);
	float shore = 1.0 - smoothstep(0.012, 0.065 + fnoise * 0.05, depth);
	float band_a = smoothstep(0.55, 0.93, shore_phase)
			* (1.0 - smoothstep(0.6, 1.5, depth)) * smoothstep(0.12, 0.3, depth);
	float band_b = smoothstep(0.78, 0.98, sin(depth * 1.85 + 1.8 - time * 0.38 + fnoise * 4.5))
			* (1.0 - smoothstep(2.2, 4.2, depth)) * smoothstep(0.8, 1.5, depth);
	float foam = max(shore * 0.2, band_a * 0.15 * foam_amount + band_b * 0.12 * foam_amount);
	// 岸线细白线（参考帧最明确的一层泡沫）
	float line_depth = 0.05 + fnoise * 0.07;
	float crisp = 1.0 - smoothstep(0.0, 0.045 + 0.03 * fn2, abs(depth - line_depth));
	foam = max(foam, crisp * 0.5 * foam_amount);
	// 离岸的零散泡沫弧（参考帧里沙脊上的细白纹）
	float curls = smoothstep(0.78, 0.9, fn2) * smoothstep(0.55, 0.85, sin(depth * 3.1 - time * 0.5 + fn1 * 9.0));
	foam += curls * 0.18 * foam_amount * smoothstep(0.35, 0.8, depth) * (1.0 - smoothstep(2.0, 4.0, depth));

	// 浪尖泡沫（浪高滑条拉高时才出现，贴近参考的“平静海面”默认值）
	float crest_foam = smoothstep(0.22, 0.78, v_crest) * smoothstep(0.85, 1.5, wave_height);
	foam += crest_foam * 0.7 * foam_amount;

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
	foam += ring_a * 1.15 * ripple_amp;
	foam *= smoothstep(0.18, 0.5, fnoise + 0.16);
	foam = clamp(foam, 0.0, 1.25);

	// ── 浅水焦散（参考帧：沙底光网） ─────────────────────────────────
	float caustic = 0.0;
	if (depth < 5.2) {
		vec2 cuv = p.xz * 0.085;
		float c1 = texture(caustic_tex, cuv + vec2(time * 0.005, -time * 0.004)).r;
		float c2 = texture(caustic_tex, cuv * 1.57 - vec2(time * 0.0035, time * 0.006)).r;
		caustic = max(c1, c2 * 0.8);
		caustic = smoothstep(0.15, 0.85, caustic);
		float mask = (1.0 - smoothstep(0.6, 2.8, depth)) * smoothstep(0.08, 0.45, depth);
		col += caustic_color * caustic * mask * 0.12;
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

	col = mix(col, foam_color * (0.94 + 0.06 * fnoise), clamp(foam, 0.0, 1.0) * 0.92);

	// 夜晚整体压暗并偏冷（颜色 uniform 已由脚本按时间插值）
	col = mix(col, col * vec3(0.72, 0.82, 1.0), night * 0.35);

	// 远处空气透视
	float dist_cam = distance(p, CAMERA_POSITION_WORLD);
	float fog = 1.0 - exp(-max(dist_cam - 110.0, 0.0) * 0.0022);
	col = mix(col, fog_color, clamp(fog, 0.0, 0.55));

	// ── 调试视图 ───────────────────────────────────────────────────
	if (debug_view == 1) {
		float hh = clamp(v_crest * 0.5 + 0.5, 0.0, 1.0);
		col = vec3(pow(hh, 1.6));
	} else if (debug_view == 2) {
		col = n * 0.5 + 0.5;
	} else if (debug_view == 3) {
		col = vec3(clamp(foam, 0.0, 1.0));
	} else if (debug_view == 4) {
		col = vec3(0.02, 0.05, 0.08) + vec3(0.2, 0.9, 1.0) * (ring_a * 1.2 + v_ripple_field * 0.35);
	} else if (debug_view == 5) {
		float dn2v = clamp(depth / max_depth, 0.0, 1.0);
		vec3 heat = mix(vec3(0.05, 0.25, 0.55), vec3(0.2, 0.85, 0.7), smoothstep(0.0, 0.4, dn2v));
		heat = mix(heat, vec3(1.0, 0.85, 0.3), smoothstep(0.4, 0.75, dn2v));
		col = heat;
	} else if (debug_view == 6) {
		float g = length(v_shore_grad);
		col = vec3(0.08, 0.1, 0.12) + vec3(1.0, 0.55, 0.25) * smoothstep(0.0, 1.2, g);
	}

	ALBEDO = col;
}
