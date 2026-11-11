
// Light from the gas flowing between the stars. axis points from the giant to the dwarf; side is
// which way the stream curls (the direction the system spins); tipW is the width of the giant's tip.
vec3 transferLight(vec2 uv, vec2 tip, vec2 dwarf, vec2 axis, float side, float rd, float tipW, float t) {
    vec3 light = vec3(0.0);
    vec2 perp = vec2(-axis.y, axis.x) * side;
    const vec3 GAS = vec3(1.0, 0.42, 0.16);

    // Accretion disk: a tilted ring of swirling gas, white-blue near the dwarf, orange at the rim,
    // viewed a little from above.
    vec2 dq = uv - dwarf;
    vec2 e = vec2(dot(dq, axis), dot(dq, perp) / 0.42) / rd;
    float er = length(e);
    if (er < 1.6) {
        vec2 sw = rotate(-t * 0.5 / pow(max(er, 0.12), 1.5)) * e;
        float swirl = fbm(sw * 3.0 + vec2(er * 6.0));
        float spiral = 0.5 + 0.5 * sin(atan(sw.y, sw.x) * 2.0 + log(max(er, 0.05)) * 6.0);
        float ring = smoothstep(1.1, 0.75, er) * smoothstep(0.04, 0.15, er);
        vec3 dc = mix(vec3(0.9, 0.95, 1.3), GAS, smoothstep(0.15, 0.95, er));
        light += dc * ring * (0.4 + 0.7 * swirl + 0.3 * spiral) * 1.1;
        light += mix(vec3(0.9, 0.95, 1.2), GAS, 0.5) * exp(-er / 0.5) * 0.35; // glow over the disk
    }

    // The stream: wide where it leaves the giant's tip, narrowing as it curls into the disk edge.
    vec2 land = dwarf - axis * rd * 0.55 + perp * rd * 0.42 * 0.8;
    vec2 mid = 0.5 * (tip + land) + perp * rd * 0.35;
    // Distance to the curve, measured to the segments between sample points (measuring to the
    // points alone leaves beads along a thin stream).
    float best = 1e9;
    float bestS = 0.0;
    vec2 prev = tip;
    for (int i = 1; i <= 24; i++) {
        float s = float(i) / 24.0;
        vec2 b = mix(mix(tip, mid, s), mix(mid, land, s), s);
        vec2 seg = b - prev;
        float h = clamp(dot(uv - prev, seg) / dot(seg, seg), 0.0, 1.0);
        float dd = length(uv - prev - seg * h);
        if (dd < best) {
            best = dd;
            bestS = (float(i) - 1.0 + h) / 24.0;
        }
        prev = b;
    }
    float w = mix(tipW, rd * 0.05, smoothstep(0.0, 0.7, bestS));
    float flow = 0.75 + 0.25 * fbm(vec2(bestS * 5.0 - t * 0.5, best / w * 0.5));
    light += GAS * exp(-best * best / (w * w)) * flow * 1.2;
    light += GAS * exp(-best / (w * 3.0)) * 0.15;

    // Hot spot where the stream hits the disk, and the white dwarf at the centre.
    float hs = length(uv - land) / rd;
    light += vec3(1.0, 0.92, 0.75) * (exp(-hs * hs / 0.006) * 1.2 + exp(-hs / 0.15) * 0.25);
    float dPx = length(uv - dwarf) * minDim();
    float ps = pxScale();
    light += vec3(0.9, 0.95, 1.0) * (exp(-dPx * dPx / (5.0 * ps * ps)) * 2.0 + exp(-dPx / (30.0 * ps)) * 0.4);
    return light;
}

