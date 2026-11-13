// Pillars nebula, like the JWST and Hubble images of the Pillars of Creation: columns of cold dust
// and gas rising toward a cluster of hot young stars off the top of the screen, inside a glowing
// cloud. The columns are shaded as solid shapes: lit on the side facing the stars, translucent and
// glowing at their thin edges, dense and dark in their cores, their knots and folds catching the
// light. Along the lit edge an ionisation front glows, and small knots of dust sit at the tips. Emission in .rgb (premultiplied); .a is how much the dust blocks the sky behind it.
vec4 pillarNebula(vec2 uv, float seed, float slot, float t) {
    vec2 ext = halfExtent();
    bool hubble = hash12(vec2(slot, seed + 163.0)) < 0.6;
    // Hubble's palette: teal gas, gold-brown pillars. JWST's: blue haze, rust-orange pillars.
    vec3 hot = hubble ? vec3(0.3, 0.7, 0.72) : vec3(0.35, 0.5, 0.85);
    vec3 warm = hubble ? vec3(0.9, 0.65, 0.35) : vec3(1.0, 0.5, 0.3);
    vec3 dustCol = hubble ? vec3(0.22, 0.13, 0.07) : vec3(0.25, 0.1, 0.05);
    vec3 front = hubble ? vec3(1.0, 0.85, 0.6) : vec3(1.0, 0.7, 0.45);

    // The star cluster lighting everything sits just off the top edge.
    vec2 src = vec2((hash12(vec2(slot, seed + 165.0)) - 0.5) * ext.x, ext.y + 0.3);
    vec2 toSrc = src - uv;
    vec2 dirSrc = normalize(toSrc);
    float nearSrc = exp(-length(toSrc) / 0.9);

    // The glowing cloud, drifting very slowly: warped noise with fine filaments, hotter and bluer
    // toward the stars.
    vec2 p = uv * 1.6 + seed;
    float nt = t * 0.006;
    vec2 q = vec2(fbm(p + vec2(0.0, nt)), fbm(p + vec2(4.1, 7.3) - nt));
    float gas = fbm(p * 1.3 + q * 2.2 + nt);
    float wisp = fbm(p * 5.0 + q * 3.0 - nt);
    vec3 col = mix(warm * 0.8, hot, clamp(nearSrc * 1.3 + (q.x - 0.5) * 0.8, 0.0, 1.0))
            * (0.12 + 0.75 * gas * gas + 0.25 * wisp * wisp) * (0.45 + 1.0 * nearSrc);
    // The cluster's young stars, crowded near the source.
    col += starLayer(uv, 40.0, 0.5, 2.0, seed + 11.0, t, 1.0) * exp(-length(toSrc) / 0.4);

    // Pillars rising from the bottom toward the light, with ragged, eroded edges.
    float erosion = fbm(uv * 4.0 + seed * 1.7) * 0.65 + fbm(uv * 14.0 - seed) * 0.35;
    float dens = 0.0;   // how much dust the line of sight crosses
    float nx = 0.0;     // across-the-pillar position (-1..1), for shading it as a rounded column
    float height = 0.0; // how far up its pillar this pixel is
    float frontGlow = 0.0;
    int count = 2 + int(hash12(vec2(slot, seed + 167.0)) * 1.99);
    float y0 = -ext.y - 0.1;
    for (int i = 0; i < 3; i++) {
        if (i >= count) {
            break;
        }
        float hi = hash12(vec2(slot * 3.0 + float(i), seed + 169.0));
        float baseX = ((float(i) + 0.5) / float(count) * 2.0 - 1.0 + (hi - 0.5) * 0.5) * ext.x * 0.75;
        float tipY = mix(-0.05, ext.y * 0.6, hash12(vec2(hi, 1.0)));
        float lean = (hash12(vec2(hi, 2.0)) - 0.5) * 0.5;
        float wBase = mix(0.12, 0.22, hash12(vec2(hi, 3.0)));

        float s = clamp((uv.y - y0) / (tipY - y0), 0.0, 1.2); // 0 at the bottom, 1 at the tip
        float axis = baseX + lean * s * (tipY - y0) + (noise(vec2(uv.y * 3.0, hi * 10.0)) - 0.5) * 0.1;
        // Tapers toward a broad, rounded head rather than a point.
        float width = wBase * mix(1.0, 0.45, s) * sqrt(max(1.0 - pow(max(s - 0.8, 0.0) / 0.25, 2.0), 0.0));
        float edgeD = width - abs(uv.x - axis) + (erosion - 0.5) * 0.14; // > 0 inside
        float inside = smoothstep(-0.01, 0.03, edgeD) * smoothstep(1.08, 1.0, s);
        // Thickness through a rounded column: thin at the edges, thick in the middle.
        float th = inside * sqrt(clamp(edgeD / max(width, 0.01), 0.0, 1.0));
        if (th > dens) {
            dens = th;
            nx = clamp((uv.x - axis) / max(width, 0.01), -1.0, 1.0);
            height = s;
        }
        // Ionisation front: a thin glow just outside the edge, strongest at the head and on the
        // side facing the light.
        float lit = smoothstep(0.3, 1.0, s) * smoothstep(1.12, 1.0, s);
        float facing = 0.5 + 0.5 * sign(uv.x - axis) * dirSrc.x + 0.4;
        frontGlow += exp(-abs(edgeD + 0.004) / 0.008) * lit * facing * (0.4 + 0.6 * erosion);
    }

    // Shading the column: a normal from across-pillar position, tipped up at the head.
    // Lumpy relief: the slope of the dust's clumps tilts the surface, so knots and folds catch
    // the light on one side and fall into shadow on the other.
    float lumps = fbm(uv * 9.0 + seed);
    float grit = fbm(uv * 30.0 - seed);
    const float eh = 0.004;
    vec2 relief = vec2(fbm((uv + vec2(eh, 0.0)) * 9.0 + seed) - lumps, fbm((uv + vec2(0.0, eh)) * 9.0 + seed) - lumps) / eh * 0.014;
    vec3 n = normalize(vec3(nx - relief.x * 1.5, smoothstep(0.75, 1.0, height) * 1.2 - relief.y * 1.5, sqrt(max(1.0 - nx * nx, 0.0))));
    vec3 L = normalize(vec3(dirSrc, 0.4));
    float lambert = max(dot(n, L), 0.0);
    float density = dens * (0.6 + 0.6 * lumps) * (0.8 + 0.4 * grit);
    float alpha = 1.0 - exp(-density * 4.0);
    // The dust glows faintly from inside where light leaks in, warmest toward the head.
    vec3 dustShade = dustCol * (0.12 + 2.4 * lambert * (0.3 + 0.7 * height)) * (0.5 + 1.0 * lumps)
                   + front * 0.22 * pow(lambert, 3.0) * height
                   + warm * 0.12 * (1.0 - alpha) * height;
    col = col * (1.0 - alpha) + dustShade * alpha;
    col += front * min(frontGlow, 1.5) * 0.45;

    // Small dark knots of dust at the pillar heads (evaporating gas globules), each lit on top.
    vec2 kg = uv * 28.0 + seed;
    vec2 kid = floor(kg);
    vec2 kf = fract(kg) - 0.5 - (hash22(kid) - 0.5) * 0.4;
    float knot = exp(-dot(kf, kf) / 0.02) * step(hash12(kid + 3.0), 0.25) * smoothstep(0.8, 1.0, height) * dens;
    col = mix(col, dustCol * 0.5, knot * 0.7) + front * knot * smoothstep(0.0, 0.15, dot(kf, dirSrc)) * 0.3;

    // Glowing haze drifting in front of the pillars' bases, so they rise out of the gas.
    float baseHaze = smoothstep(0.0, -ext.y - 0.05, uv.y) * (0.5 + 0.5 * fbm(uv * 3.0 - nt + seed));
    col += warm * 0.18 * baseHaze;
    alpha *= 1.0 - 0.6 * baseHaze;
    // A few young stars embedded in the gas.
    col += heatStars(uv + seed, seed + 13.0, t, 1.0) * 0.7;
    return vec4(col, alpha);
}
