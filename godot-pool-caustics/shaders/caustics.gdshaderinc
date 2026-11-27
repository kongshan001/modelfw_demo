// 池底光网 · 公共 Voronoi / F1 / F2 焦散核心（原创实现）。
//
// 参考公开教程的“思路”而非代码：特征点格网 → 3×3 邻域找最近 F1 与次近 F2 →
// F2−F1 在边界归零 → 指数衰减成细亮线 + 宽柔光；再加坐标扭曲、交点鼓结、
// 低频明暗聚散。同一函数同时供池底、圆石与熔岩变体使用。

uniform float u_time = 0.0;
uniform float u_scale = 0.72;       // 世界单位 → 格子数
uniform float u_width = 0.050;      // 亮纹宽度（格单位）
uniform float u_softness = 0.95;    // 宽柔光扩散
uniform float u_brightness = 1.00;
uniform float u_speed = 0.46;
uniform float u_warp_amount = 0.96; // 坐标扭曲强度
uniform float u_junction = 1.42;    // 交点鼓结
uniform float u_gather = 0.94;      // 低频明暗聚散
uniform float u_soft_light = 0.95;  // 宽柔光开关/强度
uniform float u_search_3x3 = 1.0;   // 0 = 单格，1 = 3×3 邻域
uniform int u_debug = 0;            // 0 final / 1 F1 / 2 F2 / 3 F2−F1 / 4 beam / 5 grid / 6 warp
uniform float u_style = 0.0;        // 0 池底 / 1 熔岩
uniform float u_gap_threshold = 0.0;
uniform float u_flow_angle = -31.0;  // 光网漂移方向（度）
uniform float u_seed = 0.0;
uniform vec4 u_line_color : source_color = vec4(0.68, 1.0, 0.93, 1.0);
uniform vec4 u_glow_color : source_color = vec4(0.10, 0.76, 0.68, 1.0);
uniform vec4 u_focus = vec4(0.0, 0.0, 0.0, 0.0);

float caustic_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 caustic_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float caustic_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = caustic_hash12(i);
	float b = caustic_hash12(i + vec2(1.0, 0.0));
	float c = caustic_hash12(i + vec2(0.0, 1.0));
	float d = caustic_hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 便宜的解析式域扭曲：两项错频正弦，足以让格网像水一样漂移。
vec2 caustic_warp(vec2 p, float t) {
	vec2 w = vec2(
		sin(p.y * 0.24 + t * 0.13) + 0.46 * sin(p.x * 0.12 - t * 0.08 + 1.7),
		cos(p.x * 0.27 - t * 0.11) + 0.46 * cos(p.y * 0.14 + t * 0.07 + 4.2)
	);
	// 第二层更细的弯折，让边界不是标准几何折线。
	w += 0.24 * vec2(sin(p.y * 0.87 - t * 0.05), cos(p.x * 0.79 + t * 0.04));
	return w * u_warp_amount * 0.40;
}

struct VoronoiSample {
	float f1;
	float f2;
	float f3;
	vec2 nearest;
	vec2 cell;
	bool has_second;
};

// 9 格搜索：记录最近、次近、第三近。距离先用平方比较，最后统一开方。
VoronoiSample voronoi_f1f2(vec2 q, bool three_by_three) {
	vec2 cell = floor(q);
	float f1 = 1e8;
	float f2 = 1e8;
	float f3 = 1e8;
	vec2 nearest = q;

	if (!three_by_three) {
		vec2 h = caustic_hash22(cell + vec2(u_seed, u_seed * 0.73));
		vec2 site = cell + 0.10 + 0.80 * h;
		nearest = site;
		f1 = dot(site - q, site - q);
	} else {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 g = vec2(float(x), float(y));
				vec2 h = caustic_hash22(cell + g + vec2(u_seed, u_seed * 0.73));
				vec2 site = cell + g + 0.10 + 0.80 * h;
				vec2 diff = site - q;
				float d = dot(diff, diff);
				if (d < f1) {
					f3 = f2;
					f2 = f1;
					f1 = d;
					nearest = site;
				} else if (d < f2) {
					f3 = f2;
					f2 = d;
				} else if (d < f3) {
					f3 = d;
				}
			}
		}
	}

	VoronoiSample v;
	v.f1 = sqrt(f1);
	v.f2 = three_by_three ? sqrt(f2) : 1e4;
	v.f3 = three_by_three ? sqrt(f3) : 1e4;
	v.nearest = nearest;
	v.cell = cell;
	v.has_second = three_by_three;
	return v;
}