// Binary stars: two stars of different kinds orbiting their shared centre on a tilted orbit, passing
// in front of and behind each other (one orbit takes about 2.5 minutes). Premultiplied
// colour/coverage; shimmer is the heat ripple for the sky behind.
vec4 binaryStars(vec2 uv, float seed, float slot, float t, float fade, out float shimmer) {
    shimmer = 0.0;
    vec2 c = (hash22(vec2(slot * 6.7, seed + 251.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.25, 0.2);
    float sysTilt = (hash12(vec2(slot, seed + 253.0)) - 0.5) * 0.7;
    float k = mix(0.25, 0.45, hash12(vec2(slot, seed + 255.0)));    // how flattened the orbit looks
    mat2 plane = rotate(sysTilt);
    float spinSign = hash12(vec2(slot, seed + 257.0)) < 0.5 ? -1.0 : 1.0;
    float phase0 = hash12(vec2(slot, seed + 259.0)) * 6.2831;
    vec3 g1, g2;
    float s1, s2;
    // Two stars of different kinds and sizes; the bigger one is the heavier.
    float k1 = hash12(vec2(slot, seed + 263.0));
    float k2 = hash12(vec2(slot, seed + 265.0));
    float r1 = k1 >= STAR_GIANT && k1 < STAR_BLUE ? 0.14 : k1 >= STAR_BLUE ? 0.065 : 0.1;
    float r2 = k2 >= STAR_GIANT && k2 < STAR_BLUE ? 0.11 : k2 >= STAR_BLUE ? 0.05 : 0.075;
    float sep = (r1 + r2) * mix(2.2, 3.2, hash12(vec2(slot, seed + 267.0)));
    float th = phase0 + spinSign * t * 0.042;
    vec2 o = vec2(cos(th), sin(th));
    vec2 q1 = -o * sep * r2 / (r1 + r2);  // in the orbital plane
    vec2 q2 = o * sep * r1 / (r1 + r2);
    vec2 p1 = c + plane * vec2(q1.x, q1.y * k);
    vec2 p2 = c + plane * vec2(q2.x, q2.y * k);
    vec4 a = star(uv, p1, r1, k1, seed + 11.0, slot, t, 1.0, g1, s1);
    vec4 b = star(uv, p2, r2, k2, seed + 23.0, slot, t, 1.0, g2, s2);
    shimmer = max(s1, s2) * fade;
    // The one on the far side of the orbit (positive y) is behind.
    bool firstBehind = q1.y > 0.0;
    vec4 back = firstBehind ? a : b;
    vec4 front = firstBehind ? b : a;
    vec3 backGlow = firstBehind ? g1 : g2;
    vec3 frontGlow = firstBehind ? g2 : g1;
    vec4 res = over(vec4(backGlow, 0.0), back);
    res = over(front, res);
    res.rgb += frontGlow;
    return res * fade;
}

// A star being eaten: a red giant stretched into a teardrop by a tiny white dwarf. Its outer layers
// turn to glowing gas at the tip and pour off in a stream that curls into a swirling disk around
// the dwarf, with a hot spot where it lands. Real orbits like this take days, so the pair holds
// still; the motion is in the gas. Premultiplied colour/coverage; shimmer is the heat ripple.
vec4 starEaten(vec2 uv, float seed, float slot, float t, float fade, out float shimmer) {
    vec2 c = (hash22(vec2(slot * 6.7, seed + 251.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.2, 0.15);
    c += (hash22(vec2(slot, seed + 273.0)) - 0.5) * 0.0003 * eventTime(t); // a very slow drift
    float ang = hash12(vec2(slot, seed + 253.0)) * 6.2831;
    vec2 axis = vec2(cos(ang), sin(ang));                       // giant -> dwarf
    float side = hash12(vec2(slot, seed + 257.0)) < 0.5 ? -1.0 : 1.0;
    float R = mix(0.12, 0.16, hash12(vec2(slot, seed + 269.0)));
    float sep = R * mix(3.3, 3.8, hash12(vec2(slot, seed + 271.0)));
    vec2 giant = c - axis * sep * 0.45;
    vec2 dwarf = c + axis * sep * 0.55;

    // Stretch the giant toward the dwarf into a teardrop by warping where we sample the star.
    vec2 d = uv - giant;
    float along = dot(d, axis);
    float acr = dot(d, vec2(-axis.y, axis.x));
    float pull = smoothstep(0.0, R * 1.9, along);
    float alongW = along / (1.0 + 0.9 * pull * pull);
    float acrW = acr * (1.0 + 1.6 * pull * pull * pull);
    vec2 warped = giant + axis * alongW + vec2(-axis.y, axis.x) * acrW;
    vec3 g1;
    vec4 body = star(warped, giant, R, 0.55, seed + 31.0, slot, t, 1.0, g1, shimmer);
    shimmer *= fade;

    // Toward the tip the surface dissolves into glowing gas instead of ending in a hard point.
    float gasify = smoothstep(R * 1.15, R * 1.85, along);
    vec3 gasGlow = vec3(1.0, 0.42, 0.16) * body.a * gasify * 0.9;
    body *= 1.0 - gasify * 0.85;

    vec2 tip = giant + axis * R * 1.7;
    vec3 light = transferLight(uv, tip, dwarf, axis, side, R * 0.85, R * 0.16, t);
    vec4 res = over(body, vec4(g1, 0.0));
    res.rgb += light + gasGlow;
    return res * fade;
}
