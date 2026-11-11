// Star cluster, one of two kinds:
//  - Globular cluster: an ancient ball of hundreds of thousands of stars. Toward the centre they
//    crowd together into a warm unresolved glow; further out they thin into a sparkling halo of
//    individual yellow, orange and red giants, with the odd blue straggler.
//  - Open cluster, like the Pleiades: a loose group of young, hot blue-white stars with
//    diffraction spikes, wrapped in a wispy blue reflection nebula they light up, plus a scatter
//    of fainter members.
// The whole cluster drifts very slowly. Premultiplied colour/coverage.

// Surface density of a cluster: a flat core of radius rc, falling off outward, gone by rt.
float clusterProfile(float r, float rc, float rt) {
    float x = r / rc;
    return pow(1.0 / (1.0 + x * x), 1.2) * smoothstep(rt, rt * 0.35, r);
}

// One grid layer of cluster stars. Each cell holds at most one star, more likely where the
// cluster is denser; each layer's grid is turned to a different angle so the grids don't show.
vec3 clusterStarLayer(vec2 d, float cells, float ang, float seed, float densK, float rc, float rt,
                      bool globular, float bright, float zoom, float t) {
    vec2 g = rotate(ang) * d * cells;
    vec2 id = floor(g);
    float r = length((id + 0.5) / cells);
    float dens = globular ? clusterProfile(r, rc, rt) : exp(-r * r / (rt * rt));
    if (hash12(id + seed) > dens * densK) {
        return vec3(0.0);
    }
    vec2 pos = 0.5 + (hash22(id + seed + 1.7) - 0.5) * 0.7;
    float dPx = length(fract(g) - pos) * minDim() / cells * zoom;
    float m = hash12(id + seed + 3.3);
    float lum = 0.12 + 0.6 * m * m + 2.2 * pow(m, 14.0);
    // Variable stars (like the RR Lyrae stars common in globulars) swell and fade over seconds.
    float hv = hash12(id + seed + 8.1);
    if (hv < 0.07) {
        float ph = fract(t * mix(0.15, 0.5, hv / 0.07) + hash12(id + seed + 9.4));
        lum *= 0.45 + 1.6 * exp(-ph * 4.0) * smoothstep(0.0, 0.05, ph) + 0.3 * (1.0 - ph);
    }
    vec3 c;
    if (globular) {
        // Old stars: the brightest are red giants; a rare few are hot blue stragglers.
        c = hash12(id + seed + 5.9) < 0.04 ? vec3(0.65, 0.78, 1.0)
          : mix(vec3(1.0, 0.92, 0.78), vec3(1.0, 0.6, 0.35), smoothstep(0.5, 1.0, m));
    } else {
        c = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.92, 0.8), hash12(id + seed + 5.9));
    }
    float ps = pxScale();
    float rad = (0.7 + 0.7 * m) * ps;
    return c * lum * bright * (exp(-dPx * dPx / (rad * rad)) + exp(-dPx / (rad * 3.0)) * 0.08);
}

// A bright star with a soft glow and four diffraction spikes; b is its brightness.
vec3 clusterBrightStar(vec2 uv, vec2 p, float b, vec3 c, float spikeAng, float spikeLen) {
    float ps = pxScale();
    vec2 dv = (uv - p) * minDim();
    float dPx = length(dv);
    float core = exp(-dPx * dPx / (4.0 * ps * ps * (0.6 + b)));
    float glow = exp(-dPx / (10.0 * ps * (0.5 + b))) * 0.25 + exp(-dPx / (45.0 * ps * b)) * 0.05;
    vec2 a = abs(rotate(spikeAng) * dv);
    float len = spikeLen * ps * b;
    float spikes = exp(-a.x / (1.2 * ps)) * exp(-a.y * a.y / (len * len)) + exp(-a.y / (1.2 * ps)) * exp(-a.x * a.x / (len * len));
    return c * (core * 2.0 * b + glow * b + spikes * 0.5 * b);
}

