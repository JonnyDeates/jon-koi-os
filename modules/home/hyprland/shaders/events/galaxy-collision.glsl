// Two spiral galaxies partway through merging, like the Antennae or the Mice: two warm cores with
// their spiral arms, slowly circling each other; a long, curving tidal tail of stars flung out from
// each (curving the same way around, as gravity drags them); and a starburst between the cores
// full of pink star-forming regions and young blue clusters, threaded with dust. Emission in .rgb,
// dust in .a.

// Distance from p to a quadratic Bezier curve a-b-c (sampled), and how far along it the nearest
// point is (0..1).
vec2 bezierDist(vec2 p, vec2 a, vec2 b, vec2 c) {
    float best = 1e9;
    float bestS = 0.0;
    vec2 prev = a;
    for (int i = 1; i <= 16; i++) {
        float s = float(i) / 16.0;
        vec2 q = mix(mix(a, b, s), mix(b, c, s), s);
        vec2 seg = q - prev;
        float h = clamp(dot(p - prev, seg) / max(dot(seg, seg), 1e-9), 0.0, 1.0);
        float dd = length(p - prev - seg * h);
        if (dd < best) {
            best = dd;
            bestS = (float(i) - 1.0 + h) / 16.0;
        }
        prev = q;
    }
    return vec2(best, bestS);
}

vec4 galaxyCollision(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 center = (hash22(vec2(slot * 5.9, seed + 351.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.15, 0.1);
    float tilt = hash12(vec2(slot, seed + 353.0)) * 6.2831;
    float size = mix(1.25, 1.6, hash12(vec2(slot, seed + 355.0)));
    float spin = hash12(vec2(slot, seed + 357.0)) < 0.5 ? -1.0 : 1.0;
    // Tail shape: 0 = long and fairly straight (Mice), 1 = sweeping arcs (Antennae).
    float curl = hash12(vec2(slot, seed + 359.0));
    float sep = mix(0.13, 0.2, hash12(vec2(slot, seed + 361.0))) * size;

    mat2 rot = rotate(tilt + t * 0.002 * spin);
    vec2 axis = rot * vec2(1.0, 0.0);
    vec2 perp = vec2(-axis.y, axis.x) * spin;
    vec2 c1 = center - axis * sep * 0.5;
    vec2 c2 = center + axis * sep * 0.5;
    vec2 d = uv - center;
    vec2 px = vec2(1.0 / minDim());

    vec3 col = vec3(0.0);
    float dust = 0.0;
    const vec3 TAIL = vec3(0.62, 0.72, 1.0);
    const vec3 OLD = vec3(1.0, 0.86, 0.66);
    const vec3 PINK = vec3(1.0, 0.42, 0.62);
    const vec3 YOUNG = vec3(0.68, 0.8, 1.0);

    // Tidal tails: each sweeps out from its galaxy, curving the same way around the pair.
    for (int k = 0; k < 2; k++) {
        float sg = k == 0 ? -1.0 : 1.0;
        vec2 ck = k == 0 ? c1 : c2;
        float len = mix(0.35, 0.55, hash12(vec2(slot * 3.0 + float(k), seed + 363.0))) * size;
        vec2 out1 = axis * sg;
        vec2 a = ck;
        vec2 b = ck + out1 * len * 0.6 + perp * sg * len * mix(0.35, 0.8, curl);
        vec2 c = ck + out1 * len * mix(0.7, 0.2, curl) + perp * sg * len * mix(0.75, 1.3, curl);
        // Skip pixels nowhere near this tail (outside its control points' box plus its width).
        vec2 lo = min(min(a, b), c) - 0.2 * size;
        vec2 hi = max(max(a, b), c) + 0.2 * size;
        if (any(lessThan(uv, lo)) || any(greaterThan(uv, hi))) {
            continue;
        }
        vec2 bd = bezierDist(uv, a, b, c);
        float s = bd.y;
        float w = mix(0.025, 0.09, s) * size;
        float body = exp(-bd.x * bd.x / (w * w)) * pow(1.0 - s, 1.5) * smoothstep(0.0, 0.1, s);
        float mottle = 0.5 + 0.8 * fbm((uv - center) * 12.0 + float(k) * 7.0 + seed);
        col += mix(OLD, TAIL, smoothstep(0.0, 0.4, s)) * body * mottle * 0.35;
        // Clumps of young stars strung along the tail.
        float knots = smoothstep(0.68, 0.82, fbm((uv - center) * 40.0 + float(k) * 3.0 - seed));
        col += YOUNG * knots * body * 0.5;
    }

    // The two galaxies: warm cores with short spiral arms, each slightly distorted toward the other.
    for (int k = 0; k < 2; k++) {
        vec2 ck = k == 0 ? c1 : c2;
        float rk = mix(0.9, 1.15, hash12(vec2(slot * 7.0 + float(k), seed + 365.0)));
        vec2 q = rotate(-tilt - float(k) * 0.8) * (uv - ck) / (0.11 * size * rk);
        q.y /= mix(0.5, 0.85, hash12(vec2(slot * 9.0 + float(k), seed + 367.0)));
        float r = length(q);
        if (r > 3.0) {
            continue;
        }
        float th = atan(q.y, q.x);
        float arms = pow(0.5 + 0.5 * cos(2.0 * (th - log(max(r, 0.05)) / 0.35) + fbm(q * 2.0 + seed) * 1.5), 2.0);
        float disk = exp(-r / 0.7) * (0.35 + 0.65 * arms) * smoothstep(2.6, 1.2, r);
        col += mix(OLD, YOUNG, 0.35) * disk * 0.6;
        col += OLD * (exp(-r * r / 0.03) * 1.3 + exp(-r / 0.3) * 0.45); // bright core
        float lane = pow(0.5 + 0.5 * cos(2.0 * (th - log(max(r, 0.05)) / 0.35) + 0.7), 5.0)
                * smoothstep(0.3, 0.8, r) * smoothstep(2.2, 1.2, r) * (0.4 + 0.6 * fbm(q * 3.0 - seed));
        dust = max(dust, lane * 0.35);
    }

    // Starburst between the cores: pink star-forming regions, young blue clusters and dust.
    vec2 m = rotate(-tilt) * d / (sep * 1.4);
    float zone = exp(-dot(m * vec2(1.2, 2.2), m * vec2(1.2, 2.2)));
    if (zone > 0.003) {
    float sb = fbm(d * 26.0 + seed * 2.0);
    col += PINK * smoothstep(0.68, 0.82, sb) * zone * 1.2;
    col += YOUNG * smoothstep(0.7, 0.82, fbm(d * 50.0 - seed)) * zone * 0.7;
    col += mix(OLD, PINK, 0.3) * zone * 0.18;
    float zDust = smoothstep(0.45, 0.7, fbm(d * 14.0 + seed * 3.0)) * zone;
    dust = max(dust, zDust * 0.7);
    }
    col *= 1.0 - dust * 0.75;

    // A scattering of resolved stars over the whole system.
    float glow = 0.0;
    for (int k = 0; k < 2; k++) {
        glow += exp(-length(uv - (k == 0 ? c1 : c2)) / (0.12 * size));
    }
    if (glow > 0.01) {
        col += starLayer(uv, 80.0, 0.3, 1.0, seed + 15.0, t, 1.0) * clamp(glow, 0.0, 1.0) * 0.8;
    }

    return vec4(col, dust * 0.6) * fade;
}
