shader_type canvas_item;
render_mode blend_add, unshaded;

// 圆形发光子弹：白色核心 + 实例色光晕。
// MultiMesh 的每实例 COLOR 会进入 COLOR 输入。

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;
	float glow = smoothstep(1.0, 0.0, d);
	glow = pow(glow, 2.35);
	float core = smoothstep(0.30, 0.0, d);
	core = pow(core, 1.15);
	vec3 tint = COLOR.rgb;
	vec3 col = tint * glow * 2.35 + vec3(0.94, 0.98, 1.0) * core;
	float alpha = clamp(glow * 0.88 + core * 0.95, 0.0, 1.0) * COLOR.a;
	COLOR = vec4(col, alpha);
}
