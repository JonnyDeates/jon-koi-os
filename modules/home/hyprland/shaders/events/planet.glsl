// A planet hanging in space, seen whole. Gas worlds use the gas giant close-up's renderer (bands,
// eddies, storms, rings and their shadows, a small moon). Rocky worlds are one of:
//  - Earth-like: oceans with a sun glint, continents of forest, grassland and desert, ice caps,
//    swirling clouds and cyclones casting shadows, and sometimes city lights on the night side;
//  - ocean world: nearly all sea, scattered islands, heavy cloud;
//  - desert, like Mars: rust plains, dark rock, craters, a small polar cap, thin pink haze;
//  - ice world: white and blue-grey ice crossed by cracks;
//  - lava world: dark crust split by glowing magma, bright on the night side;
//  - barren and cratered, like Mercury, with no air.
// The surface is textured in 3D, so nothing pinches at the poles, and the planet slowly turns.
// Premultiplied planet colour in .rgb, coverage in .a; atmosphere glow is returned separately.

// Turn a point on the planet into its own spinning frame: axis tipped by tilt, turned by ang.
vec3 planetSpin(vec3 n, float tilt, float ang) {
    vec2 xy = rotate(tilt) * n.xy;
    vec3 s = vec3(xy, n.z);
    float c = cos(ang), sn = sin(ang);
    return vec3(s.x * c - s.z * sn, s.y, s.x * sn + s.z * c);
}

// One layer of craters in 3D cells, at most one per cell, each its own size. Returns the
// ground's slope (to tilt the surface normal, so the sun lights one inner wall and shadows the
// other) in .xyz, and a darkening of the floor in .w. px is the pixel size, for fading out
// craters too small to draw.
vec4 planetCraterLayer(vec3 p, float scale, float dens, float seed, float px) {
    vec3 g = p * scale;
    vec3 id = floor(g);
    vec3 h = hash33(id + seed);
    if (h.x > dens) {
        return vec4(0.0);
    }
    float rad = mix(0.1, 0.32, h.y * h.y);
    float keep = smoothstep(2.0, 5.0, rad / scale / px);
    vec3 o = g - (id + 0.5 + (hash33(id + seed + 7.1) - 0.5) * 0.3);
    float q = length(o) / rad;
    if (q > 1.6 || keep <= 0.0) {
        return vec4(0.0);
    }
    vec3 dir = o / max(length(o), 1e-5);
    // Bowl inside (rising toward the rim), sharp rim crest, ejecta sloping away outside.
    float dh = q < 1.0 ? 1.4 * q : -1.4 * exp(-(q - 1.0) * 5.0);
    float young = step(0.8, h.z);
    float floorDark = smoothstep(1.0, 0.7, q) * 0.15 - young * smoothstep(1.6, 1.0, q) * 0.25;
    return vec4(dir * dh * mix(0.4, 0.8, h.z), floorDark) * keep;
}

vec4 planetCraters(vec3 s, float seed, float px, float dens) {
    return planetCraterLayer(s, 4.0, dens * 0.5, seed, px)
         + planetCraterLayer(s, 9.0, dens * 0.6, seed + 3.0, px)
         + planetCraterLayer(s, 20.0, dens * 0.7, seed + 6.0, px);
}

