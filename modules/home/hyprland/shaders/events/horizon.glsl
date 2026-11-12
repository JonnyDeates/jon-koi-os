// A planet seen from low orbit, like ISS photos: we look out toward a wide, gently curved horizon
// across the screen. Every pixel is traced as a ray from a camera just above a curved planet, so
// the ground recedes with real perspective (clouds big and detailed near the bottom, squashed into
// streaks toward the horizon), distant ground fades into pale-blue haze, and the atmosphere above
// the horizon is a soft band - white at the surface deepening to blue, orange at sunrise/sunset.
// The sun is anywhere: in view with glare, ahead with a glint path on the ocean, behind or to the
// side, or below the horizon at dusk with city lights. Premultiplied colour/coverage.
float hazeLitG(float mu) {
    return smoothstep(-0.1, 0.2, mu);
}

// Billowy noise: broad rounded bulges with sharp creases between them, like cumulus tops.
float billow(vec2 p, float fp) {
    const mat2 rot = mat2(0.8, -0.6, 0.6, 0.8);
    float v = 0.0;
    float a = 0.5;
    float f = 1.0;
    for (int i = 0; i < 5; i++) {
        float keep = clamp(1.5 - fp * f * 3.0, 0.0, 1.0);
        v += a * mix(0.5, sqrt(abs(2.0 * noise(p) - 1.0)), keep);
        p = rot * p * 2.0 + 13.0;
        a *= 0.5;
        f *= 2.0;
    }
    return v;
}

// Height of the puffy cloud kinds (cumulus, streets, stratus), blended by region weights w.
// Evaluated twice - here and nudged toward the sun - to shade the slopes of each puff.
float hzPuffs(vec2 cq, vec2 cqw, vec2 cw, float systems, float fp, vec3 w) {
    float fCum = fbmAA(cq * 0.5 + cw, fp * 0.5) * 0.62 + billow(cq * 3.0 + cw * 2.0, fp * 3.0) * 0.28
               + billow(cq * 14.0 + cw * 3.0, fp * 14.0) * 0.14 + (systems - 0.5) * 0.35;
    float rowPhase = cqw.y * 22.0 + fbmAA(cqw * 0.6, fp * 0.6) * 6.0;
    float rows = (0.5 + 0.5 * sin(rowPhase)) * clamp(1.5 - fp * 22.0 * 3.0, 0.0, 1.0);
    float fStreet = billow(cqw * vec2(9.0, 14.0) + 3.0, fp * 14.0) * 0.62 + rows * 0.16
                  + fbmAA(cq * 0.6 + cw, fp * 0.6) * 0.25 + (systems - 0.5) * 0.3;
    float fStrat = fbmAA(cq * 0.35 + cw * 0.5, fp * 0.35) * 0.75 + (1.0 - abs(2.0 * noise(cq * 6.0) - 1.0)) * 0.08
                 + (systems - 0.5) * 0.25 + 0.12;
    return dot(vec3(fCum, fStreet, fStrat), w) / max(w.x + w.y + w.z, 1e-3);
}

