shader_type canvas_item;
render_mode blend_add, unshaded;

// 水面闪光：用同一张水面纹理的 alpha 当遮罩，按时间滚动细碎反光。

uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float flow = 0.0;
uniform float pulse = 1.0;

void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	if (mask.a < 0.1) {
		discard;
	}
	float a = sin(UV.x * 68.0 + flow * 1.7) * sin(UV.y * 46.0 - flow * 1.15 + 0.8);
	float b = sin((UV.x + UV.y) * 92.0 - flow * 0.8);
	float spark = smoothstep(0.80, 0.99, a) * 0.34
			+ smoothstep(0.90, 0.998, b) * 0.18;
	spark *= mask.a * pulse;
	vec3 warm = mix(vec3(0.72, 0.9, 0.95), vec3(1.0, 0.72, 0.32), night);
	COLOR = vec4(warm * spark, spark);
}
