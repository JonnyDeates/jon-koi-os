// Supernova, played out over the event: a bloated blue supergiant swells and pulses unstably, then
// collapses inward and explodes in a blinding flash with long spikes; a shockwave shell races
// outward, bright at its rim, with turbulent finger-like plumes, cooling from blue-white into
// colour as it grows. It settles into a remnant like Cassiopeia A, Tycho or SN 1006 - a shell of
// tangled, patchily coloured filaments and knots inside a thin blast-wave edge, creeping outward,
// with a pulsar blinking at the centre. lt is the time within the event. Emission only; shimmer
// is for the early star.
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

    // 3. The shockwave shell, slowing as it sweeps up gas, then creeping outward for the rest of
    //    the event.
    float R = (0.34 * (1.0 - exp(-since / 35.0)) + 0.01) * (1.0 + 0.15 * eventDrift(since) / 150.0);
    float age = smoothstep(0.0, 90.0, since);
    vec2 pr = d / R;
    // Lumpy outline with finger-like plumes, built from the direction vector so there's no seam.
    float lump = (fbm(dir * 2.5 + seed) - 0.5) * 0.14;
    float fingers = (fbm(dir * 6.0 + seed * 3.0) - 0.5) * 0.22 * age;
    float s = r / R - lump - fingers;

    // Which remnant this is: a colourful Cassiopeia A, a red-and-blue Tycho, or a faint SN 1006.
    float kindR = hash12(vec2(slot, seed + 313.0));
    vec3 cA, cB, cC, edgeC;
    if (kindR < 0.45) {        // Cas A: green-teal oxygen, red sulphur, gold and blue knots
        cA = vec3(0.35, 0.95, 0.6); cB = vec3(1.0, 0.3, 0.2); cC = vec3(1.0, 0.8, 0.35); edgeC = vec3(0.4, 0.6, 1.0);
    } else if (kindR < 0.8) {  // Tycho: red-orange filaments inside a thin blue shock
        cA = vec3(1.0, 0.45, 0.25); cB = vec3(0.95, 0.25, 0.2); cC = vec3(1.0, 0.75, 0.45); edgeC = vec3(0.45, 0.65, 1.0);
    } else {                   // SN 1006: faint pinkish shell with a delicate rim
        cA = vec3(1.0, 0.55, 0.65); cB = vec3(0.8, 0.45, 0.9); cC = vec3(0.95, 0.85, 0.9); edgeC = vec3(0.7, 0.8, 1.0);
    }

    // Tangled filaments: ridges of warped noise at two scales, densest in the shell.
    vec2 w = vec2(fbm(pr * 2.0 + seed), fbm(pr * 2.0 - seed)) - 0.5;
    float f1 = pow(1.0 - abs(2.0 * fbm(pr * 4.0 + w * 2.5 + seed * 2.0) - 1.0), 5.0);
    float f2 = pow(1.0 - abs(2.0 * fbm(pr * 11.0 + w * 4.0 - seed) - 1.0), 7.0);
    float knots = smoothstep(0.6, 0.85, fbm(pr * 7.0 + seed * 5.0));
    float shellBand = exp(-pow((s - 0.88) / 0.13, 2.0));          // thick ejecta shell
    float inner = smoothstep(0.95, 0.2, s) * 0.25;                 // faint ejecta inside
    float gas = (f1 * 0.9 + f2 * 0.6 + knots * 0.7) * (shellBand + inner);
    // Patchy colour: each region of the shell glows in a different element's light.
    float patchA = fbm(pr * 1.6 + seed * 7.0);
    float patchB = fbm(pr * 2.3 - seed * 4.0);
    vec3 gc = mix(cA, cB, smoothstep(0.4, 0.6, patchA));
    gc = mix(gc, cC, smoothstep(0.55, 0.7, patchB) * 0.7);
    // While young, everything is still hot and blue-white.
    gc = mix(vec3(0.8, 0.9, 1.0), gc, smoothstep(0.05, 0.5, age));
    float bright = mix(1.8, 0.75, age) * (kindR >= 0.8 ? 0.6 : 1.0);
    col += gc * gas * bright;
    // Soft glow of the whole shell, so the filaments sit in a haze rather than on black.
    col += gc * shellBand * 0.06 * (0.5 + patchA);
    // The blast wave out ahead: a thin, sharp, faint edge, brightest where it's seen edge-on.
    // It's smooth (the plumes lag behind it) and only shows along some stretches of the rim.
    float se = r / R - lump * 0.6;
    float edge = exp(-pow((se - 1.06) / 0.02, 2.0)) * smoothstep(0.45, 0.7, fbm(dir * 3.0 + seed * 9.0));
    col += edgeC * edge * mix(1.2, 0.25, age);

    // The pulsar left behind, blinking at the centre.
    float dPx = r * minDim();
    float ps = pxScale();
    float blink = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(t * 6.2831 / 0.7), 8.0);
    col += vec3(0.85, 0.92, 1.0) * smoothstep(5.0, 20.0, since) * blink
            * (exp(-dPx * dPx / (4.0 * ps * ps)) * 1.6 + exp(-dPx / (25.0 * ps)) * 0.3);
    return vec4(col * fade, 0.0);
}
