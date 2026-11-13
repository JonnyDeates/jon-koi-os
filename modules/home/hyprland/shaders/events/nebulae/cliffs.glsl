// Cosmic Cliffs, like JWST's Carina image: ranges of billowing dust one behind another - far
// ones pale in the glowing haze, near ones dark - each lit gold along its skyline, under a blue
// cavity full of young stars with 8-point spikes.
// Draws the gas and dust; forge.glsl adds the stars. Uses the shared field from field.glsl.
NebulaLook nebulaCliffs(NebulaField f) {
    vec2 p = f.p;
    float seed = f.seed;
    float slot = f.slot;
    float lt = f.lt;
    float s1 = f.s1;
    vec2 w1 = f.w1;
    vec2 w2 = f.w2;
    float gas = f.gas;
    float fine = f.fine;
    float gas2 = f.gas2;
    float g = f.g;
    float lanes = f.lanes;
    vec3 col = vec3(0.0);
    float dust = 0.0;
    vec3 rimC = vec3(1.0, 0.8, 0.55);
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
    return NebulaLook(col, dust, rimC);
}
