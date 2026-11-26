shader_type canvas_item;
render_mode unshaded, blend_add;

// One additive MultiMesh for 6 VFX families (3 frames each, 32px cells).
// INSTANCE_CUSTOM.x = effect row, .y = frame, COLOR = team tint / fade.

varying vec2 v_uv;

void vertex() {
	vec2 cell = vec2(1.0 / 3.0, 1.0 / 6.0);
	v_uv = (vec2(INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.x) + clamp(vec2(UV.x, 1.0 - UV.y), vec2(0.01), vec2(0.99))) * cell;
}

void fragment() {
	vec4 t = texture(TEXTURE, v_uv);
	COLOR = vec4(t.rgb * COLOR.rgb, t.a * COLOR.a);
}