struct CausticField {
	float f1;
	float f2;
	float f3;
	float gap;
	float beam;
	float halo;
	float junction;
	float seam;
	float gather;
	vec2 warped;
	vec2 cell;
	vec2 nearest;
	vec2 warp;
};

// 统一焦散场：所有表面都只依赖世界 XZ + 时间，因此池底与圆石上的光网连续。
CausticField caustic_fields(vec2 world_xz, float t) {
	float anim = t * u_speed;
	vec2 p = world_xz * u_scale;
	float flow_a = radians(u_flow_angle);
	vec2 flow = vec2(cos(flow_a), sin(flow_a)) * 0.080 * anim;
	vec2 q = p + flow;
	vec2 warp = caustic_warp(q, anim);
	q += warp;

	bool wide = u_search_3x3 > 0.5;
	VoronoiSample v = voronoi_f1f2(q, wide);

	CausticField c;
	c.f1 = v.f1;
	c.f2 = v.f2;
	c.f3 = v.f3;
	c.warped = q;
	c.cell = v.cell;
	c.nearest = v.nearest;
	c.warp = warp;

	// 格缝：单格演示时能看到“每个像素只看本格”的硬切边。
	vec2 cell_local = q - v.cell;
	float edge = min(min(cell_local.x, 1.0 - cell_local.x),
			min(cell_local.y, 1.0 - cell_local.y));
	c.seam = 1.0 - smoothstep(0.0, 0.045, edge);

	float gap = max(v.f2 - v.f1 - u_gap_threshold, 0.0);
	c.gap = gap;

	// 线宽随 F1 缓变：靠近晶胞中心时光带略鼓，是参考教程后半段的“动态线宽”。
	float local_width = u_width * mix(0.78, 1.46, smoothstep(0.0, 0.90, v.f1));
	float core = exp(-pow(gap / max(local_width, 0.0001), 2.0));

	// 宽柔光用更长的指数尾巴，模拟水体散射后的模糊亮域。
	float halo = exp(-gap / max(u_width * u_softness * 7.0, 0.0001));
	halo = pow(halo, 1.35) * u_soft_light;

	// F3−F1 只在三条边界相交的顶点处接近零 → 交点鼓结。
	float junction = 0.0;
	if (wide) {
		junction = exp(-pow((v.f3 - v.f1) / max(u_width * 2.35, 0.0001), 2.0));
	}

	if (!wide) {
		// 单格对照：用本格 F1 的等距环，被格缝硬切；它不是完整光网，只用于教学对比。
		float ring = exp(-pow(abs(v.f1 - 0.43) / max(u_width * 1.65, 0.0001), 2.0));
		core = ring * 0.62;
		halo = ring * 0.10;
		junction = 0.0;
	}

	float gather = 1.0;
	if (u_gather > 0.001) {
		float n = caustic_noise(q * 0.16 + vec2(anim * 0.035, -anim * 0.022));
		float n2 = caustic_noise(q * 0.39 + vec2(5.2, anim * 0.018));
		float m = clamp(0.66 * n + 0.34 * n2, 0.0, 1.0);
		gather = mix(1.0, 0.10 + 1.92 * pow(m, 1.70), u_gather);
	}
	c.gather = gather;

	// 鼠标聚焦：只在局部加亮，不改变图案本身。
	float focus_d = distance(world_xz, u_focus.xy);
	float focus_boost = 1.0 + u_focus.w * exp(-focus_d * focus_d * 0.22);

	c.beam = core * u_brightness * gather * focus_boost;
	c.halo = halo * u_brightness * mix(gather, 1.0, 0.25) * focus_boost;
	c.junction = junction * u_junction;
	return c;
}

