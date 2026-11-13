// Shared by the eight full-screen nebula scenes (cliffs ... rho): the bright young stars, and the
// gas and dust fields every one of them is shaped from. Each scene's own file turns the field into
// colour and dust (a NebulaLook); forge.glsl picks the scene and adds the stars.

// A bright young star with diffraction spikes: JWST's 6 long + 2 short, or Hubble's 4.
vec3 forgeStar(vec2 uv, vec2 p, float b, vec3 c, bool jwst) {
    float ps = pxScale();
    vec2 dv = (uv - p) * minDim();
    float d2 = dot(dv, dv);
    vec3 col = c * (exp(-d2 / (5.0 * ps * ps * (0.5 + b))) * 2.5 * b + exp(-sqrt(d2) / (14.0 * ps * (0.4 + b))) * 0.35 * b);
    float len = 70.0 * ps * b;
    float spikes = 0.0;
    if (jwst) {
        for (int k = 0; k < 3; k++) {
            vec2 a = abs(rotate(float(k) * 1.0472) * dv);
            spikes += exp(-a.x / (1.1 * ps)) * exp(-a.y / len);
        }
        vec2 a = abs(dv);
        spikes += 0.5 * exp(-a.y / (1.0 * ps)) * exp(-a.x / (len * 0.45));
    } else {
        vec2 a = abs(rotate(0.785) * dv);
        spikes = exp(-a.x / (1.1 * ps)) * exp(-a.y / len) + exp(-a.y / (1.1 * ps)) * exp(-a.x / len);
    }
    return col + c * spikes * 0.6 * b;
}

// Everything about the nebula at one pixel that the scenes share.
struct NebulaField {
    vec2 uv;
    vec2 p;
    vec2 ext;
    vec2 cl;
    float seed;
    float slot;
    float t;
    float lt;
    float dc;
    float nearC;
    float s1;
    vec2 w1;
    vec2 w2;
    float gas;
    float fine;
    float gas2;
    float g;
    float lanes;
    float patches;
};

// What a scene draws: glowing gas, how much dust hides the sky, and the colour dust edges are lit.
struct NebulaLook {
    vec3 col;
    float dust;
    vec3 rimC;
};

NebulaField nebulaField(vec2 uv, float seed, float slot, float t, int style) {
    NebulaField f;
    float lt = eventTime(t);
    vec2 ext = halfExtent();

    // A very slow push-in and drift.
    float dr = eventDrift(lt);
    vec2 p = uv / (1.0 + 0.0008 * dr) + vec2(dr * 0.00015, 0.0);
    float s1 = seed * 1.3 + 3.0;

    // The young cluster lighting it all.
    vec2 cl = (hash22(vec2(slot, seed + 803.0)) - 0.5) * 2.0 * ext * vec2(0.55, 0.4);
    if (style == 0) {
        cl.y = ext.y * 0.75;   // above the cliffs, partly off the top
    }
    vec2 toC = cl - p;
    float dc = length(toC);
    float nearC = exp(-dc / 0.45);

    // Gas: a twice-warped noise field, so it billows and streams rather than blotches.
    vec2 w1 = vec2(fbm(p * 1.6 + s1), fbm(p * 1.6 + s1 + 5.2)) - 0.5;
    vec2 w2 = vec2(fbm(p * 2.3 + w1 * 2.2 + 9.1 + s1), fbm(p * 2.3 + w1 * 2.2 + 2.7 - s1)) - 0.5;
    float gas = fbm(p * 2.0 + w2 * 2.4 + seed);
    float fine = fbm(p * 7.0 + w2 * 4.0 - seed);
    // A second gas field for the other element's glow.
    float gas2 = fbm(p * 1.4 - w1 * 2.0 + w2 + seed * 2.0);

    // Bright filaments threading the gas.
    float fil = pow(1.0 - abs(2.0 * fine - 1.0), 4.0) * smoothstep(0.3, 0.7, gas);
    // Gas brightness with real contrast: bright billows, fainter gaps, never flat.
    float g = 0.06 + 1.5 * pow(gas, 2.4) + 0.5 * fil;

    // Dust: soft wispy lanes (broad ridges of warped noise, broken up by finer noise) and patches.
    float laneN = fbm(p * 1.2 + w2 * 1.6 + seed * 3.0);
    float lanes = smoothstep(0.5, 0.95, 1.0 - abs(2.0 * laneN - 1.0)) * (0.55 + 0.6 * fine);
    float patches = smoothstep(0.55, 0.8, fbm(p * 2.6 - w1 * 2.0 - seed * 4.0));

    f.uv = uv; f.p = p; f.ext = ext; f.cl = cl; f.seed = seed; f.slot = slot; f.t = t; f.lt = lt;
    f.dc = dc; f.nearC = nearC; f.s1 = s1; f.w1 = w1; f.w2 = w2; f.gas = gas; f.fine = fine;
    f.gas2 = gas2; f.g = g; f.lanes = lanes; f.patches = patches;
    return f;
}