vec4 starCluster(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 ext = halfExtent();
    bool globular = hash12(vec2(slot, seed + 471.0)) < 0.55;
    vec2 center = (hash22(vec2(slot * 7.7, seed + 473.0)) - 0.5) * 2.0 * ext * vec2(0.3, 0.2);
    float lt = eventTime(t);
    center += (hash22(vec2(slot, seed + 475.0)) - 0.5) * 0.0003 * lt;
    // We drift slowly toward the cluster while the view turns a little. Nearer (brighter) stars
    // spread outward faster than the distant crowd, giving a sense of depth.
    float spin = (hash12(vec2(slot, seed + 497.0)) - 0.5) * 0.002 * lt;
    vec2 d0 = rotate(spin) * (uv - center);
    float zoom = 1.0 + 0.001 * lt;
    vec2 d = d0 / zoom;
    float r = length(d);
    float spikeAng = (hash12(vec2(slot, seed + 477.0)) - 0.5) * 0.5;
    vec3 col = vec3(0.0);
    float alpha = 0.0;

    if (globular) {
        float R = mix(0.15, 0.22, hash12(vec2(slot, seed + 479.0)));
        float rc = R * 0.35;
        float rt = R * 3.2;
        if (r < rt * 1.2) {
            // Unresolved light of the countless stars too faint to see one by one.
            float x = r / rc;
            float smoothGlow = pow(1.0 / (1.0 + x * x), 1.5) * smoothstep(rt, 0.0, r);
            col += vec3(1.0, 0.86, 0.66) * (smoothGlow * 0.55 + exp(-r / (R * 0.8)) * 0.08);
            // Grainy shimmer of just-resolved stars over the core glow.
            float grain = noise(d * minDim() * 0.35 + seed);
            col += vec3(1.0, 0.9, 0.75) * smoothGlow * pow(grain, 4.0) * 0.5;
            alpha = clamp(smoothGlow * 0.8, 0.0, 0.9);
            // Resolved stars at three sizes.
            float z1 = 1.0 + 0.0016 * lt, z2 = 1.0 + 0.0012 * lt, z3 = zoom, z4 = 1.0 + 0.0008 * lt;
            col += clusterStarLayer(d0 / z1, 150.0, 0.0, seed + 11.0, 1.2, rc, rt, true, 1.2, z1, t);
            col += clusterStarLayer(d0 / z2, 260.0, 0.7, seed + 23.0, 1.2, rc, rt, true, 0.9, z2, t);
            col += clusterStarLayer(d0 / z3, 430.0, 1.9, seed + 37.0, 1.1, rc, rt, true, 0.65, z3, t);
            col += clusterStarLayer(d0 / z4, 700.0, 2.6, seed + 43.0, 1.0, rc, rt, true, 0.45, z4, t);
        }
        // A handful of the brightest giants, with small spikes.
        for (int i = 0; i < 10; i++) {
            float fi = float(i);
            vec2 h = hash22(vec2(fi * 3.1 + slot, seed + 481.0));
            vec2 p = center + rotate(-spin) * vec2(cos(h.x * 6.2831), sin(h.x * 6.2831)) * R * 0.9 * sqrt(-log(max(h.y, 0.02))) * (1.0 + 0.002 * lt);
            float b = mix(0.35, 0.8, hash12(vec2(fi, seed + 483.0)));
            // A few of the giants are slow pulsating variables.
            b *= 1.0 + 0.35 * step(0.6, hash12(vec2(fi, seed + 499.0))) * sin(t * mix(0.3, 0.8, h.y) + fi * 2.0);
            vec3 c = hash12(vec2(fi, seed + 485.0)) < 0.2 ? vec3(0.7, 0.8, 1.0) : vec3(1.0, 0.7, 0.45);
            col += clusterBrightStar(uv, p, b, c, spikeAng, 30.0);
        }
    } else {
        // Open cluster: the bright blue stars, and the nebula they light.
        float spread = mix(0.16, 0.24, hash12(vec2(slot, seed + 487.0)));
        float illum = 0.0;
        for (int i = 0; i < 12; i++) {
            float fi = float(i);
            vec2 h = hash22(vec2(fi * 5.3 + slot, seed + 489.0));
            vec2 p = center + rotate(-spin) * (h - 0.5) * 2.0 * spread * vec2(1.3, 1.0) * (1.0 + 0.002 * lt);
            float b = mix(0.3, 1.1, pow(hash12(vec2(fi, seed + 491.0)), 2.0));
            vec3 c = mix(vec3(0.62, 0.76, 1.0), vec3(0.9, 0.94, 1.0), hash12(vec2(fi, seed + 493.0)));
            col += clusterBrightStar(uv, p, b, c, spikeAng, 90.0);
            float ds = length(uv - p);
            illum += b * (exp(-ds / 0.09) + exp(-ds / 0.03) * 0.6);
        }
        // Reflection nebula: wispy streaks of dust lit blue, combed in one direction.
        float nAng = hash12(vec2(slot, seed + 495.0)) * 3.1416;
        vec2 nq = rotate(nAng) * d;
        float flow = lt * 0.006;
        float streaks = fbm(nq * vec2(3.0, 16.0) + fbm(d * 3.0 + seed) * 2.0 + seed + vec2(flow, 0.0));
        float clouds = fbm(d * 4.0 - seed + vec2(0.0, flow));
        float neb = smoothstep(0.35, 0.8, streaks * 0.6 + clouds * 0.5) * (0.4 + 0.6 * clouds);
        col += vec3(0.35, 0.55, 1.0) * neb * illum * 0.35;
        col += vec3(0.5, 0.65, 1.0) * illum * 0.02;
        // Fainter members, concentrated toward the middle.
        float z1 = 1.0 + 0.0015 * lt, z2 = 1.0 + 0.0008 * lt;
        col += clusterStarLayer(d0 / z1, 110.0, 0.4, seed + 51.0, 0.35, 0.0, spread * 1.5, false, 0.8, z1, t);
        col += clusterStarLayer(d0 / z2, 210.0, 1.3, seed + 67.0, 0.3, 0.0, spread * 1.8, false, 0.5, z2, t);
    }
    return vec4(col, alpha) * fade;
}
