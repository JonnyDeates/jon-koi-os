// Full-screen nebulae, eight separate scenes sharing this code (style picks which) -
//  0. Cosmic Cliffs, like JWST's Carina image: ranges of billowing dust one behind another - far
//     ones pale in the glowing haze, near ones dark - each lit gold along its skyline, under a
//     blue cavity full of young stars with 8-point spikes;
//  1. Orion: a blazing cluster at the heart of a pink-red cloud, teal gas around the core, blue
//     reflection haze, dark lanes of dust;
//  2. Lagoon/Trifid: vivid magenta gas split by snaking dark dust lanes, with a blue reflection
//     lobe and a hot pink core;
//  3. Rosette: a great ring of red-pink gas around a cavity its central cluster has blown clear,
//     teal inside, dotted with dark globules;
//  4. Horsehead: a glowing red curtain over a dark dust floor, a dark pillar with a bent-over head
//     rearing out of it, a bright star in a blue reflection haze;
//  5. Tarantula: a chaotic web of pink, teal and gold filaments blown into bubbles around a
//     blazing central cluster;
//  6. Veil: braided ropes of shocked gas, teal-blue and red side by side, sweeping in great arcs
//     across dark sky;
//  7. Rho Ophiuchi: a dense Milky Way starfield cut by dark dust, with a golden glow, a blue
//     reflection nebula and red emission.
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