vec4 planetHorizon(vec2 uv, float seed, float slot, float t, float fade) {
    const float RP = 1.0;   // planet radius
    const float H = 0.007;  // atmosphere scale height
    float h = mix(0.035, 0.07, hash12(vec2(slot, seed + 431.0)));      // camera altitude
    float roll = (hash12(vec2(slot, seed + 433.0)) - 0.5) * 0.25;
    float horizonY = mix(0.02, 0.22, hash12(vec2(slot, seed + 435.0))); // where the horizon sits on screen
    float dip = acos(RP / (RP + h));
    float camEl = -dip - atan(horizonY);
    vec3 fwd = vec3(0.0, sin(camEl), cos(camEl));
    vec3 right = vec3(1.0, 0.0, 0.0);
    vec3 upC = vec3(0.0, cos(camEl), -sin(camEl));
    vec2 q2 = rotate(roll) * uv;
    vec3 rd = normalize(fwd + right * q2.x + upC * q2.y);
    vec3 C = vec3(0.0, RP + h, 0.0);

    // Sun: any direction, from below the horizon (dusk) to high in the sky.
    float az = hash12(vec2(slot, seed + 437.0)) * 6.2831;
    float e = mix(-0.22, 0.8, hash12(vec2(slot, seed + 439.0)));
    vec3 S = normalize(vec3(sin(az) * cos(e), sin(e), cos(az) * cos(e)));
    // Each world gets its own air, seas and soil. Earth-like is the most common; the others are
    // a dusty rust world (butterscotch sky, blue sunsets, pinkish clouds, like Mars), a green-aired world with emerald
    // seas and purple plant life, a violet-hazed world with wine-dark seas, an icy world under pale
    // cyan air, and a smoggy amber world with black hydrocarbon lakes (like Titan).
    vec3 SKYBLUE = vec3(0.25, 0.5, 1.0);          // upper atmosphere
    vec3 HAZE = vec3(0.75, 0.85, 1.0);            // thick air near the surface
    vec3 SUNSET = vec3(1.0, 0.5, 0.22);           // light through the most air
    vec3 seaDeep = vec3(0.015, 0.05, 0.14), seaShelf = vec3(0.03, 0.13, 0.17);
    vec3 land1 = vec3(0.05, 0.085, 0.035), land2 = vec3(0.13, 0.12, 0.07), land3 = vec3(0.3, 0.24, 0.15);
    vec3 CLOUD = vec3(0.97, 0.98, 1.0);           // what the clouds are made of: white water droplets
    float seaLevel = 0.7;                         // higher = less ocean
    float world = hash12(vec2(slot, seed + 461.0));
    if (world < 0.45) {                           // Earth-like: keep the defaults
    } else if (world < 0.56) {                    // rust
        SKYBLUE = vec3(0.8, 0.55, 0.35); HAZE = vec3(1.0, 0.82, 0.62); SUNSET = vec3(0.35, 0.55, 1.0);
        seaDeep = vec3(0.04, 0.06, 0.07); seaShelf = vec3(0.1, 0.11, 0.09);
        land1 = vec3(0.16, 0.06, 0.03); land2 = vec3(0.3, 0.13, 0.06); land3 = vec3(0.42, 0.25, 0.14);
        seaLevel = 0.58;
        CLOUD = vec3(1.0, 0.86, 0.76);            // ice clouds stained by the dust in the air
    } else if (world < 0.65) {                    // green air, emerald seas, purple life
        SKYBLUE = vec3(0.25, 0.85, 0.55); HAZE = vec3(0.75, 1.0, 0.82); SUNSET = vec3(1.0, 0.75, 0.25);
        seaDeep = vec3(0.01, 0.08, 0.06); seaShelf = vec3(0.05, 0.2, 0.12);
        land1 = vec3(0.09, 0.03, 0.09); land2 = vec3(0.16, 0.08, 0.13); land3 = vec3(0.24, 0.2, 0.14);
        CLOUD = vec3(0.86, 1.0, 0.9);             // a faint green cast from the air
    } else if (world < 0.74) {                    // violet haze, wine-dark seas, ochre ground
        SKYBLUE = vec3(0.55, 0.35, 1.0); HAZE = vec3(0.88, 0.78, 1.0); SUNSET = vec3(1.0, 0.35, 0.45);
        seaDeep = vec3(0.06, 0.015, 0.06); seaShelf = vec3(0.14, 0.05, 0.12);
        land1 = vec3(0.14, 0.1, 0.04); land2 = vec3(0.24, 0.17, 0.07); land3 = vec3(0.32, 0.27, 0.18);
        CLOUD = vec3(0.95, 0.86, 1.0);            // lavender-pink
    } else if (world < 0.84) {                    // ice: dark open water between white land and sea ice
        SKYBLUE = vec3(0.4, 0.75, 1.0); HAZE = vec3(0.85, 0.95, 1.0); SUNSET = vec3(1.0, 0.65, 0.5);
        seaDeep = vec3(0.01, 0.03, 0.07); seaShelf = vec3(0.12, 0.2, 0.26);
        land1 = vec3(0.35, 0.4, 0.45); land2 = vec3(0.55, 0.6, 0.66); land3 = vec3(0.7, 0.74, 0.8);
        seaLevel = 0.64;
        CLOUD = vec3(0.9, 0.97, 1.0);             // crisp ice crystals, bluish white
    } else if (world < 0.92) {                    // amber smog, black lakes, brown dunes
        SKYBLUE = vec3(0.85, 0.6, 0.2); HAZE = vec3(1.0, 0.85, 0.5); SUNSET = vec3(1.0, 0.4, 0.1);
        seaDeep = vec3(0.012, 0.01, 0.008); seaShelf = vec3(0.05, 0.035, 0.02);
        land1 = vec3(0.12, 0.07, 0.03); land2 = vec3(0.2, 0.12, 0.05); land3 = vec3(0.3, 0.2, 0.1);
        seaLevel = 0.74;
        CLOUD = vec3(1.0, 0.82, 0.5);             // methane clouds seen through orange smog
    }
    vec3 AMB = normalize(mix(SKYBLUE, HAZE, 0.4)) * 1.2;  // tint of skylight on the ground
    vec3 sunC = mix(SUNSET, vec3(1.0, 0.97, 0.92), smoothstep(-0.02, 0.15, e));

    float b = dot(C, rd);
    float c = dot(C, C) - RP * RP;
    float disc = b * b - c;
    // Signed closest-approach altitude of the ray (negative = it hits the planet).
    float ac = b < 0.0 ? sqrt(max(dot(C, C) - b * b, 0.0)) - RP : h;
    float pa = 1.0 / minDim();
    float aaW = sqrt(2.0 * h) * pa * 1.5;
    float cover = b < 0.0 ? smoothstep(aaW, -aaW, ac) : 0.0;

    vec3 col = vec3(0.0);
    if (cover > 0.0) {
        float tt = -b - sqrt(max(disc, 0.0));
        vec3 P = C + rd * tt;
        vec3 N = normalize(P);
        float cosV = max(dot(-rd, N), 0.02);
        // We're in orbit: the whole planet slides slowly underneath us, along a heading that's
        // mostly straight ahead.
        float head = (hash12(vec2(slot, seed + 463.0)) - 0.5) * 1.2;
        vec2 orb = vec2(sin(head), -cos(head)) * t * 0.0018;
        vec2 q = (P.xz - orb) * 70.0 + seed;
        float fp = tt * pa / cosV * 70.0;                       // pixel footprint in q units
        float mu = dot(N, S);

        // Ground. Coastlines are warped so they wander into bays, peninsulas and island chains.
        vec2 cwp = vec2(fbmAA(q * 0.08 + 3.1, fp * 0.08), fbmAA(q * 0.08 - 5.7, fp * 0.08)) - 0.5;
        float cont = fbmAA(q * 0.15 + cwp * 1.8, fp * 0.15) + 0.3 * fbmAA(q * 0.6 + cwp, fp * 0.6) + 0.06 * fbmAA(q * 2.5, fp * 2.5);
        float isLand = smoothstep(seaLevel - 0.004, seaLevel + 0.008, cont);
        float inland = smoothstep(seaLevel, seaLevel + 0.15, cont);
        // Ocean: darkest far out, lighter over the shelves near the coast with the sea floor
        // showing through, and faint swirls of plankton in the currents.
        float shelf = smoothstep(seaLevel - 0.09, seaLevel - 0.005, cont) * (1.0 - isLand);
        float tex = fbmAA(q * 1.5, fp * 1.5);
        vec3 ocean = mix(seaDeep * mix(0.7, 1.0, smoothstep(seaLevel - 0.35, seaLevel - 0.1, cont)), seaShelf * (0.8 + 0.4 * tex), shelf * shelf);
        float swirl = smoothstep(0.55, 0.75, fbmAA(q * 1.2 + cwp * 6.0, fp * 1.2));
        ocean += seaShelf * swirl * 0.25 * (1.0 - shelf);

        // Mountain ranges: ridged noise, rising inland, which also gives the land its relief.
        const float eR = 0.15;
        float rA = 1.0 - abs(2.0 * fbmAA(q * 1.3 + cwp * 2.0, fp * 1.3) - 1.0);
        float rX = 1.0 - abs(2.0 * fbmAA((q + vec2(eR, 0.0)) * 1.3 + cwp * 2.0, fp * 1.3) - 1.0);
        float rY = 1.0 - abs(2.0 * fbmAA((q + vec2(0.0, eR)) * 1.3 + cwp * 2.0, fp * 1.3) - 1.0);
        // Sharpened so the ranges are narrow ridgelines rather than broad swells.
        float pA = pow(rA, 5.0);
        float mtn = pA * inland;
        vec2 grad = vec2(pow(rX, 5.0) - pA, pow(rY, 5.0) - pA) / eR * inland;
        // Land: forest and grassland where it's wet, desert where it's dry, bare rock on the
        // ranges, snow on the highest peaks.
        float dry = fbmAA(q * 0.4 + 7.0, fp * 0.4) * 0.7 + fbmAA(q * 1.6 - 3.0, fp * 1.6) * 0.3;
        vec3 landC = mix(land1, land2, smoothstep(0.42, 0.58, dry));
        landC = mix(landC, land3, smoothstep(0.55, 0.68, dry));
        landC *= 0.7 + 0.6 * tex;
        // Fine texture - fields, gullies, rock - at two smaller scales, where it can be seen.
        float fine = fbmAA(q * 6.0 + cwp * 4.0, fp * 6.0) * 0.6 + fbmAA(q * 20.0, fp * 20.0) * 0.4;
        landC *= 0.75 + 0.5 * fine;
        landC = mix(landC, mix(land2, land3, 0.4) * 0.85, smoothstep(0.1, 0.4, mtn));
        // Snow only where there's water to make it (Earth-like and icy worlds).
        float snow = smoothstep(0.45, 0.7, mtn) * (world < 0.45 || (world >= 0.74 && world < 0.84) ? 1.0 : 0.0);
        landC = mix(landC, vec3(0.75, 0.78, 0.8), snow);
        vec3 ground = mix(ocean, landC, isLand);
        // Relief: the slope of the ranges tilts the ground toward or away from the sun.
        vec3 Tx = normalize(vec3(1.0, 0.0, 0.0) - N * N.x);
        vec3 Tz = normalize(vec3(0.0, 0.0, 1.0) - N * N.z);
        float reliefKeep = clamp(1.0 - fp * 2.0, 0.0, 1.0) * isLand;
        vec3 Nl = normalize(N - (Tx * grad.x + Tz * grad.y) * 1.2 * reliefKeep);

        // Clouds: several kinds mixed by region - puffy cumulus, cloud streets lined up with the wind,
        // thin wispy cirrus stretched along it, and smooth stratus decks - bunched into weather
        // systems with open ocean between, shaded toward the sun and casting shadows.
        vec2 sh = normalize(S.xz + 1e-4);
        const float HC = 0.0012;                                  // cloud-deck altitude
        float rc = RP + HC;
        float tc = -b - sqrt(max(b * b - (dot(C, C) - rc * rc), 0.0));
        vec3 Pc = C + rd * tc;
        // Clouds ride along with the ground, blown a little further by the wind, and slowly
        // change shape as they go.
        float windA = hash12(vec2(slot, seed + 453.0)) * 6.2831;
        vec2 windV = vec2(cos(windA), sin(windA)) * mix(0.015, 0.035, hash12(vec2(slot, seed + 465.0)));
        vec2 cq = ((Pc.xz - orb) * 70.0 + seed) * 0.5 - windV * t;
        fp *= 0.5;                                                // footprint in cloud units
        mat2 toWind = rotate(-windA);
        vec2 cqw = toWind * cq;
        float fpw = fp;
        vec2 cw = vec2(fbmAA(cq * 0.3 + vec2(t * 0.008, 0.0), fp * 0.27), fbmAA(cq * 0.3 + vec2(5.0, t * 0.008), fp * 0.27)) * 1.6;
        float systems = fbmAA(cq * 0.12 + seed * 0.37, fp * 0.12);
        // Which kind dominates where: two slow fields carve the planet into regions.
        float tA = fbmAA(cq * 0.18 + seed * 0.71, fp * 0.18);
        float tB = fbmAA(cq * 0.18 - seed * 0.53 + 9.0, fp * 0.18);
        float wCum = smoothstep(0.45, 0.6, tA) * (1.0 - smoothstep(0.55, 0.68, tB));
        float wStreet = (1.0 - smoothstep(0.4, 0.55, tA)) * (1.0 - smoothstep(0.55, 0.68, tB));
        float wStrat = smoothstep(0.55, 0.68, tB) * smoothstep(0.45, 0.6, tA);
        float wCirrus = smoothstep(0.55, 0.68, tB) * (1.0 - smoothstep(0.45, 0.6, tA));
        // Each planet has its own amount of cloud, mostly on the clearer side.
        float coverT = mix(0.5, 0.66, pow(hash12(vec2(slot, seed + 451.0)), 0.6));
        float edgeW = 0.015 + fp * 0.6;

        vec3 wP = vec3(wCum, wStreet, wStrat);
        float fPuff = hzPuffs(cq, cqw, cw, systems, fp, wP);
        // Cirrus: thin wisps stretched along the wind, very fine across it, in wispy bundles.
        vec2 cr = cqw + vec2(0.0, fbmAA(cqw * vec2(0.3, 0.6), fpw * 0.6) * 1.5);
        float fibres = 1.0 - abs(2.0 * fbmAA(cr * vec2(0.8, 30.0), fpw * 30.0) - 1.0);
        float fCirrus = fbmAA(cr * vec2(0.4, 2.0) + cw * 0.3, fpw * 2.0) * 0.7 + pow(fibres, 3.0) * 0.35;

        float wPuff = min(wCum + wStreet + wStrat, 1.0);
        float puffEdge = coverT + (wStrat / max(wPuff, 1e-3)) * 0.04;
        float dPuff = smoothstep(puffEdge - edgeW, puffEdge + edgeW * 1.5, fPuff) * wPuff;
        float dCirrus = smoothstep(0.6, 0.9, fCirrus) * 0.3 * wCirrus;     // thin and see-through
        float dens = max(dPuff, dCirrus);
        // How high the cloud piles up above its edge: tall middles, low fringes.
        float height = smoothstep(puffEdge, puffEdge + 0.18, fPuff) * wPuff;

        // Slope toward the sun, from the height nudged a little that way: sunward faces of puffs
        // light up, the far sides fall into shade.
        const float EPS = 0.03;
        vec2 shw = toWind * sh;
        float slope = 0.0;
        if (dPuff > 0.001) {                                      // only where there's cloud to shade
            float fPuffS = hzPuffs(cq + sh * EPS, cqw + shw * EPS, cw, systems, fp, wP);
            slope = (fPuff - fPuffS) / EPS;
        }
        float relief = clamp(slope * 0.35, -1.0, 1.0) * wPuff * clamp(1.0 - fp * 20.0, 0.0, 1.0);
        // Shadows on the ground follow the larger shapes of the clouds that cast them.
        vec3 Ps = P + S * (HC / max(mu, 0.06));
        vec2 cd = ((Ps.xz - orb) * 70.0 + seed) * 0.5 - windV * t;
        float shadowField = fbmAA(cd * 0.5 + cw, fp * 0.5) * 0.62 + billow(cd * 3.0 + cw * 2.0, fp * 3.0) * 0.28 + 0.1
                          + (fbmAA(cd * 0.12 + seed * 0.37, fp * 0.12) - 0.5) * 0.35;
        float densShadow = smoothstep(coverT - 0.02, coverT + 0.05, shadowField) * (wCum + wStreet + wStrat * 0.6);
        fp *= 2.0;
        ground *= 1.0 - 0.45 * clamp(densShadow, 0.0, 1.0) * smoothstep(0.0, 0.3, mu);

        float day = smoothstep(-0.08, 0.12, mu);
        float sunVisG = smoothstep(-0.01, 0.03, mu);
        float lit = max(mu, 0.0);
        // Land lit by its own slope, so ranges show a sunny side and a shadowed one.
        // Skylight keeps the shaded side from going black.
        float litL = max(dot(Nl, S) * 0.75 + mu * 0.25, 0.0) * smoothstep(-0.02, 0.05, mu);
        lit = mix(lit, litL, isLand);
        // Direct sun (warm only right at sunrise/sunset) plus cool ambient light from the sky.
        vec3 lightC = mix(mix(SUNSET, vec3(1.0), 0.35), vec3(1.0, 0.97, 0.92), smoothstep(-0.02, 0.1, mu));
        vec3 amb = AMB * (0.012 + 0.09 * hazeLitG(mu));
        vec3 surf = ground * (amb + 1.5 * lit * lightC);
        // Clouds lit on the sun-facing side, darker where thicker cloud lies toward the sun.
        // Thicker cloud is brighter; thin edges let the dark ocean show through a little.
        // Light wraps around cloud volumes; puff faces toward the sun are brighter, far sides and
        // the crevices between puffs darker.
        float wrap = clamp((mu + 0.3) / 0.9, 0.0, 1.0);
        // Slopes matter most when the sun is low; overhead sun lights every face.
        float faceSun = clamp(wrap + relief * mix(0.9, 0.35, clamp(mu, 0.0, 1.0)), 0.05, 1.4);
        float crevice = mix(0.6, 1.0, height);
        float thick = height;
        vec3 skyAmb = AMB * (0.03 + 0.28 * hazeLitG(mu));
        vec3 cloud = CLOUD * (skyAmb * crevice + 1.7 * faceSun * day * lightC * crevice);
        // Silver lining: thin edges glow when we look toward the sun.
        float toward = pow(max(dot(rd, S), 0.0), 6.0);
        cloud += sunC * toward * (1.0 - thick) * day * 1.2;
        // Low sun tints cloud tops orange.
        cloud += SUNSET * dens * exp(-pow(mu / 0.12, 2.0)) * 0.35 * day;
        surf = mix(surf, cloud, dens);
        // Water: tilted by waves, it mirrors the sky (much more at grazing angles, so distant sea
        // turns pale) and the sun, as a glittering path that breaks into sparkles from individual
        // wave facets near us and blurs into a smooth sheen far away where waves are sub-pixel.
        float sea = (1.0 - isLand) * (1.0 - dens);
        if (sea > 0.0) {
            float wKeep = smoothstep(0.014, 0.003, fp);
            vec2 wa = q * 60.0 + vec2(t * 0.8, t * 0.3);
            vec2 wb = q * 140.0 - vec2(t * 0.5, t * 1.1);
            vec2 slopeW = ((vec2(noise(wa), noise(wa + 17.3)) - 0.5) + 0.6 * (vec2(noise(wb), noise(wb + 9.1)) - 0.5)) * 0.22 * wKeep;
            vec3 T1 = normalize(cross(N, vec3(0.0, 0.0, 1.0)));
            vec3 T2 = cross(T1, N);
            vec3 Nw = normalize(N + T1 * slopeW.x + T2 * slopeW.y);
            vec3 R = reflect(rd, Nw);
            float rs = max(dot(R, S), 0.0);
            // Where facets are resolved the highlight is tight; where they average out it's broad.
            float n = mix(140.0, 900.0, wKeep);
            float spec = min(pow(rs, n) * (n + 2.0) * 0.012, 6.0);
            // From orbit the glint spreads into a broad patch, streaked where calm slicks and
            // wind-roughened water lie side by side.
            float slick = fbmAA(toWind * q * vec2(0.4, 3.0) + 11.0, fp * 3.0);
            float sheenN = mix(10.0, 40.0, smoothstep(0.45, 0.7, slick));
            float sheen = pow(max(dot(reflect(rd, N), S), 0.0), sheenN) * mix(0.12, 0.35, smoothstep(0.45, 0.7, slick));
            float fres = 0.02 + 0.98 * pow(1.0 - max(dot(-rd, Nw), 0.0), 5.0);
            vec3 skyRefl = mix(HAZE, SKYBLUE, 0.4) * (0.02 + 0.3 * hazeLitG(mu)) * fres;
            float unshaded = 1.0 - 0.9 * clamp(densShadow, 0.0, 1.0);
            surf += (skyRefl + sunC * (spec + sheen) * unshaded * day * sunVisG) * sea;
        }
        // Night: city lights on land, dimmed under cloud.
        float night = 1.0 - smoothstep(-0.12, 0.02, mu);
        float lights = smoothstep(0.6, 0.78, fbmAA(q * 4.0, fp * 4.0)) * smoothstep(0.55, 0.75, fbmAA(q * 0.8 + 3.0, fp * 0.8)) * isLand;
        surf += vec3(1.0, 0.7, 0.35) * lights * night * (1.0 - dens * 0.85) * 0.8;
        // Lightning: thunderstorms in the thicker cloud systems flicker on the night side, each flash
        // lighting up a patch of cloud from inside for a moment.
        if (night > 0.0 && dPuff > 0.0) {
            vec2 cell = floor(cq * 0.35);
            vec2 cc = (cell + 0.25 + 0.5 * hash22(cell + seed)) / 0.35;   // kept inside its cell
            float storm = smoothstep(0.42, 0.58, systems);
            float burst = floor(t * 7.0);
            float strike = step(0.96, hash12(cell + burst * 0.37 + seed)) * step(0.4, hash12(cell + seed * 1.3));
            float flick = 0.5 + 0.5 * hash12(cell + floor(t * 30.0));
            float dl = length(cq - cc);
            surf += vec3(0.7, 0.8, 1.0) * strike * flick * storm * (exp(-dl * dl / 0.1) * dPuff + exp(-dl * dl / 0.03) * 0.3) * night * 1.6;
        }

        // Atmosphere between us and the ground: the further and more grazing, the more haze.
        float airmass = min(1.0 / cosV + tt / h * 0.5, 40.0);
        float trans = exp(-airmass * 0.05);
        float hazeLit = smoothstep(-0.1, 0.2, mu);
        float towardSun = max(dot(normalize(rd.xz + 1e-5), normalize(S.xz + 1e-5)), 0.0);
        float orange = exp(-pow(mu / 0.08, 2.0)) * towardSun * smoothstep(28.0, 40.0, airmass);
        vec3 hazeC = mix(mix(SKYBLUE * 0.7, HAZE, 0.6), SUNSET, orange);
        vec3 inscatter = hazeC * (1.0 - trans) * (0.015 + 0.6 * hazeLit + 0.4 * orange);
        col = surf * trans + inscatter;
    }

    // Atmosphere glow above the horizon (and along the limb), from the ray's closest altitude.
    float aUp = max(ac, 0.0);
    vec3 Tpt = C + rd * max(-b, 0.0);
    float limbSun = dot(normalize(Tpt), S);
    float limbLit = smoothstep(-0.25, 0.15, limbSun);
    float twilight = exp(-pow(limbSun / 0.14, 2.0));
    vec3 glow = SKYBLUE * exp(-aUp / H) * 0.9
              + HAZE * exp(-aUp / (H * 0.3)) * 0.9
              + SUNSET * exp(-aUp / (H * 0.45)) * twilight * 1.2;
    // The thin upper atmosphere keeps scattering a little light far above the bright band, fading
    // from blue into deep indigo and then space.
    glow += SKYBLUE * exp(-aUp / (H * 3.0)) * 0.16 + SKYBLUE * vec3(0.48, 0.4, 0.6) * exp(-aUp / (H * 9.0)) * 0.07;
    glow *= mix(0.06, 1.0, limbLit);
    // Looking toward the sun the haze scatters light forward: the limb there is brighter and whiter.
    float fwdSc = pow(max(dot(rd, S), 0.0), 4.0) * smoothstep(-0.1, 0.05, e);
    glow = mix(glow, vec3(dot(glow, vec3(0.33))) * vec3(1.0, 0.95, 0.88), fwdSc * 0.5) * (1.0 + fwdSc * 1.2);
    // Airglow: a faint green line high above the night-side horizon (oxygen glowing at ~100 km).
    float airglow = exp(-pow((aUp - H * 2.4) / (H * 0.35), 2.0));
    glow += vec3(0.3, 1.0, 0.45) * airglow * 0.07 * (1.0 - limbLit);
    col = col + glow * (1.0 - cover);

    // The sun itself, only if it's above the horizon and happens to be in view: disc, glare, spikes.
    if (dot(S, fwd) > 0.0) {
        vec2 sp = vec2(dot(S, right), dot(S, upC)) / dot(S, fwd);
        vec2 dv = (q2 - sp) / pa;                                // in pixels
        float dPx = length(dv);
        float ps = pxScale();
        float glare = exp(-dPx / (60.0 * ps)) * 0.5 + exp(-dPx / (12.0 * ps)) * 1.5 + exp(-dPx * dPx / (16.0 * ps * ps)) * 4.0;
        vec2 a = abs(rotate(0.4) * dv);
        float spikes = exp(-a.x / (1.5 * ps)) * exp(-a.y / (140.0 * ps)) + exp(-a.y / (1.5 * ps)) * exp(-a.x / (140.0 * ps));
        // Hidden once the planet's edge passes in front of it (soft, as it sinks through the air).
        float bS = dot(C, S);
        float acS = bS < 0.0 ? sqrt(max(dot(C, C) - bS * bS, 0.0)) - RP : h;
        float sunVis = smoothstep(0.0, H * 0.6, acS);
        // Spikes only when the sun is actually in frame, not reaching in from just outside it.
        vec2 ext = halfExtent();
        float inFrame = step(abs(sp.x), ext.x) * step(abs(sp.y), ext.y);
        col += sunC * (glare + spikes * 0.8 * inFrame) * (1.0 - cover) * sunVis;
    }
    // Bright sky dims the stars behind it.
    float skyA = clamp(dot(glow, vec3(0.3, 0.5, 0.2)) * 0.9, 0.0, 0.9) * (1.0 - cover);
    return vec4(col, cover + skyA) * fade;
}
