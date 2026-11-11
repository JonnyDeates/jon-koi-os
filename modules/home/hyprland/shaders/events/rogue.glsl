// Rogue planet: a planet drifting through deep space with no star of its own. Mostly a dark
// silhouette blotting out the stars behind it, its edge picked out faintly by starlight, with a very
// dim icy surface, faint aurora around its poles and a thin glowing atmosphere rim. A small grey
// moon, just as faintly lit, circles it, passing in front and behind. Premultiplied colour/coverage.
vec4 roguePlanet(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 center = (hash22(vec2(slot * 9.3, seed + 411.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.3, 0.2);
    center += (hash22(vec2(slot, seed + 413.0)) - 0.5) * 0.0003 * eventTime(t);
    float R = mix(0.14, 0.24, hash12(vec2(slot, seed + 415.0)));
    float tilt = (hash12(vec2(slot, seed + 417.0)) - 0.5) * 0.8;
    vec3 L = normalize(vec3((hash22(vec2(slot, seed + 419.0)) - 0.5) * 2.0, -0.3));  // faint starlight, mostly from behind
    // Aurora colours depend on what the atmosphere is made of: each planet gets its own pair
    // (inner ring colour, outer fringe colour).
    float ap = hash12(vec2(slot, seed + 427.0));
    vec3 aur1, aur2;
    if (ap < 0.2) {         // oxygen green with nitrogen violet, like Earth
        aur1 = vec3(0.25, 1.0, 0.55); aur2 = vec3(0.65, 0.35, 1.0);
    } else if (ap < 0.35) { // high oxygen red
        aur1 = vec3(1.0, 0.25, 0.3); aur2 = vec3(1.0, 0.55, 0.4);
    } else if (ap < 0.5) {  // blue nitrogen
        aur1 = vec3(0.3, 0.55, 1.0); aur2 = vec3(0.55, 0.4, 1.0);
    } else if (ap < 0.62) { // hydrogen pink, like Jupiter's
        aur1 = vec3(1.0, 0.4, 0.75); aur2 = vec3(0.75, 0.35, 1.0);
    } else if (ap < 0.74) { // cyan to teal
        aur1 = vec3(0.3, 1.0, 0.95); aur2 = vec3(0.3, 0.6, 1.0);
    } else if (ap < 0.86) { // sodium gold
        aur1 = vec3(1.0, 0.8, 0.3); aur2 = vec3(1.0, 0.45, 0.2);
    } else {                // green with a red top, like strong Earth storms
        aur1 = vec3(0.3, 1.0, 0.45); aur2 = vec3(1.0, 0.3, 0.3);
    }
    const vec3 ICE = vec3(0.55, 0.62, 0.75);

    vec2 d = (uv - center) / R;
    float r = length(d);
    float px = 1.5 / (R * minDim());
    vec4 res = vec4(0.0);

    // Moon orbit (tilted ellipse); it passes behind the planet when on the far side.
    float mth = hash12(vec2(slot, seed + 421.0)) * 6.2831 + t * 0.03;
    float mr = mix(1.7, 2.3, hash12(vec2(slot, seed + 423.0)));
    vec2 mo = rotate(tilt) * vec2(cos(mth) * mr, sin(mth) * mr * 0.3);
    bool moonBehind = sin(mth) > 0.0;
    float mR = mix(0.18, 0.27, hash12(vec2(slot, seed + 425.0)));
    vec2 md = (d - mo) / mR;
    float mrr = length(md);
    vec4 moon = vec4(0.0);
    if (mrr < 1.2) {
        float mz = sqrt(max(1.0 - mrr * mrr, 0.0));
        vec3 mn = vec3(md, mz);
        float crater = fbm(md * 3.0 + seed) * 0.6 + 0.4 * fbm(md * 9.0 - seed);
        float lit = clamp(dot(mn, L) + 0.15, 0.0, 1.0);
        vec3 mc = vec3(0.55, 0.57, 0.62) * (0.35 + 0.65 * crater) * (0.04 + 0.6 * lit);
        mc += vec3(0.5, 0.6, 0.8) * pow(1.0 - mz, 3.0) * 0.18;   // faint rim
        float mcov = smoothstep(1.0 + px / mR, 1.0 - px / mR, mrr);
        moon = vec4(mc * mcov, mcov);
    }

    if (r < 1.35) {
        // Atmosphere rim: a thin glow just beyond the edge, brightest where starlight grazes it.
        vec3 limbN = vec3(d / max(r, 1e-4), 0.0);
        float grazing = 0.4 + 0.6 * smoothstep(-0.3, 0.6, dot(limbN, L));
        res.rgb += vec3(0.35, 0.5, 0.85) * exp(-max(r - 1.0, 0.0) / 0.03) * smoothstep(1.0 - px, 1.0 + px, r) * 0.35 * grazing;

        if (r < 1.0 + px) {
            float z = sqrt(max(1.0 - r * r, 0.0));
            vec2 dt = rotate(tilt) * d;
            vec3 n = vec3(d, z);
            // Very dim icy surface: cracked plains catching a trace of starlight.
            float lon = atan(dt.x, z) + t * 0.01;
            float lat = asin(clamp(dt.y, -1.0, 1.0));
            float ice = fbm(vec2(lon, lat) * 3.0 + seed);
            float cracks = pow(1.0 - abs(2.0 * fbm(vec2(lon, lat) * 7.0 - seed) - 1.0), 8.0);
            float lit = clamp(dot(n, L) + 0.1, 0.0, 1.0);
            vec3 c = ICE * (0.4 + 0.6 * ice) * (0.006 + 0.18 * lit * lit) + ICE * cracks * 0.02;
            // Edge picked out by starlight from behind.
            c += vec3(0.5, 0.6, 0.85) * pow(1.0 - z, 4.0) * grazing * 0.25;
            // Aurora: faint flickering rings around both poles, on the sphere (the pole axis tips toward
            // us a little, so the near ring shows as an oval).
            vec3 P = normalize(vec3(rotate(tilt) * vec2(0.0, 1.0), 0.45));
            float polar = abs(dot(n, P));
            float oval = exp(-pow((polar - 0.86) / 0.05, 2.0));
            vec3 e1 = normalize(cross(P, vec3(0.0, 0.0, 1.0)));
            float az = atan(dot(n, cross(P, e1)), dot(n, e1));
            float curtain = 0.5 + 0.5 * fbm(vec2(az * 4.0 + t * 0.1, polar * 12.0 - t * 0.05) + seed);
            c += mix(aur1, aur2, smoothstep(0.86, 0.95, polar)) * oval * curtain * 0.35;
            float cov = smoothstep(1.0 + px, 1.0 - px, r);
            res = vec4(c * cov + res.rgb * (1.0 - cov), cov);
        }
    }
    // Composite the moon in front of or behind the planet.
    res = moonBehind ? over(res, moon) : over(moon, res);
    return res * fade;
}
