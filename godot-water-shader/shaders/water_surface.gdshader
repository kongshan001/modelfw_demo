shader_type canvas_item;
render_mode unshaded, blend_mix;

// 单层水面：全屏 ColorRect，不新建任何水面网格。
// 数据全部来自 16px 栅格：mask(R 硬掩码 / G 覆盖率 / B 桥面裁切)、
// depth(R 展示水深 / G 距岸格数)、category(实体 id)、flow(RG 方向)。
//
// 视觉层（T-20261126-005 整改，参数见 docs/art-review-T-20261126-004.md）：
//   1. 5 档水深色阶（海/河各 5 档、湖 4 档），按“距岸格数”混合；
//   2. 浅水按深度透出沙底/鹅卵石/海草（seabed ratio 0.72 → 0）；
//   3. 岸线：湿沙（资产层）+ 2px 水线暗线 + 白芯 4–7px + 青沫 4–6px + 分段断口；
//   4. 双波前泡沫：cycle 0.18、相位差 0.5、front 1.2–3.6 格、宽度 0.45 格；
//   5. 2 octave Voronoi 焦散（56 / 23 world px、8Hz、仅 0.75–4.5 格）；
//   6. 暖色太阳闪、天空 sheen、流动亮纹减半；
//   7. 湖无泡沫环，只有 1px 水线 + 近岸 sheen；积水复用同一 shader。
// 湖的浪幅≈0、焦散=0（BFS 内陆湖）。

uniform sampler2D u_ground : filter_nearest, repeat_disable;
uniform sampler2D u_mask : filter_linear, repeat_disable;
uniform sampler2D u_depth : filter_linear, repeat_disable;
uniform sampler2D u_category : filter_nearest, repeat_disable;
uniform sampler2D u_flow : filter_nearest, repeat_disable;
uniform sampler2D u_puddle_mask : filter_linear, repeat_disable;
uniform sampler2D u_puddle_depth : filter_linear, repeat_disable;

uniform vec2 u_world = vec2(1280.0, 720.0);
uniform float u_cell = 16.0;
uniform float u_time = 0.0;
uniform float u_tide = 0.5;
uniform float u_rain = 0.0;
uniform float u_focus = 0.0;
uniform int u_debug = 0;

uniform vec3 u_wave = vec3(1.0, 0.32, 0.06);
uniform vec3 u_flow_speed = vec3(0.55, 1.35, 0.0);
uniform vec3 u_foam = vec3(1.0, 0.50, 0.0);
uniform vec3 u_caustic = vec3(1.0, 0.60, 0.0);

// 色板（sRGB，source_color）。海 / 河 / 湖按距岸格数取 5 / 5 / 4 档。
uniform vec3 u_sea0 : source_color = vec3(0.51, 0.75, 0.69);
uniform vec3 u_sea1 : source_color = vec3(0.40, 0.67, 0.65);
uniform vec3 u_sea2 : source_color = vec3(0.29, 0.50, 0.52);
uniform vec3 u_sea3 : source_color = vec3(0.21, 0.44, 0.47);
uniform vec3 u_sea4 : source_color = vec3(0.19, 0.34, 0.36);
uniform vec3 u_river0 : source_color = vec3(0.62, 0.78, 0.69);
uniform vec3 u_river1 : source_color = vec3(0.47, 0.68, 0.59);
uniform vec3 u_river2 : source_color = vec3(0.31, 0.55, 0.49);
uniform vec3 u_river3 : source_color = vec3(0.21, 0.43, 0.38);
uniform vec3 u_river4 : source_color = vec3(0.14, 0.31, 0.28);
uniform vec3 u_lake0 : source_color = vec3(0.44, 0.64, 0.54);
uniform vec3 u_lake1 : source_color = vec3(0.29, 0.50, 0.44);
uniform vec3 u_lake2 : source_color = vec3(0.18, 0.36, 0.32);
uniform vec3 u_lake3 : source_color = vec3(0.11, 0.25, 0.24);
uniform vec3 u_puddle0 : source_color = vec3(0.36, 0.45, 0.41);
uniform vec3 u_puddle1 : source_color = vec3(0.20, 0.30, 0.29);
uniform vec3 u_sand_warm : source_color = vec3(0.79, 0.71, 0.49);
uniform vec3 u_foam_core : source_color = vec3(0.91, 0.95, 0.87);
uniform vec3 u_foam_wash : source_color = vec3(0.61, 0.80, 0.74);
uniform vec3 u_waterline : source_color = vec3(0.17, 0.29, 0.27);
uniform vec3 u_sparkle : source_color = vec3(1.0, 0.91, 0.69);
uniform vec3 u_caustic_col : source_color = vec3(0.87, 0.95, 0.86);
uniform vec3 u_sheen : source_color = vec3(0.66, 0.81, 0.78);