// Cloud cover on an Earth-like world at body point s: warped 3D noise, a couple of cyclones
// twisting it into spirals, and a coverage threshold.
float planetClouds(vec3 s, float seed, float slot, float t, float cover) {
    vec3 p = s;
    float cyc = 0.0;
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        vec3 c = normalize(hash33(vec3(slot, seed + 71.0, fi)) - 0.5);
        float sgn = hash12(vec2(fi, seed + 73.0)) < 0.5 ? -1.0 : 1.0;
        float dd = length(p - c);
        // Bend the surrounding clouds gently around the storm.
        float tw = sgn * 1.2 * exp(-dd * dd / 0.06);
        vec3 rel = p - c * dot(p, c);
        p = c * dot(p, c) + rel * cos(tw) + cross(c, rel) * sin(tw);
        // The storm itself: two spiral arms winding into a clear eye.
        float size = mix(0.1, 0.17, hash12(vec2(fi, seed + 75.0)));
        if (dot(s, c) > 0.0 && dd < size * 2.6) {
            vec3 e1 = normalize(cross(c, vec3(0.0, 1.0, 0.0)));
            vec3 e2 = cross(c, e1);
            vec2 l = vec2(dot(s, e1), dot(s, e2)) / size;
            float rl = length(l);
            float th = atan(l.y, l.x);
            float arm = 0.5 + 0.5 * cos(2.0 * (th + sgn * 3.0 * log(rl + 0.05)) + giantNoise(s * 30.0) * 1.5);
            cyc = max(cyc, smoothstep(0.25, 0.9, arm) * (0.55 + 0.45 * giantNoise(s * 45.0 + seed)) * exp(-rl * rl * 0.5) * smoothstep(0.08, 0.3, rl));
        }
    }
    vec3 q = p * 4.0 + seed + vec3(t * 0.004, 0.0, 0.0);
    float wv = giantFbm(q * 0.6, 3);
    float d = giantFbm(q + vec3(wv * 2.5, wv * 1.5, 0.0) + vec3(0.0, 0.0, t * 0.003), 5);
    // Streaky, where weather fronts are stretched out along the winds.
    float streak = giantFbm(vec3(p.x * 6.0, p.y * 26.0, p.z * 6.0) + vec3(wv * 3.0, 0.0, 0.0) + seed * 2.0, 4);
    float v = d * 0.6 + streak * 0.45;
    // Thin wisps around the edges of the thicker cloud.
    float base = smoothstep(cover, cover + 0.12, v) * 0.85 + smoothstep(cover - 0.08, cover + 0.02, v) * 0.15;
    return max(base, cyc);
}

