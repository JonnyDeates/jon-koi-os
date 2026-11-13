// The rare lone meteor, drawn over every scene: a quick streak with no lingering train. The meteor
// itself is drawn by meteorLight in bodies.glsl, shared with the meteor shower scene
// (events/shower.glsl). Additive light.

// A lone meteor may cross once in each METEOR_WINDOW seconds, with odds METEOR_ODDS: about one
// every half hour.
const float METEOR_WINDOW = 180.0;
const float METEOR_ODDS = 0.1;

vec3 meteors(vec2 uv, float seed, float t) {
    float win = floor(t / METEOR_WINDOW);
    float hm = hash12(vec2(win, seed + 407.0));
    if (hm > METEOR_ODDS) {
        return vec3(0.0);
    }
    float dur = mix(0.3, 1.4, hash12(vec2(hm, 1.0)));
    float start = hash12(vec2(hm, 12.0)) * (METEOR_WINDOW - 2.0);
    float age = (t - win * METEOR_WINDOW - start) / dur;
    if (age < 0.0 || age > 1.0) {
        return vec3(0.0);
    }
    vec2 p0 = (hash22(vec2(hm, 4.0)) - 0.5) * 2.0 * halfExtent() * 0.8;
    float a = hash12(vec2(hm, 5.0)) * 6.2831;
    vec2 dir = vec2(cos(a), sin(a));
    float len = mix(0.15, 0.45, hash12(vec2(hm, 6.0)));
    bool fireball = hash12(vec2(hm, 7.0)) < 0.08;
    float bright = mix(0.5, 1.2, hash12(vec2(hm, 9.0))) * (fireball ? 1.6 : 1.0);
    return meteorLight(uv, p0, dir, len, age, 0.0, bright, meteorTint(hash12(vec2(hm, 8.0))), fireball, hm);
}
