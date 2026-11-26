shader_type canvas_item;
render_mode unshaded;

uniform float amp = 0.018;

void fragment() {
	vec2 uv = UV;
	float banner = smoothstep(0.10, 0.55, uv.x);
	uv.x += sin(uv.y * 8.0 + TIME * 2.6) * amp * banner;
	uv.y += sin(uv.x * 5.0 + TIME * 1.9) * amp * 0.35 * banner;
	COLOR = texture(TEXTURE, uv);
}
