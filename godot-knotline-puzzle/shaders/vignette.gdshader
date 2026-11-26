shader_type canvas_item;

// Soft paper vignette; no screen texture, cheap on integrated GPUs.
uniform vec4 tint : source_color = vec4(0.16, 0.12, 0.08, 0.30);

void fragment() {
	vec2 d = UV - vec2(0.5);
	d.x *= 0.85;
	float r = length(d);
	float edge = smoothstep(0.34, 0.76, r);
	COLOR = vec4(tint.rgb, edge * tint.a);
}
