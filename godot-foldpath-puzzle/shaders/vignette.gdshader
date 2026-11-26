shader_type canvas_item;

// Soft paper vignette + a touch of grain. No textures.

uniform vec4 tint : source_color = vec4(0.055, 0.090, 0.080, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float grain_amount : hint_range(0.0, 0.1) = 0.018;

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = distance(uv, vec2(0.5));
	float edge = smoothstep(0.34, 0.92, d);
	float grain = fract(sin(dot(uv * vec2(1280.0, 720.0) + TIME * 0.7, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	COLOR = vec4(tint.rgb, edge * strength + grain * grain_amount);
}
