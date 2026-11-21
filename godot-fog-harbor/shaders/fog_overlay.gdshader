shader_type canvas_item;
// 单次全屏夜间/雾层：暗色遮罩 + 3 个灯光光池 + 玩家手电锥 + 雾纹理 + 暗角。
// 替代 2D Light2D 的多遍渲染；在 GL Compatibility + Intel HD 上更稳定。

uniform sampler2D fog_tex : repeat_enable, filter_linear;
uniform vec4 night_color : source_color = vec4(0.035, 0.07, 0.09, 1.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.66;
uniform float fog_density : hint_range(0.0, 0.5) = 0.085;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.28;
uniform float aspect = 1.7777778;

uniform vec2 player_uv = vec2(0.5);
uniform vec2 aim_dir = vec2(1.0, 0.0);

uniform vec2 lamp0_uv = vec2(-1.0);
uniform vec2 lamp1_uv = vec2(-1.0);
uniform vec2 lamp2_uv = vec2(-1.0);
uniform float lamp_radius = 0.44;
uniform float lamp_power = 0.82;

float lamp_light(vec2 uv, vec2 pos) {
	if (pos.x < 0.0) {
		return 0.0;
	}
	vec2 d = (uv - pos) * vec2(aspect, 1.0);
	return (1.0 - smoothstep(0.06, lamp_radius, length(d))) * lamp_power;
}

void fragment() {
	vec2 uv = UV;
	float illum = 0.0;
	illum += lamp_light(uv, lamp0_uv);
	illum += lamp_light(uv, lamp1_uv);
	illum += lamp_light(uv, lamp2_uv);

	vec2 pd = (uv - player_uv) * vec2(aspect, 1.0);
	float pd_len = length(pd);
	illum += (1.0 - smoothstep(0.03, 0.28, pd_len)) * 0.68;

	vec2 dir = normalize(uv - player_uv + vec2(0.00001));
	float cone_dot = dot(dir, normalize(aim_dir + vec2(0.00001)));
	float cone = smoothstep(0.62, 0.95, cone_dot) * (1.0 - smoothstep(0.06, 0.46, pd_len)) * 0.62;
	illum += cone;

	float dark = darkness * (1.0 - clamp(illum, 0.0, 1.0));
	float n = texture(fog_tex, uv * vec2(2.2, 1.35) + vec2(TIME * 0.006, TIME * 0.003)).r;
	float fog = smoothstep(0.40, 0.90, n) * fog_density;
	vec2 centered = (uv - vec2(0.5)) * vec2(1.0, 0.78);
	float vig = smoothstep(0.78, 0.18, length(centered));
	float alpha = clamp(dark + fog + (1.0 - vig) * vignette_strength * 0.5, 0.0, 0.94);
	COLOR = vec4(night_color.rgb, alpha);
}
