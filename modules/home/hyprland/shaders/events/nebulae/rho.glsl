// Rho Ophiuchi: a dense Milky Way starfield cut by dark dust, with a golden glow, a blue
// reflection nebula and red emission.
// Draws the gas and dust; forge.glsl adds the stars. Uses the shared field from field.glsl.
NebulaLook nebulaRho(NebulaField f) {
    vec2 uv = f.uv;
    vec2 p = f.p;
    vec2 cl = f.cl;
    float seed = f.seed;
    float slot = f.slot;
    float t = f.t;
    float gas = f.gas;
    float lanes = f.lanes;
    float patches = f.patches;
    vec3 col = vec3(0.0);
    float dust = 0.0;
    vec3 rimC = vec3(1.0, 0.8, 0.55);
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
    return NebulaLook(col, dust, rimC);
}
