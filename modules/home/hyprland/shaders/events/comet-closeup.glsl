// A big comet, as through a telescope: a glowing green coma around a bright white core, and a long,
// straight tail streaming away from the sun across the screen, shading from green to pinkish-white,
// with faint streaks moving along it and a fainter, broader dust tail curving away beside it.
// The nucleus itself is far too small to see. Emission only.
vec4 cometCloseUp(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 ext = halfExtent();
    // The tail points away from the sun; the head sits toward the opposite side of the screen so the
    // tail has room to cross it.
    float ang = hash12(vec2(slot, seed + 231.0)) * 6.2831;
    vec2 tailDir = vec2(cos(ang), sin(ang));
    vec2 head = -tailDir * ext * mix(0.45, 0.65, hash12(vec2(slot, seed + 233.0)))
              + (hash22(vec2(slot * 3.7, seed + 235.0)) - 0.5) * ext * 0.3;
    head -= tailDir * t * 0.0003; // drifts very slowly along its orbit
    float size = mix(0.8, 1.3, hash12(vec2(slot, seed + 237.0)));
    float curveSide = hash12(vec2(slot, seed + 239.0)) < 0.5 ? -1.0 : 1.0;
    // Coma tint: green most often (from carbon gas), sometimes teal.
    vec3 comaCol = hash12(vec2(slot, seed + 241.0)) < 0.7 ? vec3(0.3, 1.0, 0.62) : vec3(0.3, 0.9, 0.95);
    const vec3 TAIL = vec3(1.0, 0.72, 0.82); // pinkish-white
    const vec3 DUST = vec3(1.0, 0.88, 0.7);  // pale gold

    vec2 rel = (uv - head) / size;
    float x = dot(rel, tailDir);                        // along the tail
    float y = dot(rel, vec2(-tailDir.y, tailDir.x));    // across it
    float r = length(rel);
    float ps = pxScale() / minDim() / size;

    // Head: a white core, a bright inner coma and a wide, soft green halo.
    vec3 col = vec3(1.0, 1.0, 0.97) * exp(-r * r / (4.0 * ps * ps)) * 1.6;
    col += mix(vec3(0.85, 1.0, 0.9), comaCol, 0.5) * exp(-r / 0.012) * 1.1;
    col += comaCol * (exp(-r / 0.04) * 0.55 + exp(-r / 0.11) * 0.18);

    // Main tail: straight and narrow, widening slowly, starting as wide as the coma.
    float xp = max(x, 0.0);
    float w = 0.018 + xp * 0.055;
    float across = y / w;
    float body = exp(-across * across) * smoothstep(-0.02, 0.04, x);
    float len = exp(-xp / 0.9) * 0.75 + exp(-xp / 2.5) * 0.25;
    // Faint streaks running along the tail, drifting outward.
    float streak = 0.75 + 0.25 * fbm(vec2(across * 2.2, xp * 1.5 - t * 0.03) + seed);
    vec3 tailCol = mix(comaCol, TAIL, smoothstep(0.0, 0.25, xp));
    col += tailCol * body * len * streak * 0.55;

    // Fainter, broader dust tail, curving gently away to one side.
    float yd = y - curveSide * xp * xp * 0.12;
    float wd = 0.03 + xp * 0.14;
    float dust = exp(-(yd / wd) * (yd / wd)) * exp(-xp / 1.0) * smoothstep(-0.02, 0.06, x);
    col += DUST * dust * 0.16 * (0.8 + 0.2 * fbm(vec2(xp * 3.0, yd / wd) + seed * 2.0));

    return vec4(col * fade, 0.0);
}
