// Veil: braided ropes of shocked gas, teal-blue and red side by side, sweeping in great arcs
// across dark sky.
// Draws the gas and dust; forge.glsl adds the stars. Uses the shared field from field.glsl.
NebulaLook nebulaVeil(NebulaField f) {
    vec2 p = f.p;
    vec2 cl = f.cl;
    float seed = f.seed;
    float slot = f.slot;
    vec2 w1 = f.w1;
    vec2 w2 = f.w2;
    float gas = f.gas;
    float fine = f.fine;
    float g = f.g;
    vec3 col = vec3(0.0);
    float dust = 0.0;
    vec3 rimC = vec3(1.0, 0.8, 0.55);
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
    return NebulaLook(col, dust, rimC);
}
