// The eight full-screen nebula scenes, one per file in this folder; style (0-7, the scene's id
// minus EV_CLIFFS) picks which. Everything is lit by a young cluster: gas glows brighter near it,
// dust is rimmed where it faces it. The view drifts and pushes in very slowly. This draws the
// chosen scene's gas and dust, then the young stars over it. Premultiplied colour; .a is how much of
// the background it covers.
vec4 starForge(vec2 uv, float seed, float slot, float t, float fade, int style) {
    // Each nebula gets its own shapes, not the same clouds in different colours.
    seed += float(style) * 13.7;
    NebulaField f = nebulaField(uv, seed, slot, t, style);
    vec2 p = f.p;
    vec2 cl = f.cl;
    vec2 ext = f.ext;
    float nearC = f.nearC;
    float g = f.g;

    NebulaLook n = style == 0 ? nebulaCliffs(f)
                 : style == 1 ? nebulaOrion(f)
                 : style == 2 ? nebulaLagoon(f)
                 : style == 3 ? nebulaRosette(f)
                 : style == 4 ? nebulaHorsehead(f)
                 : style == 5 ? nebulaTarantula(f)
                 : style == 6 ? nebulaVeil(f)
                 : nebulaRho(f);
    vec3 col = n.col;
    float dust = n.dust;
    vec3 rimC = n.rimC;

    if (style != 0 && style != 4 && style != 6) {
        // Dust darkens and slightly reddens the glow behind it.
        col = col * (1.0 - dust) + col * vec3(0.25, 0.12, 0.08) * dust;
        // Its edges facing the cluster are lit: brighter where the dust is thin and near the light.
        col += rimC * smoothstep(0.15, 0.45, dust) * smoothstep(0.75, 0.45, dust) * (0.05 + 0.4 * nearC) * g;
    }

    // Young stars: a dusting everywhere, crowded toward the cluster, dimmed behind dust.
    float clear = 1.0 - dust * 0.85;
    col += starLayer(p, 110.0, 0.35, 0.9, seed + 21.0, t, 1.0) * clear;
    col += starLayer(p, 55.0, 0.35, 1.3, seed + 23.0, t, 1.0) * clear * (0.4 + 1.6 * nearC);
    // A handful of bright ones with spikes.
    bool jwst = style == 0 || hash12(vec2(slot, seed + 813.0)) < 0.5;
    for (int i = 0; i < 9; i++) {
        float fi = float(i);
        vec2 h = hash22(vec2(fi * 3.7 + slot, seed + 815.0));
        vec2 sp2 = i < 4 ? cl + (h - 0.5) * (style == 3 ? 0.6 : 0.35) : (h - 0.5) * 2.0 * ext;
        if (style == 0 && i >= 4) {
            sp2.y = abs(sp2.y) * 0.8;   // up in the cavity
        }
        float b = mix(0.35, 1.0, hash12(vec2(fi, seed + 817.0))) * (i < 4 ? 1.0 : 0.6);
        vec3 c = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.95, 0.9), hash12(vec2(fi, seed + 819.0)));
        col += forgeStar(uv, sp2, b, c, jwst);
    }

    float a = clamp(max(dust, dot(col, vec3(0.3, 0.5, 0.2)) * 1.2), 0.0, 0.97);
    return vec4(col, a) * fade;
}
