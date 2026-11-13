// Lagoon/Trifid: vivid magenta gas split by snaking dark dust lanes, with a blue reflection lobe
// and a hot pink core.
// Draws the gas and dust; forge.glsl adds the stars. Uses the shared field from field.glsl.
NebulaLook nebulaLagoon(NebulaField f) {
    vec2 p = f.p;
    vec2 cl = f.cl;
    float seed = f.seed;
    float slot = f.slot;
    float dc = f.dc;
    float nearC = f.nearC;
    float gas2 = f.gas2;
    float g = f.g;
    float lanes = f.lanes;
    float patches = f.patches;
    vec3 col = vec3(0.0);
    float dust = 0.0;
    vec3 rimC = vec3(1.0, 0.8, 0.55);
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
    return NebulaLook(col, dust, rimC);
}
