// Star factory: a stellar nursery filling the whole display, in one of four styles -
//  0. Cosmic Cliffs, like JWST's Carina image: ranges of billowing dust one behind another - far
//     ones pale in the glowing haze, near ones dark - each lit gold along its skyline, under a
//     blue cavity full of young stars with 8-point spikes;
//  1. Orion: a blazing cluster at the heart of a pink-red cloud, teal gas around the core, blue
//     reflection haze, dark lanes of dust;
//  2. Lagoon/Trifid: vivid magenta gas split by snaking dark dust lanes, with a blue reflection
//     lobe and a hot pink core;
//  3. Rosette: a great ring of red-pink gas around a cavity its central cluster has blown clear,
//     teal inside, dotted with dark globules.
// Everything is lit by the young cluster: gas glows brighter near it, dust is rimmed where it
// faces it. The view drifts and pushes in very slowly. Premultiplied colour; .a is how much of
// the background it covers.

// A bright young star with diffraction spikes: JWST's 6 long + 2 short, or Hubble's 4.
vec3 forgeStar(vec2 uv, vec2 p, float b, vec3 c, bool jwst) {
    float ps = pxScale();
    vec2 dv = (uv - p) * minDim();
    float d2 = dot(dv, dv);
    vec3 col = c * (exp(-d2 / (5.0 * ps * ps * (0.5 + b))) * 2.5 * b + exp(-sqrt(d2) / (14.0 * ps * (0.4 + b))) * 0.35 * b);
    float len = 70.0 * ps * b;
    float spikes = 0.0;
    if (jwst) {
        for (int k = 0; k < 3; k++) {
            vec2 a = abs(rotate(float(k) * 1.0472) * dv);
            spikes += exp(-a.x / (1.1 * ps)) * exp(-a.y / len);
        }
        vec2 a = abs(dv);
        spikes += 0.5 * exp(-a.y / (1.0 * ps)) * exp(-a.x / (len * 0.45));
    } else {
        vec2 a = abs(rotate(0.785) * dv);
        spikes = exp(-a.x / (1.1 * ps)) * exp(-a.y / len) + exp(-a.y / (1.1 * ps)) * exp(-a.x / len);
    }
    return col + c * spikes * 0.6 * b;
}

