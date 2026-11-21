shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(1.0);
uniform vec4 bottom_color : source_color = vec4(1.0);
uniform vec4 border_color : source_color = vec4(0.0);
uniform vec4 gloss_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float radius = 10.0;
uniform float border_width = 2.0;
uniform float gloss = 0.0;
uniform float sheen = 0.0;

void fragment() {
	vec2 p = UV * rect_size;
	vec2 hs = rect_size * 0.5;
	vec2 q = abs(p - hs) - (hs - vec2(radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float aa = 1.0;
	float mask = 1.0 - smoothstep(-aa, aa, d);
	if (mask <= 0.002) {
		discard;
	}
	vec3 fill = mix(top_color.rgb, bottom_color.rgb, clamp(UV.y, 0.0, 1.0));
	// soft top gloss
	fill = mix(fill, gloss_color.rgb, gloss * smoothstep(0.55, 0.0, UV.y) * 0.42);
	// diagonal icy sheen
	float diag = clamp((UV.x * 0.65 + (1.0 - UV.y) * 0.35), 0.0, 1.0);
	fill = mix(fill, vec3(1.0), sheen * smoothstep(0.2, 0.9, diag) * 0.22);
	// border, drawn inside the silhouette
	float inside_border = smoothstep(-border_width - aa, -border_width + aa, d);
	vec3 col = mix(fill, border_color.rgb, inside_border * step(0.001, border_width));
	// crisp inner highlight just inside the border
	float rim = 1.0 - smoothstep(1.2, 3.2, abs(d + border_width + 1.2));
	col = mix(col, gloss_color.rgb, rim * step(0.001, border_width) * 0.25);
	COLOR = vec4(col, mix(top_color.a, bottom_color.a, clamp(UV.y, 0.0, 1.0)) * mask);
}
