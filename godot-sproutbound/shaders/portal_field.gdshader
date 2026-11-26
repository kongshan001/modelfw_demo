shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

// 石拱门内的叶脉光场：未激活时几乎透明，激活后旋转增亮。
uniform vec4 tint : source_color = vec4(0.52, 1.0, 0.70, 1.0);
uniform float active_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float swirl = sin(ang * 3.0 + TIME * 1.8 - r * 10.0) * 0.5 + 0.5;
	float veins = pow(0.5 + 0.5 * sin(ang * 6.0 + TIME * 0.7), 3.0);
	float edge = 1.0 - smoothstep(0.68, 1.0, r);
	float alpha = (0.08 + active_amount * (0.52 + 0.38 * swirl + 0.12 * veins)) * edge;
	ALBEDO = tint.rgb * (0.55 + 0.7 * swirl + 0.25 * veins);
	ALPHA = clamp(alpha, 0.0, 0.92);
}