const float PI2 = 3.14159265;
const vec3 SAND_TINT = vec3(1.0, 1.0, 0.97);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float pixel_hash(vec2 uv) {
	return hash21(floor(uv * u_world * 0.5));
}

float pixel_hash4(vec2 uv) {
	return hash21(floor(uv * u_world * 0.25) + vec2(7.1, 3.7));
}

float pick3(vec3 v, int cat) {
	if (cat == 2) {
		return v.y;
	}
	if (cat == 3) {
		return v.z;
	}
	return v.x;
}

// 5 档色阶：阈值按 brief 的“距岸格数”，用 0.5–0.9 格宽做柔化，
// 避免出现硬色带；最深层仍由 controller 的深色 uniform 控制。
vec3 water_ramp(int cat, float dc) {
	vec3 c;
	if (cat == 2) {
		c = u_river0;
		c = mix(c, u_river1, smoothstep(0.10, 0.45, dc));
		c = mix(c, u_river2, smoothstep(0.50, 1.00, dc));
		c = mix(c, u_river3, smoothstep(1.05, 1.70, dc));
		c = mix(c, u_river4, smoothstep(1.90, 2.80, dc));
	} else if (cat == 3) {
		c = u_lake0;
		c = mix(c, u_lake1, smoothstep(0.20, 0.80, dc));
		c = mix(c, u_lake2, smoothstep(0.90, 1.80, dc));
		c = mix(c, u_lake3, smoothstep(2.00, 3.20, dc));
	} else {
		c = u_sea0;
		c = mix(c, u_sea1, smoothstep(2.2, 3.2, dc));
		c = mix(c, u_sea2, smoothstep(4.2, 5.4, dc));
		c = mix(c, u_sea3, smoothstep(7.5, 9.0, dc));
		c = mix(c, u_sea4, smoothstep(11.5, 14.0, dc));
	}
	return c;
}

// 沙底可见比例（brief 6.2）：0–0.75 格 72%，0.75–1.75 格 45%，
// 1.75–3.5 格 22%，3.5–5 格 10%，>6.5 格 0。
float seabed_ratio(float dc) {
	if (dc < 0.75) {
		return 0.55;
	}
	if (dc < 1.75) {
		return mix(0.55, 0.40, smoothstep(0.75, 1.75, dc));
	}
	if (dc < 3.5) {
		return mix(0.40, 0.18, smoothstep(1.75, 3.5, dc));
	}
	if (dc < 5.0) {
		return mix(0.22, 0.10, smoothstep(3.5, 5.0, dc));
	}
	return mix(0.10, 0.0, smoothstep(5.0, 6.5, dc));
}

// 3×3 Voronoi：用最近与次近距离差画晶体亮边。
float voronoi_edge(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash21(n + g), hash21(n + g + vec2(17.3, 9.1)));
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}

float grid_line(vec2 uv) {
	vec2 f = fract(uv * u_world / u_cell);
	return step(0.94, max(f.x, f.y));
}

float rain_streaks(vec2 uv) {
	// 单层雨丝（T-005 性能取舍：去掉第二层 hash，密度提高补偿）。
	vec2 q = vec2(uv.x * 150.0, uv.y * 80.0 + u_time * 42.0);
	vec2 g = floor(q);
	vec2 f = fract(q);
	float on = step(0.72, hash21(g));
	float line = smoothstep(0.34, 0.5, f.x) * smoothstep(0.66, 0.5, f.x);
	float tail = smoothstep(0.0, 0.28, f.y) * smoothstep(1.0, 0.58, f.y);
	return on * line * tail;
}

