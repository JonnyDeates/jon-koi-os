// A field of tumbling asteroids drifting past at four depths (near ones bigger and faster).
// Each rock is a real 3D shape - a lumpy, elongated potato, ray-marched so its outline and
// shading come from the geometry - turning slowly about its own random axis. The surfaces are
// dusty regolith pocked with craters, lit by a hard sun with black shadows and no air to soften
// them. Fine dust streams past close to the camera. Premultiplied colour/coverage.

// Rotation by angle a about unit axis ax.
mat3 rockRot(vec3 ax, float a) {
    float c = cos(a), s = sin(a), k = 1.0 - c;
    return mat3(c + ax.x * ax.x * k, ax.y * ax.x * k + ax.z * s, ax.z * ax.x * k - ax.y * s,
                ax.x * ax.y * k - ax.z * s, c + ax.y * ax.y * k, ax.z * ax.y * k + ax.x * s,
                ax.x * ax.z * k + ax.y * s, ax.y * ax.z * k - ax.x * s, c + ax.z * ax.z * k);
}

// Distance (roughly) to the surface of rock h, at pb in its own frame: a squashed, stretched
// ball whose radius wanders with direction into lobes and hollows, then cut by four planes
// (columns of cuts: normal and offset) into flat faces with sharp edges, like a broken chunk.
float rockShape(vec3 pb, float h, vec3 squash, mat4 cuts) {
    vec3 q = pb / squash;
    float l = length(q);
    vec3 dir = q / max(l, 1e-4);
    float R = 1.0 + (giantFbm(dir * 1.2 + h * 17.0, 3) - 0.5) * 0.7 + (giantNoise(dir * 5.0 + h * 5.0) - 0.5) * 0.1;
    float d = l - R;
    // The broken faces aren't perfectly flat: a little roughness across them.
    float rough = (giantNoise(q * 6.0 + h * 3.0) - 0.5) * 0.08;
    for (int j = 0; j < 4; j++) {
        d = max(d, dot(q, cuts[j].xyz) - cuts[j].w + rough);
    }
    return d * 0.55;
}

