// The background sky: which kind each hour gets (skyKind) and how they are layered (sky). The
// kinds themselves are in skies/*.glsl; the void is just this gradient and fewer stars.

// Which kind of sky skySeed gives: 0 nebula clouds, 1 Milky Way, 2 deep field, 3 cirrus, 4 void.
int skyKind(vec2 skySeed) {
    if (FORCE_SKY >= 0) {
        return FORCE_SKY;
    }
    float k = hash12(skySeed + 11.0);
    return k < 0.4 ? 0 : k < 0.6 ? 1 : k < 0.75 ? 2 : k < 0.9 ? 3 : 4;
}

// The whole background: a gradient, then one kind of sky (see skyKind), three parallax star
// layers and a few hot stars. skySeed picks the kind and the layout.
vec3 sky(vec2 screen, vec2 bgUv, vec2 skySeed, float t, float lens, float nebulaAmount) {
    int kind = skyKind(skySeed);
    vec3 col = mix(vec3(0.035, 0.015, 0.060), vec3(0.008, 0.010, 0.030), screen.y);
    if (kind == 4) {
        col *= 0.5;   // the void: deeper black
    }

    float dens = 0.0;
    float band = 0.0;
    if (nebulaAmount > 0.0) { // skipped entirely while an event replaces the background
        vec3 bg = vec3(0.0);
        if (kind == 0) {
            bg = nebula(bgUv, skySeed, hash12(skySeed + 5.0), t, dens);
        } else if (kind == 1) {
            bg = milkyWay(bgUv, skySeed, t, band, dens);
        } else if (kind == 2) {
            bg = deepField(bgUv, skySeed, t);
        } else if (kind == 3) {
            bg = cirrus(bgUv, skySeed, t, dens);
        }
        col += bg * nebulaAmount;
        dens *= nebulaAmount;
        band *= nebulaAmount;
    }

    // Fewer stars in the deep field and the void, so the faint things show.
    float starMul = kind == 2 ? 0.55 : kind == 4 ? 0.5 : 1.0;
    vec3 stars = vec3(0.0);
    stars += starLayer(bgUv + vec2(t * 0.0030, t * 0.0010), 60.0, 0.14 * starMul, 1.00, skySeed.x, t, lens);
    stars += starLayer(bgUv + vec2(t * 0.0018, t * 0.0006), 110.0, 0.08 * starMul, 0.70, skySeed.x + 41.0, t, lens);
    stars += starLayer(bgUv + vec2(t * 0.0009, t * 0.0003), 200.0, 0.05 * starMul, 0.45, skySeed.x + 97.0, t, lens);
    if (band > 0.01) {
        // The Milky Way's crowd of faint stars, thickest in the band.
        stars += starLayer(bgUv + vec2(t * 0.0006, 0.0), 420.0, 0.6 * band, 0.35, skySeed.x + 151.0, t, lens);
        stars += starLayer(bgUv + vec2(t * 0.0006, 0.0), 230.0, 0.4 * band, 0.5, skySeed.x + 163.0, t, lens);
    }
    col += stars * (1.0 - dens * 0.6);
    col += heatStars(bgUv + vec2(t * 0.0012, t * 0.0004), skySeed.x + 300.0, t, lens) * (kind == 4 ? 0.6 : 1.0);
    return col;
}
