// Quasar / active galaxy, like M87: a soft, warm elliptical galaxy with a blazing point-like core
// where its supermassive black hole is feeding. A long, narrow blue-white jet shoots from the core
// across much of the screen, slowly wavering, with bright knots travelling outward along it; a much
// fainter counter-jet points the other way (dimmed because it's moving away from us). Each jet ends
// in a big, faint, billowing radio lobe with a bright hot spot. Emission only.
vec4 quasar(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 ext = halfExtent();
    float ang = hash12(vec2(slot, seed + 371.0)) * 6.2831;
    vec2 jdir = vec2(cos(ang), sin(ang));
    vec2 jperp = vec2(-jdir.y, jdir.x);
    // Put the core toward the back so the main jet has room to cross the screen.
    vec2 core = -jdir * ext * mix(0.35, 0.5, hash12(vec2(slot, seed + 373.0)))
              + jperp * (hash12(vec2(slot, seed + 375.0)) - 0.5) * 0.25;
    float L = mix(0.55, 0.75, hash12(vec2(slot, seed + 377.0))) * length(ext);   // main jet length
    float Lc = L * mix(0.35, 0.55, hash12(vec2(slot, seed + 379.0)));            // counter-jet length
    const vec3 JET = vec3(0.6, 0.78, 1.0);
    const vec3 LOBE = vec3(0.75, 0.55, 1.0);
    const vec3 HOST = vec3(1.0, 0.86, 0.66);

    vec2 d = uv - core;
    float along = dot(d, jdir);
    float across = dot(d, jperp);
    float r = length(d);
    vec3 col = vec3(0.0);

    // Host galaxy: smooth warm glow and a blazing core.
    vec2 hq = rotate(-ang) * d;
    float hr = length(hq * vec2(1.0, 1.3)) / 0.22;
    col += HOST * exp(-3.67 * (sqrt(max(hr, 1e-4)) - 1.0)) * 0.22 / (1.0 + exp(-3.67 * (sqrt(max(hr, 1e-4)) - 1.0)) * 0.1);
    float ps = pxScale() / minDim();
    col += vec3(1.0, 0.97, 0.92) * (exp(-r * r / (9.0 * ps * ps)) * 2.5 + exp(-r / 0.015) * 0.6 + exp(-r / 0.06) * 0.15);

    // Jets (main forward, counter-jet backward), only computed near their path.
    for (int k = 0; k < 2; k++) {
        float sg = k == 0 ? 1.0 : -1.0;
        float len = k == 0 ? L : Lc;
        float bright = k == 0 ? 1.0 : 0.18;
        float x = along * sg;
        if (x < -0.05 || x > len + 0.25 || abs(across) > 0.3) {
            continue;
        }
        float xs = clamp(x / len, 0.0, 1.0);
        // Slow, gentle wavering along the jet, growing further out.
        float wav = sin(x * 9.0 - t * 0.15 + seed) * 0.006 * xs + (noise(vec2(x * 4.0, t * 0.05 + seed)) - 0.5) * 0.01 * xs;
        float y = across - wav;
        float w = 0.003 + xs * 0.014;
        float jet = exp(-y * y / (w * w)) * smoothstep(0.0, 0.02, x) * smoothstep(1.02, 0.9, xs);
        float streak = 0.7 + 0.3 * noise(vec2(x * 60.0 - t * 2.0, y / w * 2.0));
        // Irregular brighter knots drifting outward along the jet.
        float knots = smoothstep(0.55, 0.85, fbm(vec2(x / len * 7.0 - t * 0.015, seed + float(k) * 3.0)))
                * smoothstep(0.03, 0.15, xs);
        col += JET * jet * (0.5 + 1.0 * knots) * streak * (1.0 - 0.45 * xs) * bright * 1.3;
        // Soft glow around the jet.
        col += JET * exp(-y * y / (w * w * 30.0)) * smoothstep(0.0, 0.05, x) * smoothstep(1.0, 0.8, xs) * 0.14 * bright;

        // Radio lobe at the end: a billowing glow with a bright hot spot at the tip.
        vec2 lc = core + jdir * sg * len;
        vec2 lq = vec2(dot(uv - lc, jdir) * sg, dot(uv - lc, jperp));
        float lr = length((lq - vec2(0.03, 0.0)) / vec2(0.12, 0.17) * (1.0 / mix(0.8, 1.2, hash12(vec2(slot + float(k), seed + 381.0)))));
        float billow = fbm(lq * 9.0 + seed + float(k) * 5.0);
        float lobe = smoothstep(1.2, 0.2, lr + (billow - 0.5) * 0.6) * (0.4 + 0.8 * billow);
        col += LOBE * lobe * 0.4 * (k == 0 ? 1.0 : 0.6);
        float hs = length(uv - lc);
        col += mix(JET, vec3(1.0), 0.5) * (exp(-hs * hs / 0.00006) * 1.2 + exp(-hs / 0.02) * 0.25) * (k == 0 ? 1.0 : 0.4);
    }
    return vec4(col * fade, 0.0);
}