// 雨点涟漪：0.4–0.6s 一圈；10% 的雨点在中心带 2–3px 溅水。
vec2 rain_rings(vec2 uv, float amount) {
	vec2 p = uv * u_world / 12.0;
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash21(id + floor(u_time * 2.2) * vec2(3.1, 7.7));
	float r = fract(u_time * 2.0 + h);
	float ring = smoothstep(0.055, 0.0, abs(length(f) - r * 0.34));
	float splash = step(0.90, h) * smoothstep(0.10, 0.0, length(f)) * smoothstep(0.35, 0.0, r);
	float gate = step(0.58, hash21(id * 1.37));
	return vec2(ring * gate * amount, splash * amount);
}

// ── 调试视图 ─────────────────────────────────────────────────────────────
vec4 debug_view(vec2 uv, vec4 m, vec4 pm, vec4 d, vec4 pd) {
	int cat = int(round(texture(u_category, uv).r * 4.0));
	float grid = grid_line(uv) * 0.14;
	vec3 col = vec3(0.035, 0.05, 0.05);
	if (u_debug == 1) {
		// 水体掩码：红=硬格，青=覆盖率，蓝=桥面裁切，黄=低洼积水。
		col = vec3(0.055, 0.075, 0.07);
		if (m.r > 0.5) {
			col = mix(vec3(0.12, 0.34, 0.40), vec3(0.55, 0.92, 0.86), m.g);
		} else if (m.g > 0.05) {
			col = vec3(0.34, 0.20, 0.16) + vec3(0.22, 0.15, 0.10) * m.g;
		}
		if (m.b > 0.5) {
			col = vec3(0.22, 0.44, 0.95);
		}
		float puddle_gate = smoothstep(0.02, 0.3, u_rain);
		if (pm.r > 0.5) {
			col = mix(col, vec3(0.88, 0.75, 0.22), 0.35 + 0.65 * puddle_gate);
		}
		col += grid;
	} else if (u_debug == 2) {
		// 水深：距离场的平滑结果 + 每 1 格等高线。
		float depth = max(d.r, pd.r * step(0.5, pm.r));
		vec3 ramp = mix(vec3(0.12, 0.30, 0.48), vec3(0.95, 0.83, 0.36), depth);
		ramp = mix(ramp, vec3(0.20, 0.62, 0.52), smoothstep(0.0, 0.20, depth) * 0.45);
		col = vec3(0.08, 0.09, 0.10);
		if (m.r > 0.5 || pm.r > 0.5) {
			col = ramp;
		}
		float dd = max(d.g, pd.g * step(0.5, pm.r)) * 16.0;
		float contour = smoothstep(0.06, 0.0, abs(fract(dd) - 0.5));
		col = mix(col, vec3(0.92, 0.97, 0.92), contour * 0.38);
		if (m.b > 0.5) {
			col = vec3(0.20, 0.25, 0.45);
		}
		col += grid;
	} else if (u_debug == 5) {
		// 诊断：depth.G 原始值（0..1）。
		col = vec3(texture(u_depth, uv).g);
	} else if (u_debug == 6) {
		// 诊断：R = 距岸格数/20, G = 类别/4, B = 展示水深。
		col = vec3(texture(u_depth, uv).g * 16.0 / 20.0,
				texture(u_category, uv).r, texture(u_depth, uv).r);
	} else if (u_debug == 3) {
		// 类别：海蓝 / 河绿 / 湖紫 / 积水黄，桥面裁切洋红。
		if (cat == 1) {
			col = vec3(0.20, 0.47, 0.78);
		} else if (cat == 2) {
			col = vec3(0.22, 0.72, 0.46);
		} else if (cat == 3) {
			col = vec3(0.62, 0.38, 0.80);
		} else if (cat == 4) {
			col = vec3(0.92, 0.83, 0.28);
		}
		if (m.r < 0.5 && pm.r < 0.5) {
			col *= 0.25;
		}
		if (m.b > 0.5) {
			col = vec3(0.92, 0.28, 0.58);
		}
		col += grid;
	} else {
		// 岸线叠加：去色地形 + 覆盖率等值线 + 水深轮廓。
		vec3 ground = texture(u_ground, uv).rgb;
		float lum = dot(ground, vec3(0.30, 0.59, 0.11));
		col = mix(vec3(lum), ground, 0.15) * 0.72;
		float edge = smoothstep(0.055, 0.0, abs(m.g - 0.5));
		col = mix(col, vec3(0.95, 0.98, 0.92), edge);
		float dd = d.g * 16.0;
		float contour = smoothstep(0.045, 0.0, abs(fract(dd) - 0.5));
		col = mix(col, vec3(0.55, 0.92, 0.86), contour * 0.30);
		if (m.b > 0.5) {
			col = mix(col, vec3(0.95, 0.35, 0.58), 0.55);
		}
		col += grid * 0.5;
	}
	return vec4(col, 1.0);
}

