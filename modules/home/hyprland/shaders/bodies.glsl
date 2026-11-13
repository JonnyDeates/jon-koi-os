// Star kinds: < 0.4 a yellow sun like ours, < 0.7 a red giant, otherwise a blue-white star.
const float STAR_GIANT = 0.4;
const float STAR_BLUE = 0.7;

// A star with boiling plasma, granulation, limb darkening, sunspots, prominences and a corona of
// heat streaming outward. Returns premultiplied colour/coverage for the disk; corona light goes
// to glowOut, and shimmer is how strongly the heat should ripple the sky behind it.
vec4 star(vec2 uv, vec2 center, float radius, float kind, float seed, float slot, float t, float fade,
          out vec3 glowOut, out float shimmer) {
    glowOut = vec3(0.0);
    shimmer = 0.0;
    bool giant = kind >= STAR_GIANT && kind < STAR_BLUE;
    bool blue = kind >= STAR_BLUE;

    vec3 coreCol = giant ? vec3(1.35, 0.48, 0.1) : blue ? vec3(0.9, 1.1, 1.55) : vec3(1.45, 1.0, 0.4);
    vec3 limbCol = giant ? vec3(0.9, 0.22, 0.05) : blue ? vec3(0.4, 0.6, 1.3) : vec3(1.0, 0.4, 0.08);
    vec3 coronaCol = giant ? vec3(1.0, 0.35, 0.1) : blue ? vec3(0.55, 0.75, 1.4) : vec3(1.0, 0.72, 0.38);
    vec3 promCol = blue ? vec3(0.8, 0.9, 1.5) : vec3(1.0, 0.35, 0.3);
    float limbDark = giant ? 0.62 : blue ? 0.4 : 0.6;
    float cellScale = giant ? 4.5 : blue ? 30.0 : 38.0; // giants have huge convection cells
    float plasmaScale = giant ? 2.0 : blue ? 2.5 : 3.0;

    vec2 d = (uv - center) / radius;
    float r = length(d);
    if (r > 4.0) {
        return vec4(0.0);
    }
    vec2 dir = d / max(r, 1e-4);
    float px = 1.5 / (radius * minDim());

    // The surface boils, so the edge isn't perfectly round.
    float edge = 1.0 + (noise(dir * 4.0 + t * 0.15) - 0.5) * 0.006;
    vec4 body = vec4(0.0);
    if (r < edge + px) {
        float z = sqrt(max(1.0 - r * r, 0.0));
        // Surface motion is in units of the star's radius, so on small stars it would crawl at a pixel
        // a second. Speed it up for smaller stars so it churns at a similar on-screen pace.
        float ts = t * clamp(0.22 / radius, 1.0, 5.0);
        float rot = ts * 0.01;
        vec3 sp = vec3(d.x * cos(rot) + z * sin(rot), d.y, -d.x * sin(rot) + z * cos(rot));

        // Supergranulation: a faint, slowly churning mottling across the whole disk.
        vec2 ps = sp.xy * plasmaScale + sp.z * 1.7;
        vec2 q = vec2(fbm(ps + vec2(0.0, ts * 0.06)), fbm(ps + vec2(5.2, 1.3) - ts * 0.06));
        float plasma = fbm(ps * 1.4 + q * 2.5 + vec2(sp.z * 2.0, ts * 0.09));
        // Granulation: bright convection cells with dark lanes between them. The grain boils: two
        // cell patterns cross-fade, each re-seeded while it's invisible, so cells keep fading out
        // and new ones forming. Cells foreshorten and blur out toward the limb, and fade when too
        // small to draw.
        // Warped, so the cells are irregular blobs rather than tidy polygons.
        vec3 gp = sp * cellScale + vec3(ts * 0.12, ts * 0.05, -ts * 0.08) + vec3(q - 0.5, q.x - q.y) * (giant ? 1.2 : 0.6);
        float phase = ts / 6.0;
        float wA = 0.5 + 0.5 * cos(phase * 3.14159);
        float wB = 1.0 - wA;
        float seedA = floor(phase * 0.5 + 0.5) * 17.0;
        float seedB = floor(phase * 0.5) * 17.0 + 9.0;
        vec2 vA = voronoi3(gp + seedA, ts * 2.5);
        vec2 vB = voronoi3(gp + seedB, ts * 2.5);
        float lane = giant ? 0.6 : 0.25;
        float gran = smoothstep(0.0, lane, vA.y - vA.x) * wA + smoothstep(0.0, lane, vB.y - vB.x) * wB;
        float granVis = smoothstep(4.0, 10.0, 1.0 / (cellScale * px)) * smoothstep(0.0, 0.5, z);
        float b = 1.0 + (giant ? 0.45 : 0.12) * (plasma - 0.5) + (giant ? 0.3 : 0.22) * (gran - 0.6) * granVis;
        // Faculae: bright, veined patches that show up near the limb.
        float fac = smoothstep(0.55, 0.75, fbm(sp.xz * 6.0 + sp.y * 5.0 + seed * 3.0));
        b += fac * 0.25 * (1.0 - z) * (blue ? 0.3 : 1.0);
        if (!blue && !giant) {
            // Sunspot groups: a few dark umbras, each in a lighter penumbra streaked with radial
            // filaments, riding round with the star. Giants show huge convection cells instead.
            for (int k = 0; k < 6; k++) {
                float fk = float(k);
                float grp = floor(fk / 2.0);
                float hk = hash12(vec2(grp + slot * 3.0, seed + 91.0));
                if (hk > (giant ? 0.5 : 0.75)) {
                    continue;
                }
                float lat = (hash12(vec2(grp, seed + 93.0)) - 0.5) * 1.0;
                float lon = hash12(vec2(grp, seed + 95.0)) * 6.2831 + (fk - grp * 2.0) * mix(0.08, 0.16, hk);
                lat += (fk - grp * 2.0) * 0.03;
                vec3 c = vec3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon));
                vec3 rel = sp - c;
                float dd = length(rel);
                float ru = mix(0.02, 0.045, hash12(vec2(fk, seed + 97.0))) * (giant ? 2.0 : 1.0) * (fk - grp * 2.0 > 0.5 ? 0.6 : 1.0);
                if (dot(sp, c) < 0.0 || dd > ru * 3.0) {
                    continue;
                }
                vec3 e1 = normalize(cross(c, vec3(0.0, 1.0, 0.0)));
                float ang = atan(dot(rel, cross(c, e1)), dot(rel, e1));
                float fib = 0.75 + 0.25 * noise(vec2(ang * 9.0, fk * 7.0));
                float rp = ru * (2.1 + 0.3 * (noise(vec2(ang * 3.0, fk)) - 0.5));
                b *= mix(1.0, 0.55 * fib, smoothstep(rp, rp * 0.85, dd));
                b *= mix(1.0, 0.25, smoothstep(ru, ru * 0.7, dd));
            }
        }

        // Limb darkening: the edge is dimmer and redder because we see cooler, higher layers there.
        float limb = 1.0 - limbDark * (1.0 - z) - 0.12 * (1.0 - z) * (1.0 - z);
        vec3 col = mix(limbCol, coreCol, smoothstep(0.0, 0.8, z)) * b * max(limb, 0.32);
        float cover = smoothstep(edge + px, edge - px, r);
        body = vec4(col * cover, cover);
    }

    if (r > 0.98) {
        float h = max(r - 1.0, 0.0);
        // Streamers: tongues of hot gas reaching straight out, slowly changing shape...
        float streamer = fbm(dir * 6.0 + vec2(t * 0.02, -t * 0.015) + seed);
        float fine = fbm(dir * 18.0 + vec2(-t * 0.03, t * 0.02) + seed * 2.0);
        float reach = 0.04 + 0.32 * streamer * streamer + 0.06 * fine;
        // ...with waves of heat rippling outward through them.
        float waves = 0.75 + 0.25 * noise(vec2(h * 18.0 - t * 1.4, dot(dir, vec2(3.1, 1.7)) * 3.0));
        float tongues = exp(-h / reach) * waves;
        // Kept no brighter at the edge than the darkened limb itself, so the disk doesn't look outlined.
        float corona = exp(-h / 0.03) * 0.12 + exp(-h / 0.4) * 0.2 + exp(-h / 1.5) * 0.07;
        vec3 g = coronaCol * (corona + tongues * 0.45);

        // Prominences: glowing arcs of plasma looping off the edge.
        for (int k = 0; k < 3; k++) {
            float hk = hash12(vec2(slot * 5.0 + float(k), seed + 81.0));
            if (hk > (giant ? 0.85 : 0.65)) {
                continue;
            }
            float ang = hk * 40.0 + float(k) * 2.1 + t * 0.003;
            vec2 at = vec2(cos(ang), sin(ang));
            vec2 tng = vec2(-at.y, at.x);
            vec2 q = vec2(dot(d - at, tng), dot(d - at, at));
            // Wobble the arc so it's an irregular plume rather than a perfect ring.
            q += (vec2(noise(q * 8.0 + t * 0.1), noise(q * 8.0 + 5.0 - t * 0.1)) - 0.5) * 0.05;
            float loopR = mix(0.08, 0.2, hash12(vec2(hk, 3.0))) * (0.9 + 0.1 * sin(t * 0.2 + hk * 9.0));
            float dist = abs(length(q * vec2(1.0, 0.8)) - loopR);
            float wisp = 0.4 + 0.6 * fbm(q * 14.0 + vec2(0.0, -t * 0.3));
            float width = 0.012 + 0.022 * wisp;
            float topFade = 1.0 - 0.55 * clamp(q.y / loopR, 0.0, 1.0); // brightest near the footpoints
            // No straight cut at the base: the star's disk itself hides the part of the loop behind it.
            g += promCol * exp(-dist / width) * wisp * wisp * topFade * 1.3;
        }
        glowOut = g * smoothstep(1.0 - px, 1.0 + px, r) * fade;
        shimmer = exp(-h * 2.5) * fade;
    }
    return body * fade;
}

