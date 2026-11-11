// A distant spiral galaxy seen at an angle, slowly turning: a warm glowing bulge, bluish spiral
// arms with pink star-forming knots and young blue stars, dark dust lanes along the arms' inner
// edges, and a speckle of resolved stars. Sometimes a small companion galaxy.
// Emission in .rgb (premultiplied), and .a is how much the dust blocks the sky behind it.
vec4 spiralGalaxy(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 center = (hash22(vec2(slot * 6.1, seed + 131.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.35, 0.25);
    float size = mix(0.35, 0.6, hash12(vec2(slot, seed + 133.0)));   // disk radius
    float tilt = hash12(vec2(slot, seed + 135.0)) * 6.2831;          // orientation on screen
    float incl = mix(0.35, 0.9, hash12(vec2(slot, seed + 137.0)));   // 1 = face-on
    // 2 arms (grand-design spirals) most often, sometimes 3 or 4.
    float armPick = hash12(vec2(slot, seed + 139.0));
    float arms = armPick < 0.6 ? 2.0 : armPick < 0.85 ? 3.0 : 4.0;
    // Choose how much further out each neighbouring arm sits (1.7-2.4x), then derive the pitch, so
    // arms stay evenly spaced instead of opening into huge gaps at the edge.
    float gapRatio = mix(1.7, 2.4, hash12(vec2(slot, seed + 141.0)));
    float pitch = atan(arms * log(gapRatio) / 6.2831);
    float spinDir = hash12(vec2(slot, seed + 143.0)) < 0.5 ? -1.0 : 1.0;
    // Variety: arm colour (blue-white, lavender or golden), a central bar, and bulge size.
    float tintPick = hash12(vec2(slot, seed + 147.0));
    vec3 armTint = tintPick < 0.5 ? vec3(0.62, 0.74, 1.0)
                 : tintPick < 0.75 ? vec3(0.78, 0.68, 1.0) : vec3(1.0, 0.85, 0.62);
    bool barred = hash12(vec2(slot, seed + 149.0)) < 0.4;
    float bulge = mix(0.7, 1.4, hash12(vec2(slot, seed + 151.0)));

    // Into the galaxy's own plane, in units of its radius. The whole pattern turns slowly as one.
    vec2 p = rotate(-tilt) * (uv - center);
    p.y /= incl;
    vec2 dp = rotate(spinDir * t * 0.005) * (p / size);
    float r = length(dp);
    vec4 result = vec4(0.0);
    if (r < 1.6) {
        float theta = atan(dp.y, dp.x);
        float px = 1.0 / (size * incl * minDim()); // one screen pixel in disk units (worst axis)

        // Logarithmic spiral arms, wobbled a little by noise so they look clumpy rather than drawn.
        float warp = fbmAA(dp * 4.0 + seed, px * 4.0) - 0.5;
        float phase = arms * (theta - log(max(r, 1e-3)) / tan(pitch)) + warp * 1.4;
        float arm = pow(0.5 + 0.5 * cos(phase), 2.2);
        // Faint spurs and feathering between the main arms.
        arm += 0.25 * pow(0.5 + 0.5 * cos(phase * 2.0 + 1.3 + warp * 3.0), 4.0)
                * smoothstep(0.3, 0.6, fbmAA(dp * 6.0 + seed * 1.3, px * 6.0));
        float mottle = 0.6 + 0.8 * fbmAA(dp * 8.0 - seed, px * 8.0);
        float diskLight = exp(-r / 0.4);
        float armLight = arm * mottle * exp(-r / 0.55) * (barred ? smoothstep(0.18, 0.3, r) : smoothstep(0.04, 0.18, r));

        // Star-forming knots (pink) and young blue stars, mostly along the arms.
        float knotN = fbmAA(dp * 16.0 + seed * 2.0, px * 16.0);
        float knots = smoothstep(0.62, 0.8, knotN) * armLight;
        float young = smoothstep(0.58, 0.78, fbmAA(dp * 24.0 - seed, px * 24.0)) * armLight;

        vec3 col = vec3(0.85, 0.82, 0.92) * diskLight * 0.5;
        col += armTint * armLight * 1.2;
        col += vec3(1.0, 0.42, 0.6) * knots * 1.8;
        col += vec3(0.7, 0.82, 1.0) * young * 1.1;

        // Warm, bright bulge.
        col += vec3(1.0, 0.85, 0.62) * (exp(-r / (0.06 * bulge)) * 1.2 + exp(-r / (0.2 * bulge)) * 0.5);
        if (barred) {
            // A bar through the centre, lined up with where the arms begin so they grow from its ends.
            float barAng = log(0.26) / tan(pitch);
            vec2 bd = vec2(cos(barAng), sin(barAng));
            float bx = dot(dp, bd);
            float by = dot(dp, vec2(-bd.y, bd.x));
            float bar = exp(-pow(bx / 0.26, 4.0)) * exp(-(by / 0.045) * (by / 0.045));
            col += mix(armTint, vec3(1.0, 0.88, 0.7), 0.6) * bar * 0.7;
        }

        // Dust lanes hugging the inner (trailing) edge of each arm.
        float lanes = pow(0.5 + 0.5 * cos(phase + 0.55 * spinDir), 8.0);
        float dust = lanes * fbmAA(dp * 10.0 + seed * 3.0, px * 10.0) * 1.6
                * smoothstep(0.08, 0.25, r) * exp(-r / 0.7);
        dust = clamp(dust, 0.0, 0.85);
        col *= 1.0 - dust;

        // Resolved stars scattered through the disk, denser where the disk is bright.
        col += starLayer(dp * size, 70.0, 0.25, 1.0, seed + 5.0, t, 1.0) * (diskLight + armLight) * 1.5;

        col *= smoothstep(1.6, 1.0, r); // soft outer edge
        result = vec4(col, dust * 0.6 * smoothstep(1.2, 0.6, r));
    }

    // A small companion galaxy, sometimes.
    if (hash12(vec2(slot, seed + 145.0)) < 0.4) {
        vec2 cc = center + rotate(tilt) * vec2(size * 1.25, size * 0.3 * incl);
        float cr = length(uv - cc) / (size * 0.12);
        result.rgb += vec3(1.0, 0.88, 0.7) * (exp(-cr * 2.0) * 0.6 + exp(-cr * 0.7) * 0.12);
    }
    return result * fade;
}

// An elliptical galaxy: a smooth, featureless glow of old stars, warm yellow-white and brightest
// in the core, falling off gently into a wide halo (de Vaucouleurs profile). Round to quite flat,
// with a swarm of globular clusters around it, sometimes a faint dust lane across the core, and a
// few small companion galaxies. Emission in .rgb; .a is the dust lane.
vec4 ellipticalGalaxy(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 center = (hash22(vec2(slot * 5.3, seed + 211.0)) - 0.5) * 2.0 * halfExtent() * vec2(0.35, 0.25);
    float re = mix(0.16, 0.26, hash12(vec2(slot, seed + 213.0)));      // half-light radius
    float tilt = hash12(vec2(slot, seed + 215.0)) * 6.2831;
    float axis = mix(0.45, 0.95, hash12(vec2(slot, seed + 217.0)));    // 1 = round
    bool lane = hash12(vec2(slot, seed + 219.0)) < 0.3;
    vec3 warm = mix(vec3(1.0, 0.86, 0.66), vec3(1.0, 0.92, 0.82), hash12(vec2(slot, seed + 221.0)));

    vec2 p = rotate(-tilt) * (uv - center);
    p.y /= axis;
    float r = length(p) / re;

    // Smooth light profile (Sersic, n = 2): a bright but soft core falling off into a wide halo.
    // The outskirts get a slightly boxy outline and faint lumpiness; the core stays round.
    float boxy = 1.0 + 0.05 * cos(4.0 * atan(p.y, p.x)) * smoothstep(0.5, 2.0, r);
    float rr = r * boxy * (1.0 + (fbm(p / re * 0.8 + seed) - 0.5) * 0.06);
    float I = exp(-3.67 * (sqrt(max(rr, 1e-4)) - 1.0));
    // Slightly redder toward the outskirts.
    vec3 col = mix(warm, vec3(1.0, 0.72, 0.5), smoothstep(0.5, 4.0, r)) * I * 0.3;
    col += vec3(1.0, 0.95, 0.85) * exp(-r * r / 0.004) * 0.6; // small bright nucleus
    col = col / (1.0 + col * 0.6);

    float dust = 0.0;
    if (lane) {
        // A thin, wavy dust lane across the core, like Centaurus A.
        float ly = (p.y * axis + (noise(vec2(p.x / re * 1.5, seed)) - 0.5) * re * 0.3) / (re * 0.18);
        dust = exp(-ly * ly) * smoothstep(2.5, 0.8, abs(p.x) / re) * (0.6 + 0.4 * fbm(p / re * 3.0 + seed));
        col *= 1.0 - dust * 0.8;
        col += vec3(0.25, 0.12, 0.06) * dust * 0.15;
    }

    // Globular clusters: faint, tight points swarming around the galaxy.
    vec2 gq = (uv - center) / re;
    float gr = length(gq);
    col += starLayer(uv, 90.0, 0.35, 0.9, seed + 23.0, t, 1.0) * vec3(1.0, 0.92, 0.8)
            * smoothstep(6.0, 1.0, gr) * smoothstep(0.8, 1.6, gr);

    // A few small companion galaxies nearby.
    for (int i = 0; i < 3; i++) {
        float hi = hash12(vec2(slot * 13.0 + float(i), seed + 223.0));
        if (hi > 0.6) {
            continue;
        }
        vec2 cc = center + (hash22(vec2(hi, 4.0)) - 0.5) * re * 9.0;
        float cr = length(uv - cc) / (re * mix(0.12, 0.3, hash12(vec2(hi, 5.0))));
        col += warm * (exp(-cr * 2.0) * 0.5 + exp(-cr * 0.6) * 0.05);
    }
    return vec4(col, dust * 0.8) * fade;
}
