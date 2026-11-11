// Pillars nebula, like the Pillars of Creation: glowing gas lit from above by an off-screen star
// cluster, with dark columns of dust rising toward the light, their edges glowing where it hits.
// Emission in .rgb (premultiplied); .a is how much the dust blocks the sky behind it.
vec4 pillarNebula(vec2 uv, float seed, float slot, float t) {
    vec2 ext = halfExtent();
    bool hubble = hash12(vec2(slot, seed + 163.0)) < 0.6;
    vec3 hot = hubble ? vec3(0.35, 0.85, 0.85) : vec3(0.45, 0.6, 1.0);   // energetic gas near the stars
    vec3 warm = hubble ? vec3(1.0, 0.7, 0.35) : vec3(1.0, 0.4, 0.55);    // the bulk of the glowing gas
    vec3 dustCol = hubble ? vec3(0.16, 0.09, 0.05) : vec3(0.12, 0.06, 0.08);
    const vec3 RIM = vec3(1.0, 0.9, 0.72);

    // The star cluster lighting everything sits just off the top edge.
    vec2 src = vec2((hash12(vec2(slot, seed + 165.0)) - 0.5) * ext.x, ext.y + 0.3);
    vec2 toSrc = src - uv;
    float nearSrc = exp(-length(toSrc) / 0.9);

    // Glowing gas, drifting very slowly.
    vec2 p = uv * 1.6 + seed;
    float nt = t * 0.006;
    vec2 q = vec2(fbm(p + vec2(0.0, nt)), fbm(p + vec2(4.1, 7.3) - nt));
    float gas = fbm(p * 1.3 + q * 2.2 + nt);
    vec3 col = mix(warm, hot, clamp(nearSrc * 1.4 + (q.x - 0.5), 0.0, 1.0))
            * (0.15 + 0.6 * gas * gas) * (0.4 + 0.9 * nearSrc);
    // Faint rays of light fanning out from the cluster.
    col += warm * 0.08 * smoothstep(0.4, 0.8, noise(normalize(toSrc) * 14.0 + seed)) * nearSrc;
    // The cluster's young stars, crowded near the source.
    col += starLayer(uv, 40.0, 0.5, 2.0, seed + 11.0, t, 1.0) * exp(-length(toSrc) / 0.4);

    // Pillars rising from the bottom toward the light, with ragged, eroded edges.
    float erosion = fbm(uv * 4.0 + seed * 1.7) * 0.7 + fbm(uv * 14.0 - seed) * 0.3;
    float dust = 0.0;
    float rim = 0.0;
    float height = 0.0; // how far up its pillar this pixel is, for lighting the tips
    int count = 2 + int(hash12(vec2(slot, seed + 167.0)) * 1.99);
    float y0 = -ext.y - 0.1;
    for (int i = 0; i < 3; i++) {
        if (i >= count) {
            break;
        }
        float hi = hash12(vec2(slot * 3.0 + float(i), seed + 169.0));
        float baseX = ((float(i) + 0.5) / float(count) * 2.0 - 1.0 + (hi - 0.5) * 0.5) * ext.x * 0.75;
        float tipY = mix(-0.05, ext.y * 0.6, hash12(vec2(hi, 1.0)));
        float lean = (hash12(vec2(hi, 2.0)) - 0.5) * 0.5;
        float wBase = mix(0.12, 0.22, hash12(vec2(hi, 3.0)));

        float s = clamp((uv.y - y0) / (tipY - y0), 0.0, 1.2); // 0 at the bottom, 1 at the tip
        float axis = baseX + lean * s * (tipY - y0) + (noise(vec2(uv.y * 3.0, hi * 10.0)) - 0.5) * 0.1;
        // Tapers toward a broad, rounded head rather than a point.
        float width = wBase * mix(1.0, 0.45, s) * sqrt(max(1.0 - pow(max(s - 0.8, 0.0) / 0.25, 2.0), 0.0));
        float edgeD = width - abs(uv.x - axis) + (erosion - 0.5) * 0.14; // > 0 inside
        float inside = smoothstep(-0.006, 0.02, edgeD) * smoothstep(1.08, 1.0, s);
        if (inside > dust) {
            dust = inside;
            height = s;
        }
        // Edges glow where the light strikes them: the head most, fading down the sides.
        float lit = smoothstep(0.35, 1.0, s) * smoothstep(1.1, 1.0, s);
        rim += exp(-abs(edgeD) / 0.012) * lit * (0.4 + 0.6 * erosion);
    }

    // Inside the pillars: dark dust with lumpy structure, lit warmer near the head.
    float lumps = fbm(uv * 9.0 + seed);
    vec3 dustShade = mix(dustCol, warm * 0.35, smoothstep(0.6, 1.0, height) * lumps)
            * (0.35 + 0.9 * lumps) * (0.35 + 0.65 * height);
    col = col * (1.0 - dust) + dustShade * dust + mix(RIM, warm, 0.3) * min(rim, 1.2) * 0.8;
    // Glowing haze drifting in front of the pillars' bases, so they rise out of the gas.
    float baseHaze = smoothstep(0.0, -ext.y - 0.05, uv.y) * (0.5 + 0.5 * fbm(uv * 3.0 - nt + seed));
    col += warm * 0.22 * baseHaze;
    dust *= 1.0 - 0.6 * baseHaze;
    // A few young stars embedded in the gas.
    col += heatStars(uv + seed, seed + 13.0, t, 1.0) * 0.7;
    return vec4(col, dust);
}

