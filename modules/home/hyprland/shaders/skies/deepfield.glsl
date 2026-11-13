// A Hubble Deep Field sky: near-black, scattered with tiny distant galaxies - golden ellipticals,
// blue spirals (some edge-on), and faint red specks far beyond.
vec3 deepField(vec2 uv, vec2 seed, float t) {
    vec3 acc = vec3(0.0);
    float ps = pxScale() / minDim();
    for (int l = 0; l < 2; l++) {
        float cells = l == 0 ? 11.0 : 26.0;
        vec2 g = (uv + vec2(t * 0.0004, 0.0)) * cells + seed * 3.0 + float(l) * 7.7;
        vec2 id = floor(g);
        if (hash12(id + 1.3) > (l == 0 ? 0.55 : 0.75)) {
            continue;
        }
        float kind = hash12(id + 8.3);
        float size = mix(0.006, 0.026, pow(hash12(id + 2.1), 2.5)) * (l == 0 ? 1.0 : 0.5) * (kind < 0.8 ? 1.0 : 0.4);
        // Everything out to r = 3 must stay inside the cell, or the galaxy gets cut off square.
        size = min(size, 0.15 / cells);
        vec2 c = 0.5 + (hash22(id + 3.7) - 0.5) * max(1.0 - 6.0 * size * cells, 0.0);
        vec2 q = (fract(g) - c) / cells;
        float axis = mix(0.25, 1.0, hash12(id + 4.9));
        q = rotate(hash12(id + 6.1) * 6.2831) * q;
        q.y /= axis;
        float r = length(q) / size;
        if (r > 3.0) {
            continue;
        }
        vec3 col;
        float prof;
        if (kind < 0.35) {          // elliptical: smooth golden glow
            col = vec3(1.0, 0.82, 0.55);
            prof = exp(-r * 2.2) * 1.2;
        } else if (kind < 0.8) {    // spiral: a bright core in a blue disk with two faint arms
            float th = atan(q.y, q.x);
            float arms = 0.5 + 0.5 * cos(2.0 * th - log(max(r, 0.05)) * 3.0);
            col = mix(vec3(0.6, 0.72, 1.0), vec3(1.0, 0.88, 0.7), exp(-r * 3.0));
            prof = exp(-r * 6.0) * 1.2 + exp(-r * 1.6) * (0.25 + 0.5 * arms) * 0.6;
        } else {                    // very far away: a small red smudge
            col = vec3(1.0, 0.45, 0.35);
            prof = exp(-r * r * 2.0) * 0.7;
        }
        // At least a pixel or two across, however small.
        float minR = ps * 1.2 / size;
        prof *= min(1.0, 1.0 / (minR * minR + 0.2));
        acc += col * prof * mix(0.25, 0.7, hash12(id + 9.7));
    }
    return acc;
}