// ── 主函数 ───────────────────────────────────────────────────────────────
void fragment() {
	vec2 uv = clamp(UV, vec2(0.002), vec2(0.998));
	vec4 m = texture(u_mask, uv);
	vec2 puv = floor(uv * u_world * 0.5) / (u_world * 0.5);

	if (u_debug > 0) {
		vec4 pm_dbg = texture(u_puddle_mask, uv);
		vec4 d_dbg = texture(u_depth, uv);
		vec4 pd_dbg = texture(u_puddle_depth, uv);
		COLOR = debug_view(uv, m, pm_dbg, d_dbg, pd_dbg);
	} else {
		// 岸线像素化：2px + 4px 双层抖动硬切，潮汐平移切分阈值。
		float dith = pixel_hash(puv) - 0.5;
		float dith4 = pixel_hash4(puv) - 0.5;
		float tide_shift = (u_tide - 0.5) * 0.24;
		float cut = 0.5 - dith * 0.13 - dith4 * 0.07 + tide_shift;
		float water_sel = step(0.5, m.g + dith * 0.13 + dith4 * 0.07 - tide_shift);
		// 水线内侧归一化距离：0 = 水线，1 = 完全水格（供泡沫/河流收色共用）。
		float t = clamp((m.g - cut) / max(1.0 - cut, 0.02), 0.0, 1.0);
		// 只在雨天采样低洼 mask（旱地路径省一次纹理采样）。
		float puddle_gate = smoothstep(0.04, 0.55, u_rain);
		vec4 pm = vec4(0.0);
		if (puddle_gate > 0.001) {
			pm = texture(u_puddle_mask, uv);
		}
		float puddle_amt = smoothstep(0.26, 0.72, pm.g) * puddle_gate;
		puddle_amt = max(puddle_amt, step(0.5, pm.g + dith * 0.12) * puddle_gate);
		float coverage = max(water_sel, puddle_amt * step(0.001, pm.r));
		float streak = 0.0;
		if (u_rain > 0.01) {
			streak = rain_streaks(uv) * u_rain;
		}

		if (coverage < 0.002) {
			float veil = 0.13 * u_rain;
			if (streak > 0.01 || veil > 0.002) {
				COLOR = vec4(vec3(0.10, 0.16, 0.17), veil + streak * 0.58);
			} else {
				discard;
			}
		} else {
			// 水深/积水深度只在真正的水面/积水像素采样。
			vec4 d = texture(u_depth, uv);
			vec4 pd = texture(u_puddle_depth, uv);
			int cat = int(round(texture(u_category, uv).r * 4.0));
			if (puddle_amt > water_sel) {
				cat = 4;
			}
			vec2 flow = texture(u_flow, uv).rg * 2.0 - 1.0;
			if (cat == 3 || cat == 4) {
				flow = vec2(0.0);
			}
			float wave_amt = pick3(u_wave, cat);
			float flow_amt = pick3(u_flow_speed, cat);
			float foam_amt = pick3(u_foam, cat);
			float caustic_amt = pick3(u_caustic, cat);
			if (cat == 4) {
				wave_amt = 0.02;
				flow_amt = 0.0;
				foam_amt = 0.0;
				caustic_amt = 0.0;
			}

			float dc_raw = (cat == 4 ? pd.g : d.g) * 16.0;
			// 距岸格数从手绘水线算起（倒角距离最小为 1 格）。
			float dc = max(dc_raw - 1.0, 0.0);

			// 折射采样海底：浅水 ≤1.5 world px，深水归零，全部 snap 到 2px 块。
			float refr_px = 1.5 * (1.0 - smoothstep(0.5, 4.5, dc));
			vec2 refr = vec2(
				sin(uv.y * 34.0 + u_time * 0.9 + flow.x * 1.7),
				cos(uv.x * 29.0 - u_time * 0.75 + flow.y * 1.3)
			) * refr_px * (0.35 + 0.65 * wave_amt) / u_world;
			vec2 guv = clamp(uv + refr, vec2(0.0), vec2(1.0));
			guv = floor(guv * u_world * 0.5) / (u_world * 0.5);
			vec3 seabed = texture(u_ground, guv).rgb;
			// 浅水暖沙：#C9B57E 混入 15–20%，避免薄荷色代替沙底。
			seabed = mix(seabed, u_sand_warm, 0.18 * (1.0 - smoothstep(1.5, 3.5, dc)));

			vec3 water;
			if (cat == 4) {
				// 积水：深色石面水膜 + 冷色 sheen + 2px 湿边，不用薄荷色。
				float depth_q = clamp(pd.r, 0.0, 1.0);
				// 积水：深色湿石 + 右上小范围天空反光 + 少量 2px 闪烁；不要整片乳白。
				vec3 stone = seabed * vec3(0.45, 0.50, 0.48);
				vec3 pcol = mix(u_puddle0 * 0.82, u_puddle1, smoothstep(0.10, 0.85, depth_q));
				water = mix(stone, pcol, 0.72);
				float sky = smoothstep(0.42, 0.90, 0.52 + (puv.y - puv.x) * 0.55);
				water = mix(water, u_sheen * 0.55, sky * 0.07);
				float glint = step(0.9955, hash21(floor(puv * u_world * 0.5) + floor(u_time * 6.0)));
				water += u_sparkle * glint * 0.40;
				float rim = smoothstep(0.10, 0.0, abs(pm.g - 0.5)) * step(0.001, pm.r);
				water = mix(water, u_waterline, rim * 0.70);
				// 右上受光湿边 1px（很轻）。
				float rim_lit = smoothstep(0.08, 0.0, abs(pm.g - 0.5)) * step(0.0, uv.x - uv.y);
				water += u_sheen * rim_lit * 0.10;
			} else {
				// 色阶 + 透沙：浅水沙底占比 72%，深水只剩色阶。
				// 湖的水深只有 6 格，视觉上按 1.3 倍计深、沙底权重 ×0.55，
				// 避免小湖整体读成浅薄荷色（brief：湖心 L*20–30）。
				float dc_vis = dc * (cat == 3 ? 1.3 : (cat == 2 ? 1.1 : 1.0));
				vec3 base = water_ramp(cat, dc_vis);
				float sb = seabed_ratio(dc_vis) * (cat == 3 ? 0.55 : 1.0);
				water = mix(base, seabed * SAND_TINT, sb);
				// 水层本身仍带一点青绿，避免沙底像直接露出的地面。
				water = mix(water, base, (1.0 - sb) * 0.08);
				// 河只有 3–4 格宽，大部分格距岸 1–2 格；为让 25% 下河流
				// 靠“深水色”而不是白边识别，水格内部向深一档收色（边缘保留沙/沫）。
				if (cat == 2) {
					float interior = smoothstep(0.48, 0.78, t);
					water = mix(water, water_ramp(2, dc_vis + 2.2), interior * 0.76);
				}

				// 近岸天空 sheen（湖更宽）：8–16 显示 px 的浅色带。
				float sheen_band = 1.0 - smoothstep(0.10, cat == 3 ? 0.50 : 0.75, dc);
				water += u_sheen * sheen_band * (cat == 3 ? 0.02 : 0.04);

				// 2 octave Voronoi 焦散：56 / 23 world px，8Hz 更新，仅 0.75–4.5 格。
				// 边缘收窄到 0.13 + pow 1.35，让覆盖约 8–15%，读作光网而不是冰裂纹。
				float caustic_window = smoothstep(0.20, 0.60, dc)
						* (1.0 - smoothstep(3.4, 4.2, dc));
				// 只在浅水窗口内做 2 octave Voronoi；深水直接跳过（Intel 预算）。
				if (caustic_amt > 0.01 && caustic_window > 0.002) {
					float tq = floor(u_time * 8.0) * 0.125;
					vec2 drift = flow * tq * 0.55 + vec2(flow.x * 3.0);
					vec2 warp = vec2(sin(puv.y * 9.0 + tq * 3.1), cos(puv.x * 7.0 - tq * 2.7)) * 0.12;
					float e1 = voronoi_edge((puv * u_world + drift * 16.0) / 56.0 + warp);
					float e2 = voronoi_edge((puv * u_world + drift * 12.0) / 23.0 + vec2(5.7, 9.3) - warp * 1.6);
					// 细亮芯 + 柔光晕：细芯负责可读的移动光网（9×9 高通可测），
					// 光晕补足 8–15% 的覆盖，避免只剩几条线。
					float core = pow(smoothstep(0.035, 0.0, e1), 1.15)
							+ 0.50 * pow(smoothstep(0.035, 0.0, e2), 1.15);
					float glow = smoothstep(0.17, 0.0, e1) + 0.50 * smoothstep(0.17, 0.0, e2);
					water += u_caustic_col * (core * 0.20 + glow * 0.060) * caustic_window * caustic_amt;
				}

				// 深水色相缓慢起伏（±1%），避免整片平涂。
				float deep_var = sin(puv.x * 37.0 + puv.y * 23.0 + u_time * 0.25);
				water *= 1.0 + deep_var * 0.010 * smoothstep(0.5, 0.9, min(dc / 8.0, 1.0));

				// 流动亮纹：强度从 0.32 降到 0.10，避免与焦散抢。
				if (flow_amt > 0.01) {
					vec2 fs = puv * u_world;
					float along = dot(fs, flow) * 0.055;
					float across = dot(fs, vec2(-flow.y, flow.x)) * 0.22;
					float crest = sin(across + sin(along * 0.6 + u_time * 0.7) * 2.0
							- u_time * (1.25 + 0.22 * flow_amt));
					crest = smoothstep(0.90, 1.0, crest);
					float flow_fade = smoothstep(0.02, 0.3, dc) * (1.0 - smoothstep(5.0, 7.0, dc));
					water += u_foam_wash * crest * flow_fade * min(flow_amt, 1.3) * 0.07;
				}

				// 暖色太阳闪：0.4% 像素，6–8Hz，深水也有少量。
				float sparkle = step(0.996, pixel_hash(puv + floor(u_time * 7.0) * vec2(19.0, 11.0)));
				water += u_sparkle * sparkle * smoothstep(0.05, 0.8, min(dc / 2.0, 1.0)) * 0.55;

				// ── 岸线泡沫 ─────────────────────────────────────────────
				// 8–16px 岸段 hash：20–40% 断口，避免连续白描边。
				float seg = hash21(floor(puv * u_world / 10.0) + vec2(3.0, 17.0));
				float gap = step(0.30, seg);
				float seg2 = hash21(floor(puv * u_world / vec2(18.0, 14.0)) + vec2(9.0, 5.0));
				float gap2 = step(0.22, seg2);
				float gaps = gap * gap2;

				float foam_strength = clamp(foam_amt, 0.0, 1.2);
				// t 与 dc（距岸格数，1 格 = 16px）联合使用，才能得到 4–7px 的窄带；
				// 只用 coverage 会让所有内部水格 (m.g=1) 都变成白沫。
				float near_shore = 1.0 - smoothstep(0.75, 1.25, dc);
				float core = 0.0;
				float wash = 0.0;
				if (cat != 3) {
					// 白芯 4–7px：coverage band（3–8px）+ dc 领口（兜住全水格岸段）。
					float core_band = smoothstep(0.48, 0.24, t) * smoothstep(0.02, 0.10, t)
							* near_shore * gaps;
					float collar = smoothstep(0.60, 0.10, dc) * (1.0 - smoothstep(0.70, 1.05, dc))
							* gaps;
					// 青沫水洗：白芯外侧 4–6px。
					float wash_band = exp(-pow((t - 0.72) / 0.10, 2.0))
							* near_shore * gaps;
					float wash_dc = smoothstep(1.05, 0.72, dc) * smoothstep(0.48, 0.78, dc)
							* step(0.22, hash21(floor(puv * u_world / 14.0) + vec2(2.0)));
					core = max(core_band * foam_strength, collar * foam_strength * 0.55);
					wash = max(wash_band, wash_dc * 0.45) * foam_strength * 0.42;

					// 双波前：front 3.6 → 1.2 格，宽 0.45 格，相位差 0.5。
					if (foam_amt > 0.04) {
						float shore_noise = (hash21(floor(uv * vec2(90.0, 52.0))) - 0.5) * 0.30;
						float front_sum = 0.0;
						float front_gap = step(0.18, hash21(floor(puv * u_world / vec2(13.0, 11.0)) + vec2(8.0, 4.0)));
						float front_core = 0.0;
						float front_wash = 0.0;
						for (int k = 0; k < 2; k++) {
							float c = fract(u_time * 0.18 * (0.72 + 0.55 * u_tide)
									+ float(k) * 0.5);
							float front = 3.6 - 2.4 * c + shore_noise;
							float band = exp(-pow((dc - front) / 0.34, 2.0));
							float halo = exp(-pow((dc - front) / 0.60, 2.0));
							float amp = (k == 0 ? 1.0 : 0.65) * sin(c * PI2) * sin(c * PI2);
							front_core += band * amp;
							front_wash += halo * amp;
						}
						float fade = 1.0 - smoothstep(4.6, 6.5, dc);
						front_core *= front_gap * fade;
						front_wash *= front_gap * fade;
						if (cat == 2) {
							front_core *= 0.35;
							front_wash *= 0.35;
						}
						core += front_core * 1.40;
						wash += front_wash * 1.00;
					}
				} else {
					// 湖：只保留 1px 水线，不出现泡沫环。
					wash = 0.0;
				}

				// 青沫用比水略深的青绿，白芯才读得出来（brief 的青沫环）。
				vec3 wash_col = mix(u_foam_wash, u_waterline, 0.28);
				water = mix(water, wash_col, clamp(wash * 0.20, 0.0, 0.30));
				water = mix(water, u_foam_core, clamp(core, 0.0, 0.95));

				// 2px 水线暗线：放在泡沫之后，保证沙→湿沙→白芯→青沫→水可读。
				float line = smoothstep(0.10, 0.0, abs(m.g - cut)) * water_sel;
				water = mix(water, u_waterline, line * 0.62);
			}

			// 雨点涟漪：同一水面逻辑，积水处更密、更大。
			if (u_rain > 0.02) {
				vec2 rings = rain_rings(uv, u_rain * (cat == 4 ? 0.9 : 0.22));
				water = mix(water, vec3(0.72, 0.85, 0.82), rings.x * 0.38);
				water = mix(water, vec3(0.93, 0.98, 0.95), rings.y * 0.55);
				// 雨态水面粗糙化：2px 块轻微明度抖动。
				float rough = pixel_hash(puv + vec2(3.7, 1.9)) - 0.5;
				water *= 1.0 + rough * 0.05 * u_rain;
			}

			// 观察模式：非当前水体降饱和压暗。
			if (u_focus > 0.5 && abs(float(cat) - u_focus) > 0.5) {
				float lum = dot(water, vec3(0.30, 0.59, 0.11));
				water = mix(water, vec3(lum) * vec3(0.62, 0.68, 0.66), 0.52);
			}

			// 轻雨丝也落在水面。
			water += vec3(0.62, 0.78, 0.76) * streak * 0.10;
			float alpha = max(water_sel, puddle_amt * step(0.001, pm.r));
			COLOR = vec4(water, alpha);
		}
	}
}