// A small planet lit by a star in direction toStar (view space, z toward the camera), with a thin
// atmosphere. Premultiplied colour/coverage; the atmosphere glow is folded into .rgb.
vec4 miniPlanet(vec2 uv, vec2 c, float rad, vec3 toStar, float t, float pseed, bool gas) {
    vec2 d = (uv - c) / rad;
    float r2 = dot(d, d);
    if (r2 > 2.5) {
        return vec4(0.0);
    }
    float r = sqrt(r2);
    float px = 1.5 / (rad * minDim());
    vec3 L = normalize(toStar);
    float hueA = hash12(vec2(pseed, 2.0));
    vec3 palA = planetHue(hueA);
    vec3 palB = planetHue(fract(hueA + mix(0.12, 0.45, hash12(vec2(pseed, 3.0)))));
    if (!gas) {
        palB = mix(vec3(0.15, 0.35, 0.7), palB, 0.35); // oceans stay mostly blue
    }
    vec3 sky = gas ? mix(palA, vec3(1.0, 0.9, 0.8), 0.45) : mix(vec3(0.35, 0.62, 1.0), TEAL, 0.3);

    vec4 body = vec4(0.0);
    if (r < 1.0 + px) {
        float z = sqrt(max(1.0 - r2, 0.0));
        vec3 n = vec3(d, z);
        float lon = atan(n.x, n.z) + t * 0.1;
        float lat = asin(clamp(n.y, -1.0, 1.0));
        vec3 surf;
        if (gas) {
            float bands = fbm(vec2(lat * 6.0 + fbm(vec2(lon, lat * 6.0)) * 0.8, lon * 0.4) + pseed);
            surf = mix(palA * 0.85, mix(palA, palB, 0.45), smoothstep(0.35, 0.65, bands));
        } else {
            float land = fbm(vec2(lon, lat) * 2.0 + pseed);
            surf = mix(palB * 0.5, palA * 0.8, smoothstep(0.45, 0.55, land));
        }
        float sunDot = dot(n, L);
        vec3 col = surf * (0.015 + clamp((sunDot + 0.05) / 1.05, 0.0, 1.0));
        float haze = 1.0 - exp(-0.06 / max(z, 0.04) * 6.0);
        col = mix(col, sky * 0.8 * smoothstep(-0.25, 0.3, sunDot), haze * 0.6);
        float cover = smoothstep(1.0 + px, 1.0 - px, r);
        body = vec4(col * cover, cover);
    }
    if (r > 1.0 - px) {
        float limbSun = dot(vec3(d / r, 0.0), L);
        float density = exp(-max(r - 1.0, 0.0) / 0.04);
        float forward = pow(max(-L.z, 0.0), 1.2) * smoothstep(-1.0, 0.2, limbSun) * 2.0;
        body.rgb += sky * density * (smoothstep(-0.35, 0.5, limbSun) + forward) * 0.6
                * smoothstep(1.0 - px, 1.0 + px, r);
    }
    return body;
}

