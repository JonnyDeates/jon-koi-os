// Crab-like supernova remnant: an irregular oval of blue-white glow (from fast particles spiralling
// in magnetic fields), wrapped in a tangled cage of thin red, orange and yellow filaments of gas
// thrown off by the explosion, with a pulsar at the centre sending faint ripples outward. Expands
// very slowly. Emission only.
vec4 crabNebula(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 center = (hash22(vec2(slot * 8.9, seed + 181.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.3, 0.2);
    float R = mix(0.24, 0.34, hash12(vec2(slot, seed + 183.0))) * (1.0 + t * 0.0002);
    float tilt = hash12(vec2(slot, seed + 185.0)) * 6.2831;
    float aspect = mix(1.3, 1.6, hash12(vec2(slot, seed + 187.0)));

    vec2 p = rotate(-tilt) * (uv - center);
    p.x /= aspect;
    vec2 pr = p / R;
    vec2 dir = p / max(length(p), 1e-4);
    // Irregular, lumpy outline.
    float lump = 1.0 + (fbm(dir * 2.0 + seed) - 0.5) * 0.35;
    float r = length(pr) / lump;
    if (r > 1.6) {
        return vec4(0.0);
    }
    float envelope = smoothstep(1.05, 0.55, r);

    // Blue-white glow filling the inside, brightest toward the centre.
    float haze = fbm(pr * 3.0 + seed * 2.0);
    vec3 col = vec3(0.5, 0.65, 1.0) * envelope * (0.25 + 0.45 * haze) + vec3(0.65, 0.78, 1.0) * exp(-r / 0.3) * 0.35;

    // Filaments: thin ridges of warped noise, tangled into a cage that's densest near the edge.
    vec2 w = pr * 2.6 + vec2(fbm(pr * 1.5 + seed), fbm(pr * 1.5 - seed)) * 1.6;
    float ridge1 = 1.0 - abs(2.0 * fbm(w) - 1.0);
    float ridge2 = 1.0 - abs(2.0 * fbm(w * 2.3 + 7.0) - 1.0);
    float fil = pow(ridge1, 7.0) + pow(ridge2, 10.0) * 0.6;
    fil *= mix(0.35, 1.0, smoothstep(0.15, 0.85, r)) * smoothstep(1.15, 0.85, r);
    // Filament colour varies from red through orange to yellow, with the odd greenish strand.
    float hueN = fbm(pr * 2.0 + 13.0 + seed);
    vec3 filCol = mix(vec3(1.0, 0.22, 0.1), vec3(1.0, 0.55, 0.18), smoothstep(0.35, 0.55, hueN));
    filCol = mix(filCol, vec3(1.0, 0.85, 0.45), smoothstep(0.55, 0.7, hueN));
    filCol = mix(filCol, vec3(0.55, 0.9, 0.45), smoothstep(0.72, 0.8, hueN) * 0.6);
    col += filCol * fil * 1.5;

    // Faint reddish glow just outside, where the filaments thin out into space.
    col += vec3(0.6, 0.15, 0.08) * smoothstep(0.85, 1.05, r) * exp(-(r - 1.05) * 4.0) * (0.3 + haze) * 0.25;

    // The pulsar at the centre, with faint ripples moving outward from it.
    vec2 dc = uv - center;
    float dPx = length(dc) * minDim();
    float ps = pxScale();
    col += vec3(0.85, 0.92, 1.0) * (exp(-dPx * dPx / (5.0 * ps * ps)) * 2.2 + exp(-dPx / (30.0 * ps)) * 0.35);
    float rc = length(dc) / R;
    float ripple = 0.5 + 0.5 * sin(rc * 60.0 - t * 0.8);
    col += vec3(0.6, 0.75, 1.0) * ripple * exp(-rc / 0.12) * smoothstep(0.02, 0.05, rc) * 0.15;

    return vec4(col * fade, 0.0);
}