vec4 starForge(vec2 uv, float seed, float slot, float t, float fade, int style) {
    // Each nebula gets its own shapes, not the same clouds in different colours.
    seed += float(style) * 13.7;
    float lt = eventTime(t);
    vec2 ext = halfExtent();

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
    } else if (style == 3) {
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
    } else if (style == 4) {
        // Horsehead: a glowing red curtain of gas streaked vertically along its ionisation front,
        // a dark dust floor, and a dark pillar rearing out of it with a bulging, bent-over head.
        float streak = fbm(vec2(p.x * 2.0 + w1.x, p.y * 9.0 + w2.y * 2.0) + seed * 2.0);
        vec3 ha = vec3(1.0, 0.18, 0.22);
        float curtain = (0.2 + 1.3 * pow(gas, 1.8)) * (0.55 + 0.6 * streak) * (0.6 + 0.5 * smoothstep(-0.4, 0.4, p.y));
        col = ha * curtain;
        col = mix(col, vec3(1.0, 0.45, 0.3) * curtain, smoothstep(0.5, 0.8, gas2) * 0.4);
        // The floor of dark dust.
        float floorY = mix(-0.32, -0.18, hash12(vec2(slot, seed + 825.0))) + (fbm(vec2(p.x * 1.3, s1)) - 0.5) * 0.12 + w2.x * 0.04;
        float fl = smoothstep(0.025, -0.05, p.y - floorY + (fine - 0.5) * 0.06 + (fbm(p * 12.0 + seed) - 0.5) * 0.03);
        // The pillar: a column of dust rising from the floor, swelling into a head that leans to
        // one side, every edge eaten away by the radiation into ragged billows.
        float hx = (hash12(vec2(slot, seed + 827.0)) - 0.5) * ext.x * 0.9;
        float hside = hash12(vec2(slot, seed + 829.0)) < 0.5 ? -1.0 : 1.0;
        float H = mix(0.3, 0.42, hash12(vec2(slot, seed + 831.0)));
        vec2 q = p - vec2(hx, floorY);
        q += (vec2(fbm(q * 4.0 + seed), fbm(q * 4.0 - seed)) - 0.5) * 0.06;
        float up = clamp(q.y / H, 0.0, 1.2);
        float lean = hside * 0.07 * smoothstep(0.55, 1.0, up);
        float w = mix(0.075, 0.045, up) + 0.055 * exp(-pow((up - 0.88) / 0.12, 2.0));
        float erode = (fbm(q * 9.0 + seed * 3.0) - 0.5) * 0.06 + (fbm(q * 25.0 - seed) - 0.5) * 0.025;
        // A soft edge: thin dust at the fringe lets the glow through.
        float horse = smoothstep(0.012, -0.022, abs(q.x - lean) - w + erode) * smoothstep(1.04, 0.86, up + erode * 3.0);
        float body = max(fl, horse);
        // Glowing rim where the curtain's light wraps the dark shapes.
        float rimH = smoothstep(0.0, 0.5, body) * smoothstep(1.0, 0.5, body);
        // The dust is faintly lit from the curtain behind and above, so it isn't flat black.
        col = col * (1.0 - body * 0.93) + vec3(0.18, 0.05, 0.05) * body * (0.3 + 0.7 * fine) * smoothstep(-0.5, 0.0, p.y)
            + vec3(1.0, 0.45, 0.35) * rimH * 0.6 * curtain;
        dust = body * 0.95;
        // A bright star in a blue reflection haze, low in a corner.
        vec2 rsp = vec2(-hside * ext.x * 0.6, floorY + 0.08);
        float rh = exp(-length(p - rsp) / 0.18);
        col = mix(col, vec3(0.35, 0.55, 1.0) * (0.3 + 0.9 * gas2), rh * 0.75);
        col += forgeStar(uv, rsp, 0.9, vec3(0.85, 0.9, 1.0), false);
        rimC = vec3(1.0, 0.5, 0.4);
    } else if (style == 5) {
        // Tarantula: a chaotic web of bright filaments blown into overlapping bubbles by a blazing
        // central cluster, in pink, teal and gold.
        float bub = 0.0;
        for (int k = 0; k < 5; k++) {
            float fk = float(k);
            vec2 bc = cl + (hash22(vec2(fk, seed + 833.0)) - 0.5) * 0.9;
            float br = mix(0.12, 0.3, hash12(vec2(fk, seed + 835.0)));
            float e = length(p - bc) / br + (gas - 0.5) * 0.35;
            bub = max(bub, exp(-pow((e - 1.0) / 0.12, 2.0)));
        }
        float web = pow(1.0 - abs(2.0 * fbm(p * 3.0 + w2 * 3.0 + seed * 4.0) - 1.0), 6.0);
        vec3 pink = vec3(1.0, 0.3, 0.5);
        vec3 teal = vec3(0.25, 0.85, 0.8);
        vec3 gold = vec3(1.0, 0.75, 0.35);
        vec3 tint = mix(mix(pink, teal, smoothstep(0.4, 0.65, gas2)), gold, smoothstep(0.6, 0.8, gas) * 0.5);
        col = tint * (g * 0.45 + web * 0.9 + bub * 0.8 * (0.5 + gas)) * (0.45 + 1.1 * nearC);
        col += vec3(0.9, 0.95, 1.0) * (exp(-dc / 0.05) * 1.6 + exp(-dc / 0.15) * 0.5);
        dust = clamp(lanes * 0.55 + patches * 0.25, 0.0, 0.8);
        rimC = vec3(1.0, 0.75, 0.6);
    } else if (style == 6) {
        // Veil: delicate braided ropes of shocked gas sweeping across dark sky in great arcs, the
        // teal-blue and red emission running side by side.
        vec2 ac = cl + vec2(0.0, -0.9) * (hash12(vec2(slot, seed + 837.0)) < 0.5 ? 1.0 : -1.0);
        float ar = mix(0.8, 1.2, hash12(vec2(slot, seed + 839.0)));
        float da = length(p - ac) - ar;
        // Ropes run along the arc: noise stretched along it, gently wavering.
        float along = atan(p.y - ac.y, p.x - ac.x) * ar;
        // Strong, slow wavering makes neighbouring ropes wander across each other into braids.
        vec2 rq = vec2(da * 14.0 + (fbm(vec2(along * 0.9, seed)) - 0.5) * 7.0 + (fbm(vec2(along * 3.0, seed + 4.0)) - 0.5) * 2.0, along * 1.2) + w2 * 1.2;
        float ropeN = noise(rq + seed * 3.0) * 0.7 + noise(rq * 2.1 + seed) * 0.3;
        float ropeN2 = noise(rq + vec2(0.55, 0.0) + seed * 3.0) * 0.7 + noise(rq * 2.1 + vec2(1.1, 0.0) + seed) * 0.3;
        // In bright stretches and faint gaps along the arc, not one continuous line.
        float band = exp(-pow(da / 0.32, 2.0)) * smoothstep(0.3, 0.65, fbm(vec2(along * 1.6, seed + 9.0)) + gas * 0.3);
        float ropeB = pow(1.0 - abs(2.0 * ropeN - 1.0), 22.0) * band;
        float ropeR = pow(1.0 - abs(2.0 * ropeN2 - 1.0), 22.0) * band;
        // Only a few bundles at any point: the rest of the ropes are gated off, so they come and go.
        float bundle = smoothstep(0.38, 0.62, noise(vec2(da * 4.0 + w1.x * 2.0, along * 0.6) + seed * 5.0));
        ropeB *= bundle;
        ropeR *= bundle;
        float haze = g * band * 0.08;
        col = vec3(0.2, 0.6, 1.0) * (ropeB * 0.9 + haze) + vec3(1.0, 0.22, 0.25) * (ropeR * 0.8 + haze * 0.6);
        // Fainter wisps all around.
        col += vec3(0.6, 0.4, 0.8) * pow(1.0 - abs(2.0 * fine - 1.0), 10.0) * 0.15 * (0.3 + band);
        dust = 0.0;
    } else {
        // Rho Ophiuchi: a dense starfield cut by dark dust lanes, around a golden glow (a bright
        // orange giant lighting its dust), a blue reflection nebula and a red emission patch.
        vec2 goldP = cl;
        vec2 blueP = cl + (hash22(vec2(slot, seed + 841.0)) - 0.5) * vec2(1.2, 0.6);
        vec2 redP = cl + (hash22(vec2(slot, seed + 843.0)) - 0.5) * vec2(1.0, 0.8);
        float gG = exp(-length(p - goldP) / 0.4);
        float gB = exp(-length(p - blueP) / 0.32);
        float gR = exp(-length(p - redP) / 0.32);
        float cloud = 0.35 + 1.3 * gas * gas;
        col = vec3(1.0, 0.72, 0.18) * gG * cloud * 1.8 + vec3(0.2, 0.42, 1.0) * gB * cloud * 1.8
            + vec3(1.0, 0.15, 0.32) * gR * cloud * 1.5;
        col += forgeStar(uv, goldP, 1.0, vec3(1.0, 0.7, 0.4), false);
        col += forgeStar(uv, blueP, 0.8, vec3(0.75, 0.85, 1.0), false);
        // The Milky Way's crowd of stars behind it all.
        col += starLayer(p, 170.0, 0.4, 0.4, seed + 31.0, t, 1.0);
        dust = clamp(lanes * 0.9 + patches * 0.3, 0.0, 0.95);
        rimC = vec3(1.0, 0.8, 0.6);
    }

    if (style != 0 && style != 4 && style != 6) {
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
