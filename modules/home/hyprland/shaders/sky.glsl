// Nebula colour sets, chosen by pick in [0, 1): the theme colours (most common), emerald and gold,
// Hubble-style crimson and orange, or violet and cyan.
void nebulaPalette(float pick, out vec3 a, out vec3 b, out vec3 c, out vec3 d) {
    if (pick < 0.4) {
        a = ROSE; b = KOI_BLUE; c = TEAL; d = VIOLET;
    } else if (pick < 0.6) {
        a = vec3(0.95, 0.75, 0.3); b = vec3(0.2, 0.8, 0.55); c = vec3(0.3, 0.6, 0.9); d = vec3(0.15, 0.5, 0.45);
    } else if (pick < 0.8) {
        a = vec3(0.95, 0.3, 0.25); b = vec3(1.0, 0.6, 0.25); c = vec3(0.35, 0.5, 0.9); d = vec3(0.6, 0.2, 0.5);
    } else {
        a = vec3(0.9, 0.4, 0.9); b = vec3(0.3, 0.85, 1.0); c = vec3(0.25, 0.35, 0.95); d = vec3(0.6, 0.35, 1.0);
    }
}

// Returns the nebula colour; dens is its density, used to dim stars behind thick clouds.
vec3 nebula(vec2 uv, vec2 seed, float palettePick, float t, out float dens) {
    vec3 colA, colB, colC, colD;
    nebulaPalette(palettePick, colA, colB, colC, colD);
    vec2 p = uv * 1.4 + seed * 7.0;
    float nt = t * 0.012;
    vec2 q = vec2(fbm(p + vec2(0.0, nt)), fbm(p + vec2(5.2, 1.3) - nt));
    vec2 r = vec2(fbm(p + 3.0 * q + vec2(1.7, 9.2) + nt * 0.6),
                  fbm(p + 3.0 * q + vec2(8.3, 2.8) - nt * 0.6));
    float n = fbm(p + 3.0 * r);

    // Large-scale mask so nebulas form distinct clouds with empty space between them.
    float mask = smoothstep(0.38, 0.72, noise(p * 0.45 + seed * 3.0 + nt * 0.3));
    dens = smoothstep(0.38, 0.95, n) * mask;

    vec3 c = mix(colA, colB, clamp(q.x * 1.7 - 0.35, 0.0, 1.0));
    c = mix(c, colC, clamp(r.y * 1.5 - 0.6, 0.0, 1.0));
    c = mix(c, colD, clamp(r.x * 1.3 - 0.7, 0.0, 1.0));
    // Push saturation so the clouds read as colour rather than grey haze.
    c = mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, 1.6);
    vec3 col = c * dens * 0.55 + c * pow(dens, 2.5) * 0.9 + vec3(1.0, 0.9, 0.95) * pow(dens, 6.0) * 0.35;

    float dust = smoothstep(0.55, 0.80, fbm(p * 2.3 + r * 1.5 - nt));
    return col * (1.0 - dust * 0.6);
}

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

// The whole background: gradient, nebula, three parallax star layers and a few hot stars.
// skySeed picks the layout and the nebula palette.
vec3 sky(vec2 screen, vec2 bgUv, vec2 skySeed, float t, float lens, float nebulaAmount) {
    vec3 col = mix(vec3(0.035, 0.015, 0.060), vec3(0.008, 0.010, 0.030), screen.y);

    float dens;
    col += nebula(bgUv, skySeed, hash12(skySeed + 5.0), t, dens) * nebulaAmount;
    dens *= nebulaAmount;

    vec3 stars = vec3(0.0);
    stars += starLayer(bgUv + vec2(t * 0.0030, t * 0.0010), 60.0, 0.14, 1.00, skySeed.x, t, lens);
    stars += starLayer(bgUv + vec2(t * 0.0018, t * 0.0006), 110.0, 0.08, 0.70, skySeed.x + 41.0, t, lens);
    stars += starLayer(bgUv + vec2(t * 0.0009, t * 0.0003), 200.0, 0.05, 0.45, skySeed.x + 97.0, t, lens);
    col += stars * (1.0 - dens * 0.4);
    col += heatStars(bgUv + vec2(t * 0.0012, t * 0.0004), skySeed.x + 300.0, t, lens);
    return col;
}