// Colour of a ring nebula's gas at normalised radius s: the hottest, most ionised gas glows blue
// near the star, shading outward through cyan, green and yellow to orange and red.
vec3 ringGradient(float s) {
    const vec3 c0 = vec3(0.22, 0.42, 0.9);  // centre: blue
    const vec3 c1 = vec3(0.2, 0.62, 0.9);   // cyan
    const vec3 c2 = vec3(0.45, 0.82, 0.55); // green
    const vec3 c3 = vec3(0.92, 0.88, 0.4);  // yellow
    const vec3 c4 = vec3(1.0, 0.52, 0.15);  // orange
    const vec3 c5 = vec3(0.85, 0.14, 0.06); // red
    vec3 c = mix(c0, c1, smoothstep(0.3, 0.6, s));
    c = mix(c, c2, smoothstep(0.58, 0.7, s));
    c = mix(c, c3, smoothstep(0.68, 0.8, s));
    c = mix(c, c4, smoothstep(0.8, 0.92, s));
    return mix(c, c5, smoothstep(0.9, 1.05, s));
}

// Ring nebula, like the Hubble photo of M57: a shell of gas thrown off by a dying star around a
// hot white dwarf. Colour runs outward from blue through cyan, green and yellow to orange and red;
// the ring is brightest in the yellow-green band, with fine mottling, small dark dusty knots, and
// a faint, wispy dark-red halo beyond. It expands very slowly. Emission only.
vec4 ringNebula(vec2 uv, float seed, float slot, float t) {
    vec2 center = (hash22(vec2(slot * 7.3, seed + 171.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.3, 0.2);
    float R = mix(0.25, 0.4, hash12(vec2(slot, seed + 173.0)));
    float tilt = hash12(vec2(slot, seed + 175.0)) * 6.2831;
    float squash = mix(0.7, 0.95, hash12(vec2(slot, seed + 177.0)));

    vec2 p = rotate(-tilt) * (uv - center);
    p.y /= squash;
    vec2 dir = p / max(length(p), 1e-4);
    vec2 pr = p / R;
    // Lumpy outline that grows very slowly.
    float lump = 1.0 + (fbm(dir * 2.5 + seed) - 0.5) * 0.16 + t * 0.0002;
    float r = length(p) / R / lump;
    float mottle = fbm(pr * 5.0 + seed);
    float fine = fbm(pr * 14.0 - seed);
    // Ragged boundaries between the colour zones, and between the nebula and space.
    float s = r + (mottle - 0.5) * 0.12 + (fine - 0.5) * 0.05;

    // Brightness: the blue cavity glows softly, the ring peaks in the green-yellow band, and the
    // red rim falls off into the halo.
    float b = 0.5 * smoothstep(1.0, 0.5, s)
            + 0.85 * exp(-pow((s - 0.78) / 0.15, 2.0))
            + 0.35 * exp(-pow((s - 0.98) / 0.07, 2.0));
    b *= 0.7 + 0.6 * mottle;
    // Faint radial streaks in the outer red gas.
    float streak = fbm(dir * 18.0 + vec2(s * 3.0, seed));
    b *= mix(1.0, 0.7 + 0.6 * streak, smoothstep(0.85, 1.0, s));
    vec3 col = ringGradient(s) * b * 1.15;

    // A sprinkling of small dark dusty knots in the ring, each a short streak pointing outward,
    // varied in size and darkness so they don't line up into a pattern.
    float ang = atan(dir.y, dir.x);
    vec2 kg = vec2(ang * 24.0, r * 14.0) + vec2(fine, mottle) * 1.5;
    vec2 kid = floor(kg);
    vec2 kh = hash22(kid + seed);
    vec2 kf = fract(kg) - (0.25 + 0.5 * kh);
    float ksz = mix(0.5, 1.4, hash12(kid + seed + 3.0));
    float knot = exp(-(kf.x * kf.x / (0.004 * ksz) + kf.y * kf.y / (0.03 * ksz)))
            * step(hash12(kid + seed + 7.0), 0.18) * mix(0.3, 0.8, kh.y);
    col *= 1.0 - knot * smoothstep(0.62, 0.72, s) * smoothstep(0.98, 0.88, s);

    // Faint dark-red halo beyond the ring, with wispy loops.
    float halo = smoothstep(0.95, 1.15, s) * exp(-(s - 1.15) * 2.0) * (0.3 + 0.9 * fbm(pr * 2.5 - seed));
    col += vec3(0.5, 0.08, 0.05) * halo * 0.35;

    // The white dwarf at the centre.
    float dPx = length(uv - center) * minDim();
    float ps = pxScale();
    col += vec3(0.85, 0.92, 1.0) * (exp(-dPx * dPx / (4.0 * ps * ps)) * 2.0 + exp(-dPx / (25.0 * ps)) * 0.3);
    return vec4(col, 0.0);
}
