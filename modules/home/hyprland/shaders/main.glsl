void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 screen = fragCoord / iResolution.xy;
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / minDim();
    // Each monitor differs (resolution) and each launch differs (RANDOM_SEED).
    vec2 resSeed = vec2(iResolution.x * 0.0013, iResolution.y * 0.0007);
    float t = iTime;

    float slot = floor(t / EVENT_PERIOD);
    float lt = t - slot * EVENT_PERIOD;
    float fade = smoothstep(0.0, EVENT_FADE, lt) * smoothstep(EVENT_PERIOD, EVENT_PERIOD - EVENT_FADE, lt);
    float eventSeed = resSeed.x + resSeed.y * 3.0 + RANDOM_SEED;
    float roll = hash12(vec2(slot, eventSeed));
    int ev = pickEvent(roll); // same for every pixel, so derivatives inside events stay valid
    bool hasHole = ev == EV_HOLE;
    bool hasStar = ev == EV_STAR;
    bool hasSystem = ev == EV_SYSTEM;
    bool hasBinary = ev == EV_BINARY;
    bool hasEaten = ev == EV_EATEN;
    bool hasPulsar = ev == EV_PULSAR;
    bool hasPulsarClose = ev == EV_PULSARCLOSE;
    bool hasSupernova = ev == EV_SUPERNOVA;
    bool hasSurface = ev == EV_SURFACE;
    bool hasCollision = ev == EV_COLLISION;
    bool hasQuasar = ev == EV_QUASAR;
    bool hasRogue = ev == EV_ROGUE;
    bool hasHorizon = ev == EV_HORIZON;
    bool hasCluster = ev == EV_CLUSTER;
    bool hasComet = ev == EV_COMET;
    bool hasField = ev == EV_FIELD;
    bool hasPlanet = ev == EV_PLANET;
    bool hasSpiral = ev == EV_SPIRAL;
    bool hasElliptical = ev == EV_ELLIPTICAL;
    bool hasCometClose = ev == EV_COMETCLOSE;
    bool hasPillars = ev == EV_PILLARS;
    bool hasRing = ev == EV_RING;
    bool hasBipolar = ev == EV_BIPOLAR;
    bool hasCrab = ev == EV_CRAB;

    vec2 bgUv = uv;
    float shadow = 1.0;
    vec4 holeOverlay = vec4(0.0);
    if (hasHole) {
        blackHole(uv, eventSeed, slot, lt, t, fade, bgUv, shadow, holeOverlay);
    }
    // How much the lens squeezes the sky here (1 = not at all).
    float lens = clamp(length(fwidth(bgUv)) / length(fwidth(uv)), 1.0, 8.0);

    vec4 sun = vec4(0.0);
    vec3 sunGlow = vec3(0.0);
    float shimmer = 0.0;
    if (hasStar) {
        float kind = hash12(vec2(slot, eventSeed + 71.0));
        float sz = hash12(vec2(slot, eventSeed + 73.0));
        bool giant = kind >= STAR_GIANT && kind < STAR_BLUE;
        float radius = giant ? mix(0.25, 0.45, sz) : kind >= STAR_BLUE ? mix(0.07, 0.13, sz) : mix(0.12, 0.22, sz);
        vec2 center = (hash22(vec2(slot * 3.1, eventSeed + 75.0)) - 0.5) * 2.0 * halfExtent() * 0.8;
        center += (hash22(vec2(slot, eventSeed + 77.0)) - 0.5) * 0.0004 * lt;
        sun = star(uv, center, radius, kind, eventSeed, slot, t, fade, sunGlow, shimmer);
    }
    vec3 nova = vec3(0.0);
    if (hasSupernova) {
        nova = supernova(uv, eventSeed, slot, lt, t, fade, shimmer).rgb;
    }
    vec4 system = vec4(0.0);
    if (hasBinary) {
        system = binaryStars(uv, eventSeed, slot, t, fade, shimmer);
    }
    if (hasEaten) {
        system = starEaten(uv, eventSeed, slot, t, fade, shimmer);
    }
    if (hasSystem) {
        system = solarSystem(uv, eventSeed, slot, t, fade, shimmer);
    }
    // Heat shimmer: the sky behind a star's corona ripples, with waves rising over time.
    vec2 wob = vec2(noise(uv * 40.0 + vec2(0.0, t * 1.2)), noise(uv * 40.0 + vec2(t * 1.2, 7.0))) - 0.5;
    bgUv += wob * shimmer * 0.004;

    // Asteroid fields get plain dark space behind them: the nebula fades out as the field fades in.
    // A nebula close-up replaces the background nebula the same way.
    float nebulaAmount = hasField || hasPillars || hasRing || hasCrab || hasBipolar || hasCometClose || hasSurface || hasCollision || hasQuasar || hasRogue || hasHorizon || hasCluster ? 1.0 - fade : 1.0;

    // A new random sky every SKY_PERIOD, cross-fading into the next one over the last SKY_FADE.
    float hour = floor(t / SKY_PERIOD);
    vec2 skySeedA = resSeed + hash22(vec2(hour, RANDOM_SEED)) * 100.0;
    vec3 col = sky(screen, bgUv, skySeedA, t, lens, nebulaAmount);
    float skyBlend = smoothstep(SKY_PERIOD - SKY_FADE, SKY_PERIOD, t - hour * SKY_PERIOD);
    if (skyBlend > 0.0) {
        vec2 skySeedB = resSeed + hash22(vec2(hour + 1.0, RANDOM_SEED)) * 100.0;
        col = mix(col, sky(screen, bgUv, skySeedB, t, lens, nebulaAmount), skyBlend);
    }

    // How much of each pixel is covered by something solid (planets, moons, rocks); meteors are
    // hidden behind it.
    float solid = 0.0;
    if (hasPillars) {
        vec4 n = pillarNebula(uv, eventSeed, slot, t) * fade;
        col = col * (1.0 - n.a) + n.rgb;
    }
    if (hasBipolar) {
        vec4 n = bipolarNebula(uv, eventSeed, slot, t, fade);
        col = col * (1.0 - n.a) + n.rgb;
    }
    if (hasRing) {
        col += ringNebula(uv, eventSeed, slot, t).rgb * fade;
    }
    if (hasCrab) {
        col += crabNebula(uv, eventSeed, slot, t, fade).rgb;
    }
    if (hasRogue) {
        vec4 rp = roguePlanet(uv, eventSeed, slot, t, fade);
        col = col * (1.0 - rp.a) + rp.rgb;
        solid = rp.a;
    }
    if (hasHorizon) {
        vec4 hz = planetHorizon(uv, eventSeed, slot, t, fade);
        col = col * (1.0 - hz.a) + hz.rgb;
        // From orbit, meteors burn up far below us, so none streak across this sky.
        solid = fade;
    }
    if (hasCluster) {
        vec4 sc = starCluster(uv, eventSeed, slot, t, fade);
        col = col * (1.0 - sc.a) + sc.rgb;
    }
    if (hasQuasar) {
        col += quasar(uv, eventSeed, slot, t, fade).rgb;
    }
    if (hasCollision) {
        vec4 gc = galaxyCollision(uv, eventSeed, slot, t, fade);
        col = col * (1.0 - gc.a) + gc.rgb;
    }
    if (hasElliptical) {
        vec4 g = ellipticalGalaxy(uv, eventSeed, slot, t, fade);
        col = col * (1.0 - g.a) + g.rgb;
    }
    if (hasSpiral) {
        vec4 g = spiralGalaxy(uv, eventSeed, slot, t, fade);
        col = col * (1.0 - g.a) + g.rgb;
    }
    if (hasPlanet) {
        vec3 glow;
        vec4 p = planet(uv, eventSeed, slot, lt, t, fade, glow);
        col = col * (1.0 - p.a) + p.rgb + glow;
        solid = max(solid, p.a);
    }
    col = col * (1.0 - sun.a) + sun.rgb + sunGlow;
    col = col * (1.0 - system.a) + system.rgb;
    solid = max(solid, system.a);
    if (hasField) {
        vec4 field = asteroidField(uv, eventSeed, slot, t, fade);
        col = col * (1.0 - field.a) + field.rgb;
        solid = max(solid, field.a);
    }
    col += nova;
    if (hasSurface) {
        vec4 ss = starSurface(uv, eventSeed, slot, t, fade);
        col = col * (1.0 - ss.a) + ss.rgb;
        solid = max(solid, ss.a);
    }
    if (hasPulsarClose) {
        col += pulsarCloseUp(uv, eventSeed, slot, t, fade).rgb;
    }
    if (hasPulsar) {
        col += pulsar(uv, eventSeed, slot, t, fade).rgb;
    }
    if (hasCometClose) {
        vec4 cc = cometCloseUp(uv, eventSeed, slot, t, fade);
        col = col * (1.0 - cc.a) + cc.rgb;
        solid = max(solid, cc.a);
    }
    if (hasComet) {
        col += comet(uv, eventSeed, slot, lt, t, fade);
    }

    col = col * shadow;
    col = col * (1.0 - holeOverlay.a) + holeOverlay.rgb;

    // Shooting stars, behind anything solid in the scene.
    col += meteors(uv, eventSeed, t) * (1.0 - clamp(max(solid, holeOverlay.a), 0.0, 1.0));

    vec2 c = screen - 0.5;
    col *= 1.0 - 0.35 * dot(c, c);

    // Soft tonemap so hot stars and bright cores don't clip harshly, plus a static dither.
    col = col / (1.0 + col * 0.25);
    col += (hash12(fragCoord) - 0.5) / 255.0;

    fragColor = vec4(col, 1.0);
}
