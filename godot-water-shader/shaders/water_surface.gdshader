shader_type canvas_item;
render_mode unshaded, blend_mix;

// 单层水面：全屏 ColorRect，不新建任何水面网格。
// 数据全部来自 16px 栅格：mask(R 硬掩码 / G 覆盖率 / B 桥面裁切)、
// depth(R 展示水深 / G 距岸格数)、category(实体 id)、flow(RG 方向)。
// 海 / 河 / 湖参数用 vec3 传入；湖的浪幅≈0、焦散=0（BFS 内陆湖）。
// 雨积水复用同一函数：低洼 mask + 独立浅水深 + 同一套涟漪/岸线逻辑。

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
uniform vec3 u_foam = vec3(1.0, 0.50, 0.18);
uniform vec3 u_caustic = vec3(1.0, 0.60, 0.0);
uniform vec3 u_sea_deep : source_color = vec3(0.16, 0.42, 0.46);
uniform vec3 u_river_deep : source_color = vec3(0.12, 0.34, 0.32);
uniform vec3 u_lake_deep : source_color = vec3(0.10, 0.26, 0.24);
uniform vec3 u_shallow : source_color = vec3(0.67, 0.83, 0.71);

const float PI2 = 3.14159265;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
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

vec3 pick_deep(int cat) {
	if (cat == 2) {
		return u_river_deep;
	}
	if (cat == 3) {
		return u_lake_deep;
	}
	if (cat == 4) {
		return mix(u_river_deep, u_shallow, 0.35);
	}
	return u_sea_deep;
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

float pixel_hash(vec2 uv) {
	return hash21(floor(uv * u_world * 0.5));
}

float grid_line(vec2 uv) {
	vec2 f = fract(uv * u_world / u_cell);
	return step(0.94, max(f.x, f.y));
}

float rain_streaks(vec2 uv) {
	vec2 q = vec2(uv.x * 150.0, uv.y * 80.0 + u_time * 42.0);
	vec2 g = floor(q);
	vec2 f = fract(q);
	float h = hash21(g);
	float on = step(0.78, h);
	float line = smoothstep(0.34, 0.5, f.x) * smoothstep(0.66, 0.5, f.x);
	float tail = smoothstep(0.0, 0.28, f.y) * smoothstep(1.0, 0.58, f.y);
	float s1 = on * line * tail;
	vec2 q2 = vec2(uv.x * 233.0 + 7.3, uv.y * 121.0 + u_time * 61.0);
	vec2 f2 = fract(q2);
	float s2 = step(0.86, hash21(floor(q2))) * smoothstep(0.38, 0.5, f2.x)
			* smoothstep(0.62, 0.5, f2.x) * smoothstep(0.0, 0.3, f2.y);
	return max(s1, s2 * 0.55);
}

float rain_rings(vec2 uv, float amount) {
	vec2 p = uv * u_world / 10.0;
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash21(id + floor(u_time * 1.6) * vec2(3.1, 7.7));
	float r = fract(u_time * 0.85 + h);
	float ring = smoothstep(0.065, 0.0, abs(length(f) - r * 0.30));
	return ring * step(0.66, hash21(id * 1.37)) * amount;
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
	vec4 pm = texture(u_puddle_mask, uv);
	vec4 d = texture(u_depth, uv);
	vec4 pd = texture(u_puddle_depth, uv);
	vec2 puv = floor(uv * u_world * 0.5) / (u_world * 0.5);

	if (u_debug > 0) {
		COLOR = debug_view(uv, m, pm, d, pd);
	} else {
		// 岸线像素化：2px 块哈希做有序抖动的硬切，潮汐平移切分阈值。
		float dith = pixel_hash(puv) - 0.5;
		float tide_shift = (u_tide - 0.5) * 0.24;
		float water_sel = step(0.5, m.g + dith * 0.16 - tide_shift);
		float puddle_gate = smoothstep(0.04, 0.55, u_rain);
		float puddle_amt = smoothstep(0.26, 0.72, pm.g) * puddle_gate;
		puddle_amt = max(puddle_amt, step(0.5, pm.g + dith * 0.12) * puddle_gate);
		float coverage = max(water_sel, puddle_amt * step(0.001, pm.r));
		float streak = rain_streaks(uv) * u_rain;

		if (coverage < 0.002) {
			float veil = 0.13 * u_rain;
			if (streak > 0.01 || veil > 0.002) {
				COLOR = vec4(vec3(0.10, 0.16, 0.17), veil + streak * 0.58);
			} else {
				discard;
			}
		} else {
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
				foam_amt = 0.22 + 0.30 * u_rain;
				caustic_amt = 0.0;
			}

			float depth = cat == 4 ? pd.r : d.r;
			float dshore = (cat == 4 ? pd.g : d.g) * 16.0;
			// 像素块级的水色抖动，稳定不闪。
			float band_dith = pixel_hash(puv + vec2(11.0, 3.0)) - 0.5;
			float depth_q = clamp(depth + band_dith * 0.035, 0.0, 1.0);

			// 折射采样海底：浅水看得见沙、鹅卵石与河床。
			vec2 refr = vec2(
				sin(uv.y * 34.0 + u_time * 1.05 + flow.x * 1.7),
				cos(uv.x * 29.0 - u_time * 0.85 + flow.y * 1.3)
			) * (0.55 + 1.8 * depth) * wave_amt * 1.8 / u_world;
			vec2 guv = clamp(uv + refr, vec2(0.0), vec2(1.0));
			guv = floor(guv * u_world * 0.5) / (u_world * 0.5);
			vec3 seabed = texture(u_ground, guv).rgb;
			vec3 deep = pick_deep(cat);

			// 焦散：3×3 Voronoi 亮边，只在浅中水且非湖/非积水。
			if (caustic_amt > 0.01) {
				vec2 cp = puv * u_world / 31.0 + flow * u_time * 0.22;
				float edge = voronoi_edge(cp);
				float caus = pow(smoothstep(0.20, 0.0, edge), 1.35);
				float window = smoothstep(0.03, 0.20, depth) * (1.0 - smoothstep(0.52, 0.88, depth));
				seabed += vec3(0.58, 0.86, 0.78) * caus * window * caustic_amt * 0.26;
			}

			vec3 water;
			if (cat == 4) {
				// 积水是一层薄薄的深色水膜：压暗石面，只留雨点涟漪与湿边。
				water = seabed * vec3(0.34, 0.46, 0.47) + vec3(0.012, 0.042, 0.050);
				water = mix(water, u_shallow * 0.16 + seabed * 0.26, 0.16);
				water = mix(water, vec3(0.10, 0.21, 0.24), smoothstep(0.15, 0.75, depth_q) * 0.30);
				float sheen = smoothstep(0.85, 1.0, sin(puv.x * 90.0 + puv.y * 57.0 + u_time * 0.5));
				water += vec3(0.08, 0.12, 0.12) * sheen * 0.45;
			} else {
				// 浅滩沙底先被水色薄薄压一层，深处过渡到类别色。
				float murk = smoothstep(0.02, 0.76, depth_q);
				water = mix(seabed * vec3(0.96, 1.0, 0.93) + u_shallow * 0.10, deep, murk);
				// 浅滩偏暖的沙色反光。
				float sand_glow = (1.0 - murk) * smoothstep(0.015, 0.18, depth_q);
				water = mix(water, water * vec3(1.10, 1.03, 0.84) + vec3(0.055, 0.045, 0.015), sand_glow * 0.42);
				// 深水也保留一点色相起伏，避免整片平涂。
				float deep_var = sin(puv.x * 37.0 + puv.y * 23.0 + u_time * 0.25);
				water += vec3(0.010, 0.018, 0.017) * deep_var * smoothstep(0.3, 0.9, depth);
			}

			// 流动亮纹（河最强，海有缓流，湖为 0，积水无）。
			if (flow_amt > 0.01 && cat != 4) {
				vec2 fs = puv * u_world;
				float along = dot(fs, flow) * 0.055;
				float across = dot(fs, vec2(-flow.y, flow.x)) * 0.22;
				float crest = sin(across + sin(along * 0.6 + u_time * 0.7) * 2.0
						- u_time * (1.25 + 0.22 * flow_amt));
				crest = smoothstep(0.84, 1.0, crest);
				float flow_fade = smoothstep(0.02, 0.25, depth) * (1.0 - smoothstep(0.75, 0.98, depth));
				water += vec3(0.16, 0.27, 0.25) * crest * flow_fade * min(flow_amt, 1.3) * 0.32;
			}

			// 稳定水面闪光（2px 块，8Hz 更替，不闪烁）。
			float sparkle = step(0.988, pixel_hash(puv + floor(u_time * 8.0) * vec2(19.0, 11.0)));
			water += vec3(0.15, 0.23, 0.21) * sparkle * smoothstep(0.05, 0.5, depth) * (0.5 + 0.5 * wave_amt);

			// 双波前 + 岸边白沫：front 从 2 格向 0 推进，两道相位错开。
			float shore_hash = pixel_hash(puv + vec2(5.0, 19.0));
			float foam = 0.0;
			if (cat == 4) {
				float rim = smoothstep(0.12, 0.0, abs(pm.g - 0.5));
				foam = rim * (0.08 + 0.10 * u_rain);
			} else {
				float cut = 0.5 - dith * 0.16 + tide_shift;
				float edge_line = smoothstep(0.085, 0.0, abs(m.g - cut));
				float dshore_n = dshore + (shore_hash - 0.5) * 0.18;
				float crisp = smoothstep(0.20, 0.0, dshore_n);
				float fronts = 0.0;
				if (foam_amt > 0.04 && cat != 3) {
					float phase = hash21(floor(uv * vec2(28.0, 16.0)));
					for (int k = 0; k < 2; k++) {
						float c = fract(u_time * 0.22 * (0.72 + 0.55 * u_tide)
								+ float(k) * 0.5 + phase * 0.18);
						float front = (1.0 - c) * (1.85 + 0.55 * u_tide);
						float band = exp(-pow((dshore_n - front) * 10.0, 2.0));
						band *= 0.60 + 0.40 * pow(abs(sin(c * PI2)), 0.8);
						fronts += band;
					}
					fronts *= 1.0 - smoothstep(2.4, 3.4, dshore_n);
				}
				float line_strength = 0.30 + 0.70 * clamp(foam_amt, 0.0, 1.0);
				float foam_raw = edge_line * line_strength;
				foam_raw += (crisp * 0.18 + fronts * 1.35) * foam_amt;
				foam_raw += smoothstep(1.6, 0.0, dshore_n) * shore_hash * 0.08;
				foam = smoothstep(0.36, 0.60, foam_raw);
			}
			water = mix(water, vec3(0.93, 0.97, 0.88), clamp(foam, 0.0, 0.92));

			// 雨点涟漪：同一水面逻辑，积水处更密。
			if (u_rain > 0.02) {
				float rings = rain_rings(uv, u_rain * (cat == 4 ? 0.85 : 0.20));
				water = mix(water, vec3(0.82, 0.93, 0.90), rings * 0.30);
			}

			// 观察模式：非当前水体降饱和压暗。
			if (u_focus > 0.5 && abs(float(cat) - u_focus) > 0.5) {
				float lum = dot(water, vec3(0.30, 0.59, 0.11));
				water = mix(water, vec3(lum) * vec3(0.62, 0.68, 0.66), 0.52);
			}

			// 轻雨丝也落在水面。
			water += vec3(0.62, 0.78, 0.76) * streak * 0.12;
			float alpha = max(water_sel, puddle_amt * step(0.001, pm.r));
			COLOR = vec4(water, alpha);
		}
	}
}
