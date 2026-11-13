// Orion: a blazing cluster at the heart of a pink-red cloud, teal gas around the core, blue
// reflection haze, dark lanes of dust.
// Draws the gas and dust; forge.glsl adds the stars. Uses the shared field from field.glsl.
NebulaLook nebulaOrion(NebulaField f) {
    vec2 p = f.p;
    vec2 cl = f.cl;
    float seed = f.seed;
    float slot = f.slot;
    float dc = f.dc;
    float nearC = f.nearC;
    float gas = f.gas;
    float gas2 = f.gas2;
    float g = f.g;
    float lanes = f.lanes;
    float patches = f.patches;
    vec3 col = vec3(0.0);
    float dust = 0.0;
    vec3 rimC = vec3(1.0, 0.8, 0.55);
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
    return NebulaLook(col, dust, rimC);
}