vec4 planet(vec2 uv, float seed, float slot, float lt, float t, float fade, out vec3 glowOut) {
    glowOut = vec3(0.0);
    vec2 rnd = hash22(vec2(slot * 1.7, seed + 3.0));
    // Mostly small-to-medium, occasionally huge.
    float radius = mix(0.06, 0.26, pow(hash12(vec2(slot, seed + 5.0)), 1.8));
    vec2 center = (rnd - 0.5) * 2.0 * halfExtent() * vec2(0.75, 0.6);
    center += (hash22(vec2(slot, seed + 9.0)) - 0.5) * 0.0006 * eventDrift(lt);

    bool gas = hash12(vec2(slot, seed + 13.0)) < 0.5;
    float tilt = (hash12(vec2(slot, seed + 19.0)) - 0.5) * 0.9;
    // Sun off to one side; sometimes partly behind the planet for a crescent.
    vec2 lightDir = normalize(hash22(vec2(slot, seed + 29.0)) - 0.5);
    vec3 light = normalize(vec3(lightDir, mix(-0.45, 0.6, hash12(vec2(slot, seed + 33.0)))));

    vec2 d = (uv - center) / radius;
    float r2 = dot(d, d);
    if (r2 > (gas ? 7.0 : 2.8)) {
        return vec4(0.0);
    }
    float r = sqrt(r2);
    float px = 1.5 / (radius * minDim());

    // World kind and its air: sky colour (scattered light), how thick the air is.
    float kr = hash12(vec2(slot, seed + 61.0));
    int kind;
    vec3 sky;
    float thickness;
    if (gas) {
        kind = -1;
        sky = vec3(0.0);
        thickness = 0.09;
    } else if (kr < 0.35) {
        kind = 0; sky = vec3(0.3, 0.55, 1.0); thickness = 0.06;    // Earth-like
    } else if (kr < 0.47) {
        kind = 1; sky = vec3(0.3, 0.6, 1.0); thickness = 0.07;     // ocean world
    } else if (kr < 0.67) {
        kind = 2; sky = vec3(0.95, 0.65, 0.5); thickness = 0.025;  // desert
    } else if (kr < 0.8) {
        kind = 3; sky = vec3(0.6, 0.8, 1.0); thickness = 0.02;     // ice
    } else if (kr < 0.9) {
        kind = 4; sky = vec3(0.6, 0.4, 0.3); thickness = 0.02;     // lava
    } else {
        kind = 5; sky = vec3(0.0); thickness = 0.0;                // barren
    }
    const vec3 SUNSET = vec3(1.0, 0.5, 0.3);
    float scaleH = max(thickness * 0.5, 0.001);

    vec4 body = vec4(0.0);
    if (gas) {
        // The gas giant renderer, at this size and lighting.
        vec3 gTint;
        body = giantBody(uv, center, radius, light, seed, slot, lt, gTint);
        sky = mix(gTint, vec3(0.8, 0.9, 1.0), 0.4);
        thickness = 0.05;
        scaleH = 0.025;
    } else if (r < 1.0 + px) {
        float z = sqrt(max(1.0 - r2, 0.0));
        vec3 n = vec3(d, z);
        // A full turn every ~10 minutes, so continents visibly creep round over a long event.
        float ang = t * 0.01 + hash12(vec2(slot, seed + 23.0)) * 6.2831;
        vec3 s = planetSpin(n, tilt, ang);
        float sunDot = dot(n, light);
        float lat = s.y;
        float pSeed = hash12(vec2(slot, seed + 43.0)) * 50.0;

        vec3 surf;
        float ocean = 0.0;
        float clouds = 0.0;
        float cloudShadow = 0.0;
        vec3 emit = vec3(0.0);
        vec4 crat = vec4(0.0);
        if (kind <= 1) {
            // Continents: warped 3D noise; the ocean world keeps only the highest ground.
            vec3 wp = s * 1.7 + pSeed;
            float wv = giantFbm(wp * 1.3, 3) - 0.5;
            float h = giantFbm(wp + vec3(wv, -wv, wv) * 0.9, 6);
            float sea = kind == 0 ? mix(0.47, 0.55, hash12(vec2(slot, seed + 63.0))) : 0.64;
            ocean = smoothstep(sea + 0.006, sea - 0.006, h);
            float elev = clamp((h - sea) / 0.2, 0.0, 1.0);
            float depth = clamp((sea - h) / 0.15, 0.0, 1.0);
            vec3 seaC = mix(vec3(0.03, 0.16, 0.24), vec3(0.01, 0.04, 0.12), sqrt(depth));
            // Land: wet green near the equator and high latitudes, dry desert belts in between,
            // brown-grey mountains, all broken up by noise.
            float moist = giantFbm(s * 4.0 - pSeed, 4);
            float dryBelt = exp(-pow((abs(lat) - 0.38) / 0.16, 2.0));
            float dry = smoothstep(0.52, 0.72, moist * 0.6 + dryBelt * 0.55);
            vec3 green = mix(vec3(0.07, 0.13, 0.05), vec3(0.16, 0.2, 0.08), moist);
            vec3 desert = mix(vec3(0.55, 0.43, 0.28), vec3(0.7, 0.58, 0.4), moist);
            vec3 land = mix(green, desert, dry);
            land = mix(land, vec3(0.32, 0.28, 0.24), smoothstep(0.45, 0.85, elev));
            surf = mix(land, seaC, ocean);
            // Ice caps, ragged at the edge; sea ice too.
            float capEdge = mix(0.82, 0.9, hash12(vec2(slot, seed + 65.0))) + (giantFbm(s * 6.0 + pSeed, 3) - 0.5) * 0.12;
            float ice = smoothstep(capEdge, capEdge + 0.03, abs(lat) + elev * 0.08);
            surf = mix(surf, vec3(0.85, 0.9, 0.95), ice);
            ocean *= 1.0 - ice;

            // Clouds, and their shadows a little way off toward the sun.
            float cover = kind == 0 ? mix(0.52, 0.6, hash12(vec2(slot, seed + 67.0))) : 0.53;
            float cAng = t * 0.013 + hash12(vec2(slot, seed + 23.0)) * 6.2831;
            clouds = planetClouds(planetSpin(n, tilt, cAng), seed, slot, t, cover);
            vec3 nSh = normalize(n + light * 0.02);
            cloudShadow = planetClouds(planetSpin(nSh, tilt, cAng), seed, slot, t, cover);

            // City lights: clusters along coasts and in the lowlands, on some Earth-likes.
            if (kind == 0 && hash12(vec2(slot, seed + 69.0)) < 0.5) {
                float coast = smoothstep(0.12, 0.0, elev) * (1.0 - ocean);
                float cities = smoothstep(0.62, 0.8, giantFbm(s * 28.0 + pSeed, 3)) * (0.3 + 0.7 * coast);
                emit = vec3(1.0, 0.7, 0.35) * cities * (1.0 - ice) * (1.0 - ocean) * 0.35;
            }
        } else if (kind == 2) {
            float h = giantFbm(s * 2.2 + pSeed, 6);
            vec3 base = mix(vec3(0.48, 0.24, 0.13), vec3(0.68, 0.45, 0.3), smoothstep(0.35, 0.65, h));
            // Dark rocky regions, like Mars's Syrtis Major.
            base = mix(base, vec3(0.22, 0.13, 0.09), smoothstep(0.55, 0.7, giantFbm(s * 1.4 - pSeed, 4)) * 0.8);
            crat = planetCraters(s, pSeed, px, 0.7);
            float cap = smoothstep(0.9, 0.93, abs(lat) + (giantFbm(s * 8.0, 2) - 0.5) * 0.06);
            surf = mix(base, vec3(0.9, 0.88, 0.86), cap);
        } else if (kind == 3) {
            float h = giantFbm(s * 2.0 + pSeed, 5);
            surf = mix(vec3(0.62, 0.7, 0.78), vec3(0.9, 0.93, 0.96), smoothstep(0.35, 0.7, h));
            // Long arcing cracks stained reddish-brown, like Europa's lineae: great-circle-ish
            // bands that wander a little, some doubled.
            float crack = 0.0;
            for (int i = 0; i < 9; i++) {
                float fi = float(i);
                vec3 ax = normalize(hash33(vec3(fi, pSeed, 3.0)) - 0.5);
                float off = (hash12(vec2(fi, pSeed + 5.0)) - 0.5) * 0.8;
                float l = abs(dot(s, ax) - off + (giantNoise(s * 6.0 + fi * 7.0) - 0.5) * 0.06);
                float w = mix(0.004, 0.012, hash12(vec2(fi, pSeed + 9.0))) + px * 0.7;
                float band = smoothstep(w, w * 0.3, abs(l - w * 1.6)) + smoothstep(w * 0.8, 0.0, l) * 0.5;
                // Each crack only runs part way round.
                band *= smoothstep(0.2, 0.5, giantNoise(s * 2.0 + fi * 11.0));
                crack = max(crack, band * mix(0.5, 0.9, hash12(vec2(fi, pSeed + 13.0))));
            }
            surf = mix(surf, vec3(0.5, 0.33, 0.24), crack * 0.7);
            crat = planetCraters(s, pSeed, px, 0.15);
        } else if (kind == 4) {
            float h = giantFbm(s * 2.5 + pSeed, 5);
            surf = mix(vec3(0.07, 0.065, 0.06), vec3(0.2, 0.18, 0.16), h);
            // Magma: thin wandering fissures (ridges of warped noise) and a few lava lakes,
            // flickering slowly. Bright on the night side, a dull red glow by day.
            vec3 fp3 = s * 3.0 + pSeed;
            float fw = giantFbm(fp3 * 0.8, 3) - 0.5;
            float ridge = 1.0 - abs(2.0 * giantFbm(fp3 + fw * 1.5, 4) - 1.0);
            float crackL = smoothstep(0.965 - px * 3.0, 0.992, ridge);
            float lake = smoothstep(0.66, 0.72, giantFbm(s * 2.2 - pSeed, 4));
            float hot = max(crackL, lake);
            surf = mix(surf, vec3(0.25, 0.07, 0.02), hot);
            emit = mix(vec3(1.0, 0.28, 0.04), vec3(1.0, 0.7, 0.3), lake) * hot * (0.65 + 0.35 * giantNoise(s * 20.0 + t * 0.3));
            crat = planetCraters(s, pSeed, px, 0.12);
        } else {
            float h = giantFbm(s * 2.4 + pSeed, 5);
            surf = mix(vec3(0.22, 0.21, 0.2), vec3(0.42, 0.4, 0.38), h);
            crat = planetCraters(s, pSeed, px, 1.0);
        }

        // Crater slopes tilt the surface (in the planet's own frame), so each crater has a lit
        // wall and a shadowed one.
        surf *= 1.0 - crat.w;
        vec3 sb = normalize(s - crat.xyz * 0.35);
        vec3 lb = planetSpin(light, tilt, ang);
        float sunDotC = dot(sb, lb);
        // Daylight with a soft terminator (wider where the air is thicker), darker toward the limb.
        float wrap = thickness * 1.5;
        float diff = clamp((sunDotC + wrap) / (1.0 + wrap), 0.0, 1.0) * smoothstep(-0.12, 0.02, sunDot);
        float limbDark = mix(1.0, 0.65 + 0.35 * z, step(0.001, thickness));
        vec3 col = surf * diff * limbDark * (1.0 - 0.6 * cloudShadow * (1.0 - clouds));
        // Sun glint on open water: a sharp core and a broad sheen, stronger at a glancing angle.
        if (ocean > 0.0) {
            vec3 hv = normalize(light + vec3(0.0, 0.0, 1.0));
            float nh = max(dot(n, hv), 0.0);
            float fres = 0.02 + 0.98 * pow(1.0 - z, 5.0);
            float glint = pow(nh, 400.0) * 3.0 + pow(nh, 40.0) * 0.25;
            col += vec3(1.0, 0.92, 0.8) * glint * ocean * (1.0 - clouds) * step(0.0, sunDot) * (0.3 + fres);
        }
        // Lit cloud tops, slightly brighter than the ground and with their own soft terminator.
        vec3 cloudC = vec3(0.95, 0.96, 1.0) * clamp((sunDot + 0.08) / 1.08, 0.0, 1.0);
        col = mix(col, cloudC, clouds * 0.92);
        // Night-side glow (cities, magma), dimmed by cloud and fading into daylight.
        col += emit * smoothstep(0.1, -0.1, sunDot) * (1.0 - clouds * 0.8) + emit * 0.08 * (kind == 4 ? 1.0 : 0.0);

        if (thickness > 0.0) {
            // Haze thickens toward the limb (more air along the line of sight).
            float airmass = thickness / max(z, 0.04);
            float haze = 1.0 - exp(-airmass * 6.0);
            vec3 hazeLight = mix(SUNSET, sky, smoothstep(-0.02, 0.25, sunDot)) * smoothstep(-0.08, 0.35, sunDot);
            col = mix(col, hazeLight * 0.8, haze * 0.6);
            // Twilight: a thin band of sunset light along the day/night line.
            float twilight = exp(-sunDot * sunDot / 0.002) * smoothstep(-0.08, 0.02, sunDot);
            col += SUNSET * twilight * (0.01 + 0.12 * haze) * thickness * 8.0;
        }

        float cover = smoothstep(1.0 + px, 1.0 - px, r);
        body = vec4(col * cover, cover);
    }

    // Atmosphere seen edge-on beyond the surface: a thin, bright shell that fades out into space.
    if (thickness > 0.0 && r > 1.0 - px) {
        vec3 limbN = vec3(d / r, 0.0);
        float limbSun = dot(limbN, light);
        float density = exp(-max(r - 1.0, 0.0) / scaleH);
        float column = density * sqrt(max(r - 1.0, 0.0) + scaleH) / sqrt(scaleH);
        float lit = smoothstep(-0.35, 0.5, limbSun);
        // Backlit: sunlight scattering forward through the rim makes a ring of light.
        float forward = pow(max(-light.z, 0.0), 1.2) * smoothstep(-1.0, 0.2, limbSun) * 2.0;
        vec3 tint = mix(SUNSET, sky, smoothstep(-0.1, 0.45, limbSun));
        float edgeIn = smoothstep(1.0 - px, 1.0 + px, r);
        glowOut = tint * column * (lit + forward) * 0.75 * edgeIn * fade * min(thickness / 0.05, 1.0);
    }
    return body * fade;
}
