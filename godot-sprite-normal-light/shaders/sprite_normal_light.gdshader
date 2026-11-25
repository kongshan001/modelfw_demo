shader_type canvas_item;
render_mode unshaded, blend_mix;

// Manual 2D normal-map lighting for one movable point light or one
// directional light. The fragment normal is decoded from an OpenGL-style
// (green = +Y up) tangent-space normal map, mirrored for Sprite2D.flip_h,
// then transformed to world/screen space with the inverse-transpose of the
// sprite's model basis (so rotation and non-uniform scale keep lighting
// coherent). Height is a third component: L = normalize(vec3(to_light.xy, h)).
//
// Alpha of the normal map stores per-pixel roughness (0 smooth / 255 rough).
// This is our own convention; Godot's built-in 2D path ignores that alpha.

global uniform int u_light_mode;          // 0 = point, 1 = directional
global uniform vec2 u_light_pos;          // world/art pixels
global uniform float u_light_height;      // light z above the sprite plane
global uniform float u_light_radius;      // point-light falloff radius (2D)
global uniform vec4 u_light_color;
global uniform float u_light_energy;
global uniform float u_light_angle_deg;   // 0 = from above, 90 = from right
global uniform vec4 u_ambient_color;
global uniform float u_normal_strength;
global uniform float u_roughness;         // 0..1 global bias
global uniform float u_spec_strength;
global uniform float u_rim_strength;
global uniform int u_debug_mode;          // 0 lit, 1 normal, 2 light vec, 3 diffuse, 4 lit+overlay
global uniform bool u_normals_on;

uniform sampler2D normal_tex : hint_normal;
uniform float flip_x = 1.0;

varying vec2 v_world;
varying mat2 v_nmat;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	mat2 basis = mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy);
	// inverse-transpose maps tangent x/y through rotation and inverse scale
	v_nmat = transpose(inverse(basis));
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a < 0.02) {
		discard;
	}
	vec4 ntex = texture(normal_tex, UV);
	vec3 nd = ntex.rgb * 2.0 - 1.0;
	// green is +Y-up in the asset; the screen/world Y axis points down
	nd.xy = vec2(nd.x * flip_x, -nd.y);
	nd.xy *= u_normal_strength;
	if (!u_normals_on) {
		nd = vec3(0.0, 0.0, 1.0);
	}
	// guard against normalizing a zero vector when normals are switched off
	vec2 n_world = v_nmat * nd.xy;
	float n_len = length(n_world);
	n_world = n_len > 0.0001 ? n_world / n_len : vec2(0.0);
	vec3 N = normalize(vec3(n_world, max(nd.z, 0.035)));

	vec3 L;
	float attenuation = 1.0;
	if (u_light_mode == 0) {
		vec3 to_light = vec3(u_light_pos - v_world, u_light_height);
		float dist = max(length(to_light), 0.001);
		L = to_light / dist;
		float planar = length(u_light_pos - v_world);
		attenuation = clamp(1.0 - planar / max(u_light_radius, 1.0), 0.0, 1.0);
		attenuation = pow(attenuation, 1.2);
	} else {
		float a = radians(u_light_angle_deg);
		L = normalize(vec3(sin(a), -cos(a), max(u_light_height, 1.0) / 80.0));
	}

	float ndl = dot(N, L);
	float diffuse = max(ndl, 0.0);
	vec3 V = vec3(0.0, 0.0, 1.0);
	vec3 H = normalize(L + V);
	float rough = clamp(ntex.a + (u_roughness - 0.5), 0.02, 1.0);
	float shininess = mix(120.0, 6.0, rough);
	float specular = pow(max(dot(N, H), 0.0), shininess);
	specular *= u_spec_strength * (1.0 - rough * 0.72);
	specular *= attenuation * smoothstep(-0.05, 0.25, ndl);

	float rim = pow(1.0 - max(dot(N, V), 0.0), 3.0);
	rim *= u_rim_strength * attenuation * (0.25 + 0.75 * diffuse);
	if (!u_normals_on) {
		rim = 0.0;
	}

	vec3 light = u_light_color.rgb * u_light_energy * attenuation;
	vec3 col = base.rgb * (u_ambient_color.rgb + light * diffuse);
	col += light * specular;
	col += u_light_color.rgb * rim;

	if (u_debug_mode == 1) {
		col = ntex.rgb;
	} else if (u_debug_mode == 2) {
		col = L * 0.5 + 0.5;
	} else if (u_debug_mode == 3) {
		col = vec3(diffuse * attenuation);
	}
	COLOR = vec4(min(col, vec3(1.0)), base.a);
}
