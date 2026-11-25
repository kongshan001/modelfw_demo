shader_type spatial;

// 程序化梦境地砖：两种房间色 + 细缝 + 微弱自发光。
// 单材质即可覆盖整块地面，避免大量 tile 节点拖慢 Intel HD。

render_mode cull_back, diffuse_burley;

uniform vec3 color_a : source_color = vec3(0.10, 0.14, 0.18);
uniform vec3 color_b : source_color = vec3(0.14, 0.19, 0.22);
uniform vec3 edge_color : source_color = vec3(0.38, 0.57, 0.53);
uniform float cell_size = 1.0;
uniform float edge_width = 0.018;
uniform float edge_glow = 0.24;
uniform float checker_amount = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 grid = world_pos.xz / max(cell_size, 0.01);
	vec2 f = fract(grid);
	float checker = mod(floor(grid.x) + floor(grid.y), 2.0);
	vec3 base = mix(color_a, color_b, clamp(checker * checker_amount, 0.0, 1.0));
	vec2 edge_d = min(f, vec2(1.0) - f);
	float line = 1.0 - smoothstep(edge_width, edge_width + 0.012, min(edge_d.x, edge_d.y));
	line = clamp(line, 0.0, 1.0);
	ALBEDO = mix(base, edge_color * 0.55, line * 0.55);
	ROUGHNESS = 0.88;
	SPECULAR = 0.18;
	EMISSION = edge_color * edge_glow * line + base * 0.06;
}
