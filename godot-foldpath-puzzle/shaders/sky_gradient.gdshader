shader_type sky;

// Seamless vertical paper-sky gradient. Avoids the hard horizon line of
// ProceduralSkyMaterial and keeps the diorama floating in soft haze.

uniform vec3 top_color : source_color = vec3(0.56, 0.69, 0.62);
uniform vec3 horizon_color : source_color = vec3(0.92, 0.87, 0.76);
uniform vec3 bottom_color : source_color = vec3(0.42, 0.53, 0.48);
uniform float top_power : hint_range(0.1, 2.0) = 0.6;
uniform float bottom_power : hint_range(0.1, 2.0) = 0.7;

void sky() {
	float h = EYEDIR.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), top_power));
	} else {
		col = mix(horizon_color, bottom_color, pow(clamp(-h, 0.0, 1.0), bottom_power));
	}
	COLOR = col;
}