const vec3 DISK_DUST = vec3(0.22, 0.08, 0.03);
const vec3 DISK_AMBER = vec3(0.95, 0.56, 0.30);
const vec3 DISK_WHITE = vec3(1.0, 0.95, 0.88);

// One rotation phase of the disk texture. fpRho/fpDir are pixel footprints in rho and direction
// units, used to drop detail that's too fine to display.
float diskLayer(float rho, vec2 dirp, float angle, float seed, float fpRho, float fpDir) {
    vec2 p = rotate(angle) * dirp;
    float warp = fbmAA(p * 1.2 + vec2(rho * 0.8) + seed, 1.2 * fpDir + 0.8 * fpRho);
    float streak = fbmAA(vec2(rho * 5.0 + warp * 4.0, seed) + p * 1.6, 5.0 * fpRho + 1.6 * fpDir);
    // Each streak is only a partial arc: break the bands up along the orbit so they read as
    // sheared clumps of gas rather than grooves.
    float arcs = fbmAA(p * 4.5 + vec2(rho * 3.0 + warp * 3.0, seed * 2.0), 4.5 * fpDir + 3.0 * fpRho);
    streak = mix(0.5, streak, smoothstep(0.3, 0.65, arcs));
    float clump = fbmAA(p * 2.5 + vec2(rho * 1.5 + warp * 2.0), 2.5 * fpDir + 1.5 * fpRho);
    // Fine turbulence riding on top.
    float fine = fbmAA(p * 9.0 + vec2(rho * 6.0 + warp * 5.0), 9.0 * fpDir + 6.0 * fpRho);
    return streak * 0.28 + clump * 0.75 + (fine - 0.5) * 0.3;
}

