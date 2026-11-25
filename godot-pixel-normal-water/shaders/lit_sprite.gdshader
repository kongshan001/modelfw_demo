shader_type canvas_item;
render_mode blend_mix, unshaded;

// 2D 像素法线受光：环境光 + 冷月方向光 + 两盏暖灯点光。
// normal 贴图 alpha 通道 = 自发光遮罩，roughness 贴图 R = 粗糙度。
// 法线不是一张平面贴纸：先取细节法线，再用正交基 (right/up/basis) 重组，
// 让凹凸细节绕基础法线旋转；x/y 分量按 u_normal_strength 独立缩放。

uniform sampler2D u_normal_tex : filter_nearest, repeat_disable;
uniform sampler2D u_rough_tex : filter_nearest, repeat_disable;

uniform bool u_normals_on = true;
uniform float u_normal_strength = 1.0;
uniform vec2 u_light_dir = vec2(0.574, -0.819);
uniform vec3 u_light_color = vec3(0.64, 0.78, 1.0);
uniform float u_light_energy = 1.18;
uniform vec3 u_ambient_color = vec3(0.155, 0.215, 0.335);
uniform float u_specular_strength = 0.32;
uniform float u_emission_strength = 0.0;

uniform vec2 u_lamp_a = vec2(113.0, 78.0);
uniform vec2 u_lamp_b = vec2(185.0, 78.0);
uniform vec3 u_lamp_color = vec3(1.0, 0.60, 0.28);
uniform float u_lamp_energy = 1.20;
uniform float u_lamp_radius = 54.0;
uniform float u_lamp_height = 22.0;
uniform bool u_lamps_on = true;

uniform int u_debug_mode = 0;
uniform float u_time = 0.0;

varying vec2 v_world;

vec3 ortho_detail_normal(vec3 detail, float strength) {
	detail.xy *= strength;
	detail.z = max(detail.z, 0.055);
	// 2D 正交基：basis 指向屏幕外，right/up 在画布平面内。
	vec3 basis = normalize(vec3(0.0, 0.0, 1.0));
	vec3 helper = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(helper, basis));
	vec3 up = cross(basis, right);
	// detail 的 x/y 是绕基础法线的正交细节分量，不直接拼接成“塑料高光”。
	return normalize(right * detail.x + up * detail.y + basis * detail.z);
}

vec3 lamp_contribution(vec2 lamp_pos, vec3 N, vec3 albedo, float rough, float phase) {
	vec2 d = lamp_pos - v_world;
	float dist = length(d);
	float atten = 1.0 - smoothstep(5.0, u_lamp_radius, dist);
	if (atten <= 0.001) {
		return vec3(0.0);
	}
	float flicker = 0.93 + 0.07 * sin(u_time * 3.1 + phase);
	vec3 L = normalize(vec3(d, u_lamp_height));
	float ndl = max(dot(N, L), 0.0);
	vec3 diffuse = albedo * u_lamp_color * ndl * atten * u_lamp_energy * flicker;
	vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
	float exponent = mix(64.0, 8.0, rough);
	float spec = pow(max(dot(N, H), 0.0), exponent)
			* (1.0 - rough) * u_specular_strength * 0.70;
	vec3 highlight = u_lamp_color * spec * atten * u_lamp_energy * flicker;
	return diffuse + highlight;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 albedo_tex = texture(TEXTURE, UV);
	if (albedo_tex.a < 0.5) {
		discard;
	}
	vec4 normal_sample = texture(u_normal_tex, UV);
	vec3 detail = normal_sample.rgb * 2.0 - 1.0;
	float emission_mask = normal_sample.a;
	float rough = texture(u_rough_tex, UV).r;
	rough = clamp(rough, 0.05, 1.0);

	vec3 N = ortho_detail_normal(detail, u_normal_strength);
	if (!u_normals_on) {
		N = vec3(0.0, 0.0, 1.0);
	}

	if (u_debug_mode == 1) {
		COLOR = vec4(N * 0.5 + 0.5, 1.0);
	} else if (u_debug_mode == 2) {
		COLOR = vec4(vec3(rough), 1.0);
	} else {
		vec3 albedo = albedo_tex.rgb;
		vec2 light_xy = normalize(u_light_dir);
		vec3 L = normalize(vec3(light_xy, 0.82));
		float ndl = max(dot(N, L), 0.0);
		// 半兰伯特让背光仍保留一点蓝色环境形，但保留明确的受光面。
		// 轻微像素颗粒乘在 diffuse 上，打破完全均匀的塑料面。
		float grain = fract(sin(dot(floor(v_world), vec2(12.9898, 78.233))) * 43758.5453);
		float diffuse = mix(ndl, smoothstep(0.0, 1.0, ndl), 0.42)
				* (0.965 + grain * 0.035);
		float sky_ambient = 0.72 + 0.28 * clamp(-N.y, 0.0, 1.0);
		vec3 ambient = albedo * u_ambient_color * sky_ambient;
		vec3 direct = albedo * u_light_color * u_light_energy * diffuse;

		vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
		float exponent = mix(96.0, 8.0, rough);
		float spec = pow(max(dot(N, H), 0.0), exponent)
				* (1.0 - rough) * u_specular_strength * diffuse;
		vec3 highlight = u_light_color * spec * u_light_energy;

		vec3 lamp = vec3(0.0);
		if (u_lamps_on) {
			lamp += lamp_contribution(u_lamp_a, N, albedo, rough, 0.0);
			lamp += lamp_contribution(u_lamp_b, N, albedo, rough, 2.2);
		}

		// 自发光只取法线图 alpha 标出的灯窗/灯芯，不会把整片暖色墙面点亮。
		vec3 emission = albedo * emission_mask * u_emission_strength * 1.35;

		vec3 color = ambient + direct + lamp + highlight + emission;
		COLOR = vec4(color, 1.0);
	}
}
