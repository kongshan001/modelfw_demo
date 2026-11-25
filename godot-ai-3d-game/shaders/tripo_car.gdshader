shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Tripo H3.1 真实感跑车车体：保留 GLB 的 PBR 贴图（底色/ORM/法线），
// 只把大面积的中高明度中性漆面重着成车队色，深色包围/玻璃/轮拱/内饰保持原样。
// 这样三辆车共用同一 GLB，同时保留金属漆的明暗与 PBR 法线细节。
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 body_color : source_color = vec3(1.0, 0.94, 0.82);
uniform float metallic_scale = 0.30;
uniform float roughness_bias = 0.06;

void fragment() {
	vec3 tex = texture(albedo_tex, UV).rgb;
	float lum = dot(tex, vec3(0.299, 0.587, 0.114));
	float sat = max(max(tex.r, tex.g), tex.b) - min(min(tex.r, tex.g), tex.b);
	// 车漆/翼子板是高亮度中性色；深色包围、玻璃、轮拱、内饰亮度低。
	// 红尾灯/蓝色玻璃等有饱和度的细节不重着，避免被车队色染掉。
	float paint = smoothstep(0.30, 0.55, lum) * (1.0 - smoothstep(0.10, 0.26, sat));
	// 头灯/高光是接近纯白的小面积，保留原贴图避免被车队色染掉。
	float lamp = smoothstep(0.90, 0.99, lum);
	vec3 tinted = body_color * (0.52 + lum * 0.58);
	vec3 color = mix(tex, tinted, paint * 0.92);
	color = mix(color, tex, lamp * 0.55);
	ALBEDO = color;

	vec3 orm = texture(orm_tex, UV).rgb;
	METALLIC = clamp(orm.b * metallic_scale, 0.0, 0.85);
	ROUGHNESS = clamp(orm.g + roughness_bias, 0.12, 0.95);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 1.0;
}