vec4 asteroidField(vec2 uv, float seed, float slot, float t, float fade) {
    vec2 flow = normalize(hash22(vec2(slot, seed + 121.0)) - 0.5);
    // Sun off to the side or a little behind, so the rocks show strong light and shadow.
    vec3 L = normalize(vec3(normalize(hash22(vec2(slot, seed + 123.0)) - 0.5), mix(-0.35, 0.45, hash12(vec2(slot, seed + 127.0)))));
    // Rock colours vary per field: brown (most common), grey, or reddish.
    float tone = hash12(vec2(slot, seed + 125.0));
    vec3 rockA = tone < 0.5 ? vec3(0.3, 0.27, 0.24) : tone < 0.75 ? vec3(0.3, 0.3, 0.31) : vec3(0.36, 0.24, 0.18);
    vec3 rockB = tone < 0.5 ? vec3(0.44, 0.38, 0.31) : tone < 0.75 ? vec3(0.46, 0.45, 0.46) : vec3(0.52, 0.36, 0.26);
    vec4 ov = vec4(0.0);
    for (int i = 0; i < 4; i++) {
        float depth = float(i) / 3.0; // 0 = far, 1 = near
        float cell = mix(0.045, 0.3, depth * depth);
        vec2 g = (uv + flow * mix(0.002, 0.02, depth) * t + float(i) * 13.7) / cell;
        vec2 id = floor(g);
        float h = hash12(id + seed + float(i) * 31.0);
        if (h > mix(0.32, 0.22, depth)) {
            continue;
        }
        vec2 h2 = hash22(id + seed + float(i) * 17.0);
        // Mostly small rocks with the odd big one, placed anywhere they fit in their cell.
        float rad = mix(0.1, 0.26, pow(h2.x, 1.5));
        float maxJitter = 0.5 - rad * 1.6;
        vec2 pos = 0.5 + (hash22(id + seed + float(i) * 23.0) - 0.5) * 2.0 * maxJitter;
        vec2 q = (fract(g) - pos) / rad;
        if (dot(q, q) > 2.6) {
            continue;
        }
        float rockPx = rad * cell * minDim();
        float px = 1.0 / rockPx;
        // Each rock its own shade: some darker carbon-rich ones among the rest.
        vec3 rockCol = mix(rockA, rockB, h2.y) * (hash12(id + seed + 8.0) < 0.25 ? 0.55 : 1.0);

        if (rockPx < 5.0) {
            // Too small to show its shape: a speck, as bright as the lit fraction it shows.
            float cover = smoothstep(0.9 + px, 0.9 - px * 2.0, length(q)) * 0.9;
            vec3 col = rockCol * max(0.15 + 0.6 * L.z, 0.05);
            ov = over(vec4(col * cover, cover), ov);
            continue;
        }

        // Tumbling about a random axis.
        vec3 ax = normalize(hash33(vec3(id, seed + float(i))) - 0.5);
        mat3 M = rockRot(ax, t * mix(0.03, 0.12, h2.y) + h * 40.0);
        vec3 squash = vec3(mix(1.0, 1.6, hash12(id + seed + 5.0)), 1.0, mix(0.7, 1.0, hash12(id + seed + 6.0)));
        float hs = h * 13.0 + float(i);
        mat4 cuts;
        for (int j = 0; j < 4; j++) {
            vec3 cn = normalize(hash33(vec3(id + float(j) * 7.1, hs)) - 0.5);
            cuts[j] = vec4(cn, mix(0.45, 0.8, hash12(id + float(j) * 3.3 + hs)));
        }

        // March in from the front along the view axis (the rock is small, so the view is flat).
        float zt = sqrt(max(2.6 - dot(q, q), 0.0));
        float dmin = 1e9;
        bool hit = false;
        for (int k = 0; k < 18; k++) {
            float dd = rockShape(M * vec3(q, zt), hs, squash, cuts);
            dmin = min(dmin, dd);
            if (dd < 0.004) {
                hit = true;
                break;
            }
            zt -= max(dd, 0.01);
            if (zt < -1.7) {
                break;
            }
        }
        float cover = hit ? 1.0 : smoothstep(px * 1.2, 0.0, dmin);
        if (cover <= 0.0) {
            continue;
        }
        vec3 p = vec3(q, zt);
        // Surface normal from the shape (tetrahedron of samples), in view space.
        const vec2 e = vec2(0.02, -0.02);
        vec3 n = normalize(e.xyy * rockShape(M * (p + e.xyy), hs, squash, cuts) + e.yyx * rockShape(M * (p + e.yyx), hs, squash, cuts)
                         + e.yxy * rockShape(M * (p + e.yxy), hs, squash, cuts) + e.xxx * rockShape(M * (p + e.xxx), hs, squash, cuts));
        // Craters tilt the surface; they live on the rock, so they turn with it.
        vec3 pb = M * p;
        vec4 crat = planetCraterLayer(pb * 0.6, 3.0, 0.8, hs, px * 0.6) + planetCraterLayer(pb * 0.6, 7.0, 0.8, hs + 3.0, px * 0.6)
                  + planetCraterLayer(pb * 0.6, 15.0, 0.9, hs + 6.0, px * 0.6) * 0.7;
        // Rubble and grit: bumps at two scales finer than the shape, tilting the normal; each
        // fades out once too small to see on this rock.
        vec3 bump = vec3(0.0);
        float bs = 6.0;
        for (int k = 0; k < 2; k++) {
            float keepB = smoothstep(1.5, 4.0, 1.0 / (bs * px));
            if (keepB > 0.0) {
                vec3 bp = pb * bs + hs * float(k + 1);
                float b0 = giantFbm(bp, 3);
                const float eb = 0.2;
                vec3 gb = vec3(giantFbm(bp + vec3(eb, 0.0, 0.0), 3), giantFbm(bp + vec3(0.0, eb, 0.0), 3),
                               giantFbm(bp + vec3(0.0, 0.0, eb), 3)) - b0;
                bump += gb / eb * keepB * (k == 0 ? 0.45 : 0.3);
            }
            bs *= 2.8;
        }
        n = normalize(n - ((crat.xyz * 0.35 + bump) * M));
        // Dusty regolith: patchy albedo, darker crater floors.
        float alb = (0.75 + 0.5 * giantFbm(pb * 2.5 + hs, 4)) * (0.85 + 0.3 * giantNoise(pb * 22.0 - hs));
        vec3 surf = rockCol * alb * (1.0 - crat.w);
        // Dusty, airless reflectance: mostly lunar-like, some Lambert for shape.
        float mu0 = max(dot(n, L), 0.0);
        float mu = max(n.z, 0.05);
        float refl = 0.5 * mu0 / (mu0 + mu) + 1.3 * mu0;
        vec3 col = surf * refl + surf * 0.006;
        // Far rocks a touch dimmer, so the depth reads.
        col *= mix(0.6, 1.0, depth);
        ov = over(vec4(col * cover, cover), ov);
    }
    // Fine dust close to the camera, streaming past quickly.
    ov.rgb += starLayer(uv + flow * 0.04 * t, 90.0, 0.12, 0.5, seed + 9.0, t, 1.0) * vec3(0.9, 0.85, 0.8);
    return ov * fade;
}
