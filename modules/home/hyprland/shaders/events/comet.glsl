// A comet crossing the screen, like Hale-Bopp or NEOWISE: a small bright nucleus in a large, soft
// green-blue coma; a bright, broad, curved dust tail combed into striations; and a fainter, thin
// blue ion tail of ragged strands. Both tails point away from
// the (off-screen) sun rather than along the direction of travel. Returns additive light.
vec3 comet(vec2 uv, float seed, float slot, float lt, float t, float fade) {
    float sunAng = hash12(vec2(slot, seed + 111.0)) * 6.2831;
    vec2 tailDir = vec2(cos(sunAng), sin(sunAng));
    float side = hash12(vec2(slot, seed + 113.0)) < 0.5 ? -1.0 : 1.0;
    vec2 travel = rotate(side * mix(1.1, 1.9, hash12(vec2(slot, seed + 115.0)))) * tailDir;
    float scale = mix(0.6, 1.5, hash12(vec2(slot, seed + 117.0)));
    vec2 start = (hash22(vec2(slot * 5.7, seed + 119.0)) - 0.5) * 2.0 * halfExtent() * 0.6 - travel * 0.35;
    vec2 nucleus = start + travel * 0.7 * (lt / EVENT_PERIOD);

    // x runs down the tail (away from the sun), y across it.
    vec2 rel = uv - nucleus;
    vec2 q = vec2(dot(rel, tailDir), dot(rel, vec2(-tailDir.y, tailDir.x))) / scale;
    float r = length(q);
    float core = 1.5 * pxScale() / minDim() / scale;

    // Head: a small bright false nucleus inside a large, soft coma.
    vec3 col = vec3(1.0) * exp(-r * r / (core * core * 2.5)) * 1.2;
    // Coma colour varies: green (most common, from carbon gas), teal or white.
    float comaPick = hash12(vec2(slot, seed + 127.0));
    vec3 coma = comaPick < 0.5 ? vec3(0.6, 1.0, 0.85) : comaPick < 0.8 ? vec3(0.55, 0.85, 1.0) : vec3(0.95, 0.95, 1.0);
    col += coma * (exp(-r / 0.005) * 0.7 + exp(-r / 0.02) * 0.3 + exp(-r / 0.06) * 0.08);

    float x = max(q.x, 0.0);
    float on = smoothstep(-0.01, 0.03, q.x);
    // Dust tail: the bright one. A broad, curved, cream-white fan, combed into fine straight
    // striations that fan out from the head, fading gradually.
    float yd = q.y + side * x * x * 0.6;
    float wd = 0.006 + x * 0.17;
    float fanAng = yd / max(x, 0.01);
    float stri = 0.7 + 0.3 * noise(vec2(fanAng * 30.0, seed)) * (0.6 + 0.4 * noise(vec2(fanAng * 90.0, seed + 3.0)));
    float dustProfile = exp(-pow(yd / wd, 2.0) * 1.2) * (0.6 + 0.4 * smoothstep(-0.2, 0.6, side * yd / wd));
    col += vec3(1.0, 0.9, 0.76) * dustProfile * exp(-x / 0.5) * stri * on * 0.85;
    // Ion tail: fainter, thin and blue, pointing straight away from the sun - several ragged strands,
    // with kinks travelling down it.
    float kink = sin(q.x * 6.0 - t * 0.6) * x * 0.012 + (noise(vec2(q.x * 3.0 - t * 0.2, seed)) - 0.5) * x * 0.04;
    float yi = q.y - kink;
    float wi = 0.002 + x * 0.03;
    float strands = 0.35 + 0.65 * pow(noise(vec2(yi / wi * 3.0, q.x * 2.0 - t * 0.5)), 2.0);
    col += vec3(0.45, 0.68, 1.2) * exp(-pow(yi / wi, 2.0)) * exp(-x / 0.7) * strands * on * 0.45;
    return col * fade;
}
