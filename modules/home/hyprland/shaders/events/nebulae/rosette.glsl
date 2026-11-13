// Rosette: a great ring of red-pink gas around a cavity its central cluster has blown clear, teal
// inside, dotted with dark globules.
// Draws the gas and dust; forge.glsl adds the stars. Uses the shared field from field.glsl.
NebulaLook nebulaRosette(NebulaField f) {
    vec2 p = f.p;
    float seed = f.seed;
    float slot = f.slot;
    float t = f.t;
    float dc = f.dc;
    vec2 w2 = f.w2;
    float gas = f.gas;
    float gas2 = f.gas2;
    float g = f.g;
    float lanes = f.lanes;
    vec3 col = vec3(0.0);
    float dust = 0.0;
    vec3 rimC = vec3(1.0, 0.8, 0.55);
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
    return NebulaLook(col, dust, rimC);
}
