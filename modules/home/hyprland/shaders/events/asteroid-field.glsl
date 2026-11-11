// A field of tumbling asteroids drifting past at four depths (near ones bigger and faster, far ones
// fading into dusty haze), lit from one side, with fine dust streaming past. Premultiplied
// colour/coverage.
vec4 asteroidField(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 flow = normalize(hash22(vec2(slot, seed + 121.0)) - 0.5);
    vec3 L = normalize(vec3(normalize(hash22(vec2(slot, seed + 123.0)) - 0.5), 0.25));
    // Rock colours vary per field: brown (most common), grey, or reddish.
    float tone = hash12(vec2(slot, seed + 125.0));
    vec3 rockA = tone < 0.5 ? vec3(0.32, 0.29, 0.27) : tone < 0.75 ? vec3(0.33, 0.33, 0.35) : vec3(0.4, 0.26, 0.2);
    vec3 rockB = tone < 0.5 ? vec3(0.42, 0.34, 0.27) : tone < 0.75 ? vec3(0.45, 0.44, 0.46) : vec3(0.5, 0.32, 0.24);
    vec4 ov = vec4(0.0);
    for (int i = 0; i < 4; i++) {
        float depth = float(i) / 3.0; // 0 = far, 1 = near
        float cell = mix(0.045, 0.3, depth * depth);
        vec2 g = (uv + flow * mix(0.002, 0.02, depth) * t + float(i) * 13.7) / cell;
        vec2 id = floor(g);
        float h = hash12(id + seed + float(i) * 31.0);
        if (h > mix(0.32, 0.22, depth)) {
            continue;
        }
        vec2 h2 = hash22(id + seed + float(i) * 17.0);
        // Mostly small rocks with the odd big one, placed anywhere they fit in their cell.
        float rad = mix(0.1, 0.28, pow(h2.x, 1.5));
        float maxJitter = 0.5 - rad * 1.35;
        vec2 pos = 0.5 + (hash22(id + seed + float(i) * 23.0) - 0.5) * 2.0 * maxJitter;
        vec2 q = (fract(g) - pos) / rad;
        // Elongated, lumpy rock that tumbles as it spins.
        float spinA = t * mix(-0.15, 0.15, h2.y);
        float stretch = mix(1.0, 1.7, hash12(id + seed + 5.0));
        vec2 rq = rotate(spinA) * q;
        vec2 sq = vec2(rq.x / stretch, rq.y);
        float r = length(sq);
        if (r > 1.5) {
            continue;
        }
        vec2 dir = sq / max(r, 1e-4);
        float edgeR = 1.0 + 0.45 * (noise(dir * 1.5 + h * 20.0) - 0.5) + 0.12 * (noise(dir * 5.0 + h * 9.0) - 0.5);
        float px = 1.5 / (rad * cell * minDim());
        float cover = smoothstep(edgeR + px, edgeR - px, r);
        if (cover <= 0.0) {
            continue;
        }
        // Bumpy, cratered surface: tilt the normal by the slope of a noise field.
        float bump = fbm(rq * 2.5 + h * 7.0);
        vec2 grad = vec2(fbm(rq * 2.5 + vec2(0.05, 0.0) + h * 7.0) - bump,
                         fbm(rq * 2.5 + vec2(0.0, 0.05) + h * 7.0) - bump) / 0.05;
        float nz = sqrt(max(1.0 - (r / edgeR) * (r / edgeR), 0.0));
        vec3 n = normalize(vec3(rotate(-spinA) * (sq / edgeR), nz) + vec3(rotate(-spinA) * grad, 0.0) * 0.2);
        float diff = clamp(dot(n, L), 0.0, 1.0);
        vec3 rockCol = mix(rockA, rockB, h2.y) * (0.55 + 0.7 * bump);
        vec3 col = rockCol * (0.008 + 1.2 * diff);
        col = mix(vec3(0.02, 0.025, 0.04), col, mix(0.25, 1.0, depth)); // distant rocks fade into haze
        ov = over(vec4(col * cover, cover), ov);
    }
    // Fine dust close to the camera, streaming past quickly.
    ov.rgb += starLayer(uv + flow * 0.04 * t, 90.0, 0.12, 0.5, seed + 9.0, t, 1.0) * vec3(0.9, 0.85, 0.8);
    return ov * fade;
}
