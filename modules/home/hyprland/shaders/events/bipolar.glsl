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
    float h = W * (0.08 + 0.92 * pow(uc, 0.55)) * sqrt(max(1.0 - pow(uc, 3.0), 0.0)) + 1e-4;
    float q = abs(p.y) / h + (fbm(vec2(u * 4.0, p.y / L * 6.0) + seed) - 0.5) * 0.22;
    // Hollow tube: a sight line through the walls crosses more gas than one through the middle.
    float shell = sqrt(max(1.0 - q * q, 0.0)) - sqrt(max(0.7 * 0.7 - q * q, 0.0));
    shell += exp(-max(q - 1.0, 0.0) * 10.0) * step(0.98, q) * 0.15; // soft haze just outside

    // Brightest near the waist, fading and fraying open toward the tip.
    float fray = (fbm(vec2(p.y / L * 5.0, seed)) - 0.5) * 0.35;
    float lengthFade = mix(1.0, 0.35, uc) * smoothstep(1.02, 0.7, u + fray);
    // Filaments streaming outward along the lobes.
    float streaks = fbm(vec2(p.y / h * 2.5, u * 3.0 - t * 0.01) + seed);
    // Thin bright filaments in the walls: ridges of warped noise stretched along the lobe.
    vec2 fw = vec2(u * 3.0, p.y / h * 1.2) + vec2(fbm(pr * 2.0 + seed), fbm(pr * 2.0 - seed)) * 0.8;
    float fil = pow(1.0 - abs(2.0 * fbm(fw * vec2(1.0, 3.0)) - 1.0), 6.0);
    float b = shell * lengthFade * (0.35 + 0.9 * streaks * mottle + 0.35 * mottle + 1.2 * fil);
    // The inside of each lobe glows faintly too.
    b += smoothstep(1.0, 0.3, q) * lengthFade * 0.12 * mottle;

    vec3 c = mix(waistCol, midCol, smoothstep(0.05, 0.45, uc));
    c = mix(c, tipCol, smoothstep(0.4, 0.95, uc));
    vec3 col = c * b * 2.0;

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
    vec2 dq = vec2(p.x / (W * 0.22), p.y / (W * 0.65));
    float dustR = length(dq) + (fbm(dq * 1.5 + seed * 3.0) - 0.5) * 0.5;
    float dust = smoothstep(1.0, 0.55, dustR) * (0.8 + 0.2 * mottle);
    vec3 dustLit = vec3(0.22, 0.12, 0.07) * (0.3 + 0.7 * mottle) * dust;

    // The hot central star, glowing through the dust.
    float dPx = length(uv - center) * minDim();
    float ps = pxScale();
    vec3 starLight = vec3(0.9, 0.95, 1.0) * (exp(-dPx * dPx / (6.0 * ps * ps)) * 2.0 + exp(-dPx / (40.0 * ps)) * 0.5);
    col = col * (1.0 - dust * 0.9) + dustLit + starLight * (1.0 - dust * 0.6);

    return vec4(col, dust * 0.9) * fade;
}
