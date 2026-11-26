shader_type canvas_item;
render_mode unshaded;

// Ordered-ish block dissolve between the old snapshot and the new scene.
// Uses a deterministic 8x8 hash so the pattern is stable for screenshots.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 blocks = vec2(160.0, 90.0);

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float bayer8(vec2 cell) {
    vec2 m = mod(cell, 8.0);
    int x = int(m.x);
    int y = int(m.y);
    int idx = y * 8 + x;
    // 8x8 Bayer threshold table packed as arithmetic (stable, no arrays).
    float v = 0.0;
    int bits = idx;
    float weight = 0.5;
    for (int i = 0; i < 6; i++) {
        int bit = (bits >> i) & 1;
        int ibit = ((idx >> (i + 1)) ^ (idx >> (5 - i))) & 1;
        v += float(bit ^ ibit) * weight;
        weight *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 cell = floor(UV * blocks);
    float th = bayer8(cell) * 0.75 + hash21(cell) * 0.25;
    if (th < progress) {
        discard;
    }
    vec4 c = texture(TEXTURE, UV);
    c.rgb *= 0.62;
    COLOR = c;
}
