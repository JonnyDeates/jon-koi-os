// Pulsar: a tiny, intensely bright neutron star spinning every couple of seconds. Two narrow beams
// shine out from its magnetic poles; the magnetic axis is tilted from the spin axis, so the beams
// sweep around like a lighthouse and the star flares whenever one swings toward us. Faint magnetic
// field loops turn with the beams, and a glowing ring of gas around its equator with jets along its
// spin axis surrounds it (like the Crab and Vela pulsars in X-rays). Emission only.
vec4 pulsar(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 center = (hash22(vec2(slot * 7.9, seed + 281.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.3, 0.2);
    float size = mix(0.8, 1.2, hash12(vec2(slot, seed + 283.0)));
    vec2 d = (uv - center) / size;
    float r = length(d);

    // Spin axis: mostly across the screen, tipped a little toward or away from us.
    float sa = hash12(vec2(slot, seed + 285.0)) * 6.2831;
    vec3 S = normalize(vec3(cos(sa), sin(sa), mix(-0.5, 0.5, hash12(vec2(slot, seed + 287.0)))));
    vec3 e1 = normalize(cross(S, vec3(0.0, 0.0, 1.0)));
    vec3 e2 = cross(S, e1);
    float incl = mix(0.6, 1.0, hash12(vec2(slot, seed + 289.0)));  // magnetic tilt from the spin axis
    float period = mix(1.8, 3.0, hash12(vec2(slot, seed + 291.0)));
    float phi = t * 6.2831 / period;
    vec3 M = cos(incl) * S + sin(incl) * (cos(phi) * e1 + sin(phi) * e2); // magnetic axis, now

    const vec3 BEAM = vec3(0.65, 0.78, 1.0);
    const vec3 HOT = vec3(0.85, 0.9, 1.0);
    const vec3 WIND = vec3(0.55, 0.45, 1.0);
    vec3 col = vec3(0.0);

    // Wind nebula: a tilted, glowing ring around the equator, and wiggly jets along the spin axis.
    vec2 s2 = S.xy;
    float sLen = max(length(s2), 1e-3);
    vec2 sDir = s2 / sLen;
    vec2 sPerp = vec2(-sDir.y, sDir.x);
    float ringX = dot(d, sPerp);
    float ringY = dot(d, sDir) / max(abs(S.z), 0.25);   // the ring looks flatter the more edge-on it is
    float ringR = length(vec2(ringX, ringY)) / 0.22;
    float ring = exp(-pow((ringR - 1.0) / 0.25, 2.0)) * (0.5 + 0.7 * fbm(vec2(atan(ringY, ringX) * 2.0, ringR * 3.0) - t * 0.05 + seed));
    col += WIND * ring * 0.35;
    col += WIND * exp(-r / 0.12) * 0.12;
    float jx = dot(d, sDir);
    float jy = dot(d, sPerp) - sin(jx * 30.0 - t * 1.5) * 0.0025 * min(abs(jx) / 0.05, 1.0);
    float jet = exp(-pow(jy / (0.006 + abs(jx) * 0.05), 2.0)) * exp(-abs(jx) / (0.11 * sLen)) * smoothstep(0.0, 0.02, abs(jx));
    col += mix(WIND, HOT, 0.5) * jet * 0.6 * (0.6 + 0.4 * noise(vec2(jx * 30.0 - t * 2.0, 3.0)));

    // Magnetic field loops in the plane of the magnetic axis, turning with it: r = L sin^2(theta).
    vec2 mDir = normalize(M.xy + 1e-4);
    float th = atan(dot(d, vec2(-mDir.y, mDir.x)), dot(d, mDir));
    float s2th = sin(th) * sin(th);
    for (int i = 0; i < 3; i++) {
        float L = 0.08 + float(i) * 0.06;
        float fl = abs(r - L * s2th);
        col += BEAM * exp(-fl / 0.003) * 0.22 * smoothstep(0.005, 0.02, r) * (0.6 + 0.4 * noise(vec2(th * 6.0, float(i))));
    }

    // Two beams from the magnetic poles: narrow cones, foreshortened when they point at or away from
    // us, and brighter when they point toward us.
    float flash = 0.0;
    for (int k = 0; k < 2; k++) {
        vec3 b = k == 0 ? M : -M;
        vec2 b2 = b.xy;
        float bl = length(b2);
        vec2 bd = b2 / max(bl, 1e-3);
        float along = dot(d, bd);
        float across = dot(d, vec2(-bd.y, bd.x));
        float w = 0.004 + max(along, 0.0) * 0.09;
        float len = 0.9 * bl + 0.05;
        float streak = 0.7 + 0.3 * noise(vec2(along * 20.0 - t * 6.0, across / w));
        float beam = exp(-(across / w) * (across / w)) * exp(-max(along, 0.0) / len)
                * smoothstep(0.0, 0.01, along) * streak;
        float toward = max(b.z, 0.0);
        col += BEAM * beam * (0.35 + 1.2 * toward);
        flash = max(flash, pow(toward, 6.0));
    }

    // The neutron star itself: a tiny white-hot point that flares as a beam sweeps past us.
    float dPx = r * size * minDim();
    float ps = pxScale();
    col += HOT * (exp(-dPx * dPx / (8.0 * ps * ps)) * (2.0 + 4.0 * flash) + exp(-dPx / (40.0 * ps)) * (0.5 + 1.2 * flash));
    col += BEAM * exp(-r / 0.25) * flash * 0.35;  // the flash lights up the surrounding gas
    return vec4(col * fade, 0.0);
}

// Pulsar close-up: the neutron star as a visible blue-white sphere, slowly turning, with blazing hot
// spots at its magnetic poles. 3D magnetic field lines arch from pole to pole all around it, with
// glowing particles streaming along them, and huge searchlight beams pour out of the poles and sweep
// across the screen; the whole scene flashes when one points at us. Emission only.
vec4 pulsarCloseUp(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 center = (hash22(vec2(slot * 8.3, seed + 293.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.2, 0.15);
    float Rs = mix(0.06, 0.08, hash12(vec2(slot, seed + 295.0)));
    vec2 d = uv - center;
    float r = length(d);

    float sa = hash12(vec2(slot, seed + 297.0)) * 6.2831;
    vec3 S = normalize(vec3(cos(sa), sin(sa), mix(-0.4, 0.4, hash12(vec2(slot, seed + 299.0)))));
    vec3 e1 = normalize(cross(S, vec3(0.0, 0.0, 1.0)));
    vec3 e2 = cross(S, e1);
    float incl = mix(0.5, 0.9, hash12(vec2(slot, seed + 301.0)));
    float period = mix(3.0, 5.0, hash12(vec2(slot, seed + 303.0)));
    float phi = t * 6.2831 / period;
    vec3 M = cos(incl) * S + sin(incl) * (cos(phi) * e1 + sin(phi) * e2);
    vec3 u1 = normalize(cross(M, S));
    vec3 u2 = cross(M, u1);

    const vec3 BEAM = vec3(0.6, 0.75, 1.0);
    const vec3 HOT = vec3(0.88, 0.93, 1.0);
    const vec3 WIND = vec3(0.55, 0.45, 1.0);
    float ps = pxScale() / minDim();
    vec3 col = vec3(0.0);

    // Faint, large equatorial ring and jets in the background.
    vec2 sDir = normalize(S.xy + 1e-4);
    vec2 sPerp = vec2(-sDir.y, sDir.x);
    float ringR = length(vec2(dot(d, sPerp), dot(d, sDir) / max(abs(S.z), 0.25))) / (Rs * 9.0);
    col += WIND * exp(-pow((ringR - 1.0) / 0.3, 2.0)) * (0.4 + 0.6 * fbm(vec2(ringR * 4.0, dot(d, sPerp) / Rs) - t * 0.04 + seed)) * 0.18;
    float jx = dot(d, sDir) / Rs;
    float jet = exp(-pow(dot(d, sPerp) / (Rs * (0.15 + abs(jx) * 0.06)), 2.0)) * exp(-abs(jx) / 9.0) * smoothstep(1.0, 2.0, abs(jx));
    col += WIND * jet * 0.25 * (0.6 + 0.4 * noise(vec2(jx * 2.0 - t * 2.0, 1.0)));

    // Beams from the magnetic poles, with a bright core and a wide halo, streaming outward.
    vec3 frontBeam = vec3(0.0);
    float flash = 0.0;
    for (int k = 0; k < 2; k++) {
        vec3 b = k == 0 ? M : -M;
        float bl = length(b.xy);
        vec2 bd = b.xy / max(bl, 1e-3);
        vec2 o = b.xy * Rs;
        float along = dot(d - o, bd);
        float across = dot(d - o, vec2(-bd.y, bd.x));
        float w = Rs * 0.25 + max(along, 0.0) * 0.16;
        float len = 1.4 * bl + 0.08;
        float streak = 0.7 + 0.3 * fbm(vec2(along / Rs * 1.5 - t * 8.0, across / w * 1.5) + float(k) * 7.0);
        float body = exp(-max(along, 0.0) / len) * smoothstep(-Rs * 0.2, Rs * 0.3, along) * streak;
        float beam = (exp(-pow(across / (w * 0.3), 2.0)) * 1.2 + exp(-pow(across / w, 2.0)) * 0.45) * body;
        float toward = max(b.z, 0.0);
        vec3 bc = BEAM * beam * (0.5 + 1.5 * toward);
        if (b.z > 0.0) {
            frontBeam += bc;
        } else {
            col += bc;
        }
        flash = max(flash, pow(toward, 8.0));
    }

    // Magnetic field lines r = L sin^2(theta) around the magnetic axis, in 3D, with particles
    // streaming along them. Lines behind the star are hidden by it.
    if (r < Rs * 4.4) {
        for (int k = 0; k < 8; k++) {
            float psi = float(k) * 0.7854 + seed;
            float L = (k % 2 == 0) ? 2.4 : 3.6;
            vec3 radial = cos(psi) * u1 + sin(psi) * u2;
            float th0 = asin(sqrt(1.0 / L));
            vec3 prev = Rs * (cos(th0) * M + sin(th0) * radial);
            float best = 1e9;
            float bestS = 0.0;
            float bestZ = 0.0;
            for (int i = 1; i <= 24; i++) {
                float th = mix(th0, 3.14159 - th0, float(i) / 24.0);
                float rr = L * sin(th) * sin(th);
                vec3 p = Rs * rr * (cos(th) * M + sin(th) * radial);
                vec2 seg = p.xy - prev.xy;
                float h = clamp(dot(d - prev.xy, seg) / max(dot(seg, seg), 1e-9), 0.0, 1.0);
                float dd = length(d - prev.xy - seg * h);
                if (dd < best) {
                    best = dd;
                    bestS = (float(i) - 1.0 + h) / 24.0;
                    bestZ = mix(prev.z, p.z, h);
                }
                prev = p;
            }
            float hidden = (bestZ < 0.0 && r < Rs) ? 1.0 : 0.0;
            float w = ps * 1.3;
            float flow = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(bestS * 40.0 - t * 5.0 + float(k) * 2.0), 3.0);
            float fadeOut = 0.55 + 0.45 * max(bestZ, 0.0) / (Rs * 2.0); // lines toward the back are dimmer
            col += BEAM * (exp(-best * best / (w * w)) * 0.45 + exp(-best / (w * 8.0)) * 0.14) * flow * (1.0 - hidden) * clamp(fadeOut, 0.4, 1.0);
        }
    }

    // The neutron star: a turning blue-white sphere with blazing polar caps.
    float ns = 0.0;
    if (r < Rs * 1.05) {
        float z = sqrt(max(Rs * Rs - r * r, 0.0));
        vec3 n = vec3(d, z) / Rs;
        vec2 ab = rotate(-phi) * vec2(dot(n, e1), dot(n, e2));
        float tex = fbm(vec2(atan(ab.y, ab.x) * 2.0, dot(n, S) * 4.0) + seed);
        float cap = exp(-(1.0 - dot(n, M)) * 14.0) + exp(-(1.0 + dot(n, M)) * 14.0);
        vec3 surf = HOT * (0.55 + 0.35 * tex) * (0.65 + 0.35 * n.z) + vec3(1.0) * cap * 2.0;
        ns = smoothstep(Rs + ps * 1.5, Rs - ps * 1.5, r);
        col = col * (1.0 - ns) + surf * ns;
    }
    // A glow around the star, flaring when a beam sweeps past us.
    col += HOT * (exp(-max(r - Rs, 0.0) / (Rs * 0.35)) * 0.5 + exp(-r / (Rs * 3.0)) * 0.15) * (1.0 + 2.0 * flash) * (1.0 - ns * 0.7);
    col += frontBeam;
    col += BEAM * flash * (0.18 * exp(-r / 0.5) + 0.06);   // the flash lights up everything
    return vec4(col * fade, 0.0);
}