// Accretion disk material at radius rho (units of R) along in-plane direction dirp: turbulent,
// streaky gas that is white-hot inward, amber further out, with dark dusty lanes.
// Returns premultiplied emission in .rgb and opacity in .a.
// spin is the signed angular speed at rho = 1; outerR is where the disk fades out; dustC, midC and
// hotC are its colours from the dusty outskirts to the white-hot inner gas.
vec4 diskSample(float rho, vec2 dirp, float t, float spin, float seed, float fpRho, float fpDir,
                float outerR, vec3 dustC, vec3 midC, vec3 hotC) {
    // Ragged outer edge so the disk trails off instead of ending in a clean ellipse.
    float edge = noise(dirp * 2.5 + vec2(rho * 0.35, seed));
    float radial = smoothstep(0.6, 0.85, rho) * smoothstep(outerR, outerR * 0.32, rho + (edge - 0.5) * 4.0);
    if (radial <= 0.0) {
        return vec4(0.0);
    }
    // Inner gas orbits faster. Two copies of the swirl are cross-faded, each restarting while it's
    // invisible, so the shear never winds the texture up into noise however long it runs.
    const float FLOW_PERIOD = 16.0;
    float phA = fract(t / FLOW_PERIOD);
    float phB = fract(phA + 0.5);
    float wA = 1.0 - abs(2.0 * phA - 1.0);
    float wB = 1.0 - wA;
    float omega = spin / pow(rho, 1.5);
    float shear = 1.5 * abs(omega) / rho * FLOW_PERIOD * fpRho;
    float nA = diskLayer(rho, dirp, omega * phA * FLOW_PERIOD, seed, fpRho, fpDir + shear * phA);
    float nB = diskLayer(rho, dirp, omega * phB * FLOW_PERIOD, seed + 19.0, fpRho, fpDir + shear * phB);
    // Renormalise so contrast stays constant through the cross-fade.
    const float mean = 0.55;
    float n = mean + ((nA - mean) * wA + (nB - mean) * wB) / sqrt(wA * wA + wB * wB);

    // The innermost gas is always dense and hot, giving an even bright rim around the hole.
    float dens = max(smoothstep(0.12, 0.95, n), smoothstep(1.4, 0.7, rho) * 0.75);
    float heat = clamp(2.4 / rho, 0.0, 1.0);
    float b = dens * (0.35 + 0.9 * heat);
    vec3 c = mix(dustC, midC, smoothstep(0.08, 0.45, b));
    c = mix(c, hotC, smoothstep(0.45, 0.85, b));
    float a = radial * clamp(0.65 + dens * 0.5, 0.0, 1.0);
    return vec4(c * (0.2 + b * 1.5) * a, a);
}