vec3 caustic_light(CausticField c) {
	vec3 hot = u_line_color.rgb;
	vec3 glow = u_glow_color.rgb;
	float core = clamp(c.beam, 0.0, 2.2);
	float halo = clamp(c.halo, 0.0, 1.5);
	float knot = clamp(c.junction, 0.0, 1.0);

	if (u_style < 0.5) {
		// 池底：青白光纹 + 青绿宽柔光，交点略偏白。
		vec3 col = glow * halo * 1.00;
		col += hot * core;
		col += mix(hot, vec3(1.0), 0.42) * knot * 0.66;
		return col;
	}
	// 熔岩：同一距离差，换成宽阈值 + 热色 + 更强的辉光。
	vec3 col = glow * halo * (0.55 + 0.55 * c.junction);
	col += mix(glow, hot, clamp(core, 0.0, 1.0)) * core * 1.15;
	col += hot * knot * 1.05;
	return col;
}

// 调试图的格子与特征点只用于教学，不参与最终光网。
float caustic_grid_glow(CausticField c) {
	vec2 f = fract(c.warped);
	vec2 d = min(f, 1.0 - f);
	float line = 1.0 - smoothstep(0.0, 0.018, min(d.x, d.y));
	float site = 1.0 - smoothstep(0.012, 0.055, length(c.warped - c.nearest));
	return clamp(line * 0.45 + site * 0.9, 0.0, 1.0);
}

vec3 caustic_debug(CausticField c) {
	if (u_debug == 1) {
		float v = 1.0 - smoothstep(0.0, 0.92, c.f1);
		return vec3(v) * vec3(0.74, 1.0, 0.94);
	}
	if (u_debug == 2) {
		if (!(u_search_3x3 > 0.5)) {
			return vec3(0.035);
		}
		float v = 1.0 - smoothstep(0.0, 1.18, c.f2);
		return vec3(v) * vec3(0.72, 0.92, 1.0);
	}
	if (u_debug == 3) {
		if (!(u_search_3x3 > 0.5)) {
			return vec3(0.035);
		}
		// 边界 gap→0 呈亮线，内部按距离差渐暗。
		float edge = exp(-c.gap * 13.0);
		vec3 base = vec3(0.012, 0.035, 0.042) * (0.6 + 0.4 * c.f1);
		return base + vec3(0.82, 0.96, 0.90) * edge;
	}
	if (u_debug == 4) {
		float v = clamp(c.beam * 0.72, 0.0, 1.0);
		return vec3(v) * vec3(0.78, 1.0, 0.92);
	}
	if (u_debug == 6) {
		vec2 w = clamp(c.warp * 1.9 + 0.5, 0.0, 1.0);
		float g = caustic_grid_glow(c);
		return vec3(w.x * 0.65 + g * 0.32, w.y * 0.65 + g * 0.32, 0.22 + g * 0.45);
	}
	return caustic_light(c);
}

// 最终合成入口：f1/f2/gap 在调试模式下以灰阶/色场呈现。
vec3 caustic_composite(CausticField c, vec3 surface) {
	if (u_debug == 0) {
		vec3 light = caustic_light(c);
		if (u_search_3x3 < 0.5) {
			// 单格对照最终图：等距环 + 暗格缝，提醒这不是连续网络。
			surface *= 1.0 - c.seam * 0.62;
		}
		return surface + light;
	}
	if (u_debug == 5) {
		float grid = caustic_grid_glow(c);
		vec3 base = surface * 0.16;
		vec3 light = caustic_light(c) * 0.35;
		return base + light + vec3(0.35, 0.86, 0.80) * grid;
	}
	return caustic_debug(c) * vec3(0.82, 0.96, 0.94);
}
