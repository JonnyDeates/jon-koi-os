// Shooting stars. meteorLight draws one: a bright head with a fading, glowing trail and a slight
// tint; fireballs flare and break apart, and a lingering one leaves a persistent train that hangs in
// the sky and slowly fades. meteors() is the rare lone meteor drawn over every scene; the meteor
// shower is a scene of its own (events/shower.glsl). Additive light.

// A lone meteor may cross once in each METEOR_WINDOW seconds, with odds METEOR_ODDS: about one
// every half hour.
const float METEOR_WINDOW = 180.0;
const float METEOR_ODDS = 0.1;

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

// The rare lone meteor: a quick streak, no lingering train.
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
