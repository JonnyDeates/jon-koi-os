// A comet crossing the screen: a bright nucleus in a glowing green-blue coma, a straight blue ion
// tail with streamers rushing outward, and a broad, curved dust tail. Both tails point away from
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

    vec3 col = vec3(1.0) * exp(-r * r / (core * core)) * 1.5;
    // Coma colour varies: green (most common, from carbon gas), teal or white.
    float comaPick = hash12(vec2(slot, seed + 127.0));
    vec3 coma = comaPick < 0.5 ? vec3(0.6, 1.0, 0.85) : comaPick < 0.8 ? vec3(0.55, 0.85, 1.0) : vec3(0.95, 0.95, 1.0);
    col += coma * exp(-r / 0.006) * 0.9;
    col += coma * 0.9 * exp(-r / 0.03) * 0.25;

    float x = max(q.x, 0.0);
    float on = smoothstep(-0.01, 0.02, q.x);
    // Ion tail: straight, narrow and blue, with streamers rushing outward and a gentle ripple.
    float yi = q.y - sin(q.x * 6.0 - t * 0.6) * q.x * 0.012;
    float wi = 0.003 + x * 0.04;
    float streak = 0.55 + 0.45 * noise(vec2(yi / wi * 2.5, q.x * 6.0 - t * 0.9));
    col += vec3(0.45, 0.7, 1.25) * exp(-abs(yi) / wi) * exp(-x / 0.55) * streak * on * 0.9;
    // Dust tail: broad and pale gold, curving back behind the comet's motion, with faint striations.
    float yd = q.y + side * x * x * 0.6;
    float wd = 0.004 + x * 0.16;
    float stri = 0.8 + 0.2 * noise(vec2(q.x * 25.0, yd / wd * 1.5 + 3.0));
    col += vec3(1.0, 0.88, 0.65) * exp(-(yd / wd) * (yd / wd)) * exp(-x / 0.45) * stri * on * 0.55;
    return col * fade;
}
