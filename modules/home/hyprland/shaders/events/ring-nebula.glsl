// Ring nebula, like the JWST and Hubble images of M57: a shell of gas thrown off by a dying star
// around a hot white dwarf. Two kinds of glowing gas set the colour: ionised oxygen fills the inside
// with a soft teal glow, while hydrogen and nitrogen make the thick, clumpy orange-red ring outside
// it; where they overlap the light turns warm and pale. The ring is woven from filaments streaming
// outward, its inner edge lined with cometary knots (bright heads facing the star, dark tails
// pointing away), and faint red arcs of older shells loop beyond it. It expands very slowly.
// Emission only.
vec4 ringNebula(vec2 uv, float seed, float slot, float t) {
    vec2 center = (hash22(vec2(slot * 7.3, seed + 171.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.3, 0.2);
    float R = mix(0.25, 0.4, hash12(vec2(slot, seed + 173.0)));
    float tilt = hash12(vec2(slot, seed + 175.0)) * 6.2831;
    float squash = mix(0.7, 0.95, hash12(vec2(slot, seed + 177.0)));

    vec2 p = rotate(-tilt) * (uv - center);
    p.y /= squash;
    vec2 dir = p / max(length(p), 1e-4);
    vec2 pr = p / R;
    // Lumpy outline that grows very slowly.
    float lump = 1.0 + (fbm(dir * 2.5 + seed) - 0.5) * 0.16 + eventDrift(eventTime(t)) * 0.0002;
    float r = length(p) / R / lump;
    float w1 = fbm(pr * 3.0 + seed);
    float rw = r + (w1 - 0.5) * 0.1;
    if (rw > 2.0) {
        return vec4(0.0);
    }

    // Filaments streaming outward: ridged noise that changes fast around the ring and slowly
    // along the radius, so it draws radial strands.
    float fil = 1.0 - abs(2.0 * fbm(dir * 14.0 + vec2(rw * 2.0, -rw * 1.3) + seed * 2.0) - 1.0);
    fil = pow(fil, 3.0);
    // Clumps: the gas is knotted at every scale.
    float clump = fbm(pr * 7.0 - seed);
    float clumpF = fbm(pr * 22.0 + seed * 3.0);
    float dens = (0.35 + 0.9 * clump * clump) * (0.7 + 0.6 * clumpF);

    // Oxygen glow: fills the cavity, strongest just inside the ring.
    float oiii = smoothstep(0.9, 0.2, rw) * 0.22 + exp(-pow((rw - 0.62) / 0.18, 2.0)) * 0.35;
    // Hydrogen/nitrogen: the main ring, sharp on the inside, fading outward.
    float ha = exp(-pow((rw - 0.84) / (rw < 0.84 ? 0.08 : 0.15), 2.0));
    vec3 teal = vec3(0.22, 0.72, 0.78);
    vec3 red = mix(vec3(1.0, 0.62, 0.36), vec3(0.95, 0.26, 0.12), smoothstep(0.76, 0.98, rw));
    vec3 col = teal * oiii * (0.7 + 0.5 * clump) * (0.9 + 0.35 * fil * smoothstep(0.45, 0.75, rw))
             + red * ha * dens * (0.75 + 0.6 * fil) * 1.1;

    // Cometary knots along the inner edge of the ring: a bright rim on the side facing the star
    // and a dark tail streaming outward.
    float ang = atan(dir.y, dir.x);
    vec2 kg = vec2(ang * 40.0 / 6.2832 * 4.0, rw * 30.0);
    vec2 kid = floor(kg);
    vec2 kh = hash22(kid + seed);
    vec2 kf = fract(kg) - (0.3 + 0.4 * kh);
    float present = step(hash12(kid + seed + 7.0), 0.35) * smoothstep(0.66, 0.74, rw) * smoothstep(0.9, 0.8, rw);
    float head = exp(-(kf.x * kf.x + kf.y * kf.y) / 0.006);
    float tail = exp(-kf.x * kf.x / 0.004) * smoothstep(-0.05, 0.05, kf.y) * exp(-max(kf.y, 0.0) / 0.25);
    col *= 1.0 - tail * present * 0.6;
    col += vec3(1.0, 0.75, 0.55) * head * present * 0.25 * smoothstep(0.0, -0.06, kf.y + 0.03);

    // Faint red arcs of older shells looping beyond the ring.
    float arcs = 1.0 - abs(2.0 * noise(vec2(rw * 6.0 + (fbm(dir * 3.0 - seed) - 0.5) * 2.5, seed)) - 1.0);
    float haloMask = smoothstep(0.95, 1.15, rw) * smoothstep(1.9, 1.3, rw);
    col += vec3(0.6, 0.1, 0.06) * (pow(arcs, 3.0) * 0.35 * smoothstep(0.3, 0.7, fbm(pr * 4.0 + seed * 5.0)) + 0.08) * haloMask * (0.5 + clump);

    // The white dwarf at the centre.
    float dPx = length(uv - center) * minDim();
    float ps = pxScale();
    col += vec3(0.85, 0.92, 1.0) * (exp(-dPx * dPx / (4.0 * ps * ps)) * 2.0 + exp(-dPx / (25.0 * ps)) * 0.3);
    return vec4(col, 0.0);
}
