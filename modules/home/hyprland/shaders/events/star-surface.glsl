// Star surface up close: a huge star whose edge arcs in from one corner of the screen, filling about
// a third to half of that quadrant. We're close enough to see granulation (thousands of small
// boiling convection cells with dark lanes between them, like DKIST's close-ups of the Sun) and
// sunspots with dark centres and streaky penumbras, with bright patches and strong limb darkening
// toward the edge. Above the edge: a thin pink-red layer of hot gas bristling with fine flickering
// jets, prominences arching off it, faint loops, and the corona fading into space.
// Premultiplied colour/coverage.
vec4 starSurface(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 ext = halfExtent();
    // Pick a corner; the star's centre sits beyond it so only its edge comes on screen.
    vec2 corner = vec2(hash12(vec2(slot, seed + 321.0)) < 0.5 ? -1.0 : 1.0,
                       hash12(vec2(slot, seed + 323.0)) < 0.5 ? -1.0 : 1.0);
    vec2 cpos = corner * ext;
    vec2 outward = normalize(corner * ext);
    float R = mix(1.1, 1.6, hash12(vec2(slot, seed + 325.0)));
    // How far the disk reaches in from the corner, as a fraction of the quadrant's diagonal.
    float reach = mix(0.42, 0.55, hash12(vec2(slot, seed + 327.0))) * length(ext);
    vec2 center = cpos + outward * (R - reach);

    float kind = hash12(vec2(slot, seed + 329.0));
    bool giant = kind >= 0.55 && kind < 0.8;
    bool blue = kind >= 0.8;
    vec3 coreCol = giant ? vec3(1.3, 0.5, 0.12) : blue ? vec3(0.9, 1.08, 1.5) : vec3(1.4, 1.0, 0.45);
    vec3 limbCol = giant ? vec3(0.55, 0.1, 0.02) : blue ? vec3(0.35, 0.55, 1.25) : vec3(0.95, 0.35, 0.06);
    vec3 chromo = giant ? vec3(1.0, 0.3, 0.12) : blue ? vec3(0.6, 0.7, 1.4) : vec3(1.0, 0.35, 0.45);
    vec3 corona = giant ? vec3(1.0, 0.45, 0.15) : blue ? vec3(0.6, 0.8, 1.4) : vec3(1.0, 0.8, 0.55);

    vec2 d = (uv - center) / R;
    float r = length(d);
    vec2 dir = d / max(r, 1e-5);
    float px = 1.5 / (R * minDim());
    vec3 col = vec3(0.0);
    float cover = 0.0;

    if (r < 1.0 + px) {
        float z = sqrt(max(1.0 - r * r, 0.0));
        vec3 sp = vec3(d, z);
        // Granulation, sized so cells are ~20 px across at the centre of the visible part.
        float cells = R * minDim() / 16.0 / pxScale() * (giant ? 0.45 : 1.0);
        // Warp the cell lattice a little so cell edges curve instead of running straight.
        vec3 gp = sp * cells;
        gp += 0.45 * vec3(noise(gp.xy * 0.35 + seed), noise(gp.yz * 0.35 - seed), noise(gp.zx * 0.35 + 3.0)) - 0.22;
        vec2 v = voronoi3(gp, t * 1.5);
        // Rounded, bright cell centres with soft, darker lanes between; each cell a different brightness.
        float blob = exp(-v.x * v.x * 2.6);
        float lane = smoothstep(0.0, 0.45, v.y - v.x);
        float cellVar = 0.8 + 0.4 * noise(gp.xy * 0.5 + seed);
        float gran = (0.5 + 0.55 * blob * cellVar) * mix(0.8, 1.0, lane);
        // Larger patterns: supergranulation and slow plasma flows.
        float sup = fbm(sp.xy * 9.0 + sp.z * 4.0 + seed + t * 0.004);
        float b = gran * (0.82 + 0.35 * sup);
        // Sunspots: dark umbra, streaky penumbra.
        for (int k = 0; k < 2; k++) {
            if (blue) {
                break;
            }
            vec3 sc = normalize(vec3((hash22(vec2(slot * 3.0 + float(k), seed + 331.0)) - 0.5) * 0.5 + (-outward) * 0.35 * float(1 - k), 1.0));
            sc = normalize(vec3(-outward * mix(0.25, 0.75, hash12(vec2(slot, seed + 333.0 + float(k)))), 1.0)
                           + vec3((hash22(vec2(slot + float(k), seed + 335.0)) - 0.5) * 0.4, 0.0));
            float ang = acos(clamp(dot(sp, sc), -1.0, 1.0));
            float sz = mix(0.012, 0.025, hash12(vec2(slot, seed + 337.0 + float(k))));
            vec3 tA = normalize(cross(sc, vec3(0.0, 0.0, 1.0)));
            vec3 tB = cross(sc, tA);
            float sa = atan(dot(sp, tB), dot(sp, tA));
            float pen = 0.75 + 0.25 * noise(vec2(sa * 30.0, ang / sz * 2.0));
            b *= mix(1.0, 0.45 * pen, smoothstep(sz * 2.4, sz * 1.6, ang));
            b *= mix(1.0, 0.25, smoothstep(sz * 1.1, sz * 0.7, ang));
        }
        // Bright faculae near the limb.
        b += smoothstep(0.55, 0.8, fbm(sp.xy * 18.0 - seed)) * pow(1.0 - z, 2.0) * 0.6;
        // Strong limb darkening: dimmer and redder toward the edge.
        float limb = pow(z, 0.45);
        col = mix(limbCol, coreCol, pow(z, 0.6)) * b * (0.35 + 0.75 * limb);
        cover = smoothstep(1.0 + px, 1.0 - px, r);
        col *= cover;
    }

    // Above the edge.
    float h = (r - 1.0) * R;                  // height above the surface, in screen units
    if (h > -0.01) {
        float hu = max(h, 0.0);
        float along = atan(dir.y, dir.x) * R;  // distance along the edge, in screen units
        // Thin chromosphere with spicules: fine, flickering jets along the whole edge.
        float spic = fbm(vec2(along * 260.0, hu * 40.0 - t * 0.6) + seed);
        float spicH = 0.006 + 0.012 * spic;
        col += chromo * exp(-hu / spicH) * (0.6 + 0.6 * spic) * 0.9 * (1.0 - cover);
        // Corona: soft glow falling off into space, streaky.
        float streak = 0.75 + 0.25 * fbm(vec2(along * 6.0, hu * 2.0 - t * 0.02) + seed);
        col += corona * (exp(-hu / 0.05) * 0.35 + exp(-hu / 0.25) * 0.12) * streak * (1.0 - cover * 0.9);
        // Prominences: ragged, flame-like plumes and hedgerows standing on the edge, slowly shifting,
        // with vertical streaks of plasma draining down them.
        for (int k = 0; k < 3; k++) {
            float hk = hash12(vec2(slot * 5.0 + float(k), seed + 341.0));
            float centreA = atan(-outward.y, -outward.x) + (hk - 0.5) * 1.1 * (0.55 / R);
            float footW = mix(0.08, 0.18, hash12(vec2(hk, 1.0)));
            float x = (along - centreA * R) / footW;                 // -1..1 across the plume
            float win = smoothstep(1.0, 0.4, abs(x));
            float hgt = mix(0.05, 0.13, hash12(vec2(hk, 2.0)))
                    * (0.55 + 0.45 * fbm(vec2(x * 2.0 + t * 0.03, hk * 10.0))) * win;
            float body = smoothstep(hgt, hgt * 0.4, hu) * win;
            float streaks = fbm(vec2(x * 14.0, hu * 25.0 + t * 0.2) + hk * 20.0);
            float plume = body * (0.35 + 0.9 * streaks * streaks);
            col += chromo * plume * 1.4 * (1.0 - cover);
            col += chromo * body * 0.15 * (1.0 - cover);   // soft glow around each plume
        }
    }
    return vec4(col, cover) * fade;
}
