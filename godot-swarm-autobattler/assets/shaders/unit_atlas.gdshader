shader_type canvas_item;
render_mode unshaded, blend_mix;

// Battle units: one MultiMesh draw call, per-instance atlas cell + frame + flash
// + elite gold outline + faction base shape (ring = ally, chevron = enemy).

uniform vec4 gold : source_color = vec4(0.94, 0.71, 0.35, 1.0);

varying vec2 v_cell_uv;
varying vec2 v_atlas_uv;
varying float v_flash;
varying float v_team;
varying float v_gold;
varying vec2 v_cell_min;
varying vec2 v_cell_max;

void vertex() {
	float card = INSTANCE_CUSTOM.x;
	float frame = INSTANCE_CUSTOM.y;
	v_flash = INSTANCE_CUSTOM.z;
	float code = INSTANCE_CUSTOM.w;
	v_team = step(2.0, code);
	v_gold = step(0.5, code - v_team * 2.0);
	vec2 cell = vec2(1.0 / 12.0, 1.0 / 10.0);
	// MultiMesh quads deliver V from the bottom-left; flip it so the atlas
	// (authored top-down) is upright and the baked contact shadow sits below.
	vec2 uv = clamp(vec2(UV.x, 1.0 - UV.y), vec2(0.006), vec2(0.994));
	v_cell_uv = uv;
	v_atlas_uv = (vec2(frame, card) + uv) * cell;
	// clamp gold-outline taps to this atlas cell: otherwise the 3.5-texel probe
	// wraps into the neighbouring frame and draws a gold box around the quad.
	v_cell_min = v_atlas_uv - uv * cell + cell * 0.02;
	v_cell_max = v_atlas_uv + (vec2(1.0) - uv) * cell - cell * 0.02;
	UV = v_atlas_uv;
}

void fragment() {
	vec4 tex = texture(TEXTURE, v_atlas_uv);
	vec3 col = tex.rgb * COLOR.rgb * 1.12;
	float alpha = tex.a * COLOR.a;

	// faction base plate: 6px ring (ally) vs chevron (enemy)
	vec2 ep = vec2((v_cell_uv.x - 0.5) / 0.255, (v_cell_uv.y - 0.862) / 0.066);
	float ring = 1.0 - smoothstep(0.06, 0.22, abs(length(ep) - 0.9));
	float bx = abs(v_cell_uv.x - 0.5);
	float chev = step(bx, 0.21) * (1.0 - smoothstep(0.010, 0.030, abs(v_cell_uv.y - (0.792 + bx * 0.34))));
	float base_shape = mix(ring, chev, v_team);
	vec3 base_col = mix(COLOR.rgb, vec3(1.0), 0.30);
	base_col = mix(base_col, gold.rgb, v_gold * 0.85);
	float base_a = base_shape * (0.55 + 0.45 * v_gold);
	col = mix(col, base_col, base_a * (1.0 - tex.a));
	alpha = max(alpha, base_a * COLOR.a);

	// per-instance hit flash (0.06 s, highest-brightness combat event)
	col = mix(col, vec3(1.0), v_flash * 0.92);
	alpha = max(alpha, tex.a * v_flash * 0.35);

	// gold rank marker: a small crown above the unit. A 1 px outline around the
	// 64 px source aliases into a gold box at 8-12 px display, so the elite cue
	// is carried by the crown + gold base ring + warmer tint + +4% size.
	if (v_gold > 0.5) {
		vec2 gq = vec2((v_cell_uv.x - 0.5) / 0.085, (v_cell_uv.y - 0.125) / 0.060);
		float crown = 1.0 - smoothstep(0.72, 1.05, abs(gq.x) + abs(gq.y));
		col = mix(col, gold.rgb, crown * 0.95);
		alpha = max(alpha, crown * 0.90 * COLOR.a);
	}
	COLOR = vec4(col, alpha);
}
