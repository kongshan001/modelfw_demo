// 海鸥：非受光白羽，翼尖灰，按翼展扑动（同一 MultiMesh 每帧更新位置）。
shader_type spatial;
render_mode cull_disabled, unshaded;

varying vec3 v_col;

void vertex() {
	float phase = INSTANCE_CUSTOM.x * 6.2831;
	float flap = sin(TIME * 6.6 + phase);
	float w = clamp(abs(VERTEX.z) / 1.4, 0.0, 1.0);
	VERTEX.y += flap * w * 0.5;
	vec3 white = vec3(0.965, 0.98, 0.99);
	vec3 gray = vec3(0.66, 0.75, 0.79);
	v_col = mix(white, gray, smoothstep(0.45, 1.15, abs(VERTEX.z)));
}

void fragment() {
	ALBEDO = v_col;
}
