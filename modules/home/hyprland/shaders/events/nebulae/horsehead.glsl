// Horsehead: a glowing red curtain over a dark dust floor, a dark pillar with a bent-over head
// rearing out of it, a bright star in a blue reflection haze.
// Draws the gas and dust; forge.glsl adds the stars. Uses the shared field from field.glsl.
NebulaLook nebulaHorsehead(NebulaField f) {
    vec2 uv = f.uv;
    vec2 p = f.p;
    vec2 ext = f.ext;
    float seed = f.seed;
    float slot = f.slot;
    float t = f.t;
    float s1 = f.s1;
    vec2 w1 = f.w1;
    vec2 w2 = f.w2;
    float gas = f.gas;
    float fine = f.fine;
    float gas2 = f.gas2;
    vec3 col = vec3(0.0);
    float dust = 0.0;
    vec3 rimC = vec3(1.0, 0.8, 0.55);
    // Horsehead: a glowing red curtain of gas streaked vertically along its ionisation front,
    // a dark dust floor, and a dark pillar rearing out of it with a bulging, bent-over head.
    float streak = fbm(vec2(p.x * 2.0 + w1.x, p.y * 9.0 + w2.y * 2.0) + seed * 2.0);
    vec3 ha = vec3(1.0, 0.18, 0.22);
    float curtain = (0.2 + 1.3 * pow(gas, 1.8)) * (0.55 + 0.6 * streak) * (0.6 + 0.5 * smoothstep(-0.4, 0.4, p.y));
    col = ha * curtain;
    col = mix(col, vec3(1.0, 0.45, 0.3) * curtain, smoothstep(0.5, 0.8, gas2) * 0.4);
    // The floor of dark dust.
    float floorY = mix(-0.32, -0.18, hash12(vec2(slot, seed + 825.0))) + (fbm(vec2(p.x * 1.3, s1)) - 0.5) * 0.12 + w2.x * 0.04;
    float fl = smoothstep(0.025, -0.05, p.y - floorY + (fine - 0.5) * 0.06 + (fbm(p * 12.0 + seed) - 0.5) * 0.03);
    // The pillar: a column of dust rising from the floor, swelling into a head that leans to
    // one side, every edge eaten away by the radiation into ragged billows.
    float hx = (hash12(vec2(slot, seed + 827.0)) - 0.5) * ext.x * 0.9;
    float hside = hash12(vec2(slot, seed + 829.0)) < 0.5 ? -1.0 : 1.0;
    float H = mix(0.3, 0.42, hash12(vec2(slot, seed + 831.0)));
    vec2 q = p - vec2(hx, floorY);
    q += (vec2(fbm(q * 4.0 + seed), fbm(q * 4.0 - seed)) - 0.5) * 0.06;
    float up = clamp(q.y / H, 0.0, 1.2);
    float lean = hside * 0.07 * smoothstep(0.55, 1.0, up);
    float w = mix(0.075, 0.045, up) + 0.055 * exp(-pow((up - 0.88) / 0.12, 2.0));
    float erode = (fbm(q * 9.0 + seed * 3.0) - 0.5) * 0.06 + (fbm(q * 25.0 - seed) - 0.5) * 0.025;
    // A soft edge: thin dust at the fringe lets the glow through.
    float horse = smoothstep(0.012, -0.022, abs(q.x - lean) - w + erode) * smoothstep(1.04, 0.86, up + erode * 3.0);
    float body = max(fl, horse);
    // Glowing rim where the curtain's light wraps the dark shapes.
    float rimH = smoothstep(0.0, 0.5, body) * smoothstep(1.0, 0.5, body);
    // The dust is faintly lit from the curtain behind and above, so it isn't flat black.
    col = col * (1.0 - body * 0.93) + vec3(0.18, 0.05, 0.05) * body * (0.3 + 0.7 * fine) * smoothstep(-0.5, 0.0, p.y)
        + vec3(1.0, 0.45, 0.35) * rimH * 0.6 * curtain;
    dust = body * 0.95;
    // A bright star in a blue reflection haze, low in a corner.
    vec2 rsp = vec2(-hside * ext.x * 0.6, floorY + 0.08);
    float rh = exp(-length(p - rsp) / 0.18);
    col = mix(col, vec3(0.35, 0.55, 1.0) * (0.3 + 0.9 * gas2), rh * 0.75);
    col += forgeStar(uv, rsp, 0.9, vec3(0.85, 0.9, 1.0), false);
    rimC = vec3(1.0, 0.5, 0.4);
    return NebulaLook(col, dust, rimC);
}
