// A star with planets on visible orbits. Inner planets orbit faster (Kepler's third law), each is
// lit by the star, and they pass behind it on the far side of their orbits and in front of it on
// the near side. Sometimes there's an asteroid belt. Premultiplied colour/coverage; shimmer is the
// star's heat ripple. Must be called from uniform control flow (orbit lines use derivatives).
vec4 solarSystem(vec2 uv, float seed, float slot, float t, float fade, out float shimmer) {
    vec2 center = (hash22(vec2(slot * 4.3, seed + 91.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.25, 0.2);
    float sysTilt = (hash12(vec2(slot, seed + 93.0)) - 0.5) * 0.5;
    float k = mix(0.22, 0.4, hash12(vec2(slot, seed + 95.0))); // how flattened the orbits look
    float depthK = sqrt(1.0 - k * k);
    float kind = hash12(vec2(slot, seed + 97.0)) * 0.85;     // mostly suns, sometimes giants or blue
    bool giant = kind >= STAR_GIANT && kind < STAR_BLUE;
    float starR = giant ? 0.07 : kind >= STAR_BLUE ? 0.03 : 0.045;
    int count = 3 + int(hash12(vec2(slot, seed + 99.0)) * 2.99); // 3-5 planets
    const float ORBIT_SPEED = 0.08; // innermost planet's angular speed, rad/s (~80 s per orbit)

    float aMax = halfExtent().x * 0.92;
    float a0 = max(starR * 2.6, aMax / pow(1.55, float(count - 1)));
    float spacing = pow(aMax / a0, 1.0 / float(count - 1));

    vec2 p = rotate(-sysTilt) * (uv - center); // into the orbit frame
    float er = length(vec2(p.x, p.y / k));     // radius within the orbital plane
    bool far = p.y > 0.0;                      // upper half of each ellipse is behind the star

    vec3 backLines = vec3(0.0);
    vec3 frontLines = vec3(0.0);
    vec4 backPlanets = vec4(0.0);
    vec4 frontPlanets = vec4(0.0);
    const vec3 LINE_COL = vec3(0.55, 0.65, 0.85);

    for (int i = 0; i < 7; i++) {
        float a = a0 * pow(spacing, float(i));
        float f = er - a;
        float w = max(fwidth(f), 1e-5) * 1.2;
        if (i >= count) {
            continue;
        }
        vec3 line = LINE_COL * exp(-(f * f) / (w * w)) * 0.10;
        if (far) {
            backLines += line;
        } else {
            frontLines += line;
        }

        float h = hash12(vec2(slot * 7.0 + float(i), seed + 101.0));
        float theta = h * 6.2831 + ORBIT_SPEED * pow(a0 / a, 1.5) * t;
        vec2 o = a * vec2(cos(theta), sin(theta));
        vec2 pc = center + rotate(sysTilt) * vec2(o.x, o.y * k);
        float prad = mix(0.008, 0.026, pow(hash12(vec2(h, 5.0)), 1.5));
        vec3 rel = vec3(pc - center, -o.y * depthK); // view space; far side of the orbit is away from us
        vec4 pl = miniPlanet(uv, pc, prad, -rel, t, h * 97.0);
        if (o.y > 0.0) {
            backPlanets = over(pl, backPlanets);
        } else {
            frontPlanets = over(pl, frontPlanets);
        }
    }

    // Asteroid belt in a gap between two orbits: tiny specks drifting around the star.
    if (hash12(vec2(slot, seed + 103.0)) < 0.65) {
        float ab = a0 * pow(spacing, 1.5 + floor(hash12(vec2(slot, seed + 105.0)) * float(count - 3)));
        float band = exp(-pow((er - ab) / (ab * 0.08), 2.0));
        if (band > 0.01) {
            vec2 q = rotate(ORBIT_SPEED * pow(a0 / ab, 1.5) * t) * vec2(p.x, p.y / k);
            const float cell = 0.004;
            vec2 id = floor(q / cell);
            vec2 jit = hash22(id + seed);
            float dPx = length(fract(q / cell) - (0.2 + 0.6 * jit)) * cell * minDim();
            float speck = exp(-dPx * dPx / (0.8 * pxScale())) * step(hash12(id + seed + 7.0), 0.35);
            vec3 rock = vec3(0.75, 0.68, 0.6) * speck * band * 1.3;
            if (far) {
                backLines += rock;
            } else {
                frontLines += rock;
            }
        }
    }

    vec3 starGlow;
    vec4 sun = star(uv, center, starR, kind, seed, slot, t, 1.0, starGlow, shimmer);
    shimmer *= fade;

    vec4 ovl = over(backPlanets, vec4(backLines, 0.0));
    ovl = over(sun, ovl);
    ovl = over(vec4(starGlow, 0.0), ovl);
    ovl = over(vec4(frontLines, 0.0), ovl);
    ovl = over(frontPlanets, ovl);
    return ovl * fade;
}
