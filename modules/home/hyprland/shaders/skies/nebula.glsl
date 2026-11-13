// Nebula colour sets, chosen by pick in [0, 1): the theme colours (most common), emerald and gold,
// Hubble-style crimson and orange, or violet and cyan.
void nebulaPalette(float pick, out vec3 a, out vec3 b, out vec3 c, out vec3 d) {
    if (pick < 0.4) {
        a = ROSE; b = KOI_BLUE; c = TEAL; d = VIOLET;
    } else if (pick < 0.6) {
        a = vec3(0.95, 0.75, 0.3); b = vec3(0.2, 0.8, 0.55); c = vec3(0.3, 0.6, 0.9); d = vec3(0.15, 0.5, 0.45);
    } else if (pick < 0.8) {
        a = vec3(0.95, 0.3, 0.25); b = vec3(1.0, 0.6, 0.25); c = vec3(0.35, 0.5, 0.9); d = vec3(0.6, 0.2, 0.5);
    } else {
        a = vec3(0.9, 0.4, 0.9); b = vec3(0.3, 0.85, 1.0); c = vec3(0.25, 0.35, 0.95); d = vec3(0.6, 0.35, 1.0);
    }
}

// Returns the nebula colour; dens is its density, used to dim stars behind thick clouds.
vec3 nebula(vec2 uv, vec2 seed, float palettePick, float t, out float dens) {
    vec3 colA, colB, colC, colD;
    nebulaPalette(palettePick, colA, colB, colC, colD);
    vec2 p = uv * 1.4 + seed * 7.0;
    float nt = t * 0.012;
    vec2 q = vec2(fbm(p + vec2(0.0, nt)), fbm(p + vec2(5.2, 1.3) - nt));
    vec2 r = vec2(fbm(p + 3.0 * q + vec2(1.7, 9.2) + nt * 0.6),
                  fbm(p + 3.0 * q + vec2(8.3, 2.8) - nt * 0.6));
    float n = fbm(p + 3.0 * r);

    // Large-scale mask so nebulas form distinct clouds with empty space between them.
    float mask = smoothstep(0.38, 0.72, noise(p * 0.45 + seed * 3.0 + nt * 0.3));
    dens = smoothstep(0.38, 0.95, n) * mask;

    vec3 c = mix(colA, colB, clamp(q.x * 1.7 - 0.35, 0.0, 1.0));
    c = mix(c, colC, clamp(r.y * 1.5 - 0.6, 0.0, 1.0));
    c = mix(c, colD, clamp(r.x * 1.3 - 0.7, 0.0, 1.0));
    // Push saturation so the clouds read as colour rather than grey haze.
    c = mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, 1.6);
    vec3 col = c * dens * 0.55 + c * pow(dens, 2.5) * 0.9 + vec3(1.0, 0.9, 0.95) * pow(dens, 6.0) * 0.35;

    float dust = smoothstep(0.55, 0.80, fbm(p * 2.3 + r * 1.5 - nt));
    return col * (1.0 - dust * 0.6);
}
