// Galactic cirrus: faint wisps of dust drifting across the sky, lit grey-blue by the galaxy's
// light, browner where thicker. dens is how much they hide the stars.
vec3 cirrus(vec2 uv, vec2 seed, float t, out float dens) {
    vec2 p = uv * 1.1 + seed * 5.0 + vec2(t * 0.0015, 0.0);
    vec2 q = vec2(fbm(p), fbm(p + vec2(4.1, 1.7))) - 0.5;
    float ang = hash12(seed + 23.0) * 3.1416;
    float streak = fbm(rotate(ang) * p * vec2(1.0, 4.5) + q * 2.5);
    float n = fbm(p * 2.0 + q * 2.0);
    float wisps = smoothstep(0.35, 0.8, n * 0.55 + streak * 0.6) * smoothstep(0.2, 0.55, noise(p * 0.5 + seed));
    dens = wisps * 0.7;
    vec3 c = mix(vec3(0.38, 0.44, 0.55), vec3(0.5, 0.38, 0.28), smoothstep(0.5, 0.8, n));
    return c * wisps * 0.45;
}
