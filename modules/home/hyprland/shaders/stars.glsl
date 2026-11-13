// The background star layers, used by the sky and by scenes that draw their own starfield.

// One small star per occupied grid cell. lens > 1 where a black hole squeezes the sky: stars keep
// their on-screen size and fade so the squeezed region doesn't turn into speckle.
vec3 starLayer(vec2 uv, float cells, float density, float brightness, float seed, float t, float lens) {
    vec2 g = uv * cells;
    vec2 id = floor(g);
    float h = hash12(id + seed);
    if (h > density) {
        return vec3(0.0);
    }
    float cellPx = minDim() / cells / lens;
    vec2 pos = 0.5 + (hash22(id + seed) - 0.5) * 0.6;
    float dPx = length(fract(g) - pos) * cellPx;

    float radius = mix(0.6, 1.5, hash12(id + seed + 3.1)) * pxScale();
    float core = exp(-dPx * dPx / (radius * radius));
    float glow = exp(-dPx / (radius * 2.5)) * 0.10;

    float twinkle = 0.65 + 0.35 * sin(t * mix(0.4, 2.2, hash12(id + seed + 7.7)) + h * 6.2831);
    vec3 tint = mix(starColor(hash12(id + seed + 11.3)), vec3(1.0), 0.55);
    return tint * (core + glow) * twinkle * brightness / (lens * lens);
}

// A few big, hot stars with a pulsing, shimmering corona and diffraction spikes.
vec3 heatStars(vec2 uv, float seed, float t, float lens) {
    const float cells = 3.0;
    vec2 g = uv * cells;
    vec2 base = floor(g);
    vec3 acc = vec3(0.0);
    float ps = pxScale();
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 id = base + vec2(x, y);
            float h = hash12(id + seed + 200.0);
            if (h > 0.30) {
                continue;
            }
            vec2 pos = id + 0.5 + (hash22(id + seed + 200.0) - 0.5) * 0.7;
            vec2 dv = (g - pos) / cells * minDim() / lens; // offset in screen pixels
            float dPx = length(dv);

            vec3 col = starColor(hash12(id + seed + 5.0));
            float size = mix(2.0, 4.5, hash12(id + seed + 9.0)) * ps;
            float pulse = 0.82 + 0.18 * sin(t * mix(0.5, 1.3, h * 3.3) + h * 40.0);

            // Heat shimmer: ripples that travel outward through the corona.
            vec2 dir = dv / max(dPx, 1e-3);
            float shimmer = noise(dir * 3.0 + vec2(dPx / ps * 0.04 - t * 0.9) + id * 13.0);

            float core = exp(-dPx * dPx / (size * size));
            float corona = exp(-dPx / (size * 9.0 * (0.7 + 0.6 * shimmer))) * 0.65 * pulse;
            float halo = exp(-dPx / (size * 25.0)) * 0.12 * pulse;

            // Gaussian falloff keeps the spikes short instead of trailing faint lines across the screen.
            vec2 a = abs(dv);
            float spikeW = 1.1 * ps;
            float spikeLen = size * 14.0 * pulse;
            vec2 along = a / spikeLen;
            float spikes = exp(-a.x / spikeW) * exp(-along.y * along.y) + exp(-a.y / spikeW) * exp(-along.x * along.x);

            acc += col * (corona + halo) + mix(col, vec3(1.0), 0.7) * (core * 1.6 + spikes * 0.45 * pulse);
        }
    }
    return acc / (lens * lens);
}