// Shooting stars, shared by the lone meteor (meteors.glsl) and the meteor shower: a bright head
// with a fading, glowing trail and a slight tint; fireballs flare and break apart, and a lingering
// one leaves a persistent train that hangs in the sky and slowly fades. Additive light.
// One meteor travelling from p0 along dir; age runs 0 -> 1 while the head crosses, then up to
// 1 + linger while a persistent train fades.
vec3 meteorLight(vec2 uv, vec2 p0, vec2 dir, float len, float age, float linger, float bright, vec3 tint,
                 bool fireball, float hm) {
    float after = max(age - 1.0, 0.0) / max(linger, 1e-4);  // 0..1 through the train's fade
    age = min(age, 1.0);
    vec2 head = p0 + dir * len * age;
    vec2 rel = uv - head;
    float along = -dot(rel, dir);                 // > 0 behind the head
    float across = dot(rel, vec2(-dir.y, dir.x));
    float ps = pxScale() / minDim();
    float trailLen = len * 0.6 * min(age * 2.5, 1.0);
    // Brightness swells then fades over its life; fireballs flare near the end.
    float life = smoothstep(0.0, 0.15, age) * smoothstep(1.0, 0.6, age);
    if (fireball) {
        life *= 1.0 + 2.5 * exp(-pow((age - 0.7) / 0.08, 2.0));
    }
    float w = ps * (fireball ? 3.0 : 1.8);
    float spread = 1.0 + max(along, 0.0) / max(trailLen, 1e-4) * 3.0; // trail widens behind the head
    float trail = exp(-across * across / (w * w * spread))
            * exp(-max(along, 0.0) / max(trailLen, 1e-4) * 1.8) * step(0.0, along + w);
    float headGlow = exp(-dot(rel, rel) / (w * w * 4.0)) * 1.5 + exp(-length(rel) / (w * 8.0)) * 0.3;
    vec3 col = (mix(tint, vec3(1.0), 0.4) * trail * 1.6 + vec3(1.0) * headGlow) * life * bright;
    if (linger > 0.0 && after > 0.0) {
        // Persistent train: the glowing path stays, spreading out and fading with a little drift.
        float behind = clamp(dot(uv - p0, dir) / len, 0.0, 1.0);
        float trAcross = dot(uv - p0, vec2(-dir.y, dir.x)) + (noise(vec2(behind * 8.0, hm * 9.0)) - 0.5) * 0.01 * after;
        float tw = w * (1.5 + 10.0 * after);
        // Tapers off at both ends instead of stopping at a hard line.
        float s = dot(uv - p0, dir) / len;
        float train = exp(-trAcross * trAcross / (tw * tw)) * smoothstep(0.0, 0.3, s) * smoothstep(1.05, 0.8, s)
                * (1.0 - after) * (1.0 - after) / (1.0 + 4.0 * after);
        col += mix(tint, vec3(0.7, 1.0, 0.8), 0.5) * train * 0.7 * bright;
    }
    if (fireball && age > 0.7) {
        // Fragments peeling off behind the head after it breaks up.
        for (int i = 0; i < 4; i++) {
            float hi = hash12(vec2(hm, float(i)));
            vec2 off = dir * (-0.01 - hi * 0.03) * (age - 0.7) / 0.3 + vec2(-dir.y, dir.x) * (hi - 0.5) * 0.02 * (age - 0.7) / 0.3;
            float fd = length(uv - head - off);
            col += tint * exp(-fd * fd / (w * w * 2.0)) * smoothstep(1.0, 0.75, age) * bright * 0.8;
        }
    }
    return col;
}

// A meteor's colour: green (magnesium) most often, then blue-white, sometimes orange (sodium).
vec3 meteorTint(float pick) {
    return pick < 0.5 ? vec3(0.75, 1.0, 0.8) : pick < 0.8 ? vec3(0.9, 0.92, 1.0) : vec3(1.0, 0.75, 0.45);
}
