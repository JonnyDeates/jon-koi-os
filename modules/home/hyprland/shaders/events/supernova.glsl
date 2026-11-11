// Supernova, played out over the event: a bloated blue supergiant swells and pulses unstably, then
// collapses inward and explodes in a blinding flash with long spikes; a shockwave shell races
// outward, bright at its rim, with turbulent finger-like plumes, cooling from blue-white through
// teal to gold and red as it grows; finally it fades into wispy filaments with a pulsar blinking
// at the centre. lt is the time within the event. Emission only; shimmer is for the early star.
vec4 supernova(vec2 uv, float seed, float slot, float lt, float t, float fade, out float shimmer) {
    shimmer = 0.0;
    vec2 center = (hash22(vec2(slot * 9.1, seed + 311.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.2, 0.15);
    const float BLAST = 30.0;                 // when the star explodes, seconds into the event
    float since = lt - BLAST;
    vec2 d = uv - center;
    float r = length(d);
    vec2 dir = d / max(r, 1e-5);
    vec3 col = vec3(0.0);

    // 1. The progenitor: a blue supergiant, swelling and pulsing faster as the end approaches,
    //    then collapsing in the last second.
    if (since < 0.0) {
        float swell = 1.0 + 0.25 * smoothstep(0.0, BLAST, lt);
        float pulse = 1.0 + 0.04 * sin(lt * mix(1.0, 6.0, smoothstep(10.0, BLAST, lt)));
        float collapse = smoothstep(-0.8, 0.0, since);
        float R = 0.07 * swell * pulse * (1.0 - 0.85 * collapse);
        vec3 g;
        vec4 s = star(uv, center, R, 0.85, seed + 41.0, slot, t, 1.0, g, shimmer);
        col = s.rgb + g * (1.0 - s.a);
        col += vec3(0.7, 0.85, 1.0) * exp(-r / 0.04) * collapse * 0.8;  // core flare as it implodes
        return vec4(col * fade, 0.0);
    }

    // 2. The flash: a blinding burst with long diffraction spikes, fading over several seconds.
    float flash = exp(-since / 2.5);
    float spikeL = 0.4 * (1.0 - exp(-since * 3.0));
    vec2 a = abs(d);
    float spikes = exp(-a.x / 0.004) * exp(-a.y / spikeL) + exp(-a.y / 0.004) * exp(-a.x / spikeL);
    vec2 ad = abs(rotate(0.785) * d);
    spikes += 0.5 * (exp(-ad.x / 0.003) * exp(-ad.y / (spikeL * 0.6)) + exp(-ad.y / 0.003) * exp(-ad.x / (spikeL * 0.6)));
    col += vec3(1.0, 0.98, 0.95) * flash * (exp(-r / 0.05) * 3.0 + exp(-r / 0.25) * 0.8 + spikes * 1.5 + 0.25);

    // 3. The shockwave shell, slowing as it sweeps up gas.
    float R = 0.42 * (1.0 - exp(-since / 35.0)) + 0.01;
    float age = smoothstep(0.0, 90.0, since);
    // Turbulent, finger-like edge (Rayleigh-Taylor plumes) and a lumpy outline.
    float lump = (fbm(dir * 2.5 + seed) - 0.5) * 0.15;
    // Built from the direction vector, not the angle, so there's no seam where the angle wraps.
    float fingers = (fbm(dir * 5.0 + seed * 3.0) - 0.5) * 0.25 * age;
    float s = r / R - lump - fingers;
    // A hollow shell: brightest at the rim, as with real supernova remnants.
    float shell = sqrt(max(1.0 - s * s, 0.0)) - sqrt(max(0.9 * 0.9 - s * s, 0.0));
    // Glow across the outer edge, continuous on both sides (a one-sided glow left a dark line at s = 1).
    shell += exp(-abs(s - 1.0) * 20.0) * 0.3;
    float fil = fbm(d / R * 3.0 + seed) * 0.6 + pow(1.0 - abs(2.0 * fbm(d / R * 5.0 - seed) - 1.0), 6.0) * 0.8;
    // Colour cools with age: blue-white, teal, then gold and red at the rim.
    vec3 hot = vec3(0.75, 0.88, 1.0);
    vec3 midC = vec3(0.3, 0.85, 0.8);
    vec3 cool = mix(vec3(1.0, 0.7, 0.3), vec3(0.95, 0.25, 0.15), smoothstep(0.85, 1.05, s));
    vec3 sc = mix(hot, midC, smoothstep(0.05, 0.35, age));
    sc = mix(sc, cool, smoothstep(0.3, 0.8, age) * smoothstep(0.5, 0.95, s));
    float bright = mix(1.6, 0.55, age);
    // 4. The remnant: the shell thins into wisps as it fades.
    float wisp = mix(1.0, smoothstep(0.35, 0.75, fil), smoothstep(0.6, 1.0, age));
    // Ragged knots and filaments concentrated at the rim; only faint wisps inside.
    float rim = smoothstep(0.75, 0.95, s);
    col += sc * shell * mix(0.5, 0.35 + 1.1 * fil, rim) * wisp * bright * 1.3;
    // Faint glow filling the inside.
    col += mix(hot, midC, age) * smoothstep(1.0, 0.3, s) * 0.05 * (0.4 + fbm(d / R * 2.0 + seed * 2.0));

    // The pulsar left behind, blinking at the centre.
    float dPx = r * minDim();
    float ps = pxScale();
    float blink = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(t * 6.2831 / 0.7), 8.0);
    col += vec3(0.85, 0.92, 1.0) * smoothstep(5.0, 20.0, since) * blink
            * (exp(-dPx * dPx / (4.0 * ps * ps)) * 1.6 + exp(-dPx / (25.0 * ps)) * 0.3);
    return vec4(col * fade, 0.0);
}
