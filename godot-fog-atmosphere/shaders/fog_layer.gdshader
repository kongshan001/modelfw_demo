shader_type spatial;
// 水平贴地雾层：可平铺 patch 噪声 + 世界坐标 UV 漂移 + 角色周围局部雾量遮罩。
// 遮罩只清除“看得见的雾层”，不改变 WorldEnvironment 的全局深度/高度雾（Compatibility 限制）。
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D fog_texture : filter_linear_mipmap, repeat_enable;
uniform vec4 fog_color : source_color = vec4(0.95, 0.97, 0.94, 1.0);
uniform float fog_alpha = 0.15;
uniform vec2 uv_scale = vec2(2.4, 2.4);
uniform vec2 uv_offset = vec2(0.0);

uniform vec3 player_pos = vec3(0.0, 0.0, 0.0);
uniform float clear_radius = 4.5;
uniform float clear_strength = 0.85;
uniform float clear_amount = 0.0;
uniform float body_softness = 0.35;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV * uv_scale + uv_offset;
	float a = texture(fog_texture, uv).a * fog_alpha;
	float d = distance(v_world.xz, player_pos.xz);
	float core = 1.0 - smoothstep(clear_radius * 0.55, clear_radius * 1.55, d);
	float core_near = 1.0 - smoothstep(1.4, 3.0, d);
	float local = max(body_softness * core_near, clear_strength * clear_amount * core);
	a *= 1.0 - local;
	ALBEDO = fog_color.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