vec4 starForge(vec2 uv, float seed, float slot, float t, float fade) {
    float lt = eventTime(t);
    vec2 ext = halfExtent();
    float sp = hash12(vec2(slot, seed + 801.0));
    int style = sp < 0.3 ? 0 : sp < 0.55 ? 1 : sp < 0.8 ? 2 : 3;

    // A very slow push-in and drift.
    float dr = eventDrift(lt);
    vec2 p = uv / (1.0 + 0.0008 * dr) + vec2(dr * 0.00015, 0.0);
    float s1 = seed * 1.3 + 3.0;

    // The young cluster lighting it all.
    vec2 cl = (hash22(vec2(slot, seed + 803.0)) - 0.5) * 2.0 * ext * vec2(0.55, 0.4);
    if (style == 0) {
        cl.y = ext.y * 0.75;   // above the cliffs, partly off the top
    }
    vec2 toC = cl - p;
    float dc = length(toC);
    vec2 dirC = toC / max(dc, 1e-4);
    float nearC = exp(-dc / 0.45);

    // Gas: a twice-warped noise field, so it billows and streams rather than blotches.
    vec2 w1 = vec2(fbm(p * 1.6 + s1), fbm(p * 1.6 + s1 + 5.2)) - 0.5;
    vec2 w2 = vec2(fbm(p * 2.3 + w1 * 2.2 + 9.1 + s1), fbm(p * 2.3 + w1 * 2.2 + 2.7 - s1)) - 0.5;
    float gas = fbm(p * 2.0 + w2 * 2.4 + seed);
    float fine = fbm(p * 7.0 + w2 * 4.0 - seed);
    // A second gas field for the other element's glow.
    float gas2 = fbm(p * 1.4 - w1 * 2.0 + w2 + seed * 2.0);

    // Bright filaments threading the gas.
    float fil = pow(1.0 - abs(2.0 * fine - 1.0), 4.0) * smoothstep(0.3, 0.7, gas);
    // Gas brightness with real contrast: bright billows, fainter gaps, never flat.
    float g = 0.06 + 1.5 * pow(gas, 2.4) + 0.5 * fil;

    // Dust: soft wispy lanes (broad ridges of warped noise, broken up by finer noise) and patches.
    float laneN = fbm(p * 1.2 + w2 * 1.6 + seed * 3.0);
    float lanes = smoothstep(0.5, 0.95, 1.0 - abs(2.0 * laneN - 1.0)) * (0.55 + 0.6 * fine);
    float patches = smoothstep(0.55, 0.8, fbm(p * 2.6 - w1 * 2.0 - seed * 4.0));

    vec3 col = vec3(0.0);
    float dust = 0.0;
    vec3 rimC = vec3(1.0, 0.8, 0.55);

    if (style == 0) {
        // Cosmic Cliffs: three ranges of dust one behind another, far to near. The far ones are
        // pale and hazy (seen through more glowing gas), the near ones dark, sharp and furrowed.
        // Each is lit gold along its skyline from the cluster above.
        float x = p.x;
        float base0 = mix(-0.12, 0.02, hash12(vec2(slot, seed + 805.0)));
        // The cavity: blue-teal glowing gas, brightest low down where the light skims the cliffs.
        vec3 cav = mix(vec3(0.12, 0.3, 0.7), vec3(0.35, 0.7, 0.95), gas2) * g
                 * (0.5 + 0.8 * smoothstep(0.35, base0, p.y));
        col = cav;
        float cover = 0.0;
        for (int j = 0; j < 3; j++) {
            float fj = float(j);
            float near = fj / 2.0;                       // 0 = farthest, 1 = nearest
            float ls = s1 + fj * 17.3;
            float sc = mix(1.4, 0.8, near);              // nearer ranges are bigger features
            float edgeY = base0 - fj * mix(0.1, 0.16, hash12(vec2(slot, seed + 821.0 + fj)))
                        + (fbm(vec2(x * 0.9 * sc, ls)) - 0.5) * mix(0.25, 0.45, near)
                        + pow(smoothstep(0.45, 0.9, noise(vec2(x * 2.2 * sc, ls + 7.0))), 1.5) * mix(0.1, 0.2, near)
                        + (fbm(vec2(x * 6.0 * sc, ls + 3.0)) - 0.5) * 0.06 + w2.x * 0.05;
            float below = p.y - edgeY;
            float inL = smoothstep(0.012, -0.025, below + (fine - 0.5) * 0.05);
            if (inL <= 0.0) {
                continue;
            }
            // Billowing dust lit from above: lumps facing up catch the light.
            vec2 lq = p * vec2(3.5, 4.5) * sc + w1 * 0.7 + ls;
            float lumps = fbm(lq) * 0.65 + fbm(p * 1.6 * sc + ls * 1.3) * 0.35;
            float lumpsUp = fbm(lq + vec2(0.0, 0.054 * sc)) * 0.65 + fbm((p + vec2(0.0, 0.012)) * 1.6 * sc + ls * 1.3) * 0.35;
            float litUp = clamp(0.5 + (lumpsUp - lumps) * 14.0, 0.0, 1.0);
            float depthIn = clamp(-below / mix(0.3, 0.16, near), 0.0, 1.0);
            // Each range its own warmth: rust, amber or crimson-brown.
            float hue = hash12(vec2(slot, seed + 823.0 + fj));
            vec3 lightC = hue < 0.4 ? vec3(1.0, 0.58, 0.28) : hue < 0.75 ? vec3(1.0, 0.72, 0.38) : vec3(0.95, 0.42, 0.3);
            vec3 darkC = mix(vec3(0.24, 0.1, 0.05), vec3(0.18, 0.06, 0.06), step(0.75, hue));
            vec3 lc = mix(lightC, darkC, depthIn) * (0.2 + 1.2 * litUp * (1.0 - 0.8 * depthIn)) * (0.55 + 0.7 * lumps)
                    * mix(1.0, 0.75, near);
            // Glowing pockets: young stars buried in the dust light it from inside.
            float pocket = smoothstep(0.72, 0.86, fbm(p * 3.0 * sc + ls * 2.1)) * smoothstep(0.05, 0.3, depthIn) * near;
            lc += vec3(1.0, 0.55, 0.3) * pocket * 0.5;
            // Gold along the skyline.
            lc += vec3(1.0, 0.75, 0.42) * exp(-abs(below) / mix(0.006, 0.02, fine)) * (0.35 + 0.5 * fine);
            // Far ranges are seen through more glowing gas: paler, bluer, softer.
            lc = mix(lc, cav * 1.3 + vec3(0.12, 0.1, 0.12), (1.0 - near) * 0.5);
            col = mix(col, lc, inL);
            cover = max(cover, inL * mix(0.75, 0.98, near));
        }
        // Steam rising off the nearest skyline into the cavity.
        float steam = smoothstep(0.6, 0.88, fbm(vec2(x * 9.0 + w1.x * 3.0, p.y * 2.5 - lt * 0.004) + s1)) * (1.0 - cover);
        col += vec3(1.0, 0.72, 0.45) * steam * 0.15;
        dust = cover;
        // Thin dark tendrils of dust drifting in the cavity.
        float tend = lanes * (1.0 - cover) * 0.4;
        col *= 1.0 - tend;
        dust = max(dust, tend);
    } else if (style == 1) {
        // Orion: pink-red gas, teal near the core, a blinding white-pink heart.
        vec3 ha = vec3(1.0, 0.24, 0.36);
        vec3 o3 = vec3(0.2, 0.8, 0.82);
        col = ha * g * (0.3 + 1.5 * nearC);
        col += o3 * smoothstep(0.35, 0.75, gas2) * exp(-dc / 0.3) * 0.9;
        col += vec3(1.0, 0.9, 0.88) * (exp(-dc / 0.06) * 1.3 + exp(-dc / 0.18) * 0.4);
        // Blue reflection haze off to one side.
        vec2 rp = cl + vec2(0.35, 0.15) * (hash12(vec2(slot, seed + 807.0)) < 0.5 ? -1.0 : 1.0);
        col += vec3(0.3, 0.45, 1.0) * exp(-length(p - rp) / 0.25) * (0.3 + 0.7 * gas2) * 0.5;
        dust = clamp(lanes * 0.85 + patches * 0.35, 0.0, 0.9);
        rimC = vec3(1.0, 0.6, 0.6);
    } else if (style == 2) {
        // Lagoon/Trifid: magenta, orange sulphur glow in places, a blue reflection lobe.
        vec3 ha = vec3(1.0, 0.2, 0.55);
        vec3 s2 = vec3(1.0, 0.5, 0.2);
        col = ha * g * (0.4 + 1.2 * nearC);
        col = mix(col, s2 * g * 1.1, smoothstep(0.55, 0.8, gas2) * 0.6);
        col += vec3(1.0, 0.75, 0.85) * exp(-dc / 0.08) * 0.9;
        float lobeSide = hash12(vec2(slot, seed + 809.0)) < 0.5 ? -1.0 : 1.0;
        vec2 lp = cl + vec2(0.0, 0.45 * lobeSide);
        float lobe = exp(-length(p - lp) / 0.28);
        col = mix(col, vec3(0.3, 0.45, 1.0) * (0.15 + 1.1 * gas2 * gas2), lobe * 0.7);
        dust = clamp(lanes * 1.0 + patches * 0.3, 0.0, 0.93);
        rimC = vec3(1.0, 0.7, 0.8);
    } else {
        // Rosette: a great ring of gas around a cavity blown clear by the central cluster.
        float R0 = mix(0.42, 0.58, hash12(vec2(slot, seed + 811.0)));
        float rr = dc / R0 + (gas - 0.5) * 0.45 + w2.y * 0.2;
        float ring = smoothstep(0.5, 0.95, rr) * (rr > 1.0 ? exp(-(rr - 1.0) * 1.6) : 1.0);
        vec3 ha = vec3(1.0, 0.27, 0.36);
        vec3 o3 = vec3(0.25, 0.72, 0.85);
        col = mix(o3, ha, smoothstep(0.55, 0.95, rr)) * g * (0.08 + 1.5 * ring);
        // The cavity isn't empty: a faint teal glow, brighter toward the ring.
        col += o3 * (0.15 + 0.5 * gas2) * smoothstep(0.1, 0.8, rr) * smoothstep(1.0, 0.6, rr) * 0.35;
        // Dark globules: small irregular knots of dust in the ring, a few elephant trunks.
        float glob = smoothstep(0.72, 0.82, fbm(p * 7.0 + w2 * 2.0 + seed * 6.0)) * ring;
        dust = clamp(lanes * 0.6 * ring + glob * 0.85, 0.0, 0.92);
        rimC = vec3(1.0, 0.65, 0.6);
    }

    if (style != 0) {
        // Dust darkens and slightly reddens the glow behind it.
        col = col * (1.0 - dust) + col * vec3(0.25, 0.12, 0.08) * dust;
        // Its edges facing the cluster are lit: brighter where the dust is thin and near the light.
        col += rimC * smoothstep(0.15, 0.45, dust) * smoothstep(0.75, 0.45, dust) * (0.05 + 0.4 * nearC) * g;
    }

    // Young stars: a dusting everywhere, crowded toward the cluster, dimmed behind dust.
    float clear = 1.0 - dust * 0.85;
    col += starLayer(p, 110.0, 0.35, 0.9, seed + 21.0, t, 1.0) * clear;
    col += starLayer(p, 55.0, 0.35, 1.3, seed + 23.0, t, 1.0) * clear * (0.4 + 1.6 * nearC);
    // A handful of bright ones with spikes.
    bool jwst = style == 0 || hash12(vec2(slot, seed + 813.0)) < 0.5;
    for (int i = 0; i < 9; i++) {
        float fi = float(i);
        vec2 h = hash22(vec2(fi * 3.7 + slot, seed + 815.0));
        vec2 sp2 = i < 4 ? cl + (h - 0.5) * (style == 3 ? 0.6 : 0.35) : (h - 0.5) * 2.0 * ext;
        if (style == 0 && i >= 4) {
            sp2.y = abs(sp2.y) * 0.8;   // up in the cavity
        }
        float b = mix(0.35, 1.0, hash12(vec2(fi, seed + 817.0))) * (i < 4 ? 1.0 : 0.6);
        vec3 c = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.95, 0.9), hash12(vec2(fi, seed + 819.0)));
        col += forgeStar(uv, sp2, b, c, jwst);
    }

    float a = clamp(max(dust, dot(col, vec3(0.3, 0.5, 0.2)) * 1.2), 0.0, 0.97);
    return vec4(col, a) * fade;
}
