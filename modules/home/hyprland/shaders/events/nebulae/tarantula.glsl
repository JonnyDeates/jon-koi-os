// Tarantula: a chaotic web of pink, teal and gold filaments blown into bubbles around a blazing
// central cluster.
// Draws the gas and dust; forge.glsl adds the stars. Uses the shared field from field.glsl.
NebulaLook nebulaTarantula(NebulaField f) {
    vec2 p = f.p;
    vec2 cl = f.cl;
    float seed = f.seed;
    float dc = f.dc;
    float nearC = f.nearC;
    vec2 w2 = f.w2;
    float gas = f.gas;
    float gas2 = f.gas2;
    float g = f.g;
    float lanes = f.lanes;
    float patches = f.patches;
    vec3 col = vec3(0.0);
    float dust = 0.0;
    vec3 rimC = vec3(1.0, 0.8, 0.55);
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
    return NebulaLook(col, dust, rimC);
}
