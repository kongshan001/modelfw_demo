shader_type canvas_item;
render_mode unshaded;

// The five layers from the study:
//   1 water mask, 2 refracted bottom, 3 water colour, 4 shoreline foam, 5 caustics
// plus event ripples and a day/night tint.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D mask_tex : filter_nearest;
uniform sampler2D depth_tex : filter_nearest;
uniform sampler2D caustic_tex : repeat_enable, filter_nearest;
uniform sampler2D foam_tex : repeat_enable, filter_nearest;

uniform vec2 resolution = vec2(640.0, 360.0);
uniform float time = 0.0;
uniform float day = 1.0;

uniform int debug_mode = 0;      // 0 normal, 1 mask, 2 depth, 3 caustics
uniform float caustic_on = 1.0;
uniform float refract_on = 1.0;
uniform float foam_on = 1.0;

// xy = uv centre, z = start time, w = strength.  Fixed 8 slots.
uniform vec4 ripples[8];

void fragment() {
	vec2 uv = SCREEN_UV;
	float mask = texture(mask_tex, uv).r;
	float depth = texture(depth_tex, uv).r;

	if (debug_mode == 1) {
		COLOR = vec4(vec3(mask), 1.0);
	} else if (debug_mode == 2) {
		COLOR = vec4(vec3(depth), 1.0);
	} else if (debug_mode == 3) {
		float c = texture(caustic_tex, uv * 2.0 + vec2(time * 0.015)).r;
		COLOR = vec4(vec3(c), 1.0);
	} else if (mask < 0.5) {
		discard;
	} else {
		vec2 rip_off = vec2(0.0);
		float rip = 0.0;
		for (int i = 0; i < 8; i++) {
			vec4 r = ripples[i];
			float age = time - r.z;
			if (age >= 0.0 && age <= 3.2) {
				float d = distance(uv * resolution, r.xy * resolution);
				float radius = age * 58.0;
				float band = exp(-abs(d - radius) * 0.09);
				float ring = sin((d - radius) * 0.7) * band * exp(-age * 0.85) * r.w;
				rip += ring;
				rip_off += normalize(uv - r.xy + vec2(1e-4)) * ring * 0.0055;
			}
		}

		vec2 wave = vec2(sin(uv.y * 95.0 + time * 1.8), cos(uv.x * 78.0 - time * 1.45));
		wave *= 0.0045 * (0.35 + depth) * refract_on;
		vec2 off = wave + rip_off * refract_on;
		vec2 snapped = floor((uv + off) * resolution + 0.5) / resolution;
		vec3 bottom = texture(screen_tex, snapped).rgb;
		bottom *= mix(vec3(0.45, 0.55, 0.82), vec3(0.80, 0.98, 0.96), day);

		vec2 cuv = snapped * resolution / 78.0 + off * resolution * 0.35
			+ vec2(time * 0.07, time * 0.05);
		float ca = texture(caustic_tex, cuv).r;
		ca *= smoothstep(0.04, 0.30, depth) * caustic_on;

		vec3 shallow = mix(vec3(0.05, 0.24, 0.34), vec3(0.18, 0.80, 0.76), day);
		vec3 deep = mix(vec3(0.008, 0.05, 0.14), vec3(0.03, 0.30, 0.52), day);
		vec3 wcol = mix(shallow, deep, smoothstep(0.0, 0.85, depth));
		float alpha = mix(0.30, 0.66, smoothstep(0.06, 0.9, depth));
		vec3 col = bottom * (1.0 - alpha) + wcol * alpha;
		col += vec3(0.28, 0.56, 0.52) * ca * mix(0.35, 1.0, day) * (0.25 + 0.45 * depth);
		float surf = smoothstep(0.90, 1.0, sin(uv.x * resolution.x * 0.09 + time * 1.3) * cos(uv.y * resolution.y * 0.07 - time * 0.9));
		col += vec3(0.22, 0.38, 0.38) * surf * 0.06;

		float shore = 1.0 - smoothstep(0.015, 0.16, depth);
		float fn = texture(foam_tex, uv * resolution / 20.0 + vec2(time * 0.45, -time * 0.3)).r;
		float foam = shore * smoothstep(0.22, 0.62, fn + 0.16 * sin(time * 3.0 + uv.x * 52.0));
		foam += max(rip, 0.0) * 0.55;
		foam *= foam_on;
		vec3 foam_col = mix(vec3(0.52, 0.70, 0.82), vec3(0.92, 1.0, 0.97), day);
		col = mix(col, foam_col, clamp(foam, 0.0, 1.0) * 0.9);

		float gx = uv.x - (0.60 + 0.035 * sin(time * 0.45));
		float glint = exp(-gx * gx * 150.0) * smoothstep(0.12, 0.7, depth);
		glint *= 0.55 + 0.45 * sin(uv.y * 60.0 + time * 1.4);
		col += mix(vec3(0.18, 0.42, 0.58), vec3(1.0, 0.93, 0.70), day) * max(glint, 0.0) * mix(0.10, 0.18, day);

		col += vec3(0.45, 0.72, 0.68) * max(rip, 0.0) * 0.22;
		COLOR = vec4(col, 1.0);
	}
}
