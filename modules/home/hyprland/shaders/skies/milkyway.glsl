// The Milky Way seen edge-on: a band of unresolved starlight across the sky, swelling around the
// galactic centre's warm bulge and bluish-white toward its ends. It's grainy and uneven - bright
// star clouds and fainter gaps - and threaded with a network of dark dust: long lanes along its
// middle (like the Great Rift) that branch and break into filaments, reddening the light at their
// edges. Pink star-forming knots and blue reflection patches are dotted along it. band is how deep
// in the band this point is (for the extra stars); dens is the dust.
vec3 milkyWay(vec2 uv, vec2 seed, float t, out float band, out float dens) {
    float ang = (hash12(seed + 13.0) - 0.5) * 2.4;
    vec2 d = rotate(ang) * uv + vec2(t * 0.0006, 0.0);
    vec2 wq = vec2(fbm(d * 1.3 + seed), fbm(d * 1.3 + seed + 5.1)) - 0.5;
    float bulge = exp(-pow((d.x - (hash12(seed + 19.0) - 0.5) * 1.2) / 0.45, 2.0));
    float width = 0.2 + 0.1 * bulge;
    float y = d.y - (hash12(seed + 17.0) - 0.5) * 0.35 + (fbm(vec2(d.x * 0.8, seed.x)) - 0.5) * 0.16;
    float y2 = y * y / (width * width);
    band = exp(-y2);
    float core = exp(-y2 * 4.0);
    // Star clouds: big uneven patches, and a fine grain from countless faint stars.
    float clouds = fbm(d * vec2(1.6, 3.5) + wq * 1.5 + seed * 3.0);
    float grain = noise(d * 150.0 + seed) * 0.5 + noise(d * 55.0 - seed) * 0.5;
    // The whole band glows, all the way across; the bulge is brighter on top of that.
    float lum = band * (0.3 + 1.0 * clouds * clouds) * (0.7 + 0.6 * grain) * (1.0 + 1.3 * bulge * core);
    vec3 glow = mix(vec3(0.62, 0.7, 0.95), vec3(1.0, 0.8, 0.55), clamp(core * bulge * 0.9 + core * 0.25, 0.0, 1.0)) * lum;
    // Dust: warped ridges stretched along the band at two scales (lanes that branch and break),
    // plus scattered dark clouds.
    vec2 dq = d * vec2(1.1, 5.0) + wq * 2.5 + seed * 4.0;
    float l1 = 1.0 - abs(2.0 * fbm(dq) - 1.0);
    float l2 = 1.0 - abs(2.0 * fbm(dq * 2.3 + 7.0) - 1.0);
    float lanes = smoothstep(0.62, 0.9, l1) * 0.75 + smoothstep(0.72, 0.93, l2) * 0.45;
    float darkClouds = smoothstep(0.58, 0.78, fbm(d * 3.0 - wq * 2.0 + seed * 6.0));
    dens = clamp(lanes * exp(-y2 * 2.0) + darkClouds * 0.35 * band, 0.0, 0.9);
    // Dust dims the light, and reddens what still gets through at its thin edges.
    glow = glow * (1.0 - dens) + glow * vec3(0.55, 0.3, 0.15) * dens * smoothstep(0.9, 0.3, dens) * 0.8;
    // Pink star-forming knots and small blue reflection patches.
    glow += vec3(1.0, 0.3, 0.45) * smoothstep(0.8, 0.92, fbm(d * 7.0 + seed * 5.0)) * band * 0.4;
    glow += vec3(0.35, 0.5, 1.0) * smoothstep(0.82, 0.93, fbm(d * 6.0 - seed * 7.0)) * band * 0.25;
    return glow * 0.8;
}
