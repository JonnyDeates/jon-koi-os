// Bipolar nebula, like the Butterfly or Hourglass nebulae: a dying star has thrown its gas out in
// two opposite lobes that flare from a tightly pinched waist. Each lobe is a hollow, flaring tube of
// gas, so its walls glow brighter than its middle; it's brightest near the centre and frays open
// at the tip. Colour shifts from white-blue at the waist to red at the tips. A compact dark dust
// ring hugs the waist, the hot central star peeks through, and faint knots shoot out past the
// tips. Premultiplied emission; .a is how much the dust blocks the sky.
vec4 bipolarNebula(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 center = (hash22(vec2(slot * 9.7, seed + 191.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.2, 0.15);
    float tilt = hash12(vec2(slot, seed + 193.0)) * 6.2831;
    float L = mix(0.3, 0.45, hash12(vec2(slot, seed + 195.0))) * (1.0 + t * 0.0002); // lobe length
    float W = L * mix(0.3, 0.5, hash12(vec2(slot, seed + 197.0)));                   // max half-width
    float uneven = mix(0.85, 1.0, hash12(vec2(slot, seed + 199.0)));
    bool hourglass = hash12(vec2(slot, seed + 201.0)) < 0.4;
    vec3 waistCol = vec3(0.85, 0.92, 1.0);
    vec3 midCol = hourglass ? vec3(0.3, 0.8, 0.85) : vec3(0.95, 0.75, 0.5);
    vec3 tipCol = hourglass ? vec3(0.95, 0.35, 0.6) : vec3(0.95, 0.3, 0.12);

    vec2 p = rotate(-tilt) * (uv - center); // x runs along the lobes
    float len = L * (p.x < 0.0 ? uneven : 1.0); // one lobe slightly shorter
    float u = abs(p.x) / len;                    // 0 at the waist, 1 at the tip
    vec2 pr = p / L;
    float mottle = fbm(pr * 6.0 + seed * 2.0);

    // Lobe half-width along its length: pinched at the waist, swelling, then rounding off.
    float uc = clamp(u, 0.0, 1.0);
    float h = W * (0.2 + 0.8 * pow(uc, 0.6)) * sqrt(max(1.0 - pow(uc, 3.0), 0.0)) + 1e-4;
    // Ragged, clumpy outline: the wall wanders in and out at several scales.
    float edgeN = fbm(vec2(u * 5.0, sign(p.y) * 3.0 + seed)) - 0.5;
    float edgeF = fbm(pr * 14.0 + seed * 1.7) - 0.5;
    float q = abs(p.y) / h + edgeN * 0.45 + edgeF * 0.18;
    // Hollow, translucent tube: a sight line through the walls crosses much more gas than one
    // through the middle, so the walls glow and the inside is faint.
    // Thickness of a soft-edged shell along the sight line: peaks just inside the wall, with a
    // faint haze of gas beyond it rather than a hard cut.
    float qs = q / 1.08;
    float shell = sqrt(max(1.0 - qs * qs, 0.0)) - sqrt(max(0.72 * 0.72 - qs * qs, 0.0)) * 0.95;
    shell = shell * smoothstep(1.08, 0.88, q) + exp(-max(q - 0.95, 0.0) * 9.0) * 0.12 * smoothstep(0.6, 1.0, q);

    // Brightest near the waist, fading and fraying open into wisps toward the tip.
    float fray = (fbm(vec2(p.y / L * 7.0, seed)) - 0.5) * 0.6;
    float lengthFade = mix(1.0, 0.4, uc) * smoothstep(1.05, 0.6, u + fray);
    // Clumpy gas: knots and voids at a couple of scales.
    float clumps = fbm(pr * 9.0 - seed) * 0.6 + fbm(pr * 25.0 + seed * 3.0) * 0.4;
    // Soft filaments flowing outward along the walls (no sharp ridges).
    vec2 fw = vec2(u * 2.5, p.y / h * 1.5) + vec2(fbm(pr * 2.0 + seed), fbm(pr * 2.0 - seed)) * 1.2;
    float fil = pow(1.0 - abs(2.0 * fbm(fw * vec2(1.0, 4.0)) - 1.0), 3.0);
    float streaks = fbm(vec2(p.y / h * 3.0, u * 2.0 - t * 0.01) + seed);
    float b = shell * lengthFade * (0.25 + 0.6 * clumps * clumps + 0.35 * fil * streaks);
    // Faint glow filling each lobe, and wisps escaping past the frayed tip.
    b += smoothstep(1.1, 0.2, q) * lengthFade * 0.07 * clumps;
    float wisps = smoothstep(0.55, 0.8, fbm(vec2(p.y / L * 9.0, u * 2.0) + seed * 2.0)) * smoothstep(0.75, 1.0, u) * smoothstep(1.4, 1.0, u) * smoothstep(1.4, 0.6, q);
    b += wisps * 0.12;
    // Dark dust threads crossing the lobes.
    float threads = smoothstep(0.62, 0.75, fbm(pr * vec2(5.0, 11.0) + seed * 4.0));
    b *= 1.0 - threads * 0.55;

    vec3 c = mix(waistCol, midCol, smoothstep(0.05, 0.45, uc));
    c = mix(c, tipCol, smoothstep(0.4, 0.95, uc));
    vec3 col = c * b * 2.2;
    // Bright gas filling the waist around the star, so the two lobes join smoothly.
    float wr = length(p / vec2(W * 0.35, W * 0.25));
    col += mix(waistCol, midCol, 0.3) * exp(-wr * wr) * 0.35 * (0.7 + 0.6 * mottle);

    // Faint knots of gas shot out beyond each tip, along the axis.
    for (int k = 0; k < 2; k++) {
        float sgn = k == 0 ? 1.0 : -1.0;
        float lk = L * (sgn < 0.0 ? uneven : 1.0);
        for (int j = 0; j < 2; j++) {
            float hj = hash12(vec2(slot * 11.0 + float(j) + float(k) * 5.0, seed + 203.0));
            vec2 kp = vec2(sgn * lk * (1.12 + float(j) * 0.14 + hj * 0.05), (hj - 0.5) * W * 0.25);
            vec2 kd = (p - kp) / (L * vec2(0.035, 0.018));
            col += tipCol * exp(-dot(kd, kd)) * (0.35 - float(j) * 0.12) * (0.6 + 0.4 * mottle);
        }
    }

    // Compact dark dust ring hugging the waist, with ragged edges.
    // A narrow band across the waist, no wider than the waist itself.
    vec2 dq = vec2(p.x / (W * 0.07), p.y / (W * 0.24));
    float dustR = length(dq) + (fbm(dq * 2.0 + seed * 3.0) - 0.5) * 0.45;
    float dust = smoothstep(1.3, 0.2, dustR) * (0.5 + 0.25 * mottle);
    vec3 dustLit = vec3(0.16, 0.09, 0.05) * (0.3 + 0.7 * mottle) * dust;

    // The hot central star, glowing through the dust.
    float dPx = length(uv - center) * minDim();
    float ps = pxScale();
    vec3 starLight = vec3(0.9, 0.95, 1.0) * (exp(-dPx * dPx / (6.0 * ps * ps)) * 2.0 + exp(-dPx / (40.0 * ps)) * 0.5);
    col = col * (1.0 - dust * 0.75) + dustLit + starLight * (1.0 - dust * 0.4);

    return vec4(col, dust * 0.9) * fade;
}
